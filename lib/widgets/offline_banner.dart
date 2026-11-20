import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/network_status.dart';

/// Pruh „Jste offline“, který vyjede nad spodní lištou, když telefon
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
      builder: (context, isOffline, _) {
        // Opačné barvy než obrazovka (ve světlém režimu tmavý pruh,
        // v tmavém světlý), aby byl pruh vždy dobře vidět.
        final colors = Theme.of(context).colorScheme;
        return AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          child: isOffline
              ? Container(
                  width: double.infinity,
                  color: colors.inverseSurface,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.cloud_off,
                        size: 16,
                        color: colors.onInverseSurface,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Jste offline',
                        style: TextStyle(
                          color: colors.onInverseSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                )
              : const SizedBox(width: double.infinity),
        );
      },
    );
  }
}
