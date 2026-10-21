import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../calc/cable_sizing.dart';
import '../../services/recents.dart';
import '../../theme/app_theme.dart';
import '../../widgets/calc_widgets.dart';
import '../../widgets/common.dart';
import '../../widgets/reveal.dart';
import '../../widgets/tool_widgets.dart';

const _green = Color(0xFF1E9E5A);
const _greenTint = Color(0xFFE7F6EE);
const _amber = Color(0xFFB86E00);
const _amberTint = Color(0xFFFFF4E0);

class CableSizePage extends StatefulWidget {
  const CableSizePage({
    super.key,
    this.initialLoad,
    this.initialUnit,
    this.initialPhase,
    this.initialVoltage,
  });

  /// Optional starting values, e.g. from the load calculator.
  final double? initialLoad;
  final LoadUnit? initialUnit;
  final SupplyPhase? initialPhase;
  final double? initialVoltage;

  @override
  State<CableSizePage> createState() => _CableSizePageState();
}

class _CableSizePageState extends State<CableSizePage>
    with SingleTickerProviderStateMixin {
  CableStandard _standard = CableStandard.bs7671;
  LoadUnit _loadUnit = LoadUnit.kw;
  SupplyPhase _phase = SupplyPhase.three;
  LengthUnit _lengthUnit = LengthUnit.m;
  ConductorMaterial _material = ConductorMaterial.copper;
  Insulation _insulation = Insulation.xlpe;
  InstallMethod _method = InstallMethod.tray;

  final _load = TextEditingController(text: '15');
  final _voltage = TextEditingController(text: '400');
  final _pf = TextEditingController(text: '0.85');
  final _length = TextEditingController(text: '40');
  final _ambient = TextEditingController(text: '35');
  final _grouped = TextEditingController(text: '3');
  final _maxVd = TextEditingController(text: '5');

  final _resultsKey = GlobalKey();
  CableResult? _result;

  /// Minimum size index, set when the user accepts a voltage-drop upsize.
  int _sizeFloor = 0;

  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..forward();

  Animation<double> _section(int i) => CurvedAnimation(
    parent: _entrance,
    curve: Interval(i * 0.12, 0.5 + i * 0.12, curve: Curves.easeOutCubic),
  );

  @override
  void initState() {
    super.initState();
    final w = widget;
    if (w.initialLoad != null) {
      _load.text = w.initialLoad!.toStringAsFixed(1);
    }
    if (w.initialUnit != null) _loadUnit = w.initialUnit!;
    if (w.initialPhase != null) _phase = w.initialPhase!;
    if (w.initialVoltage != null) {
      final v = w.initialVoltage!;
      _voltage.text = v == v.roundToDouble()
          ? v.toInt().toString()
          : v.toString();
    }
  }

  @override
  void dispose() {
    _entrance.dispose();
    for (final c in [
      _load,
      _voltage,
      _pf,
      _length,
      _ambient,
      _grouped,
      _maxVd,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  double _num(TextEditingController c) => double.tryParse(c.text) ?? 0;

  CableInput get _input => CableInput(
    standard: _standard,
    load: _num(_load),
    loadUnit: _loadUnit,
    voltage: _num(_voltage),
    phase: _phase,
    powerFactor: _num(_pf),
    length: _num(_length),
    lengthUnit: _lengthUnit,
    material: _material,
    insulation: _insulation,
    method: _method,
    ambientTemp: _num(_ambient),
    groupedCircuits: _num(_grouped).toInt(),
    maxVoltDropPct: _num(_maxVd),
  );

  /// Applies an input change; once calculated, results stay live.
  void _update(VoidCallback change) {
    setState(() {
      change();
      _sizeFloor = 0;
      if (_result != null) _result = calculateCable(_input);
    });
  }

  static String _defaultVoltage(CableStandard s, SupplyPhase p) =>
      switch ((s == CableStandard.nec, p)) {
        (true, SupplyPhase.three) => '480',
        (true, SupplyPhase.single) => '240',
        (false, SupplyPhase.three) => '400',
        (false, SupplyPhase.single) => '230',
      };

  void _setStandard(CableStandard s) => _update(() {
    final wasNec = _standard == CableStandard.nec;
    _standard = s;
    _voltage.text = _defaultVoltage(s, _phase);
    _maxVd.text = s == CableStandard.nec ? '3' : '5';
    if (wasNec != (s == CableStandard.nec)) {
      _setLengthUnit(s == CableStandard.nec ? LengthUnit.ft : LengthUnit.m);
    }
  });

  void _setPhase(SupplyPhase p) => _update(() {
    // Swap the voltage only if it is still the other phase's default.
    if (_voltage.text == _defaultVoltage(_standard, _phase)) {
      _voltage.text = _defaultVoltage(_standard, p);
    }
    _phase = p;
  });

  void _setLengthUnit(LengthUnit u) {
    if (u == _lengthUnit) return;
    final v = _num(_length);
    if (v > 0) {
      final converted = u == LengthUnit.ft ? v / 0.3048 : v * 0.3048;
      _length.text = converted.toStringAsFixed(converted >= 100 ? 0 : 1);
    }
    _lengthUnit = u;
  }

  void _calculate() {
    FocusScope.of(context).unfocus();
    HapticFeedback.mediumImpact();
    setState(() => _result = calculateCable(_input, sizeFloor: _sizeFloor));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _resultsKey.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          alignment: 0.02,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  void _applyUpsize() {
    HapticFeedback.selectionClick();
    setState(() {
      _sizeFloor = _result!.upsizeIndex!;
      _result = calculateCable(_input, sizeFloor: _sizeFloor);
    });
  }

  String get _summary {
    final r = _result!;
    final i = _input;
    return [
      'Cable Sizing · AOJ SiteKit',
      'Standard: ${i.standard.label}',
      'Load: ${_load.text} ${i.loadUnit.label}, ${_voltage.text} V '
          '${i.phase.label.toLowerCase()}, pf ${_pf.text}',
      'Run: ${_length.text} ${i.lengthUnit.label}, ${i.material.label} '
          '${i.insulation.labelFor(i.standard)}, ${i.method.label} '
          '(${i.method.reference}), ${_ambient.text} °C, '
          '${_grouped.text} grouped',
      'Cable: ${r.sizeLabel} ${r.cableDescription}',
      'Design current ${r.designCurrent.toStringAsFixed(1)} A · '
          'Capacity ${r.capacity!.toStringAsFixed(1)} A',
      'Voltage drop ${r.voltDrop!.toStringAsFixed(2)} V '
          '(${r.voltDropPct!.toStringAsFixed(2)}%)',
      'Protection: ${r.deviceLabel}',
    ].join('\n');
  }

  Future<void> _save() async {
    final r = _result!;
    await Recents.add(
      RecentCalc(
        toolId: 'elec_cable_size',
        tool: 'Cable Size',
        result: '${r.sizeLabel} · ${r.designCurrent.toStringAsFixed(1)} A',
        site: 'Site A',
        savedAt: DateTime.now(),
      ),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text('Saved to recent calculations'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.ink,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final nec = _standard == CableStandard.nec;
    final buried = _method == InstallMethod.buried;
    final result = _result;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppColors.bg,
        body: Column(
          children: [
            PageHeader(
              title: 'Cable Sizing',
              trailing: SizedBox(
                width: 150,
                child: StandardSwitch(
                  value: _standard,
                  onChanged: _setStandard,
                ),
              ),
            ),
            Expanded(
              child: GestureDetector(
                onTap: () => FocusScope.of(context).unfocus(),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Reveal(
                        animation: _section(0),
                        child: CalcSection(
                          title: 'Load',
                          children: [
                            NumberField(
                              label: 'Load',
                              controller: _load,
                              onChanged: (_) => _update(() {}),
                              unitPicker: UnitPicker<LoadUnit>(
                                value: _loadUnit,
                                options: LoadUnit.values,
                                labelOf: (u) => u.label,
                                onChanged: (u) => _update(() => _loadUnit = u),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Reveal(
                        animation: _section(1),
                        child: CalcSection(
                          title: 'Supply',
                          children: [
                            NumberField(
                              label: 'Voltage',
                              controller: _voltage,
                              unit: 'V',
                              onChanged: (_) => _update(() {}),
                            ),
                            SegmentedToggle<SupplyPhase>(
                              value: _phase,
                              options: SupplyPhase.values,
                              labelOf: (p) => p.label,
                              onChanged: _setPhase,
                            ),
                            NumberField(
                              label: 'Power factor',
                              controller: _pf,
                              onChanged: (_) => _update(() {}),
                            ),
                          ],
                        ),
                      ),
                      Reveal(
                        animation: _section(2),
                        child: CalcSection(
                          title: 'Cable run',
                          children: [
                            NumberField(
                              label: 'Cable length',
                              controller: _length,
                              onChanged: (_) => _update(() {}),
                              unitPicker: UnitPicker<LengthUnit>(
                                value: _lengthUnit,
                                options: LengthUnit.values,
                                labelOf: (u) => u.label,
                                onChanged: (u) =>
                                    _update(() => _setLengthUnit(u)),
                              ),
                            ),
                            SegmentedToggle<ConductorMaterial>(
                              value: _material,
                              options: ConductorMaterial.values,
                              labelOf: (m) => m.label,
                              onChanged: (m) => _update(() => _material = m),
                            ),
                            SelectField<Insulation>(
                              label: 'Insulation',
                              value: _insulation,
                              options: Insulation.values,
                              labelOf: (ins) => ins.labelFor(_standard),
                              onChanged: (ins) =>
                                  _update(() => _insulation = ins),
                            ),
                          ],
                        ),
                      ),
                      Reveal(
                        animation: _section(3),
                        child: CalcSection(
                          title: 'Installation',
                          children: [
                            SelectField<InstallMethod>(
                              label: 'Installation method',
                              value: _method,
                              options: InstallMethod.values,
                              labelOf: (m) => nec
                                  ? m.description
                                  : '${m.label} (${m.reference})',
                              onChanged: (m) => _update(() => _method = m),
                            ),
                            _MethodTiles(
                              selected: _method,
                              onSelect: (m) => _update(() => _method = m),
                            ),
                            NumberField(
                              label: buried ? 'Ground temp' : 'Ambient temp',
                              controller: _ambient,
                              unit: '°C',
                              onChanged: (_) => _update(() {}),
                            ),
                            NumberField(
                              label: 'Grouped circuits',
                              controller: _grouped,
                              integer: true,
                              onChanged: (_) => _update(() {}),
                            ),
                            NumberField(
                              label: 'Max voltage drop',
                              controller: _maxVd,
                              unit: '%',
                              onChanged: (_) => _update(() {}),
                            ),
                          ],
                        ),
                      ),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 400),
                        switchInCurve: Curves.easeOutCubic,
                        transitionBuilder: (child, animation) => FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: Tween(
                              begin: const Offset(0, 0.06),
                              end: Offset.zero,
                            ).animate(animation),
                            child: child,
                          ),
                        ),
                        child: result == null
                            ? const SizedBox.shrink()
                            : _Results(
                                key: _resultsKey,
                                result: result,
                                onApplyUpsize: _applyUpsize,
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: _ActionBar(
          enabled: result != null && result.error == null,
          onCalculate: _calculate,
          onSave: _save,
          onBoq: () => showComingSoon(context, 'Add to BOQ'),
          onPdf: () => showComingSoon(context, 'PDF export'),
          onShare: () => SharePlus.instance.share(
            ShareParams(text: _summary, subject: 'Cable sizing result'),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Header
// ---------------------------------------------------------------------------

// ---------------------------------------------------------------------------
// Inputs
// ---------------------------------------------------------------------------

class _MethodTiles extends StatelessWidget {
  const _MethodTiles({required this.selected, required this.onSelect});

  final InstallMethod selected;
  final ValueChanged<InstallMethod> onSelect;

  static const _icons = {
    InstallMethod.conduit: Icons.timeline_rounded,
    InstallMethod.tray: Icons.view_week_outlined,
    InstallMethod.buried: Icons.landscape_outlined,
    InstallMethod.clipped: Icons.push_pin_outlined,
  };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          for (final (i, m) in InstallMethod.values.indexed) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(
              child: Pressable(
                onTap: () => onSelect(m),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  height: 68,
                  decoration: BoxDecoration(
                    color: m == selected ? AppColors.redTint : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: m == selected ? AppColors.red : AppColors.border,
                      width: m == selected ? 1.4 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _icons[m],
                        size: 22,
                        color: m == selected ? AppColors.red : AppColors.muted,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        m.label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: m == selected
                              ? FontWeight.w600
                              : FontWeight.w500,
                          color: m == selected
                              ? AppColors.red
                              : AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Results
// ---------------------------------------------------------------------------

class _Results extends StatelessWidget {
  const _Results({
    super.key,
    required this.result,
    required this.onApplyUpsize,
  });

  final CableResult result;
  final VoidCallback onApplyUpsize;

  @override
  Widget build(BuildContext context) {
    final r = result;
    if (r.error != null) return _ErrorCard(message: r.error!);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!r.voltDropOk) _WarningCard(result: r, onApply: onApplyUpsize),
        _RecommendedCard(result: r),
        const SizedBox(height: 14),
        _MetricsCard(result: r),
        const SizedBox(height: 12),
        const Text(
          'Design aid only. Verify against the full standard and the cable '
          "manufacturer's data before installation.",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11, color: AppColors.faint, height: 1.4),
        ),
      ],
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.redTint,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.red.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.red),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppColors.ink,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WarningCard extends StatelessWidget {
  const _WarningCard({required this.result, required this.onApply});

  final CableResult result;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    final r = result;
    final pct = r.voltDropPct!.toStringAsFixed(1);
    final limit = r.maxVoltDropPct!.toStringAsFixed(0);
    final message = r.upsizeLabel != null
        ? 'Voltage drop is $pct%, above the $limit% limit. '
              'Increase to ${r.upsizeLabel}.'
        : 'Voltage drop is $pct%, above the $limit% limit, even at the '
              'largest size. Shorten the run or use parallel cables.';
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _amberTint,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _amber.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.warning_amber_rounded, color: _amber),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'SAFETY WARNING',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                        color: _amber,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      message,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.ink,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (r.upsizeLabel != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 44,
              child: FilledButton(
                onPressed: onApply,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.ink,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Use ${r.upsizeLabel}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward_rounded, size: 18),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RecommendedCard extends StatefulWidget {
  const _RecommendedCard({required this.result});

  final CableResult result;

  @override
  State<_RecommendedCard> createState() => _RecommendedCardState();
}

class _RecommendedCardState extends State<_RecommendedCard> {
  bool _showWorking = false;

  @override
  Widget build(BuildContext context) {
    final r = widget.result;
    final safe = r.safe;
    final parts = r.sizeLabel!.split(' ');
    final accent = safe ? _green : _amber;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.45), width: 1.4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
            color: safe ? _greenTint : _amberTint,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'RECOMMENDED CABLE',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                        color: AppColors.muted,
                      ),
                    ),
                    const Spacer(),
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
                        safe ? 'SAFE' : 'CHECK',
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
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 350),
                  transitionBuilder: (child, animation) => ScaleTransition(
                    scale: Tween(begin: 0.8, end: 1.0).animate(
                      CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeOutBack,
                      ),
                    ),
                    child: FadeTransition(opacity: animation, child: child),
                  ),
                  child: Text.rich(
                    key: ValueKey(r.sizeLabel),
                    TextSpan(
                      children: [
                        TextSpan(text: parts.first),
                        TextSpan(
                          text: ' ${parts.skip(1).join(' ')}',
                          style: const TextStyle(
                            fontSize: 20,
                            color: AppColors.red,
                          ),
                        ),
                      ],
                    ),
                    style: const TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                      height: 1.15,
                    ),
                  ),
                ),
                Text(
                  r.cableDescription!,
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                ),
              ],
            ),
          ),
          InkWell(
            onTap: () => setState(() => _showWorking = !_showWorking),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
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
                    turns: _showWorking ? 0.5 : 0,
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
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: _showWorking
                ? _Working(result: r)
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

class _Working extends StatelessWidget {
  const _Working({required this.result});

  final CableResult result;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const FieldLabel('Formula used'),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.bg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(
              result.formula,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
              ),
            ),
          ),
          const SizedBox(height: 14),
          const FieldLabel('Step by step'),
          for (final (i, step) in result.steps.indexed)
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
    );
  }
}

class _MetricsCard extends StatelessWidget {
  const _MetricsCard({required this.result});

  final CableResult result;

  @override
  Widget build(BuildContext context) {
    final r = result;
    final vdColor = r.voltDropOk ? _green : AppColors.red;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: cardDecoration(),
      child: Column(
        children: [
          Row(
            children: [
              _Metric(
                label: 'Design current',
                value: r.designCurrent,
                suffix: ' A',
              ),
              _Metric(
                label: 'Cable capacity',
                value: r.capacity!,
                suffix: ' A',
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _Metric(
                label: 'Voltage drop',
                value: r.voltDropPct!,
                suffix: '%',
                decimals: 2,
                color: vdColor,
              ),
              _Metric(
                label: 'Drop',
                value: r.voltDrop!,
                suffix: ' V',
                decimals: 2,
              ),
            ],
          ),
          const Divider(height: 28, color: AppColors.border),
          Row(
            children: [
              const IconTile(Icons.shield_outlined, size: 34),
              const SizedBox(width: 12),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      const TextSpan(
                        text: 'Protective device  ',
                        style: TextStyle(color: AppColors.muted),
                      ),
                      TextSpan(
                        text: r.deviceLabel,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                        ),
                      ),
                    ],
                  ),
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    required this.suffix,
    this.decimals = 1,
    this.color = AppColors.ink,
  });

  final String label;
  final double value;
  final String suffix;
  final int decimals;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FieldLabel(label),
          AnimatedNumber(
            value: value,
            decimals: decimals,
            suffix: suffix,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Bottom actions
// ---------------------------------------------------------------------------

class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.enabled,
    required this.onCalculate,
    required this.onSave,
    required this.onBoq,
    required this.onPdf,
    required this.onShare,
  });

  final bool enabled;
  final VoidCallback onCalculate;
  final VoidCallback onSave;
  final VoidCallback onBoq;
  final VoidCallback onPdf;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton(
                  onPressed: onCalculate,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.red,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.calculate_outlined, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Calculate',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 6),
              AnimatedOpacity(
                duration: const Duration(milliseconds: 250),
                opacity: enabled ? 1 : 0.4,
                child: IgnorePointer(
                  ignoring: !enabled,
                  child: Row(
                    children: [
                      _Action(Icons.bookmark_border_rounded, 'Save', onSave),
                      _Action(Icons.receipt_long_outlined, 'Add to BOQ', onBoq),
                      _Action(
                        Icons.picture_as_pdf_outlined,
                        'Export PDF',
                        onPdf,
                      ),
                      _Action(Icons.ios_share_rounded, 'Share', onShare),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action(this.icon, this.label, this.onTap);

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Pressable(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            children: [
              Icon(icon, size: 20, color: AppColors.ink),
              const SizedBox(height: 2),
              Text(
                label,
                style: const TextStyle(fontSize: 10, color: AppColors.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
