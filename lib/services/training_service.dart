import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../utils/error_text.dart';
import '../utils/firestore_write.dart';

// Enumy tréninku se v databázi ukládají jako svůj název ([Enum.name],
// např. `team`, `yes`, `run`) a zpět se převádějí přes fromName.

/// Druh tréninku.
enum TrainingKind {
  /// Společný trénink celého týmu – hráči odpovídají BUDU / NEBUDU.
  team,

  /// Individuální trénink zadaný vybraným hráčům – sleduje se jeho splnění.
  individual;

  static TrainingKind fromName(String? name) =>
      values.asNameMap()[name] ?? team;
}

/// Odpověď hráče v mapě `responses` tréninku (uid hráče -> odpověď).
enum TrainingResponse {
  /// BUDU – u společného tréninku.
  yes,

  /// NEBUDU – u společného tréninku.
  no,

  /// Splněno – u individuálního tréninku.
  done;

  static TrainingResponse? fromName(String? name) => values.asNameMap()[name];
}

/// Typ tréninku.
enum TrainingType {
  run('Běh'),
  strength('Silový trénink'),
  technique('Technický trénink'),
  recovery('Regenerace'),
  other('Ostatní');

  const TrainingType(this.label);

  final String label;

  static TrainingType fromName(String? name) =>
      values.asNameMap()[name] ?? other;
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
      kind: TrainingKind.fromName(data['kind'] as String?),
      title: data['title'] as String? ?? 'Trénink',
      type: TrainingType.fromName(data['type'] as String?),
      startAt: (data['startAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endAt: (data['endAt'] as Timestamp?)?.toDate(),
      place: data['place'] as String?,
      description: data['description'] as String?,
      assignedTo: List<String>.from(data['assignedTo'] as List? ?? const []),
      responses: _parseResponses(data['responses']),
    );
  }

  /// Mapa odpovědí z databáze; neznámé hodnoty se vynechají.
  static Map<String, TrainingResponse> _parseResponses(Object? raw) {
    final responses = <String, TrainingResponse>{};
    (raw as Map? ?? const {}).forEach((uid, value) {
      final response = TrainingResponse.fromName(value as String?);
      if (response != null) responses[uid as String] = response;
    });
    return responses;
  }

  final String id;
  final TrainingKind kind;
  final String title;
  final TrainingType type;
  final DateTime startAt;
  final DateTime? endAt;
  final String? place;
  final String? description;

  /// Hráči, kterým je individuální trénink zadaný. U společného prázdné.
  final List<String> assignedTo;

  /// Odpovědi hráčů: uid -> odpověď.
  final Map<String, TrainingResponse> responses;

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
      throw AppException('Uživatel není přihlášen');
    }
    return user.uid;
  }

  CollectionReference<Map<String, dynamic>> _trainings(String teamId) =>
      _db.collection('teams').doc(teamId).collection('trainings');

  /// Tréninky týmu pro kalendář – nadcházející (od dnešní půlnoci), nebo
  /// proběhlé ([past]). Vždy seřazené podle začátku vzestupně.
  Stream<List<Training>> streamTrainings(
    String teamId, {
    required bool isCoach,
    required bool past,
  }) {
    final now = DateTime.now();
    final todayStart =
        Timestamp.fromDate(DateTime(now.year, now.month, now.day));
    return _streamVisible(
      teamId,
      isCoach,
      (query) => past
          ? query.where('startAt', isLessThan: todayStart)
          : query.where('startAt', isGreaterThanOrEqualTo: todayStart),
    );
  }

  /// Tréninky týmu se začátkem v rozmezí [from] (včetně) až [to] (bez) –
  /// týdenní kalendář v detailu týmu.
  Stream<List<Training>> streamTrainingsBetween(
    String teamId, {
    required bool isCoach,
    required DateTime from,
    required DateTime to,
  }) {
    return _streamVisible(
      teamId,
      isCoach,
      (query) => query
          .where('startAt', isGreaterThanOrEqualTo: Timestamp.fromDate(from))
          .where('startAt', isLessThan: Timestamp.fromDate(to)),
    );
  }

  /// Tréninky, které uživatel smí vidět, omezené podmínkou [inRange] na
  /// startAt a seřazené podle začátku.
  ///
  /// Trenér čte všechny tréninky týmu jedním dotazem. Hráč smí číst jen
  /// společné tréninky a individuální zadané jemu. Firestore pravidla
  /// nejsou filtr – dotaz musí sám zaručit, že vrátí jen povolené
  /// dokumenty – proto se pro hráče posílají dva dotazy (kind == 'team'
  /// a assignedTo array-contains uid) a jejich výsledky se spojí. Oba
  /// potřebují složený index, viz firestore.indexes.json.
  Stream<List<Training>> _streamVisible(
    String teamId,
    bool isCoach,
    Query<Map<String, dynamic>> Function(Query<Map<String, dynamic>>) inRange,
  ) {
    Stream<List<Training>> listen(Query<Map<String, dynamic>> query) {
      return inRange(query)
          .orderBy('startAt')
          .snapshots()
          .map((snapshot) => snapshot.docs.map(Training.fromDoc).toList());
    }

    final trainings = _trainings(teamId);
    if (isCoach) return listen(trainings);
    return _combine(
      listen(trainings.where('kind', isEqualTo: TrainingKind.team.name)),
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
  ///
  /// Nečeká se, až změnu potvrdí server: bez internetu se trénink uloží
  /// v telefonu a odešle se sám po připojení. Vrací false, když změna
  /// zatím čeká v telefonu (viz waitForServer).
  Future<bool> saveTraining({
    required String teamId,
    String? trainingId,
    required TrainingKind kind,
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
      throw AppException('Zadej název tréninku');
    }
    if (trimmedTitle.length > 100) {
      throw AppException('Název může mít nejvýše 100 znaků');
    }
    if (endAt != null && !endAt.isAfter(startAt)) {
      throw AppException('Konec tréninku musí být až po jeho začátku');
    }
    final isTeam = kind == TrainingKind.team;
    if (!isTeam && assignedTo.isEmpty) {
      throw AppException('Vyber alespoň jednoho hráče');
    }

    final data = <String, dynamic>{
      'kind': kind.name,
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
      return waitForServer(_trainings(teamId).doc().set({
        ...data,
        'responses': <String, String>{},
        'createdBy': _uid,
        'createdAt': FieldValue.serverTimestamp(),
      }));
    }

    // Po změně druhu tréninku (společný <-> individuální) už dosavadní
    // odpovědi nedávají smysl (BUDU/NEBUDU vs. splněno), proto se smažou.
    // Bez internetu se trénink přečte z telefonu (je tam z kalendáře).
    final ref = _trainings(teamId).doc(trainingId);
    final current = await ref.get();
    if (current.data()?['kind'] != kind.name) {
      data['responses'] = <String, String>{};
    }
    return waitForServer(ref.update(data));
  }

  /// Smaže trénink. Smí jen trenér týmu.
  ///
  /// Smazání vyžaduje internet: nejdřív se trénink přečte přímo ze
  /// serveru – bez připojení to skončí chybou „bez internetu“ (viz
  /// errorText) a nic se nesmaže ani nezařadí do fronty v telefonu.
  Future<void> deleteTraining(String teamId, String trainingId) async {
    final ref = _trainings(teamId).doc(trainingId);
    await ref.get(const GetOptions(source: Source.server));
    await ref.delete();
  }

  /// Uloží odpověď aktuálního hráče – [TrainingResponse.yes] / [TrainingResponse.no]
  /// u společného tréninku, [TrainingResponse.done] u individuálního.
  /// `null` odpověď smaže (zpět na „bez odpovědi“ / „naplánovaný“).
  Future<void> respond(
      String teamId, String trainingId, TrainingResponse? response) {
    return _trainings(teamId).doc(trainingId).update({
      FieldPath(['responses', _uid]): response?.name ?? FieldValue.delete(),
    });
  }
}
