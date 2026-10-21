import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../calc/cable_sizing.dart';
import '../../../calc/electrical/load_schedule.dart';
import '../../../services/load_schedule_store.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/calc_widgets.dart';
import '../../../widgets/common.dart';
import '../../../widgets/fade_route.dart';
import '../../../widgets/tool_widgets.dart';
import '../cable_size_page.dart';
import 'generator_page.dart';

class LoadCalculatorPage extends StatefulWidget {
  const LoadCalculatorPage({super.key});

  @override
  State<LoadCalculatorPage> createState() => _LoadCalculatorPageState();
}

class _LoadCalculatorPageState extends State<LoadCalculatorPage> {
  LoadSchedule _schedule = const LoadSchedule();
  bool _loaded = false;
  final _voltage = TextEditingController(text: '400');
  final _diversity = TextEditingController(text: '1');
  var _idCounter = 0;

  @override
  void initState() {
    super.initState();
    LoadScheduleStore.load().then((s) {
      if (!mounted) return;
      setState(() {
        _schedule = s;
        _voltage.text = _trim(s.voltage);
        _diversity.text = _trim(s.diversity);
        _loaded = true;
      });
    });
  }

  @override
  void dispose() {
    _voltage.dispose();
    _diversity.dispose();
    super.dispose();
  }

  static String _trim(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  void _update(LoadSchedule s) {
    setState(() => _schedule = s);
    LoadScheduleStore.save(s);
  }

  LoadSchedule _with({
    SupplyPhase? supply,
    double? voltage,
    double? diversity,
    List<LoadItem>? items,
  }) => LoadSchedule(
    supply: supply ?? _schedule.supply,
    voltage: voltage ?? _schedule.voltage,
    diversity: diversity ?? _schedule.diversity,
    items: items ?? _schedule.items,
  );

  void _setSupply(SupplyPhase p) {
    final defaultV = p == SupplyPhase.three ? '400' : '230';
    final otherDefault = p == SupplyPhase.three ? '230' : '400';
    if (_voltage.text == otherDefault) _voltage.text = defaultV;
    // On a single-phase supply every single-phase load sits on L1.
    final items = p == SupplyPhase.single
        ? [
            for (final i in _schedule.items)
              i.phase == LoadPhase.three ? i : i.copyWith(phase: LoadPhase.l1),
          ]
        : _schedule.items;
    _update(_with(supply: p, voltage: parseField(_voltage) ?? 0, items: items));
  }

  String _newId() => '${DateTime.now().microsecondsSinceEpoch}-${_idCounter++}';

  Future<void> _editLoad([LoadItem? existing]) async {
    final result = await showModalBottomSheet<LoadItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      showDragHandle: true,
      builder: (_) => _LoadEditor(
        existing: existing,
        threePhaseSupply: _schedule.supply == SupplyPhase.three,
        newId: _newId,
      ),
    );
    if (result == null) return;
    final items = existing == null
        ? [..._schedule.items, result]
        : [for (final i in _schedule.items) i.id == existing.id ? result : i];
    _update(_with(items: items));
  }

  void _delete(LoadItem item) {
    final before = _schedule.items;
    _update(_with(items: before.where((i) => i.id != item.id).toList()));
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Removed ${item.name}'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.ink,
          action: SnackBarAction(
            label: 'Undo',
            textColor: Colors.white,
            onPressed: () => _update(_with(items: before)),
          ),
        ),
      );
  }

  void _cyclePhase(LoadItem item) {
    if (_schedule.supply == SupplyPhase.single) return;
    HapticFeedback.selectionClick();
    final next = LoadPhase.values[(item.phase.index + 1) % 4];
    _update(
      _with(
        items: [
          for (final i in _schedule.items)
            i.id == item.id ? i.copyWith(phase: next) : i,
        ],
      ),
    );
  }

  Future<void> _clearAll() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Clear all loads?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(d, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.red),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (ok == true) _update(_with(items: const []));
  }

  @override
  Widget build(BuildContext context) {
    final s = _schedule.summary;
    final three = _schedule.supply == SupplyPhase.three;
    final hasLoads = _schedule.items.isNotEmpty;
    final balanced = !three || s.imbalancePct <= 10;

    return ToolScaffold(
      title: 'Load Calculator',
      trailing: PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert_rounded, color: AppColors.ink),
        position: PopupMenuPosition.under,
        color: Colors.white,
        onSelected: (v) {
          if (v == 'balance') {
            _update(_with(items: autoBalance(_schedule.items)));
            showMessage(context, 'Single-phase loads rebalanced');
          } else if (v == 'clear') {
            _clearAll();
          }
        },
        itemBuilder: (_) => [
          if (three)
            const PopupMenuItem(
              value: 'balance',
              child: Text('Auto-balance phases'),
            ),
          const PopupMenuItem(value: 'clear', child: Text('Clear all loads')),
        ],
      ),
      actions: ToolActionBar(
        enabled: hasLoads && s.error == null,
        toolId: 'elec_load',
        toolName: 'Load Calculation',
        recentResult: () =>
            '${s.demandKw.toStringAsFixed(1)} kW · '
            '${s.designCurrent.toStringAsFixed(1)} A',
        shareText: () => _shareText(s),
        extra: [
          (
            icon: Icons.cable_rounded,
            label: 'Size cable',
            onTap: () => Navigator.of(context).push(
              fadeRoute(
                CableSizePage(
                  initialLoad: s.designCurrent,
                  initialUnit: LoadUnit.amps,
                  initialPhase: _schedule.supply,
                  initialVoltage: _schedule.voltage,
                ),
              ),
            ),
          ),
          (
            icon: Icons.electric_bolt_rounded,
            label: 'Generator',
            onTap: () => Navigator.of(context).push(
              fadeRoute(
                GeneratorPage(
                  initialRunningKw: s.demandKw,
                  initialPf: s.powerFactor,
                ),
              ),
            ),
          ),
        ],
      ),
      children: [
        CalcSection(
          title: 'Supply',
          children: [
            SegmentedToggle<SupplyPhase>(
              value: _schedule.supply,
              options: SupplyPhase.values,
              labelOf: (p) => p.label,
              onChanged: _setSupply,
            ),
            NumberField(
              label: three ? 'Voltage (line to line)' : 'Voltage',
              controller: _voltage,
              unit: 'V',
              onChanged: (_) =>
                  _update(_with(voltage: parseField(_voltage) ?? 0)),
            ),
            NumberField(
              label: 'Overall diversity factor (0–1)',
              controller: _diversity,
              onChanged: (_) {
                final d = parseField(_diversity);
                if (d != null && d > 0 && d <= 1) {
                  _update(_with(diversity: d));
                }
              },
            ),
          ],
        ),
        if (s.error != null) ...[ErrorNote(s.error!), toolGap],
        if (hasLoads && s.error == null) ...[
          ResultHero(
            label: 'Maximum demand',
            value: s.demandKw.toStringAsFixed(1),
            unit: 'kW',
            caption:
                '${s.demandKva.toStringAsFixed(1)} kVA · pf '
                '${s.powerFactor.toStringAsFixed(2)} · '
                '${s.designCurrent.toStringAsFixed(1)} A design current',
            ok: balanced,
            okText: three ? 'BALANCED' : 'OK',
            badText: 'UNBALANCED',
          ),
          toolGap,
          MetricGrid([
            ('Connected load', '${s.connectedKw.toStringAsFixed(1)} kW', null),
            (
              'Main device',
              s.mainDevice == null ? 'Over 800 A' : '${s.mainDevice} A',
              null,
            ),
            if (three)
              (
                'Phase imbalance',
                '${s.imbalancePct.toStringAsFixed(0)}%',
                balanced ? null : AppColors.red,
              ),
            ('Loads', '${_schedule.items.length}', null),
          ]),
          if (three) ...[toolGap, _PhaseBars(currents: s.phaseCurrents)],
          if (!balanced) ...[
            toolGap,
            const NoteCard(
              'Phase imbalance is above 10%. Use "Auto-balance phases" in '
              'the menu, or tap a load\'s phase to move it.',
              icon: Icons.warning_amber_rounded,
            ),
          ],
          toolGap,
        ],
        Row(
          children: [
            Expanded(
              child: Text(
                'Loads (${_schedule.items.length})',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: _loaded ? () => _editLoad() : null,
              style: TextButton.styleFrom(foregroundColor: AppColors.red),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add load'),
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (!hasLoads)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: cardDecoration(),
            child: const Text(
              'Add the loads on this board or building. Start from a preset '
              '(lighting, sockets, AC, pumps…) and adjust the figures.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.muted),
            ),
          )
        else
          for (final item in _schedule.items)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Dismissible(
                key: ValueKey(item.id),
                direction: DismissDirection.endToStart,
                onDismissed: (_) => _delete(item),
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  decoration: BoxDecoration(
                    color: AppColors.red,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.delete_outline_rounded,
                    color: Colors.white,
                  ),
                ),
                child: _LoadCard(
                  item: item,
                  canChangePhase: three,
                  onTap: () => _editLoad(item),
                  onPhaseTap: () => _cyclePhase(item),
                ),
              ),
            ),
        if (hasLoads)
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text(
              'Tap a load to edit, its phase to move it, swipe left to remove.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: AppColors.faint),
            ),
          ),
        const DesignAidNote(),
      ],
    );
  }

  String _shareText(LoadSummary s) => [
    'Load schedule · AOJ SiteKit',
    '${_schedule.supply.label}, ${_trim(_schedule.voltage)} V, '
        'diversity ${_trim(_schedule.diversity)}',
    for (final i in _schedule.items)
      '- ${i.name}: ${i.quantity} × ${_trim(i.rating)} ${i.unit.label}, '
          'DF ${(i.demandFactor * 100).round()}%, ${i.phase.label} '
          '= ${i.demandKva.toStringAsFixed(2)} kVA',
    'Connected ${s.connectedKw.toStringAsFixed(1)} kW',
    'Max demand ${s.demandKw.toStringAsFixed(1)} kW / '
        '${s.demandKva.toStringAsFixed(1)} kVA',
    if (_schedule.supply == SupplyPhase.three)
      'Phase currents L1 ${s.phaseCurrents[0].toStringAsFixed(1)} A, '
          'L2 ${s.phaseCurrents[1].toStringAsFixed(1)} A, '
          'L3 ${s.phaseCurrents[2].toStringAsFixed(1)} A '
          '(imbalance ${s.imbalancePct.toStringAsFixed(0)}%)',
    'Design current ${s.designCurrent.toStringAsFixed(1)} A, '
        'main device ${s.mainDevice ?? '>800'} A',
  ].join('\n');
}

class _PhaseBars extends StatelessWidget {
  const _PhaseBars({required this.currents});

  final List<double> currents;

  @override
  Widget build(BuildContext context) {
    final peak = currents.reduce(math.max);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: cardDecoration(),
      child: Column(
        children: [
          for (final (i, c) in currents.indexed)
            Padding(
              padding: EdgeInsets.only(bottom: i == 2 ? 0 : 10),
              child: Row(
                children: [
                  SizedBox(
                    width: 28,
                    child: Text(
                      'L${i + 1}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: peak == 0 ? 0 : c / peak,
                        minHeight: 8,
                        color: c == peak ? AppColors.red : AppColors.chevron,
                        backgroundColor: AppColors.bg,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 72,
                    child: Text(
                      '${c.toStringAsFixed(1)} A',
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink,
                        fontFeatures: [FontFeature.tabularFigures()],
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

class _LoadCard extends StatelessWidget {
  const _LoadCard({
    required this.item,
    required this.canChangePhase,
    required this.onTap,
    required this.onPhaseTap,
  });

  final LoadItem item;
  final bool canChangePhase;
  final VoidCallback onTap;
  final VoidCallback onPhaseTap;

  @override
  Widget build(BuildContext context) {
    String trim(double v) =>
        v == v.roundToDouble() ? v.toInt().toString() : v.toString();
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink,
                      ),
                    ),
                    Text(
                      '${item.quantity} × ${trim(item.rating)} '
                      '${item.unit.label} · pf ${item.powerFactor} · '
                      'DF ${(item.demandFactor * 100).round()}%',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${item.demandKva.toStringAsFixed(2)} kVA',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(width: 6),
              Tooltip(
                message: canChangePhase ? 'Change phase' : 'Phase',
                child: InkWell(
                  onTap: canChangePhase ? onPhaseTap : null,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 58,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: item.phase == LoadPhase.three
                          ? AppColors.ink
                          : AppColors.redTint,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      item.phase == LoadPhase.three ? '3-ph' : item.phase.label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: item.phase == LoadPhase.three
                            ? Colors.white
                            : AppColors.red,
                      ),
                    ),
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

/// Bottom sheet to add or edit one load.
class _LoadEditor extends StatefulWidget {
  const _LoadEditor({
    required this.existing,
    required this.threePhaseSupply,
    required this.newId,
  });

  final LoadItem? existing;
  final bool threePhaseSupply;
  final String Function() newId;

  @override
  State<_LoadEditor> createState() => _LoadEditorState();
}

class _LoadEditorState extends State<_LoadEditor> {
  late final _name = TextEditingController(text: widget.existing?.name);
  late final _qty = TextEditingController(
    text: '${widget.existing?.quantity ?? 1}',
  );
  late final _rating = TextEditingController(
    text: widget.existing == null ? '' : _trim(widget.existing!.rating),
  );
  late final _pf = TextEditingController(
    text: '${widget.existing?.powerFactor ?? 0.9}',
  );
  late final _df = TextEditingController(
    text: '${((widget.existing?.demandFactor ?? 1) * 100).round()}',
  );
  late RatingUnit _unit = widget.existing?.unit ?? RatingUnit.w;
  late LoadPhase _phase = widget.existing?.phase ?? LoadPhase.l1;
  String? _error;

  static String _trim(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  @override
  void dispose() {
    for (final c in [_name, _qty, _rating, _pf, _df]) {
      c.dispose();
    }
    super.dispose();
  }

  void _applyPreset(LoadPreset p) => setState(() {
    _name.text = p.name;
    _rating.text = _trim(p.rating);
    _unit = p.unit;
    _pf.text = '${p.powerFactor}';
    _df.text = '${(p.demandFactor * 100).round()}';
    if (p.threePhase && widget.threePhaseSupply) _phase = LoadPhase.three;
    if (!p.threePhase && _phase == LoadPhase.three) _phase = LoadPhase.l1;
  });

  void _save() {
    final qty = int.tryParse(_qty.text);
    final rating = parseField(_rating);
    final pf = parseField(_pf);
    final df = parseField(_df);
    final err = switch (null) {
      _ when _name.text.trim().isEmpty => 'Give the load a name.',
      _ when qty == null || qty < 1 => 'Quantity must be at least 1.',
      _ when rating == null || rating <= 0 => 'Enter the rating.',
      _ when pf == null || pf <= 0 || pf > 1 => 'Power factor must be 0–1.',
      _ when df == null || df <= 0 || df > 100 =>
        'Demand factor must be 1–100%.',
      _ => null,
    };
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    Navigator.pop(
      context,
      LoadItem(
        id: widget.existing?.id ?? widget.newId(),
        name: _name.text.trim(),
        quantity: qty!,
        rating: rating!,
        unit: _unit,
        powerFactor: pf!,
        demandFactor: df! / 100,
        phase: widget.threePhaseSupply ? _phase : LoadPhase.l1,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.existing == null ? 'Add load' : 'Edit load',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
            if (widget.existing == null) ...[
              const SizedBox(height: 10),
              const FieldLabel('Start from a preset'),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final p in loadPresets)
                    if (!p.threePhase || widget.threePhaseSupply)
                      ActionChip(
                        label: Text(p.name),
                        onPressed: () => _applyPreset(p),
                        backgroundColor: AppColors.bg,
                        side: const BorderSide(color: AppColors.border),
                        labelStyle: const TextStyle(
                          fontSize: 12,
                          color: AppColors.ink,
                        ),
                      ),
                ],
              ),
            ],
            const SizedBox(height: 14),
            const FieldLabel('Name'),
            TextField(
              controller: _name,
              maxLength: 60,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                counterText: '',
                isDense: true,
                filled: true,
                fillColor: const Color(0xFFF7F7F8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                SizedBox(
                  width: 96,
                  child: NumberField(
                    label: 'Qty',
                    controller: _qty,
                    integer: true,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: NumberField(
                    label: 'Rating each',
                    controller: _rating,
                    unitPicker: UnitPicker<RatingUnit>(
                      value: _unit,
                      options: RatingUnit.values,
                      labelOf: (u) => u.label,
                      onChanged: (u) => setState(() => _unit = u),
                    ),
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: NumberField(label: 'Power factor', controller: _pf),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: NumberField(
                    label: 'Demand factor',
                    controller: _df,
                    unit: '%',
                  ),
                ),
              ],
            ),
            if (widget.threePhaseSupply)
              SegmentedToggle<LoadPhase>(
                value: _phase,
                options: LoadPhase.values,
                labelOf: (p) => p == LoadPhase.three ? '3-ph' : p.label,
                onChanged: (p) => setState(() => _phase = p),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  _error!,
                  style: const TextStyle(color: AppColors.red, fontSize: 13),
                ),
              ),
            SizedBox(
              height: 52,
              child: FilledButton(
                onPressed: _save,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.red,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  widget.existing == null ? 'Add load' : 'Save changes',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
