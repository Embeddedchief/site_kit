import 'package:flutter/material.dart';

import '../../../calc/cable_sizing.dart';
import '../../../calc/electrical/voltage_drop.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/calc_widgets.dart';
import '../../../widgets/tool_widgets.dart';

class VoltageDropPage extends StatefulWidget {
  const VoltageDropPage({super.key});

  @override
  State<VoltageDropPage> createState() => _VoltageDropPageState();
}

class _VoltageDropPageState extends State<VoltageDropPage> {
  CableStandard _standard = CableStandard.bs7671;
  SupplyPhase _phase = SupplyPhase.three;
  LoadUnit _loadUnit = LoadUnit.kw;
  ConductorMaterial _material = ConductorMaterial.copper;
  Insulation _insulation = Insulation.xlpe;
  LengthUnit _lengthUnit = LengthUnit.m;
  int _size = 2; // 4 mm²

  final _voltage = TextEditingController(text: '400');
  final _load = TextEditingController(text: '15');
  final _pf = TextEditingController(text: '0.85');
  final _length = TextEditingController(text: '40');
  final _limit = TextEditingController(text: '5');

  @override
  void dispose() {
    for (final c in [_voltage, _load, _pf, _length, _limit]) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _nec => _standard == CableStandard.nec;

  VoltDropInput get _input => VoltDropInput(
    standard: _standard,
    phase: _phase,
    voltage: parseField(_voltage) ?? 0,
    load: parseField(_load) ?? 0,
    loadUnit: _loadUnit,
    powerFactor: parseField(_pf) ?? 0,
    material: _material,
    insulation: _insulation,
    sizeIndex: _size,
    length: parseField(_length) ?? 0,
    lengthUnit: _lengthUnit,
    limitPct: parseField(_limit) ?? 0,
  );

  String _defaultVoltage(SupplyPhase p) => _nec
      ? (p == SupplyPhase.three ? '480' : '240')
      : (p == SupplyPhase.three ? '400' : '230');

  void _setStandard(CableStandard s) => setState(() {
    final wasNec = _nec;
    _standard = s;
    _voltage.text = _defaultVoltage(_phase);
    _limit.text = _nec ? '3' : '5';
    if (wasNec != _nec) {
      // Size tables differ between metric and AWG; pick a mid-range size.
      _size = _nec ? 3 : 2;
      _setLengthUnit(_nec ? LengthUnit.ft : LengthUnit.m);
    }
    _clampSize();
  });

  void _setPhase(SupplyPhase p) => setState(() {
    if (_voltage.text == _defaultVoltage(_phase)) {
      _phase = p;
      _voltage.text = _defaultVoltage(p);
    } else {
      _phase = p;
    }
  });

  void _setLengthUnit(LengthUnit u) {
    if (u == _lengthUnit) return;
    final v = parseField(_length);
    if (v != null && v > 0) {
      final c = u == LengthUnit.ft ? v / 0.3048 : v * 0.3048;
      _length.text = c.toStringAsFixed(c >= 100 ? 0 : 1);
    }
    _lengthUnit = u;
  }

  void _clampSize() {
    final first = firstSize(_standard, _material);
    if (_size < first) _size = first;
  }

  @override
  Widget build(BuildContext context) {
    final labels = sizeLabels(_standard);
    final first = firstSize(_standard, _material);
    final r = calculateVoltDrop(_input);
    final ok = r.ok && r.dropPct <= (parseField(_limit) ?? 0) + 1e-9;

    return ToolScaffold(
      title: 'Voltage Drop',
      trailing: StandardSwitch(value: _standard, onChanged: _setStandard),
      actions: ToolActionBar(
        enabled: r.ok,
        toolId: 'elec_voltage_drop',
        toolName: 'Voltage Drop',
        recentResult: () =>
            '${r.dropPct.toStringAsFixed(2)}% on ${labels[_size]}',
        shareText: () => [
          'Voltage drop · AOJ SiteKit (${_standard.label})',
          '${_load.text} ${_loadUnit.label}, ${_voltage.text} V '
              '${_phase.label.toLowerCase()}',
          '${labels[_size]} ${_material.label} '
              '${_insulation.labelFor(_standard)}, '
              '${_length.text} ${_lengthUnit.label}',
          'Drop ${r.drop.toStringAsFixed(2)} V '
              '(${r.dropPct.toStringAsFixed(2)}%), '
              '${r.endVoltage.toStringAsFixed(1)} V at load',
          if (r.minSizeLabel != null)
            'Smallest size within ${_limit.text}%: ${r.minSizeLabel}',
        ].join('\n'),
      ),
      children: [
        CalcSection(
          title: 'Supply & load',
          children: [
            SegmentedToggle<SupplyPhase>(
              value: _phase,
              options: SupplyPhase.values,
              labelOf: (p) => p.label,
              onChanged: _setPhase,
            ),
            NumberField(
              label: 'Voltage',
              controller: _voltage,
              unit: 'V',
              onChanged: (_) => setState(() {}),
            ),
            NumberField(
              label: 'Load',
              controller: _load,
              onChanged: (_) => setState(() {}),
              unitPicker: UnitPicker<LoadUnit>(
                value: _loadUnit,
                options: LoadUnit.values,
                labelOf: (u) => u.label,
                onChanged: (u) => setState(() => _loadUnit = u),
              ),
            ),
            if (_loadUnit == LoadUnit.kw)
              NumberField(
                label: 'Power factor',
                controller: _pf,
                onChanged: (_) => setState(() {}),
              ),
          ],
        ),
        CalcSection(
          title: 'Cable',
          children: [
            SegmentedToggle<ConductorMaterial>(
              value: _material,
              options: ConductorMaterial.values,
              labelOf: (m) => m.label,
              onChanged: (m) => setState(() {
                _material = m;
                _clampSize();
              }),
            ),
            SelectField<Insulation>(
              label: 'Insulation',
              value: _insulation,
              options: Insulation.values,
              labelOf: (i) => i.labelFor(_standard),
              onChanged: (i) => setState(() => _insulation = i),
            ),
            SelectField<int>(
              label: 'Cable size',
              value: _size,
              options: [for (var s = first; s < labels.length; s++) s],
              labelOf: (s) => labels[s],
              onChanged: (s) => setState(() => _size = s),
            ),
            NumberField(
              label: 'Length (one way)',
              controller: _length,
              onChanged: (_) => setState(() {}),
              unitPicker: UnitPicker<LengthUnit>(
                value: _lengthUnit,
                options: LengthUnit.values,
                labelOf: (u) => u.label,
                onChanged: (u) => setState(() => _setLengthUnit(u)),
              ),
            ),
            NumberField(
              label: 'Max voltage drop',
              controller: _limit,
              unit: '%',
              onChanged: (_) => setState(() {}),
            ),
          ],
        ),
        if (r.error != null)
          ErrorNote(r.error!)
        else ...[
          ResultHero(
            label: 'Voltage drop',
            value: r.dropPct.toStringAsFixed(2),
            unit: '%',
            caption:
                '${r.drop.toStringAsFixed(2)} V · '
                '${r.endVoltage.toStringAsFixed(1)} V at the load',
            ok: ok,
            okText: 'WITHIN LIMIT',
            badText: 'TOO HIGH',
          ),
          toolGap,
          MetricGrid([
            ('Design current', '${r.current.toStringAsFixed(1)} A', null),
            (
              'Max run at this size',
              '${r.maxLength.toStringAsFixed(0)} ${_lengthUnit.label}',
              null,
            ),
            (
              'Smallest size in limit',
              r.minSizeLabel ?? 'None',
              r.minSizeLabel == labels[_size] ? null : AppColors.red,
            ),
            ('Cable', labels[_size], null),
          ]),
          if (!ok && r.minSizeLabel != null) ...[
            toolGap,
            NoteCard(
              'Increase to ${r.minSizeLabel} to keep the drop within '
              '${_limit.text}%, or shorten the run below '
              '${r.maxLength.toStringAsFixed(0)} ${_lengthUnit.label}.',
              icon: Icons.warning_amber_rounded,
            ),
          ],
          toolGap,
          WorkingCard(formula: r.formula, steps: r.steps),
          const DesignAidNote(),
        ],
      ],
    );
  }
}
