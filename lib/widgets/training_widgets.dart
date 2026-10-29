import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../screens/run_screen.dart';
import '../services/training_service.dart';
import '../utils/date_format.dart';
import '../utils/error_text.dart';

// Widgety pro zobrazení tréninku sdílené kalendářem a detailem tréninku.

IconData trainingTypeIcon(TrainingType type) => switch (type) {
      TrainingType.run => Icons.directions_run,
      TrainingType.strength => Icons.fitness_center,
      TrainingType.technique => Icons.sports_soccer,
      TrainingType.recovery => Icons.self_improvement,
      TrainingType.other => Icons.event,
    };

/// Ikona s barevným popiskem – stav tréninku nebo počet odpovědí.
class TrainingStatusLabel extends StatelessWidget {
  const TrainingStatusLabel({
    super.key,
    required this.icon,
    required this.color,
    required this.label,
  });

  final IconData icon;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(color: color, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

/// Štítek „Společný“ / „Individuální“.
class TrainingKindChip extends StatelessWidget {
  const TrainingKindChip({super.key, required this.isTeam});

  final bool isTeam;

  @override
  Widget build(BuildContext context) {
    final color = isTeam ? Colors.indigo : Colors.teal;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        isTeam ? 'Společný' : 'Individuální',
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Stav individuálního tréninku jednoho hráče.
TrainingStatusLabel individualStatusLabel(IndividualStatus status) =>
    switch (status) {
      IndividualStatus.planned => const TrainingStatusLabel(
          icon: Icons.schedule, color: Colors.blueGrey, label: 'Naplánovaný'),
      IndividualStatus.done => const TrainingStatusLabel(
          icon: Icons.check_circle, color: Colors.green, label: 'Splněný'),
      IndividualStatus.missed => const TrainingStatusLabel(
          icon: Icons.cancel, color: Colors.red, label: 'Nesplněný'),
    };

/// Odpověď hráče na společný trénink.
TrainingStatusLabel teamResponseLabel(TrainingResponse? response) =>
    switch (response) {
      TrainingResponse.yes => const TrainingStatusLabel(
          icon: Icons.check_circle, color: Colors.green, label: 'Budu'),
      TrainingResponse.no => const TrainingStatusLabel(
          icon: Icons.cancel, color: Colors.red, label: 'Nebudu'),
      _ => const TrainingStatusLabel(
          icon: Icons.help_outline, color: Colors.grey, label: 'Bez odpovědi'),
    };

/// Karta tréninku v kalendáři. Hráč na ní rovnou odpovídá / plní trénink,
/// trenér vidí souhrn odpovědí. [players] (uid -> jméno hráčů týmu) je
/// potřeba jen pro trenérský souhrn.
class TrainingCard extends StatelessWidget {
  const TrainingCard({
    super.key,
    required this.teamId,
    required this.training,
    required this.isCoach,
    this.players = const {},
    this.onTap,
  });

  final String teamId;
  final Training training;
  final bool isCoach;
  final Map<String, String> players;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor:
                        training.isTeam ? Colors.indigo : Colors.teal,
                    child: Icon(
                      trainingTypeIcon(training.type),
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          training.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          [
                            formatTimeRange(training.startAt, training.endAt),
                            ?training.place,
                          ].join(' · '),
                          style: const TextStyle(color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                  TrainingKindChip(isTeam: training.isTeam),
                ],
              ),
              const SizedBox(height: 12),
              if (isCoach)
                TrainingCoachSummary(training: training, players: players)
              else
                TrainingPlayerActions(teamId: teamId, training: training),
            ],
          ),
        ),
      ),
    );
  }
}

/// Trenérský souhrn: počty BUDU / NEBUDU / bez odpovědi u společného
/// tréninku, počet splnění u individuálního.
class TrainingCoachSummary extends StatelessWidget {
  const TrainingCoachSummary({
    super.key,
    required this.training,
    required this.players,
  });

  final Training training;
  final Map<String, String> players;

  @override
  Widget build(BuildContext context) {
    if (training.isTeam) {
      final yes = players.keys
          .where((uid) => training.responses[uid] == TrainingResponse.yes)
          .length;
      final no = players.keys
          .where((uid) => training.responses[uid] == TrainingResponse.no)
          .length;
      return Wrap(
        spacing: 16,
        runSpacing: 4,
        children: [
          TrainingStatusLabel(
              icon: Icons.check_circle, color: Colors.green, label: 'Přijde $yes'),
          TrainingStatusLabel(
              icon: Icons.cancel, color: Colors.red, label: 'Nepřijde $no'),
          TrainingStatusLabel(
            icon: Icons.help_outline,
            color: Colors.grey,
            label: 'Bez odpovědi ${players.length - yes - no}',
          ),
        ],
      );
    }

    // Hráči, kteří mezitím z týmu odešli, se nepočítají.
    final assigned = training.assignedTo.where(players.containsKey).toList();
    final done = assigned
        .where((uid) => training.statusOf(uid) == IndividualStatus.done)
        .length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Pro: ${assigned.map((uid) => players[uid]).join(', ')}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        TrainingStatusLabel(
          icon: Icons.check_circle,
          color: Colors.green,
          label: 'Splněno $done / ${assigned.length}',
        ),
      ],
    );
  }
}

/// Akce hráče: BUDU / NEBUDU u společného tréninku, u individuálního jeho
/// stav a tlačítka pro splnění (u běhu navíc „Začít běh“).
class TrainingPlayerActions extends StatelessWidget {
  const TrainingPlayerActions({
    super.key,
    required this.teamId,
    required this.training,
  });

  final String teamId;
  final Training training;

  Future<void> _respond(BuildContext context, TrainingResponse? response) async {
    try {
      await TrainingService().respond(teamId, training.id, response);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorText(e))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    return training.isTeam
        ? _buildTeam(context, training.responses[uid])
        : _buildIndividual(context, training.statusOf(uid));
  }

  Widget _buildTeam(BuildContext context, TrainingResponse? response) {
    if (!training.canRespond) return teamResponseLabel(response);

    return Row(
      children: [
        Expanded(
          child: _ChoiceButton(
            label: 'BUDU',
            icon: Icons.check,
            color: Colors.green,
            selected: response == TrainingResponse.yes,
            onPressed: () => _respond(context, TrainingResponse.yes),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _ChoiceButton(
            label: 'NEBUDU',
            icon: Icons.close,
            color: Colors.red,
            selected: response == TrainingResponse.no,
            onPressed: () => _respond(context, TrainingResponse.no),
          ),
        ),
      ],
    );
  }

  Widget _buildIndividual(BuildContext context, IndividualStatus status) {
    final label = individualStatusLabel(status);
    switch (status) {
      case IndividualStatus.missed:
        return label;
      case IndividualStatus.done:
        return Row(
          children: [
            label,
            const Spacer(),
            TextButton(
              onPressed: () => _respond(context, null),
              child: const Text('Zrušit splnění'),
            ),
          ],
        );
      case IndividualStatus.planned:
        if (training.type != TrainingType.run) {
          return SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              icon: const Icon(Icons.check),
              label: const Text('Označit jako splněný'),
              onPressed: () => _respond(context, TrainingResponse.done),
            ),
          );
        }
        // Běh jde zatím (než bude hotový GPS záznam) splnit i ručně.
        return Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                icon: const Icon(Icons.play_arrow),
                label: const Text('Začít běh'),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        RunScreen(teamId: teamId, training: training),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.check),
                label: const Text('Splněno'),
                onPressed: () => _respond(context, TrainingResponse.done),
              ),
            ),
          ],
        );
    }
  }
}

class _ChoiceButton extends StatelessWidget {
  const _ChoiceButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    if (selected) {
      return FilledButton.icon(
        style: FilledButton.styleFrom(backgroundColor: color),
        icon: Icon(icon),
        label: Text(label),
        onPressed: onPressed,
      );
    }
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(foregroundColor: color),
      icon: Icon(icon),
      label: Text(label),
      onPressed: onPressed,
    );
  }
}
