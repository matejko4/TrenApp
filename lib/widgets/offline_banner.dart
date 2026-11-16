import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/network_status.dart';

/// Šedý pruh „Jste offline“, který vyjede nad spodní lištou, když telefon
/// nemá připojení. Obrazovky pak ukazují data uložená v telefonu
/// a změny se odešlou po připojení.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key, this.offline});

  /// Stav připojení – v aplikaci [NetworkStatus.offline], v testech
  /// vlastní hodnota.
  final ValueListenable<bool>? offline;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: offline ?? NetworkStatus.offline,
      builder: (context, isOffline, _) => AnimatedSize(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        child: isOffline
            ? Container(
                width: double.infinity,
                color: Colors.grey.shade700,
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.cloud_off, size: 16, color: Colors.white),
                    SizedBox(width: 8),
                    Text(
                      'Jste offline',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              )
            : const SizedBox(width: double.infinity),
      ),
    );
  }
}
