import 'package:flutter_test/flutter_test.dart';

import 'package:aoj_sitekit/calc/cable_sizing.dart';
import 'package:aoj_sitekit/calc/electrical/breaker_selection.dart';
import 'package:aoj_sitekit/calc/electrical/generator_sizing.dart';
import 'package:aoj_sitekit/calc/electrical/load_schedule.dart';
import 'package:aoj_sitekit/calc/electrical/voltage_drop.dart';

VoltDropInput vd({
  CableStandard standard = CableStandard.bs7671,
  SupplyPhase phase = SupplyPhase.three,
  double voltage = 400,
  double load = 15,
  LoadUnit unit = LoadUnit.kw,
  int size = 2, // 4 mm²
  double length = 40,
  LengthUnit lengthUnit = LengthUnit.m,
  Insulation insulation = Insulation.xlpe,
}) => VoltDropInput(
  standard: standard,
  phase: phase,
  voltage: voltage,
  load: load,
  loadUnit: unit,
  powerFactor: 0.85,
  material: ConductorMaterial.copper,
  insulation: insulation,
  sizeIndex: size,
  length: length,
  lengthUnit: lengthUnit,
  limitPct: standard == CableStandard.nec ? 3 : 5,
);

LoadItem item(
  String id,
  double kw, {
  LoadPhase phase = LoadPhase.l1,
  double pf = 1,
  double df = 1,
}) => LoadItem(
  id: id,
  name: id,
  quantity: 1,
  rating: kw,
  unit: RatingUnit.kw,
  powerFactor: pf,
  demandFactor: df,
  phase: phase,
);

void main() {
  group('voltage drop', () {
    test('BS 7671: 15 kW three-phase on 4 mm² XLPE, 40 m', () {
      final r = calculateVoltDrop(vd());
      // Ib = 25.47 A; Vd = 10 mV/A/m × 25.47 × 40 / 1000 = 10.19 V.
      expect(r.current, closeTo(25.47, 0.01));
      expect(r.drop, closeTo(10.19, 0.01));
      expect(r.dropPct, closeTo(2.55, 0.01));
      expect(r.endVoltage, closeTo(389.81, 0.01));
      // 5% of 400 V = 20 V → 20 / (0.010 × 25.47) = 78.5 m.
      expect(r.maxLength, closeTo(78.5, 0.1));
      // 2.5 mm²: 16 × 25.47 × 40 / 1000 = 16.3 V = 4.08% (within 5%).
      expect(r.minSizeLabel, '2.5 mm²');
    });

    test('NEC: 30 A single-phase on 8 AWG, 50 ft', () {
      final r = calculateVoltDrop(
        vd(
          standard: CableStandard.nec,
          phase: SupplyPhase.single,
          voltage: 240,
          load: 30,
          unit: LoadUnit.amps,
          size: 3,
          length: 50,
          lengthUnit: LengthUnit.ft,
        ),
      );
      // 2 × 30 × 0.764 × 50 / 1000 = 2.292 V.
      expect(r.drop, closeTo(2.292, 0.001));
      expect(r.dropPct, closeTo(0.955, 0.001));
    });

    test('rejects bad input', () {
      expect(calculateVoltDrop(vd(length: 0)).error, isNotNull);
      expect(calculateVoltDrop(vd(voltage: 0)).error, isNotNull);
    });
  });

  group('load schedule', () {
    test('phase currents, imbalance and main device', () {
      final s = summariseLoads(
        [item('motor', 10, phase: LoadPhase.three), item('heater', 4.6188)],
        supply: SupplyPhase.three,
        voltage: 400,
      );
      // 10 kW 3-phase: 3.333 kVA per phase / 230.94 V = 14.43 A.
      // Heater adds 4.6188 kVA / 230.94 V = 20 A on L1.
      expect(s.phaseCurrents[0], closeTo(34.43, 0.01));
      expect(s.phaseCurrents[1], closeTo(14.43, 0.01));
      expect(s.designCurrent, closeTo(34.43, 0.01));
      expect(s.imbalancePct, closeTo(63.2, 0.1));
      expect(s.mainDevice, 40);
      expect(s.demandKw, closeTo(14.6188, 1e-6));
    });

    test('demand and diversity factors', () {
      final s = summariseLoads(
        [item('a', 10, df: 0.5, pf: 0.8)],
        supply: SupplyPhase.single,
        voltage: 230,
        diversity: 0.8,
      );
      expect(s.connectedKva, closeTo(12.5, 1e-9));
      expect(s.demandKw, closeTo(4, 1e-9)); // 10 × 0.5 × 0.8
      expect(s.demandKva, closeTo(5, 1e-9));
      expect(s.designCurrent, closeTo(5000 / 230, 1e-9));
      expect(s.powerFactor, closeTo(0.8, 1e-9));
    });

    test('units: W, HP and kVA', () {
      final w = LoadItem(
        id: 'w',
        name: 'w',
        quantity: 10,
        rating: 20,
        unit: RatingUnit.w,
        powerFactor: 1,
        demandFactor: 1,
        phase: LoadPhase.l1,
      );
      expect(w.connectedKw, closeTo(0.2, 1e-12));
      final hp = LoadItem(
        id: 'h',
        name: 'h',
        quantity: 2,
        rating: 1.5,
        unit: RatingUnit.hp,
        powerFactor: 0.85,
        demandFactor: 1,
        phase: LoadPhase.l1,
      );
      expect(hp.connectedKw, closeTo(2.238, 1e-9));
      final kva = LoadItem(
        id: 'k',
        name: 'k',
        quantity: 1,
        rating: 10,
        unit: RatingUnit.kva,
        powerFactor: 0.8,
        demandFactor: 1,
        phase: LoadPhase.l1,
      );
      expect(kva.connectedKw, 8);
      expect(kva.connectedKva, 10);
    });

    test('3-phase load on single-phase supply is an error', () {
      final s = summariseLoads(
        [item('m', 5, phase: LoadPhase.three)],
        supply: SupplyPhase.single,
        voltage: 230,
      );
      expect(s.error, isNotNull);
    });

    test('auto-balance spreads single-phase loads', () {
      final balanced = autoBalance([item('a', 1), item('b', 3), item('c', 2)]);
      final phaseOf = {for (final l in balanced) l.id: l.phase};
      expect(phaseOf['b'], LoadPhase.l1);
      expect(phaseOf['c'], LoadPhase.l2);
      expect(phaseOf['a'], LoadPhase.l3);
    });

    test('JSON round-trip', () {
      final l = item('x', 2, phase: LoadPhase.l3, pf: 0.9, df: 0.7);
      final back = LoadItem.fromJson(l.toJson());
      expect(back.phase, LoadPhase.l3);
      expect(back.demandKva, closeTo(l.demandKva, 1e-12));
    });
  });

  group('breaker selection', () {
    test('BS 7671 socket circuit: 32 A Type B with RCD and max Zs', () {
      final r = selectBreaker(
        const BreakerInput(
          standard: CableStandard.bs7671,
          phase: SupplyPhase.single,
          designCurrent: 25.5,
          loadType: BreakerLoad.sockets,
          cableCapacity: 33,
        ),
      );
      expect(r.rating, 32);
      expect(r.device, 'MCB');
      expect(r.curve, 'B');
      expect(r.poles, '1-pole + N');
      // 0.95 × 230 / (5 × 32) = 1.37 Ω (BS 7671 Table 41.3: B32 = 1.37).
      expect(r.maxZs, closeTo(1.37, 0.005));
      expect(r.rcdAdvice, isNotNull);
      expect(r.allChecksPass, isTrue);
    });

    test('flags a breaker larger than the cable', () {
      final r = selectBreaker(
        const BreakerInput(
          standard: CableStandard.bs7671,
          phase: SupplyPhase.single,
          designCurrent: 25.5,
          loadType: BreakerLoad.lighting,
          cableCapacity: 27,
        ),
      );
      expect(r.allChecksPass, isFalse);
    });

    test('Table 41.3 values for C and D curves', () {
      BreakerResult r(BreakerLoad t) => selectBreaker(
        BreakerInput(
          standard: CableStandard.bs7671,
          phase: SupplyPhase.single,
          designCurrent: 30,
          loadType: t,
        ),
      );
      expect(r(BreakerLoad.inductive).maxZs, closeTo(0.68, 0.005)); // C32
      expect(r(BreakerLoad.motor).maxZs, closeTo(0.34, 0.005)); // D32
    });

    test(
      'above 125 A becomes an MCCB; fault level picks breaking capacity',
      () {
        final r = selectBreaker(
          const BreakerInput(
            standard: CableStandard.bs7671,
            phase: SupplyPhase.three,
            designCurrent: 150,
            loadType: BreakerLoad.motor,
            faultLevelKa: 20,
          ),
        );
        expect(r.rating, 160);
        expect(r.device, 'MCCB');
        expect(r.curve, isNull);
        expect(r.poles, '4-pole');
        expect(r.breakingCapacityKa, 25);
      },
    );

    test('NEC: 125% continuous load', () {
      final r = selectBreaker(
        const BreakerInput(
          standard: CableStandard.nec,
          phase: SupplyPhase.single,
          designCurrent: 30,
          loadType: BreakerLoad.lighting,
          voltage: 240,
        ),
      );
      expect(r.rating, 40);
      expect(r.poles, '2-pole');
    });
  });

  group('generator sizing', () {
    GeneratorInput gen({
      StartMethod start = StartMethod.dol,
      double altitude = 0,
      double ambient = 40,
    }) => GeneratorInput(
      runningKw: 50,
      powerFactor: 0.8,
      largestMotorKw: 15,
      startMethod: start,
      marginPct: 20,
      maxDipPct: 20,
      duty: GeneratorDuty.prime,
      altitudeM: altitude,
      ambientC: ambient,
    );

    test('DOL motor start drives the size', () {
      final r = sizeGenerator(gen());
      // 50 kW / 0.8 = 62.5 kVA; +20% = 75 kVA.
      expect(r.runningKva, closeTo(62.5, 1e-9));
      expect(r.designKva, closeTo(75, 1e-9));
      // Motor 15 / 0.765 = 19.61 kVA; DOL ×6 = 117.6 kVA.
      // Base 42.89 + 0.2 × 117.65 × 0.8 / 0.2 = 137.01 kVA → 150 kVA set.
      expect(r.motorStartKva, closeTo(117.65, 0.01));
      expect(r.startRequirementKva, closeTo(137.01, 0.01));
      expect(r.selectedKva, 150);
      expect(r.warnings, isNotEmpty);
    });

    test('a soft starter allows a smaller set', () {
      final r = sizeGenerator(gen(start: StartMethod.softStarter));
      // 42.89 + 0.2 × 58.82 × 4 = 89.95 kVA → 100 kVA.
      expect(r.selectedKva, 100);
    });

    test('site derating', () {
      expect(generatorDerating(1600, 45), closeTo(0.92 * 0.95, 1e-9));
      expect(generatorDerating(500, 30), 1);
    });

    test('rejects a motor bigger than the load', () {
      final r = sizeGenerator(
        const GeneratorInput(
          runningKw: 10,
          powerFactor: 0.8,
          largestMotorKw: 15,
          startMethod: StartMethod.dol,
          marginPct: 20,
          maxDipPct: 20,
          duty: GeneratorDuty.prime,
        ),
      );
      expect(r.error, isNotNull);
    });
  });
}
