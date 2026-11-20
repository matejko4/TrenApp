import 'package:flutter/material.dart';

import '../services/run_service.dart';
import '../utils/error_text.dart';
import '../widgets/run_widgets.dart';

/// Detail běhu jednoho hráče u tréninku: mapa trasy a údaje o běhu.
/// Otevírá ho trenér ze seznamu hráčů v detailu tréninku a hráč ze své
/// karty „Můj běh“.
class RunDetailScreen extends StatefulWidget {
  const RunDetailScreen({
    super.key,
    required this.teamId,
    required this.trainingId,
    required this.uid,
    required this.title,
  });

  final String teamId;
  final String trainingId;

  /// Hráč, jehož běh se zobrazuje.
  final String uid;

  /// Nadpis – jméno hráče (trenér), nebo „Můj běh“ (hráč).
  final String title;

  @override
  State<RunDetailScreen> createState() => _RunDetailScreenState();
}

class _RunDetailScreenState extends State<RunDetailScreen> {
  late final Stream<Run?> _run = RunService().streamRun(
    widget.teamId,
    widget.trainingId,
    widget.uid,
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: StreamBuilder<Run?>(
        stream: _run,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text(errorText(snapshot.error!)));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final run = snapshot.data;
          if (run == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'Hráč zatím nemá záznam běhu.\n'
                  'Trénink mohl splnit i ručně, bez záznamu z telefonu.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            );
          }
          // Bez scrollování stránky – posouvání prstem patří mapě.
          return Column(
            children: [
              SizedBox(height: 300, child: RunMap(run: run)),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: RunStats(run: run),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
