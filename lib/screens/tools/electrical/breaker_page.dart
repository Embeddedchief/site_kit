import 'package:flutter/material.dart';

import '../../../calc/cable_sizing.dart';
import '../../../calc/electrical/breaker_selection.dart';
import '../../../calc/electrical/common.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/calc_widgets.dart';
import '../../../widgets/tool_widgets.dart';

class BreakerPage extends StatefulWidget {
  const BreakerPage({super.key});

  @override
  State<BreakerPage> createState() => _BreakerPageState();
}

class _BreakerPageState extends State<BreakerPage> {
  CableStandard _standard = CableStandard.bs7671;
  SupplyPhase _phase = SupplyPhase.single;
  LoadUnit _loadUnit = LoadUnit.amps;
  BreakerLoad _type = BreakerLoad.sockets;
  bool _neutral = true;

  final _load = TextEditingController(text: '25');
  final _voltage = TextEditingController(text: '230');
  final _pf = TextEditingController(text: '0.9');
  final _iz = TextEditingController();
  final _fault = TextEditingController();

  @override
  void dispose() {
    for (final c in [_load, _voltage, _pf, _iz, _fault]) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _nec => _standard == CableStandard.nec;

  String _defaultVoltage(SupplyPhase p) => _nec
      ? (p == SupplyPhase.three ? '480' : '240')
      : (p == SupplyPhase.three ? '400' : '230');

  double get _current => loadCurrent(
    load: parseField(_load) ?? 0,
    unit: _loadUnit,
    voltage: parseField(_voltage) ?? 0,
    phase: _phase,
    powerFactor: parseField(_pf) ?? 1,
  );

  @override
  Widget build(BuildContext context) {
    final ib = _current;
    final r = selectBreaker(
      BreakerInput(
        standard: _standard,
        phase: _phase,
        designCurrent: ib.isFinite ? ib : 0,
        loadType: _type,
        cableCapacity: parseField(_iz),
        faultLevelKa: parseField(_fault),
        withNeutral: _neutral,
        voltage: parseField(_voltage) ?? 230,
      ),
    );

    return ToolScaffold(
      title: 'Breaker Selector',
      trailing: StandardSwitch(
        value: _standard,
        onChanged: (s) => setState(() {
          _standard = s;
          _voltage.text = _defaultVoltage(_phase);
        }),
      ),
      actions: ToolActionBar(
        enabled: r.error == null,
        toolId: 'elec_breaker',
        toolName: 'Breaker',
        recentResult: () => r.summary,
        shareText: () => [
          'Breaker selection · AOJ SiteKit (${_standard.label})',
          'Design current ${ib.toStringAsFixed(1)} A, '
              '${_type.label.toLowerCase()}',
          'Device: ${r.summary}, ${r.breakingCapacityKa} kA',
          if (r.maxZs != null)
            'Max Zs ${r.maxZs!.toStringAsFixed(2)} ohm (0.4 s)',
          for (final c in r.checks)
            '${c.pass ? 'PASS' : 'FAIL'} ${c.label}: ${c.detail}',
          ?r.rcdAdvice,
        ].join('\n'),
      ),
      children: [
        CalcSection(
          title: 'Circuit',
          children: [
            SegmentedToggle<SupplyPhase>(
              value: _phase,
              options: SupplyPhase.values,
              labelOf: (p) => p.label,
              onChanged: (p) => setState(() {
                if (_voltage.text == _defaultVoltage(_phase)) {
                  _voltage.text = _defaultVoltage(p);
                }
                _phase = p;
              }),
            ),
            NumberField(
              label: _loadUnit == LoadUnit.amps ? 'Design current Ib' : 'Load',
              controller: _load,
              onChanged: (_) => setState(() {}),
              unitPicker: UnitPicker<LoadUnit>(
                value: _loadUnit,
                options: LoadUnit.values,
                labelOf: (u) => u.label,
                onChanged: (u) => setState(() => _loadUnit = u),
              ),
            ),
            if (_loadUnit != LoadUnit.amps) ...[
              NumberField(
                label: 'Voltage',
                controller: _voltage,
                unit: 'V',
                onChanged: (_) => setState(() {}),
              ),
              if (_loadUnit == LoadUnit.kw)
                NumberField(
                  label: 'Power factor',
                  controller: _pf,
                  onChanged: (_) => setState(() {}),
                ),
            ],
            SelectField<BreakerLoad>(
              label: 'Load type',
              value: _type,
              options: BreakerLoad.values,
              labelOf: (t) => t.label,
              onChanged: (t) => setState(() => _type = t),
            ),
            if (_phase == SupplyPhase.three && !_nec)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Switched neutral (4-pole)',
                        style: TextStyle(fontSize: 14, color: AppColors.ink),
                      ),
                    ),
                    Switch(
                      value: _neutral,
                      activeThumbColor: Colors.white,
                      activeTrackColor: AppColors.red,
                      onChanged: (v) => setState(() => _neutral = v),
                    ),
                  ],
                ),
              ),
          ],
        ),
        CalcSection(
          title: 'Optional checks',
          children: [
            NumberField(
              label: 'Cable capacity Iz (blank if unknown)',
              controller: _iz,
              unit: 'A',
              onChanged: (_) => setState(() {}),
            ),
            NumberField(
              label: 'Prospective fault current (blank if unknown)',
              controller: _fault,
              unit: 'kA',
              onChanged: (_) => setState(() {}),
            ),
          ],
        ),
        if (r.error != null)
          ErrorNote(r.error!)
        else ...[
          ResultHero(
            label: 'Protective device',
            value: '${r.rating}',
            unit: 'A',
            caption: [
              if (r.curve != null) 'Type ${r.curve}',
              r.device,
              r.poles,
              '${r.breakingCapacityKa} kA',
            ].join(' · '),
            ok: r.allChecksPass,
            okText: 'OK',
            badText: 'CHECK',
          ),
          toolGap,
          CheckList([for (final c in r.checks) (c.label, c.pass, c.detail)]),
          if (r.maxZs != null) ...[
            toolGap,
            MetricGrid([
              ('Design current', '${ib.toStringAsFixed(1)} A', null),
              ('Max Zs (0.4 s)', '${r.maxZs!.toStringAsFixed(2)} ohm', null),
            ]),
          ],
          if (r.rcdAdvice != null) ...[
            toolGap,
            NoteCard(r.rcdAdvice!, icon: Icons.shield_outlined),
          ],
          toolGap,
          WorkingCard(steps: r.steps),
          const DesignAidNote(),
        ],
      ],
    );
  }
}
