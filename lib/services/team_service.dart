import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Role uživatele v rámci konkrétního týmu. V databázi se ukládá
/// [Enum.name] (`coach` / `player`).
enum TeamRole {
  coach,
  player;

  static TeamRole fromName(String? name) => values.asNameMap()[name] ?? player;
}

/// Jméno člena ze soupisky. Jméno je povinné ještě před vstupem do týmu
/// (NameSetupScreen), záložní text je jen pojistka.
String memberName(Map<String, dynamic> memberData) =>
    memberData['name'] as String? ?? 'Bez jména';

/// Hráči (bez trenérů) ze soupisky týmu jako uid -> jméno.
Map<String, String> playerNames(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> members) {
  return {
    for (final doc in members)
      if (TeamRole.fromName(doc.data()['role'] as String?) == TeamRole.player)
        doc.id: memberName(doc.data()),
  };
}

/// Stará se o vytváření týmů, připojování k týmům kódem a čtení
/// týmů, ve kterých je aktuální uživatel členem.
///
/// Datový model:
/// - teams/{teamId}                      – základní údaje o týmu (název, kód, správce)
/// - teams/{teamId}/members/{uid}        – roster týmu (jméno, role, kdy se přidal)
/// - users/{uid}/teams/{teamId}          – rychlý přehled týmů daného uživatele a jeho role v nich
/// - team_codes/{code}                   – mapování pozvánkového kódu na tým (viz níže)
///
/// Do soupisky se neukládá e-mail – soupisku čtou všichni členové týmu
/// a pravidla nejdou omezit na jednotlivá pole dokumentu.
///
/// Uživatel může být v libovolném počtu týmů, v každém s jinou rolí,
/// proto se role neukládá na uživatele globálně, ale vždy ve vazbě na tým.
///
/// team_codes je samostatná kolekce (doc id = kód) místo dotazu
/// `teams.where('code', ...)`, protože Firestore pravidla vyhodnocují
/// `list`/dotazy staticky vůči celému dotazu, ne per-dokument – dotaz
/// nad kolekcí teams by tak vyžadoval, aby podmínka platila pro všechny
/// týmy v kolekci najednou, což pro nečlena (přesně případ připojování)
/// nejde splnit. Přímý `get()` podle id dokumentu (=kódu) tento problém
/// nemá, protože se vyhodnocuje jen vůči jednomu konkrétnímu dokumentu.
class TeamService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get _uid {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Uživatel není přihlášen');
    }
    return user.uid;
  }

  String _generateCode() {
    // Bez znaků, které se snadno pletou (0/O, 1/I).
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rand = Random.secure();
    return List.generate(8, (_) => chars[rand.nextInt(chars.length)]).join();
  }

  Future<String> _generateUniqueCode() async {
    for (var attempt = 0; attempt < 10; attempt++) {
      final code = _generateCode();
      final existing = await _db.collection('team_codes').doc(code).get();
      if (!existing.exists) return code;
    }
    throw Exception('Nepodařilo se vygenerovat kód týmu, zkus to znovu');
  }

  /// Jméno aktuálního uživatele (users/{uid}.name), které se ukládá do
  /// rosteru týmu, aby se ostatním členům zobrazovalo místo e-mailu.
  Future<String?> _myName(User user) async {
    final doc = await _db.collection('users').doc(user.uid).get();
    return doc.data()?['name'] as String? ?? user.displayName;
  }

  /// Vytvoří nový tým. Zakladatel se stává jeho správcem a trenérem.
  /// Vrací id nově vytvořeného týmu.
  ///
  /// Tým, pozvánkový kód, členství zakladatele i jeho index se zapisují
  /// v jedné dávce – vznikne buď všechno, nebo nic. Pravidla pro kód
  /// a trenérské členství proto ověřují správce přes getAfter() (stav po
  /// celé dávce), protože dokument týmu před dávkou ještě neexistuje.
  Future<String> createTeam(String name) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw Exception('Zadej název týmu');
    }

    final user = _auth.currentUser;
    if (user == null) throw Exception('Uživatel není přihlášen');

    final code = await _generateUniqueCode();
    final myName = await _myName(user);
    final teamRef = _db.collection('teams').doc();

    final batch = _db.batch();

    batch.set(teamRef, {
      'name': trimmedName,
      'code': code,
      'ownerUid': user.uid,
      'createdAt': FieldValue.serverTimestamp(),
    });

    batch.set(_db.collection('team_codes').doc(code), {
      'teamId': teamRef.id,
      'teamName': trimmedName,
    });

    batch.set(teamRef.collection('members').doc(user.uid), {
      'uid': user.uid,
      'name': myName,
      'role': TeamRole.coach.name,
      'joinedAt': FieldValue.serverTimestamp(),
    });

    batch.set(
      _db.collection('users').doc(user.uid).collection('teams').doc(teamRef.id),
      {
        'teamId': teamRef.id,
        'teamName': trimmedName,
        'role': TeamRole.coach.name,
        // Kód se ukládá i sem, aby ho trenér viděl přímo na HomeScreen a
        // mohl ho sdílet s hráči, aniž by se muselo číst z teams/{teamId}.
        'code': code,
        'joinedAt': FieldValue.serverTimestamp(),
      },
    );

    await batch.commit();
    return teamRef.id;
  }

  /// Připojí aktuálního uživatele k týmu podle kódu. Nový člen se
  /// vždy stává hráčem (trenéři se přidávají jinou cestou).
  Future<void> joinTeamByCode(String code) async {
    final normalized = code.trim().toUpperCase();
    if (normalized.isEmpty) {
      throw Exception('Zadej kód týmu');
    }

    final user = _auth.currentUser;
    if (user == null) throw Exception('Uživatel není přihlášen');

    final codeDoc = await _db.collection('team_codes').doc(normalized).get();
    if (!codeDoc.exists) {
      throw Exception('Tým s tímto kódem neexistuje');
    }

    final teamId = codeDoc.data()!['teamId'] as String;
    final teamName = codeDoc.data()!['teamName'] as String? ?? 'Tým';
    final memberRef =
        _db.collection('teams').doc(teamId).collection('members').doc(user.uid);

    final existingMember = await memberRef.get();
    if (existingMember.exists) {
      throw Exception('V tomto týmu už jsi členem');
    }

    final myName = await _myName(user);

    final batch = _db.batch();

    batch.set(memberRef, {
      'uid': user.uid,
      'name': myName,
      'role': TeamRole.player.name,
      'joinedAt': FieldValue.serverTimestamp(),
    });

    batch.set(
      _db.collection('users').doc(user.uid).collection('teams').doc(teamId),
      {
        'teamId': teamId,
        'teamName': teamName,
        'role': TeamRole.player.name,
        'joinedAt': FieldValue.serverTimestamp(),
      },
    );

    await batch.commit();
  }

  /// Stream týmů, ve kterých je aktuální uživatel členem (jakoukoliv rolí).
  Stream<QuerySnapshot<Map<String, dynamic>>> streamMyTeams() {
    return _db
        .collection('users')
        .doc(_uid)
        .collection('teams')
        .orderBy('joinedAt', descending: true)
        .snapshots();
  }

  /// Stream členů (rosteru) konkrétního týmu.
  Stream<QuerySnapshot<Map<String, dynamic>>> streamTeamMembers(
      String teamId) {
    return _db
        .collection('teams')
        .doc(teamId)
        .collection('members')
        .orderBy('joinedAt')
        .snapshots();
  }

  /// Stream dokumentu týmu – detail týmu z něj sleduje, kdo je správce.
  Stream<DocumentSnapshot<Map<String, dynamic>>> streamTeam(String teamId) {
    return _db.collection('teams').doc(teamId).snapshots();
  }

  /// Změní roli člena týmu (coach/player). Smí jen správce týmu.
  ///
  /// Správce nejde přepnout na hráče, aby tým nikdy nezůstal bez
  /// trenéra, který ho spravuje (viz i firestore.rules). Vedení může
  /// správce nejdřív předat jinému členovi ([transferOwnership]).
  ///
  /// Kromě záznamu v rosteru (teams/{teamId}/members/{uid}) se role
  /// aktualizuje i v indexu users/{uid}/teams/{teamId}, aby zůstala
  /// konzistentní i tam, odkud si daný uživatel čte přehled svých týmů.
  Future<void> updateMemberRole(String teamId, String uid, TeamRole role) async {
    if (role == TeamRole.player) {
      final teamDoc = await _db.collection('teams').doc(teamId).get();
      if (teamDoc.data()?['ownerUid'] == uid) {
        throw Exception('Správce týmu nelze změnit na hráče');
      }
    }

    final batch = _db.batch();
    batch.update(
      _db.collection('teams').doc(teamId).collection('members').doc(uid),
      {'role': role.name},
    );
    batch.update(
      _db.collection('users').doc(uid).collection('teams').doc(teamId),
      {'role': role.name},
    );
    await batch.commit();
  }

  /// Odebere člena z týmu. Hráče smí odebrat každý trenér, trenéra jen
  /// správce týmu.
  ///
  /// Správce takto odebrat nejde (viz i firestore.rules) – tým by přišel
  /// o toho, kdo ho spravuje. Správce může vedení předat jinému členovi
  /// ([transferOwnership]), nebo tým celý zrušit ([deleteTeam]).
  Future<void> removeMember(String teamId, String uid) async {
    final teamDoc = await _db.collection('teams').doc(teamId).get();
    if (teamDoc.data()?['ownerUid'] == uid) {
      throw Exception(
          'Správce nelze z týmu odebrat. Může předat vedení jinému členovi, nebo tým zrušit.');
    }

    final batch = _db.batch();
    batch.delete(
      _db.collection('teams').doc(teamId).collection('members').doc(uid),
    );
    batch.delete(
      _db.collection('users').doc(uid).collection('teams').doc(teamId),
    );
    await batch.commit();
  }

  /// Předá vedení týmu jinému členovi. Smí jen současný správce.
  ///
  /// Nový správce musí být trenér – hráče proto stejná dávka zároveň
  /// povýší (v rosteru i v indexu users/{uid}/teams). Původní správce
  /// zůstane trenérem.
  Future<void> transferOwnership(String teamId, String newOwnerUid) async {
    final teamRef = _db.collection('teams').doc(teamId);
    final member = await teamRef.collection('members').doc(newOwnerUid).get();
    if (!member.exists) {
      throw Exception('Vedení lze předat jen členovi týmu');
    }

    final batch = _db.batch();
    if (TeamRole.fromName(member.data()?['role'] as String?) != TeamRole.coach) {
      batch.update(member.reference, {'role': TeamRole.coach.name});
      batch.update(
        _db.collection('users').doc(newOwnerUid).collection('teams').doc(teamId),
        {'role': TeamRole.coach.name},
      );
    }
    batch.update(teamRef, {'ownerUid': newOwnerUid});
    await batch.commit();
  }

  /// Úplně zruší tým – smaže samotný tým, celý roster (a jeho index u
  /// každého člena), tréninky i pozvánkový kód. Smí jen správce týmu.
  /// Operace je nevratná.
  ///
  /// Podkolekce (members, trainings) Firestore se smazáním dokumentu týmu
  /// sám nesmaže, proto se mažou ručně ve stejné dávce.
  Future<void> deleteTeam(String teamId) async {
    final teamRef = _db.collection('teams').doc(teamId);
    final teamDoc = await teamRef.get();
    if (!teamDoc.exists) return;

    final code = teamDoc.data()!['code'] as String?;

    final membersSnap = await teamRef.collection('members').get();
    final trainingsSnap = await teamRef.collection('trainings').get();

    final batch = _db.batch();
    for (final trainingDoc in trainingsSnap.docs) {
      batch.delete(trainingDoc.reference);
    }
    for (final memberDoc in membersSnap.docs) {
      batch.delete(memberDoc.reference);
      batch.delete(
        _db.collection('users').doc(memberDoc.id).collection('teams').doc(teamId),
      );
    }
    if (code != null) {
      batch.delete(_db.collection('team_codes').doc(code));
    }
    batch.delete(teamRef);

    await batch.commit();
  }
}
