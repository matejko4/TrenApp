import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  /// Ověří a upraví jméno zadané uživatelem (ořízne a sloučí mezery).
  String _checkName(String name) {
    final trimmed = name.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (trimmed.isEmpty) {
      throw Exception('Zadej své jméno');
    }
    if (trimmed.length > 40) {
      throw Exception('Jméno může mít nejvýše 40 znaků');
    }
    return trimmed;
  }

  // Registrace email/heslo - jméno se ukládá do users/{uid} a v aplikaci se
  // zobrazuje místo e-mailu. Role se přiřadí až po vytvoření/připojení týmu
  // (viz TeamService), proto se zde neukládá.
  Future<UserCredential> register(
      String name, String email, String password) async {
    final trimmedName = _checkName(name);
    UserCredential cred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    await _db.collection('users').doc(cred.user!.uid).set({
      'name': trimmedName,
      'email': email,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await cred.user!.updateDisplayName(trimmedName);
    return cred;
  }

  // Přihlášení email/heslo
  Future<UserCredential> login(String email, String password) async {
    return await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  // Google přihlášení
  Future<UserCredential?> signInWithGoogle() async {
    final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
    if (googleUser == null) return null;

    final GoogleSignInAuthentication googleAuth =
        await googleUser.authentication;

    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    UserCredential cred = await _auth.signInWithCredential(credential);

    // Jméno se při prvním přihlášení převezme z Google účtu. Pokud ho
    // účet nemá, RootGate si ho od uživatele vyžádá (NameSetupScreen).
    final doc = await _db.collection('users').doc(cred.user!.uid).get();
    if (!doc.exists) {
      final googleName = cred.user!.displayName?.trim();
      await _db.collection('users').doc(cred.user!.uid).set({
        if (googleName != null && googleName.isNotEmpty) 'name': googleName,
        'email': cred.user!.email,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    return cred;
  }

  /// Nastaví/změní jméno aktuálního uživatele. Kromě users/{uid} se jméno
  /// propíše i do rosteru všech jeho týmů (teams/{teamId}/members/{uid}),
  /// protože soupiska týmu čte jména přímo odtud.
  Future<void> updateName(String name) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Uživatel není přihlášen');
    final trimmedName = _checkName(name);

    final teamsSnap =
        await _db.collection('users').doc(user.uid).collection('teams').get();

    final batch = _db.batch();
    batch.set(
      _db.collection('users').doc(user.uid),
      {'name': trimmedName, 'email': user.email},
      SetOptions(merge: true),
    );
    for (final teamDoc in teamsSnap.docs) {
      batch.update(
        _db
            .collection('teams')
            .doc(teamDoc.id)
            .collection('members')
            .doc(user.uid),
        {'name': trimmedName},
      );
    }
    await batch.commit();
    await user.updateDisplayName(trimmedName);
  }

  /// Zda má uživatel přihlášení e-mailem a heslem (Google účty heslo nemají).
  bool get hasPasswordLogin =>
      _auth.currentUser?.providerData
          .any((p) => p.providerId == EmailAuthProvider.PROVIDER_ID) ??
      false;

  /// Změní heslo. Firebase vyžaduje nedávné přihlášení, proto se uživatel
  /// nejdřív znovu ověří současným heslem.
  Future<void> changePassword(String currentPassword, String newPassword) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) {
      throw Exception('Uživatel není přihlášen');
    }
    if (newPassword.length < 6) {
      throw Exception('Nové heslo musí mít alespoň 6 znaků');
    }
    try {
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(newPassword);
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'wrong-password':
        case 'invalid-credential':
          throw Exception('Současné heslo není správné');
        case 'weak-password':
          throw Exception('Nové heslo je příliš slabé');
        case 'too-many-requests':
          throw Exception('Příliš mnoho pokusů, zkus to později');
        default:
          throw Exception('Změna hesla selhala (${e.code})');
      }
    }
  }

  Future<void> sendPasswordReset() async {
    final email = _auth.currentUser?.email;
    if (email == null) throw Exception('Účet nemá e-mail');
    await _auth.sendPasswordResetEmail(email: email);
  }

  // Odhlášení
  Future<void> logout() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();
  // Na rozdíl od authStateChanges hlásí i změnu jména (displayName).
  Stream<User?> get userChanges => _auth.userChanges();
}