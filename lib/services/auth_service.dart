import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // Registrace email/heslo - bez role
  Future<UserCredential> register(String email, String password) async {
    UserCredential cred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    await _db.collection('users').doc(cred.user!.uid).set({
      'email': email,
      'role': null,      // role se přiřadí až po připojení k týmu
      'teamId': null,    // tým zatím nemá
      'createdAt': DateTime.now(),
    });
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

    final doc = await _db.collection('users').doc(cred.user!.uid).get();
    if (!doc.exists) {
      await _db.collection('users').doc(cred.user!.uid).set({
        'email': cred.user!.email,
        'role': null,
        'teamId': null,
        'createdAt': DateTime.now(),
      });
    }

    return cred;
  }

  // Odhlášení
  Future<void> logout() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();
}