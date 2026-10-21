import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aoj_sitekit/screens/tools/unit_converter_page.dart';

void main() {
  Finder result(String text) => find.descendant(
    of: find.byKey(const ValueKey('result')),
    matching: find.text(text),
  );

  testWidgets('converts, swaps and switches category', (tester) async {
    tester.view.physicalSize = const Size(390, 844) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: UnitConverterPage()));

    // Default: 1 m → ft.
    expect(result('3.280839895'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '10');
    await tester.pump();
    expect(result('32.80839895'), findsOneWidget);

    // Swap puts the result in the input: 32.80839895 ft → 10 m.
    await tester.tap(find.byTooltip('Swap units'));
    await tester.pump();
    expect(result('10'), findsOneWidget);

    // Categories scroll sideways; bring Temperature into view first.
    await tester.scrollUntilVisible(
      find.text('Temperature'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Temperature'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), '100');
    await tester.pump();
    expect(result('212'), findsOneWidget); // °C → °F
  });
}
