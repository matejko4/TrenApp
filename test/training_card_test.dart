import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tren_app/services/training_service.dart';
import 'package:tren_app/widgets/training_widgets.dart';

/// Hráči na soupisce týmu (uid -> jméno). Hráč „odesel“ už v týmu není.
const players = {'jan': 'Jan', 'petr': 'Petr', 'eva': 'Eva'};

Future<void> pumpCoachCard(WidgetTester tester, Training training) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: TrainingCard(
          teamId: 'tym1',
          training: training,
          isCoach: true,
          players: players,
        ),
      ),
    ),
  );
}

Training makeTraining({
  required String kind,
  List<String> assignedTo = const [],
  required Map<String, String> responses,
}) {
  return Training(
    id: 't1',
    kind: kind,
    title: 'Trénink',
    type: TrainingType.technique,
    startAt: DateTime.now().add(const Duration(days: 1)),
    assignedTo: assignedTo,
    responses: responses,
  );
}

void main() {
  testWidgets('trenér vidí počty odpovědí jen za současné hráče',
      (tester) async {
    await pumpCoachCard(
      tester,
      makeTraining(kind: TrainingKind.team, responses: {
        'jan': TrainingResponse.yes,
        'petr': TrainingResponse.no,
        'odesel': TrainingResponse.yes,
      }),
    );

    expect(find.text('Společný'), findsOneWidget);
    expect(find.text('Přijde 1'), findsOneWidget);
    expect(find.text('Nepřijde 1'), findsOneWidget);
    expect(find.text('Bez odpovědi 1'), findsOneWidget);
  });

  testWidgets('trenér vidí, komu je individuální trénink zadaný a kolik ho splnilo',
      (tester) async {
    await pumpCoachCard(
      tester,
      makeTraining(
        kind: TrainingKind.individual,
        assignedTo: ['jan', 'eva', 'odesel'],
        responses: {'jan': TrainingResponse.done, 'odesel': TrainingResponse.done},
      ),
    );

    expect(find.text('Individuální'), findsOneWidget);
    expect(find.text('Pro: Jan, Eva'), findsOneWidget);
    expect(find.text('Splněno 1 / 2'), findsOneWidget);
  });

  test('popisky stavů odpovídají odpovědím', () {
    expect(teamResponseLabel(TrainingResponse.yes).label, 'Budu');
    expect(teamResponseLabel(TrainingResponse.no).label, 'Nebudu');
    expect(teamResponseLabel(null).label, 'Bez odpovědi');
    expect(individualStatusLabel(IndividualStatus.planned).label, 'Naplánovaný');
    expect(individualStatusLabel(IndividualStatus.done).label, 'Splněný');
    expect(individualStatusLabel(IndividualStatus.missed).label, 'Nesplněný');
  });
}
