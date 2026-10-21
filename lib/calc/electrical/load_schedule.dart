import 'dart:math' as math;

import '../cable_sizing.dart';
import 'common.dart';

// Load schedule: connected load, maximum demand after demand and diversity
// factors, phase balance and the resulting design current.

enum LoadPhase {
  l1('L1'),
  l2('L2'),
  l3('L3'),
  three('3-phase');

  const LoadPhase(this.label);
  final String label;
}

enum RatingUnit {
  w('W'),
  kw('kW'),
  hp('HP'),
  kva('kVA');

  const RatingUnit(this.label);
  final String label;
}

const kwPerHp = 0.746;

class LoadItem {
  const LoadItem({
    required this.id,
    required this.name,
    required this.quantity,
    required this.rating,
    required this.unit,
    required this.powerFactor,
    required this.demandFactor,
    required this.phase,
  });

  final String id;
  final String name;
  final int quantity;

  /// Rating of one item, in [unit]. HP is taken as electrical input at
  /// 0.746 kW per HP (no motor efficiency applied).
  final double rating;
  final RatingUnit unit;
  final double powerFactor;

  /// Fraction of the connected load expected at the same time (0–1).
  final double demandFactor;
  final LoadPhase phase;

  double get connectedKw => switch (unit) {
    RatingUnit.w => rating * quantity / 1000,
    RatingUnit.kw => rating * quantity,
    RatingUnit.hp => rating * quantity * kwPerHp,
    RatingUnit.kva => rating * quantity * powerFactor,
  };

  double get connectedKva =>
      unit == RatingUnit.kva ? rating * quantity : connectedKw / powerFactor;

  double get demandKw => connectedKw * demandFactor;
  double get demandKva => connectedKva * demandFactor;

  LoadItem copyWith({LoadPhase? phase}) => LoadItem(
    id: id,
    name: name,
    quantity: quantity,
    rating: rating,
    unit: unit,
    powerFactor: powerFactor,
    demandFactor: demandFactor,
    phase: phase ?? this.phase,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'quantity': quantity,
    'rating': rating,
    'unit': unit.name,
    'pf': powerFactor,
    'df': demandFactor,
    'phase': phase.name,
  };

  factory LoadItem.fromJson(Map<String, dynamic> j) => LoadItem(
    id: j['id'] as String,
    name: j['name'] as String,
    quantity: (j['quantity'] as num).toInt(),
    rating: (j['rating'] as num).toDouble(),
    unit: RatingUnit.values.byName(j['unit'] as String),
    powerFactor: (j['pf'] as num).toDouble(),
    demandFactor: (j['df'] as num).toDouble(),
    phase: LoadPhase.values.byName(j['phase'] as String),
  );
}

/// Typical allowances to start from; users edit them to suit.
class LoadPreset {
  const LoadPreset(
    this.name,
    this.rating,
    this.unit,
    this.powerFactor,
    this.demandFactor, {
    this.threePhase = false,
  });

  final String name;
  final double rating;
  final RatingUnit unit;
  final double powerFactor;
  final double demandFactor;
  final bool threePhase;
}

const loadPresets = [
  LoadPreset('Lighting point', 20, RatingUnit.w, 0.95, 0.9),
  LoadPreset('Socket outlet', 200, RatingUnit.w, 0.9, 0.5),
  LoadPreset('Ceiling fan', 75, RatingUnit.w, 0.9, 1),
  LoadPreset('Split AC 1 HP', 1, RatingUnit.hp, 0.85, 1),
  LoadPreset('Split AC 1.5 HP', 1.5, RatingUnit.hp, 0.85, 1),
  LoadPreset('Split AC 2 HP', 2, RatingUnit.hp, 0.85, 1),
  LoadPreset('Refrigerator', 150, RatingUnit.w, 0.8, 1),
  LoadPreset('Water heater', 3, RatingUnit.kw, 1, 1),
  LoadPreset('Electric cooker', 3, RatingUnit.kw, 1, 0.5),
  LoadPreset('Computer / office', 250, RatingUnit.w, 0.9, 0.7),
  LoadPreset('Water pump 1.5 HP', 1.5, RatingUnit.hp, 0.8, 1),
  LoadPreset(
    'Borehole pump 3-ph',
    2.2,
    RatingUnit.kw,
    0.8,
    1,
    threePhase: true,
  ),
  LoadPreset('Lift motor 3-ph', 7.5, RatingUnit.kw, 0.85, 1, threePhase: true),
];

class LoadSummary {
  const LoadSummary({
    required this.connectedKw,
    required this.connectedKva,
    required this.demandKw,
    required this.demandKva,
    required this.phaseKva,
    required this.phaseCurrents,
    required this.designCurrent,
    required this.imbalancePct,
    required this.mainDevice,
    this.error,
  });

  final double connectedKw;
  final double connectedKva;

  /// Maximum demand after demand factors and the overall diversity factor.
  final double demandKw;
  final double demandKva;

  /// Per phase (L1, L2, L3); single-phase supplies use L1 only.
  final List<double> phaseKva;
  final List<double> phaseCurrents;
  final double designCurrent;

  /// Largest deviation from the average phase current, as % of the average.
  final double imbalancePct;

  /// Smallest standard protective device rating at or above the design
  /// current, or null if above 800 A.
  final int? mainDevice;
  final String? error;

  double get powerFactor => demandKva == 0 ? 1 : demandKw / demandKva;
}

LoadSummary summariseLoads(
  List<LoadItem> loads, {
  required SupplyPhase supply,
  required double voltage,
  double diversity = 1,
}) {
  final three = supply == SupplyPhase.three;
  String? error;
  if (voltage <= 0) error = 'Enter the supply voltage.';
  if (!three && loads.any((l) => l.phase == LoadPhase.three)) {
    error = 'A 3-phase load is on a single-phase supply.';
  }

  final connectedKw = loads.fold(0.0, (a, l) => a + l.connectedKw);
  final connectedKva = loads.fold(0.0, (a, l) => a + l.connectedKva);
  final demandKw = loads.fold(0.0, (a, l) => a + l.demandKw) * diversity;
  final demandKva = loads.fold(0.0, (a, l) => a + l.demandKva) * diversity;

  final phaseKva = [0.0, 0.0, 0.0];
  for (final l in loads) {
    final kva = l.demandKva * diversity;
    if (!three) {
      phaseKva[0] += kva;
    } else if (l.phase == LoadPhase.three) {
      for (var p = 0; p < 3; p++) {
        phaseKva[p] += kva / 3;
      }
    } else {
      phaseKva[l.phase.index] += kva;
    }
  }

  final phaseVoltage = three ? voltage / math.sqrt(3) : voltage;
  final currents = [
    for (final kva in phaseKva) voltage <= 0 ? 0.0 : kva * 1000 / phaseVoltage,
  ];
  final design = currents.reduce(math.max);
  var imbalance = 0.0;
  if (three) {
    final avg = currents.reduce((a, b) => a + b) / 3;
    if (avg > 0) {
      final worst = currents.map((c) => (c - avg).abs()).reduce(math.max);
      imbalance = worst / avg * 100;
    }
  }

  return LoadSummary(
    connectedKw: connectedKw,
    connectedKva: connectedKva,
    demandKw: demandKw,
    demandKva: demandKva,
    phaseKva: phaseKva,
    phaseCurrents: currents,
    designCurrent: design,
    imbalancePct: imbalance,
    mainDevice: nextRating(metricDeviceRatings, design),
    error: error,
  );
}

/// Reassigns single-phase loads to phases, largest first onto the least
/// loaded phase, to minimise imbalance. 3-phase loads are left as they are.
List<LoadItem> autoBalance(List<LoadItem> loads) {
  final totals = [0.0, 0.0, 0.0];
  for (final l in loads.where((l) => l.phase == LoadPhase.three)) {
    for (var p = 0; p < 3; p++) {
      totals[p] += l.demandKva / 3;
    }
  }
  final single = loads.where((l) => l.phase != LoadPhase.three).toList()
    ..sort((a, b) => b.demandKva.compareTo(a.demandKva));
  final assigned = <String, LoadPhase>{};
  for (final l in single) {
    var p = 0;
    for (var k = 1; k < 3; k++) {
      if (totals[k] < totals[p]) p = k;
    }
    totals[p] += l.demandKva;
    assigned[l.id] = LoadPhase.values[p];
  }
  return [
    for (final l in loads)
      assigned.containsKey(l.id) ? l.copyWith(phase: assigned[l.id]) : l,
  ];
}
