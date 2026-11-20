// České tvary slov podle počtu.

/// Počet se slovem ve správném tvaru, např. `czechCount(1, 'hráč',
/// 'hráči', 'hráčů')` → „1 hráč“, pro 3 → „3 hráči“, pro 5 → „5 hráčů“.
String czechCount(int count, String one, String few, String many) {
  final word = switch (count) {
    1 => one,
    >= 2 && <= 4 => few,
    _ => many,
  };
  return '$count $word';
}
