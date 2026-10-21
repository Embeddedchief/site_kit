import 'package:flutter_test/flutter_test.dart';

import 'package:aoj_sitekit/calc/units.dart';

Unit unit(String category, String symbol) => unitCategories
    .firstWhere((c) => c.name == category)
    .units
    .firstWhere((u) => u.symbol == symbol);

double conv(String category, double v, String from, String to) =>
    convert(v, unit(category, from), unit(category, to));

void main() {
  test('every category has unique symbols and valid defaults', () {
    for (final c in unitCategories) {
      final symbols = c.units.map((u) => u.symbol).toSet();
      expect(symbols.length, c.units.length, reason: c.name);
      expect(c.from, lessThan(c.units.length), reason: c.name);
      expect(c.to, lessThan(c.units.length), reason: c.name);
    }
  });

  test('round trips return the input', () {
    for (final c in unitCategories) {
      for (final a in c.units) {
        for (final b in c.units) {
          expect(
            convert(convert(123.456, a, b), b, a),
            closeTo(123.456, 1e-9),
            reason: '${c.name}: ${a.symbol} ↔ ${b.symbol}',
          );
        }
      }
    }
  });

  test('reference values', () {
    expect(conv('Length', 1, 'ft', 'mm'), closeTo(304.8, 1e-9));
    expect(conv('Length', 1, 'mi', 'km'), closeTo(1.609344, 1e-12));
    expect(conv('Area', 1, 'acre', 'm²'), closeTo(4046.8564224, 1e-9));
    expect(conv('Volume', 1, 'gal (US)', 'L'), closeTo(3.785411784, 1e-9));
    expect(conv('Mass', 1, 'lb', 'kg'), closeTo(0.45359237, 1e-12));
    expect(conv('Force', 1, 'kip', 'kN'), closeTo(4.4482216152605, 1e-9));
    expect(
      conv('Pressure & stress', 1, 'psi', 'kPa'),
      closeTo(6.894757293, 1e-8),
    );
    expect(
      conv('Pressure & stress', 1, 'bar', 'psi'),
      closeTo(14.503773773, 1e-8),
    );
    expect(conv('Pressure & stress', 1, 'N/mm²', 'MPa'), 1);
    expect(
      conv('Pressure & stress', 1, 'mH2O', 'kPa'),
      closeTo(9.80665, 1e-12),
    );
    expect(conv('Energy', 1, 'kWh', 'BTU'), closeTo(3412.141633, 1e-5));
    expect(conv('Power', 1, 'hp', 'W'), closeTo(745.69987158, 1e-7));
    expect(conv('Power', 1, 'TR', 'kW'), closeTo(3.516852842, 1e-8));
    expect(
      conv('Torque & moment', 1, 'lbf·ft', 'N·m'),
      closeTo(1.355817948, 1e-8),
    );
    expect(
      conv('Flow rate', 1, 'L/s', 'gpm (US)'),
      closeTo(15.850323141, 1e-8),
    );
    expect(conv('Density', 1, 'lb/ft³', 'kg/m³'), closeTo(16.018463374, 1e-8));
    expect(conv('Illuminance', 1, 'fc', 'lx'), closeTo(10.763910417, 1e-8));
    expect(
      conv('Heat transfer (U)', 1, 'BTU/h·ft²·°F', 'W/m²K'),
      closeTo(5.678263337, 1e-8),
    );
  });

  test('temperature offsets', () {
    expect(conv('Temperature', 100, '°C', '°F'), closeTo(212, 1e-9));
    expect(conv('Temperature', 32, '°F', '°C'), closeTo(0, 1e-9));
    expect(conv('Temperature', 0, '°C', 'K'), closeTo(273.15, 1e-9));
    expect(conv('Temperature', 0, 'K', '°R'), 0);
    expect(conv('Temperature', -40, '°C', '°F'), closeTo(-40, 1e-9));
  });
}
