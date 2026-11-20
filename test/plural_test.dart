import 'package:flutter_test/flutter_test.dart';
import 'package:tren_app/utils/plural.dart';

void main() {
  test('tvar slova odpovídá počtu', () {
    String players(int n) => czechCount(n, 'hráč', 'hráči', 'hráčů');
    expect(players(0), '0 hráčů');
    expect(players(1), '1 hráč');
    expect(players(2), '2 hráči');
    expect(players(4), '4 hráči');
    expect(players(5), '5 hráčů');
    expect(players(12), '12 hráčů');
  });
}
