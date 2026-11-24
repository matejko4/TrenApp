import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/team_service.dart';
import '../theme/app_theme.dart';
import '../utils/error_text.dart';
import '../utils/plural.dart';
import '../widgets/account_actions.dart';
import '../widgets/app_bottom_bar.dart';
import '../widgets/common.dart';
import 'team_calendar_tab.dart';
import 'team_overview_tab.dart';
import 'team_roster_tab.dart';
import 'training_form_screen.dart';

/// Detail týmu – nahoře přepínač tří záložek:
///  - Přehled  – barevná hlavička (role, počet členů, kód týmu), nejbližší
///               akce, čísla za tento týden a další akce
///               (team_overview_tab.dart),
///  - Kalendář – týdenní pás a časová osa akcí (team_calendar_tab.dart),
///  - Tým      – soupiska a správa členů (team_roster_tab.dart).
///
/// Trenér přidává akce plovoucím tlačítkem „Přidat“ na Přehledu
/// a v Kalendáři. Správce týmu může tým zrušit v menu ⋮ vpravo nahoře.
class TeamDetailScreen extends StatefulWidget {
  const TeamDetailScreen({
    super.key,
    required this.teamId,
    required this.teamName,
    required this.isCoach,
    this.code,
  });

  final String teamId;
  final String teamName;
  final bool isCoach;
  final String? code;

  @override
  State<TeamDetailScreen> createState() => _TeamDetailScreenState();
}

// SingleTickerProviderStateMixin dodává „hodiny“ pro animaci přepínání
// záložek (TabController ji potřebuje).
class _TeamDetailScreenState extends State<TeamDetailScreen>
    with SingleTickerProviderStateMixin {
  final _teamService = TeamService();
  late final TabController _tabs = TabController(length: 3, vsync: this);
  bool _deleting = false;
  String? _ownerUid;
  // Kód týmu z teams/{teamId} – vidí ho každý trenér a po vytvoření
  // nového kódu se hned změní. Než dorazí, ukazuje se kód z Domů.
  late String? _code = widget.code;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _teamSub;

  late final Stream<QuerySnapshot<Map<String, dynamic>>> _members = _teamService
      .streamTeamMembers(widget.teamId);

  @override
  void initState() {
    super.initState();
    // Po přepnutí záložky překreslit – tlačítko Přidat se na záložce Tým
    // schová.
    _tabs.addListener(() => setState(() {}));
    // Správce týmu se sleduje živě – po předání vedení se obrazovce hned
    // změní nabízené akce (stejná oprávnění vynucuje firestore.rules).
    _teamSub = _teamService.streamTeam(widget.teamId).listen((doc) {
      if (!mounted) return;
      setState(() {
        _ownerUid = doc.data()?['ownerUid'] as String?;
        _code = doc.data()?['code'] as String? ?? _code;
      });
    });
  }

  @override
  void dispose() {
    _teamSub?.cancel();
    _tabs.dispose();
    super.dispose();
  }

  bool get _isOwner =>
      _ownerUid != null && _ownerUid == FirebaseAuth.instance.currentUser?.uid;

  /// Pozvánkový kód se ukazuje jen trenérům.
  String? get _shownCode => widget.isCoach ? _code : null;

  void _addEvent() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TrainingFormScreen(teamId: widget.teamId),
      ),
    );
  }

  /// Správce vymění kód týmu za nový – např. když kód unikl, nebo se
  /// odebraný hráč nemá mít jak vrátit. Nový kód se hned ukáže v hlavičce
  /// (přijde přes _teamSub).
  Future<void> _changeCode() async {
    final confirmed = await confirmDialog(
      context,
      title: 'Nový kód týmu',
      message:
          'Současný kód přestane platit – kdo ho zná, už se s ním do týmu '
          'nepřipojí (ani odebraný hráč). Členové týmu v něm zůstanou. '
          'Novým hráčům pak pošli nový kód.',
      confirmLabel: 'Vytvořit nový kód',
    );
    if (!confirmed || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      final code = await _teamService.changeCode(widget.teamId);
      messenger.showSnackBar(SnackBar(content: Text('Nový kód týmu: $code')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorText(e))));
    }
  }

  Future<void> _deleteTeam() async {
    final confirmed = await confirmDialog(
      context,
      title: 'Zrušit tým',
      message:
          'Opravdu chceš úplně zrušit tým "${widget.teamName}"? '
          'Smažou se všichni členové a tato akce je nevratná.',
      confirmLabel: 'Zrušit tým',
    );
    if (!confirmed) return;

    setState(() => _deleting = true);
    try {
      await _teamService.deleteTeam(widget.teamId);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _deleting = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(errorText(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    // Tlačítko Přidat má trenér na Přehledu a v Kalendáři (ne na záložce Tým).
    final showAdd = widget.isCoach && !_deleting && _tabs.index != 2;

    return Scaffold(
      appBar: AppBar(title: Text(widget.teamName), actions: [_buildMenu()]),
      bottomNavigationBar: const AppBottomBar(current: AppTab.home),
      floatingActionButton: showAdd
          ? FloatingActionButton.extended(
              icon: const Icon(Icons.add),
              label: const Text('Přidat'),
              onPressed: _addEvent,
            )
          : null,
      body: _deleting
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _members,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text(errorText(snapshot.error!)));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final members = snapshot.data!.docs;
                final coachCount = members
                    .where(
                      (m) =>
                          TeamRole.fromName(m.data()['role'] as String?) ==
                          TeamRole.coach,
                    )
                    .length;

                // Přepínač záložek je pevně nahoře, pod ním obsah vybrané
                // záložky (TabBarView – jde i přejet prstem do strany).
                return Column(
                  children: [
                    _TabSwitcher(controller: _tabs),
                    Expanded(
                      child: TabBarView(
                        controller: _tabs,
                        children: [
                          TeamOverviewTab(
                            teamId: widget.teamId,
                            isCoach: widget.isCoach,
                            players: playerNames(members),
                            onOpenCalendar: () => _tabs.animateTo(1),
                            header: _TeamHeader(
                              isCoach: widget.isCoach,
                              isOwner: _isOwner,
                              coachCount: coachCount,
                              playerCount: members.length - coachCount,
                              code: _shownCode,
                            ),
                          ),
                          TeamCalendarTab(
                            teamId: widget.teamId,
                            isCoach: widget.isCoach,
                            players: playerNames(members),
                          ),
                          TeamRosterTab(
                            teamId: widget.teamId,
                            teamName: widget.teamName,
                            isCoach: widget.isCoach,
                            ownerUid: _ownerUid,
                            members: members,
                            code: _shownCode,
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }

  /// Menu ⋮ vpravo nahoře – kopírovat kód (trenér), nový kód a zrušit tým
  /// (správce) a odhlásit se.
  Widget _buildMenu() {
    final code = _shownCode;
    final error = Theme.of(context).colorScheme.error;
    return PopupMenuButton<_TeamAction>(
      tooltip: 'Další možnosti',
      onSelected: (action) {
        switch (action) {
          case _TeamAction.copyCode:
            copyTeamCode(context, code!);
          case _TeamAction.newCode:
            _changeCode();
          case _TeamAction.delete:
            _deleteTeam();
          case _TeamAction.logout:
            logOut(context);
        }
      },
      itemBuilder: (context) => [
        if (code != null)
          const PopupMenuItem(
            value: _TeamAction.copyCode,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.copy),
              title: Text('Kopírovat kód týmu'),
            ),
          ),
        if (_isOwner)
          const PopupMenuItem(
            value: _TeamAction.newCode,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.autorenew),
              title: Text('Nový kód týmu'),
            ),
          ),
        if (_isOwner)
          PopupMenuItem(
            value: _TeamAction.delete,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.delete_forever, color: error),
              title: Text('Zrušit tým', style: TextStyle(color: error)),
            ),
          ),
        const PopupMenuItem(
          value: _TeamAction.logout,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.logout),
            title: Text('Odhlásit se'),
          ),
        ),
      ],
    );
  }
}

enum _TeamAction { copyCode, newCode, delete, logout }

/// Barevná hlavička týmu – role uživatele, počet trenérů a hráčů a u
/// trenéra pozvánkový kód (klepnutím se zkopíruje).
class _TeamHeader extends StatelessWidget {
  const _TeamHeader({
    required this.isCoach,
    required this.isOwner,
    required this.coachCount,
    required this.playerCount,
    required this.code,
  });

  final bool isCoach;
  final bool isOwner;
  final int coachCount;
  final int playerCount;
  final String? code;

  @override
  Widget build(BuildContext context) {
    final code = this.code;
    final role = isOwner ? 'Správce týmu' : (isCoach ? 'Trenér' : 'Hráč');

    return GradientCard(
      gradient: isCoach ? AppColors.brandGradient : AppColors.playerGradient,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconBadge(
                icon: isCoach ? Icons.sports : Icons.directions_run,
                size: 52,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      role,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      '${czechCount(playerCount, 'hráč', 'hráči', 'hráčů')}'
                      ' · '
                      '${czechCount(coachCount, 'trenér', 'trenéři', 'trenérů')}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (code != null) ...[
            const SizedBox(height: 14),
            Material(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(999),
              child: InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: () => copyTeamCode(context, code),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Kód pro hráče: ',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                      Text(
                        code,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.copy, size: 16, color: Colors.white),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Přepínač záložek Přehled / Kalendář / Tým.
class _TabSwitcher extends StatelessWidget {
  const _TabSwitcher({required this.controller});

  final TabController controller;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.outlineVariant),
        ),
        child: TabBar(
          controller: controller,
          tabs: const [
            Tab(height: 36, text: 'Přehled'),
            Tab(height: 36, text: 'Kalendář'),
            Tab(height: 36, text: 'Tým'),
          ],
        ),
      ),
    );
  }
}
