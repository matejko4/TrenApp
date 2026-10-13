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
