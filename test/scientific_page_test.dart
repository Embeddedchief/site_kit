import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aoj_sitekit/screens/tools/scientific/scientific_calculator_page.dart';

void main() {
  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const MaterialApp(home: ScientificCalculatorPage()),
    );
  }

  Future<void> keys(WidgetTester tester, List<String> labels) async {
    for (final label in labels) {
      await tester.tap(find.text(label).last);
      await tester.pump();
    }
  }

  Finder result(String text) => find.descendant(
    of: find.byKey(const ValueKey('result')),
    matching: find.text(text),
  );

  testWidgets('keypad evaluates with precedence, Ans and SHIFT', (
    tester,
  ) async {
    await open(tester);

    await keys(tester, ['2', '+', '3', '×', '4', '=']);
    expect(result('14'), findsOneWidget);

    // An operator straight after "=" continues from Ans.
    await keys(tester, ['÷', '2', '=']);
    expect(result('7'), findsOneWidget);

    // With SHIFT on, the x⁻¹ key shows and inserts x!.
    await keys(tester, ['AC', '5', 'SHIFT', 'x!', '=']);
    expect(result('120'), findsOneWidget);

    // sin(30) in the default DEG mode.
    await keys(tester, ['AC', 'sin', '3', '0', ')', '=']);
    expect(result('0.5'), findsOneWidget);

    await keys(tester, ['AC', '1', '÷', '0', '=']);
    expect(find.text('Math ERROR'), findsOneWidget);
  });

  testWidgets('equation mode solves a quadratic', (tester) async {
    await open(tester);
    await tester.tap(find.text('Equation'));
    await tester.pump();

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), '1');
    await tester.enterText(fields.at(1), '-3');
    await tester.enterText(fields.at(2), '2');
    await tester.pump();

    expect(find.text('x1'), findsOneWidget);
    expect(find.text('2'), findsWidgets);
    expect(find.text('Minimum'), findsOneWidget);
  });

  testWidgets('statistics mode summarises a list', (tester) async {
    await open(tester);
    await tester.tap(find.text('Statistics'));
    await tester.pump();

    await tester.enterText(
      find.byType(TextField).first,
      '2, 4, 4, 4, 5, 5, 7, 9',
    );
    await tester.pump();

    expect(find.text('8'), findsWidgets); // n
    expect(find.text('5'), findsWidgets); // mean
    expect(find.text('Population SD'), findsOneWidget);
  });
}
