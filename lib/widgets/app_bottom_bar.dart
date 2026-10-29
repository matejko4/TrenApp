import 'package:flutter/material.dart';

import '../screens/account_settings_screen.dart';
import '../screens/notifications_screen.dart';

/// Položky spodní lišty – pořadí odpovídá pořadí tlačítek v liště.
enum AppTab { home, notifications, account }

/// Spodní navigační lišta pro obrazovky po přihlášení (uživatel s týmem).
///
/// Domů zavře všechny otevřené obrazovky až po úvodní. Oznámení a Účet se
/// otevírají vždy přímo nad úvodní obrazovkou, takže se při přepínání
/// obrazovky nehromadí a tlačítko Zpět z nich vede na Domů. Kalendář
/// a další obrazovky týmu se otevírají z detailu týmu, ne z lišty.
class AppBottomBar extends StatelessWidget {
  const AppBottomBar({super.key, required this.current});

  final AppTab current;

  void _onSelected(BuildContext context, AppTab tab) {
    final navigator = Navigator.of(context);
    if (tab == AppTab.home) {
      navigator.popUntil((route) => route.isFirst);
      return;
    }
    if (tab == current) return;

    final Widget screen = tab == AppTab.account
        ? const AccountSettingsScreen()
        : const NotificationsScreen();
    navigator.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => screen),
      (route) => route.isFirst,
    );
  }

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: current.index,
      onDestinationSelected: (index) =>
          _onSelected(context, AppTab.values[index]),
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home),
          label: 'Domů',
        ),
        NavigationDestination(
          icon: Icon(Icons.notifications_outlined),
          selectedIcon: Icon(Icons.notifications),
          label: 'Oznámení',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline),
          selectedIcon: Icon(Icons.person),
          label: 'Účet',
        ),
      ],
    );
  }
}
