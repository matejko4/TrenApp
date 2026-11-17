// Formátování údajů o běhu (čas, vzdálenost, tempo) česky.

String _twoDigits(int n) => n.toString().padLeft(2, '0');

/// Doba běhu, např. „28:29“, od hodiny výš „1:05:09“.
String formatDuration(int seconds) {
  final hours = seconds ~/ 3600;
  final minutes = seconds % 3600 ~/ 60;
  final secs = seconds % 60;
  if (hours > 0) return '$hours:${_twoDigits(minutes)}:${_twoDigits(secs)}';
  return '$minutes:${_twoDigits(secs)}';
}

/// Vzdálenost v kilometrech s desetinnou čárkou, např. „5,23 km“.
String formatDistance(num meters) =>
    '${(meters / 1000).toStringAsFixed(2).replaceAll('.', ',')} km';

/// Pod touto vzdáleností tempo nedává smysl (pár metrů za dlouhý čas by
/// ukázalo nesmyslné tempo) – ukazuje se „–“.
const minPaceDistanceMeters = 50;

/// Průměrné tempo (čas na kilometr), např. „5:27 /km“, nebo „–“, když je
/// uběhnutá vzdálenost zatím moc krátká.
String formatPace(int seconds, num meters) {
  if (meters < minPaceDistanceMeters || seconds <= 0) return '–';
  final perKm = (seconds * 1000 / meters).round();
  return '${perKm ~/ 60}:${_twoDigits(perKm % 60)} /km';
}
