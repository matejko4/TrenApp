import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tren_app/services/run_service.dart';
import 'package:tren_app/widgets/run_widgets.dart';

Run makeRun(List<RunPoint> points) => Run(
  startedAt: DateTime(2026, 11, 16, 17, 5),
  endedAt: DateTime(2026, 11, 16, 17, 40),
  durationSeconds: 1709,
  distanceMeters: 5230,
  points: points,
);

Future<void> pump(WidgetTester tester, Widget child) =>
    tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));

void main() {
  testWidgets('údaje o běhu: čas, vzdálenost, tempo, start a pauzy', (
    tester,
  ) async {
    await pump(
      tester,
      RunStats(
        run: makeRun(const [
          RunPoint(lat: 50, lng: 14, t: 0, s: 0),
          RunPoint(lat: 50.01, lng: 14, t: 900, s: 1),
        ]),
      ),
    );

    expect(find.text('28:29'), findsOneWidget);
    expect(find.text('5,23 km'), findsOneWidget);
    expect(find.text('5:27 /km'), findsOneWidget);
    expect(find.textContaining('v 17:05'), findsOneWidget);
    expect(find.textContaining('pauzy: 1'), findsOneWidget);
  });

  testWidgets('běh bez bodů ukáže místo mapy hlášku', (tester) async {
    await pump(tester, SizedBox(height: 300, child: RunMap(run: makeRun([]))));

    expect(
      find.text('Trasa se nezaznamenala (GPS nenašlo signál).'),
      findsOneWidget,
    );
  });
}
