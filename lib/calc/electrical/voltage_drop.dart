import 'dart:math' as math;

import '../cable_sizing.dart';
import 'common.dart';

// Voltage drop for an existing or proposed cable.
// BS 7671 / IEC: Vd = (mV/A/m) × Ib × L / 1000 using Tables 4D2B/4E2B.
// NEC: Vd = k × I × R × L / 1000 (k = 2 single-phase, √3 three-phase) with
// Chapter 9 Table 8 resistance.

class VoltDropInput {
  const VoltDropInput({
    required this.standard,
    required this.phase,
    required this.voltage,
    required this.load,
    required this.loadUnit,
    required this.powerFactor,
    required this.material,
    required this.insulation,
    required this.sizeIndex,
    required this.length,
    required this.lengthUnit,
    required this.limitPct,
  });

  final CableStandard standard;
  final SupplyPhase phase;
  final double voltage;
  final double load;
  final LoadUnit loadUnit;
  final double powerFactor;
  final ConductorMaterial material;
  final Insulation insulation;
  final int sizeIndex;
  final double length;
  final LengthUnit lengthUnit;
  final double limitPct;

  bool get nec => standard == CableStandard.nec;
  double get lengthM => lengthUnit == LengthUnit.m ? length : length * 0.3048;
  double get lengthFt => lengthUnit == LengthUnit.ft ? length : length / 0.3048;
}

class VoltDropResult {
  const VoltDropResult({
    this.error,
    this.current = 0,
    this.drop = 0,
    this.dropPct = 0,
    this.endVoltage = 0,
    this.maxLength = 0,
    this.minSizeLabel,
    this.formula = '',
    this.steps = const [],
  });

  final String? error;
  final double current;
  final double drop;
  final double dropPct;
  final double endVoltage;

  /// Longest run (in the input's length unit) that stays within the limit.
  final double maxLength;

  /// Smallest size meeting the limit, or null if none does.
  final String? minSizeLabel;
  final String formula;
  final List<String> steps;

  bool get ok => error == null;
}

List<String> sizeLabels(CableStandard s) => s == CableStandard.nec
    ? necSizes
    : [for (var i = 0; i < metricSizes.length; i++) metricSizeLabel(i)];

int firstSize(CableStandard s, ConductorMaterial m) =>
    s == CableStandard.nec ? necFirstSize(m) : metricFirstSize(m);

VoltDropResult calculateVoltDrop(VoltDropInput i) {
  final error = switch (i) {
    _ when i.voltage <= 0 => 'Enter the supply voltage.',
    _ when i.load <= 0 => 'Enter the load.',
    _ when i.powerFactor <= 0 || i.powerFactor > 1 =>
      'Power factor must be between 0 and 1.',
    _ when i.length <= 0 => 'Enter the cable length.',
    _ when i.limitPct <= 0 => 'Enter a drop limit above 0%.',
    _ => null,
  };
  if (error != null) return VoltDropResult(error: error);
  if (i.sizeIndex < firstSize(i.standard, i.material)) {
    return const VoltDropResult(
      error: 'Aluminium is not used in this size. Pick a larger cable.',
    );
  }

  final ib = loadCurrent(
    load: i.load,
    unit: i.loadUnit,
    voltage: i.voltage,
    phase: i.phase,
    powerFactor: i.powerFactor,
  );
  final labels = sizeLabels(i.standard);
  final first = firstSize(i.standard, i.material);
  final steps = <String>[
    'Design current: Ib = ${fmt(ib)} A'
        '${i.loadUnit == LoadUnit.amps ? ' (given)' : ' from ${fmt(i.load, 2)} ${i.loadUnit.label}'}',
  ];

  // Volts dropped per unit current per unit length, for each size.
  double perAmpPerLength(int s) => i.nec
      ? (i.phase == SupplyPhase.three ? math.sqrt(3) : 2) *
            necOhmsPerKft(i.material, s) /
            1000
      : metricMvPerAm(i.insulation, i.phase, i.material, s) / 1000;
  final length = i.nec ? i.lengthFt : i.lengthM;
  double pctAt(int s) => perAmpPerLength(s) * ib * length / i.voltage * 100;

  final drop = perAmpPerLength(i.sizeIndex) * ib * length;
  final pct = drop / i.voltage * 100;
  final unitLen = i.nec ? 'ft' : 'm';

  final String formula;
  if (i.nec) {
    final k = i.phase == SupplyPhase.three ? '1.732' : '2';
    final r = necOhmsPerKft(i.material, i.sizeIndex);
    formula = 'Vd = k × I × R × L / 1000';
    steps.add(
      'Vd = $k × ${fmt(ib)} × $r ohm/kft × ${fmt(length, 0)} ft / 1000 = '
      '${fmt(drop, 2)} V (Chapter 9 Table 8)',
    );
  } else {
    final mv = metricMvPerAm(i.insulation, i.phase, i.material, i.sizeIndex);
    formula = 'Vd = mV/A/m × Ib × L / 1000';
    steps.add(
      'Vd = ${mv.toStringAsFixed(2)} mV/A/m × ${fmt(ib)} A × '
      '${fmt(length)} m / 1000 = ${fmt(drop, 2)} V '
      '(${i.insulation == Insulation.xlpe ? 'Table 4E2B' : 'Table 4D2B'})',
    );
  }
  steps.add(
    'Percentage: ${fmt(drop, 2)} / ${fmt(i.voltage, 0)} V × 100 = '
    '${fmt(pct, 2)}% (limit ${fmt(i.limitPct)}%)',
  );

  final maxLen =
      i.limitPct / 100 * i.voltage / (perAmpPerLength(i.sizeIndex) * ib);
  final maxLenInInput = i.nec
      ? (i.lengthUnit == LengthUnit.ft ? maxLen : maxLen * 0.3048)
      : (i.lengthUnit == LengthUnit.m ? maxLen : maxLen / 0.3048);
  steps.add(
    'Longest run within ${fmt(i.limitPct)}%: '
    '${fmt(maxLen, 0)} $unitLen at ${labels[i.sizeIndex]}',
  );

  String? minSize;
  for (var s = first; s < labels.length; s++) {
    if (pctAt(s) <= i.limitPct + 1e-9) {
      minSize = labels[s];
      break;
    }
  }
  steps.add(
    minSize == null
        ? 'No single cable size meets the limit. Shorten the run, raise the '
              'voltage or use parallel cables.'
        : 'Smallest size within the limit: $minSize',
  );

  return VoltDropResult(
    current: ib,
    drop: drop,
    dropPct: pct,
    endVoltage: i.voltage - drop,
    maxLength: maxLenInInput,
    minSizeLabel: minSize,
    formula: formula,
    steps: steps,
  );
}
