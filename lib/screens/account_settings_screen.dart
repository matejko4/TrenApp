import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../utils/error_text.dart';
import '../widgets/account_actions.dart';
import '../widgets/app_bottom_bar.dart';
import '../widgets/common.dart';

/// Nastavení účtu: změna jména, hesla, vzhled (světlý / tmavý režim)
/// a odhlášení.
class AccountSettingsScreen extends StatelessWidget {
  const AccountSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    final colors = Theme.of(context).colorScheme;

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
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              // Profil – kolečko s počátečním písmenem, jméno a e-mail.
              GradientCard(
                child: Row(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.2),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.5),
                          width: 2,
                        ),
                      ),
                      child: Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name.isNotEmpty ? name : 'Bez jména',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            email,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              const _GroupTitle('Profil'),
              _Group(children: [
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
              ]),
              const _GroupTitle('Vzhled'),
              const _Group(children: [_ThemeModePicker()]),
              const _GroupTitle('Zabezpečení'),
              _Group(children: [
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
              ]),
              const SizedBox(height: 16),
              _Group(children: [
                ListTile(
                  leading: Icon(Icons.logout, color: colors.error),
                  title: Text(
                    'Odhlásit se',
                    style: TextStyle(
                      color: colors.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onTap: () => logOut(context),
                ),
              ]),
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

/// Nadpis skupiny nastavení (např. „PROFIL“).
class _GroupTitle extends StatelessWidget {
  const _GroupTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return SectionTitle(title, padding: const EdgeInsets.fromLTRB(4, 20, 4, 8));
  }
}

/// Skupina položek nastavení v jedné kartě, oddělených čarou.
class _Group extends StatelessWidget {
  const _Group({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const Divider(height: 1, indent: 56),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// Volba vzhledu: podle systému telefonu, světlý, nebo tmavý režim.
/// Změna se projeví hned v celé aplikaci a uloží se do telefonu
/// (viz ThemeController v theme/app_theme.dart).
class _ThemeModePicker extends StatelessWidget {
  const _ThemeModePicker();

  @override
  Widget build(BuildContext context) {
    final controller = ThemeController.instance;
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: controller,
      builder: (context, mode, _) => Padding(
        padding: const EdgeInsets.all(12),
        child: SizedBox(
          width: double.infinity,
          child: SegmentedButton<ThemeMode>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                value: ThemeMode.system,
                label: Text('Systém'),
                icon: Icon(Icons.brightness_auto_outlined),
              ),
              ButtonSegment(
                value: ThemeMode.light,
                label: Text('Světlý'),
                icon: Icon(Icons.light_mode_outlined),
              ),
              ButtonSegment(
                value: ThemeMode.dark,
                label: Text('Tmavý'),
                icon: Icon(Icons.dark_mode_outlined),
              ),
            ],
            selected: {mode},
            onSelectionChanged: (selection) =>
                controller.setMode(selection.first),
          ),
        ),
      ),
    );
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
            decoration: const InputDecoration(labelText: 'Jméno'),
          ),
          if (_error.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              _error,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
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
      decoration: InputDecoration(labelText: label),
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
              Text(
                _error,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
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
