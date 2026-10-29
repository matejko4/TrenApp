import 'package:flutter_test/flutter_test.dart';
import 'package:tren_app/utils/date_format.dart';

void main() {
  group('formatTime', () {
    test('minuty mají vždy dvě číslice', () {
      expect(formatTime(DateTime(2026, 1, 1, 7, 5)), '7:05');
      expect(formatTime(DateTime(2026, 1, 1, 17, 0)), '17:00');
    });
  });

  group('formatTimeRange', () {
    final start = DateTime(2026, 1, 1, 17, 0);

    test('bez konce ukáže jen začátek', () {
      expect(formatTimeRange(start, null), '17:00');
    });

    test('s koncem ukáže rozsah', () {
      expect(formatTimeRange(start, DateTime(2026, 1, 1, 18, 30)), '17:00–18:30');
    });
  });

  group('formatDate', () {
    test('datum z jiného roku je i s rokem a českým dnem v týdnu', () {
      expect(formatDate(DateTime(2025, 10, 13)), 'pondělí 13. 10. 2025');
    });

    test('letošní datum je bez roku', () {
      final now = DateTime.now();
      final text = formatDate(DateTime(now.year, 3, 2));
      expect(text, endsWith(' 2. 3.'));
      expect(text, isNot(contains('${now.year}')));
    });
  });

  group('formatDayHeader', () {
    final now = DateTime.now();
    DateTime day(int offset) => DateTime(now.year, now.month, now.day + offset);

    test('dnes, zítra a včera jsou pojmenované', () {
      expect(formatDayHeader(day(0)), startsWith('Dnes · '));
      expect(formatDayHeader(day(1)), startsWith('Zítra · '));
      expect(formatDayHeader(day(-1)), startsWith('Včera · '));
    });

    test('ostatní dny jsou jen datum', () {
      expect(formatDayHeader(day(3)), formatDate(day(3)));
    });
  });
}
