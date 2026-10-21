import 'package:flutter_test/flutter_test.dart';

import 'package:aoj_sitekit/calc/cable_sizing.dart';

CableInput input({
  CableStandard standard = CableStandard.bs7671,
  double load = 15,
  LoadUnit loadUnit = LoadUnit.kw,
  double voltage = 400,
  SupplyPhase phase = SupplyPhase.three,
  double pf = 0.85,
  double length = 40,
  LengthUnit lengthUnit = LengthUnit.m,
  ConductorMaterial material = ConductorMaterial.copper,
  Insulation insulation = Insulation.xlpe,
  InstallMethod method = InstallMethod.tray,
  double ambient = 35,
  int grouped = 3,
  double maxVd = 5,
}) => CableInput(
  standard: standard,
  load: load,
  loadUnit: loadUnit,
  voltage: voltage,
  phase: phase,
  powerFactor: pf,
  length: length,
  lengthUnit: lengthUnit,
  material: material,
  insulation: insulation,
  method: method,
  ambientTemp: ambient,
  groupedCircuits: grouped,
  maxVoltDropPct: maxVd,
);

void main() {
  test('BS 7671: 15 kW 3-phase on tray, 3 circuits at 35 °C', () {
    final r = calculateCable(input());
    // Ib = 15000 / (√3 × 400 × 0.85) = 25.47 A → 32 A Type C (pf < 0.95).
    expect(r.designCurrent, closeTo(25.47, 0.01));
    expect(r.deviceLabel, '32 A Type C MCB');
    // It ≥ 32 / (0.96 × 0.82) = 40.65 A → 4 mm² (42 A, Method E 3-core).
    expect(r.sizeLabel, '4 mm²');
    expect(r.capacity, closeTo(42 * 0.96 * 0.82, 0.01));
    // Vd = 10 × 25.47 × 40 / 1000 = 10.19 V = 2.55 %.
    expect(r.voltDrop, closeTo(10.19, 0.01));
    expect(r.voltDropPct, closeTo(2.55, 0.01));
    expect(r.safe, isTrue);
    expect(r.upsizeLabel, isNull);
  });

  test('long run fails voltage drop and suggests an upsize', () {
    final r = calculateCable(input(length: 150));
    // 4 mm²: 10 × 25.47 × 150 / 1000 = 38.2 V = 9.55 %; 6 mm² still 6.49 %.
    expect(r.sizeLabel, '4 mm²');
    expect(r.voltDropPct, closeTo(9.55, 0.01));
    expect(r.voltDropOk, isFalse);
    // 10 mm²: 4.0 × 25.47 × 150 / 1000 = 15.28 V = 3.82 %.
    expect(r.upsizeLabel, '10 mm²');

    final applied = calculateCable(
      input(length: 150),
      sizeFloor: r.upsizeIndex!,
    );
    expect(applied.sizeLabel, '10 mm²');
    expect(applied.voltDropPct, closeTo(3.82, 0.01));
    expect(applied.safe, isTrue);
  });

  test('single-phase PVC in conduit uses 2-core ratings', () {
    final r = calculateCable(
      input(
        load: 20,
        loadUnit: LoadUnit.amps,
        voltage: 230,
        phase: SupplyPhase.single,
        insulation: Insulation.pvc,
        method: InstallMethod.conduit,
        ambient: 30,
        grouped: 1,
      ),
    );
    // In = 20 A; It ≥ 20 A → 2.5 mm² (23 A, Method B 2-core PVC).
    expect(r.deviceRating, 20);
    expect(r.sizeLabel, '2.5 mm²');
  });

  test('aluminium starts at 16 mm²', () {
    final r = calculateCable(input(material: ConductorMaterial.aluminium));
    expect(r.sizeLabel, '16 mm²');
  });

  test('NEC: 30 A single-phase 240 V on THWN copper', () {
    final r = calculateCable(
      input(
        standard: CableStandard.nec,
        load: 30,
        loadUnit: LoadUnit.amps,
        voltage: 240,
        phase: SupplyPhase.single,
        length: 50,
        lengthUnit: LengthUnit.ft,
        insulation: Insulation.pvc,
        method: InstallMethod.conduit,
        ambient: 30,
        grouped: 1,
        maxVd: 3,
      ),
    );
    // 125 % × 30 = 37.5 A → 40 A breaker; 10 AWG (35 A) too small → 8 AWG.
    expect(r.deviceLabel, '40 A 2-pole breaker');
    expect(r.sizeLabel, '8 AWG');
    // Vd = 2 × 30 × 0.764 × 50 / 1000 = 2.29 V.
    expect(r.voltDrop, closeTo(2.292, 0.001));
  });

  test('invalid input returns an error', () {
    expect(calculateCable(input(pf: 1.5)).error, isNotNull);
    expect(calculateCable(input(length: 0)).error, isNotNull);
  });

  test('temperature outside table is rejected', () {
    expect(calculateCable(input(ambient: 80)).error, isNotNull);
  });
}
