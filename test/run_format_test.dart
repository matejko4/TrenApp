import 'package:flutter_test/flutter_test.dart';
import 'package:tren_app/utils/run_format.dart';

void main() {
  test('doba běhu v minutách, od hodiny i s hodinami', () {
    expect(formatDuration(0), '0:00');
    expect(formatDuration(1709), '28:29');
    expect(formatDuration(3909), '1:05:09');
  });

  test('vzdálenost v km s desetinnou čárkou', () {
    expect(formatDistance(5230), '5,23 km');
    expect(formatDistance(0), '0,00 km');
    expect(formatDistance(12345.6), '12,35 km');
  });

  test('tempo na kilometr, u krátké vzdálenosti pomlčka', () {
    expect(formatPace(1709, 5230), '5:27 /km');
    expect(formatPace(300, 1000), '5:00 /km');
    expect(formatPace(60, 30), '–');
    expect(formatPace(0, 1000), '–');
  });
}
