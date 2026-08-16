import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Role uživatele v rámci konkrétního týmu.
class TeamRole {
  static const coach = 'coach';
  static const player = 'player';
}

/// Stará se o vytváření týmů, připojování k týmům kódem a čtení
/// týmů, ve kterých je aktuální uživatel členem.
///
/// Datový model:
/// - teams/{teamId}                      – základní údaje o týmu (název, kód, zakladatel)
/// - teams/{teamId}/members/{uid}        – roster týmu (role, e-mail, kdy se přidal)
/// - users/{uid}/teams/{teamId}          – rychlý přehled týmů daného uživatele a jeho role v nich
/// - team_codes/{code}                   – mapování pozvánkového kódu na tým (viz níže)
/// - team_names/{normalizedName}         – hlídání unikátnosti názvu týmu (viz níže)
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
///
/// team_names funguje na stejném principu a navíc vynucuje unikátnost
/// názvu: doc id je normalizovaný název (trim + lowercase + sloučené
/// mezery) a bezpečnostní pravidla na něj povolují jen `create`, ne
/// `update`. Když už název existuje, druhý pokus o zápis Firestore
/// vyhodnotí jako update existujícího dokumentu, který pravidla zakazují
/// – to spolehlivě zabrání duplicitám i při souběžném vytváření dvou
/// týmů se stejným názvem ve stejný okamžik.
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
    return List.generate(6, (_) => chars[rand.nextInt(chars.length)]).join();
  }

  Future<String> _generateUniqueCode() async {
    for (var attempt = 0; attempt < 10; attempt++) {
      final code = _generateCode();
      final existing = await _db.collection('team_codes').doc(code).get();
      if (!existing.exists) return code;
    }
    throw Exception('Nepodařilo se vygenerovat kód týmu, zkus to znovu');
  }

  /// Normalizovaný klíč pro kontrolu unikátnosti názvu: bez ohledu na
  /// velikost písmen a na duplicitní/okrajové mezery.
  String _normalizeName(String name) {
    return name.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  /// Vytvoří nový tým. Zakladatel se stává trenérem tohoto týmu.
  /// Vrací id nově vytvořeného týmu.
  ///
  /// Vyhodí Exception, pokud už tým se stejným názvem existuje (viz
  /// team_names v komentáři u třídy).
  Future<String> createTeam(String name) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw Exception('Zadej název týmu');
    }
    if (trimmedName.contains('/')) {
      throw Exception('Název týmu nesmí obsahovat znak "/"');
    }

    final user = _auth.currentUser;
    if (user == null) throw Exception('Uživatel není přihlášen');

    final teamRef = _db.collection('teams').doc();
    final nameRef = _db.collection('team_names').doc(_normalizeName(trimmedName));

    // Zamluvení unikátního názvu musí proběhnout jako první – teprve když
    // se to podaří, má smysl generovat kód a zakládat samotný tým.
    try {
      await nameRef.set({
        'teamId': teamRef.id,
        'createdBy': user.uid,
      });
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw Exception(
            'Tým s názvem "$trimmedName" už existuje, zvol prosím jiný název');
      }
      rethrow;
    }

    final code = await _generateUniqueCode();

    // Tým se zapisuje samostatně a až poté (v dávce) členství a index u
    // uživatele. Bezpečnostní pravidla pro vznik "coach" členství ověřují
    // teams/{teamId}.createdBy, což vyžaduje, aby dokument týmu už v době
    // vyhodnocení pravidel existoval – v rámci jedné dávky by ještě
    // neexistoval, proto dva kroky místo jedné velké dávky.
    await teamRef.set({
      'name': trimmedName,
      'code': code,
      'createdBy': user.uid,
      'createdAt': FieldValue.serverTimestamp(),
    });

    final batch = _db.batch();

    batch.set(_db.collection('team_codes').doc(code), {
      'teamId': teamRef.id,
      'teamName': trimmedName,
    });

    batch.set(teamRef.collection('members').doc(user.uid), {
      'uid': user.uid,
      'email': user.email,
      'role': TeamRole.coach,
      'joinedAt': FieldValue.serverTimestamp(),
    });

    batch.set(
      _db.collection('users').doc(user.uid).collection('teams').doc(teamRef.id),
      {
        'teamId': teamRef.id,
        'teamName': trimmedName,
        'role': TeamRole.coach,
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

    final batch = _db.batch();

    batch.set(memberRef, {
      'uid': user.uid,
      'email': user.email,
      'role': TeamRole.player,
      'joinedAt': FieldValue.serverTimestamp(),
    });

    batch.set(
      _db.collection('users').doc(user.uid).collection('teams').doc(teamId),
      {
        'teamId': teamId,
        'teamName': teamName,
        'role': TeamRole.player,
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

  Future<DocumentSnapshot<Map<String, dynamic>>> getTeam(String teamId) {
    return _db.collection('teams').doc(teamId).get();
  }

  /// Změní roli člena týmu (coach/player). Smí jen trenér týmu.
  ///
  /// Zakladatel týmu (teams/{teamId}.createdBy) nejde přepnout na hráče –
  /// ani sám sebe, ani jiným trenérem – aby tým nikdy nezůstal bez
  /// trenéra, kterého by šlo znovu upravovat (viz i firestore.rules).
  ///
  /// Kromě záznamu v rosteru (teams/{teamId}/members/{uid}) se role
  /// aktualizuje i v indexu users/{uid}/teams/{teamId}, aby zůstala
  /// konzistentní i tam, odkud si daný uživatel čte přehled svých týmů.
  Future<void> updateMemberRole(String teamId, String uid, String role) async {
    if (role != TeamRole.coach && role != TeamRole.player) {
      throw Exception('Neplatná role');
    }

    if (role == TeamRole.player) {
      final teamDoc = await _db.collection('teams').doc(teamId).get();
      final createdBy = teamDoc.data()?['createdBy'] as String?;
      if (createdBy == uid) {
        throw Exception('Zakladatele týmu nelze změnit na hráče');
      }
    }

    final batch = _db.batch();
    batch.update(
      _db.collection('teams').doc(teamId).collection('members').doc(uid),
      {'role': role},
    );
    batch.update(
      _db.collection('users').doc(uid).collection('teams').doc(teamId),
      {'role': role},
    );
    await batch.commit();
  }

  /// Odebere člena z týmu. Smí jen trenér týmu.
  ///
  /// Zakladatele týmu takto odebrat nejde (viz i firestore.rules) – tým
  /// by tak mohl přijít o posledního/jediného trenéra. Jediný způsob, jak
  /// se zakladatele „zbavit“, je zrušit tým celý (viz [deleteTeam]).
  Future<void> removeMember(String teamId, String uid) async {
    final teamDoc = await _db.collection('teams').doc(teamId).get();
    final createdBy = teamDoc.data()?['createdBy'] as String?;
    if (createdBy == uid) {
      throw Exception('Zakladatele nelze z týmu odebrat, tým lze pouze celý zrušit');
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

  /// Úplně zruší tým – smaže samotný tým, celý roster (a jeho index u
  /// každého člena), pozvánkový kód i zamluvený název týmu. Smí jen
  /// trenér týmu. Operace je nevratná.
  Future<void> deleteTeam(String teamId) async {
    final teamRef = _db.collection('teams').doc(teamId);
    final teamDoc = await teamRef.get();
    if (!teamDoc.exists) return;

    final data = teamDoc.data()!;
    final code = data['code'] as String?;
    final name = data['name'] as String?;

    final membersSnap = await teamRef.collection('members').get();

    final batch = _db.batch();
    for (final memberDoc in membersSnap.docs) {
      batch.delete(memberDoc.reference);
      batch.delete(
        _db.collection('users').doc(memberDoc.id).collection('teams').doc(teamId),
      );
    }
    if (code != null) {
      batch.delete(_db.collection('team_codes').doc(code));
    }
    if (name != null) {
      batch.delete(_db.collection('team_names').doc(_normalizeName(name)));
    }
    batch.delete(teamRef);

    await batch.commit();
  }
}
