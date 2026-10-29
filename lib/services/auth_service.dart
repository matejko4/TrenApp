import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
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

  /// Prázdný e-mail nebo heslo se ohlásí hned, bez dotazu na Firebase
  /// (ten by vrátil nesrozumitelnou chybu).
  void _checkFilled(String email, String password) {
    if (email.isEmpty) throw Exception('Zadej e-mail');
    if (password.isEmpty) throw Exception('Zadej heslo');
  }

  /// Česká hláška pro chybu z Firebase Auth podle jejího kódu.
  String _authErrorMessage(FirebaseAuthException e) => switch (e.code) {
        'invalid-credential' || 'wrong-password' || 'user-not-found' =>
          'Nesprávný e-mail nebo heslo',
        'invalid-email' => 'Neplatný tvar e-mailu',
        'email-already-in-use' =>
          'Účet s tímto e-mailem už existuje – přihlas se',
        'weak-password' => 'Heslo je příliš slabé – musí mít alespoň 6 znaků',
        'user-disabled' => 'Tento účet je zablokovaný',
        'too-many-requests' => 'Příliš mnoho pokusů, zkus to za chvíli',
        'network-request-failed' => 'Nejsi připojený k internetu',
        'popup-blocked' =>
          'Prohlížeč zablokoval okno pro přihlášení – povol vyskakovací okna',
        _ => 'Něco se nepovedlo (${e.code})',
      };

  // Registrace email/heslo - jméno se ukládá do users/{uid} a v aplikaci se
  // zobrazuje místo e-mailu. Role se přiřadí až po vytvoření/připojení týmu
  // (viz TeamService), proto se zde neukládá.
  Future<UserCredential> register(
      String name, String email, String password) async {
    final trimmedName = _checkName(name);
    _checkFilled(email, password);
    if (password.length < 6) {
      throw Exception('Heslo musí mít alespoň 6 znaků');
    }
    final UserCredential cred;
    try {
      cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw Exception(_authErrorMessage(e));
    }
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
    _checkFilled(email, password);
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw Exception(_authErrorMessage(e));
    }
  }

  // Google přihlášení. Vrací null, když uživatel okno s výběrem účtu zavřel.
  Future<UserCredential?> signInWithGoogle() async {
    final UserCredential? result;
    try {
      result =
          kIsWeb ? await _signInWithGoogleWeb() : await _signInWithGoogleApp();
    } on FirebaseAuthException catch (e) {
      throw Exception(_authErrorMessage(e));
    } on PlatformException catch (e) {
      // Chyby z okna Google účtu (balíček google_sign_in) mají vlastní kódy.
      if (e.code == GoogleSignIn.kSignInCanceledError) return null;
      if (e.code == GoogleSignIn.kNetworkError) {
        throw Exception('Nejsi připojený k internetu');
      }
      throw Exception('Přihlášení přes Google selhalo');
    }
    if (result == null) return null;
    final cred = result;

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

  /// Web: okno s Google účtem otevře přímo Firebase. Balíček google_sign_in
  /// by na webu potřeboval mít v Google Cloud Console povolenou přesnou
  /// adresu stránky (origin) – a `flutter run` ji spouští pokaždé na jiném
  /// portu. Firebase má `localhost` povolený automaticky.
  Future<UserCredential?> _signInWithGoogleWeb() async {
    try {
      return await _auth.signInWithPopup(GoogleAuthProvider());
    } on FirebaseAuthException catch (e) {
      // Zavřené okno není chyba – uživatel si to rozmyslel.
      if (e.code == 'popup-closed-by-user' ||
          e.code == 'cancelled-popup-request') {
        return null;
      }
      rethrow;
    }
  }

  /// Android: výběr Google účtu přes balíček google_sign_in, získaný
  /// účet se pak použije k přihlášení do Firebase.
  Future<UserCredential?> _signInWithGoogleApp() async {
    final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
    if (googleUser == null) return null; // okno zavřené bez výběru účtu

    final GoogleSignInAuthentication googleAuth =
        await googleUser.authentication;

    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    return _auth.signInWithCredential(credential);
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
      // Tady jde o ověření současného hesla, proto přesnější hláška než
      // obecné „Nesprávný e-mail nebo heslo“.
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        throw Exception('Současné heslo není správné');
      }
      throw Exception(_authErrorMessage(e));
    }
  }

  Future<void> sendPasswordReset() async {
    final email = _auth.currentUser?.email;
    if (email == null) throw Exception('Účet nemá e-mail');
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw Exception(_authErrorMessage(e));
    }
  }

  // Odhlášení
  Future<void> logout() async {
    // Na webu se google_sign_in nepoužívá (viz _signInWithGoogleWeb).
    if (!kIsWeb) await _googleSignIn.signOut();
    await _auth.signOut();
  }

  User? get currentUser => _auth.currentUser;
  // Na rozdíl od authStateChanges (používá RootGate) hlásí i změnu jména
  // (displayName).
  Stream<User?> get userChanges => _auth.userChanges();
}