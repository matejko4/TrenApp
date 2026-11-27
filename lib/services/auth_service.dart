import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../utils/error_text.dart';
import '../utils/firestore_write.dart';
import 'team_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  /// Ověří a upraví jméno zadané uživatelem (ořízne a sloučí mezery).
  String _checkName(String name) {
    final trimmed = name.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (trimmed.isEmpty) {
      throw AppException('Zadej své jméno');
    }
    if (trimmed.length > 40) {
      throw AppException('Jméno může mít nejvýše 40 znaků');
    }
    return trimmed;
  }

  /// Prázdný e-mail nebo heslo se ohlásí hned, bez dotazu na Firebase
  /// (ten by vrátil nesrozumitelnou chybu).
  void _checkFilled(String email, String password) {
    if (email.isEmpty) throw AppException('Zadej e-mail');
    if (password.isEmpty) throw AppException('Zadej heslo');
  }

  /// Česká hláška pro chybu z Firebase Auth podle jejího kódu.
  String _authErrorMessage(FirebaseAuthException e) => switch (e.code) {
    'invalid-credential' ||
    'wrong-password' ||
    'user-not-found' => 'Nesprávný e-mail nebo heslo',
    'invalid-email' => 'Neplatný tvar e-mailu',
    'email-already-in-use' => 'Účet s tímto e-mailem už existuje – přihlas se',
    'weak-password' => 'Heslo je příliš slabé – musí mít alespoň 6 znaků',
    'user-disabled' => 'Tento účet je zablokovaný',
    'too-many-requests' => 'Příliš mnoho pokusů, zkus to za chvíli',
    'network-request-failed' => offlineMessage,
    'popup-blocked' =>
      'Prohlížeč zablokoval okno pro přihlášení – povol vyskakovací okna',
    // Při znovuověření (smazání účtu) vybral uživatel jiný Google účet.
    'user-mismatch' => 'Vyber stejný Google účet, kterým jsi přihlášený',
    'requires-recent-login' =>
      'Z bezpečnostních důvodů se odhlas, znovu přihlas a zkus to znovu',
    _ => 'Něco se nepovedlo (${e.code})',
  };

  // Registrace email/heslo - jméno se ukládá do users/{uid} a v aplikaci se
  // zobrazuje místo e-mailu. Role se přiřadí až po vytvoření/připojení týmu
  // (viz TeamService), proto se zde neukládá.
  Future<UserCredential> register(
    String name,
    String email,
    String password,
  ) async {
    final trimmedName = _checkName(name);
    _checkFilled(email, password);
    if (password.length < 6) {
      throw AppException('Heslo musí mít alespoň 6 znaků');
    }
    final UserCredential cred;
    try {
      cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw AppException(_authErrorMessage(e));
    }
    // E-mail se sem nekopíruje – drží ho Firebase Authentication. Profil
    // users/{uid} čte jen uživatel sám (viz firestore.rules).
    await _db.collection('users').doc(cred.user!.uid).set({
      'name': trimmedName,
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
      throw AppException(_authErrorMessage(e));
    }
  }

  // Google přihlášení. Vrací null, když uživatel okno s výběrem účtu zavřel.
  Future<UserCredential?> signInWithGoogle() async {
    final UserCredential? result;
    try {
      result = kIsWeb
          ? await _signInWithGoogleWeb()
          : await _signInWithGoogleApp();
    } on FirebaseAuthException catch (e) {
      throw AppException(_authErrorMessage(e));
    } on PlatformException catch (e) {
      // Chyby z okna Google účtu (balíček google_sign_in) mají vlastní kódy.
      if (e.code == GoogleSignIn.kSignInCanceledError) return null;
      if (e.code == GoogleSignIn.kNetworkError) {
        throw AppException(offlineMessage);
      }
      throw AppException('Přihlášení přes Google selhalo');
    }
    if (result == null) return null;
    final cred = result;

    // Jméno se při prvním přihlášení převezme z Google účtu. Pokud ho
    // účet nemá, RootGate si ho od uživatele vyžádá (NameSetupScreen).
    // Stejně tak u jména delšího než 40 znaků – firestore.rules by ho
    // odmítly (stejný limit jako u ručně zadaného jména, viz _checkName).
    final doc = await _db.collection('users').doc(cred.user!.uid).get();
    if (!doc.exists) {
      final googleName = cred.user!.displayName?.trim().replaceAll(
        RegExp(r'\s+'),
        ' ',
      );
      final useGoogleName =
          googleName != null &&
          googleName.isNotEmpty &&
          googleName.length <= 40;
      await _db.collection('users').doc(cred.user!.uid).set({
        if (useGoogleName) 'name': googleName,
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
    final credential = await _pickGoogleAccount();
    if (credential == null) return null;
    return _auth.signInWithCredential(credential);
  }

  /// Android: okno s výběrem Google účtu (balíček google_sign_in). Vrací
  /// přihlašovací údaje pro Firebase, nebo null, když uživatel okno
  /// zavřel bez výběru účtu.
  Future<AuthCredential?> _pickGoogleAccount() async {
    final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
    if (googleUser == null) return null;

    final GoogleSignInAuthentication googleAuth =
        await googleUser.authentication;

    return GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
  }

  /// Nastaví/změní jméno aktuálního uživatele. Kromě users/{uid} se jméno
  /// propíše i do rosteru všech jeho týmů (teams/{teamId}/members/{uid}),
  /// protože soupiska týmu čte jména přímo odtud.
  ///
  /// Nečeká se, až změnu potvrdí server: bez internetu se jméno uloží
  /// v telefonu a odešle se samo po připojení. Vrací false, když změna
  /// zatím čeká v telefonu (viz waitForServer).
  Future<bool> updateName(String name) async {
    final user = _auth.currentUser;
    if (user == null) throw AppException(notSignedInMessage);
    final trimmedName = _checkName(name);

    final teamsSnap = await _db
        .collection('users')
        .doc(user.uid)
        .collection('teams')
        .get();

    final batch = _db.batch();
    batch.set(_db.collection('users').doc(user.uid), {
      'name': trimmedName,
    }, SetOptions(merge: true));
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
    // Jméno v účtu Firebase Auth je jen doplněk (aplikace čte jméno
    // z users/{uid}) a bez internetu se nezmění – proto se na něj nečeká.
    unawaited(
      user
          .updateDisplayName(trimmedName)
          .catchError(
            (Object e) =>
                debugPrint('Jméno v účtu Firebase Auth se nezměnilo: $e'),
          ),
    );
    return waitForServer(batch.commit());
  }

  /// Jméno přihlášeného uživatele z users/{uid}. Na rozdíl od jména v účtu
  /// Firebase Auth se změní hned, i bez internetu.
  Stream<String?> get myName => _db
      .collection('users')
      .doc(_auth.currentUser!.uid)
      .snapshots()
      .map((doc) => doc.data()?['name'] as String?);

  /// Zda má uživatel přihlášení e-mailem a heslem (Google účty heslo nemají).
  bool get hasPasswordLogin =>
      _auth.currentUser?.providerData.any(
        (p) => p.providerId == EmailAuthProvider.PROVIDER_ID,
      ) ??
      false;

  /// Změní heslo. Firebase vyžaduje nedávné přihlášení, proto se uživatel
  /// nejdřív znovu ověří současným heslem. [confirmPassword] je nové heslo
  /// zadané podruhé – musí se shodovat s [newPassword].
  Future<void> changePassword(
    String currentPassword,
    String newPassword,
    String confirmPassword,
  ) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) {
      throw AppException(notSignedInMessage);
    }
    if (newPassword != confirmPassword) {
      throw AppException('Nová hesla se neshodují');
    }
    if (newPassword.length < 6) {
      throw AppException('Nové heslo musí mít alespoň 6 znaků');
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
        throw AppException('Současné heslo není správné');
      }
      throw AppException(_authErrorMessage(e));
    }
  }

  /// Pošle odkaz pro obnovení hesla na [email] – na přihlašovací obrazovce
  /// ten, který uživatel zadal, v nastavení účtu (bez parametru) e-mail
  /// přihlášeného uživatele.
  Future<void> sendPasswordReset([String? email]) async {
    final address = (email ?? _auth.currentUser?.email ?? '').trim();
    if (address.isEmpty) throw AppException('Zadej e-mail');
    try {
      await _auth.sendPasswordResetEmail(email: address);
    } on FirebaseAuthException catch (e) {
      throw AppException(_authErrorMessage(e));
    }
  }

  /// Smaže účet přihlášeného uživatele i jeho data. Vrací false, když
  /// uživatel zavřel okno Google účtu – pak se nic nesmazalo.
  ///
  /// Postup:
  ///  1. Uživatel nesmí spravovat žádný tým (TeamService.ownedTeams) –
  ///     tým by zůstal bez správce. Hlídají to i firestore.rules.
  ///  2. Znovuověření – heslem ([password]), nebo výběrem Google účtu.
  ///     Firebase smazání účtu dovolí jen po nedávném přihlášení a zároveň
  ///     tak účet nesmaže nikdo, kdo jen vezme do ruky odemčený telefon.
  ///  3. Odchod ze všech týmů (TeamService.leaveAllTeams) a smazání
  ///     profilu users/{uid}.
  ///  4. Smazání účtu ve Firebase Authentication – tím se uživatel
  ///     zároveň odhlásí a RootGate ukáže přihlašovací obrazovku.
  ///
  /// Data se mažou před účtem, protože bez účtu by k nim uživatel už
  /// neměl oprávnění. Díky kroku 2 krok 4 neselže na „vyžaduje nedávné
  /// přihlášení“. Všechno se čte přímo ze serveru, takže bez internetu
  /// to skončí chybou dřív, než se cokoli smaže.
  Future<bool> deleteAccount({String password = ''}) async {
    final user = _auth.currentUser;
    if (user == null) throw AppException(notSignedInMessage);
    final usesPassword = hasPasswordLogin;
    if (usesPassword && password.isEmpty) {
      throw AppException('Zadej heslo');
    }

    final teamService = TeamService();
    if ((await teamService.ownedTeams()).isNotEmpty) {
      throw AppException('Nejdřív předej vedení svých týmů, nebo je zruš');
    }

    try {
      if (usesPassword) {
        await user.reauthenticateWithCredential(
          EmailAuthProvider.credential(email: user.email!, password: password),
        );
      } else if (!await _reauthenticateWithGoogle(user)) {
        return false;
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        throw AppException('Heslo není správné');
      }
      throw AppException(_authErrorMessage(e));
    } on PlatformException catch (e) {
      if (e.code == GoogleSignIn.kSignInCanceledError) return false;
      if (e.code == GoogleSignIn.kNetworkError) {
        throw AppException(offlineMessage);
      }
      throw AppException('Ověření přes Google selhalo');
    }

    await teamService.leaveAllTeams();
    await _db.collection('users').doc(user.uid).delete();
    try {
      await user.delete();
    } on FirebaseAuthException catch (e) {
      throw AppException(_authErrorMessage(e));
    }
    // Ať příští přihlášení přes Google znovu nabídne výběr účtu. Účet už
    // je smazaný, takže případná chyba tady nevadí.
    if (!kIsWeb) await _googleSignIn.signOut().catchError((Object _) => null);
    return true;
  }

  /// Znovuověření Google účtem (před smazáním účtu) – stejné okno jako při
  /// přihlášení. Vrací false, když ho uživatel zavřel.
  Future<bool> _reauthenticateWithGoogle(User user) async {
    if (kIsWeb) {
      try {
        await user.reauthenticateWithPopup(GoogleAuthProvider());
        return true;
      } on FirebaseAuthException catch (e) {
        if (e.code == 'popup-closed-by-user' ||
            e.code == 'cancelled-popup-request') {
          return false;
        }
        rethrow;
      }
    }
    // Bez odhlášení by google_sign_in okno vůbec neukázal a rovnou vrátil
    // naposledy vybraný účet – potvrzení by pak nic neznamenalo.
    await _googleSignIn.signOut();
    final credential = await _pickGoogleAccount();
    if (credential == null) return false;
    await user.reauthenticateWithCredential(credential);
    return true;
  }

  // Odhlášení
  Future<void> logout() async {
    // Na webu se google_sign_in nepoužívá (viz _signInWithGoogleWeb).
    if (!kIsWeb) await _googleSignIn.signOut();
    await _auth.signOut();
  }

  User? get currentUser => _auth.currentUser;
}
