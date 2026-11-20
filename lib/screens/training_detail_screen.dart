import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/run_service.dart';
import '../services/team_service.dart';
import '../services/training_service.dart';
import '../theme/app_theme.dart';
import '../utils/date_format.dart';
import '../utils/error_text.dart';
import '../widgets/common.dart';
import '../widgets/run_widgets.dart';
import '../widgets/training_widgets.dart';
import 'run_detail_screen.dart';
import 'training_form_screen.dart';

/// Detail tréninku. Hráč tu vidí zadání a odpovídá, trenér vidí jmenovitý
/// přehled odpovědí (kdo přijde / nepřijde / neodpověděl, u individuálního
/// tréninku kdo ho splnil) a může trénink upravit nebo smazat.
///
/// U běhu hráč vidí svůj zaznamenaný běh a trenér si klepnutím na hráče
/// otevře mapu jeho trasy.
class TrainingDetailScreen extends StatefulWidget {
  const TrainingDetailScreen({
    super.key,
    required this.teamId,
    required this.trainingId,
    required this.isCoach,
  });

  final String teamId;
  final String trainingId;
  final bool isCoach;

  @override
  State<TrainingDetailScreen> createState() => _TrainingDetailScreenState();
}

class _TrainingDetailScreenState extends State<TrainingDetailScreen> {
  final _trainingService = TrainingService();
  late final Stream<Training?> _training = _trainingService.streamTraining(
    widget.teamId,
    widget.trainingId,
  );
  late final Stream<QuerySnapshot<Map<String, dynamic>>>? _members =
      widget.isCoach ? TeamService().streamTeamMembers(widget.teamId) : null;
  // Hráčův vlastní běh (jen jeden dokument). Trenér běhy předem nenačítá –
  // každý nese celou trasu, otevírají se až po klepnutí na hráče.
  late final Stream<Run?>? _myRun = widget.isCoach
      ? null
      : RunService().streamMyRun(widget.teamId, widget.trainingId);
  bool _deleting = false;

  Future<void> _delete(Training training) async {
    final confirmed = await confirmDialog(
      context,
      title: training.isMatch ? 'Smazat zápas' : 'Smazat trénink',
      message:
          'Opravdu chceš smazat ${training.isMatch ? 'zápas' : 'trénink'} '
          '"${training.title}"?',
      confirmLabel: 'Smazat',
    );
    if (!confirmed) return;

    setState(() => _deleting = true);
    try {
      await _trainingService.deleteTraining(widget.teamId, training.id);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _deleting = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(errorText(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Training?>(
      stream: _training,
      builder: (context, snapshot) {
        final training = snapshot.data;

        final Widget body;
        if (snapshot.connectionState == ConnectionState.waiting || _deleting) {
          body = const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          body = Center(child: Text(errorText(snapshot.error!)));
        } else if (training == null) {
          body = const Center(child: Text('Trénink byl smazán.'));
        } else {
          body = _buildBody(training);
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(training?.title ?? 'Trénink'),
            actions: [
              if (widget.isCoach && training != null) ...[
                IconButton(
                  icon: const Icon(Icons.edit),
                  tooltip: 'Upravit trénink',
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => TrainingFormScreen(
                        teamId: widget.teamId,
                        training: training,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete),
                  tooltip: 'Smazat trénink',
                  onPressed: _deleting ? null : () => _delete(training),
                ),
              ],
            ],
          ),
          body: body,
        );
      },
    );
  }

  Widget _buildBody(Training training) {
    final place = training.place;
    final description = training.description;
    final members = _members;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            IconBadge(
              icon: trainingTypeIcon(training.type),
              size: 52,
              color: trainingColor(training),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                training.title,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            TrainingKindChip(training: training),
          ],
        ),
        const SizedBox(height: 16),
        // Údaje o tréninku v jedné kartě.
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Column(
              children: [
                _InfoTile(
                  icon: Icons.event,
                  text: formatDate(training.startAt),
                ),
                _InfoTile(
                  icon: Icons.schedule,
                  text: formatTimeRange(training.startAt, training.endAt),
                ),
                _InfoTile(
                  icon: trainingTypeIcon(training.type),
                  text: training.type.label,
                ),
                if (place != null) _InfoTile(icon: Icons.place, text: place),
                if (description != null)
                  _InfoTile(icon: Icons.notes, text: description),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        if (members == null) ...[
          TrainingPlayerActions(teamId: widget.teamId, training: training),
          if (_isRun(training)) _buildMyRun(),
        ] else
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: members,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final players = playerNames(snapshot.data!.docs);
              return training.isTeam
                  ? _buildTeamOverview(training, players)
                  : _buildIndividualOverview(training, players);
            },
          ),
      ],
    );
  }

  /// Kdo na společný trénink přijde, nepřijde a kdo ještě neodpověděl.
  Widget _buildTeamOverview(Training training, Map<String, String> players) {
    List<String> namesWith(TrainingResponse response) => [
      for (final entry in players.entries)
        if (training.responses[entry.key] == response) entry.value,
    ]..sort();

    final yes = namesWith(TrainingResponse.yes);
    final no = namesWith(TrainingResponse.no);
    final none = [
      for (final entry in players.entries)
        if (training.responses[entry.key] != TrainingResponse.yes &&
            training.responses[entry.key] != TrainingResponse.no)
          entry.value,
    ]..sort();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _NameSection(
          title: 'Přijdou (${yes.length})',
          label: teamResponseLabel(TrainingResponse.yes),
          names: yes,
        ),
        _NameSection(
          title: 'Nepřijdou (${no.length})',
          label: teamResponseLabel(TrainingResponse.no),
          names: no,
        ),
        _NameSection(
          title: 'Bez odpovědi (${none.length})',
          label: teamResponseLabel(null),
          names: none,
        ),
      ],
    );
  }

  /// Individuální běh – jen u něj můžou existovat záznamy z GPS.
  bool _isRun(Training training) =>
      !training.isTeam && training.type == TrainingType.run;

  void _openRun(String uid, String title) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RunDetailScreen(
          teamId: widget.teamId,
          trainingId: widget.trainingId,
          uid: uid,
          title: title,
        ),
      ),
    );
  }

  /// Karta „Můj běh“ – hráčův zaznamenaný běh (i offline z telefonu).
  /// Když běh nemá (zatím neběžel, nebo trénink splnil ručně), nic se
  /// nezobrazí.
  Widget _buildMyRun() {
    return StreamBuilder<Run?>(
      stream: _myRun,
      builder: (context, snapshot) {
        final run = snapshot.data;
        if (run == null) return const SizedBox.shrink();
        return Card.outlined(
          margin: const EdgeInsets.only(top: 16),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionTitle('Můj běh'),
                    const SizedBox(height: 8),
                    RunStats(run: run),
                  ],
                ),
              ),
              SizedBox(
                height: 180,
                child: RunMap(run: run, interactive: false),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  icon: const Icon(Icons.map),
                  label: const Text('Zobrazit trasu'),
                  onPressed: () => _openRun(
                    FirebaseAuth.instance.currentUser!.uid,
                    'Můj běh',
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Stav individuálního tréninku u každého hráče, kterému je zadaný.
  /// U běhu jde řádek hráče otevřít – mapa a údaje o jeho běhu.
  Widget _buildIndividualOverview(
    Training training,
    Map<String, String> players,
  ) {
    // Hráči, kteří mezitím z týmu odešli, se nezobrazují.
    final assigned = training.assignedTo.where(players.containsKey).toList()
      ..sort((a, b) => players[a]!.compareTo(players[b]!));
    final isRun = _isRun(training);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle('Hráči (${assigned.length})'),
        for (final uid in assigned)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const RoleAvatar(isCoach: false),
            title: Text(players[uid]!),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                individualStatusLabel(training.statusOf(uid)),
                if (isRun) const Icon(Icons.chevron_right),
              ],
            ),
            onTap: isRun ? () => _openRun(uid, players[uid]!) : null,
          ),
      ],
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: IconBadge(
        icon: icon,
        size: 36,
        color: Theme.of(context).colorScheme.primary,
      ),
      title: Text(text),
    );
  }
}

/// Nadpis skupiny (např. „Přijdou (3)“) a jména hráčů v ní.
class _NameSection extends StatelessWidget {
  const _NameSection({
    required this.title,
    required this.label,
    required this.names,
  });

  final String title;
  final TrainingStatusLabel label;
  final List<String> names;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(title),
        if (names.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'Nikdo',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        for (final name in names)
          ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            leading: Icon(label.icon, color: label.color),
            title: Text(name),
          ),
      ],
    );
  }
}
