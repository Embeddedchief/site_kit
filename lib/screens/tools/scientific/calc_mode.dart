import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../calc/sci/sci_engine.dart';
import '../../../theme/app_theme.dart';
import 'number_display.dart';

const _tabular = [FontFeature.tabularFigures()];

/// Tokens that act on a previous value; typed straight after "=" they
/// continue from Ans, as on the Casio.
const _continuesAns = {
  Tok.plus, Tok.minus, Tok.times, Tok.divide, Tok.power, Tok.root, //
  Tok.square, Tok.cube, Tok.inverse, Tok.fact, Tok.percent, Tok.nCr, Tok.nPr,
};

class _HistoryEntry {
  const _HistoryEntry(this.tokens, this.value);
  final List<String> tokens;
  final double value;
}

/// COMP mode: expression entry with a Casio-style keypad.
class CalcMode extends StatefulWidget {
  const CalcMode({super.key});

  @override
  State<CalcMode> createState() => _CalcModeState();
}

class _CalcModeState extends State<CalcMode> {
  List<String> _tokens = [];
  int _cursor = 0;
  bool _shift = false;
  bool _hyp = false;
  AngleMode _angle = AngleMode.deg;
  double _ans = 0;
  double _memory = 0;
  double? _result;
  String? _error;
  bool _fraction = false;
  bool _eng = false;

  /// True right after "=", until the next edit.
  bool _evaluated = false;
  final List<_HistoryEntry> _history = [];

  EvalContext get _context =>
      EvalContext(angle: _angle, ans: _ans, memory: _memory);

  void _press(VoidCallback action) {
    HapticFeedback.selectionClick();
    setState(() {
      action();
      _shift = false;
    });
  }

  void _insert(String token) {
    if (_evaluated) {
      _tokens = _continuesAns.contains(token) ? [Tok.ans] : [];
      _cursor = _tokens.length;
      _evaluated = false;
      _result = null;
    }
    _error = null;
    _tokens = [..._tokens]..insert(_cursor, token);
    _cursor++;
  }

  void _delete() {
    _error = null;
    if (_evaluated) {
      _evaluated = false;
      return;
    }
    if (_cursor == 0) return;
    _tokens = [..._tokens]..removeAt(_cursor - 1);
    _cursor--;
  }

  void _clear() {
    _tokens = [];
    _cursor = 0;
    _result = null;
    _error = null;
    _evaluated = false;
    _hyp = false;
  }

  void _moveCursor(int delta) {
    _evaluated = false;
    _cursor = (_cursor + delta).clamp(0, _tokens.length);
  }

  /// Evaluates the expression; returns null and shows the error on failure.
  double? _evaluateNow() {
    try {
      return evaluate(_tokens, _context);
    } on CalcError catch (e) {
      _error = e.message;
      _result = null;
      return null;
    }
  }

  void _equals() {
    if (_tokens.isEmpty) return;
    final v = _evaluateNow();
    if (v == null) return;
    _result = v;
    _ans = v;
    _error = null;
    _fraction = false;
    _evaluated = true;
    _cursor = _tokens.length;
    _history.insert(0, _HistoryEntry(List.of(_tokens), v));
  }

  void _addToMemory(int sign) {
    final v = _tokens.isEmpty ? (_result ?? 0) : _evaluateNow();
    if (v == null) return;
    _memory += sign * v;
    _result = v;
    _ans = v;
    _evaluated = true;
  }

  void _trig(String plain, String inverse, String hyp, String inverseHyp) {
    _insert(_hyp ? (_shift ? inverseHyp : hyp) : (_shift ? inverse : plain));
    _hyp = false;
  }

  void _openHistory() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      showDragHandle: true,
      builder: (sheet) => _history.isEmpty
          ? const SizedBox(
              height: 160,
              child: Center(
                child: Text(
                  'No calculations yet',
                  style: TextStyle(color: AppColors.muted),
                ),
              ),
            )
          : ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              itemCount: _history.length,
              separatorBuilder: (_, _) =>
                  const Divider(height: 1, color: AppColors.border),
              itemBuilder: (_, i) {
                final h = _history[i];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: MathText(
                    h.tokens.map(tokenMarkup).join(),
                    style: const TextStyle(color: AppColors.muted),
                  ),
                  trailing: Text(
                    formatNumber(h.value).toString(),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                      fontFeatures: _tabular,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(sheet);
                    setState(() {
                      _tokens = List.of(h.tokens);
                      _cursor = _tokens.length;
                      _result = null;
                      _error = null;
                      _evaluated = false;
                    });
                  },
                );
              },
            ),
    );
  }

  // Keypad geometry: 4 function rows, 4 number rows, 6 px gaps.
  static const _fnKey = 44.0, _numKey = 54.0;
  static const _minFnKey = 30.0, _minNumKey = 38.0;
  static const _keypadChrome = 20.0 + 8 * 6 + 6; // padding + row gaps
  static const _tightChrome = 12.0 + 8 * 4 + 4; // same, on short screens
  static const _displayMin = 150.0, _displayMargin = 22.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        // Shrink keys (down to comfortable touch sizes) so the display keeps
        // its room on short screens instead of overflowing.
        final textScale = MediaQuery.textScalerOf(context).scale(1);
        final bottomInset = MediaQuery.paddingOf(context).bottom;
        final forKeys =
            box.maxHeight -
            _displayMin * textScale -
            _displayMargin -
            _keypadChrome -
            bottomInset;
        final rowsAtFull = 4 * _fnKey + 4 * _numKey;
        final tight = forKeys < rowsAtFull;
        // Tighter gaps free a little more room when space is short.
        final k =
            ((forKeys + (tight ? _keypadChrome - _tightChrome : 0)) /
                    rowsAtFull)
                .clamp(0.0, 1.0);
        return Column(
          children: [
            Expanded(child: _display()),
            _keypad(
              fnHeight: (_fnKey * k).clamp(_minFnKey, _fnKey),
              numHeight: (_numKey * k).clamp(_minNumKey, _numKey),
              gap: tight ? 4 : 6,
            ),
          ],
        );
      },
    );
  }

  // -------------------------------------------------------------------------
  // Display
  // -------------------------------------------------------------------------

  Widget _display() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F4F5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: LayoutBuilder(
        builder: (context, box) {
          // Full size when there's room, smaller text on short screens, and
          // only as a last resort scale the whole display down.
          final scale = MediaQuery.textScalerOf(context).scale(1);
          final need = (_displayMin - 24) * scale;
          final compactNeed = 86 * scale;
          final compact = box.maxHeight < need;
          final content = SizedBox(
            width: box.maxWidth,
            height: box.maxHeight < compactNeed ? compactNeed : box.maxHeight,
            child: _displayContent(compact: compact),
          );
          return box.maxHeight < compactNeed
              ? FittedBox(fit: BoxFit.contain, child: content)
              : content;
        },
      ),
    );
  }

  Widget _displayContent({required bool compact}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            _Indicator(
              _angle.label,
              active: true,
              onTap: () => setState(() {
                _angle = AngleMode
                    .values[(_angle.index + 1) % AngleMode.values.length];
                _result = null;
                _evaluated = false;
              }),
            ),
            if (_shift) const _Indicator('SHIFT', active: true, red: true),
            if (_hyp) const _Indicator('HYP', active: true),
            if (_memory != 0) const _Indicator('M', active: true),
            const Spacer(),
            _Indicator(
              'a/b',
              active: _fraction,
              onTap: _result == null
                  ? null
                  : () => setState(() => _fraction = !_fraction),
            ),
            _Indicator(
              'ENG',
              active: _eng,
              onTap: () => setState(() => _eng = !_eng),
            ),
            IconButton(
              onPressed: _openHistory,
              tooltip: 'History',
              visualDensity: compact
                  ? const VisualDensity(horizontal: -4, vertical: -4)
                  : VisualDensity.compact,
              icon: const Icon(
                Icons.history_rounded,
                size: 20,
                color: AppColors.muted,
              ),
            ),
          ],
        ),
        const Spacer(),
        _expressionLine(compact: compact),
        SizedBox(height: compact ? 2 : 6),
        Align(
          alignment: Alignment.centerRight,
          child: _error != null
              ? Text(
                  _error!,
                  style: TextStyle(
                    fontSize: compact ? 20 : 24,
                    fontWeight: FontWeight.w700,
                    color: AppColors.red,
                  ),
                )
              : _result == null
              ? SizedBox(height: compact ? 32 : 44)
              : FittedBox(
                  fit: BoxFit.scaleDown,
                  child: NumberDisplay(
                    key: const ValueKey('result'),
                    value: _result!,
                    fraction: _fraction,
                    eng: _eng,
                    fontSize: compact ? 28 : 38,
                  ),
                ),
        ),
      ],
    );
  }

  Widget _expressionLine({required bool compact}) {
    final style = TextStyle(
      fontSize: compact ? 18 : 22,
      color: AppColors.ink,
      fontFeatures: _tabular,
    );
    final cursor = Container(
      width: 2,
      height: compact ? 21 : 26,
      margin: const EdgeInsets.symmetric(horizontal: 1),
      color: _evaluated ? Colors.transparent : AppColors.red,
    );
    return SizedBox(
      height: compact ? 26 : 32,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        reverse: true,
        child: Row(
          children: [
            if (_cursor == 0) cursor,
            for (var i = 0; i < _tokens.length; i++) ...[
              GestureDetector(
                // Tapping a token puts the cursor after it.
                onTap: () => setState(() {
                  _evaluated = false;
                  _cursor = i + 1;
                }),
                child: MathText(tokenMarkup(_tokens[i]), style: style),
              ),
              if (_cursor == i + 1) cursor,
            ],
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Keypad
  // -------------------------------------------------------------------------

  _KeySpec _fn(
    String label,
    VoidCallback onTap, {
    String? shiftLabel,
    VoidCallback? onShift,
  }) => _KeySpec(
    label: label,
    shiftLabel: shiftLabel,
    onTap: () => _press(_shift && onShift != null ? onShift : onTap),
  );

  _KeySpec _tok(
    String label,
    String token, {
    String? shiftLabel,
    String? shiftToken,
  }) => _fn(
    label,
    () => _insert(token),
    shiftLabel: shiftLabel,
    onShift: shiftToken == null ? null : () => _insert(shiftToken),
  );

  Widget _keypad({
    required double fnHeight,
    required double numHeight,
    required double gap,
  }) {
    final hypOn = _hyp;
    final functionRows = <List<_KeySpec>>[
      [
        _KeySpec(
          label: 'SHIFT',
          active: _shift,
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => _shift = !_shift);
          },
        ),
        _KeySpec(
          label: 'hyp',
          active: hypOn,
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => _hyp = !_hyp);
          },
        ),
        _fn('', () => _moveCursor(-1)).withIcon(Icons.chevron_left_rounded),
        _fn('', () => _moveCursor(1)).withIcon(Icons.chevron_right_rounded),
        _fn(
          'M+',
          () => _addToMemory(1),
          shiftLabel: 'M−',
          onShift: () => _addToMemory(-1),
        ),
        _fn(
          'MR',
          () => _insert(Tok.mem),
          shiftLabel: 'MC',
          onShift: () => _memory = 0,
        ),
      ],
      [
        _fn(
          hypOn ? 'sinh' : 'sin',
          () => _trig(Tok.sin, Tok.asin, Tok.sinh, Tok.asinh),
          shiftLabel: hypOn ? 'sinh^{−1}' : 'sin^{−1}',
          onShift: () => _trig(Tok.sin, Tok.asin, Tok.sinh, Tok.asinh),
        ),
        _fn(
          hypOn ? 'cosh' : 'cos',
          () => _trig(Tok.cos, Tok.acos, Tok.cosh, Tok.acosh),
          shiftLabel: hypOn ? 'cosh^{−1}' : 'cos^{−1}',
          onShift: () => _trig(Tok.cos, Tok.acos, Tok.cosh, Tok.acosh),
        ),
        _fn(
          hypOn ? 'tanh' : 'tan',
          () => _trig(Tok.tan, Tok.atan, Tok.tanh, Tok.atanh),
          shiftLabel: hypOn ? 'tanh^{−1}' : 'tan^{−1}',
          onShift: () => _trig(Tok.tan, Tok.atan, Tok.tanh, Tok.atanh),
        ),
        _tok('log', Tok.log, shiftLabel: '10^{x}', shiftToken: Tok.pow10),
        _tok('ln', Tok.ln, shiftLabel: 'e^{x}', shiftToken: Tok.powE),
        _tok('√', Tok.sqrt, shiftLabel: '^{3}√', shiftToken: Tok.cbrt),
      ],
      [
        _tok('x²', Tok.square, shiftLabel: 'x³', shiftToken: Tok.cube),
        _tok('x^{y}', Tok.power, shiftLabel: '^{x}√', shiftToken: Tok.root),
        _tok('x^{−1}', Tok.inverse, shiftLabel: 'x!', shiftToken: Tok.fact),
        _tok('nCr', Tok.nCr, shiftLabel: 'nPr', shiftToken: Tok.nPr),
        _tok('(', Tok.open, shiftLabel: 'Abs', shiftToken: Tok.abs),
        _tok(')', Tok.close, shiftLabel: '%', shiftToken: Tok.percent),
      ],
      [
        _tok(
          '∫dx',
          Tok.integral,
          shiftLabel: 'd/dx',
          shiftToken: Tok.derivative,
        ),
        _tok('∑', Tok.sum),
        _tok('X', Tok.x),
        _tok(',', Tok.comma),
        _tok('π', Tok.pi, shiftLabel: 'e', shiftToken: Tok.e),
        _tok('×10^{x}', Tok.exp),
      ],
    ];

    final numberRows = <List<_KeySpec>>[
      [
        _tok('7', '7'),
        _tok('8', '8'),
        _tok('9', '9'),
        _KeySpec(
          label: 'DEL',
          kind: _KeyKind.danger,
          onTap: () => _press(_delete),
        ),
        _KeySpec(
          label: 'AC',
          kind: _KeyKind.danger,
          onTap: () => _press(_clear),
        ),
      ],
      [
        _tok('4', '4'),
        _tok('5', '5'),
        _tok('6', '6'),
        _tok('×', Tok.times).withKind(_KeyKind.operator),
        _tok('÷', Tok.divide).withKind(_KeyKind.operator),
      ],
      [
        _tok('1', '1'),
        _tok('2', '2'),
        _tok('3', '3'),
        _tok('+', Tok.plus).withKind(_KeyKind.operator),
        _tok('−', Tok.minus).withKind(_KeyKind.operator),
      ],
      [
        _tok('0', '0'),
        _tok('.', '.'),
        _tok('Ans', Tok.ans).withKind(_KeyKind.operator),
        _KeySpec(
          label: '=',
          kind: _KeyKind.equals,
          flex: 2,
          onTap: () {
            HapticFeedback.mediumImpact();
            setState(() {
              _equals();
              _shift = false;
            });
          },
        ),
      ],
    ];

    return Container(
      padding: EdgeInsets.fromLTRB(
        12,
        gap + 2,
        12,
        gap + 2 + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        children: [
          for (final row in functionRows)
            _KeyRow(row, height: fnHeight, gap: gap, shift: _shift),
          SizedBox(height: gap),
          for (final row in numberRows)
            _KeyRow(
              row,
              height: numHeight,
              gap: gap,
              shift: _shift,
              numberRow: true,
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Key widgets
// ---------------------------------------------------------------------------

enum _KeyKind { function, number, operator, danger, equals }

class _KeySpec {
  const _KeySpec({
    required this.label,
    required this.onTap,
    this.shiftLabel,
    this.kind = _KeyKind.function,
    this.active = false,
    this.flex = 1,
    this.icon,
  });

  final String label;
  final String? shiftLabel;
  final VoidCallback onTap;
  final _KeyKind kind;
  final bool active;
  final int flex;
  final IconData? icon;

  _KeySpec withKind(_KeyKind k) => _KeySpec(
    label: label,
    onTap: onTap,
    shiftLabel: shiftLabel,
    kind: k,
    active: active,
    flex: flex,
    icon: icon,
  );

  _KeySpec withIcon(IconData i) => _KeySpec(
    label: label,
    onTap: onTap,
    shiftLabel: shiftLabel,
    kind: kind,
    active: active,
    flex: flex,
    icon: i,
  );
}

class _KeyRow extends StatelessWidget {
  const _KeyRow(
    this.keys, {
    required this.height,
    required this.shift,
    required this.gap,
    this.numberRow = false,
  });

  final double gap;

  /// Number-pad rows style plain keys as large white number keys.
  final bool numberRow;

  final List<_KeySpec> keys;
  final double height;
  final bool shift;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: gap),
      child: Row(
        children: [
          for (final (i, k) in keys.indexed) ...[
            if (i > 0) const SizedBox(width: 6),
            Expanded(
              flex: k.flex,
              child: _Key(
                spec: k,
                height: height,
                kind: numberRow && k.kind == _KeyKind.function
                    ? _KeyKind.number
                    : k.kind,
                shift: shift,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Key extends StatefulWidget {
  const _Key({
    required this.spec,
    required this.height,
    required this.kind,
    required this.shift,
  });

  final _KeySpec spec;
  final double height;
  final _KeyKind kind;
  final bool shift;

  @override
  State<_Key> createState() => _KeyState();
}

class _KeyState extends State<_Key> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.spec;
    final showShift = widget.shift && s.shiftLabel != null;
    final (bg, fg) = switch (widget.kind) {
      _KeyKind.equals => (AppColors.red, Colors.white),
      _KeyKind.danger => (AppColors.redTint, AppColors.red),
      _KeyKind.operator => (const Color(0xFFF1F1F3), AppColors.ink),
      _KeyKind.number => (Colors.white, AppColors.ink),
      _KeyKind.function =>
        s.active
            ? (AppColors.ink, Colors.white)
            : (const Color(0xFFF7F7F8), AppColors.ink),
    };
    final isNumber = widget.kind != _KeyKind.function;

    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      onTap: s.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 90),
        height: widget.height,
        decoration: BoxDecoration(
          color: _down ? Color.lerp(bg, Colors.black, 0.08) : bg,
          borderRadius: BorderRadius.circular(12),
          border: widget.kind == _KeyKind.number
              ? Border.all(color: AppColors.border)
              : null,
        ),
        child: Stack(
          children: [
            if (s.shiftLabel != null && !showShift)
              Positioned(
                top: 3,
                left: 0,
                right: 0,
                child: Center(
                  child: MathText(
                    s.shiftLabel!,
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: AppColors.red,
                    ),
                  ),
                ),
              ),
            Center(
              child: Padding(
                padding: EdgeInsets.only(
                  top: s.shiftLabel != null && !showShift ? 8 : 0,
                ),
                child: s.icon != null
                    ? Icon(s.icon, color: fg, size: 22)
                    : FittedBox(
                        fit: BoxFit.scaleDown,
                        child: MathText(
                          showShift ? s.shiftLabel! : s.label,
                          style: TextStyle(
                            fontSize: isNumber ? 22 : 14,
                            fontWeight: isNumber
                                ? FontWeight.w500
                                : FontWeight.w600,
                            color: showShift ? AppColors.red : fg,
                            fontFeatures: _tabular,
                          ),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Indicator extends StatelessWidget {
  const _Indicator(
    this.label, {
    this.active = false,
    this.red = false,
    this.onTap,
  });

  final String label;
  final bool active;
  final bool red;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = red
        ? AppColors.red
        : (active ? AppColors.ink : AppColors.faint);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
            color: color,
          ),
        ),
      ),
    );
  }
}
