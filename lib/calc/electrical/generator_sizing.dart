import 'dart:math' as math;

import 'common.dart';

// Diesel generator sizing from running load and the largest motor start.
//
// Motor start: the alternator's transient reactance X'd limits the voltage
// dip when a motor draws its starting kVA. To keep the dip at or below D:
//   S_gen ≥ S_base + X'd × S_start × (1 − D) / D
// Altitude and temperature derating use typical manufacturer figures; always
// confirm against the chosen set's derating curve.

enum StartMethod {
  dol('Direct on line', 6.0),
  starDelta('Star-delta', 2.2),
  softStarter('Soft starter', 3.0),
  vfd('VFD / drive', 1.2);

  const StartMethod(this.label, this.multiple);
  final String label;

  /// Starting kVA as a multiple of the motor's running kVA.
  final double multiple;
}

enum GeneratorDuty {
  prime('Prime (main power)'),
  standby('Standby (backup)');

  const GeneratorDuty(this.label);
  final String label;
}

const standardGeneratorKva = [
  10, 15, 20, 30, 40, 50, 60, 80, 100, 125, 150, 200, 250, 300, 350, 400, //
  500, 600, 750, 800, 1000, 1250, 1500, 2000, 2500,
];

/// Motor running kVA per kW of shaft output (efficiency 0.9 × pf 0.85).
const _motorKvaPerKw = 1 / (0.9 * 0.85);

/// Typical diesel consumption, litres per kWh generated, near 75% load.
const _litresPerKwh = 0.27;

class GeneratorInput {
  const GeneratorInput({
    required this.runningKw,
    required this.powerFactor,
    required this.largestMotorKw,
    required this.startMethod,
    required this.marginPct,
    required this.maxDipPct,
    required this.duty,
    this.altitudeM = 0,
    this.ambientC = 40,
    this.transientReactance = 0.2,
  });

  /// Total running load including the largest motor.
  final double runningKw;
  final double powerFactor;

  /// Largest motor started on the set (kW shaft); 0 if none.
  final double largestMotorKw;
  final StartMethod startMethod;
  final double marginPct;
  final double maxDipPct;
  final GeneratorDuty duty;
  final double altitudeM;
  final double ambientC;
  final double transientReactance;
}

class GeneratorResult {
  const GeneratorResult({
    this.error,
    this.runningKva = 0,
    this.designKva = 0,
    this.motorStartKva = 0,
    this.startRequirementKva = 0,
    this.deratingFactor = 1,
    this.requiredKva = 0,
    this.selectedKva,
    this.loadingPct = 0,
    this.fuelLitresPerHour = 0,
    this.warnings = const [],
    this.steps = const [],
  });

  final String? error;
  final double runningKva;

  /// Running kVA plus the growth margin.
  final double designKva;
  final double motorStartKva;

  /// kVA needed to start the largest motor within the dip limit.
  final double startRequirementKva;
  final double deratingFactor;

  /// Site-rated kVA needed before choosing a standard size.
  final double requiredKva;

  /// Smallest standard set at or above [requiredKva], or null if larger
  /// than 2500 kVA (use parallel sets).
  final int? selectedKva;
  final double loadingPct;
  final double fuelLitresPerHour;
  final List<String> warnings;
  final List<String> steps;

  /// Set kW at the standard 0.8 power factor rating.
  double get selectedKw => (selectedKva ?? 0) * 0.8;
}

/// Combined altitude and temperature derating: 4% per 300 m above 1000 m,
/// 1% per °C above 40 °C (typical; check the set's curves).
double generatorDerating(double altitudeM, double ambientC) {
  final alt = altitudeM > 1000 ? 1 - 0.04 * (altitudeM - 1000) / 300 : 1.0;
  final temp = ambientC > 40 ? 1 - 0.01 * (ambientC - 40) : 1.0;
  return math.max(0.3, alt * temp);
}

GeneratorResult sizeGenerator(GeneratorInput i) {
  if (i.runningKw <= 0) {
    return const GeneratorResult(error: 'Enter the running load.');
  }
  if (i.powerFactor <= 0 || i.powerFactor > 1) {
    return const GeneratorResult(
      error: 'Power factor must be between 0 and 1.',
    );
  }
  if (i.largestMotorKw < 0 || i.largestMotorKw > i.runningKw) {
    return const GeneratorResult(
      error: 'The largest motor must be part of the running load.',
    );
  }
  if (i.maxDipPct <= 0 || i.maxDipPct >= 100) {
    return const GeneratorResult(error: 'Voltage dip limit must be 1–99%.');
  }

  final steps = <String>[];
  final warnings = <String>[];

  final runningKva = i.runningKw / i.powerFactor;
  steps.add(
    'Running load: ${fmt(i.runningKw)} kW / ${i.powerFactor.toStringAsFixed(2)} '
    '= ${fmt(runningKva)} kVA',
  );
  final designKva = runningKva * (1 + i.marginPct / 100);
  steps.add('With ${fmt(i.marginPct, 0)}% margin: ${fmt(designKva)} kVA');

  var startKva = 0.0, startReq = 0.0;
  if (i.largestMotorKw > 0) {
    final motorKva = i.largestMotorKw * _motorKvaPerKw;
    startKva = motorKva * i.startMethod.multiple;
    final baseKva = math.max(0.0, runningKva - motorKva);
    final d = i.maxDipPct / 100;
    startReq = baseKva + i.transientReactance * startKva * (1 - d) / d;
    steps
      ..add(
        'Largest motor ${fmt(i.largestMotorKw)} kW runs at ${fmt(motorKva)} '
        'kVA; ${i.startMethod.label.toLowerCase()} start draws '
        '${i.startMethod.multiple}× = ${fmt(startKva)} kVA',
      )
      ..add(
        "Start within ${fmt(i.maxDipPct, 0)}% dip: ${fmt(baseKva)} + "
        "${i.transientReactance.toStringAsFixed(2)} × ${fmt(startKva)} × "
        "${(1 - d).toStringAsFixed(2)} / ${d.toStringAsFixed(2)} = "
        "${fmt(startReq)} kVA",
      );
    if (i.startMethod == StartMethod.dol && startReq > designKva * 1.5) {
      warnings.add(
        'The DOL motor start drives the size. A soft starter or VFD would '
        'allow a much smaller generator.',
      );
    }
  }

  final derate = generatorDerating(i.altitudeM, i.ambientC);
  final needed = math.max(designKva, startReq);
  final required = needed / derate;
  if (derate < 1) {
    steps.add(
      'Site derating ${(derate * 100).toStringAsFixed(0)}% '
      '(${fmt(i.altitudeM, 0)} m, ${fmt(i.ambientC, 0)} °C): '
      '${fmt(needed)} / ${derate.toStringAsFixed(2)} = ${fmt(required)} kVA',
    );
  }

  final selected = standardGeneratorKva.where((k) => k >= required).firstOrNull;
  if (selected == null) {
    return GeneratorResult(
      error: 'More than 2500 kVA needed: use parallel generator sets.',
      steps: steps,
    );
  }
  steps.add(
    'Choose the next standard ${i.duty == GeneratorDuty.prime ? 'prime' : 'standby'} '
    'rating: $selected kVA (${fmt(selected * 0.8, 0)} kW at 0.8 pf)',
  );

  final loading = runningKva / selected * 100;
  if (loading < 30) {
    warnings.add(
      'Normal running is only ${fmt(loading, 0)}% of the set. Diesel sets '
      'below about 30% load suffer wet stacking; consider a smaller set with '
      'a soft starter, or a load bank.',
    );
  }
  final fuel = 0.75 * selected * 0.8 * _litresPerKwh;
  steps.add(
    'Fuel at 75% load ≈ 0.75 × ${fmt(selected * 0.8, 0)} kW × '
    '$_litresPerKwh L/kWh = ${fmt(fuel)} L/h (typical)',
  );

  return GeneratorResult(
    runningKva: runningKva,
    designKva: designKva,
    motorStartKva: startKva,
    startRequirementKva: startReq,
    deratingFactor: derate,
    requiredKva: required,
    selectedKva: selected,
    loadingPct: loading,
    fuelLitresPerHour: fuel,
    warnings: warnings,
    steps: steps,
  );
}
