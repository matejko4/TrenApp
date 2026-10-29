import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/team_service.dart';
import '../utils/error_text.dart';
import '../widgets/account_actions.dart';
import '../widgets/app_bottom_bar.dart';
import '../widgets/common.dart';

/// Detail týmu – roster členů. Trenér zde může odebírat hráče. Správce
/// týmu navíc mění role (přidává a odebírá trenéry), předává vedení
/// týmu a může tým celý zrušit.
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
  bool _deleting = false;
  String? _ownerUid;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _teamSub;

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
    super.dispose();
  }

  String get _myUid => FirebaseAuth.instance.currentUser?.uid ?? '';

  bool get _isOwner => _ownerUid != null && _ownerUid == _myUid;

  Future<void> _changeRole(String uid, String currentRole) async {
    final newRole =
        currentRole == TeamRole.coach ? TeamRole.player : TeamRole.coach;
    try {
      await _teamService.updateMemberRole(widget.teamId, uid, newRole);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorText(e))),
      );
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
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorText(e))),
      );
    }
  }

  Future<void> _transferOwnership(String uid, String name, bool isPlayer) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Předat vedení týmu'),
        content: Text(
          'Správcem týmu "${widget.teamName}" se stane "$name"'
          '${isPlayer ? ' a zároveň se stane trenérem' : ''}. '
          'Ty zůstaneš trenérem, ale tým už nebudeš moct zrušit ani spravovat trenéry.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Zrušit'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Předat vedení'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _teamService.transferOwnership(widget.teamId, uid);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Správcem týmu je teď $name')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorText(e))),
      );
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
      bottomNavigationBar: AppBottomBar(
        current: AppTab.home,
        team: CurrentTeam(
          id: widget.teamId,
          name: widget.teamName,
          isCoach: widget.isCoach,
        ),
      ),
      body: _deleting
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _teamService.streamTeamMembers(widget.teamId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Chyba: ${snapshot.error}'));
                }

                final members = snapshot.data?.docs ?? [];
                if (members.isEmpty) {
                  return const Center(child: Text('Tým nemá žádné členy.'));
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: members.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final memberDoc = members[index];
                    final data = memberDoc.data();
                    final uid = memberDoc.id;
                    final role = data['role'] as String? ?? TeamRole.player;
                    // Starší členství nemusí mít jméno uložené – pak
                    // se zobrazí aspoň e-mail.
                    final name = data['name'] as String? ??
                        data['email'] as String? ??
                        uid;
                    final isMemberCoach = role == TeamRole.coach;
                    final isMe = uid == _myUid;
                    final isOwnerRow = uid == _ownerUid;

                    return Card(
                      elevation: 1,
                      child: ListTile(
                        leading: RoleAvatar(isCoach: isMemberCoach),
                        title: Text(isMe ? '$name (já)' : name),
                        subtitle: Text(
                          isOwnerRow
                              ? 'Správce týmu'
                              : (isMemberCoach ? 'Trenér' : 'Hráč'),
                        ),
                        trailing: _memberActions(
                          uid: uid,
                          name: name,
                          role: role,
                          isOwnerRow: isOwnerRow,
                          isMe: isMe,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }

  /// Akce u člena soupisky podle oprávnění (stejná vynucuje
  /// firestore.rules): správce mění role, předává vedení a odebírá
  /// kohokoli kromě sebe, trenér smí jen odebrat hráče. Správce je zamčený.
  Widget? _memberActions({
    required String uid,
    required String name,
    required String role,
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
