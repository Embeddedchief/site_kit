import 'dart:math' as math;

import '../cable_sizing.dart';

/// Line current for a load. [voltage] is line-to-line for three-phase and
/// line-to-neutral for single-phase.
double loadCurrent({
  required double load,
  required LoadUnit unit,
  required double voltage,
  required SupplyPhase phase,
  double powerFactor = 1,
}) {
  final three = phase == SupplyPhase.three;
  final va = load * 1000;
  return switch (unit) {
    LoadUnit.amps => load,
    LoadUnit.kw =>
      three
          ? va / (math.sqrt(3) * voltage * powerFactor)
          : va / (voltage * powerFactor),
    LoadUnit.kva => three ? va / (math.sqrt(3) * voltage) : va / voltage,
  };
}

/// Smallest value in [ratings] that is at least [current], or null.
int? nextRating(List<int> ratings, double current) {
  for (final r in ratings) {
    if (r >= current) return r;
  }
  return null;
}

String fmt(double v, [int dp = 1]) => v.toStringAsFixed(dp);
