import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../utils/error_text.dart';
import '../widgets/account_actions.dart';
import '../widgets/app_bottom_bar.dart';
import '../widgets/common.dart';

/// Nastavení účtu: změna jména, hesla a odhlášení.
class AccountSettingsScreen extends StatelessWidget {
  const AccountSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nastavení účtu'),
      ),
      // Jméno se čte z users/{uid} (ne z účtu Firebase Auth), protože se
      // tam změní hned, i bez internetu – viz AuthService.updateName.
      body: StreamBuilder<String?>(
        stream: authService.myName,
        builder: (context, snapshot) {
          final name = snapshot.data ?? '';
          final email = authService.currentUser?.email ?? '';
          final hasPassword = authService.hasPasswordLogin;

          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 16),
            children: [
              Center(
                child: CircleAvatar(
                  radius: 36,
                  backgroundColor: Colors.indigo,
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: const TextStyle(fontSize: 28, color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                name.isNotEmpty ? name : 'Bez jména',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                email,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 24),
              const SectionTitle(
                'Profil',
                padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
              ),
              ListTile(
                leading: const Icon(Icons.badge_outlined),
                title: const Text('Změnit jméno'),
                subtitle: Text(name.isNotEmpty ? name : 'Nevyplněno'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => showDialog(
                  context: context,
                  builder: (_) => EditNameDialog(currentName: name),
                ),
              ),
              const SectionTitle(
                'Zabezpečení',
                padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
              ),
              if (hasPassword) ...[
                ListTile(
                  leading: const Icon(Icons.lock_outline),
                  title: const Text('Změnit heslo'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => showDialog(
                    context: context,
                    builder: (_) => const ChangePasswordDialog(),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.mail_outline),
                  title: const Text('Zapomenuté heslo'),
                  subtitle: const Text('Pošle odkaz pro obnovení na e-mail'),
                  onTap: () => _sendPasswordReset(context, authService),
                ),
              ] else
                const ListTile(
                  leading: Icon(Icons.g_mobiledata),
                  title: Text('Přihlášení přes Google'),
                  subtitle: Text('Heslo se spravuje ve tvém Google účtu.'),
                ),
              const Divider(height: 32),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const Text(
                  'Odhlásit se',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () => logOut(context),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: const AppBottomBar(current: AppTab.account),
    );
  }

  Future<void> _sendPasswordReset(
      BuildContext context, AuthService authService) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await authService.sendPasswordReset();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
              'Odkaz pro obnovení hesla odeslán na ${authService.currentUser?.email}'),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(errorText(e))),
      );
    }
  }
}

/// Dialog pro změnu jména. Změna se propíše i do soupisek
/// všech týmů uživatele (viz AuthService.updateName).
class EditNameDialog extends StatefulWidget {
  const EditNameDialog({super.key, required this.currentName});

  final String currentName;

  @override
  State<EditNameDialog> createState() => _EditNameDialogState();
}

class _EditNameDialogState extends State<EditNameDialog> {
  final _authService = AuthService();
  late final _nameController = TextEditingController(text: widget.currentName);

  bool _loading = false;
  String _error = '';

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      final sent = await _authService.updateName(_nameController.text);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      if (!sent) {
        messenger.showSnackBar(const SnackBar(
          content: Text(
              'Jméno je uložené v telefonu, odešle se, až budeš online.'),
        ));
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = errorText(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Změnit jméno'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Jméno',
              border: OutlineInputBorder(),
            ),
          ),
          if (_error.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(_error, style: const TextStyle(color: Colors.red)),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.of(context).pop(),
          child: const Text('Zrušit'),
        ),
        TextButton(
          onPressed: _loading ? null : _save,
          child: const Text('Uložit'),
        ),
      ],
    );
  }
}

/// Dialog pro změnu hesla (jen pro účty s přihlášením e-mailem a heslem).
class ChangePasswordDialog extends StatefulWidget {
  const ChangePasswordDialog({super.key});

  @override
  State<ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<ChangePasswordDialog> {
  final _authService = AuthService();
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _loading = false;
  String _error = '';

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_newController.text != _confirmController.text) {
      setState(() => _error = 'Nová hesla se neshodují');
      return;
    }
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      await _authService.changePassword(
        _currentController.text,
        _newController.text,
      );
      if (mounted) {
        final messenger = ScaffoldMessenger.of(context);
        Navigator.of(context).pop();
        messenger.showSnackBar(
          const SnackBar(content: Text('Heslo bylo změněno')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = errorText(e);
        });
      }
    }
  }

  Widget _passwordField(TextEditingController controller, String label,
      {bool autofocus = false}) {
    return TextField(
      controller: controller,
      obscureText: true,
      autofocus: autofocus,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Změnit heslo'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _passwordField(_currentController, 'Současné heslo',
                autofocus: true),
            const SizedBox(height: 12),
            _passwordField(_newController, 'Nové heslo'),
            const SizedBox(height: 12),
            _passwordField(_confirmController, 'Nové heslo znovu'),
            if (_error.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(_error, style: const TextStyle(color: Colors.red)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.of(context).pop(),
          child: const Text('Zrušit'),
        ),
        TextButton(
          onPressed: _loading ? null : _save,
          child: const Text('Uložit'),
        ),
      ],
    );
  }
}
