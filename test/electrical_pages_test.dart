import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aoj_sitekit/screens/tools/electrical/breaker_page.dart';
import 'package:aoj_sitekit/screens/tools/electrical/generator_page.dart';
import 'package:aoj_sitekit/screens/tools/electrical/load_calculator_page.dart';
import 'package:aoj_sitekit/screens/tools/electrical/voltage_drop_page.dart';
import 'package:aoj_sitekit/services/load_schedule_store.dart';

Future<void> open(WidgetTester tester, Widget page) async {
  tester.view.physicalSize = const Size(390, 844) * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: page));
  await tester.pump();
}

/// Finds text inside rich text too (result heroes use Text.rich).
Finder rich(String text) => find.textContaining(text, findRichText: true);

/// Scrolls the tool body until [finder] is built and on screen.
Future<void> seek(WidgetTester tester, Finder finder, {double delta = 300}) =>
    tester.scrollUntilVisible(
      finder,
      delta,
      scrollable: find.byType(Scrollable).first,
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('voltage drop shows the default result and reacts to length', (
    tester,
  ) async {
    await open(tester, const VoltageDropPage());
    await seek(tester, rich('2.55'));
    expect(find.text('WITHIN LIMIT'), findsOneWidget);

    // 100 m on 4 mm²: 25.5 V = 6.37%, over the 5% limit.
    await seek(tester, find.text('LENGTH (ONE WAY)'), delta: -300);
    await tester.enterText(find.byType(TextField).at(3), '100');
    await tester.pump();
    await seek(tester, rich('6.37'));
    expect(find.text('TOO HIGH'), findsOneWidget);
  });

  testWidgets('breaker selector picks 25 A Type B for a 25 A socket circuit', (
    tester,
  ) async {
    await open(tester, const BreakerPage());
    await seek(tester, rich('Type B'));
    expect(rich('25 A'), findsWidgets);
    await seek(tester, rich('RCD'));
  });

  testWidgets('generator sizing recommends 150 kVA for the defaults', (
    tester,
  ) async {
    await open(tester, const GeneratorPage());
    await seek(tester, find.text('REVIEW')); // DOL start drives the size
    expect(rich('150'), findsWidgets);
  });

  testWidgets('load calculator adds a load from a preset and saves it', (
    tester,
  ) async {
    await open(tester, const LoadCalculatorPage());
    await tester.pumpAndSettle();
    await seek(tester, find.text('Loads (0)'));

    await tester.tap(find.text('Add load'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Water heater'));
    await tester.pump();
    final add = find.widgetWithText(FilledButton, 'Add load');
    await tester.ensureVisible(add);
    await tester.pumpAndSettle();
    await tester.tap(add);
    await tester.pumpAndSettle();

    // 3 kW at pf 1 on L1 of a 400 V supply: 3000 / 230.9 = 13.0 A.
    await seek(tester, rich('13.0 A design current'), delta: -300);
    await seek(tester, find.text('Loads (1)'));
    await seek(tester, find.text('Water heater'));

    final saved = await LoadScheduleStore.load();
    expect(saved.items.single.name, 'Water heater');
  });
}
