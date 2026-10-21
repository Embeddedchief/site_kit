import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'reveal.dart';

void showMessage(BuildContext context, String text) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(text),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.ink,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
}

void showComingSoon(BuildContext context, String what) =>
    showMessage(context, '${what.replaceAll('\n', ' ')} is coming soon');

BoxDecoration cardDecoration() => BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.circular(16),
  border: Border.all(color: AppColors.border),
);

/// Red icon on a soft red rounded square.
class IconTile extends StatelessWidget {
  const IconTile(this.icon, {super.key, this.size = 44});

  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.redTint,
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: Icon(icon, color: AppColors.red, size: size * 0.5),
    );
  }
}

/// Plain white top bar used by every inner page.
class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onBack,
    this.bottom,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onBack;

  /// Optional row below the title, such as filters or a mode switch.
  final Widget? bottom;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Container(
      padding: EdgeInsets.fromLTRB(4, top + 4, 12, bottom == null ? 8 : 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: onBack ?? () => Navigator.of(context).maybePop(),
                tooltip: 'Back',
                icon: const Icon(Icons.arrow_back_rounded),
                color: AppColors.ink,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.muted,
                        ),
                      ),
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
          if (bottom != null)
            Padding(
              padding: const EdgeInsets.only(left: 12, top: 10),
              child: bottom,
            ),
        ],
      ),
    );
  }
}

/// Current site selector, for use on the red home header.
class SiteChip extends StatelessWidget {
  const SiteChip({super.key});

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: () => showComingSoon(context, 'Site switching'),
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 6, 6, 6),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.location_on_outlined, size: 14, color: Colors.white),
            SizedBox(width: 6),
            Flexible(
              child: Text(
                'Site A  ·  Block 2',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Icon(Icons.expand_more_rounded, size: 18, color: Colors.white70),
          ],
        ),
      ),
    );
  }
}
