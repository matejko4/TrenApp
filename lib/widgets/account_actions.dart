import 'package:flutter/material.dart';

import '../screens/account_settings_screen.dart';
import '../services/auth_service.dart';

/// Tlačítka do AppBaru (nastavení účtu + odhlášení) pro obrazovky bez
/// spodní lišty. Obrazovky se spodní lištou (AppBottomBar) mají nastavení
/// účtu v liště, a do AppBaru proto dávají jen [LogoutButton].
/// Použití: `actions: [..., ...accountActions()]`.
List<Widget> accountActions() => const [
      AccountSettingsButton(),
      LogoutButton(),
    ];

class AccountSettingsButton extends StatelessWidget {
  const AccountSettingsButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.manage_accounts),
      tooltip: 'Nastavení účtu',
      onPressed: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const AccountSettingsScreen(showBottomBar: false),
        ),
      ),
    );
  }
}

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
