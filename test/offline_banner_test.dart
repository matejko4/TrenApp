import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tren_app/widgets/offline_banner.dart';

void main() {
  testWidgets('pruh „Jste offline“ se ukáže jen bez připojení',
      (tester) async {
    final offline = ValueNotifier(false);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(bottomNavigationBar: OfflineBanner(offline: offline)),
    ));
    expect(find.text('Jste offline'), findsNothing);

    offline.value = true;
    await tester.pumpAndSettle();
    expect(find.text('Jste offline'), findsOneWidget);

    offline.value = false;
    await tester.pumpAndSettle();
    expect(find.text('Jste offline'), findsNothing);
  });
}
