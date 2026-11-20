import 'package:flutter_test/flutter_test.dart';
import 'package:tren_app/services/run_service.dart';
import 'package:tren_app/services/run_tracker.dart';

/// 0,001° zeměpisné šířky je zhruba 111 m.
const step = 0.001;
const metersPerStep = 111.3;

void main() {
  late DateTime clock;
  late RunTracker tracker;

  void wait(int seconds) => clock = clock.add(Duration(seconds: seconds));

  setUp(() {
    clock = DateTime(2026, 11, 16, 17);
    tracker = RunTracker(now: () => clock);
  });

  test('počítá aktivní čas a vzdálenost mezi body', () {
    tracker.start();
    tracker.addPosition(50, 14, 5);
    wait(30);
    tracker.addPosition(50 + step, 14, 5);
    wait(30);
    tracker.addPosition(50 + 2 * step, 14, 5);

    expect(tracker.state, RunState.running);
    expect(tracker.activeSeconds, 60);
    expect(tracker.distanceMeters, closeTo(2 * metersPerStep, 1));
    expect(tracker.points.map((p) => p.t), [0, 30, 60]);
  });

  test('nepřesné body (přes 25 m) se zahodí', () {
    tracker.start();
    tracker.addPosition(50, 14, 80);
    expect(tracker.hasFix, isFalse);

    tracker.addPosition(50, 14, 10);
    tracker.addPosition(50.05, 14, 60); // „skok“ o 5 km
    tracker.addPosition(50 + step, 14, 10);

    expect(tracker.hasFix, isTrue);
    expect(tracker.points, hasLength(2));
    expect(tracker.distanceMeters, closeTo(metersPerStep, 1));
  });

  test(
    'pauza zastaví čas, body během ní se ignorují a úsek přes pauzu se nepočítá',
    () {
      tracker.start();
      tracker.addPosition(50, 14, 5);
      wait(60);
      tracker.addPosition(50 + step, 14, 5);

      tracker.pause();
      wait(300);
      tracker.addPosition(50 + 5 * step, 14, 5);
      expect(tracker.activeSeconds, 60);

      tracker.resume();
      tracker.addPosition(50 + 10 * step, 14, 5); // jinde než před pauzou
      wait(60);
      tracker.addPosition(50 + 11 * step, 14, 5);

      expect(tracker.activeSeconds, 120);
      expect(tracker.distanceMeters, closeTo(2 * metersPerStep, 1));
      expect(tracker.points.map((p) => p.s), [0, 0, 1, 1]);
    },
  );

  test('po ukončení vrátí běh s celými čísly pro databázi', () {
    tracker.start();
    tracker.addPosition(50, 14, 5);
    wait(90);
    tracker.addPosition(50 + step, 14, 5);
    tracker.pause();
    wait(30);
    tracker.finish();

    expect(tracker.state, RunState.finished);
    final run = tracker.toRun();
    expect(run.durationSeconds, 90);
    expect(run.distanceMeters, 111);
    expect(run.startedAt, DateTime(2026, 11, 16, 17));
    expect(run.endedAt, DateTime(2026, 11, 16, 17, 2));

    final map = run.toMap();
    expect(map['durationSeconds'], isA<int>());
    expect(map['distanceMeters'], isA<int>());
    expect((map['points'] as List).first, {
      'lat': 50.0,
      'lng': 14.0,
      't': 0,
      's': 0,
    });
  });

  test('neukončený běh nejde uložit', () {
    tracker.start();
    expect(tracker.toRun, throwsStateError);
  });

  group('Run', () {
    Run runWith(List<RunPoint> points) => Run(
      startedAt: DateTime(2026),
      endedAt: DateTime(2026),
      durationSeconds: 0,
      distanceMeters: 0,
      points: points,
    );
    RunPoint point(int s) => RunPoint(lat: 50, lng: 14, t: 0, s: s);

    test('rozdělí body na úseky a spočítá pauzy', () {
      final run = runWith([point(0), point(0), point(1), point(2), point(2)]);
      expect(run.segments.map((segment) => segment.length), [2, 1, 2]);
      expect(run.pauseCount, 2);
    });

    test('běh bez bodů nemá úseky ani pauzy', () {
      final run = runWith([]);
      expect(run.segments, isEmpty);
      expect(run.pauseCount, 0);
    });

    test('bod z databáze přečte i celá čísla jako souřadnice', () {
      final point = RunPoint.fromMap({'lat': 50, 'lng': 14.5, 't': 3, 's': 0});
      expect(point.lat, 50.0);
      expect(point.lng, 14.5);
    });
  });
}
