import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../calc/cable_sizing.dart';
import '../services/recents.dart';
import '../theme/app_theme.dart';
import 'calc_widgets.dart';
import 'common.dart';

// Building blocks shared by the engineering tool screens.

const _green = Color(0xFF1E9E5A);
const _greenTint = Color(0xFFE7F6EE);
const _amber = Color(0xFFB86E00);
const _amberTint = Color(0xFFFFF4E0);

/// Compact BS / IEC / NEC selector for a tool's header.
class StandardSwitch extends StatelessWidget {
  const StandardSwitch({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final CableStandard value;
  final ValueChanged<CableStandard> onChanged;

  static String _short(CableStandard s) => switch (s) {
    CableStandard.bs7671 => 'BS',
    CableStandard.iec60364 => 'IEC',
    CableStandard.nec => 'NEC',
  };

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      child: Container(
        height: 34,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F1F3),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            for (final s in CableStandard.values)
              Expanded(
                child: Semantics(
                  button: true,
                  selected: s == value,
                  label: s.label,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      onChanged(s);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: s == value ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: s == value
                            ? Border.all(color: AppColors.border)
                            : null,
                      ),
                      child: Text(
                        _short(s),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                          color: s == value ? AppColors.red : AppColors.muted,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Standard layout for a tool: white header, scrolling body, action bar.
class ToolScaffold extends StatelessWidget {
  const ToolScaffold({
    super.key,
    required this.title,
    required this.children,
    this.trailing,
    this.actions,
  });

  final String title;
  final Widget? trailing;
  final List<Widget> children;
  final Widget? actions;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppColors.bg,
        body: Column(
          children: [
            PageHeader(title: title, trailing: trailing),
            Expanded(
              child: GestureDetector(
                onTap: () => FocusScope.of(context).unfocus(),
                child: ListView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  children: children,
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: actions,
      ),
    );
  }
}

/// Headline result: a big value with unit, a caption and a status badge.
class ResultHero extends StatelessWidget {
  const ResultHero({
    super.key,
    required this.label,
    required this.value,
    this.unit = '',
    this.caption,
    this.ok = true,
    this.okText = 'OK',
    this.badText = 'CHECK',
  });

  final String label;
  final String value;
  final String unit;
  final String? caption;
  final bool ok;
  final String okText;
  final String badText;

  @override
  Widget build(BuildContext context) {
    final accent = ok ? _green : _amber;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(
        color: ok ? _greenTint : _amberTint,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    color: AppColors.muted,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  ok ? okText : badText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: value),
                  if (unit.isNotEmpty)
                    TextSpan(
                      text: ' $unit',
                      style: const TextStyle(
                        fontSize: 18,
                        color: AppColors.red,
                      ),
                    ),
                ],
              ),
              style: const TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
                height: 1.15,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
          if (caption != null)
            Text(
              caption!,
              style: const TextStyle(fontSize: 12, color: AppColors.muted),
            ),
        ],
      ),
    );
  }
}

/// Two-column grid of labelled figures.
class MetricGrid extends StatelessWidget {
  const MetricGrid(this.items, {super.key});

  final List<(String label, String value, Color? color)> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 2),
      decoration: cardDecoration(),
      child: LayoutBuilder(
        builder: (context, box) {
          final w = (box.maxWidth - 12) / 2;
          return Wrap(
            spacing: 12,
            children: [
              for (final (label, value, color) in items)
                SizedBox(
                  width: w,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FieldLabel(label),
                        Text(
                          value,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: color ?? AppColors.ink,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Pass/fail list of design checks.
class CheckList extends StatelessWidget {
  const CheckList(this.checks, {super.key});

  final List<(String label, bool pass, String detail)> checks;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: cardDecoration(),
      child: Column(
        children: [
          for (final (i, (label, pass, detail)) in checks.indexed) ...[
            if (i > 0) const Divider(height: 1, color: AppColors.border),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    pass ? Icons.check_circle_rounded : Icons.cancel_rounded,
                    size: 20,
                    color: pass ? _green : AppColors.red,
                    semanticLabel: pass ? 'Pass' : 'Fail',
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.ink,
                          ),
                        ),
                        Text(
                          detail,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Amber advisory note.
class NoteCard extends StatelessWidget {
  const NoteCard(
    this.text, {
    super.key,
    this.icon = Icons.info_outline_rounded,
  });

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _amberTint,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _amber.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: _amber),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                height: 1.4,
                color: AppColors.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Red error card for invalid input.
class ErrorNote extends StatelessWidget {
  const ErrorNote(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.redTint,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.red),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13, color: AppColors.ink),
            ),
          ),
        ],
      ),
    );
  }
}

/// Expandable formula and numbered working steps.
class WorkingCard extends StatefulWidget {
  const WorkingCard({super.key, required this.steps, this.formula});

  final String? formula;
  final List<String> steps;

  @override
  State<WorkingCard> createState() => _WorkingCardState();
}

class _WorkingCardState extends State<WorkingCard> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() => _open = !_open),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  const Icon(
                    Icons.functions_rounded,
                    size: 18,
                    color: AppColors.red,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Formula & working',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: _open ? 0.5 : 0,
                    duration: const Duration(milliseconds: 250),
                    child: const Icon(
                      Icons.expand_more_rounded,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            alignment: Alignment.topCenter,
            child: !_open
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (widget.formula != null) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.bg,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              widget.formula!,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.ink,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        for (final (i, step) in widget.steps.indexed)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 20,
                                  height: 20,
                                  alignment: Alignment.center,
                                  decoration: const BoxDecoration(
                                    color: AppColors.red,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text(
                                    '${i + 1}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    step,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      height: 1.45,
                                      color: AppColors.muted,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// "Design aid" disclaimer shown under tool results.
class DesignAidNote extends StatelessWidget {
  const DesignAidNote({super.key, this.extra});

  final String? extra;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Text(
        'Design aid only. ${extra ?? ''}Verify against the full standard and '
        "the manufacturer's data before installation.",
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 11,
          height: 1.4,
          color: AppColors.faint,
        ),
      ),
    );
  }
}

/// Save to recents and share buttons along the bottom of a tool.
class ToolActionBar extends StatelessWidget {
  const ToolActionBar({
    super.key,
    required this.enabled,
    required this.toolId,
    required this.toolName,
    required this.recentResult,
    required this.shareText,
    this.extra = const [],
  });

  final bool enabled;
  final String toolId;
  final String toolName;

  /// Short result for the homepage's recent calculations.
  final String Function() recentResult;
  final String Function() shareText;

  /// Additional actions, e.g. "Size cable".
  final List<({IconData icon, String label, VoidCallback onTap})> extra;

  Future<void> _save(BuildContext context) async {
    await Recents.add(
      RecentCalc(
        toolId: toolId,
        tool: toolName,
        result: recentResult(),
        site: 'Site A',
        savedAt: DateTime.now(),
      ),
    );
    if (context.mounted) showMessage(context, 'Saved to recent calculations');
  }

  @override
  Widget build(BuildContext context) {
    final actions = [
      (
        icon: Icons.bookmark_border_rounded,
        label: 'Save',
        onTap: () => _save(context),
      ),
      ...extra,
      (
        icon: Icons.ios_share_rounded,
        label: 'Share',
        onTap: () => SharePlus.instance.share(
          ShareParams(text: shareText(), subject: toolName),
        ),
      ),
    ];
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: enabled ? 1 : 0.4,
          child: IgnorePointer(
            ignoring: !enabled,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  for (final a in actions)
                    Expanded(
                      child: InkWell(
                        onTap: a.onTap,
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Column(
                            // Keep the bar its natural height.
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(a.icon, size: 22, color: AppColors.ink),
                              const SizedBox(height: 2),
                              Text(
                                a.label,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Parses a numeric field; empty or invalid text gives null.
double? parseField(TextEditingController c) =>
    double.tryParse(c.text.replaceAll(',', '').trim());

/// Section gap used between tool cards.
const toolGap = SizedBox(height: 14);
