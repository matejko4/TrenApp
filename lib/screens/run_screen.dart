import 'package:flutter/material.dart';

import '../services/training_service.dart';
import '../widgets/coming_soon.dart';

/// Záznam běžeckého tréninku pomocí GPS (čas, vzdálenost, tempo, trasa).
/// Zatím jen zástupná obrazovka – GPS záznam je v plánu na listopad.
class RunScreen extends StatelessWidget {
  const RunScreen({super.key, required this.teamId, required this.training});

  final String teamId;
  final Training training;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(training.title),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: const ComingSoon(
        icon: Icons.directions_run,
        title: 'Záznam běhu',
        message: 'GPS záznam běhu připravujeme. Zatím můžeš trénink '
            'v kalendáři označit jako splněný ručně.',
      ),
    );
  }
}
