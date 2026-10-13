import 'package:flutter/material.dart';

import '../widgets/account_actions.dart';
import '../widgets/app_bottom_bar.dart';
import '../widgets/coming_soon.dart';

/// Oznámení a zprávy od trenérů. Zatím jen zástupná obrazovka.
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Oznámení'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: const [LogoutButton()],
      ),
      body: const ComingSoon(
        icon: Icons.notifications,
        title: 'Žádná oznámení',
        message: 'Zprávy od trenérů se tu brzy objeví. Připravujeme.',
      ),
      bottomNavigationBar: const AppBottomBar(current: AppTab.notifications),
    );
  }
}
