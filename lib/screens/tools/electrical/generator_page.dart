import 'package:flutter/material.dart';

import '../../../calc/electrical/generator_sizing.dart';
import '../../../services/load_schedule_store.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/calc_widgets.dart';
import '../../../widgets/common.dart';
import '../../../widgets/tool_widgets.dart';

class GeneratorPage extends StatefulWidget {
  const GeneratorPage({super.key, this.initialRunningKw, this.initialPf});

  /// Prefill from the load calculator.
  final double? initialRunningKw;
  final double? initialPf;

  @override
  State<GeneratorPage> createState() => _GeneratorPageState();
}

class _GeneratorPageState extends State<GeneratorPage> {
  StartMethod _start = StartMethod.dol;
  GeneratorDuty _duty = GeneratorDuty.prime;

  late final _running = TextEditingController(
    text: widget.initialRunningKw?.toStringAsFixed(1) ?? '50',
  );
  late final _pf = TextEditingController(
    text: widget.initialPf == null
        ? '0.8'
        : widget.initialPf!.clamp(0.1, 1.0).toStringAsFixed(2),
  );
  final _motor = TextEditingController(text: '15');
  final _margin = TextEditingController(text: '20');
  final _dip = TextEditingController(text: '20');
  final _altitude = TextEditingController(text: '0');
  final _ambient = TextEditingController(text: '40');

  @override
  void dispose() {
    for (final c in [
      _running,
      _pf,
      _motor,
      _margin,
      _dip,
      _altitude,
      _ambient,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _useLoadSchedule() async {
    final s = await LoadScheduleStore.load();
    if (!mounted) return;
    if (s.items.isEmpty) {
      showMessage(context, 'The load calculator has no loads yet.');
      return;
    }
    final summary = s.summary;
    setState(() {
      _running.text = summary.demandKw.toStringAsFixed(1);
      _pf.text = summary.powerFactor.toStringAsFixed(2);
    });
    showMessage(
      context,
      'Using ${summary.demandKw.toStringAsFixed(1)} kW maximum demand',
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = sizeGenerator(
      GeneratorInput(
        runningKw: parseField(_running) ?? 0,
        powerFactor: parseField(_pf) ?? 0,
        largestMotorKw: parseField(_motor) ?? 0,
        startMethod: _start,
        marginPct: parseField(_margin) ?? 0,
        maxDipPct: parseField(_dip) ?? 0,
        duty: _duty,
        altitudeM: parseField(_altitude) ?? 0,
        ambientC: parseField(_ambient) ?? 40,
      ),
    );
    final hasMotor = (parseField(_motor) ?? 0) > 0;

    return ToolScaffold(
      title: 'Generator Sizing',
      actions: ToolActionBar(
        enabled: r.error == null,
        toolId: 'elec_generator',
        toolName: 'Generator Sizing',
        recentResult: () => '${r.selectedKva} kVA ${_duty.name}',
        shareText: () => [
          'Generator sizing · AOJ SiteKit',
          'Running load ${_running.text} kW at pf ${_pf.text}',
          if (hasMotor)
            'Largest motor ${_motor.text} kW, '
                '${_start.label.toLowerCase()} start',
          'Recommended: ${r.selectedKva} kVA '
              '(${r.selectedKw.toStringAsFixed(0)} kW) ${_duty.label}',
          'Normal loading ${r.loadingPct.toStringAsFixed(0)}%, '
              'fuel ≈ ${r.fuelLitresPerHour.toStringAsFixed(1)} L/h at 75%',
          ...r.warnings,
        ].join('\n'),
      ),
      children: [
        CalcSection(
          title: 'Load',
          children: [
            NumberField(
              label: 'Running load (incl. motors)',
              controller: _running,
              unit: 'kW',
              onChanged: (_) => setState(() {}),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _useLoadSchedule,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.red,
                  padding: EdgeInsets.zero,
                ),
                icon: const Icon(Icons.playlist_add_check_rounded, size: 20),
                label: const Text('Use load calculator total'),
              ),
            ),
            const SizedBox(height: 6),
            NumberField(
              label: 'Power factor',
              controller: _pf,
              onChanged: (_) => setState(() {}),
            ),
          ],
        ),
        CalcSection(
          title: 'Largest motor',
          children: [
            NumberField(
              label: 'Motor rating (0 if none)',
              controller: _motor,
              unit: 'kW',
              onChanged: (_) => setState(() {}),
            ),
            if (hasMotor) ...[
              SelectField<StartMethod>(
                label: 'Starting method',
                value: _start,
                options: StartMethod.values,
                labelOf: (m) => '${m.label} (${m.multiple}× running kVA)',
                onChanged: (m) => setState(() => _start = m),
              ),
              NumberField(
                label: 'Allowed voltage dip on start',
                controller: _dip,
                unit: '%',
                onChanged: (_) => setState(() {}),
              ),
            ],
          ],
        ),
        CalcSection(
          title: 'Rating & site',
          children: [
            SegmentedToggle<GeneratorDuty>(
              value: _duty,
              options: GeneratorDuty.values,
              labelOf: (d) => d == GeneratorDuty.prime ? 'Prime' : 'Standby',
              onChanged: (d) => setState(() => _duty = d),
            ),
            NumberField(
              label: 'Growth margin',
              controller: _margin,
              unit: '%',
              onChanged: (_) => setState(() {}),
            ),
            Row(
              children: [
                Expanded(
                  child: NumberField(
                    label: 'Altitude',
                    controller: _altitude,
                    unit: 'm',
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: NumberField(
                    label: 'Max ambient',
                    controller: _ambient,
                    unit: '°C',
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
          ],
        ),
        if (r.error != null)
          ErrorNote(r.error!)
        else ...[
          ResultHero(
            label: 'Recommended generator',
            value: '${r.selectedKva}',
            unit: 'kVA',
            caption:
                '${r.selectedKw.toStringAsFixed(0)} kW at 0.8 pf · '
                '${_duty == GeneratorDuty.prime ? 'prime' : 'standby'} rating',
            ok: r.warnings.isEmpty,
            okText: 'SIZED',
            badText: 'REVIEW',
          ),
          toolGap,
          MetricGrid([
            ('Running load', '${r.runningKva.toStringAsFixed(1)} kVA', null),
            (
              'Motor start needs',
              hasMotor
                  ? '${r.startRequirementKva.toStringAsFixed(0)} kVA'
                  : '—',
              null,
            ),
            (
              'Normal loading',
              '${r.loadingPct.toStringAsFixed(0)}%',
              r.loadingPct < 30 ? AppColors.red : null,
            ),
            (
              'Fuel at 75% load',
              '≈ ${r.fuelLitresPerHour.toStringAsFixed(1)} L/h',
              null,
            ),
          ]),
          for (final w in r.warnings) ...[
            toolGap,
            NoteCard(w, icon: Icons.warning_amber_rounded),
          ],
          toolGap,
          WorkingCard(
            formula: "S ≥ S_base + X'd × S_start × (1 − dip) / dip",
            steps: r.steps,
          ),
          const DesignAidNote(extra: 'Derating and fuel figures are typical. '),
        ],
      ],
    );
  }
}
