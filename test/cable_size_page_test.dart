import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aoj_sitekit/screens/tools/cable_size_page.dart';
import 'package:aoj_sitekit/services/recents.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('calculates, applies a voltage-drop upsize and saves', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: CableSizePage()));
    await tester.pump(const Duration(seconds: 2));

    // Default inputs: 15 kW, 400 V 3-phase, 40 m XLPE on tray → 4 mm².
    await tester.tap(find.text('Calculate'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('SAFE'), findsOneWidget);
    expect(
      find.textContaining('32 A Type C MCB', findRichText: true),
      findsOneWidget,
    );

    // A 150 m run fails voltage drop; the warning offers 10 mm².
    await tester.enterText(find.byType(TextField).at(3), '150');
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('SAFETY WARNING'), findsOneWidget);
    await tester.ensureVisible(find.text('Use 10 mm²'));
    await tester.tap(find.text('Use 10 mm²'));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('SAFETY WARNING'), findsNothing);
    expect(find.text('SAFE'), findsOneWidget);

    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(Recents.items.value.first.result, startsWith('10 mm²'));
  });
}
