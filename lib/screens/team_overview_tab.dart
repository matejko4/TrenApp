import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/training_service.dart';
import '../theme/app_theme.dart';
import '../utils/date_format.dart';
import '../utils/error_text.dart';
import '../widgets/common.dart';
import '../widgets/training_widgets.dart';

/// Záložka „Přehled“ v detailu týmu:
///  - barevná hlavička týmu [header] (role, počet členů, kód týmu),
///  - nejbližší akce ve velké kartě s odpočtem („za 2 h 15 min“),
///  - tři čísla za tento týden (počet akcí, účast / odpovědi, splnění),
///  - další 3 akce v kompaktních řádcích a odkaz na celý kalendář.
///
/// Akce jsou stejné, jaké uživatel vidí v kalendáři – hráč jen společné
/// akce a svoje individuální tréninky.
class TeamOverviewTab extends StatefulWidget {
  const TeamOverviewTab({
    super.key,
    required this.teamId,
    required this.isCoach,
    required this.players,
    required this.onOpenCalendar,
    required this.header,
  });

  final String teamId;
  final bool isCoach;

  /// Hráči týmu (uid -> jméno) – pro trenérský souhrn odpovědí a čísla.
  final Map<String, String> players;

  /// Přepne na záložku Kalendář.
  final VoidCallback onOpenCalendar;

  /// Hlavička týmu nahoře v přehledu.
  final Widget header;

  @override
  State<TeamOverviewTab> createState() => _TeamOverviewTabState();
}

// AutomaticKeepAliveClientMixin: záložka si při přepnutí na jinou záložku
// nechá svůj stav (načtená data i pozici posunutí) a nenačítá se znovu.
class _TeamOverviewTabState extends State<TeamOverviewTab>
    with AutomaticKeepAliveClientMixin {
  final _trainingService = TrainingService();
  late final Stream<List<Training>> _upcoming = _trainingService.streamUpcoming(
    widget.teamId,
    isCoach: widget.isCoach,
  );

  late final DateTime _weekStart = startOfWeek(DateTime.now());
  late final Stream<List<Training>> _thisWeek = _trainingService
      .streamTrainingsBetween(
        widget.teamId,
        isCoach: widget.isCoach,
        from: _weekStart,
        to: DateTime(_weekStart.year, _weekStart.month, _weekStart.day + 7),
      );

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return StreamBuilder<List<Training>>(
      stream: _upcoming,
      builder: (context, upcomingSnapshot) {
        if (upcomingSnapshot.hasError) {
          return Center(child: Text(errorText(upcomingSnapshot.error!)));
        }
        if (!upcomingSnapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        // Akce, které ještě neskončily (začnou později, nebo právě běží).
        final now = DateTime.now();
        final upcoming = upcomingSnapshot.data!
            .where(
              (t) => t.startAt.isAfter(now) || (t.endAt?.isAfter(now) ?? false),
            )
            .toList();
        final next = upcoming.firstOrNull;
        final further = upcoming.skip(1).take(3).toList();

        return StreamBuilder<List<Training>>(
          stream: _thisWeek,
          builder: (context, weekSnapshot) {
            // Spodní odsazení, aby obsah nezakrylo plovoucí tlačítko.
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
              children: [
                widget.header,
                const SizedBox(height: 12),
                const SectionTitle('Nejbližší akce'),
                const SizedBox(height: 4),
                if (next == null)
                  _EmptyCard(
                    text: widget.isCoach
                        ? 'Žádná naplánovaná akce. Přidej ji tlačítkem dole.'
                        : 'Žádná naplánovaná akce.',
                  )
                else
                  _NextEventCard(
                    teamId: widget.teamId,
                    training: next,
                    isCoach: widget.isCoach,
                    players: widget.players,
                  ),
                const SizedBox(height: 16),
                const SectionTitle('Tento týden'),
                const SizedBox(height: 4),
                _buildStats(weekSnapshot.data),
                if (further.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const SectionTitle('Další akce'),
                  const SizedBox(height: 4),
                  for (final training in further)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _CompactEventTile(
                        teamId: widget.teamId,
                        training: training,
                        isCoach: widget.isCoach,
                      ),
                    ),
                ],
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: widget.onOpenCalendar,
                    icon: const Icon(Icons.calendar_month, size: 18),
                    label: const Text('Celý kalendář'),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Tři dlaždice s čísly za tento týden. Dokud se týden nenačte ([week]
  /// je null), ukazují pomlčku.
  ///
  /// Trenér: počet akcí, potvrzená účast na společných akcích (kolik
  /// odpovědí BUDU ze všech možných) a splněné individuální tréninky.
  /// Hráč: počet akcí, na kolik společných akcí už odpověděl a kolik
  /// svých individuálních tréninků splnil.
  Widget _buildStats(List<Training>? week) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final team = week?.where((t) => t.isTeam).toList() ?? const [];
    final individual = week?.where((t) => !t.isTeam).toList() ?? const [];

    final String second;
    final String third;
    if (week == null) {
      second = '–';
      third = '–';
    } else if (widget.isCoach) {
      final players = widget.players.keys;
      var yes = 0;
      for (final training in team) {
        yes += players
            .where((id) => training.responses[id] == TrainingResponse.yes)
            .length;
      }
      final possible = team.length * players.length;
      second = possible == 0 ? '–' : '${(yes * 100 / possible).round()} %';

      // Hráči, kteří mezitím z týmu odešli, se nepočítají.
      var assigned = 0;
      var done = 0;
      for (final training in individual) {
        final current = training.assignedTo
            .where(widget.players.containsKey)
            .toList();
        assigned += current.length;
        done += current
            .where((id) => training.statusOf(id) == IndividualStatus.done)
            .length;
      }
      third = '$done/$assigned';
    } else {
      final answered = team.where((t) => t.responses[uid] != null).length;
      second = '$answered/${team.length}';
      final done = individual
          .where((t) => t.statusOf(uid) == IndividualStatus.done)
          .length;
      third = '$done/${individual.length}';
    }

    return Row(
      children: [
        Expanded(
          child: _StatTile(
            icon: Icons.event,
            color: AppColors.team,
            value: week == null ? '–' : '${week.length}',
            label: 'Akcí',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatTile(
            icon: widget.isCoach ? Icons.groups : Icons.how_to_reg,
            color: AppColors.success,
            value: second,
            label: widget.isCoach ? 'Účast' : 'Odpovězeno',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatTile(
            icon: Icons.task_alt,
            color: AppColors.individual,
            value: third,
            label: 'Splněno',
          ),
        ),
      ],
    );
  }
}

/// Velká karta nejbližší akce – kdy (s odpočtem), co, kde a pod tím
/// odpovědi (hráč) nebo souhrn odpovědí (trenér). Je jemně podbarvená
/// barvou druhu akce.
class _NextEventCard extends StatelessWidget {
  const _NextEventCard({
    required this.teamId,
    required this.training,
    required this.isCoach,
    required this.players,
  });

  final String teamId;
  final Training training;
  final bool isCoach;
  final Map<String, String> players;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final color = trainingColor(training);
    final place = training.place;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => openTrainingDetail(
          context,
          teamId: teamId,
          training: training,
          isCoach: isCoach,
        ),
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withValues(alpha: 0.16),
                color.withValues(alpha: 0),
              ],
            ),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _Pill(text: formatDayHeader(training.startAt), color: color),
                  _Pill(
                    text: formatCountdown(training.startAt),
                    color: color,
                    icon: Icons.timer_outlined,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  IconBadge(
                    icon: trainingTypeIcon(training.type),
                    size: 52,
                    color: color,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      training.title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  TrainingKindChip(training: training),
                ],
              ),
              const SizedBox(height: 12),
              _DetailRow(
                icon: Icons.schedule,
                text: formatTimeRange(training.startAt, training.endAt),
              ),
              if (place != null) _DetailRow(icon: Icons.place, text: place),
              const SizedBox(height: 12),
              Divider(color: colors.outlineVariant),
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

/// Malý barevný štítek, např. „Dnes · pátek 20. 11.“ nebo „za 2 h“.
class _Pill extends StatelessWidget {
  const _Pill({required this.text, required this.color, this.icon});

  final String text;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final foreground = AppColors.readable(context, color);
    final icon = this.icon;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.25 : 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: foreground),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: TextStyle(
              color: foreground,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: colors.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: TextStyle(color: colors.onSurfaceVariant)),
          ),
        ],
      ),
    );
  }
}

/// Dlaždice s jedním číslem – ikona, velká hodnota a popisek.
class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final Color color;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IconBadge(icon: icon, size: 32, color: color),
            const SizedBox(height: 10),
            // FittedBox – delší hodnota (např. „12/15“) se zmenší, místo
            // aby přetekla z úzké dlaždice.
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
            ),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Kompaktní řádek akce – barevný čtvereček s datem, název, čas a místo.
class _CompactEventTile extends StatelessWidget {
  const _CompactEventTile({
    required this.teamId,
    required this.training,
    required this.isCoach,
  });

  final String teamId;
  final Training training;
  final bool isCoach;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = trainingColor(training);
    final foreground = AppColors.readable(context, color);
    final start = training.startAt;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => openTrainingDetail(
          context,
          teamId: teamId,
          training: training,
          isCoach: isCoach,
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 52,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: isDark ? 0.22 : 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      formatWeekdayShort(start),
                      style: TextStyle(fontSize: 11, color: foreground),
                    ),
                    Text(
                      '${start.day}.',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: foreground,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      training.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      [
                        formatTimeRange(start, training.endAt),
                        ?training.place,
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: colors.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Icon(trainingTypeIcon(training.type), color: foreground),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            IconBadge(icon: Icons.event_available, color: colors.primary),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                text,
                style: TextStyle(color: colors.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
