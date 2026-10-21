import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/notifications.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  @override
  void dispose() {
    // Everything shown on this visit counts as read once the user leaves.
    Notifications.markAllRead();
    super.dispose();
  }

  String _when(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'Just now';
    if (d.inHours < 1) return '${d.inMinutes} min ago';
    if (d.inDays < 1) return '${d.inHours} hr ago';
    if (d.inDays == 1) return 'Yesterday';
    return '${t.day}/${t.month}/${t.year}';
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppColors.bg,
        body: Column(
          children: [
            PageHeader(
              title: 'Notifications',
              trailing: ValueListenableBuilder(
                valueListenable: Notifications.items,
                builder: (_, items, _) => items.isEmpty
                    ? const SizedBox.shrink()
                    : TextButton(
                        onPressed: Notifications.clear,
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.red,
                        ),
                        child: const Text('Clear all'),
                      ),
              ),
            ),
            Expanded(
              child: ValueListenableBuilder<List<AppNotification>>(
                valueListenable: Notifications.items,
                builder: (_, items, _) => items.isEmpty
                    ? const _Empty()
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: items.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (_, i) {
                          final n = items[i];
                          return Container(
                            padding: const EdgeInsets.all(14),
                            decoration: cardDecoration(),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  margin: const EdgeInsets.only(
                                    top: 6,
                                    right: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: n.read
                                        ? Colors.transparent
                                        : AppColors.red,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        n.title,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.ink,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        n.body,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          height: 1.4,
                                          color: AppColors.muted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _when(n.createdAt),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.faint,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.notifications_none_rounded,
            size: 40,
            color: AppColors.chevron,
          ),
          SizedBox(height: 10),
          Text(
            "You're all caught up",
            style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.ink),
          ),
        ],
      ),
    );
  }
}
