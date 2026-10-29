import 'package:flutter/material.dart';

import '../services/auth_service.dart';

/// Odhlásí uživatele. Nejdřív zavře všechny obrazovky otevřené přes
/// Navigator.push, takže zůstane jen RootGate – ten po odhlášení sám
/// ukáže LoginScreen díky streamu authStateChanges.
Future<void> logOut(BuildContext context) async {
  Navigator.of(context).popUntil((route) => route.isFirst);
  await AuthService().logout();
}

class LogoutButton extends StatelessWidget {
  const LogoutButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.logout),
      tooltip: 'Odhlásit se',
      onPressed: () => logOut(context),
    );
  }
}
