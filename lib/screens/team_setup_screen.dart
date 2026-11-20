import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/team_service.dart';
import '../theme/app_theme.dart';
import '../utils/error_text.dart';
import '../widgets/account_actions.dart';

/// Založení nového týmu, nebo připojení k týmu kódem. Otevírá se z Domů
/// tlačítkem „Přidat tým“ a po úspěchu se zavře – Domů nový tým ukáže
/// sám díky streamu z Firestore.
class TeamSetupScreen extends StatefulWidget {
  const TeamSetupScreen({super.key});

  @override
  State<TeamSetupScreen> createState() => _TeamSetupScreenState();
}

class _TeamSetupScreenState extends State<TeamSetupScreen> {
  final _teamService = TeamService();
  final _nameController = TextEditingController();
  final _codeController = TextEditingController();

  bool _isCreateMode = true;
  bool _loading = false;
  String _error = '';

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      if (_isCreateMode) {
        await _teamService.createTeam(_nameController.text);
      } else {
        await _teamService.joinTeamByCode(_codeController.text);
      }
      if (mounted) {
        Navigator.of(context).maybePop();
      }
    } catch (e) {
      setState(() => _error = errorText(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Obsah je i pod průhlednou horní lištou, aby přechod šel až nahoru.
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Přidat tým'),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        titleTextStyle: Theme.of(
          context,
        ).textTheme.titleLarge?.copyWith(color: Colors.white),
        systemOverlayStyle: SystemUiOverlayStyle.light,
        actions: const [LogoutButton()],
      ),
      body: GradientBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const IconBadge(icon: Icons.groups, size: 76),
                    const SizedBox(height: 20),
                    Text(
                      'Založ tým, nebo se připoj',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Vytvoř nový tým, nebo se připoj kódem, který ti dal trenér.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                    const SizedBox(height: 28),
                    Card(
                      elevation: 8,
                      shadowColor: Colors.black38,
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SegmentedButton<bool>(
                              segments: const [
                                ButtonSegment(
                                  value: true,
                                  label: Text('Vytvořit tým'),
                                  icon: Icon(Icons.add_business),
                                ),
                                ButtonSegment(
                                  value: false,
                                  label: Text('Připojit se'),
                                  icon: Icon(Icons.key),
                                ),
                              ],
                              selected: {_isCreateMode},
                              onSelectionChanged: (selection) => setState(() {
                                _isCreateMode = selection.first;
                                _error = '';
                              }),
                            ),
                            const SizedBox(height: 20),
                            if (_isCreateMode)
                              TextField(
                                controller: _nameController,
                                textCapitalization: TextCapitalization.words,
                                decoration: const InputDecoration(
                                  labelText: 'Název týmu',
                                  hintText: 'např. AC Sparta Praha',
                                  prefixIcon: Icon(Icons.shield_outlined),
                                ),
                              )
                            else
                              TextField(
                                controller: _codeController,
                                textCapitalization:
                                    TextCapitalization.characters,
                                decoration: const InputDecoration(
                                  labelText: 'Kód týmu',
                                  hintText: 'např. AB12CD34',
                                  prefixIcon: Icon(Icons.vpn_key_outlined),
                                ),
                              ),
                            if (_error.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Text(
                                _error,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ),
                            ],
                            const SizedBox(height: 20),
                            if (_loading)
                              const Center(child: CircularProgressIndicator())
                            else
                              FilledButton(
                                onPressed: _submit,
                                style: FilledButton.styleFrom(
                                  minimumSize: const Size.fromHeight(52),
                                ),
                                child: Text(
                                  _isCreateMode
                                      ? 'Vytvořit tým'
                                      : 'Připojit se k týmu',
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
