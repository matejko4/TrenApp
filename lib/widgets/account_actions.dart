import 'package:flutter/material.dart';

import '../screens/account_settings_screen.dart';
import '../screens/login_screen.dart';
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

class LogoutButton extends StatelessWidget {
  const LogoutButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.logout),
      tooltip: 'Odhlásit se',
      onPressed: () async {
        await AuthService().logout();
        if (context.mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const LoginScreen()),
            (route) => false,
          );
        }
      },
    );
  }
}
