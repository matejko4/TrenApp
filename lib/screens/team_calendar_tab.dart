import 'package:flutter/material.dart';

import '../services/training_service.dart';
import '../utils/date_format.dart';
import '../utils/error_text.dart';
import '../widgets/common.dart';
import '../widgets/training_widgets.dart';
import '../widgets/week_strip.dart';

/// Které akce kalendář ukazuje (filtr nad časovou osou).
enum _Filter {
  all('Vše'),
  team('Společné'),
  individual('Individuální'),
  match('Zápasy');

  const _Filter(this.label);

  final String label;

  bool matches(Training training) => switch (this) {
    _Filter.all => true,
    _Filter.team => training.isTeam && !training.isMatch,
    _Filter.individual => !training.isTeam,
    _Filter.match => training.isMatch,
  };
}

/// Záložka „Kalendář“ v detailu týmu.
///
/// Nahoře týdenní pás (Po–Ne s tečkami za akce), pod ním filtr podle
/// druhu akce a časová osa celého týdne – každý den s nadpisem a jeho
/// akcemi (vlevo čas, barevná čára podle druhu akce, karta). Do minulých
/// týdnů se jde šipkami v pásu. Klepnutí na den v pásu posune časovou osu
/// na ten den.
///
/// Hráč vidí společné akce a svoje individuální tréninky a přímo tu na ně
/// odpovídá, trenér vidí všechny akce se souhrnem odpovědí.
class TeamCalendarTab extends StatefulWidget {
  const TeamCalendarTab({
    super.key,
    required this.teamId,
    required this.isCoach,
    required this.players,
  });

  final String teamId;
  final bool isCoach;

  /// Hráči týmu (uid -> jméno) – pro trenérský souhrn odpovědí.
  final Map<String, String> players;

  @override
  State<TeamCalendarTab> createState() => _TeamCalendarTabState();
}

class _TeamCalendarTabState extends State<TeamCalendarTab>
    with AutomaticKeepAliveClientMixin {
  final _trainingService = TrainingService();

  late DateTime _weekStart = startOfWeek(_today);
  late DateTime _selectedDay = _today;
  late Stream<List<Training>> _trainings = _streamWeek();
  _Filter _filter = _Filter.all;

  /// Klíč u nadpisu každého dne – podle něj se časová osa posune na
  /// vybraný den (Scrollable.ensureVisible).
  final _dayKeys = <DateTime, GlobalKey>{};

  /// Po načtení týdne se časová osa jednou sama posune na vybraný den.
  bool _scrollPending = true;

  @override
  bool get wantKeepAlive => true;

  DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  Stream<List<Training>> _streamWeek() =>
      _trainingService.streamTrainingsBetween(
        widget.teamId,
        isCoach: widget.isCoach,
        from: _weekStart,
        to: DateTime(_weekStart.year, _weekStart.month, _weekStart.day + 7),
      );

  /// Přepne na týden začínající pondělím [monday] a vybere v něm dnešek
  /// (je-li v něm), jinak pondělí.
  void _showWeek(DateTime monday) {
    setState(() {
      _weekStart = monday;
      _selectedDay = startOfWeek(_today) == monday ? _today : monday;
      _trainings = _streamWeek();
      _scrollPending = true;
    });
  }

  void _shiftWeek(int offset) => _showWeek(
    DateTime(_weekStart.year, _weekStart.month, _weekStart.day + 7 * offset),
  );

  void _selectDay(DateTime day) {
    setState(() => _selectedDay = day);
    _scrollToDay(day);
  }

  void _scrollToDay(DateTime day) {
    final context = _dayKeys[day]?.currentContext;
    if (context == null) return;
    Scrollable.ensureVisible(
      context,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isThisWeek = startOfWeek(_today) == _weekStart;

    return StreamBuilder<List<Training>>(
      stream: _trainings,
      builder: (context, snapshot) {
        // Po přepnutí týdne nezobrazovat akce z předchozího týdne.
        final loading = snapshot.connectionState == ConnectionState.waiting;
        final trainings = loading
            ? const <Training>[]
            : (snapshot.data ?? const <Training>[])
                  .where(_filter.matches)
                  .toList();

        if (!loading && _scrollPending) {
          _scrollPending = false;
          // Až po vykreslení – teprve pak mají nadpisy dnů svou pozici.
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => _scrollToDay(_selectedDay),
          );
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: WeekStrip(
                weekStart: _weekStart,
                trainings: trainings,
                selectedDay: _selectedDay,
                onDayTap: _selectDay,
                onPreviousWeek: () => _shiftWeek(-1),
                onNextWeek: () => _shiftWeek(1),
                onToday: isThisWeek
                    ? null
                    : () => _showWeek(startOfWeek(_today)),
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
              child: Row(
                children: [
                  for (final filter in _Filter.values)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(filter.label),
                        selected: _filter == filter,
                        showCheckmark: false,
                        onSelected: (_) => setState(() => _filter = filter),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: snapshot.hasError
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(errorText(snapshot.error!)),
                      ),
                    )
                  : loading
                  ? const Center(child: CircularProgressIndicator())
                  : _buildTimeline(trainings),
            ),
          ],
        );
      },
    );
  }

  /// Časová osa celého týdne – všech 7 dní, i ty bez akcí (aby šlo na
  /// každý den v pásu „skočit“).
  ///
  /// SingleChildScrollView (ne ListView) vykreslí hned všechny dny, takže
  /// posun na den funguje, i když je den zatím mimo obrazovku.
  Widget _buildTimeline(List<Training> trainings) {
    _dayKeys.clear();

    return SingleChildScrollView(
      // Spodní odsazení, aby poslední kartu nezakrylo plovoucí tlačítko.
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < 7; i++)
            ..._buildDay(
              DateTime(_weekStart.year, _weekStart.month, _weekStart.day + i),
              trainings,
            ),
        ],
      ),
    );
  }

  /// Nadpis dne a jeho akce (nebo „Žádná akce“).
  List<Widget> _buildDay(DateTime day, List<Training> trainings) {
    final colors = Theme.of(context).colorScheme;
    final key = _dayKeys[day] = GlobalKey();
    final dayTrainings = trainings
        .where(
          (t) =>
              t.startAt.year == day.year &&
              t.startAt.month == day.month &&
              t.startAt.day == day.day,
        )
        .toList();

    return [
      SectionTitle(
        formatDayHeader(day),
        key: key,
        padding: const EdgeInsets.fromLTRB(4, 16, 4, 6),
      ),
      if (dayTrainings.isEmpty)
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Text(
            'Žádná akce',
            style: TextStyle(color: colors.onSurfaceVariant),
          ),
        ),
      for (final training in dayTrainings)
        _TimelineEntry(
          teamId: widget.teamId,
          training: training,
          isCoach: widget.isCoach,
          players: widget.players,
        ),
    ];
  }
}

/// Jedna akce na časové ose: vlevo začátek a konec, pak svislá čára
/// v barvě druhu akce a vedle karta akce.
class _TimelineEntry extends StatelessWidget {
  const _TimelineEntry({
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
    final end = training.endAt;

    // IntrinsicHeight – čára vlevo je stejně vysoká jako karta vedle ní.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 46,
            child: Padding(
              padding: const EdgeInsets.only(top: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    formatTime(training.startAt),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  if (end != null)
                    Text(
                      formatTime(end),
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
          ),
          Container(
            width: 4,
            margin: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: trainingColor(training),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: TrainingCard(
              teamId: teamId,
              training: training,
              isCoach: isCoach,
              players: players,
              compact: true,
              onTap: () => openTrainingDetail(
                context,
                teamId: teamId,
                training: training,
                isCoach: isCoach,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
