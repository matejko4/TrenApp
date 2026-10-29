import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/team_service.dart';
import '../widgets/account_actions.dart';
import '../widgets/app_bottom_bar.dart';
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
            return Center(child: Text('Chyba: ${snapshot.error}'));
          }

          final teams = snapshot.data?.docs ?? [];
          if (teams.isEmpty) {
            return const Center(child: Text('Zatím nejsi v žádném týmu.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: teams.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final data = teams[index].data();
              final isCoach =
                  TeamRole.fromName(data['role'] as String?) == TeamRole.coach;
              final teamName = data['teamName'] as String? ?? 'Tým';
              final code = data['code'] as String?;

              return Card(
                elevation: 1,
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  leading: RoleAvatar(isCoach: isCoach),
                  title: Text(
                    teamName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    isCoach && code != null ? 'Trenér · Kód pro hráče: $code' : (isCoach ? 'Trenér' : 'Hráč'),
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
