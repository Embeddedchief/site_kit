import 'package:flutter/material.dart';

import '../../../calc/sci/solvers.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/calc_widgets.dart';
import '../../../widgets/common.dart';
import 'number_display.dart';

enum _StatType {
  oneVar('1-variable'),
  linear('Linear  y = a + bx');

  const _StatType(this.label);
  final String label;
}

List<double> _parseList(String text) => text
    .replaceAll('−', '-')
    .split(RegExp(r'[\s,;]+'))
    .where((s) => s.isNotEmpty)
    .map(double.tryParse)
    .whereType<double>()
    .toList();

/// STAT mode: 1-variable statistics and linear regression.
class StatsMode extends StatefulWidget {
  const StatsMode({super.key});

  @override
  State<StatsMode> createState() => _StatsModeState();
}

class _StatsModeState extends State<StatsMode> {
  _StatType _type = _StatType.oneVar;
  final _xs = TextEditingController();
  final _ys = TextEditingController();
  final _estimate = TextEditingController();

  @override
  void dispose() {
    _xs.dispose();
    _ys.dispose();
    _estimate.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final xs = _parseList(_xs.text);
    final ys = _parseList(_ys.text);
    final linear = _type == _StatType.linear;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        SegmentedToggle<_StatType>(
          value: _type,
          options: _StatType.values,
          labelOf: (t) => t.label,
          onChanged: (t) => setState(() => _type = t),
        ),
        _DataField(
          label: linear ? 'x values' : 'Data',
          controller: _xs,
          count: xs.length,
          onChanged: () => setState(() {}),
        ),
        if (linear)
          _DataField(
            label: 'y values',
            controller: _ys,
            count: ys.length,
            onChanged: () => setState(() {}),
          ),
        const SizedBox(height: 4),
        if (linear) _regression(xs, ys) else _oneVar(xs),
      ],
    );
  }

  Widget _oneVar(List<double> xs) {
    if (xs.isEmpty) {
      return const _Hint('Enter numbers separated by commas or spaces.');
    }
    final s = oneVarStats(xs);
    return _ResultsCard(
      rows: [
        ('n', '${s.n}'),
        ('Mean', formatPlain(s.mean)),
        ('Sum', formatPlain(s.sum)),
        ('Sum of squares', formatPlain(s.sumSquares)),
        ('Population SD', formatPlain(s.popSd)),
        ('Sample SD', s.sampleSd == null ? '—' : formatPlain(s.sampleSd!)),
        ('Min', formatPlain(s.min)),
        ('Q1', formatPlain(s.q1)),
        ('Median', formatPlain(s.median)),
        ('Q3', formatPlain(s.q3)),
        ('Max', formatPlain(s.max)),
      ],
    );
  }

  Widget _regression(List<double> xs, List<double> ys) {
    if (xs.length < 2 || ys.isEmpty) {
      return const _Hint('Enter at least two x values and matching y values.');
    }
    if (xs.length != ys.length) {
      return _Hint('x has ${xs.length} values but y has ${ys.length}.');
    }
    final LinearRegression r;
    try {
      r = linearRegression(xs, ys);
    } on ArgumentError catch (e) {
      return _Hint('${e.message}.');
    }
    final at = double.tryParse(_estimate.text.replaceAll('−', '-'));
    return Column(
      children: [
        _ResultsCard(
          rows: [
            ('n', '${r.n}'),
            ('a  (intercept)', formatPlain(r.a)),
            ('b  (slope)', formatPlain(r.b)),
            ('r  (correlation)', formatPlain(r.r)),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 2),
          decoration: cardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              NumberField(
                label: 'Estimate y at x =',
                controller: _estimate,
                onChanged: (_) => setState(() {}),
              ),
              if (at != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Text(
                    'y = ${formatPlain(r.estimateY(at))}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DataField extends StatelessWidget {
  const _DataField({
    required this.label,
    required this.controller,
    required this.count,
    required this.onChanged,
  });

  final String label;
  final TextEditingController controller;
  final int count;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              FieldLabel(label),
              const Spacer(),
              Text(
                '$count value${count == 1 ? '' : 's'}',
                style: const TextStyle(fontSize: 11, color: AppColors.faint),
              ),
            ],
          ),
          TextField(
            controller: controller,
            onChanged: (_) => onChanged(),
            minLines: 2,
            maxLines: 4,
            keyboardType: const TextInputType.numberWithOptions(
              signed: true,
              decimal: true,
            ),
            cursorColor: AppColors.red,
            style: const TextStyle(fontSize: 15, color: AppColors.ink),
            decoration: InputDecoration(
              hintText: 'e.g. 12, 15.5, 18, 21',
              hintStyle: const TextStyle(color: AppColors.chevron),
              filled: true,
              fillColor: Colors.white,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.red, width: 1.4),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultsCard extends StatelessWidget {
  const _ResultsCard({required this.rows});

  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: cardDecoration(),
      child: Column(
        children: [
          for (final (i, (label, value)) in rows.indexed) ...[
            if (i > 0) const Divider(height: 1, color: AppColors.border),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 11),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.muted,
                      ),
                    ),
                  ),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                      fontFeatures: [FontFeature.tabularFigures()],
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

class _Hint extends StatelessWidget {
  const _Hint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 12, color: AppColors.faint),
      ),
    );
  }
}
