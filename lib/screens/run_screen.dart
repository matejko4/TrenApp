import 'package:flutter/material.dart';

import '../services/training_service.dart';
import '../widgets/coming_soon.dart';

/// Záznam běžeckého tréninku pomocí GPS (čas, vzdálenost, tempo, trasa).
class RunScreen extends StatelessWidget {
  const RunScreen({super.key, required this.teamId, required this.training});

  final String teamId;
  final Training training;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(training.title),
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
