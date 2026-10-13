import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/team_service.dart';
import '../services/training_service.dart';
import '../utils/date_format.dart';
import '../widgets/account_actions.dart';
import '../widgets/app_bottom_bar.dart';
import '../widgets/training_widgets.dart';
import 'training_detail_screen.dart';
import 'training_form_screen.dart';

/// Kalendář tréninků konkrétního týmu – seznam tréninků seskupený po dnech.
///
/// Hráč vidí společné tréninky a individuální tréninky zadané jemu a přímo
/// tu na ně odpovídá. Trenér vidí všechny tréninky týmu se souhrnem
/// odpovědí a může přidávat nové.
class TeamCalendarScreen extends StatefulWidget {
  const TeamCalendarScreen({
    super.key,
    required this.teamId,
    required this.teamName,
    required this.isCoach,
  });

  final String teamId;
  final String teamName;
  final bool isCoach;

  @override
  State<TeamCalendarScreen> createState() => _TeamCalendarScreenState();
}

class _TeamCalendarScreenState extends State<TeamCalendarScreen> {
  final _trainingService = TrainingService();
  bool _past = false;
  late Stream<List<Training>> _trainings = _streamTrainings();

  // Soupisku potřebuje jen trenér – pro souhrn odpovědí hráčů.
  late final Stream<QuerySnapshot<Map<String, dynamic>>>? _members =
      widget.isCoach ? TeamService().streamTeamMembers(widget.teamId) : null;

  Stream<List<Training>> _streamTrainings() => _trainingService
      .streamTrainings(widget.teamId, isCoach: widget.isCoach, past: _past);

  @override
  Widget build(BuildContext context) {
    final members = _members;

    return Scaffold(
      appBar: AppBar(
        title: Text('Kalendář – ${widget.teamName}'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: const [LogoutButton()],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                  value: false,
                  label: Text('Nadcházející'),
                  icon: Icon(Icons.event),
                ),
                ButtonSegment(
                  value: true,
                  label: Text('Proběhlé'),
                  icon: Icon(Icons.history),
                ),
              ],
              selected: {_past},
              onSelectionChanged: (selection) => setState(() {
                _past = selection.first;
                _trainings = _streamTrainings();
              }),
            ),
          ),
          Expanded(
            child: members == null
                ? _buildList(const {})
                : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: members,
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Center(child: Text('Chyba: ${snapshot.error}'));
                      }
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      return _buildList(playerNames(snapshot.data!.docs));
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: widget.isCoach
          ? FloatingActionButton.extended(
              backgroundColor: Colors.indigo,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text('Trénink'),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TrainingFormScreen(teamId: widget.teamId),
                ),
              ),
            )
          : null,
      bottomNavigationBar: const AppBottomBar(current: AppTab.calendar),
    );
  }

  Widget _buildList(Map<String, String> players) {
    return StreamBuilder<List<Training>>(
      stream: _trainings,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Chyba: ${snapshot.error}'),
            ),
          );
        }

        // Proběhlé tréninky od nejnovějšího.
        final trainings = _past
            ? snapshot.data!.reversed.toList()
            : snapshot.data!;
        if (trainings.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                _past
                    ? 'Zatím tu nejsou žádné proběhlé tréninky.'
                    : widget.isCoach
                        ? 'Žádné naplánované tréninky. Přidej první tlačítkem dole.'
                        : 'Žádné naplánované tréninky.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.black54),
              ),
            ),
          );
        }

        final children = <Widget>[];
        DateTime? lastDay;
        for (final training in trainings) {
          final start = training.startAt;
          final day = DateTime(start.year, start.month, start.day);
          if (day != lastDay) {
            children.add(_DayHeader(formatDayHeader(day)));
            lastDay = day;
          }
          children.add(
            TrainingCard(
              teamId: widget.teamId,
              training: training,
              isCoach: widget.isCoach,
              players: players,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TrainingDetailScreen(
                    teamId: widget.teamId,
                    trainingId: training.id,
                    isCoach: widget.isCoach,
                  ),
                ),
              ),
            ),
          );
        }

        // Spodní odsazení, aby poslední kartu nezakrylo plovoucí tlačítko.
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 88),
          children: children,
        );
      },
    );
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
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
