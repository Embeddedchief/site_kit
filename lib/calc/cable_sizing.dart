import 'dart:math' as math;

// Cable sizing engine.
//
// BS 7671 / IEC 60364: multicore non-armoured cables, tabulated current
// ratings from BS 7671 Tables 4D2A/4E2A (= IEC 60364-5-52 Tables B.52.4,
// B.52.5, B.52.10, B.52.12), voltage drop from Tables 4D2B/4E2B.
// NEC: Table 310.16 ampacities, 310.15(B)(1) temperature correction,
// 310.15(C)(1) adjustment, Chapter 9 Table 8 resistance.
//
// Results are a design aid; final selection must be verified against the
// full standard and the cable manufacturer's data.

enum CableStandard {
  bs7671('BS 7671'),
  iec60364('IEC 60364'),
  nec('NEC');

  const CableStandard(this.label);
  final String label;
}

enum LoadUnit {
  kw('kW'),
  kva('kVA'),
  amps('A');

  const LoadUnit(this.label);
  final String label;
}

enum SupplyPhase {
  single('Single-phase'),
  three('Three-phase');

  const SupplyPhase(this.label);
  final String label;
}

enum ConductorMaterial {
  copper('Copper', 'Cu'),
  aluminium('Aluminium', 'Al');

  const ConductorMaterial(this.label, this.symbol);
  final String label;
  final String symbol;
}

enum Insulation {
  pvc('PVC 70°C', 'THWN 75°C'),
  xlpe('XLPE 90°C', 'XHHW-2 90°C');

  const Insulation(this.metricLabel, this.necLabel);
  final String metricLabel;
  final String necLabel;

  String labelFor(CableStandard s) =>
      s == CableStandard.nec ? necLabel : metricLabel;
}

enum InstallMethod {
  conduit('Conduit', 'Method B', 'In conduit / trunking'),
  tray('Tray', 'Method E', 'Perforated cable tray'),
  buried('Buried', 'Method D', 'In duct in the ground'),
  clipped('Clipped', 'Method C', 'Clipped direct to wall');

  const InstallMethod(this.label, this.reference, this.description);
  final String label;
  final String reference;
  final String description;
}

enum LengthUnit {
  m('m'),
  ft('ft');

  const LengthUnit(this.label);
  final String label;
}

class CableInput {
  const CableInput({
    required this.standard,
    required this.load,
    required this.loadUnit,
    required this.voltage,
    required this.phase,
    required this.powerFactor,
    required this.length,
    required this.lengthUnit,
    required this.material,
    required this.insulation,
    required this.method,
    required this.ambientTemp,
    required this.groupedCircuits,
    required this.maxVoltDropPct,
  });

  final CableStandard standard;
  final double load;
  final LoadUnit loadUnit;
  final double voltage;
  final SupplyPhase phase;
  final double powerFactor;
  final double length;
  final LengthUnit lengthUnit;
  final ConductorMaterial material;
  final Insulation insulation;
  final InstallMethod method;
  final double ambientTemp;
  final int groupedCircuits;
  final double maxVoltDropPct;

  bool get threePhase => phase == SupplyPhase.three;
  double get lengthM => lengthUnit == LengthUnit.m ? length : length * 0.3048;
  double get lengthFt => lengthUnit == LengthUnit.ft ? length : length / 0.3048;
}

class CableResult {
  const CableResult({
    required this.designCurrent,
    required this.formula,
    required this.steps,
    this.error,
    this.sizeIndex,
    this.sizeLabel,
    this.cableDescription,
    this.capacity,
    this.deviceRating,
    this.deviceLabel,
    this.voltDrop,
    this.voltDropPct,
    this.maxVoltDropPct,
    this.upsizeIndex,
    this.upsizeLabel,
  });

  final double designCurrent;
  final String formula;
  final List<String> steps;

  /// Set when no valid cable could be selected.
  final String? error;

  final int? sizeIndex;
  final String? sizeLabel;
  final String? cableDescription;

  /// Current-carrying capacity after correction factors (Iz), in amps.
  final double? capacity;
  final int? deviceRating;
  final String? deviceLabel;
  final double? voltDrop;
  final double? voltDropPct;
  final double? maxVoltDropPct;

  /// Smallest larger size that brings voltage drop within the limit.
  final int? upsizeIndex;
  final String? upsizeLabel;

  bool get voltDropOk =>
      voltDropPct != null && voltDropPct! <= maxVoltDropPct! + 1e-9;
  bool get safe => error == null && voltDropOk;
}

String _f(double v, [int dp = 1]) => v.toStringAsFixed(dp);

double designCurrent(CableInput i) {
  final w = i.load * 1000;
  return switch (i.loadUnit) {
    LoadUnit.amps => i.load,
    LoadUnit.kw =>
      i.threePhase
          ? w / (math.sqrt(3) * i.voltage * i.powerFactor)
          : w / (i.voltage * i.powerFactor),
    LoadUnit.kva =>
      i.threePhase ? w / (math.sqrt(3) * i.voltage) : w / i.voltage,
  };
}

String _formula(CableInput i) => switch (i.loadUnit) {
  LoadUnit.amps => 'Ib = load current',
  LoadUnit.kw => i.threePhase ? 'Ib = P / (√3 × V × pf)' : 'Ib = P / (V × pf)',
  LoadUnit.kva => i.threePhase ? 'Ib = S / (√3 × V)' : 'Ib = S / V',
};

String _ibStep(CableInput i, double ib) {
  final load = _f(i.load * 1000, 0);
  final v = _f(i.voltage, 0);
  final pf = i.powerFactor.toStringAsFixed(2);
  final working = switch (i.loadUnit) {
    LoadUnit.amps => '${_f(ib)} A (given)',
    LoadUnit.kw =>
      i.threePhase
          ? '$load / (1.732 × $v × $pf) = ${_f(ib)} A'
          : '$load / ($v × $pf) = ${_f(ib)} A',
    LoadUnit.kva =>
      i.threePhase
          ? '$load / (1.732 × $v) = ${_f(ib)} A'
          : '$load / $v = ${_f(ib)} A',
  };
  return 'Design current: ${_formula(i)} = $working';
}

String? _validate(CableInput i) {
  if (i.load <= 0) return 'Enter a load greater than zero.';
  if (i.voltage <= 0) return 'Enter a supply voltage greater than zero.';
  if (i.powerFactor <= 0 || i.powerFactor > 1) {
    return 'Power factor must be between 0 and 1.';
  }
  if (i.length <= 0) return 'Enter a cable length greater than zero.';
  if (i.groupedCircuits < 1) return 'Grouped circuits must be at least 1.';
  if (i.maxVoltDropPct <= 0) return 'Enter a voltage drop limit above 0%.';
  return null;
}

CableResult calculateCable(CableInput input, {int sizeFloor = 0}) {
  final invalid = _validate(input);
  if (invalid != null) {
    return CableResult(
      designCurrent: 0,
      formula: _formula(input),
      steps: const [],
      error: invalid,
    );
  }
  return input.standard == CableStandard.nec
      ? _necCalc(input, sizeFloor)
      : _metricCalc(input, sizeFloor);
}

// ---------------------------------------------------------------------------
// BS 7671 / IEC 60364
// ---------------------------------------------------------------------------

const metricSizes = [
  1.5, 2.5, 4, 6, 10, 16, 25, 35, 50, 70, 95, 120, 150, 185, 240, 300, //
];

String metricSizeLabel(int i) {
  final s = metricSizes[i];
  return '${s == s.roundToDouble() ? s.toInt() : s} mm²';
}

// Tabulated current It (A), copper, keyed by insulation, method and number
// of loaded conductors (2 = single-phase, 3 = three-phase).
const _metricCapacity =
    <Insulation, Map<InstallMethod, Map<int, List<double>>>>{
      Insulation.pvc: {
        InstallMethod.conduit: {
          2: [
            16.5,
            23,
            30,
            38,
            52,
            69,
            90,
            111,
            133,
            168,
            201,
            232,
            258,
            294,
            344,
            394,
          ],
          3: [
            15,
            20,
            27,
            34,
            46,
            62,
            80,
            99,
            118,
            149,
            179,
            206,
            225,
            255,
            297,
            339,
          ],
        },
        InstallMethod.clipped: {
          2: [
            19.5,
            27,
            36,
            46,
            63,
            85,
            112,
            138,
            168,
            213,
            258,
            299,
            344,
            392,
            461,
            530,
          ],
          3: [
            17.5,
            24,
            32,
            41,
            57,
            76,
            96,
            119,
            144,
            184,
            223,
            259,
            299,
            341,
            403,
            464,
          ],
        },
        InstallMethod.tray: {
          2: [
            22,
            30,
            40,
            51,
            70,
            94,
            119,
            148,
            180,
            232,
            282,
            328,
            379,
            434,
            514,
            593,
          ],
          3: [
            18.5,
            25,
            34,
            43,
            60,
            80,
            101,
            126,
            153,
            196,
            238,
            276,
            319,
            364,
            430,
            497,
          ],
        },
        InstallMethod.buried: {
          2: [
            22,
            29,
            37,
            46,
            60,
            78,
            99,
            119,
            140,
            173,
            204,
            231,
            261,
            292,
            336,
            379,
          ],
          3: [
            18,
            24,
            30,
            38,
            50,
            64,
            82,
            98,
            116,
            143,
            169,
            192,
            217,
            243,
            280,
            316,
          ],
        },
      },
      Insulation.xlpe: {
        InstallMethod.conduit: {
          2: [
            22,
            30,
            40,
            51,
            69,
            91,
            119,
            146,
            175,
            221,
            265,
            305,
            334,
            384,
            459,
            532,
          ],
          3: [
            19.5,
            26,
            35,
            44,
            60,
            80,
            105,
            128,
            154,
            194,
            233,
            268,
            300,
            340,
            398,
            455,
          ],
        },
        InstallMethod.clipped: {
          2: [
            24,
            33,
            45,
            58,
            80,
            107,
            138,
            171,
            209,
            269,
            328,
            382,
            441,
            506,
            599,
            693,
          ],
          3: [
            22,
            30,
            40,
            52,
            71,
            96,
            119,
            147,
            179,
            229,
            278,
            322,
            371,
            424,
            500,
            576,
          ],
        },
        InstallMethod.tray: {
          2: [
            26,
            36,
            49,
            63,
            86,
            115,
            149,
            185,
            225,
            289,
            352,
            410,
            473,
            542,
            641,
            741,
          ],
          3: [
            23,
            32,
            42,
            54,
            75,
            100,
            127,
            158,
            192,
            246,
            298,
            346,
            399,
            456,
            538,
            621,
          ],
        },
        InstallMethod.buried: {
          2: [
            25,
            33,
            43,
            53,
            71,
            91,
            116,
            139,
            164,
            203,
            239,
            271,
            306,
            343,
            395,
            446,
          ],
          3: [
            21,
            27,
            35,
            44,
            58,
            75,
            96,
            117,
            138,
            170,
            202,
            230,
            260,
            291,
            336,
            380,
          ],
        },
      },
    };

// Voltage drop (mV/A/m), copper, by insulation and loaded conductors.
const _metricMvAm = <Insulation, Map<int, List<double>>>{
  Insulation.pvc: {
    2: [
      29,
      18,
      11,
      7.3,
      4.4,
      2.8,
      1.75,
      1.25,
      0.93,
      0.65,
      0.49,
      0.39,
      0.33,
      0.28,
      0.24,
      0.21,
    ],
    3: [
      25,
      15,
      9.5,
      6.4,
      3.8,
      2.4,
      1.50,
      1.10,
      0.80,
      0.57,
      0.43,
      0.35,
      0.29,
      0.25,
      0.21,
      0.185,
    ],
  },
  Insulation.xlpe: {
    2: [
      31,
      19,
      12,
      7.9,
      4.7,
      2.9,
      1.90,
      1.35,
      1.00,
      0.69,
      0.52,
      0.42,
      0.35,
      0.29,
      0.24,
      0.21,
    ],
    3: [
      27,
      16,
      10,
      6.8,
      4.0,
      2.5,
      1.50,
      1.10,
      0.81,
      0.57,
      0.42,
      0.35,
      0.29,
      0.25,
      0.21,
      0.185,
    ],
  },
};

// Aluminium vs copper (IEC 60364-5-52 ratio); aluminium from 16 mm².
const _alCapacityFactor = 0.77;
const _alVoltDropFactor = 1.6;
const _alMinSizeIndex = 5;

// Ambient temperature correction: air (ref 30 °C) and ground (ref 20 °C).
const _airTemp = <Insulation, Map<int, double>>{
  Insulation.pvc: {
    10: 1.22,
    15: 1.17,
    20: 1.12,
    25: 1.06,
    30: 1.00,
    35: 0.94,
    40: 0.87,
    45: 0.79,
    50: 0.71,
    55: 0.61,
    60: 0.50,
  },
  Insulation.xlpe: {
    10: 1.15,
    15: 1.12,
    20: 1.08,
    25: 1.04,
    30: 1.00,
    35: 0.96,
    40: 0.91,
    45: 0.87,
    50: 0.82,
    55: 0.76,
    60: 0.71,
    65: 0.65,
    70: 0.58,
  },
};
const _groundTemp = <Insulation, Map<int, double>>{
  Insulation.pvc: {
    10: 1.10,
    15: 1.05,
    20: 1.00,
    25: 0.95,
    30: 0.89,
    35: 0.84,
    40: 0.77,
    45: 0.71,
    50: 0.63,
  },
  Insulation.xlpe: {
    10: 1.07,
    15: 1.04,
    20: 1.00,
    25: 0.96,
    30: 0.93,
    35: 0.89,
    40: 0.85,
    45: 0.80,
    50: 0.76,
  },
};

// Grouping factors for 1..9 circuits, then the value for larger groups.
const _grouping = <InstallMethod, List<double>>{
  InstallMethod.conduit: [
    1.00,
    0.80,
    0.70,
    0.65,
    0.60,
    0.57,
    0.54,
    0.52,
    0.50,
    0.45,
  ],
  InstallMethod.clipped: [
    1.00,
    0.85,
    0.79,
    0.75,
    0.73,
    0.72,
    0.72,
    0.71,
    0.70,
    0.70,
  ],
  InstallMethod.tray: [
    1.00,
    0.88,
    0.82,
    0.77,
    0.75,
    0.73,
    0.73,
    0.72,
    0.72,
    0.72,
  ],
  InstallMethod.buried: [
    1.00,
    0.85,
    0.75,
    0.70,
    0.65,
    0.60,
    0.57,
    0.54,
    0.52,
    0.50,
  ],
};

const _metricDeviceRatings = [
  6, 10, 16, 20, 25, 32, 40, 50, 63, 80, 100, 125, //
  160, 200, 250, 315, 400, 500, 630, 800,
];

class _MetricRefs {
  const _MetricRefs(this.temp, this.ground, this.group, this.capacity, this.vd);
  final String temp, ground, group;
  final Map<Insulation, String> capacity, vd;
}

const _bsRefs = _MetricRefs(
  'Table 4B1',
  'Table 4B2',
  'Table 4C1',
  {Insulation.pvc: 'Table 4D2A', Insulation.xlpe: 'Table 4E2A'},
  {Insulation.pvc: 'Table 4D2B', Insulation.xlpe: 'Table 4E2B'},
);
const _iecRefs = _MetricRefs(
  'Table B.52.14',
  'Table B.52.15',
  'Table B.52.17',
  {
    Insulation.pvc: 'Tables B.52.4/B.52.10',
    Insulation.xlpe: 'Tables B.52.5/B.52.12',
  },
  {Insulation.pvc: 'mV/A/m tables', Insulation.xlpe: 'mV/A/m tables'},
);

/// Linear interpolation; null outside the table range.
double? _interpolate(Map<int, double> table, double x) {
  final keys = table.keys.toList();
  if (x < keys.first || x > keys.last) return null;
  for (var k = 0; k < keys.length - 1; k++) {
    final a = keys[k], b = keys[k + 1];
    if (x <= b) {
      final t = (x - a) / (b - a);
      return table[a]! + (table[b]! - table[a]!) * t;
    }
  }
  return table[keys.last];
}

double _groupFactor(InstallMethod m, int n) {
  final list = _grouping[m]!;
  return list[math.min(n, list.length) - 1];
}

CableResult _metricCalc(CableInput i, int sizeFloor) {
  final refs = i.standard == CableStandard.bs7671 ? _bsRefs : _iecRefs;
  final std = i.standard.label;
  final ib = designCurrent(i);
  final formula = _formula(i);
  final steps = [_ibStep(i, ib)];

  CableResult fail(String error) => CableResult(
    designCurrent: ib,
    formula: formula,
    steps: steps,
    error: error,
  );

  final inRating = _metricDeviceRatings.where((r) => r >= ib).firstOrNull;
  if (inRating == null) {
    return fail(
      'Design current exceeds 800 A. Split the load or use '
      'parallel cables.',
    );
  }
  final device = inRating > 125
      ? 'MCCB'
      : (i.powerFactor >= 0.95 ? 'Type B MCB' : 'Type C MCB');
  steps.add('Protective device: In ≥ Ib, so $inRating A $device');

  final buried = i.method == InstallMethod.buried;
  final ca = _interpolate(
    (buried ? _groundTemp : _airTemp)[i.insulation]!,
    i.ambientTemp,
  );
  if (ca == null) {
    return fail(
      '${buried ? 'Ground' : 'Ambient'} temperature is outside '
      'the correction table for ${i.insulation.metricLabel}.',
    );
  }
  final cg = _groupFactor(i.method, i.groupedCircuits);
  steps.add(
    'Correction factors: Ca = ${ca.toStringAsFixed(2)} '
    '(${_f(i.ambientTemp, 0)} °C, ${buried ? refs.ground : refs.temp}), '
    'Cg = ${cg.toStringAsFixed(2)} (${i.groupedCircuits} circuit'
    '${i.groupedCircuits == 1 ? '' : 's'}, ${refs.group})',
  );

  final itRequired = inRating / (ca * cg);
  steps.add(
    'Required tabulated current: It ≥ In / (Ca × Cg) = $inRating / '
    '(${ca.toStringAsFixed(2)} × ${cg.toStringAsFixed(2)}) = '
    '${_f(itRequired)} A',
  );

  final loaded = i.threePhase ? 3 : 2;
  final al = i.material == ConductorMaterial.aluminium;
  final capacity = _metricCapacity[i.insulation]![i.method]![loaded]!;
  final mvAm = _metricMvAm[i.insulation]![loaded]!;
  double itAt(int k) => capacity[k] * (al ? _alCapacityFactor : 1);
  double mvAt(int k) => mvAm[k] * (al ? _alVoltDropFactor : 1);
  double vdAt(int k) => mvAt(k) * ib * i.lengthM / 1000;
  double pctAt(int k) => vdAt(k) / i.voltage * 100;

  final first = al ? _alMinSizeIndex : 0;
  int? ampacityIndex;
  for (var k = first; k < metricSizes.length; k++) {
    if (itAt(k) >= itRequired) {
      ampacityIndex = k;
      break;
    }
  }
  if (ampacityIndex == null) {
    return fail(
      'No single cable up to 300 mm² carries this load. Use '
      'parallel cables or reduce grouping.',
    );
  }

  final chosen = math.max(ampacityIndex, sizeFloor);
  final it = itAt(chosen);
  final iz = it * ca * cg;
  final alNote = al ? ' × $_alCapacityFactor Al' : '';
  steps.add(
    'Select ${metricSizeLabel(chosen)}: It = ${_f(it)} A$alNote '
    '(${refs.capacity[i.insulation]}, ${i.method.reference}) ≥ '
    '${_f(itRequired)} A, OK. Iz = It × Ca × Cg = ${_f(iz)} A',
  );
  if (chosen > ampacityIndex) {
    steps.add(
      'Upsized from ${metricSizeLabel(ampacityIndex)} to '
      '${metricSizeLabel(chosen)} to meet the voltage drop limit',
    );
  }

  final vd = vdAt(chosen);
  final pct = pctAt(chosen);
  final ok = pct <= i.maxVoltDropPct + 1e-9;
  steps.add(
    'Voltage drop: Vd = mV/A/m × Ib × L / 1000 = '
    '${mvAt(chosen).toStringAsFixed(2)} × ${_f(ib)} × '
    '${_f(i.lengthM)} / 1000 = ${_f(vd, 2)} V (${_f(pct, 2)}%), '
    '${ok ? 'OK, ≤' : 'exceeds'} ${_f(i.maxVoltDropPct)}% '
    '(${refs.vd[i.insulation]})',
  );

  int? upsize;
  if (!ok) {
    for (var k = chosen + 1; k < metricSizes.length; k++) {
      if (pctAt(k) <= i.maxVoltDropPct) {
        upsize = k;
        break;
      }
    }
  }

  final cores = i.threePhase ? '4-core' : '3-core';
  final ins = i.insulation == Insulation.xlpe ? 'XLPE' : 'PVC';
  return CableResult(
    designCurrent: ib,
    formula: formula,
    steps: steps,
    sizeIndex: chosen,
    sizeLabel: metricSizeLabel(chosen),
    cableDescription: '$cores $ins ${i.material.symbol} · $std',
    capacity: iz,
    deviceRating: inRating,
    deviceLabel: '$inRating A $device',
    voltDrop: vd,
    voltDropPct: pct,
    maxVoltDropPct: i.maxVoltDropPct,
    upsizeIndex: upsize,
    upsizeLabel: upsize == null ? null : metricSizeLabel(upsize),
  );
}

// ---------------------------------------------------------------------------
// NEC
// ---------------------------------------------------------------------------

const necSizes = [
  '14 AWG', '12 AWG', '10 AWG', '8 AWG', '6 AWG', '4 AWG', '3 AWG', //
  '2 AWG', '1 AWG', '1/0 AWG', '2/0 AWG', '3/0 AWG', '4/0 AWG',
  '250 kcmil', '300 kcmil', '350 kcmil', '400 kcmil', '500 kcmil',
  '600 kcmil',
];

// Table 310.16 ampacities by conductor temperature rating (°C).
const _necAmpacity = <ConductorMaterial, Map<int, List<double?>>>{
  ConductorMaterial.copper: {
    75: [
      20,
      25,
      35,
      50,
      65,
      85,
      100,
      115,
      130,
      150,
      175,
      200,
      230,
      255,
      285,
      310,
      335,
      380,
      420,
    ],
    90: [
      25,
      30,
      40,
      55,
      75,
      95,
      115,
      130,
      145,
      170,
      195,
      225,
      260,
      290,
      320,
      350,
      380,
      430,
      475,
    ],
  },
  ConductorMaterial.aluminium: {
    75: [
      null,
      20,
      30,
      40,
      50,
      65,
      75,
      90,
      100,
      120,
      135,
      155,
      180,
      205,
      230,
      250,
      270,
      310,
      340,
    ],
    90: [
      null,
      25,
      35,
      45,
      55,
      75,
      85,
      100,
      115,
      135,
      150,
      175,
      205,
      230,
      260,
      280,
      305,
      350,
      385,
    ],
  },
};

// Chapter 9 Table 8 DC resistance at 75 °C, ohm per 1000 ft.
const _necResistance = <ConductorMaterial, List<double?>>{
  ConductorMaterial.copper: [
    3.07,
    1.93,
    1.21,
    0.764,
    0.491,
    0.308,
    0.245,
    0.194,
    0.154,
    0.122,
    0.0967,
    0.0766,
    0.0608,
    0.0515,
    0.0429,
    0.0367,
    0.0321,
    0.0258,
    0.0214,
  ],
  ConductorMaterial.aluminium: [
    null,
    3.18,
    2.00,
    1.26,
    0.808,
    0.508,
    0.403,
    0.319,
    0.253,
    0.201,
    0.159,
    0.126,
    0.100,
    0.0847,
    0.0707,
    0.0605,
    0.0529,
    0.0424,
    0.0353,
  ],
};

// 310.15(B)(1): upper bound of each ambient band → factor for 75/90 °C.
const _necTemp = <(double, double?, double)>[
  (10, 1.20, 1.15),
  (15, 1.15, 1.12),
  (20, 1.11, 1.08),
  (25, 1.05, 1.04),
  (30, 1.00, 1.00),
  (35, 0.94, 0.96),
  (40, 0.88, 0.91),
  (45, 0.82, 0.87),
  (50, 0.75, 0.82),
  (55, 0.67, 0.76),
  (60, 0.58, 0.71),
  (65, 0.47, 0.65),
  (70, 0.33, 0.58),
  (75, null, 0.50),
  (80, null, 0.41),
  (85, null, 0.29),
];

const _necBreakers = [
  15, 20, 25, 30, 35, 40, 45, 50, 60, 70, 80, 90, 100, 110, 125, 150, //
  175, 200, 225, 250, 300, 350, 400, 450, 500, 600, 700, 800,
];

double? _necTempFactor(int rating, double ambient) {
  for (final (upTo, f75, f90) in _necTemp) {
    if (ambient <= upTo) return rating == 90 ? f90 : f75;
  }
  return null;
}

double _necAdjustment(int ccc) {
  if (ccc <= 3) return 1.0;
  if (ccc <= 6) return 0.80;
  if (ccc <= 9) return 0.70;
  if (ccc <= 20) return 0.50;
  if (ccc <= 30) return 0.45;
  if (ccc <= 40) return 0.40;
  return 0.35;
}

/// 240.4(D) small-conductor overcurrent limits.
int? _necSmallConductorLimit(ConductorMaterial m, int index) {
  if (m == ConductorMaterial.copper) {
    return const {0: 15, 1: 20, 2: 30}[index];
  }
  return const {1: 15, 2: 25}[index];
}

CableResult _necCalc(CableInput i, int sizeFloor) {
  final ib = designCurrent(i);
  final formula = _formula(i);
  final steps = [_ibStep(i, ib)];

  CableResult fail(String error) => CableResult(
    designCurrent: ib,
    formula: formula,
    steps: steps,
    error: error,
  );

  final required = ib * 1.25;
  steps.add(
    'Continuous load: 125% × Ib = ${_f(required)} A '
    '(NEC 210.20(A), 215.2)',
  );

  final ocpd = _necBreakers.where((r) => r >= required).firstOrNull;
  if (ocpd == null) {
    return fail(
      'Load exceeds an 800 A breaker. Split the load or use '
      'parallel sets.',
    );
  }
  final poles = i.threePhase ? 3 : (i.voltage <= 150 ? 1 : 2);
  steps.add('Overcurrent device: next standard size, $ocpd A (240.6(A))');

  final rating = i.insulation == Insulation.xlpe ? 90 : 75;
  final ct = _necTempFactor(rating, i.ambientTemp);
  if (ct == null || i.ambientTemp < 0) {
    return fail(
      'Ambient temperature is outside the NEC correction table '
      'for ${i.insulation.necLabel}.',
    );
  }
  final ccc = i.groupedCircuits * (i.threePhase ? 3 : 2);
  final adj = _necAdjustment(ccc);
  steps.add(
    'Correction: ${ct.toStringAsFixed(2)} (${_f(i.ambientTemp, 0)} °C, '
    '310.15(B)(1)); adjustment ${adj.toStringAsFixed(2)} ($ccc '
    'current-carrying conductors, 310.15(C)(1))',
  );

  final base = _necAmpacity[i.material]![rating]!;
  final at75 = _necAmpacity[i.material]![75]!;
  double? ampacityAt(int k) {
    if (base[k] == null) return null;
    // Terminations limit the usable ampacity to the 75 °C column, 110.14(C).
    return math.min(base[k]! * ct * adj, at75[k]!);
  }

  bool fits(int k) {
    final amp = ampacityAt(k);
    if (amp == null || amp < required) return false;
    final small = _necSmallConductorLimit(i.material, k);
    if (small != null && ocpd > small) return false;
    // 240.4(B): next standard breaker above the ampacity is permitted.
    final nextUp = _necBreakers.where((r) => r >= amp).firstOrNull ?? 0;
    return ocpd <= nextUp;
  }

  int? ampacityIndex;
  for (var k = 0; k < necSizes.length; k++) {
    if (fits(k)) {
      ampacityIndex = k;
      break;
    }
  }
  if (ampacityIndex == null) {
    return fail(
      'No single conductor up to 600 kcmil carries this load. '
      'Use parallel sets (310.10(G)).',
    );
  }

  final chosen = math.max(ampacityIndex, sizeFloor);
  final amp = ampacityAt(chosen)!;
  steps.add(
    'Select ${necSizes[chosen]}: ${_f(base[chosen]!, 0)} A '
    '(Table 310.16, $rating °C) × ${ct.toStringAsFixed(2)} × '
    '${adj.toStringAsFixed(2)}, limited to 75 °C terminals = '
    '${_f(amp)} A ≥ ${_f(required)} A, OK',
  );
  if (chosen > ampacityIndex) {
    steps.add(
      'Upsized from ${necSizes[ampacityIndex]} to '
      '${necSizes[chosen]} to meet the voltage drop limit',
    );
  }

  final r = _necResistance[i.material]!;
  final k = i.threePhase ? math.sqrt(3) : 2.0;
  double vdAt(int s) => k * ib * r[s]! * i.lengthFt / 1000;
  double pctAt(int s) => vdAt(s) / i.voltage * 100;
  final vd = vdAt(chosen);
  final pct = pctAt(chosen);
  final ok = pct <= i.maxVoltDropPct + 1e-9;
  steps.add(
    'Voltage drop: Vd = ${i.threePhase ? '1.732' : '2'} × Ib × R × '
    'L / 1000 = ${i.threePhase ? '1.732' : '2'} × ${_f(ib)} × '
    '${r[chosen]} × ${_f(i.lengthFt, 0)} ft / 1000 = ${_f(vd, 2)} V '
    '(${_f(pct, 2)}%), ${ok ? 'OK, ≤' : 'exceeds'} ${_f(i.maxVoltDropPct)}% '
    '(Chapter 9 Table 8)',
  );

  int? upsize;
  if (!ok) {
    for (var s = chosen + 1; s < necSizes.length; s++) {
      if (pctAt(s) <= i.maxVoltDropPct) {
        upsize = s;
        break;
      }
    }
  }

  final conductors = i.threePhase ? 3 : 2;
  final insulation = i.insulation.necLabel.split(' ').first;
  return CableResult(
    designCurrent: ib,
    formula: formula,
    steps: steps,
    sizeIndex: chosen,
    sizeLabel: necSizes[chosen],
    cableDescription:
        '$conductors × ${i.material.symbol} $insulation + EGC · NEC',
    capacity: amp,
    deviceRating: ocpd,
    deviceLabel: '$ocpd A $poles-pole breaker',
    voltDrop: vd,
    voltDropPct: pct,
    maxVoltDropPct: i.maxVoltDropPct,
    upsizeIndex: upsize,
    upsizeLabel: upsize == null ? null : necSizes[upsize],
  );
}

// ---------------------------------------------------------------------------
// Shared lookups for the other electrical tools
// ---------------------------------------------------------------------------

/// First metric size index available for [m] (aluminium starts at 16 mm²).
int metricFirstSize(ConductorMaterial m) =>
    m == ConductorMaterial.aluminium ? _alMinSizeIndex : 0;

/// Voltage drop in mV/A/m for a metric multicore cable.
double metricMvPerAm(
  Insulation ins,
  SupplyPhase phase,
  ConductorMaterial m,
  int sizeIndex,
) {
  final loaded = phase == SupplyPhase.three ? 3 : 2;
  return _metricMvAm[ins]![loaded]![sizeIndex] *
      (m == ConductorMaterial.aluminium ? _alVoltDropFactor : 1);
}

/// First NEC size index available for [m] (no 14 AWG aluminium).
int necFirstSize(ConductorMaterial m) =>
    m == ConductorMaterial.aluminium ? 1 : 0;

/// NEC Chapter 9 Table 8 resistance, ohm per 1000 ft.
double necOhmsPerKft(ConductorMaterial m, int sizeIndex) =>
    _necResistance[m]![sizeIndex]!;

/// Standard protective device ratings (A): BS EN 60898 / 60947-2 series.
const List<int> metricDeviceRatings = _metricDeviceRatings;

/// NEC 240.6(A) standard overcurrent device ratings (A).
const List<int> necDeviceRatings = _necBreakers;
