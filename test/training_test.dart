import 'package:flutter_test/flutter_test.dart';
import 'package:tren_app/services/training_service.dart';

Training makeTraining({
  String kind = TrainingKind.individual,
  required DateTime startAt,
  List<String> assignedTo = const ['hrac'],
  Map<String, String> responses = const {},
}) {
  return Training(
    id: 't1',
    kind: kind,
    title: 'Běh 5 km',
    type: TrainingType.run,
    startAt: startAt,
    assignedTo: assignedTo,
    responses: responses,
  );
}

void main() {
  final now = DateTime.now();
  final yesterday = DateTime(now.year, now.month, now.day - 1, 17);
  final todayEarly = DateTime(now.year, now.month, now.day, 0, 1);

  group('TrainingType.fromName', () {
    test('převede uložený název na typ', () {
      expect(TrainingType.fromName('run'), TrainingType.run);
      expect(TrainingType.fromName('strength'), TrainingType.strength);
    });

    test('neznámý nebo chybějící typ je „Ostatní“', () {
      expect(TrainingType.fromName('golf'), TrainingType.other);
      expect(TrainingType.fromName(null), TrainingType.other);
    });
  });

  group('Společný trénink – BUDU / NEBUDU', () {
    test('na trénink, který ještě nezačal, jde odpovídat', () {
      final training = makeTraining(
        kind: TrainingKind.team,
        startAt: now.add(const Duration(hours: 1)),
      );
      expect(training.isTeam, isTrue);
      expect(training.canRespond, isTrue);
    });

    test('po začátku tréninku už odpovídat nejde', () {
      final training = makeTraining(
        kind: TrainingKind.team,
        startAt: now.subtract(const Duration(hours: 1)),
      );
      expect(training.canRespond, isFalse);
    });
  });

  group('Individuální trénink – stav hráče', () {
    test('dnešní trénink bez splnění je naplánovaný (splnit jde do půlnoci)', () {
      final training = makeTraining(startAt: todayEarly);
      expect(training.isOver, isFalse);
      expect(training.statusOf('hrac'), IndividualStatus.planned);
    });

    test('splněný trénink je splněný, i když už jeho den uplynul', () {
      final training = makeTraining(
        startAt: yesterday,
        responses: {'hrac': TrainingResponse.done},
      );
      expect(training.statusOf('hrac'), IndividualStatus.done);
    });

    test('po uplynutí dne bez splnění je trénink nesplněný', () {
      final training = makeTraining(startAt: yesterday);
      expect(training.isOver, isTrue);
      expect(training.statusOf('hrac'), IndividualStatus.missed);
    });

    test('splnění jiného hráče stav neovlivní', () {
      final training = makeTraining(
        startAt: yesterday,
        assignedTo: ['hrac', 'hrac2'],
        responses: {'hrac2': TrainingResponse.done},
      );
      expect(training.statusOf('hrac'), IndividualStatus.missed);
      expect(training.statusOf('hrac2'), IndividualStatus.done);
    });
  });
}
