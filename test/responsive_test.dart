import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aoj_sitekit/main.dart';
import 'package:aoj_sitekit/screens/homepage.dart';
import 'package:aoj_sitekit/screens/notes/note_editor_page.dart';
import 'package:aoj_sitekit/screens/notes/notes_page.dart';
import 'package:aoj_sitekit/screens/tools/cable_size_page.dart';
import 'package:aoj_sitekit/screens/tools/electrical/breaker_page.dart';
import 'package:aoj_sitekit/screens/tools/electrical/generator_page.dart';
import 'package:aoj_sitekit/screens/tools/electrical/load_calculator_page.dart';
import 'package:aoj_sitekit/screens/tools/electrical/voltage_drop_page.dart';
import 'package:aoj_sitekit/screens/tools/scientific/scientific_calculator_page.dart';
import 'package:aoj_sitekit/screens/tools/unit_converter_page.dart';

/// Logical screen sizes from a small phone to a tablet.
const _sizes = {
  'small phone 320×568': Size(320, 568),
  'compact phone 360×640': Size(360, 640),
  'phone 390×844': Size(390, 844),
  'tablet 820×1180': Size(820, 1180),
};

final _screens = <String, Widget Function()>{
  'home': () => const HomePage(name: 'Ade Johnson'),
  'calculator': () => const ScientificCalculatorPage(),
  'unit converter': () => const UnitConverterPage(),
  'notes': () => const NotesPage(),
  'note editor': () => const NoteEditorPage(),
  'cable sizing': () => const CableSizePage(),
  'voltage drop': () => const VoltageDropPage(),
  'breaker': () => const BreakerPage(),
  'load calculator': () => const LoadCalculatorPage(),
  'generator': () => const GeneratorPage(),
};

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final size in _sizes.entries) {
    for (final screen in _screens.entries) {
      testWidgets('${screen.key} fits on ${size.key}', (tester) async {
        tester.view.physicalSize = size.value * 3;
        tester.view.devicePixelRatio = 3;
        addTearDown(tester.view.reset);

        // Mirror the app shell so the tablet width cap applies.
        await tester.pumpWidget(
          MaterialApp(
            builder: SiteKitApp.responsiveBuilder,
            home: screen.value(),
          ),
        );
        await tester.pump(const Duration(seconds: 2));
        expect(tester.takeException(), isNull);
        // A squeezed-out body doesn't overflow, it just vanishes: make sure
        // every scrolling area actually got space.
        for (final e in find.byType(Scrollable).evaluate()) {
          final box = e.renderObject! as RenderBox;
          expect(box.size.height, greaterThan(20), reason: '$e has no room');
        }
      });
    }
  }

  testWidgets('largest allowed text size still fits the calculator', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640) * 3;
    tester.view.devicePixelRatio = 3;
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(
      const MaterialApp(
        builder: SiteKitApp.responsiveBuilder,
        home: ScientificCalculatorPage(),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });
}
