import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/team_service.dart';
import '../widgets/account_actions.dart';

/// Detail týmu – roster členů. Trenér zde navíc může měnit role členů,
/// odebírat je z týmu a tým celý zrušit.
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
  String? _founderUid;

  @override
  void initState() {
    super.initState();
    // Zakladatele týmu (teams/{teamId}.createdBy) potřebujeme znát, aby
    // šlo v rosteru schovat možnost přepnout ho na hráče – viz
    // TeamService.updateMemberRole, kde je stejné pravidlo vynucené.
    _teamService.getTeam(widget.teamId).then((doc) {
      if (!mounted) return;
      setState(() => _founderUid = doc.data()?['createdBy'] as String?);
    });
  }

  String get _myUid => FirebaseAuth.instance.currentUser?.uid ?? '';

  Future<void> _changeRole(String uid, String currentRole) async {
    final newRole =
        currentRole == TeamRole.coach ? TeamRole.player : TeamRole.coach;
    try {
      await _teamService.updateMemberRole(widget.teamId, uid, newRole);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> _removeMember(String uid, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Odebrat člena'),
        content: Text('Opravdu chceš odebrat "$name" z týmu?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Zrušit'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Odebrat'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _teamService.removeMember(widget.teamId, uid);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> _deleteTeam() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Zrušit tým'),
        content: Text(
          'Opravdu chceš úplně zrušit tým "${widget.teamName}"? '
          'Smažou se všichni členové a tato akce je nevratná.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Zrušit'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Zrušit tým'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _deleting = true);
    try {
      await _teamService.deleteTeam(widget.teamId);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _deleting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.teamName),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
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
          if (widget.isCoach)
            IconButton(
              icon: const Icon(Icons.delete_forever),
              tooltip: 'Zrušit tým',
              onPressed: _deleting ? null : _deleteTeam,
            ),
          ...accountActions(),
        ],
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
                    final isFounder = uid == _founderUid;

                    return Card(
                      elevation: 1,
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor:
                              isMemberCoach ? Colors.indigo : Colors.teal,
                          child: Icon(
                            isMemberCoach ? Icons.sports : Icons.directions_run,
                            color: Colors.white,
                          ),
                        ),
                        title: Text(isMe ? '$name (já)' : name),
                        subtitle: Text(isMemberCoach ? 'Trenér' : 'Hráč'),
                        trailing: widget.isCoach
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (isFounder)
                                    const Tooltip(
                                      message:
                                          'Zakladatele týmu nelze změnit na hráče ani odebrat z týmu',
                                      child: Padding(
                                        padding: EdgeInsets.all(12),
                                        child: Icon(
                                          Icons.lock_outline,
                                          color: Colors.black38,
                                        ),
                                      ),
                                    )
                                  else
                                    IconButton(
                                      icon: Icon(
                                        isMemberCoach
                                            ? Icons.arrow_downward
                                            : Icons.arrow_upward,
                                      ),
                                      tooltip: isMemberCoach
                                          ? 'Nastavit jako hráče'
                                          : 'Nastavit jako trenéra',
                                      onPressed: () => _changeRole(uid, role),
                                    ),
                                  if (!isMe && !isFounder)
                                    IconButton(
                                      icon: const Icon(Icons.person_remove),
                                      tooltip: 'Odebrat z týmu',
                                      onPressed: () =>
                                          _removeMember(uid, name),
                                    ),
                                ],
                              )
                            : null,
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
