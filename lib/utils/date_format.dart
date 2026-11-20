// Formátování data a času česky pro kalendář tréninků.

const _weekdays = [
  'pondělí',
  'úterý',
  'středa',
  'čtvrtek',
  'pátek',
  'sobota',
  'neděle',
];

const _weekdaysShort = ['Po', 'Út', 'St', 'Čt', 'Pá', 'So', 'Ne'];

/// Zkratka dne v týdnu, např. „Po“.
String formatWeekdayShort(DateTime date) => _weekdaysShort[date.weekday - 1];

/// Pondělí týdne, do kterého patří [date] (o půlnoci).
DateTime startOfWeek(DateTime date) =>
    DateTime(date.year, date.month, date.day - (date.weekday - 1));

/// Rozsah týdne od pondělí [monday], např. „2.–8. 11.“, nebo
/// „30. 11.–6. 12.“, když týden přechází do dalšího měsíce.
String formatWeekRange(DateTime monday) {
  final sunday = DateTime(monday.year, monday.month, monday.day + 6);
  final start = monday.month == sunday.month
      ? '${monday.day}.'
      : '${monday.day}. ${monday.month}.';
  return '$start–${sunday.day}. ${sunday.month}.';
}

/// Např. „17:05“.
String formatTime(DateTime time) =>
    '${time.hour}:${time.minute.toString().padLeft(2, '0')}';

/// Např. „17:00–18:30“, nebo jen „17:00“, když konec není zadaný.
String formatTimeRange(DateTime start, DateTime? end) =>
    end == null ? formatTime(start) : '${formatTime(start)}–${formatTime(end)}';

/// Např. „úterý 13. 10.“, u jiného než letošního roku i s rokem.
String formatDate(DateTime date) {
  final year = date.year == DateTime.now().year ? '' : ' ${date.year}';
  return '${_weekdays[date.weekday - 1]} ${date.day}. ${date.month}.$year';
}

/// Nadpis dne v kalendáři – včera, dnes a zítra jsou navíc pojmenované.
String formatDayHeader(DateTime date) {
  final now = DateTime.now();
  final day = DateTime(date.year, date.month, date.day);
  final String prefix;
  if (day == DateTime(now.year, now.month, now.day)) {
    prefix = 'Dnes · ';
  } else if (day == DateTime(now.year, now.month, now.day + 1)) {
    prefix = 'Zítra · ';
  } else if (day == DateTime(now.year, now.month, now.day - 1)) {
    prefix = 'Včera · ';
  } else {
    prefix = '';
  }
  return '$prefix${formatDate(date)}';
}

/// Za jak dlouho akce začne – např. „za 45 min“, „za 2 h 15 min“,
/// „zítra“, „za 3 dny“, „za 12 dní“. Už začatá akce „právě probíhá“.
/// [now] jde zadat kvůli testům, jinak se použije aktuální čas.
String formatCountdown(DateTime start, {DateTime? now}) {
  final current = now ?? DateTime.now();
  final diff = start.difference(current);
  if (diff.isNegative) return 'právě probíhá';
  if (diff.inMinutes < 60) {
    return 'za ${diff.inMinutes < 1 ? 1 : diff.inMinutes} min';
  }

  // Rozdíl v kalendářních dnech (půlnoc–půlnoc). Zaokrouhlení kvůli
  // změně letního času, kdy den nemá přesně 24 hodin.
  final today = DateTime(current.year, current.month, current.day);
  final day = DateTime(start.year, start.month, start.day);
  final days = (day.difference(today).inHours / 24).round();

  if (days == 0) {
    final minutes = diff.inMinutes % 60;
    return 'za ${diff.inHours} h${minutes == 0 ? '' : ' $minutes min'}';
  }
  if (days == 1) return 'zítra';
  return days <= 4 ? 'za $days dny' : 'za $days dní';
}
