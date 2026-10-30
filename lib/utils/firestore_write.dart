import 'dart:async';

import 'package:flutter/foundation.dart';

/// Počká na potvrzení zápisu do Firestore nejvýš [timeout].
///
/// Firestore zápis bez internetu hned uloží v telefonu (obrazovky ho díky
/// streamům ukážou okamžitě) a odešle ho sám, až bude připojení. Future
/// zápisu ale skončí až po potvrzení serverem, takže bez internetu by
/// aplikace čekala donekonečna.
///
/// Vrací true, když server zápis potvrdil, a false, když to nestihl –
/// telefon je nejspíš offline a zápis zůstává uložený v telefonu.
/// Chyba, kterou server vrátí včas (např. chybějící oprávnění), se předá dál.
Future<bool> waitForServer(
  Future<void> write, {
  Duration timeout = const Duration(seconds: 3),
}) async {
  try {
    await write.timeout(timeout);
    return true;
  } on TimeoutException {
    // Kdyby server zápis po připojení odmítl, obrazovka už je zavřená –
    // chyba se jen vypíše do konzole.
    unawaited(write.catchError(
        (Object e) => debugPrint('Odložený zápis do Firestore selhal: $e')));
    return false;
  }
}
