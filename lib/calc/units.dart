import 'dart:math' as math;

import 'package:flutter/material.dart';

// Engineering unit conversions. Each unit converts through the category's
// SI base unit. Factors are exact definitions where one exists (inch, pound,
// gallon, psi via lbf and in², etc.).

class Unit {
  /// A linear unit: value × [factor] = base unit.
  const Unit(this.symbol, this.name, double factor)
    : _factor = factor,
      _toBase = null,
      _fromBase = null;

  /// A unit with an offset (temperature). Private fields can't be named
  /// initializing formals, hence the ignores below.
  const Unit.affine(
    this.symbol,
    this.name, {
    required double Function(double) toBase,
    required double Function(double) fromBase,
  }) : _factor = null,
       // ignore: prefer_initializing_formals
       _toBase = toBase,
       // ignore: prefer_initializing_formals
       _fromBase = fromBase;

  final String symbol;
  final String name;
  final double? _factor;
  final double Function(double)? _toBase;
  final double Function(double)? _fromBase;

  double toBase(double v) => _factor != null ? v * _factor : _toBase!(v);
  double fromBase(double v) => _factor != null ? v / _factor : _fromBase!(v);
}

class UnitCategory {
  const UnitCategory(
    this.name,
    this.icon,
    this.units, {
    this.from = 0,
    this.to = 1,
  });

  final String name;
  final IconData icon;
  final List<Unit> units;

  /// Default from/to unit indexes.
  final int from, to;
}

double convert(double value, Unit from, Unit to) =>
    to.fromBase(from.toBase(value));

const _in = 0.0254;
const _ft = 0.3048;
const _lb = 0.45359237;
const _g0 = 9.80665;
const _lbf = _lb * _g0;
const _usGal = 231 * _in * _in * _in;
const _btu = 1055.05585262;

final unitCategories = <UnitCategory>[
  UnitCategory(
    'Length',
    Icons.straighten_rounded,
    const [
      Unit('mm', 'Millimetre', 1e-3),
      Unit('cm', 'Centimetre', 1e-2),
      Unit('m', 'Metre', 1),
      Unit('km', 'Kilometre', 1e3),
      Unit('µm', 'Micrometre', 1e-6),
      Unit('in', 'Inch', _in),
      Unit('ft', 'Foot', _ft),
      Unit('yd', 'Yard', 0.9144),
      Unit('mi', 'Mile', 1609.344),
      Unit('nmi', 'Nautical mile', 1852),
    ],
    from: 2,
    to: 6,
  ),
  UnitCategory(
    'Area',
    Icons.crop_square_rounded,
    const [
      Unit('mm²', 'Square millimetre', 1e-6),
      Unit('cm²', 'Square centimetre', 1e-4),
      Unit('m²', 'Square metre', 1),
      Unit('ha', 'Hectare', 1e4),
      Unit('km²', 'Square kilometre', 1e6),
      Unit('in²', 'Square inch', _in * _in),
      Unit('ft²', 'Square foot', _ft * _ft),
      Unit('yd²', 'Square yard', 0.9144 * 0.9144),
      Unit('acre', 'Acre', 4046.8564224),
    ],
    from: 2,
    to: 6,
  ),
  UnitCategory(
    'Volume',
    Icons.view_in_ar_outlined,
    const [
      Unit('mL', 'Millilitre', 1e-6),
      Unit('L', 'Litre', 1e-3),
      Unit('m³', 'Cubic metre', 1),
      Unit('cm³', 'Cubic centimetre', 1e-6),
      Unit('in³', 'Cubic inch', _in * _in * _in),
      Unit('ft³', 'Cubic foot', _ft * _ft * _ft),
      Unit('yd³', 'Cubic yard', 0.9144 * 0.9144 * 0.9144),
      Unit('gal (US)', 'US gallon', _usGal),
      Unit('gal (UK)', 'Imperial gallon', 4.54609e-3),
    ],
    from: 2,
    to: 6,
  ),
  UnitCategory(
    'Mass',
    Icons.scale_outlined,
    const [
      Unit('g', 'Gram', 1e-3),
      Unit('kg', 'Kilogram', 1),
      Unit('t', 'Tonne', 1e3),
      Unit('lb', 'Pound', _lb),
      Unit('oz', 'Ounce', _lb / 16),
      Unit('ton (US)', 'Short ton', 2000 * _lb),
      Unit('ton (UK)', 'Long ton', 2240 * _lb),
    ],
    from: 1,
    to: 3,
  ),
  UnitCategory(
    'Density',
    Icons.blur_on_rounded,
    const [
      Unit('kg/m³', 'Kilogram per cubic metre', 1),
      Unit('g/cm³', 'Gram per cubic centimetre', 1e3),
      Unit('kg/L', 'Kilogram per litre', 1e3),
      Unit('t/m³', 'Tonne per cubic metre', 1e3),
      Unit('lb/ft³', 'Pound per cubic foot', _lb / (_ft * _ft * _ft)),
      Unit('lb/in³', 'Pound per cubic inch', _lb / (_in * _in * _in)),
    ],
    from: 0,
    to: 4,
  ),
  UnitCategory(
    'Force',
    Icons.south_rounded,
    const [
      Unit('N', 'Newton', 1),
      Unit('kN', 'Kilonewton', 1e3),
      Unit('MN', 'Meganewton', 1e6),
      Unit('kgf', 'Kilogram-force', _g0),
      Unit('tf', 'Tonne-force', 1e3 * _g0),
      Unit('lbf', 'Pound-force', _lbf),
      Unit('kip', 'Kip', 1e3 * _lbf),
    ],
    from: 1,
    to: 6,
  ),
  UnitCategory(
    'Pressure & stress',
    Icons.compress_rounded,
    const [
      Unit('Pa', 'Pascal', 1),
      Unit('kPa', 'Kilopascal', 1e3),
      Unit('MPa', 'Megapascal', 1e6),
      Unit('N/mm²', 'Newton per mm²', 1e6),
      Unit('GPa', 'Gigapascal', 1e9),
      Unit('kN/m²', 'Kilonewton per m²', 1e3),
      Unit('bar', 'Bar', 1e5),
      Unit('mbar', 'Millibar', 100),
      Unit('atm', 'Standard atmosphere', 101325),
      Unit('psi', 'Pound per square inch', _lbf / (_in * _in)),
      Unit('ksi', 'Kip per square inch', 1e3 * _lbf / (_in * _in)),
      Unit('psf', 'Pound per square foot', _lbf / (_ft * _ft)),
      Unit('kgf/cm²', 'Kilogram-force per cm²', _g0 * 1e4),
      Unit('mH2O', 'Metre of water', _g0 * 1e3),
      Unit('ftH2O', 'Foot of water', _g0 * 1e3 * _ft),
      Unit('mmHg', 'Millimetre of mercury', 133.322387415),
      Unit('inHg', 'Inch of mercury', 3386.388640341),
    ],
    from: 6,
    to: 9,
  ),
  UnitCategory(
    'Energy',
    Icons.local_fire_department_outlined,
    const [
      Unit('J', 'Joule', 1),
      Unit('kJ', 'Kilojoule', 1e3),
      Unit('MJ', 'Megajoule', 1e6),
      Unit('Wh', 'Watt-hour', 3600),
      Unit('kWh', 'Kilowatt-hour', 3.6e6),
      Unit('MWh', 'Megawatt-hour', 3.6e9),
      Unit('cal', 'Calorie', 4.184),
      Unit('kcal', 'Kilocalorie', 4184),
      Unit('BTU', 'British thermal unit', _btu),
      Unit('therm', 'Therm', 1e5 * _btu),
      Unit('ft·lbf', 'Foot-pound', _ft * _lbf),
    ],
    from: 4,
    to: 8,
  ),
  UnitCategory(
    'Power',
    Icons.bolt_rounded,
    const [
      Unit('W', 'Watt', 1),
      Unit('kW', 'Kilowatt', 1e3),
      Unit('MW', 'Megawatt', 1e6),
      Unit('hp', 'Horsepower (mechanical)', 550 * _ft * _lbf),
      Unit('PS', 'Horsepower (metric)', 75 * _g0),
      Unit('BTU/h', 'BTU per hour', _btu / 3600),
      Unit('TR', 'Ton of refrigeration', 12000 * _btu / 3600),
      Unit('kcal/h', 'Kilocalorie per hour', 4184 / 3600),
    ],
    from: 1,
    to: 3,
  ),
  UnitCategory(
    'Torque & moment',
    Icons.rotate_right_rounded,
    const [
      Unit('N·m', 'Newton-metre', 1),
      Unit('kN·m', 'Kilonewton-metre', 1e3),
      Unit('kgf·m', 'Kilogram-force metre', _g0),
      Unit('lbf·ft', 'Pound-force foot', _lbf * _ft),
      Unit('lbf·in', 'Pound-force inch', _lbf * _in),
      Unit('kip·ft', 'Kip-foot', 1e3 * _lbf * _ft),
    ],
    from: 1,
    to: 5,
  ),
  UnitCategory(
    'Velocity',
    Icons.speed_rounded,
    const [
      Unit('m/s', 'Metre per second', 1),
      Unit('km/h', 'Kilometre per hour', 1 / 3.6),
      Unit('ft/s', 'Foot per second', _ft),
      Unit('ft/min', 'Foot per minute', _ft / 60),
      Unit('mph', 'Mile per hour', 1609.344 / 3600),
      Unit('kn', 'Knot', 1852 / 3600),
    ],
    from: 0,
    to: 3,
  ),
  UnitCategory(
    'Flow rate',
    Icons.water_drop_outlined,
    const [
      Unit('m³/s', 'Cubic metre per second', 1),
      Unit('m³/h', 'Cubic metre per hour', 1 / 3600),
      Unit('L/s', 'Litre per second', 1e-3),
      Unit('L/min', 'Litre per minute', 1e-3 / 60),
      Unit('gpm (US)', 'US gallon per minute', _usGal / 60),
      Unit('gpm (UK)', 'Imperial gallon per minute', 4.54609e-3 / 60),
      Unit('cfm', 'Cubic foot per minute', _ft * _ft * _ft / 60),
    ],
    from: 2,
    to: 4,
  ),
  UnitCategory('Temperature', Icons.thermostat_rounded, [
    Unit.affine(
      '°C',
      'Celsius',
      toBase: (v) => v + 273.15,
      fromBase: (k) => k - 273.15,
    ),
    Unit.affine(
      '°F',
      'Fahrenheit',
      toBase: (v) => (v - 32) * 5 / 9 + 273.15,
      fromBase: (k) => (k - 273.15) * 9 / 5 + 32,
    ),
    const Unit('K', 'Kelvin', 1),
    const Unit('°R', 'Rankine', 5 / 9),
  ]),
  UnitCategory('Angle', Icons.architecture_rounded, const [
    Unit('°', 'Degree', math.pi / 180),
    Unit('rad', 'Radian', 1),
    Unit('grad', 'Gradian', math.pi / 200),
    Unit('′', 'Arcminute', math.pi / 10800),
    Unit('″', 'Arcsecond', math.pi / 648000),
  ]),
  UnitCategory('Illuminance', Icons.lightbulb_outline_rounded, const [
    Unit('lx', 'Lux', 1),
    Unit('fc', 'Foot-candle', 1 / (_ft * _ft)),
  ]),
  UnitCategory('Heat transfer (U)', Icons.thermostat_auto_rounded, const [
    Unit('W/m²K', 'Watt per m² kelvin', 1),
    Unit(
      'BTU/h·ft²·°F',
      'BTU per hour ft² °F',
      _btu / 3600 / (_ft * _ft) * 9 / 5,
    ),
  ]),
];
