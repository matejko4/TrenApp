import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import 'login_screen.dart';

/// Nastavení účtu: změna jména, hesla a odhlášení.
class AccountSettingsScreen extends StatelessWidget {
  const AccountSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nastavení účtu'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<User?>(
        stream: authService.userChanges,
        initialData: authService.currentUser,
        builder: (context, snapshot) {
          final user = snapshot.data;
          final name = user?.displayName ?? '';
          final email = user?.email ?? '';
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
              const _SectionHeader('Profil'),
              ListTile(
                leading: const Icon(Icons.badge_outlined),
                title: const Text('Změnit jméno'),
                subtitle: Text(name.isNotEmpty ? name : 'Nevyplněno'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => showDialog(
                  context: context,
                  builder: (_) => const EditNameDialog(),
                ),
              ),
              const _SectionHeader('Zabezpečení'),
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
                onTap: () async {
                  await authService.logout();
                  if (context.mounted) {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                      (route) => false,
                    );
                  }
                },
              ),
            ],
          );
        },
      ),
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
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.indigo,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

/// Dialog pro změnu jména. Změna se propíše i do soupisek
/// všech týmů uživatele (viz AuthService.updateName).
class EditNameDialog extends StatefulWidget {
  const EditNameDialog({super.key});

  @override
  State<EditNameDialog> createState() => _EditNameDialogState();
}

class _EditNameDialogState extends State<EditNameDialog> {
  final _authService = AuthService();
  final _nameController = TextEditingController(
    text: FirebaseAuth.instance.currentUser?.displayName ?? '',
  );

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
      await _authService.updateName(_nameController.text);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString().replaceFirst('Exception: ', '');
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
          _error = e.toString().replaceFirst('Exception: ', '');
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
