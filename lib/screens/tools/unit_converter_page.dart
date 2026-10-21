import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../calc/units.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import 'scientific/number_display.dart';

const _tabular = [FontFeature.tabularFigures()];

class UnitConverterPage extends StatefulWidget {
  const UnitConverterPage({super.key});

  @override
  State<UnitConverterPage> createState() => _UnitConverterPageState();
}

class _UnitConverterPageState extends State<UnitConverterPage> {
  int _category = 0;
  late int _from = unitCategories[0].from;
  late int _to = unitCategories[0].to;
  final _input = TextEditingController(text: '1');

  UnitCategory get _cat => unitCategories[_category];

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  double? get _value {
    final t = _input.text.replaceAll('−', '-').replaceAll(',', '').trim();
    return double.tryParse(t);
  }

  void _selectCategory(int i) => setState(() {
    _category = i;
    _from = unitCategories[i].from;
    _to = unitCategories[i].to;
  });

  void _swap() {
    HapticFeedback.selectionClick();
    setState(() {
      final result = _value == null
          ? null
          : convert(_value!, _cat.units[_from], _cat.units[_to]);
      final oldFrom = _from;
      _from = _to;
      _to = oldFrom;
      if (result != null) {
        // A plain, parseable number (10 significant digits) for the input.
        final rounded = double.parse(result.toStringAsPrecision(10));
        _input.text = rounded == rounded.roundToDouble() && rounded.abs() < 1e15
            ? rounded.toInt().toString()
            : rounded.toString();
      }
    });
  }

  void _copy(String text) {
    Clipboard.setData(ClipboardData(text: text));
    showMessage(context, 'Copied $text');
  }

  @override
  Widget build(BuildContext context) {
    final value = _value;
    final from = _cat.units[_from];
    final to = _cat.units[_to];
    final result = value == null ? null : convert(value, from, to);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppColors.bg,
        body: Column(
          children: [
            PageHeader(
              title: 'Unit Converter',
              subtitle: '${unitCategories.length} engineering categories',
            ),
            SizedBox(
              height: 56,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                itemCount: unitCategories.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final c = unitCategories[i];
                  final selected = i == _category;
                  return ChoiceChip(
                    avatar: Icon(
                      c.icon,
                      size: 16,
                      color: selected ? Colors.white : AppColors.red,
                    ),
                    label: Text(c.name),
                    selected: selected,
                    showCheckmark: false,
                    onSelected: (_) => _selectCategory(i),
                    selectedColor: AppColors.ink,
                    backgroundColor: Colors.white,
                    side: BorderSide(
                      color: selected ? AppColors.ink : AppColors.border,
                    ),
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: selected ? Colors.white : AppColors.ink,
                    ),
                  );
                },
              ),
            ),
            Expanded(
              child: ListView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: cardDecoration(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _label('From'),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _input,
                                onChanged: (_) => setState(() {}),
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      signed: true,
                                      decimal: true,
                                    ),
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(
                                    RegExp(r'[0-9.eE\-]'),
                                  ),
                                  LengthLimitingTextInputFormatter(24),
                                ],
                                cursorColor: AppColors.red,
                                style: const TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.ink,
                                  fontFeatures: _tabular,
                                ),
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  isDense: true,
                                  hintText: '0',
                                ),
                              ),
                            ),
                            _UnitButton(
                              units: _cat.units,
                              selected: _from,
                              onSelected: (i) => setState(() => _from = i),
                            ),
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: [
                              const Expanded(
                                child: Divider(color: AppColors.border),
                              ),
                              IconButton(
                                onPressed: _swap,
                                tooltip: 'Swap units',
                                icon: const Icon(
                                  Icons.swap_vert_rounded,
                                  color: AppColors.red,
                                ),
                                style: IconButton.styleFrom(
                                  backgroundColor: AppColors.redTint,
                                ),
                              ),
                              const Expanded(
                                child: Divider(color: AppColors.border),
                              ),
                            ],
                          ),
                        ),
                        _label('To'),
                        Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: result == null
                                    ? null
                                    : () => _copy(formatPlain(result)),
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: result == null
                                      ? const Text(
                                          '—',
                                          style: TextStyle(
                                            fontSize: 26,
                                            color: AppColors.faint,
                                          ),
                                        )
                                      : NumberDisplay(
                                          key: const ValueKey('result'),
                                          value: result,
                                          fontSize: 26,
                                          color: AppColors.red,
                                        ),
                                ),
                              ),
                            ),
                            _UnitButton(
                              units: _cat.units,
                              selected: _to,
                              onSelected: (i) => setState(() => _to = i),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${from.name} to ${to.name}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (value != null) ...[
                    const Padding(
                      padding: EdgeInsets.fromLTRB(2, 20, 0, 10),
                      child: Text(
                        'All units',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                    Container(
                      decoration: cardDecoration(),
                      child: Column(
                        children: [
                          for (final (i, u) in _cat.units.indexed) ...[
                            if (i > 0)
                              const Divider(
                                height: 1,
                                indent: 16,
                                color: AppColors.border,
                              ),
                            _AllUnitsRow(
                              unit: u,
                              text: formatPlain(convert(value, from, u)),
                              highlighted: i == _to,
                              onTap: () => setState(() => _to = i),
                              onLongPress: () =>
                                  _copy(formatPlain(convert(value, from, u))),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.only(top: 10),
                      child: Text(
                        'Tap a row to convert to it. Long-press to copy.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 11, color: AppColors.faint),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Text(
    text.toUpperCase(),
    style: const TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.w600,
      letterSpacing: 1.1,
      color: AppColors.faint,
    ),
  );
}

class _UnitButton extends StatelessWidget {
  const _UnitButton({
    required this.units,
    required this.selected,
    required this.onSelected,
  });

  final List<Unit> units;
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<int>(
      initialValue: selected,
      onSelected: onSelected,
      color: Colors.white,
      position: PopupMenuPosition.under,
      constraints: const BoxConstraints(maxHeight: 420),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      itemBuilder: (_) => [
        for (final (i, u) in units.indexed)
          PopupMenuItem(
            value: i,
            child: Row(
              children: [
                SizedBox(
                  width: 92,
                  child: Text(
                    u.symbol,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Flexible(
                  child: Text(
                    u.name,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.muted,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
      child: Container(
        constraints: const BoxConstraints(minWidth: 84),
        padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
        decoration: BoxDecoration(
          color: AppColors.bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              units[selected].symbol,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
            const Icon(Icons.expand_more_rounded, color: AppColors.muted),
          ],
        ),
      ),
    );
  }
}

class _AllUnitsRow extends StatelessWidget {
  const _AllUnitsRow({
    required this.unit,
    required this.text,
    required this.highlighted,
    required this.onTap,
    required this.onLongPress,
  });

  final Unit unit;
  final String text;
  final bool highlighted;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                unit.name,
                style: TextStyle(
                  fontSize: 13,
                  color: highlighted ? AppColors.red : AppColors.muted,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                '$text ${unit.symbol}',
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: highlighted ? AppColors.red : AppColors.ink,
                  fontFeatures: _tabular,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
