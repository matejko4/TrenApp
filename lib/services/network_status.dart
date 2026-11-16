import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Jestli je telefon offline – nemá wifi ani mobilní data.
///
/// Sleduje se jednou pro celou aplikaci ([start] v main.dart), aby každá
/// obrazovka znala aktuální stav hned při otevření a pruh „Jste offline“
/// při přechodu mezi obrazovkami neblikal.
///
/// Wifi bez přístupu k internetu (třeba nepřihlášená hotelová síť) se
/// počítá jako online – balíček zná jen připojení k síti, ne internet.
class NetworkStatus {
  static final ValueNotifier<bool> offline = ValueNotifier(false);

  static Future<void> start() async {
    final connectivity = Connectivity();
    connectivity.onConnectivityChanged.listen(_update);
    _update(await connectivity.checkConnectivity());
  }

  static void _update(List<ConnectivityResult> results) {
    offline.value = results.every((r) => r == ConnectivityResult.none);
  }
}
