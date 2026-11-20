import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/auth_service.dart';
import '../services/team_service.dart';
import '../theme/app_theme.dart';
import '../utils/error_text.dart';
import '../utils/plural.dart';
import '../widgets/account_actions.dart';
import '../widgets/app_bottom_bar.dart';
import '../widgets/coming_soon.dart';
import '../widgets/common.dart';
import 'team_detail_screen.dart';
import 'team_setup_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final teamService = TeamService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('TrenApp'),
        actions: const [LogoutButton()],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: teamService.streamMyTeams(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text(errorText(snapshot.error!)));
          }

          final teams = snapshot.data?.docs ?? [];
          if (teams.isEmpty) {
            return const ComingSoon(
              icon: Icons.groups,
              title: 'Zatím nejsi v žádném týmu',
              message:
                  'Založ nový tým, nebo se připoj kódem od trenéra – '
                  'tlačítkem Přidat tým dole.',
            );
          }

          // Nahoře pozdrav, pod ním nadpis a karty týmů. Proto je položek
          // o 2 víc než týmů (index 0 = pozdrav, 1 = nadpis).
          return ListView.separated(
            // Spodní odsazení, aby poslední kartu nezakrylo plovoucí tlačítko.
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            itemCount: teams.length + 2,
            separatorBuilder: (_, index) =>
                SizedBox(height: index == 0 ? 20 : 12),
            itemBuilder: (context, index) {
              if (index == 0) return _Greeting(teamCount: teams.length);
              if (index == 1) {
                return const SectionTitle(
                  'Moje týmy',
                  padding: EdgeInsets.only(left: 4),
                );
              }
              index -= 2;
              final data = teams[index].data();
              final isCoach =
                  TeamRole.fromName(data['role'] as String?) == TeamRole.coach;
              final teamName = data['teamName'] as String? ?? 'Tým';
              final code = data['code'] as String?;

              return Card(
                margin: EdgeInsets.zero,
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  leading: RoleAvatar(isCoach: isCoach, size: 48),
                  title: Text(
                    teamName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 17,
                    ),
                  ),
                  subtitle: Text(
                    isCoach && code != null
                        ? 'Trenér · Kód pro hráče: $code'
                        : (isCoach ? 'Trenér' : 'Hráč'),
                  ),
                  trailing: isCoach && code != null
                      ? IconButton(
                          icon: const Icon(Icons.copy),
                          tooltip: 'Kopírovat kód týmu',
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: code));
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Kód $code zkopírován')),
                            );
                          },
                        )
                      : const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TeamDetailScreen(
                          teamId: teams[index].id,
                          teamName: teamName,
                          isCoach: isCoach,
                          code: isCoach ? code : null,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.group_add),
        label: const Text('Přidat tým'),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const TeamSetupScreen()),
        ),
      ),
      bottomNavigationBar: const AppBottomBar(current: AppTab.home),
    );
  }
}

/// Pozdrav nahoře na Domů – jméno uživatele a počet týmů na kartě
/// s barevným přechodem.
class _Greeting extends StatelessWidget {
  const _Greeting({required this.teamCount});

  final int teamCount;

  @override
  Widget build(BuildContext context) {
    final teamsLabel = czechCount(teamCount, 'tým', 'týmy', 'týmů');

    return GradientCard(
      child: StreamBuilder<String?>(
        stream: AuthService().myName,
        builder: (context, snapshot) {
          final name = snapshot.data ?? '';
          // Jen křestní jméno (první slovo) – „Ahoj, Jane“ by bylo moc.
          final firstName = name.trim().split(' ').first;
          return Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ahoj${firstName.isEmpty ? '' : ','}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      firstName.isEmpty ? 'vítej zpět' : firstName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        teamsLabel,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const IconBadge(icon: Icons.sports, size: 64),
            ],
          );
        },
      ),
    );
  }
}
