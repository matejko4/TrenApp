import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/team_service.dart';
import '../services/training_service.dart';
import '../utils/date_format.dart';
import '../utils/error_text.dart';
import '../widgets/account_actions.dart';
import '../widgets/app_bottom_bar.dart';
import '../widgets/common.dart';
import '../widgets/training_widgets.dart';
import '../widgets/week_calendar.dart';
import 'team_calendar_screen.dart';
import 'training_detail_screen.dart';

/// Detail týmu – vlevo týdenní kalendář s tečkami za tréninky, vpravo
/// soupiska rozdělená na trenéry a hráče, pod nimi nejbližší trénink.
///
/// Trenér zde může odebírat hráče. Správce týmu navíc mění role (přidává
/// a odebírá trenéry), předává vedení týmu a může tým celý zrušit.
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

class _TeamDetailScreenState extends State<TeamDetailScreen> {
  final _teamService = TeamService();
  final _trainingService = TrainingService();
  bool _deleting = false;
  String? _ownerUid;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _teamSub;
  final _rosterScroll = ScrollController();

  late final Stream<QuerySnapshot<Map<String, dynamic>>> _members =
      _teamService.streamTeamMembers(widget.teamId);
  late final Stream<List<Training>> _upcoming = _trainingService
      .streamTrainings(widget.teamId, isCoach: widget.isCoach, past: false);
  late DateTime _weekStart = startOfWeek(DateTime.now());
  late Stream<List<Training>> _weekTrainings = _streamWeek();

  @override
  void initState() {
    super.initState();
    // Správce týmu se sleduje živě – po předání vedení se obrazovce hned
    // změní nabízené akce (stejná oprávnění vynucuje firestore.rules).
    _teamSub = _teamService.streamTeam(widget.teamId).listen((doc) {
      if (!mounted) return;
      setState(() => _ownerUid = doc.data()?['ownerUid'] as String?);
    });
  }

  @override
  void dispose() {
    _teamSub?.cancel();
    _rosterScroll.dispose();
    super.dispose();
  }

  String get _myUid => FirebaseAuth.instance.currentUser?.uid ?? '';

  bool get _isOwner => _ownerUid != null && _ownerUid == _myUid;

  void _openCalendar() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TeamCalendarScreen(
          teamId: widget.teamId,
          teamName: widget.teamName,
          isCoach: widget.isCoach,
        ),
      ),
    );
  }

  Stream<List<Training>> _streamWeek() =>
      _trainingService.streamTrainingsBetween(
        widget.teamId,
        isCoach: widget.isCoach,
        from: _weekStart,
        to: DateTime(_weekStart.year, _weekStart.month, _weekStart.day + 7),
      );

  void _showWeek(int offset) {
    setState(() {
      _weekStart = DateTime(
          _weekStart.year, _weekStart.month, _weekStart.day + 7 * offset);
      _weekTrainings = _streamWeek();
    });
  }

  void _showError(Object e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(errorText(e))),
    );
  }

  Future<void> _changeRole(String uid, TeamRole currentRole) async {
    final newRole =
        currentRole == TeamRole.coach ? TeamRole.player : TeamRole.coach;
    try {
      await _teamService.updateMemberRole(widget.teamId, uid, newRole);
    } catch (e) {
      if (mounted) _showError(e);
    }
  }

  Future<void> _removeMember(String uid, String name) async {
    final confirmed = await confirmDialog(
      context,
      title: 'Odebrat člena',
      message: 'Opravdu chceš odebrat "$name" z týmu?',
      confirmLabel: 'Odebrat',
    );
    if (!confirmed) return;

    try {
      await _teamService.removeMember(widget.teamId, uid);
    } catch (e) {
      if (mounted) _showError(e);
    }
  }

  Future<void> _transferOwnership(String uid, String name, bool isPlayer) async {
    final confirmed = await confirmDialog(
      context,
      title: 'Předat vedení týmu',
      message: 'Správcem týmu "${widget.teamName}" se stane "$name"'
          '${isPlayer ? ' a zároveň se stane trenérem' : ''}. '
          'Ty zůstaneš trenérem, ale tým už nebudeš moct zrušit ani spravovat trenéry.',
      confirmLabel: 'Předat vedení',
    );
    if (!confirmed) return;

    try {
      await _teamService.transferOwnership(widget.teamId, uid);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Správcem týmu je teď $name')),
      );
    } catch (e) {
      if (mounted) _showError(e);
    }
  }

  Future<void> _deleteTeam() async {
    final confirmed = await confirmDialog(
      context,
      title: 'Zrušit tým',
      message: 'Opravdu chceš úplně zrušit tým "${widget.teamName}"? '
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
      _showError(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.teamName),
        actions: [
          if (widget.code != null)
            IconButton(
              icon: const Icon(Icons.copy),
              tooltip: 'Kopírovat kód týmu',
              onPressed: () {
                Clipboard.setData(ClipboardData(text: widget.code!));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Kód ${widget.code} zkopírován')),
                );
              },
            ),
          if (_isOwner)
            IconButton(
              icon: const Icon(Icons.delete_forever),
              tooltip: 'Zrušit tým',
              onPressed: _deleting ? null : _deleteTeam,
            ),
          const LogoutButton(),
        ],
      ),
      bottomNavigationBar: const AppBottomBar(current: AppTab.home),
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

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(width: 132, child: _buildWeekCalendar()),
                        const SizedBox(width: 12),
                        Expanded(child: _buildRoster(members)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildNextTraining(playerNames(members)),
                  ],
                );
              },
            ),
    );
  }

  Widget _buildWeekCalendar() {
    return Column(
      children: [
        StreamBuilder<List<Training>>(
          stream: _weekTrainings,
          builder: (context, snapshot) => WeekCalendar(
            weekStart: _weekStart,
            // Po přepnutí týdne nezobrazovat tečky z předchozího týdne.
            trainings: snapshot.connectionState == ConnectionState.waiting
                ? const []
                : snapshot.data ?? const [],
            onPreviousWeek: () => _showWeek(-1),
            onNextWeek: () => _showWeek(1),
            onDayTap: (_) => _openCalendar(),
          ),
        ),
        TextButton.icon(
          onPressed: _openCalendar,
          icon: const Icon(Icons.calendar_month, size: 18),
          label: const Text('Celý kalendář'),
        ),
      ],
    );
  }

  /// Soupiska rozdělená na trenéry (správce první) a hráče, obojí v pořadí,
  /// v jakém se připojili.
  ///
  /// Je v rámečku s pevnou maximální výškou (zhruba 5 členů) a další členy
  /// jde rolovat uvnitř něj – i u velkého týmu tak zůstane nejbližší trénink
  /// hned pod soupiskou.
  Widget _buildRoster(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> members) {
    bool isCoach(QueryDocumentSnapshot<Map<String, dynamic>> member) =>
        TeamRole.fromName(member.data()['role'] as String?) == TeamRole.coach;

    final coaches = [
      ...members.where((m) => isCoach(m) && m.id == _ownerUid),
      ...members.where((m) => isCoach(m) && m.id != _ownerUid),
    ];
    final players = members.where((m) => !isCoach(m)).toList();

    return Card.outlined(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 370),
        child: Scrollbar(
          controller: _rosterScroll,
          thumbVisibility: true,
          child: ListView(
            controller: _rosterScroll,
            // Menší soupiska zabere jen tolik místa, kolik potřebuje.
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(8, 8, 12, 0),
            children: [
              SectionTitle(
                'Trenéři (${coaches.length})',
                padding: const EdgeInsets.only(bottom: 4),
              ),
              for (final member in coaches) _buildMember(member),
              SectionTitle('Hráči (${players.length})'),
              if (players.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    widget.isCoach
                        ? 'Zatím žádní hráči. Pozvi je pomocí kódu týmu.'
                        : 'Zatím žádní hráči.',
                    style: const TextStyle(color: Colors.black54),
                  ),
                ),
              for (final member in players) _buildMember(member),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMember(QueryDocumentSnapshot<Map<String, dynamic>> member) {
    final data = member.data();
    final uid = member.id;
    final role = TeamRole.fromName(data['role'] as String?);
    final name = memberName(data);
    final isMe = uid == _myUid;
    final isOwnerRow = uid == _ownerUid;

    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.only(left: 8),
        horizontalTitleGap: 8,
        leading: RoleAvatar(isCoach: role == TeamRole.coach),
        title: Text(
          isMe ? '$name (já)' : name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: isOwnerRow ? const Text('Správce týmu') : null,
        trailing: _memberActions(
          uid: uid,
          name: name,
          role: role,
          isOwnerRow: isOwnerRow,
          isMe: isMe,
        ),
      ),
    );
  }

  /// Nejbližší trénink, který ještě neskončil – ze stejných tréninků, jaké
  /// uživatel vidí v kalendáři (hráč jen společné a svoje individuální).
  Widget _buildNextTraining(Map<String, String> players) {
    return StreamBuilder<List<Training>>(
      stream: _upcoming,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Text(errorText(snapshot.error!));
        }
        if (!snapshot.hasData) return const SizedBox.shrink();

        final now = DateTime.now();
        final next = snapshot.data!
            .where((t) =>
                t.startAt.isAfter(now) || (t.endAt?.isAfter(now) ?? false))
            .firstOrNull;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionTitle(next == null
                ? 'Nejbližší trénink'
                : 'Nejbližší trénink · ${formatDayHeader(next.startAt)}'),
            if (next == null)
              const Text(
                'Žádný naplánovaný trénink.',
                style: TextStyle(color: Colors.black54),
              )
            else
              TrainingCard(
                teamId: widget.teamId,
                training: next,
                isCoach: widget.isCoach,
                players: players,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TrainingDetailScreen(
                      teamId: widget.teamId,
                      trainingId: next.id,
                      isCoach: widget.isCoach,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  /// Akce u člena soupisky podle oprávnění (stejná vynucuje
  /// firestore.rules): správce mění role, předává vedení a odebírá
  /// kohokoli kromě sebe, trenér smí jen odebrat hráče. Správce je zamčený.
  Widget? _memberActions({
    required String uid,
    required String name,
    required TeamRole role,
    required bool isOwnerRow,
    required bool isMe,
  }) {
    if (!widget.isCoach) return null;
    if (isOwnerRow) {
      return const Tooltip(
        message: 'Správce týmu nelze změnit na hráče ani odebrat z týmu',
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Icon(Icons.lock_outline, color: Colors.black38),
        ),
      );
    }

    final isMemberCoach = role == TeamRole.coach;
    if (!_isOwner) {
      if (isMemberCoach || isMe) return null;
      return IconButton(
        icon: const Icon(Icons.person_remove),
        tooltip: 'Odebrat z týmu',
        onPressed: () => _removeMember(uid, name),
      );
    }

    return PopupMenuButton<_MemberAction>(
      tooltip: 'Možnosti člena',
      onSelected: (action) {
        switch (action) {
          case _MemberAction.toggleRole:
            _changeRole(uid, role);
          case _MemberAction.transfer:
            _transferOwnership(uid, name, !isMemberCoach);
          case _MemberAction.remove:
            _removeMember(uid, name);
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: _MemberAction.toggleRole,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              isMemberCoach ? Icons.arrow_downward : Icons.arrow_upward,
            ),
            title: Text(
              isMemberCoach ? 'Nastavit jako hráče' : 'Nastavit jako trenéra',
            ),
          ),
        ),
        const PopupMenuItem(
          value: _MemberAction.transfer,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.workspace_premium),
            title: Text('Předat vedení týmu'),
          ),
        ),
        const PopupMenuItem(
          value: _MemberAction.remove,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.person_remove),
            title: Text('Odebrat z týmu'),
          ),
        ),
      ],
    );
  }
}

enum _MemberAction { toggleRole, transfer, remove }
