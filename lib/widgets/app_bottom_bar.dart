import 'package:flutter/material.dart';

import '../screens/account_settings_screen.dart';
import '../screens/notifications_screen.dart';
import '../screens/team_calendar_screen.dart';
import '../screens/team_setup_screen.dart';
import '../services/team_service.dart';

/// Položky spodní lišty – pořadí odpovídá pořadí tlačítek v liště.
enum AppTab { home, calendar, notifications, addTeam, account }

/// Tým, ve kterém se uživatel právě nachází. Podle něj se otevírá kalendář.
class CurrentTeam {
  const CurrentTeam({
    required this.id,
    required this.name,
    required this.isCoach,
  });

  final String id;
  final String name;

  /// Je uživatel v tomto týmu trenér? Trenér vidí v kalendáři všechny
  /// tréninky a může je zadávat.
  final bool isCoach;
}

/// Spodní navigační lišta pro obrazovky po přihlášení (uživatel s týmem).
///
/// Obrazovky otevřené z lišty se pushují s názvem route [_tabRouteName].
/// Před otevřením další záložky se všechny takové obrazovky nejdřív
/// zavřou, takže zásobník je vždy nejvýš Home → (detail týmu) → jedna
/// záložka a tlačítko Zpět vede tam, odkud uživatel do lišty vstoupil.
///
/// Kalendář se otevírá pro tým, ve kterém uživatel právě je ([team] na
/// detailu týmu). Ten se ukládá i do argumentů route otevřené záložky,
/// aby ho znala i lišta na ní. Bez týmu (z Home) si uživatel tým vybere.
class AppBottomBar extends StatelessWidget {
  const AppBottomBar({super.key, required this.current, this.team});

  final AppTab current;
  final CurrentTeam? team;

  static const _tabRouteName = 'app-bottom-tab';

  CurrentTeam? _currentTeam(BuildContext context) {
    if (team != null) return team;
    final settings = ModalRoute.of(context)?.settings;
    if (settings?.name == _tabRouteName) {
      return settings!.arguments as CurrentTeam?;
    }
    return null;
  }

  Future<void> _onSelected(BuildContext context, AppTab tab) async {
    final navigator = Navigator.of(context);
    if (tab == AppTab.home) {
      navigator.popUntil((route) => route.isFirst);
      return;
    }
    if (tab == current) return;

    final baseTeam = _currentTeam(context);
    final Widget screen;
    switch (tab) {
      case AppTab.calendar:
        final calendarTeam = baseTeam ?? await _pickTeam(context);
        if (calendarTeam == null || !context.mounted) return;
        screen = TeamCalendarScreen(
          teamId: calendarTeam.id,
          teamName: calendarTeam.name,
          isCoach: calendarTeam.isCoach,
        );
      case AppTab.notifications:
        screen = const NotificationsScreen();
      case AppTab.addTeam:
        screen = const TeamSetupScreen();
      case AppTab.account:
        screen = const AccountSettingsScreen();
      case AppTab.home:
        return; // Vyřešeno výše.
    }

    navigator.popUntil((route) => route.settings.name != _tabRouteName);
    navigator.push(
      MaterialPageRoute(
        settings: RouteSettings(name: _tabRouteName, arguments: baseTeam),
        builder: (_) => screen,
      ),
    );
  }

  /// Výběr týmu pro kalendář, když uživatel není v detailu žádného týmu.
  /// Má-li uživatel jediný tým, použije se rovnou bez ptaní.
  Future<CurrentTeam?> _pickTeam(BuildContext context) async {
    final snapshot = await TeamService().streamMyTeams().first;
    final teams = [
      for (final doc in snapshot.docs)
        CurrentTeam(
          id: doc.id,
          name: doc.data()['teamName'] as String? ?? 'Tým',
          isCoach: doc.data()['role'] == TeamRole.coach,
        ),
    ];
    if (teams.length == 1) return teams.first;
    if (teams.isEmpty || !context.mounted) return null;

    return showModalBottomSheet<CurrentTeam>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'Kalendář kterého týmu?',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            for (final team in teams)
              ListTile(
                leading: const Icon(Icons.groups),
                title: Text(team.name),
                onTap: () => Navigator.of(context).pop(team),
              ),
          ],
        ),
      ),
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
          icon: Icon(Icons.calendar_month_outlined),
          selectedIcon: Icon(Icons.calendar_month),
          label: 'Kalendář',
        ),
        NavigationDestination(
          icon: Icon(Icons.notifications_outlined),
          selectedIcon: Icon(Icons.notifications),
          label: 'Oznámení',
        ),
        NavigationDestination(
          icon: Icon(Icons.group_add_outlined),
          selectedIcon: Icon(Icons.group_add),
          label: 'Přidat tým',
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
