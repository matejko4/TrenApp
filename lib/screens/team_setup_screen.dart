import 'package:flutter/material.dart';
import '../services/team_service.dart';
import '../widgets/account_actions.dart';

/// Zobrazí se po přihlášení, pokud uživatel není v žádném týmu, a také
/// když existující uživatel chce vytvořit/připojit se k dalšímu týmu.
///
/// Když je tato obrazovka nasazená jako výsledek RootGate (uživatel bez
/// týmu), po úspěšném vytvoření/připojení se RootGate sám přepne na
/// HomeScreen díky streamu z Firestore – proto se odtud nikam nenaviguje,
/// pouze se zkusí zavřít, pokud byla otevřená přes Navigator.push.
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
        // Pokud je obrazovka na vrcholu navigačního zásobníku (přidávání
        // dalšího týmu z HomeScreen), vrátíme se zpět. Pokud je vykreslená
        // rovnou jako root (uživatel bez týmu), není co zavírat a RootGate
        // se sám přepne na HomeScreen.
        Navigator.of(context).maybePop();
      }
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();

    return Scaffold(
      backgroundColor: Colors.indigo.shade50,
      appBar: canPop
          ? AppBar(
              title: const Text('Přidat tým'),
              backgroundColor: Colors.indigo,
              foregroundColor: Colors.white,
              actions: accountActions(),
            )
          : AppBar(
              title: const Text('TrenApp'),
              backgroundColor: Colors.indigo,
              foregroundColor: Colors.white,
              automaticallyImplyLeading: false,
              actions: accountActions(),
            ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.groups, size: 72, color: Colors.indigo),
                const SizedBox(height: 16),
                const Text(
                  'Zatím nejsi v žádném týmu',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Vytvoř nový tým jako trenér, nebo se připoj kódem, který ti dal trenér.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 32),
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
                const SizedBox(height: 24),
                if (_isCreateMode)
                  TextField(
                    controller: _nameController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Název týmu',
                      hintText: 'např. FC Sokol Praha',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.shield_outlined),
                    ),
                  )
                else
                  TextField(
                    controller: _codeController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'Kód týmu',
                      hintText: 'např. AB12CD',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.vpn_key_outlined),
                    ),
                  ),
                if (_error.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(_error, style: const TextStyle(color: Colors.red)),
                ],
                const SizedBox(height: 24),
                _loading
                    ? const CircularProgressIndicator()
                    : ElevatedButton(
                        onPressed: _submit,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 50),
                          backgroundColor: Colors.indigo,
                          foregroundColor: Colors.white,
                        ),
                        child: Text(
                          _isCreateMode ? 'Vytvořit tým' : 'Připojit se k týmu',
                        ),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
