import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppNotification {
  const AppNotification({
    required this.title,
    required this.body,
    required this.createdAt,
    this.read = false,
  });

  final String title;
  final String body;
  final DateTime createdAt;
  final bool read;

  AppNotification markRead() => AppNotification(
    title: title,
    body: body,
    createdAt: createdAt,
    read: true,
  );

  Map<String, dynamic> toJson() => {
    'title': title,
    'body': body,
    'createdAt': createdAt.toIso8601String(),
    'read': read,
  };

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      AppNotification(
        title: json['title'] as String,
        body: json['body'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        read: json['read'] as bool? ?? false,
      );
}

/// In-app notifications, newest first. Listen to [items] for updates.
class Notifications {
  static const _key = 'notifications';
  static const _seededKey = 'notifications_seeded';

  static final items = ValueNotifier<List<AppNotification>>(const []);

  static int get unread => items.value.where((n) => !n.read).length;

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    items.value = (prefs.getStringList(_key) ?? const [])
        .map(
          (s) =>
              AppNotification.fromJson(jsonDecode(s) as Map<String, dynamic>),
        )
        .toList();
    if (!(prefs.getBool(_seededKey) ?? false)) {
      await prefs.setBool(_seededKey, true);
      await add(
        AppNotification(
          title: 'Welcome to SiteKit',
          body: 'Pin the tools you use most with the star on any tool.',
          createdAt: DateTime.now(),
        ),
      );
    }
  }

  static Future<void> add(AppNotification n) async {
    items.value = [n, ...items.value];
    await _save();
  }

  static Future<void> markAllRead() async {
    if (unread == 0) return;
    items.value = [for (final n in items.value) n.markRead()];
    await _save();
  }

  static Future<void> clear() async {
    items.value = const [];
    await _save();
  }

  static Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _key,
      items.value.map((n) => jsonEncode(n.toJson())).toList(),
    );
  }
}
