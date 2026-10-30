import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tren_app/utils/error_text.dart';

void main() {
  test('hláška ze služby (AppException) se ukáže tak, jak je', () {
    expect(errorText(const AppException('Zadej e-mail')), 'Zadej e-mail');
  });

  test('chyby kvůli chybějícímu internetu mají jednu českou hlášku', () {
    final offlineErrors = <Object>[
      FirebaseException(
        plugin: 'cloud_firestore',
        code: 'unavailable',
        message: 'Failed to get document because the client is offline.',
      ),
      FirebaseAuthException(code: 'network-request-failed'),
      PlatformException(code: 'network_error'),
    ];
    for (final error in offlineErrors) {
      expect(errorText(error), offlineMessage);
    }
  });

  test('chybějící oprávnění se ukáže česky', () {
    final error = FirebaseException(
      plugin: 'cloud_firestore',
      code: 'permission-denied',
      message: 'The caller does not have permission.',
    );
    expect(errorText(error), 'Na tuto akci nemáš oprávnění.');
  });

  test('ostatní chyby Firebase se ukážou česky s kódem chyby', () {
    final error = FirebaseException(
      plugin: 'cloud_firestore',
      code: 'not-found',
      message: 'No document to update.',
    );
    expect(errorText(error), 'Něco se nepovedlo (not-found).');
  });

  test('neznámá chyba se neukáže anglicky', () {
    expect(errorText(StateError('Bad state')), 'Něco se nepovedlo.');
  });
}
