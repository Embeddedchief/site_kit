import 'package:flutter/material.dart';

import '../../widgets/common.dart';
import '../../widgets/fade_route.dart';
import '../notes/notes_page.dart';
import 'cable_size_page.dart';
import 'electrical/breaker_page.dart';
import 'electrical/generator_page.dart';
import 'electrical/load_calculator_page.dart';
import 'electrical/voltage_drop_page.dart';
import 'scientific/scientific_calculator_page.dart';
import 'unit_converter_page.dart';

/// Screens for tools that have been built, keyed by tool id.
final Map<String, WidgetBuilder> _toolScreens = {
  'elec_cable_size': (_) => const CableSizePage(),
  'elec_voltage_drop': (_) => const VoltageDropPage(),
  'elec_breaker': (_) => const BreakerPage(),
  'elec_load': (_) => const LoadCalculatorPage(),
  'elec_generator': (_) => const GeneratorPage(),
  'sci_calculator': (_) => const ScientificCalculatorPage(),
  'unit_converter': (_) => const UnitConverterPage(),
  'site_notes': (_) => const NotesPage(),
};

/// Opens a tool's screen, or a "coming soon" note if it isn't built yet.
void openTool(BuildContext context, String id, String name) {
  final builder = _toolScreens[id];
  if (builder == null) {
    showComingSoon(context, name);
    return;
  }
  Navigator.of(context).push(fadeRoute(builder(context)));
}
