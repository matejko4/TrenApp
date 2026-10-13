import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Druh tréninku.
class TrainingKind {
  /// Společný trénink celého týmu – hráči odpovídají BUDU / NEBUDU.
  static const team = 'team';

  /// Individuální trénink zadaný vybraným hráčům – sleduje se jeho splnění.
  static const individual = 'individual';
}

/// Hodnoty v mapě `responses` tréninku (uid hráče -> odpověď).
class TrainingResponse {
  /// BUDU – u společného tréninku.
  static const yes = 'yes';

  /// NEBUDU – u společného tréninku.
  static const no = 'no';

  /// Splněno – u individuálního tréninku.
  static const done = 'done';
}

/// Typ tréninku. V databázi se ukládá [name] (např. `run`).
enum TrainingType {
  run('Běh'),
  strength('Silový trénink'),
  technique('Technický trénink'),
  recovery('Regenerace'),
  other('Ostatní');

  const TrainingType(this.label);

  final String label;

  static TrainingType fromName(String? name) =>
      values.firstWhere((type) => type.name == name, orElse: () => other);
}

/// Stav individuálního tréninku z pohledu jednoho hráče.
enum IndividualStatus { planned, done, missed }

/// Trénink načtený z teams/{teamId}/trainings/{trainingId}.
class Training {
  Training({
    required this.id,
    required this.kind,
    required this.title,
    required this.type,
    required this.startAt,
    this.endAt,
    this.place,
    this.description,
    required this.assignedTo,
    required this.responses,
  });

  factory Training.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return Training(
      id: doc.id,
      kind: data['kind'] as String? ?? TrainingKind.team,
      title: data['title'] as String? ?? 'Trénink',
      type: TrainingType.fromName(data['type'] as String?),
      startAt: (data['startAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endAt: (data['endAt'] as Timestamp?)?.toDate(),
      place: data['place'] as String?,
      description: data['description'] as String?,
      assignedTo: List<String>.from(data['assignedTo'] as List? ?? const []),
      responses:
          Map<String, String>.from(data['responses'] as Map? ?? const {}),
    );
  }

  final String id;
  final String kind;
  final String title;
  final TrainingType type;
  final DateTime startAt;
  final DateTime? endAt;
  final String? place;
  final String? description;

  /// Hráči, kterým je individuální trénink zadaný. U společného prázdné.
  final List<String> assignedTo;

  /// Odpovědi hráčů: uid -> [TrainingResponse].
  final Map<String, String> responses;

  bool get isTeam => kind == TrainingKind.team;

  /// Na společný trénink jde odpovídat BUDU / NEBUDU jen do jeho začátku.
  bool get canRespond => DateTime.now().isBefore(startAt);

  /// Individuální trénink jde splnit do konce dne, na který je zadaný –
  /// potom je nesplněný.
  bool get isOver {
    final dayEnd = DateTime(startAt.year, startAt.month, startAt.day + 1);
    return !DateTime.now().isBefore(dayEnd);
  }

  IndividualStatus statusOf(String uid) {
    if (responses[uid] == TrainingResponse.done) return IndividualStatus.done;
    return isOver ? IndividualStatus.missed : IndividualStatus.planned;
  }
}

/// Zadávání tréninků (trenér) a odpovědi na ně (hráč).
///
/// Datový model:
/// - teams/{teamId}/trainings/{trainingId} – trénink včetně odpovědí hráčů
///   v mapě `responses` (uid -> yes/no/done)
///
/// Odpovědi jsou přímo v dokumentu tréninku (ne v podkolekci), aby trenér
/// viděl přehled účasti celého kalendáře bez dalšího čtení pro každý
/// trénink. Firestore pravidla hráči dovolí v tréninku změnit jen jeho
/// vlastní klíč v `responses`.
class TrainingService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get _uid {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Uživatel není přihlášen');
    }
    return user.uid;
  }

  CollectionReference<Map<String, dynamic>> _trainings(String teamId) =>
      _db.collection('teams').doc(teamId).collection('trainings');

  /// Tréninky týmu pro kalendář – nadcházející (od dnešní půlnoci), nebo
  /// proběhlé ([past]). Vždy seřazené podle začátku vzestupně.
  ///
  /// Trenér čte všechny tréninky týmu jedním dotazem. Hráč smí číst jen
  /// společné tréninky a individuální zadané jemu. Firestore pravidla
  /// nejsou filtr – dotaz musí sám zaručit, že vrátí jen povolené
  /// dokumenty – proto se pro hráče posílají dva dotazy (kind == 'team'
  /// a assignedTo array-contains uid) a jejich výsledky se spojí. Oba
  /// potřebují složený index, viz firestore.indexes.json.
  Stream<List<Training>> streamTrainings(
    String teamId, {
    required bool isCoach,
    required bool past,
  }) {
    final now = DateTime.now();
    final todayStart =
        Timestamp.fromDate(DateTime(now.year, now.month, now.day));

    Stream<List<Training>> listen(Query<Map<String, dynamic>> query) {
      final inRange = past
          ? query.where('startAt', isLessThan: todayStart)
          : query.where('startAt', isGreaterThanOrEqualTo: todayStart);
      return inRange
          .orderBy('startAt')
          .snapshots()
          .map((snapshot) => snapshot.docs.map(Training.fromDoc).toList());
    }

    final trainings = _trainings(teamId);
    if (isCoach) return listen(trainings);
    return _combine(
      listen(trainings.where('kind', isEqualTo: TrainingKind.team)),
      listen(trainings.where('assignedTo', arrayContains: _uid)),
    );
  }

  /// Spojí dva streamy tréninků do jednoho seřazeného seznamu. Vydává až
  /// ve chvíli, kdy oba streamy poslaly alespoň jeden výsledek.
  Stream<List<Training>> _combine(
    Stream<List<Training>> a,
    Stream<List<Training>> b,
  ) {
    List<Training>? lastA;
    List<Training>? lastB;
    final subscriptions = <StreamSubscription<List<Training>>>[];
    late final StreamController<List<Training>> controller;

    void emit() {
      if (lastA == null || lastB == null) return;
      controller.add(
        [...lastA!, ...lastB!]..sort((x, y) => x.startAt.compareTo(y.startAt)),
      );
    }

    controller = StreamController<List<Training>>(
      onListen: () {
        subscriptions
          ..add(a.listen((value) {
            lastA = value;
            emit();
          }, onError: controller.addError))
          ..add(b.listen((value) {
            lastB = value;
            emit();
          }, onError: controller.addError));
      },
      onCancel: () => Future.wait(subscriptions.map((s) => s.cancel())),
    );
    return controller.stream;
  }

  /// Stream jednoho tréninku (null, pokud byl mezitím smazán).
  Stream<Training?> streamTraining(String teamId, String trainingId) {
    return _trainings(teamId)
        .doc(trainingId)
        .snapshots()
        .map((doc) => doc.exists ? Training.fromDoc(doc) : null);
  }

  String? _emptyToNull(String? text) {
    final trimmed = text?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }

  /// Vytvoří nový trénink, nebo upraví existující ([trainingId] != null).
  /// Smí jen trenér týmu.
  Future<void> saveTraining({
    required String teamId,
    String? trainingId,
    required String kind,
    required String title,
    required TrainingType type,
    required DateTime startAt,
    DateTime? endAt,
    String? place,
    String? description,
    List<String> assignedTo = const [],
  }) async {
    final trimmedTitle = title.trim();
    if (trimmedTitle.isEmpty) {
      throw Exception('Zadej název tréninku');
    }
    if (trimmedTitle.length > 100) {
      throw Exception('Název může mít nejvýše 100 znaků');
    }
    if (endAt != null && !endAt.isAfter(startAt)) {
      throw Exception('Konec tréninku musí být až po jeho začátku');
    }
    final isTeam = kind == TrainingKind.team;
    if (!isTeam && assignedTo.isEmpty) {
      throw Exception('Vyber alespoň jednoho hráče');
    }

    final data = <String, dynamic>{
      'kind': kind,
      'title': trimmedTitle,
      'type': type.name,
      'startAt': Timestamp.fromDate(startAt),
      'endAt': endAt == null ? null : Timestamp.fromDate(endAt),
      // Místo se zadává jen u společného tréninku (individuální si hráč
      // odcvičí, kde chce).
      'place': isTeam ? _emptyToNull(place) : null,
      'description': _emptyToNull(description),
      'assignedTo': isTeam ? <String>[] : assignedTo,
    };

    if (trainingId == null) {
      await _trainings(teamId).add({
        ...data,
        'responses': <String, String>{},
        'createdBy': _uid,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return;
    }

    // Po změně druhu tréninku (společný <-> individuální) už dosavadní
    // odpovědi nedávají smysl (BUDU/NEBUDU vs. splněno), proto se smažou.
    final ref = _trainings(teamId).doc(trainingId);
    final current = await ref.get();
    if (current.data()?['kind'] != kind) {
      data['responses'] = <String, String>{};
    }
    await ref.update(data);
  }

  /// Smaže trénink. Smí jen trenér týmu.
  Future<void> deleteTraining(String teamId, String trainingId) {
    return _trainings(teamId).doc(trainingId).delete();
  }

  /// Uloží odpověď aktuálního hráče – [TrainingResponse.yes] / [TrainingResponse.no]
  /// u společného tréninku, [TrainingResponse.done] u individuálního.
  /// `null` odpověď smaže (zpět na „bez odpovědi“ / „naplánovaný“).
  Future<void> respond(String teamId, String trainingId, String? response) {
    return _trainings(teamId).doc(trainingId).update({
      FieldPath(['responses', _uid]): response ?? FieldValue.delete(),
    });
  }
}
