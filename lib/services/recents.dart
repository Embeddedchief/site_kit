import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RecentCalc {
  const RecentCalc({
    required this.toolId,
    required this.tool,
    required this.result,
    required this.site,
    required this.savedAt,
  });

  final String toolId;
  final String tool;
  final String result;
  final String site;
  final DateTime savedAt;

  Map<String, dynamic> toJson() => {
    'toolId': toolId,
    'tool': tool,
    'result': result,
    'site': site,
    'savedAt': savedAt.toIso8601String(),
  };

  factory RecentCalc.fromJson(Map<String, dynamic> json) => RecentCalc(
    toolId: json['toolId'] as String,
    tool: json['tool'] as String,
    result: json['result'] as String,
    site: json['site'] as String,
    savedAt: DateTime.parse(json['savedAt'] as String),
  );

  String get ago {
    final diff = DateTime.now().difference(savedAt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes} min ago';
    if (diff.inDays < 1) return '${diff.inHours} hr ago';
    if (diff.inDays == 1) return 'Yesterday';
    return '${diff.inDays} days ago';
  }
}

/// Saved calculations, newest first. Listen to [items] for live updates.
class Recents {
  static const _key = 'recent_calcs';
  static const _max = 20;

  static final items = ValueNotifier<List<RecentCalc>>(const []);

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    items.value = (prefs.getStringList(_key) ?? const [])
        .map((s) => RecentCalc.fromJson(jsonDecode(s) as Map<String, dynamic>))
        .toList();
  }

  static Future<void> add(RecentCalc calc) async {
    items.value = [calc, ...items.value].take(_max).toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _key,
      items.value.map((c) => jsonEncode(c.toJson())).toList(),
    );
  }
}
