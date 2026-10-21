import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../calc/sci/solvers.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/common.dart';
import 'number_display.dart';

enum _EqnType {
  quadratic('ax² + bx + c = 0', ['a', 'b', 'c']),
  cubic('ax³ + bx² + cx + d = 0', ['a', 'b', 'c', 'd']),
  linear2('2 unknowns', ['a', 'b', 'c']),
  linear3('3 unknowns', ['a', 'b', 'c', 'd']);

  const _EqnType(this.label, this.columns);
  final String label;
  final List<String> columns;

  int get rows => switch (this) {
    _EqnType.linear2 => 2,
    _EqnType.linear3 => 3,
    _ => 1,
  };
}

/// EQN mode: polynomial and simultaneous linear equation solver.
class EquationMode extends StatefulWidget {
  const EquationMode({super.key});

  @override
  State<EquationMode> createState() => _EquationModeState();
}

class _EquationModeState extends State<EquationMode> {
  _EqnType _type = _EqnType.quadratic;
  late List<List<TextEditingController>> _fields = _makeFields(_type);

  static List<List<TextEditingController>> _makeFields(_EqnType t) => [
    for (var r = 0; r < t.rows; r++)
      [for (var c = 0; c < t.columns.length; c++) TextEditingController()],
  ];

  @override
  void dispose() {
    _disposeFields();
    super.dispose();
  }

  void _disposeFields() {
    for (final row in _fields) {
      for (final c in row) {
        c.dispose();
      }
    }
  }

  void _setType(_EqnType t) {
    if (t == _type) return;
    setState(() {
      _disposeFields();
      _type = t;
      _fields = _makeFields(t);
    });
  }

  double? _value(TextEditingController c) {
    final t = c.text.replaceAll('−', '-').trim();
    if (t.isEmpty || t == '-') return null;
    return double.tryParse(t);
  }

  /// Result lines as (label, value); null until every field is filled.
  List<(String, String)>? _solve() {
    final values = [
      for (final row in _fields) [for (final c in row) _value(c)],
    ];
    if (values.any((row) => row.any((v) => v == null))) return null;
    final v = [
      for (final row in values) [for (final x in row) x!],
    ];

    switch (_type) {
      case _EqnType.quadratic:
        final [a, b, c] = v.single;
        if (a == 0) return [('Error', 'a must not be 0')];
        final roots = solveQuadratic(a, b, c);
        final (vx, vy) = quadraticVertex(a, b, c);
        return [
          for (final (i, z) in roots.indexed) ('x${i + 1}', _complex(z)),
          (
            a > 0 ? 'Minimum' : 'Maximum',
            '(${formatPlain(vx)}, ${formatPlain(vy)})',
          ),
        ];
      case _EqnType.cubic:
        final [a, b, c, d] = v.single;
        if (a == 0) return [('Error', 'a must not be 0')];
        return [
          for (final (i, z) in solveCubic(a, b, c, d).indexed)
            ('x${i + 1}', _complex(z)),
        ];
      case _EqnType.linear2 || _EqnType.linear3:
        final n = _type.rows;
        final solution = solveLinear(
          [for (final row in v) row.sublist(0, n)],
          [for (final row in v) row[n]],
        );
        if (solution == null) return [('Result', 'No unique solution')];
        const names = ['x', 'y', 'z'];
        return [
          for (var i = 0; i < n; i++) (names[i], formatPlain(solution[i])),
        ];
    }
  }

  String _complex(Complex z) {
    if (z.isReal) return formatPlain(z.re);
    final im = formatPlain(z.im.abs());
    final sign = z.im < 0 ? '−' : '+';
    return z.re == 0
        ? '${z.im < 0 ? '−' : ''}${im}i'
        : '${formatPlain(z.re)} $sign ${im}i';
  }

  @override
  Widget build(BuildContext context) {
    final results = _solve();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _EqnType.values.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final t = _EqnType.values[i];
              final active = t == _type;
              return ChoiceChip(
                label: Text(t.label),
                selected: active,
                showCheckmark: false,
                onSelected: (_) => _setType(t),
                labelStyle: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: active ? Colors.white : AppColors.ink,
                ),
                selectedColor: AppColors.ink,
                backgroundColor: Colors.white,
                side: BorderSide(
                  color: active ? AppColors.ink : AppColors.border,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: cardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _type.rows == 1
                    ? _type.label
                    : _type.rows == 2
                    ? 'a·x + b·y = c'
                    : 'a·x + b·y + c·z = d',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  if (_type.rows > 1) const SizedBox(width: 22),
                  for (final c in _type.columns)
                    Expanded(
                      child: Text(
                        c,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.muted,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              for (final (r, row) in _fields.indexed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      if (_type.rows > 1)
                        SizedBox(
                          width: 22,
                          child: Text(
                            '${r + 1}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.faint,
                            ),
                          ),
                        ),
                      for (final (i, c) in row.indexed) ...[
                        if (i > 0) const SizedBox(width: 8),
                        Expanded(
                          child: _CoefficientField(
                            controller: c,
                            onChanged: () => setState(() {}),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (results != null)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: cardDecoration(),
            child: Column(
              children: [
                for (final (i, (label, value)) in results.indexed) ...[
                  if (i > 0) const Divider(height: 20, color: AppColors.border),
                  Row(
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.muted,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          value,
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          )
        else
          const Text(
            'Fill in every coefficient to solve.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppColors.faint),
          ),
      ],
    );
  }
}

class _CoefficientField extends StatelessWidget {
  const _CoefficientField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: (_) => onChanged(),
      textAlign: TextAlign.center,
      keyboardType: const TextInputType.numberWithOptions(
        signed: true,
        decimal: true,
      ),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.\-]'))],
      cursorColor: AppColors.red,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: AppColors.ink,
      ),
      decoration: InputDecoration(
        isDense: true,
        hintText: '0',
        hintStyle: const TextStyle(color: AppColors.chevron),
        filled: true,
        fillColor: const Color(0xFFF7F7F8),
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.red, width: 1.4),
        ),
      ),
    );
  }
}
