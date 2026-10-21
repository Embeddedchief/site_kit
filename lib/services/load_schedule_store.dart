import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../calc/cable_sizing.dart';
import '../calc/electrical/load_schedule.dart';

/// The user's working load schedule, kept between visits.
class LoadSchedule {
  const LoadSchedule({
    this.supply = SupplyPhase.three,
    this.voltage = 400,
    this.diversity = 1,
    this.items = const [],
  });

  final SupplyPhase supply;
  final double voltage;
  final double diversity;
  final List<LoadItem> items;

  LoadSummary get summary => summariseLoads(
    items,
    supply: supply,
    voltage: voltage,
    diversity: diversity,
  );

  Map<String, dynamic> toJson() => {
    'supply': supply.name,
    'voltage': voltage,
    'diversity': diversity,
    'items': [for (final i in items) i.toJson()],
  };

  factory LoadSchedule.fromJson(Map<String, dynamic> j) => LoadSchedule(
    supply: SupplyPhase.values.byName(j['supply'] as String),
    voltage: (j['voltage'] as num).toDouble(),
    diversity: (j['diversity'] as num).toDouble(),
    items: [
      for (final i in j['items'] as List)
        LoadItem.fromJson(i as Map<String, dynamic>),
    ],
  );
}

class LoadScheduleStore {
  static const _key = 'load_schedule';

  static Future<LoadSchedule> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) return const LoadSchedule();
      return LoadSchedule.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (e) {
      debugPrint('Load schedule unreadable, starting fresh: $e');
      return const LoadSchedule();
    }
  }

  static Future<void> save(LoadSchedule s) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode(s.toJson()));
    } catch (e) {
      debugPrint('Saving load schedule failed: $e');
    }
  }
}
