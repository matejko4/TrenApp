import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/root_gate.dart';
import 'services/network_status.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // Sledování připojení pro pruh „Jste offline“ (viz OfflineBanner).
  await NetworkStatus.start();
  // Zvolený vzhled (světlý / tmavý) z minula – ať aplikace neproblikne.
  await ThemeController.instance.load();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Po změně režimu v Nastavení účtu se MaterialApp překreslí s novým
    // themeMode. Obě témata jsou v theme/app_theme.dart.
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.instance,
      builder: (context, themeMode, _) => MaterialApp(
        title: 'TrenApp',
        debugShowCheckedModeBanner: false,
        // Čeština pro systémové widgety – kalendář při výběru data začíná
        // pondělím a čas se vybírá ve 24h formátu.
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        supportedLocales: const [Locale('cs')],
        locale: const Locale('cs'),
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: themeMode,
        home: const RootGate(),
      ),
    );
  }
}
