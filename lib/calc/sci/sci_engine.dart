import 'dart:math' as math;

// Scientific calculator engine, modelled on the Casio fx-115ES Plus:
// key tokens in, a number (or a Casio-style error) out.
//
// Precedence, highest first: postfix (x², x³, x⁻¹, x!, %), power and root
// (right-associative), unary minus, nPr/nCr, implicit multiplication,
// × and ÷, + and −. As on the Casio, implicit multiplication binds tighter
// than ÷, so 1÷2π = 1/(2π), and −2² = −4.

enum AngleMode {
  deg('DEG'),
  rad('RAD'),
  grad('GRA');

  const AngleMode(this.label);
  final String label;
}

class CalcError implements Exception {
  const CalcError(this.message);
  final String message;

  static const syntax = CalcError('Syntax ERROR');
  static const math = CalcError('Math ERROR');

  @override
  String toString() => message;
}

class EvalContext {
  const EvalContext({
    this.angle = AngleMode.deg,
    this.ans = 0,
    this.memory = 0,
    this.x,
  });

  final AngleMode angle;
  final double ans;
  final double memory;

  /// Value bound to X inside ∫, d/dx and Σ.
  final double? x;

  EvalContext withX(double value) =>
      EvalContext(angle: angle, ans: ans, memory: memory, x: value);
}

/// Every key token the keypad can insert.
abstract final class Tok {
  static const plus = '+', minus = '−', times = '×', divide = '÷';
  static const power = '^', root = 'ˣ√';
  static const square = '²', cube = '³', inverse = '⁻¹', fact = '!';
  static const percent = '%', exp = 'E';
  static const nCr = 'C', nPr = 'P';
  static const open = '(', close = ')', comma = ',';
  static const pi = 'π', e = 'e', ans = 'Ans', mem = 'M', x = 'X';

  static const sin = 'sin(', cos = 'cos(', tan = 'tan(';
  static const asin = 'sin⁻¹(', acos = 'cos⁻¹(', atan = 'tan⁻¹(';
  static const sinh = 'sinh(', cosh = 'cosh(', tanh = 'tanh(';
  static const asinh = 'sinh⁻¹(', acosh = 'cosh⁻¹(', atanh = 'tanh⁻¹(';
  static const log = 'log(', ln = 'ln(', pow10 = '10^(', powE = 'e^(';
  static const sqrt = '√(', cbrt = '∛(', abs = 'Abs(';
  static const integral = '∫(', derivative = 'd/dx(', sum = 'Σ(';
}

// ---------------------------------------------------------------------------
// Lexer
// ---------------------------------------------------------------------------

sealed class _Lex {}

class _Num extends _Lex {
  _Num(this.value);
  final double value;
}

class _Op extends _Lex {
  _Op(this.op);
  final String op;
}

class _Func extends _Lex {
  _Func(this.name);
  final String name;
}

class _Atom extends _Lex {
  _Atom(this.name);
  final String name;
}

bool _isDigit(String t) => t.length == 1 && '0123456789.'.contains(t);

List<_Lex> _lex(List<String> tokens) {
  final out = <_Lex>[];
  var i = 0;
  while (i < tokens.length) {
    final t = tokens[i];
    if (_isDigit(t) || t == Tok.exp) {
      final buf = StringBuffer();
      while (i < tokens.length && _isDigit(tokens[i])) {
        buf.write(tokens[i++]);
      }
      var mantissa = buf.toString();
      if (mantissa.isEmpty) mantissa = '1'; // "E3" means 1×10³
      if (mantissa.split('.').length > 2 || mantissa == '.') {
        throw CalcError.syntax;
      }
      var value = double.parse(
        mantissa.endsWith('.') ? '${mantissa}0' : mantissa,
      );
      if (i < tokens.length && tokens[i] == Tok.exp) {
        i++;
        var sign = 1;
        if (i < tokens.length &&
            (tokens[i] == Tok.minus || tokens[i] == Tok.plus)) {
          if (tokens[i] == Tok.minus) sign = -1;
          i++;
        }
        final exp = StringBuffer();
        while (i < tokens.length && _isDigit(tokens[i]) && tokens[i] != '.') {
          exp.write(tokens[i++]);
        }
        if (exp.isEmpty) throw CalcError.syntax;
        value *= math.pow(10, sign * int.parse(exp.toString()));
      }
      out.add(_Num(value));
      continue;
    }
    if (t.endsWith('(') && t.length > 1) {
      out.add(_Func(t));
    } else if (const [Tok.pi, Tok.e, Tok.ans, Tok.mem, Tok.x].contains(t)) {
      out.add(_Atom(t));
    } else {
      out.add(_Op(t));
    }
    i++;
  }
  return out;
}

// ---------------------------------------------------------------------------
// Parser → evaluator closures
// ---------------------------------------------------------------------------

typedef _Eval = double Function(EvalContext c);

class _Parser {
  _Parser(this.items);

  final List<_Lex> items;
  var _pos = 0;

  _Lex? get _peek => _pos < items.length ? items[_pos] : null;
  bool get _atEnd => _pos >= items.length;

  bool _isOp(String op) {
    final p = _peek;
    return p is _Op && p.op == op;
  }

  bool _accept(String op) {
    if (_isOp(op)) {
      _pos++;
      return true;
    }
    return false;
  }

  /// Closing brackets are optional at the end, as on the Casio.
  void _close() {
    if (_accept(Tok.close)) return;
    if (!_atEnd) throw CalcError.syntax;
  }

  _Eval parse() {
    if (items.isEmpty) throw CalcError.syntax;
    final e = _sum();
    if (!_atEnd) throw CalcError.syntax;
    return e;
  }

  _Eval _sum() {
    var left = _product();
    while (true) {
      if (_accept(Tok.plus)) {
        final l = left, r = _product();
        left = (c) => l(c) + r(c);
      } else if (_accept(Tok.minus)) {
        final l = left, r = _product();
        left = (c) => l(c) - r(c);
      } else {
        return left;
      }
    }
  }

  _Eval _product() {
    var left = _implicit();
    while (true) {
      if (_accept(Tok.times)) {
        final l = left, r = _implicit();
        left = (c) => l(c) * r(c);
      } else if (_accept(Tok.divide)) {
        final l = left, r = _implicit();
        left = (c) {
          final d = r(c);
          if (d == 0) throw CalcError.math;
          return l(c) / d;
        };
      } else {
        return left;
      }
    }
  }

  bool get _startsPrimary {
    final p = _peek;
    return p is _Num ||
        p is _Atom ||
        p is _Func ||
        (p is _Op && p.op == Tok.open);
  }

  _Eval _implicit() {
    var left = _combination();
    while (_startsPrimary) {
      final l = left, r = _combination();
      left = (c) => l(c) * r(c);
    }
    return left;
  }

  _Eval _combination() {
    var left = _unary();
    while (_isOp(Tok.nCr) || _isOp(Tok.nPr)) {
      final choose = (_peek as _Op).op == Tok.nCr;
      _pos++;
      final l = left, r = _unary();
      left = (c) => choose ? _nCr(l(c), r(c)) : _nPr(l(c), r(c));
    }
    return left;
  }

  _Eval _unary() {
    if (_accept(Tok.minus)) {
      final v = _unary();
      return (c) => -v(c);
    }
    if (_accept(Tok.plus)) return _unary();
    return _power();
  }

  _Eval _power() {
    final base = _postfix();
    if (_accept(Tok.power)) {
      final exp = _unary();
      return (c) => _pow(base(c), exp(c));
    }
    if (_accept(Tok.root)) {
      final radicand = _unary();
      return (c) => _nthRoot(base(c), radicand(c));
    }
    return base;
  }

  _Eval _postfix() {
    var v = _primary();
    while (true) {
      final p = _peek;
      if (p is! _Op) return v;
      final inner = v;
      switch (p.op) {
        case Tok.square:
          v = (c) => _pow(inner(c), 2);
        case Tok.cube:
          v = (c) => _pow(inner(c), 3);
        case Tok.inverse:
          v = (c) {
            final x = inner(c);
            if (x == 0) throw CalcError.math;
            return 1 / x;
          };
        case Tok.fact:
          v = (c) => _factorial(inner(c));
        case Tok.percent:
          v = (c) => inner(c) / 100;
        default:
          return v;
      }
      _pos++;
    }
  }

  _Eval _primary() {
    final p = _peek;
    if (p == null) throw CalcError.syntax;
    _pos++;
    switch (p) {
      case _Num(:final value):
        return (_) => value;
      case _Atom(:final name):
        return switch (name) {
          Tok.pi => (_) => math.pi,
          Tok.e => (_) => math.e,
          Tok.ans => (c) => c.ans,
          Tok.mem => (c) => c.memory,
          _ => (c) => c.x ?? (throw CalcError.syntax),
        };
      case _Op(:final op) when op == Tok.open:
        final inner = _sum();
        _close();
        return inner;
      case _Func(:final name):
        return _function(name);
      case _Op():
        throw CalcError.syntax;
    }
  }

  _Eval _function(String name) {
    final args = [_sum()];
    while (_accept(Tok.comma)) {
      args.add(_sum());
    }
    _close();

    if (name == Tok.integral || name == Tok.sum) {
      if (args.length != 3) throw CalcError.syntax;
      final [f, a, b] = args;
      return name == Tok.integral
          ? (c) => _integrate(f, a(c), b(c), c)
          : (c) => _summation(f, a(c), b(c), c);
    }
    if (name == Tok.derivative) {
      if (args.length != 2) throw CalcError.syntax;
      final [f, at] = args;
      return (c) => _differentiate(f, at(c), c);
    }
    if (args.length != 1) throw CalcError.syntax;
    final arg = args.single;
    final fn = _unaryFunctions[name];
    if (fn == null) throw CalcError.syntax;
    return (c) => fn(arg(c), c.angle);
  }
}

// ---------------------------------------------------------------------------
// Maths
// ---------------------------------------------------------------------------

double _toRad(double v, AngleMode m) => switch (m) {
  AngleMode.deg => v * math.pi / 180,
  AngleMode.rad => v,
  AngleMode.grad => v * math.pi / 200,
};

double _fromRad(double v, AngleMode m) => switch (m) {
  AngleMode.deg => v * 180 / math.pi,
  AngleMode.rad => v,
  AngleMode.grad => v * 200 / math.pi,
};

/// Snaps float noise such as sin(180°) = 1.2e-16 to zero.
double _clean(double v) => v.abs() < 1e-14 ? 0 : v;

double _domain(bool ok, double Function() f) => ok ? f() : throw CalcError.math;

/// Angle in quarter turns, to make tan(90°) a Math ERROR rather than 1.6e16.
bool _isOddQuarterTurn(double v, AngleMode m) {
  final quarter = switch (m) {
    AngleMode.deg => 90.0,
    AngleMode.grad => 100.0,
    AngleMode.rad => math.pi / 2,
  };
  final k = v / quarter;
  return (k - k.roundToDouble()).abs() < 1e-12 && k.round().isOdd;
}

double _log(double x) => math.log(x);

final Map<String, double Function(double, AngleMode)> _unaryFunctions = {
  Tok.sin: (v, m) => _clean(math.sin(_toRad(v, m))),
  Tok.cos: (v, m) => _clean(math.cos(_toRad(v, m))),
  Tok.tan: (v, m) => _isOddQuarterTurn(v, m)
      ? throw CalcError.math
      : _clean(math.tan(_toRad(v, m))),
  Tok.asin: (v, m) => _domain(v.abs() <= 1, () => _fromRad(math.asin(v), m)),
  Tok.acos: (v, m) => _domain(v.abs() <= 1, () => _fromRad(math.acos(v), m)),
  Tok.atan: (v, m) => _fromRad(math.atan(v), m),
  Tok.sinh: (v, _) => (math.exp(v) - math.exp(-v)) / 2,
  Tok.cosh: (v, _) => (math.exp(v) + math.exp(-v)) / 2,
  Tok.tanh: (v, _) {
    final a = math.exp(v), b = math.exp(-v);
    return a.isInfinite ? 1 : (b.isInfinite ? -1 : (a - b) / (a + b));
  },
  Tok.asinh: (v, _) => _log(v + math.sqrt(v * v + 1)),
  Tok.acosh: (v, _) => _domain(v >= 1, () => _log(v + math.sqrt(v * v - 1))),
  Tok.atanh: (v, _) =>
      _domain(v.abs() < 1, () => 0.5 * _log((1 + v) / (1 - v))),
  Tok.log: (v, _) => _domain(v > 0, () => math.log(v) / math.ln10),
  Tok.ln: (v, _) => _domain(v > 0, () => math.log(v)),
  Tok.pow10: (v, _) => _pow(10, v),
  Tok.powE: (v, _) => math.exp(v),
  Tok.sqrt: (v, _) => _domain(v >= 0, () => math.sqrt(v)),
  Tok.cbrt: (v, _) => v < 0 ? -_pow(-v, 1 / 3) : _pow(v, 1 / 3),
  Tok.abs: (v, _) => v.abs(),
};

double _pow(double base, double exp) {
  final r = math.pow(base, exp).toDouble();
  if (r.isNaN) throw CalcError.math;
  return r;
}

double _nthRoot(double n, double x) {
  if (n == 0) throw CalcError.math;
  final isOddInteger = n == n.roundToDouble() && n.round().isOdd;
  if (x < 0) {
    if (!isOddInteger) throw CalcError.math;
    return -_pow(-x, 1 / n);
  }
  return _pow(x, 1 / n);
}

bool _isNonNegInt(double v) => v >= 0 && v == v.roundToDouble();

double _factorial(double v) {
  if (!_isNonNegInt(v) || v > 170) throw CalcError.math;
  var r = 1.0;
  for (var k = 2; k <= v; k++) {
    r *= k;
  }
  return r;
}

double _nPr(double n, double r) {
  if (!_isNonNegInt(n) || !_isNonNegInt(r) || r > n) throw CalcError.math;
  var out = 1.0;
  for (var k = 0; k < r; k++) {
    out *= n - k;
  }
  return out;
}

double _nCr(double n, double r) {
  if (!_isNonNegInt(n) || !_isNonNegInt(r) || r > n) throw CalcError.math;
  final k = math.min(r, n - r);
  var out = 1.0;
  for (var i = 1; i <= k; i++) {
    out = out * (n - k + i) / i;
  }
  return out.roundToDouble();
}

double _integrate(_Eval f, double a, double b, EvalContext c) {
  double g(double x) {
    final v = f(c.withX(x));
    if (!v.isFinite) throw CalcError.math;
    return v;
  }

  double simpson(double a, double b, double fa, double fm, double fb) =>
      (b - a) / 6 * (fa + 4 * fm + fb);

  double adapt(
    double a,
    double b,
    double fa,
    double fm,
    double fb,
    double whole,
    double tol,
    int depth,
  ) {
    final m = (a + b) / 2;
    final lm = (a + m) / 2, rm = (m + b) / 2;
    final flm = g(lm), frm = g(rm);
    final left = simpson(a, m, fa, flm, fm);
    final right = simpson(m, b, fm, frm, fb);
    final delta = left + right - whole;
    if (depth <= 0 || delta.abs() <= 15 * tol) {
      return left + right + delta / 15;
    }
    return adapt(a, m, fa, flm, fm, left, tol / 2, depth - 1) +
        adapt(m, b, fm, frm, fb, right, tol / 2, depth - 1);
  }

  if (a == b) return 0;
  final fa = g(a), fb = g(b), fm = g((a + b) / 2);
  return _clean(adapt(a, b, fa, fm, fb, simpson(a, b, fa, fm, fb), 1e-10, 40));
}

double _differentiate(_Eval f, double x, EvalContext c) {
  final h = 1e-3 * math.max(1, x.abs());
  double g(double v) => f(c.withX(v));
  final d =
      (-g(x + 2 * h) + 8 * g(x + h) - 8 * g(x - h) + g(x - 2 * h)) / (12 * h);
  if (!d.isFinite) throw CalcError.math;
  // Trim the stencil's last-digit noise so d/dx(X²,3) shows 6, not 5.9999…
  return double.parse(d.toStringAsPrecision(10));
}

double _summation(_Eval f, double a, double b, EvalContext c) {
  if (a != a.roundToDouble() || b != b.roundToDouble() || b < a) {
    throw CalcError.math;
  }
  if (b - a > 1e6) throw CalcError.math;
  var total = 0.0;
  for (var k = a; k <= b; k++) {
    total += f(c.withX(k));
  }
  return total;
}

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

/// Evaluates key [tokens]; throws [CalcError] on bad syntax or maths.
double evaluate(List<String> tokens, EvalContext context) {
  final e = _Parser(_lex(tokens)).parse();
  final v = e(context);
  if (!v.isFinite || v.abs() >= 1e100) throw CalcError.math;
  return v;
}

/// A number split for display as mantissa × 10^exponent.
class DisplayNumber {
  const DisplayNumber(this.mantissa, [this.exponent]);
  final String mantissa;
  final int? exponent;

  @override
  String toString() => exponent == null ? mantissa : '${mantissa}E$exponent';
}

String _trimZeros(String s) {
  if (!s.contains('.')) return s;
  s = s.replaceFirst(RegExp(r'0+$'), '');
  return s.endsWith('.') ? s.substring(0, s.length - 1) : s;
}

/// Formats to 10 significant digits like the Casio; [eng] forces an
/// exponent that is a multiple of 3.
DisplayNumber formatNumber(double v, {bool eng = false}) {
  if (v == 0) return const DisplayNumber('0');
  final rounded = double.parse(v.toStringAsPrecision(10));
  final mag = rounded.abs();
  if (!eng && mag >= 1e-6 && mag < 1e10) {
    var s = rounded.toStringAsPrecision(10);
    if (s.contains('e')) s = rounded.toStringAsFixed(12);
    return DisplayNumber(_trimZeros(s));
  }
  var exp = (math.log(mag) / math.ln10).floor();
  if (eng) exp = (exp / 3).floor() * 3;
  var mantissa = rounded / math.pow(10, exp);
  // Guard against 9.9999999999 rounding up to 10.
  if (mantissa.abs() >= (eng ? 1000 : 10)) {
    exp += eng ? 3 : 1;
    mantissa = rounded / math.pow(10, exp);
  }
  final m = _trimZeros(mantissa.toStringAsPrecision(10));
  return exp == 0 ? DisplayNumber(m) : DisplayNumber(m, exp);
}

/// Exact fraction for [v], or null. Like the Casio, only fractions that fit
/// the 10-digit display (numerator and denominator ≤ 9 digits together).
(int, int)? toFraction(double v) {
  if (v == v.roundToDouble() || v.abs() > 1e9) return null;
  final sign = v < 0 ? -1 : 1;
  final x = v.abs();
  var h0 = 0, h1 = 1, k0 = 1, k1 = 0;
  var f = x;
  for (var i = 0; i < 40; i++) {
    final a = f.floor();
    final h2 = a * h1 + h0, k2 = a * k1 + k0;
    if ('$h2'.length + '$k2'.length > 9) break;
    h0 = h1;
    h1 = h2;
    k0 = k1;
    k1 = k2;
    if ((h1 / k1 - x).abs() <= 1e-10 * math.max(1, x)) {
      return (sign * h1, k1);
    }
    final rest = f - a;
    if (rest < 1e-15) break;
    f = 1 / rest;
  }
  return null;
}
