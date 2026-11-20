import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/team_service.dart';
import '../theme/app_theme.dart';
import '../utils/error_text.dart';
import '../widgets/common.dart';

/// Záložka „Tým“ v detailu týmu – soupiska rozdělená na trenéry (správce
/// první) a hráče, obojí v pořadí, v jakém se připojili. Trenér má nahoře
/// kartu s pozvánkovým kódem.
///
/// Akce u členů podle oprávnění (stejná vynucuje firestore.rules): správce
/// mění role, předává vedení a odebírá kohokoli kromě sebe, trenér smí jen
/// odebrat hráče. Správce je zamčený.
class TeamRosterTab extends StatelessWidget {
  const TeamRosterTab({
    super.key,
    required this.teamId,
    required this.teamName,
    required this.isCoach,
    required this.ownerUid,
    required this.members,
    this.code,
  });

  final String teamId;
  final String teamName;
  final bool isCoach;

  /// Správce týmu (null, dokud se nenačte dokument týmu).
  final String? ownerUid;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> members;

  /// Pozvánkový kód – jen pro trenéra, hráč ho nevidí.
  final String? code;

  String get _myUid => FirebaseAuth.instance.currentUser?.uid ?? '';

  bool get _isOwner => ownerUid != null && ownerUid == _myUid;

  @override
  Widget build(BuildContext context) {
    bool isMemberCoach(QueryDocumentSnapshot<Map<String, dynamic>> member) =>
        TeamRole.fromName(member.data()['role'] as String?) == TeamRole.coach;

    final coaches = [
      ...members.where((m) => isMemberCoach(m) && m.id == ownerUid),
      ...members.where((m) => isMemberCoach(m) && m.id != ownerUid),
    ];
    final players = members.where((m) => !isMemberCoach(m)).toList();
    final code = this.code;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        if (code != null) ...[
          _InviteCard(code: code),
          const SizedBox(height: 8),
        ],
        SectionTitle('Trenéři (${coaches.length})'),
        for (final member in coaches) _buildMember(context, member),
        SectionTitle('Hráči (${players.length})'),
        if (players.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              isCoach
                  ? 'Zatím žádní hráči. Pozvi je pomocí kódu týmu.'
                  : 'Zatím žádní hráči.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        for (final member in players) _buildMember(context, member),
      ],
    );
  }

  Widget _buildMember(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> member,
  ) {
    final data = member.data();
    final uid = member.id;
    final role = TeamRole.fromName(data['role'] as String?);
    final name = memberName(data);
    final isMe = uid == _myUid;
    final isOwnerRow = uid == ownerUid;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        contentPadding: const EdgeInsets.only(left: 12, right: 4),
        leading: RoleAvatar(isCoach: role == TeamRole.coach),
        title: Text(
          isMe ? '$name (já)' : name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          isOwnerRow
              ? 'Správce týmu'
              : (role == TeamRole.coach ? 'Trenér' : 'Hráč'),
        ),
        trailing: _memberActions(
          context,
          uid: uid,
          name: name,
          role: role,
          isOwnerRow: isOwnerRow,
          isMe: isMe,
        ),
      ),
    );
  }

  Widget? _memberActions(
    BuildContext context, {
    required String uid,
    required String name,
    required TeamRole role,
    required bool isOwnerRow,
    required bool isMe,
  }) {
    if (!isCoach) return null;
    if (isOwnerRow) {
      return const Tooltip(
        message: 'Správce týmu nelze změnit na hráče ani odebrat z týmu',
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Icon(Icons.lock_outline, size: 20),
        ),
      );
    }

    final isMemberCoach = role == TeamRole.coach;
    if (!_isOwner) {
      if (isMemberCoach || isMe) return null;
      return IconButton(
        icon: const Icon(Icons.person_remove),
        tooltip: 'Odebrat z týmu',
        onPressed: () => _removeMember(context, uid, name),
      );
    }

    return PopupMenuButton<_MemberAction>(
      tooltip: 'Možnosti člena',
      onSelected: (action) {
        switch (action) {
          case _MemberAction.toggleRole:
            _changeRole(context, uid, role);
          case _MemberAction.transfer:
            _transferOwnership(context, uid, name, !isMemberCoach);
          case _MemberAction.remove:
            _removeMember(context, uid, name);
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

  void _showError(BuildContext context, Object e) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(errorText(e))));
  }

  Future<void> _changeRole(
    BuildContext context,
    String uid,
    TeamRole currentRole,
  ) async {
    final newRole = currentRole == TeamRole.coach
        ? TeamRole.player
        : TeamRole.coach;
    try {
      await TeamService().updateMemberRole(teamId, uid, newRole);
    } catch (e) {
      if (context.mounted) _showError(context, e);
    }
  }

  Future<void> _removeMember(
    BuildContext context,
    String uid,
    String name,
  ) async {
    final confirmed = await confirmDialog(
      context,
      title: 'Odebrat člena',
      message: 'Opravdu chceš odebrat "$name" z týmu?',
      confirmLabel: 'Odebrat',
    );
    if (!confirmed) return;

    try {
      await TeamService().removeMember(teamId, uid);
    } catch (e) {
      if (context.mounted) _showError(context, e);
    }
  }

  Future<void> _transferOwnership(
    BuildContext context,
    String uid,
    String name,
    bool isPlayer,
  ) async {
    final confirmed = await confirmDialog(
      context,
      title: 'Předat vedení týmu',
      message:
          'Správcem týmu "$teamName" se stane "$name"'
          '${isPlayer ? ' a zároveň se stane trenérem' : ''}. '
          'Ty zůstaneš trenérem, ale tým už nebudeš moct zrušit ani spravovat trenéry.',
      confirmLabel: 'Předat vedení',
    );
    if (!confirmed) return;

    try {
      await TeamService().transferOwnership(teamId, uid);
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Správcem týmu je teď $name')));
    } catch (e) {
      if (context.mounted) _showError(context, e);
    }
  }
}

enum _MemberAction { toggleRole, transfer, remove }

/// Karta „Pozvi hráče“ s pozvánkovým kódem a tlačítkem pro zkopírování.
class _InviteCard extends StatelessWidget {
  const _InviteCard({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconBadge(icon: Icons.vpn_key_outlined, color: colors.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Pozvi hráče',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        'Pošli jim kód, v aplikaci zvolí „Připojit se“.',
                        style: TextStyle(color: colors.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: colors.surfaceContainer,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      code,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 4,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  icon: const Icon(Icons.copy),
                  tooltip: 'Kopírovat kód týmu',
                  onPressed: () => copyTeamCode(context, code),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Zkopíruje pozvánkový kód do schránky a dá o tom vědět hláškou.
void copyTeamCode(BuildContext context, String code) {
  Clipboard.setData(ClipboardData(text: code));
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text('Kód $code zkopírován')));
}
