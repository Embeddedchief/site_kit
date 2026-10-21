import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../theme/app_theme.dart';
import '../../../widgets/common.dart';
import 'calc_mode.dart';
import 'equation_mode.dart';
import 'stats_mode.dart';

enum _Mode {
  calc('Calculate'),
  equation('Equation'),
  stats('Statistics');

  const _Mode(this.label);
  final String label;
}

class ScientificCalculatorPage extends StatefulWidget {
  const ScientificCalculatorPage({super.key});

  @override
  State<ScientificCalculatorPage> createState() =>
      _ScientificCalculatorPageState();
}

class _ScientificCalculatorPageState extends State<ScientificCalculatorPage> {
  _Mode _mode = _Mode.calc;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: Colors.white,
        resizeToAvoidBottomInset: _mode != _Mode.calc,
        body: Column(
          children: [
            PageHeader(
              title: 'Scientific Calculator',
              bottom: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final m in _Mode.values)
                      Padding(
                        padding: const EdgeInsets.only(right: 20),
                        child: _ModeTab(
                          label: m.label,
                          active: m == _mode,
                          onTap: () => setState(() => _mode = m),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Expanded(
              // Keep each mode's state when switching between them.
              child: IndexedStack(
                index: _mode.index,
                children: const [CalcMode(), EquationMode(), StatsMode()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeTab extends StatelessWidget {
  const _ModeTab({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              color: active ? AppColors.ink : AppColors.muted,
            ),
          ),
          const SizedBox(height: 6),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 2,
            width: active ? 24 : 0,
            color: AppColors.red,
          ),
        ],
      ),
    );
  }
}
