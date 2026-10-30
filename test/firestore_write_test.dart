import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:tren_app/utils/firestore_write.dart';

void main() {
  const shortTimeout = Duration(milliseconds: 50);

  test('zápis potvrzený serverem včas vrátí true', () async {
    final sent = await waitForServer(Future<void>.value(), timeout: shortTimeout);
    expect(sent, isTrue);
  });

  test('bez potvrzení (telefon offline) vrátí false a nečeká donekonečna',
      () async {
    final neverConfirmed = Completer<void>().future;
    final sent = await waitForServer(neverConfirmed, timeout: shortTimeout);
    expect(sent, isFalse);
  });

  test('chyba, kterou server vrátí včas, se předá dál', () async {
    final rejected = Future<void>.error(StateError('permission-denied'));
    expect(
      waitForServer(rejected, timeout: shortTimeout),
      throwsA(isA<StateError>()),
    );
  });
}
