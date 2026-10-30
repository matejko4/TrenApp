import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Chyba, kterou služby hlásí uživateli. [message] je česká hláška,
/// která se v aplikaci zobrazí tak, jak je (viz [errorText]).
///
/// Služby ji používají pro vlastní kontroly („Zadej název týmu“) i pro
/// chyby Firebase, které umí přeložit podle situace (AuthService).
class AppException implements Exception {
  const AppException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Hláška pro chyby, které znamenají, že telefon není připojený k internetu.
const offlineMessage =
    'Nejsi připojený k internetu. Zkus to znovu, až budeš online.';

/// Text chyby pro uživatele:
/// - [AppException] ze služeb → její česká hláška,
/// - chyby Firebase a Google přihlášení kvůli chybějícímu internetu →
///   [offlineMessage],
/// - ostatní chyby Firebase → česky podle kódu chyby,
/// - cokoli jiného → obecná hláška (původní chyba se vypíše do konzole,
///   aby šla při vývoji dohledat).
String errorText(Object error) {
  if (error is AppException) return error.message;
  if (_isOffline(error)) return offlineMessage;

  debugPrint('Chyba bez české hlášky: $error');
  if (error is FirebaseException) {
    if (error.code == 'permission-denied') {
      return 'Na tuto akci nemáš oprávnění.';
    }
    return 'Něco se nepovedlo (${error.code}).';
  }
  return 'Něco se nepovedlo.';
}

bool _isOffline(Object error) {
  if (error is FirebaseException) {
    // unavailable = Firestore, network-request-failed = Firebase Auth.
    return error.code == 'unavailable' ||
        error.code == 'network-request-failed';
  }
  // Google přihlášení (balíček google_sign_in) bez internetu.
  return error is PlatformException && error.code == 'network_error';
}
