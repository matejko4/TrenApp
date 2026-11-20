import 'package:flutter/material.dart';

import '../services/training_service.dart';
import '../utils/date_format.dart';
import 'training_widgets.dart';

/// Týdenní pás – dny Po–Ne vedle sebe, pod každým dnem barevné tečky za
/// jeho akce (indigo = společný trénink, zelenomodrá = individuální,
/// oranžová = zápas, viz trainingColor).
///
/// Vybraný den [selectedDay] je podbarvený hlavní barvou, dnešek má číslo
/// v hlavní barvě. Šipkami se přepíná týden, tlačítko „Dnes“ (jen když
/// je zadané [onToday]) skočí zpátky na aktuální týden.
class WeekStrip extends StatelessWidget {
  const WeekStrip({
    super.key,
    required this.weekStart,
    required this.trainings,
    required this.selectedDay,
    required this.onDayTap,
    required this.onPreviousWeek,
    required this.onNextWeek,
    this.onToday,
  });

  /// Pondělí zobrazeného týdne (o půlnoci).
  final DateTime weekStart;
  final List<Training> trainings;
  final DateTime? selectedDay;
  final ValueChanged<DateTime> onDayTap;
  final VoidCallback onPreviousWeek;
  final VoidCallback onNextWeek;

  /// Návrat na aktuální týden – null, když je aktuální týden zobrazený.
  final VoidCallback? onToday;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final onToday = this.onToday;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  tooltip: 'Předchozí týden',
                  onPressed: onPreviousWeek,
                ),
                Expanded(
                  child: Text(
                    formatWeekRange(weekStart),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (onToday != null)
                  TextButton(onPressed: onToday, child: const Text('Dnes')),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  tooltip: 'Další týden',
                  onPressed: onNextWeek,
                ),
              ],
            ),
            Row(
              children: [
                for (var i = 0; i < 7; i++)
                  Expanded(
                    child: _buildDay(
                      context,
                      DateTime(
                        weekStart.year,
                        weekStart.month,
                        weekStart.day + i,
                      ),
                      today,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDay(BuildContext context, DateTime day, DateTime today) {
    final colors = Theme.of(context).colorScheme;
    final isToday = day == today;
    final isSelected = day == selectedDay;
    final dayTrainings = trainings
        .where(
          (t) =>
              t.startAt.year == day.year &&
              t.startAt.month == day.month &&
              t.startAt.day == day.day,
        )
        .toList();

    // Na podbarveném (vybraném) dni je všechno bílé / v barvě textu na
    // hlavní barvě, jinak by indigové tečky nebyly vidět.
    final Color? numberColor = isSelected
        ? colors.onPrimary
        : (isToday ? colors.primary : null);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Material(
        color: isSelected ? colors.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          key: ValueKey('week-day-${day.month}-${day.day}'),
          borderRadius: BorderRadius.circular(14),
          onTap: () => onDayTap(day),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              children: [
                Text(
                  formatWeekdayShort(day),
                  style: TextStyle(
                    fontSize: 12,
                    color: isSelected
                        ? colors.onPrimary
                        : colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${day.day}',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: isToday || isSelected
                        ? FontWeight.w800
                        : FontWeight.w600,
                    color: numberColor,
                  ),
                ),
                const SizedBox(height: 4),
                // Nejvýš 3 tečky, aby se vešly i do úzkého sloupce.
                SizedBox(
                  height: 6,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (final training in dayTrainings.take(3))
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 1),
                          child: TrainingDot(
                            color: isSelected
                                ? colors.onPrimary
                                : trainingColor(training),
                          ),
                        ),
                    ],
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

/// Tečka za jednu akci v týdenním pásu.
class TrainingDot extends StatelessWidget {
  const TrainingDot({super.key, required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
