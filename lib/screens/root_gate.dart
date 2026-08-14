import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'home_screen.dart';
import 'login_screen.dart';
import 'team_setup_screen.dart';

/// Kořenová obrazovka aplikace. Podle stavu přihlášení a členství
/// v týmech rozhoduje, co se má zobrazit:
///  - nepřihlášený uživatel      -> LoginScreen
///  - přihlášený bez týmu        -> TeamSetupScreen
///  - přihlášený s alespoň 1 týmem -> HomeScreen
class RootGate extends StatelessWidget {
  const RootGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const _LoadingScreen();
        }

        final user = authSnapshot.data;
        if (user == null) {
          return const LoginScreen();
        }

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('teams')
              .snapshots(),
          builder: (context, teamsSnapshot) {
            if (teamsSnapshot.connectionState == ConnectionState.waiting) {
              return const _LoadingScreen();
            }

            final hasTeams = (teamsSnapshot.data?.docs.length ?? 0) > 0;
            if (!hasTeams) {
              return const TeamSetupScreen();
            }
            return const HomeScreen();
          },
        );
      },
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.white,
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
