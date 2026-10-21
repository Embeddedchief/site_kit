import '../cable_sizing.dart';
import 'common.dart';

// Protective device selection.
// BS 7671 / IEC 60364: Ib ≤ In ≤ Iz (433.1); with MCBs/MCCBs I2 = 1.45 In,
// so I2 ≤ 1.45 Iz follows. Curve by load type (BS EN 60898), maximum earth
// fault loop impedance from Table 41.3 (Uo 230 V, Cmin 0.95).
// NEC: OCPD ≥ 125% of continuous load (210.20(A)), standard sizes 240.6(A),
// next size up permitted over conductor ampacity up to 800 A (240.4(B)).

enum BreakerLoad {
  lighting('Lighting & resistive', 'B'),
  sockets('Socket outlets', 'B'),
  inductive('Inductive / small motors', 'C'),
  motor('Motors DOL / transformers', 'D');

  const BreakerLoad(this.label, this.curve);
  final String label;
  final String curve;
}

class BreakerInput {
  const BreakerInput({
    required this.standard,
    required this.phase,
    required this.designCurrent,
    required this.loadType,
    this.cableCapacity,
    this.faultLevelKa,
    this.withNeutral = true,
    this.voltage = 230,
  });

  final CableStandard standard;
  final SupplyPhase phase;
  final double designCurrent;
  final BreakerLoad loadType;

  /// Cable current-carrying capacity Iz (A), if known.
  final double? cableCapacity;

  /// Prospective short-circuit current at the board (kA), if known.
  final double? faultLevelKa;

  /// Three-phase circuits with a switched neutral need 4 poles.
  final bool withNeutral;

  /// Line-to-neutral (single-phase) or line-to-line (three-phase) voltage,
  /// used for NEC pole count.
  final double voltage;
}

class BreakerCheck {
  const BreakerCheck(this.label, this.pass, this.detail);
  final String label;
  final bool pass;
  final String detail;
}

class BreakerResult {
  const BreakerResult({
    this.error,
    this.rating = 0,
    this.device = '',
    this.curve,
    this.poles = '',
    this.breakingCapacityKa,
    this.maxZs,
    this.rcdAdvice,
    this.checks = const [],
    this.steps = const [],
  });

  final String? error;
  final int rating;
  final String device;

  /// MCB tripping curve (B, C or D); null for MCCB/ACB.
  final String? curve;
  final String poles;
  final int? breakingCapacityKa;

  /// Maximum earth fault loop impedance for disconnection (Ω), MCB only.
  final double? maxZs;
  final String? rcdAdvice;
  final List<BreakerCheck> checks;
  final List<String> steps;

  bool get allChecksPass => checks.every((c) => c.pass);

  String get summary =>
      ['$rating A', if (curve != null) 'Type $curve', device, poles].join(' ');
}

const _mcbBreaking = [6, 10, 15, 25];
const _mccbBreaking = [16, 25, 36, 50, 70, 100, 150];

/// Instantaneous trip multiple of In used for maximum Zs (BS EN 60898).
const _curveMultiple = {'B': 5, 'C': 10, 'D': 20};

BreakerResult selectBreaker(BreakerInput i) {
  if (i.designCurrent <= 0) {
    return const BreakerResult(error: 'Enter the design current.');
  }
  final iz = i.cableCapacity;
  if (iz != null && iz <= 0) {
    return const BreakerResult(error: 'Cable capacity must be above 0 A.');
  }
  return i.standard == CableStandard.nec ? _nec(i) : _metric(i);
}

BreakerResult _metric(BreakerInput i) {
  final ib = i.designCurrent;
  final rating = nextRating(metricDeviceRatings, ib);
  if (rating == null) {
    return const BreakerResult(
      error:
          'Above 800 A: use an air circuit breaker (ACB) sized with the '
          'manufacturer.',
    );
  }
  final mcb = rating <= 125;
  final device = mcb ? 'MCB' : 'MCCB';
  final curve = mcb ? i.loadType.curve : null;
  final three = i.phase == SupplyPhase.three;
  final poles = three
      ? (i.withNeutral ? '4-pole' : '3-pole')
      : (mcb ? '1-pole + N' : '2-pole');

  final steps = <String>[
    'Select In ≥ Ib: ${fmt(ib)} A, so $rating A (standard rating)',
    mcb
        ? 'Up to 125 A: MCB to BS EN 60898, Type $curve for '
              '${i.loadType.label.toLowerCase()}'
        : 'Above 125 A: MCCB to BS EN 60947-2 with adjustable thermal and '
              'magnetic trips',
  ];

  final checks = <BreakerCheck>[
    BreakerCheck('Ib ≤ In', ib <= rating, '${fmt(ib)} A ≤ $rating A'),
  ];
  final iz = i.cableCapacity;
  if (iz != null) {
    final ok = rating <= iz;
    checks.add(
      BreakerCheck(
        'In ≤ Iz (BS 7671 433.1)',
        ok,
        ok
            ? '$rating A ≤ ${fmt(iz)} A cable rating'
            : '$rating A exceeds the ${fmt(iz)} A cable: use a larger cable',
      ),
    );
    checks.add(
      BreakerCheck(
        'I2 ≤ 1.45 Iz',
        1.45 * rating <= 1.45 * iz,
        'I2 = 1.45 × $rating = ${fmt(1.45 * rating)} A ≤ '
            '${fmt(1.45 * iz)} A',
      ),
    );
  }

  int? breaking;
  final fault = i.faultLevelKa;
  if (fault != null && fault > 0) {
    final series = mcb ? _mcbBreaking : _mccbBreaking;
    breaking = series.where((k) => k >= fault).firstOrNull;
    checks.add(
      BreakerCheck(
        'Breaking capacity ≥ fault level',
        breaking != null,
        breaking != null
            ? '$breaking kA ≥ ${fmt(fault)} kA prospective fault current'
            : '${fmt(fault)} kA is beyond ${mcb ? 'MCB' : 'MCCB'} ratings: '
                  'use a higher-rated device or upstream backup protection',
      ),
    );
  } else {
    breaking = mcb ? 6 : 25;
    steps.add(
      'No fault level entered: minimum $breaking kA assumed. Measure or '
      'obtain the prospective fault current to confirm.',
    );
  }

  double? maxZs;
  if (curve != null) {
    maxZs = 0.95 * 230 / (_curveMultiple[curve]! * rating);
    steps.add(
      'Max Zs = 0.95 × 230 / (${_curveMultiple[curve]} × $rating) = '
      '${maxZs.toStringAsFixed(2)} ohm (Table 41.3, 0.4 s)',
    );
  }

  return BreakerResult(
    rating: rating,
    device: device,
    curve: curve,
    poles: poles,
    breakingCapacityKa: breaking,
    maxZs: maxZs,
    rcdAdvice: i.loadType == BreakerLoad.sockets
        ? 'Socket circuits up to 32 A need 30 mA RCD protection '
              '(BS 7671 411.3.3). Use an RCBO or RCD-protected way.'
        : null,
    checks: checks,
    steps: steps,
  );
}

BreakerResult _nec(BreakerInput i) {
  final ib = i.designCurrent;
  final required = ib * 1.25;
  final rating = nextRating(necDeviceRatings, required);
  if (rating == null) {
    return const BreakerResult(
      error: 'Above 800 A: size the breaker with the manufacturer.',
    );
  }
  final three = i.phase == SupplyPhase.three;
  final poles = three ? '3-pole' : (i.voltage <= 150 ? '1-pole' : '2-pole');
  final steps = <String>[
    'Continuous load: 125% × ${fmt(ib)} A = ${fmt(required)} A '
        '(210.20(A))',
    'Next standard size: $rating A (240.6(A))',
    if (i.loadType == BreakerLoad.motor || i.loadType == BreakerLoad.inductive)
      'Motor branch circuits may use an inverse-time breaker up to 250% '
          'of FLC to ride through starting (430.52).',
  ];
  final checks = <BreakerCheck>[
    BreakerCheck(
      'OCPD ≥ 125% of load',
      rating >= required,
      '$rating A ≥ ${fmt(required)} A',
    ),
  ];
  final iz = i.cableCapacity;
  if (iz != null) {
    final nextAboveIz = nextRating(necDeviceRatings, iz) ?? 0;
    final ok = rating <= iz || (rating == nextAboveIz && rating <= 800);
    checks.add(
      BreakerCheck(
        'Conductor protected (240.4)',
        ok,
        ok
            ? '$rating A protects the ${fmt(iz)} A conductor'
            : '$rating A is too large for a ${fmt(iz)} A conductor',
      ),
    );
  }
  int? interrupting;
  final fault = i.faultLevelKa;
  if (fault != null && fault > 0) {
    interrupting = const [
      10,
      14,
      18,
      22,
      25,
      35,
      42,
      65,
      100,
    ].where((k) => k >= fault).firstOrNull;
    checks.add(
      BreakerCheck(
        'Interrupting rating (110.9)',
        interrupting != null,
        interrupting != null
            ? '$interrupting kA AIC ≥ ${fmt(fault)} kA available fault current'
            : 'Fault current beyond standard ratings',
      ),
    );
  } else {
    interrupting = 10;
  }
  return BreakerResult(
    rating: rating,
    device: 'breaker',
    poles: poles,
    breakingCapacityKa: interrupting,
    rcdAdvice: i.loadType == BreakerLoad.sockets
        ? 'Receptacles in kitchens, bathrooms, outdoors and other wet '
              'locations need GFCI protection (210.8).'
        : null,
    checks: checks,
    steps: steps,
  );
}
