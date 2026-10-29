import 'package:flutter/material.dart';

import '../services/training_service.dart';
import '../utils/date_format.dart';

/// Malý týdenní kalendář – dny pod sebou (Po–Ne) a u každého dne tečka
/// za každý trénink (modrá = společný, zelená = individuální). Šipkami
/// se přepíná týden, klepnutí na den volá [onDayTap].
class WeekCalendar extends StatelessWidget {
  const WeekCalendar({
    super.key,
    required this.weekStart,
    required this.trainings,
    required this.onPreviousWeek,
    required this.onNextWeek,
    required this.onDayTap,
  });

  /// Pondělí zobrazeného týdne (o půlnoci).
  final DateTime weekStart;
  final List<Training> trainings;
  final VoidCallback onPreviousWeek;
  final VoidCallback onNextWeek;
  final ValueChanged<DateTime> onDayTap;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return Card.outlined(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Row(
            children: [
              _arrow(Icons.chevron_left, 'Předchozí týden', onPreviousWeek),
              Expanded(
                child: Text(
                  formatWeekRange(weekStart),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              _arrow(Icons.chevron_right, 'Další týden', onNextWeek),
            ],
          ),
          for (var i = 0; i < 7; i++)
            _buildDay(
              DateTime(weekStart.year, weekStart.month, weekStart.day + i),
              today,
            ),
        ],
      ),
    );
  }

  Widget _arrow(IconData icon, String tooltip, VoidCallback onPressed) {
    return IconButton(
      icon: Icon(icon, size: 20),
      tooltip: tooltip,
      onPressed: onPressed,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
    );
  }

  Widget _buildDay(DateTime day, DateTime today) {
    final isToday = day == today;
    final dayTrainings = trainings
        .where((t) =>
            t.startAt.year == day.year &&
            t.startAt.month == day.month &&
            t.startAt.day == day.day)
        .toList();

    return InkWell(
      key: ValueKey('week-day-${day.month}-${day.day}'),
      onTap: () => onDayTap(day),
      child: Container(
        color: isToday ? Colors.indigo.withValues(alpha: 0.08) : null,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          children: [
            SizedBox(
              width: 22,
              child: Text(
                formatWeekdayShort(day),
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ),
            SizedBox(
              width: 30,
              child: Text(
                '${day.day}.',
                style: TextStyle(
                  fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                  color: isToday ? Colors.indigo : null,
                ),
              ),
            ),
            Expanded(
              child: Wrap(
                spacing: 3,
                runSpacing: 3,
                children: [
                  for (final training in dayTrainings)
                    TrainingDot(isTeam: training.isTeam),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tečka za jeden trénink v týdenním kalendáři.
class TrainingDot extends StatelessWidget {
  const TrainingDot({super.key, required this.isTeam});

  final bool isTeam;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: isTeam ? Colors.indigo : Colors.teal,
        shape: BoxShape.circle,
      ),
    );
  }
}
