import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import 'common.dart';

/// White card grouping related calculator inputs under a small caps title.
class CalcSection extends StatelessWidget {
  const CalcSection({super.key, required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      decoration: cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 3,
                height: 12,
                decoration: BoxDecoration(
                  color: AppColors.red,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                title.toUpperCase(),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.6,
                  color: AppColors.muted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 6),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.1,
          color: AppColors.faint,
        ),
      ),
    );
  }
}

const _fieldFill = Color(0xFFF7F7F8);

BoxDecoration _fieldDecoration({bool focused = false}) => BoxDecoration(
  color: _fieldFill,
  borderRadius: BorderRadius.circular(14),
  border: Border.all(
    color: focused ? AppColors.red : AppColors.border,
    width: focused ? 1.4 : 1,
  ),
);

/// Numeric input with a label above and a unit (text or picker) on the right.
class NumberField extends StatefulWidget {
  const NumberField({
    super.key,
    required this.label,
    required this.controller,
    this.unit,
    this.unitPicker,
    this.integer = false,
    this.onChanged,
  });

  final String label;
  final TextEditingController controller;
  final String? unit;
  final Widget? unitPicker;
  final bool integer;
  final ValueChanged<String>? onChanged;

  @override
  State<NumberField> createState() => _NumberFieldState();
}

class _NumberFieldState extends State<NumberField> {
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FieldLabel(widget.label),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 52,
            decoration: _fieldDecoration(focused: _focus.hasFocus),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: widget.controller,
                    focusNode: _focus,
                    onChanged: widget.onChanged,
                    cursorColor: AppColors.red,
                    keyboardType: TextInputType.numberWithOptions(
                      decimal: !widget.integer,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(widget.integer ? r'[0-9]' : r'[0-9.]'),
                      ),
                    ],
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink,
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 14),
                    ),
                  ),
                ),
                if (widget.unitPicker != null)
                  widget.unitPicker!
                else if (widget.unit != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 14),
                    child: Text(
                      widget.unit!,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.muted,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact unit dropdown that sits inside a [NumberField].
class UnitPicker<T> extends StatelessWidget {
  const UnitPicker({
    super.key,
    required this.value,
    required this.options,
    required this.labelOf,
    required this.onChanged,
  });

  final T value;
  final List<T> options;
  final String Function(T) labelOf;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<T>(
      initialValue: value,
      onSelected: onChanged,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      itemBuilder: (_) => [
        for (final o in options)
          PopupMenuItem(value: o, child: Text(labelOf(o))),
      ],
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: const BoxDecoration(
          border: Border(left: BorderSide(color: AppColors.border)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              labelOf(value),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.red,
              ),
            ),
            const Icon(
              Icons.expand_more_rounded,
              size: 18,
              color: AppColors.muted,
            ),
          ],
        ),
      ),
    );
  }
}

/// Full-width dropdown field with a label above.
class SelectField<T> extends StatelessWidget {
  const SelectField({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.labelOf,
    required this.onChanged,
  });

  final String label;
  final T value;
  final List<T> options;
  final String Function(T) labelOf;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FieldLabel(label),
          LayoutBuilder(
            builder: (context, constraints) => PopupMenuButton<T>(
              initialValue: value,
              onSelected: onChanged,
              color: Colors.white,
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              position: PopupMenuPosition.under,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              itemBuilder: (_) => [
                for (final o in options)
                  PopupMenuItem(value: o, child: Text(labelOf(o))),
              ],
              child: Container(
                height: 52,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: _fieldDecoration(),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        labelOf(value),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.expand_more_rounded,
                      color: AppColors.muted,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Two-or-more option toggle with a sliding red highlight.
class SegmentedToggle<T> extends StatelessWidget {
  const SegmentedToggle({
    super.key,
    required this.value,
    required this.options,
    required this.labelOf,
    required this.onChanged,
  });

  final T value;
  final List<T> options;
  final String Function(T) labelOf;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final index = options.indexOf(value);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        height: 46,
        padding: const EdgeInsets.all(4),
        decoration: _fieldDecoration(),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth / options.length;
            return Stack(
              children: [
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutCubic,
                  left: width * index,
                  top: 0,
                  bottom: 0,
                  width: width,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.red,
                      borderRadius: BorderRadius.circular(11),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.red.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                  ),
                ),
                Row(
                  children: [
                    for (final o in options)
                      Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => onChanged(o),
                          child: Center(
                            child: AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 200),
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: o == value
                                    ? Colors.white
                                    : AppColors.muted,
                              ),
                              child: Text(labelOf(o)),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Counts up to [value] whenever it changes.
class AnimatedNumber extends StatelessWidget {
  const AnimatedNumber({
    super.key,
    required this.value,
    required this.style,
    this.decimals = 1,
    this.suffix = '',
  });

  final double value;
  final TextStyle style;
  final int decimals;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: value),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (_, v, _) =>
          Text('${v.toStringAsFixed(decimals)}$suffix', style: style),
    );
  }
}
