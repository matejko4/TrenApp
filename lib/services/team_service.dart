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

  /// Vytvoří nový tým. Zakladatel se stává trenérem tohoto týmu.
  /// Vrací id nově vytvořeného týmu.
  Future<String> createTeam(String name) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw Exception('Zadej název týmu');
    }

    final user = _auth.currentUser;
    if (user == null) throw Exception('Uživatel není přihlášen');

    final code = await _generateUniqueCode();
    final teamRef = _db.collection('teams').doc();

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
}
