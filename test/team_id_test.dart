import 'package:flutter_test/flutter_test.dart';
import 'package:tren_app/services/team_service.dart';

void main() {
  test('ID týmu z názvu: malá písmena A–Z, bez mezer navíc', () {
    expect(teamIdFromName('SFC Praha'), 'sfc praha');
    expect(teamIdFromName('  SFC   Praha '), 'sfc praha');
  });

  test('diakritika se převádí stejně jako lower() v pravidlech (vůbec)', () {
    expect(teamIdFromName('ČEZ'), 'Čez');
    expect(teamIdFromName('Spárta'), 'spárta');
  });
}
