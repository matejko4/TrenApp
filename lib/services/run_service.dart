import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../utils/error_text.dart';
import '../utils/firestore_write.dart';
import 'training_service.dart';

/// Jeden bod trasy běhu.
class RunPoint {
  const RunPoint({
    required this.lat,
    required this.lng,
    required this.t,
    required this.s,
  });

  /// Bod z databáze. Čísla se převádějí přes num – Firestore celé číslo
  /// (např. souřadnici 50) vrátí jako int, ne double.
  factory RunPoint.fromMap(Map<String, dynamic> map) => RunPoint(
    lat: (map['lat'] as num).toDouble(),
    lng: (map['lng'] as num).toDouble(),
    t: (map['t'] as num).toInt(),
    s: (map['s'] as num).toInt(),
  );

  final double lat;
  final double lng;

  /// Sekundy aktivního času (bez pauz) od startu běhu.
  final int t;

  /// Číslo úseku – 0 od startu, po každém „Pokračovat“ o jedna víc.
  final int s;

  Map<String, dynamic> toMap() => {'lat': lat, 'lng': lng, 't': t, 's': s};
}

/// Záznam běhu z teams/{teamId}/trainings/{trainingId}/runs/{uid}.
class Run {
  const Run({
    required this.startedAt,
    required this.endedAt,
    required this.durationSeconds,
    required this.distanceMeters,
    required this.points,
  });

  factory Run.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return Run(
      startedAt: (data['startedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endedAt: (data['endedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      durationSeconds: (data['durationSeconds'] as num? ?? 0).toInt(),
      distanceMeters: (data['distanceMeters'] as num? ?? 0).toInt(),
      points: [
        for (final point in data['points'] as List? ?? const [])
          RunPoint.fromMap(Map<String, dynamic>.from(point as Map)),
      ],
    );
  }

  final DateTime startedAt;
  final DateTime endedAt;

  /// Aktivní čas běhu bez pauz.
  final int durationSeconds;
  final int distanceMeters;

  /// Body trasy – všechny úseky za sebou v jednom seznamu, úsek určuje
  /// [RunPoint.s]. Firestore neumí pole polí, proto ne seznam úseků.
  final List<RunPoint> points;

  /// Body rozdělené po úsecích (mezi úseky byla pauza).
  List<List<RunPoint>> get segments {
    final segments = <List<RunPoint>>[];
    for (final point in points) {
      if (segments.isEmpty || segments.last.last.s != point.s) {
        segments.add([point]);
      } else {
        segments.last.add(point);
      }
    }
    return segments;
  }

  /// Počet pauz – každé „Pokračovat“ začíná nový úsek. Pauza, po které už
  /// nepřišel žádný bod (hned Ukončit), se v trase nepozná.
  int get pauseCount => points.isEmpty ? 0 : points.last.s;

  /// Celá čísla – bezpečnostní pravidla kontrolují `is int`.
  Map<String, dynamic> toMap() => {
    'startedAt': Timestamp.fromDate(startedAt),
    'endedAt': Timestamp.fromDate(endedAt),
    'durationSeconds': durationSeconds,
    'distanceMeters': distanceMeters,
    'points': [for (final point in points) point.toMap()],
  };
}

/// Záznam běhu přes GPS: oprávnění k poloze, proud polohy a uložení.
///
/// Datový model: teams/{teamId}/trainings/{trainingId}/runs/{uid} – ID
/// dokumentu je uid hráče, takže na jeden trénink má hráč jeden běh.
///
/// Offline: běh se uloží do Firestore cache v telefonu (přežije zavření
/// aplikace) a odešle se sám, až bude internet – žádná další lokální
/// databáze není potřeba.
class RunService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get _uid {
    final user = _auth.currentUser;
    if (user == null) {
      throw AppException('Uživatel není přihlášen');
    }
    return user.uid;
  }

  DocumentReference<Map<String, dynamic>> _training(
    String teamId,
    String trainingId,
  ) => _db
      .collection('teams')
      .doc(teamId)
      .collection('trainings')
      .doc(trainingId);

  DocumentReference<Map<String, dynamic>> _run(
    String teamId,
    String trainingId,
    String uid,
  ) => _training(teamId, trainingId).collection('runs').doc(uid);

  /// Ověří, že je v telefonu zapnutá poloha a aplikace k ní smí – podle
  /// potřeby si o oprávnění řekne. Jinak vyhodí [AppException] s českou
  /// hláškou a běh se nespustí.
  Future<void> ensureLocationReady() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw AppException('Zapni v telefonu polohu (GPS) a zkus to znovu.');
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    switch (permission) {
      case LocationPermission.whileInUse:
      case LocationPermission.always:
        return;
      case LocationPermission.deniedForever:
        throw AppException(
          'Přístup k poloze je zakázaný. Povol ho '
          'v Nastavení telefonu → Aplikace → TrenApp → Oprávnění.',
        );
      case LocationPermission.denied:
      case LocationPermission.unableToDetermine:
        throw AppException('Bez přístupu k poloze nejde běh zaznamenat.');
    }
  }

  /// Proud polohy pro záznam běhu.
  ///
  /// Na Androidu běží jako služba na popředí s trvalou notifikací – díky
  /// ní systém aplikaci nechá zaznamenávat i se zhasnutým displejem
  /// (wake lock drží procesor vzhůru). distanceFilter: nový bod nejdřív
  /// po 5 metrech, aby se trasa při stání neplnila „poskakujícími“ body.
  Stream<Position> positions() {
    final LocationSettings settings;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      settings = AndroidSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 5,
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'Záznam běhu',
          notificationText: 'TrenApp zaznamenává tvůj běh',
          notificationChannelName: 'Záznam běhu',
          enableWakeLock: true,
          setOngoing: true,
        ),
      );
    } else {
      settings = const LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 5,
      );
    }
    return Geolocator.getPositionStream(locationSettings: settings);
  }

  /// Uloží běh aktuálního hráče a v téže dávce mu trénink označí jako
  /// splněný – v kalendáři se hned (i offline) přepne na „Splněný“.
  ///
  /// Nečeká se, až zápis potvrdí server: vrací false, když běh zatím
  /// čeká v telefonu a odešle se po připojení (viz waitForServer).
  Future<bool> saveRun(String teamId, String trainingId, Run run) {
    final uid = _uid;
    // WriteBatch.update bere jen textové cesty – uid obsahuje jen písmena,
    // číslice a pomlčky, takže „responses.uid“ je bezpečná cesta.
    final batch = _db.batch()
      ..set(_run(teamId, trainingId, uid), run.toMap())
      ..update(_training(teamId, trainingId), {
        'responses.$uid': TrainingResponse.done.name,
      });
    return waitForServer(batch.commit());
  }

  /// Stream běhu hráče [uid] u tréninku (null, když běh nemá – např.
  /// trénink splnil ručně). Každý dokument nese celou trasu, proto se
  /// načítá jen běh, který si někdo otevře, ne všechny najednou.
  Stream<Run?> streamRun(String teamId, String trainingId, String uid) {
    return _run(
      teamId,
      trainingId,
      uid,
    ).snapshots().map((doc) => doc.exists ? Run.fromDoc(doc) : null);
  }

  /// Stream běhu přihlášeného hráče.
  Stream<Run?> streamMyRun(String teamId, String trainingId) =>
      streamRun(teamId, trainingId, _uid);
}
