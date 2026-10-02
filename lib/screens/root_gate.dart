import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'home_screen.dart';
import 'login_screen.dart';
import 'name_setup_screen.dart';
import 'team_setup_screen.dart';

/// Kořenová obrazovka aplikace. Podle stavu přihlášení a členství
/// v týmech rozhoduje, co se má zobrazit:
///  - nepřihlášený uživatel      -> LoginScreen
///  - přihlášený bez jména       -> NameSetupScreen
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

        final userRef =
            FirebaseFirestore.instance.collection('users').doc(user.uid);

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: userRef.snapshots(),
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return const _LoadingScreen();
            }

            final name = userSnapshot.data?.data()?['name'] as String?;
            if (name == null || name.trim().isEmpty) {
              return const NameSetupScreen();
            }

            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: userRef.collection('teams').snapshots(),
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
