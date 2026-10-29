import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tren_app/services/training_service.dart';
import 'package:tren_app/widgets/week_calendar.dart';

Training makeTraining(TrainingKind kind, DateTime startAt) {
  return Training(
    id: '$kind-$startAt',
    kind: kind,
    title: 'Trénink',
    type: TrainingType.other,
    startAt: startAt,
    assignedTo: const [],
    responses: const {},
  );
}

void main() {
  final monday = DateTime(2026, 11, 2);
  DateTime? tappedDay;
  var nextWeekTaps = 0;

  Future<void> pumpCalendar(WidgetTester tester) {
    tappedDay = null;
    nextWeekTaps = 0;
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 132,
            child: WeekCalendar(
              weekStart: monday,
              trainings: [
                makeTraining(TrainingKind.team, DateTime(2026, 11, 4, 17)),
                makeTraining(TrainingKind.individual, DateTime(2026, 11, 4, 19)),
                makeTraining(TrainingKind.team, DateTime(2026, 11, 6, 17)),
              ],
              onPreviousWeek: () {},
              onNextWeek: () => nextWeekTaps++,
              onDayTap: (day) => tappedDay = day,
            ),
          ),
        ),
      ),
    );
  }

  Finder dotsOn(int day) => find.descendant(
        of: find.byKey(ValueKey('week-day-11-$day')),
        matching: find.byType(TrainingDot),
      );

  testWidgets('ukáže týden Po–Ne s rozsahem v záhlaví', (tester) async {
    await pumpCalendar(tester);

    expect(find.text('2.–8. 11.'), findsOneWidget);
    for (final day in ['Po', 'Út', 'St', 'Čt', 'Pá', 'So', 'Ne']) {
      expect(find.text(day), findsOneWidget);
    }
  });

  testWidgets('u každého dne je tečka za každý jeho trénink', (tester) async {
    await pumpCalendar(tester);

    expect(dotsOn(4), findsNWidgets(2));
    expect(dotsOn(6), findsOneWidget);
    expect(dotsOn(3), findsNothing);
  });

  testWidgets('klepnutí na den a na šipku zavolá callback', (tester) async {
    await pumpCalendar(tester);

    await tester.tap(find.byKey(const ValueKey('week-day-11-5')));
    expect(tappedDay, DateTime(2026, 11, 5));

    await tester.tap(find.byTooltip('Další týden'));
    expect(nextWeekTaps, 1);
  });
}
