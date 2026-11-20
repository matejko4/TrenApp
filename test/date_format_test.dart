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

  group('Týden', () {
    test('startOfWeek vrátí pondělí téhož týdne', () {
      expect(startOfWeek(DateTime(2026, 11, 4, 17, 30)), DateTime(2026, 11, 2));
      expect(startOfWeek(DateTime(2026, 11, 2)), DateTime(2026, 11, 2));
      expect(startOfWeek(DateTime(2026, 11, 8)), DateTime(2026, 11, 2));
    });

    test('formatWeekRange uvede měsíc jednou, nebo u obou dnů', () {
      expect(formatWeekRange(DateTime(2026, 11, 2)), '2.–8. 11.');
      expect(formatWeekRange(DateTime(2026, 11, 30)), '30. 11.–6. 12.');
    });

    test('formatWeekdayShort vrátí českou zkratku dne', () {
      expect(formatWeekdayShort(DateTime(2026, 11, 2)), 'Po');
      expect(formatWeekdayShort(DateTime(2026, 11, 8)), 'Ne');
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

  group('formatCountdown', () {
    final now = DateTime(2026, 11, 20, 14, 45);

    test('do hodiny v minutách', () {
      expect(formatCountdown(DateTime(2026, 11, 20, 15, 0), now: now), 'za 15 min');
    });

    test('dnes v hodinách a minutách', () {
      expect(formatCountdown(DateTime(2026, 11, 20, 17, 0), now: now), 'za 2 h 15 min');
      expect(formatCountdown(DateTime(2026, 11, 20, 16, 45), now: now), 'za 2 h');
    });

    test('další dny podle kalendáře', () {
      expect(formatCountdown(DateTime(2026, 11, 21, 9, 0), now: now), 'zítra');
      expect(formatCountdown(DateTime(2026, 11, 23, 9, 0), now: now), 'za 3 dny');
      expect(formatCountdown(DateTime(2026, 11, 30, 9, 0), now: now), 'za 10 dní');
    });

    test('začatá akce právě probíhá', () {
      expect(formatCountdown(DateTime(2026, 11, 20, 14, 0), now: now), 'právě probíhá');
    });
  });
}
