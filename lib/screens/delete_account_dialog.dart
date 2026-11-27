import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/team_service.dart';
import '../utils/error_text.dart';
import 'team_detail_screen.dart';

/// Dialog pro smazání účtu (Nastavení účtu → Smazat účet).
///
/// Po otevření nejdřív zjistí, jestli uživatel nespravuje nějaký tým
/// (TeamService.ownedTeams):
///  - spravuje → místo smazání ukáže upozornění se seznamem těchto týmů;
///    klepnutím na tým se otevře jeho detail, kde jde předat vedení nebo
///    tým zrušit,
///  - nespravuje → shrne, co se smaže, a nechá smazání potvrdit heslem
///    (u Google účtu výběrem účtu v okně Google).
class DeleteAccountDialog extends StatefulWidget {
  const DeleteAccountDialog({super.key});

  @override
  State<DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<DeleteAccountDialog> {
  final _authService = AuthService();
  final _passwordController = TextEditingController();

  // late final – načte se jednou při otevření dialogu, ne při každém
  // překreslení (FutureBuilder by jinak dotaz spouštěl pořád znovu).
  late final Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
  _ownedTeams = TeamService().ownedTeams();

  bool _deleting = false;
  String _error = '';

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    // Navigator a ScaffoldMessenger se vezmou předem – po smazání účtu se
    // pod dialogem přestaví celá aplikace (RootGate → přihlášení).
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _deleting = true;
      _error = '';
    });
    try {
      final deleted = await _authService.deleteAccount(
        password: _passwordController.text,
      );
      if (!deleted) {
        // Okno Google účtu zavřené – nic se nestalo.
        if (mounted) setState(() => _deleting = false);
        return;
      }
      // Zavře dialog i Nastavení účtu, zůstane jen RootGate, který už
      // ukazuje přihlašovací obrazovku.
      navigator.popUntil((route) => route.isFirst);
      messenger.showSnackBar(const SnackBar(content: Text('Účet byl smazán')));
    } catch (e) {
      if (mounted) {
        setState(() {
          _deleting = false;
          _error = errorText(e);
        });
      }
    }
  }

  /// Zavře dialog i nastavení a otevře detail týmu, kde jde předat
  /// vedení (záložka Tým) nebo tým zrušit (menu ⋮).
  void _openTeam(QueryDocumentSnapshot<Map<String, dynamic>> teamDoc) {
    final navigator = Navigator.of(context);
    navigator.pop();
    navigator.push(
      MaterialPageRoute(
        builder: (_) => TeamDetailScreen(
          teamId: teamDoc.id,
          teamName: teamDoc.data()['teamName'] as String? ?? 'Tým',
          isCoach: true,
          code: teamDoc.data()['code'] as String?,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _ownedTeams,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const AlertDialog(
            title: Text('Smazat účet'),
            content: SizedBox(
              height: 80,
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }
        if (snapshot.hasError) {
          // Nejčastěji chybějící internet – bez něj se nesmí nic mazat.
          return AlertDialog(
            title: const Text('Smazat účet'),
            content: Text(errorText(snapshot.error!)),
            actions: [_closeButton('Zavřít')],
          );
        }
        final owned = snapshot.data!;
        return owned.isNotEmpty ? _buildOwnedTeams(owned) : _buildConfirm();
      },
    );
  }

  Widget _closeButton(String label) => TextButton(
    onPressed: _deleting ? null : () => Navigator.of(context).pop(),
    child: Text(label),
  );

  /// Upozornění: uživatel je správcem týmů, účet zatím smazat nejde.
  Widget _buildOwnedTeams(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> owned,
  ) {
    return AlertDialog(
      title: const Text('Nejdřív vyřeš své týmy'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Jsi správcem týmu a tým nemůže zůstat bez správce. '
              'Než smažeš účet:',
            ),
            const SizedBox(height: 8),
            const Text(
              '• předej vedení jinému členovi (záložka Tým → ⋮ u člena → '
              'Předat vedení týmu), nebo\n'
              '• tým zruš (⋮ vpravo nahoře → Zrušit tým).',
            ),
            const SizedBox(height: 8),
            for (final teamDoc in owned)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.groups_outlined),
                title: Text(teamDoc.data()['teamName'] as String? ?? 'Tým'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _openTeam(teamDoc),
              ),
          ],
        ),
      ),
      actions: [_closeButton('Zavřít')],
    );
  }

  /// Potvrzení smazání – co se smaže a ověření heslem / Google účtem.
  Widget _buildConfirm() {
    final colors = Theme.of(context).colorScheme;
    final usesPassword = _authService.hasPasswordLogin;

    return AlertDialog(
      title: const Text('Smazat účet?'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Smazání je nevratné. Smaže se:'),
            const SizedBox(height: 8),
            const Text(
              '• tvůj profil a jméno,\n'
              '• členství ve všech týmech (z týmů odejdeš),\n'
              '• tvoje záznamy běhů (GPS trasy).',
            ),
            const SizedBox(height: 16),
            if (usesPassword)
              TextField(
                controller: _passwordController,
                obscureText: true,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Heslo pro potvrzení',
                ),
              )
            else
              const Text('Smazání potvrdíš výběrem svého Google účtu.'),
            if (_error.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(_error, style: TextStyle(color: colors.error)),
            ],
          ],
        ),
      ),
      actions: [
        _closeButton('Zrušit'),
        // Červené potvrzovací tlačítko jako v confirmDialog (widgets/common.dart).
        TextButton(
          onPressed: _deleting ? null : _delete,
          style: TextButton.styleFrom(foregroundColor: colors.error),
          child: const Text('Smazat účet'),
        ),
      ],
    );
  }
}
