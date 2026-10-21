import 'dart:math' as math;

// Equation and statistics solvers for the EQN and STAT modes.

class Complex {
  const Complex(this.re, [this.im = 0]);
  final double re;
  final double im;

  bool get isReal => im == 0;

  Complex operator +(Complex o) => Complex(re + o.re, im + o.im);
  Complex operator -(Complex o) => Complex(re - o.re, im - o.im);
  Complex operator *(Complex o) =>
      Complex(re * o.re - im * o.im, re * o.im + im * o.re);
  Complex operator /(Complex o) {
    final d = o.re * o.re + o.im * o.im;
    return Complex((re * o.re + im * o.im) / d, (im * o.re - re * o.im) / d);
  }

  double get abs => math.sqrt(re * re + im * im);
}

/// Rounds away floating-point noise (12 significant digits) and drops a
/// negligible imaginary part.
Complex _tidy(Complex z, double scale) {
  double snap(double v) =>
      v.abs() < 1e-12 * scale ? 0 : double.parse(v.toStringAsPrecision(12));
  return Complex(snap(z.re), snap(z.im));
}

/// Roots of ax² + bx + c = 0.
List<Complex> solveQuadratic(double a, double b, double c) {
  if (a == 0) throw ArgumentError('a must not be 0');
  final disc = b * b - 4 * a * c;
  final scale = math.max(1.0, [a, b, c].map((v) => v.abs()).reduce(math.max));
  if (disc >= 0) {
    // Numerically stable form avoids cancellation when b² ≫ 4ac.
    final q = -0.5 * (b + (b >= 0 ? 1 : -1) * math.sqrt(disc));
    final r1 = q / a;
    final r2 = q == 0 ? 0.0 : c / q;
    final roots = [r1, r2]..sort((x, y) => y.compareTo(x));
    return [for (final r in roots) _tidy(Complex(r), scale)];
  }
  final re = -b / (2 * a), im = math.sqrt(-disc) / (2 * a).abs();
  return [_tidy(Complex(re, im), scale), _tidy(Complex(re, -im), scale)];
}

/// Roots of ax³ + bx² + cx + d = 0 (Durand–Kerner iteration).
List<Complex> solveCubic(double a, double b, double c, double d) {
  if (a == 0) throw ArgumentError('a must not be 0');
  final coeffs = [1.0, b / a, c / a, d / a];
  Complex p(Complex z) {
    var r = const Complex(0);
    for (final k in coeffs) {
      r = r * z + Complex(k);
    }
    return r;
  }

  var roots = [
    const Complex(0.4, 0.9),
    const Complex(-0.65, 0.72),
    const Complex(0.81, -0.31),
  ];
  for (var iter = 0; iter < 500; iter++) {
    var moved = 0.0;
    final next = <Complex>[];
    for (var i = 0; i < 3; i++) {
      var denom = const Complex(1);
      for (var j = 0; j < 3; j++) {
        if (i != j) denom = denom * (roots[i] - roots[j]);
      }
      final step = p(roots[i]) / denom;
      next.add(roots[i] - step);
      moved = math.max(moved, step.abs);
    }
    roots = next;
    if (moved < 1e-15) break;
  }
  final scale = math.max(1.0, coeffs.map((v) => v.abs()).reduce(math.max));
  final tidy = [for (final r in roots) _tidy(r, scale)];
  // Real roots first (descending), then complex pairs.
  tidy.sort((x, y) {
    if (x.isReal != y.isReal) return x.isReal ? -1 : 1;
    final byRe = y.re.compareTo(x.re);
    return byRe != 0 ? byRe : y.im.compareTo(x.im);
  });
  return tidy;
}

/// Turning point of ax² + bx + c as (x, y).
(double, double) quadraticVertex(double a, double b, double c) {
  final x = -b / (2 * a);
  return (x, a * x * x + b * x + c);
}

/// Solves the n×n system [m]·x = [rhs]; null if there is no unique solution.
List<double>? solveLinear(List<List<double>> m, List<double> rhs) {
  final n = rhs.length;
  final a = [
    for (var i = 0; i < n; i++) [...m[i], rhs[i]],
  ];
  for (var col = 0; col < n; col++) {
    var pivot = col;
    for (var r = col + 1; r < n; r++) {
      if (a[r][col].abs() > a[pivot][col].abs()) pivot = r;
    }
    if (a[pivot][col].abs() < 1e-12) return null;
    final tmp = a[col];
    a[col] = a[pivot];
    a[pivot] = tmp;
    for (var r = 0; r < n; r++) {
      if (r == col) continue;
      final f = a[r][col] / a[col][col];
      for (var k = col; k <= n; k++) {
        a[r][k] -= f * a[col][k];
      }
    }
  }
  return [
    for (var i = 0; i < n; i++)
      double.parse((a[i][n] / a[i][i]).toStringAsPrecision(12)) + 0.0,
  ];
}

class OneVarStats {
  const OneVarStats({
    required this.n,
    required this.mean,
    required this.sum,
    required this.sumSquares,
    required this.popSd,
    required this.sampleSd,
    required this.min,
    required this.q1,
    required this.median,
    required this.q3,
    required this.max,
  });

  final int n;
  final double mean, sum, sumSquares, popSd;
  final double? sampleSd;
  final double min, q1, median, q3, max;
}

double _median(List<double> sorted) {
  final n = sorted.length;
  return n.isOdd ? sorted[n ~/ 2] : (sorted[n ~/ 2 - 1] + sorted[n ~/ 2]) / 2;
}

/// 1-variable statistics; quartiles use the Casio method (halves exclude
/// the median when n is odd).
OneVarStats oneVarStats(List<double> data) {
  if (data.isEmpty) throw ArgumentError('No data');
  final s = [...data]..sort();
  final n = s.length;
  final sum = s.fold(0.0, (a, b) => a + b);
  final sumSq = s.fold(0.0, (a, b) => a + b * b);
  final mean = sum / n;
  final ss = s.fold(0.0, (a, b) => a + (b - mean) * (b - mean));
  final lower = s.sublist(0, n ~/ 2);
  final upper = s.sublist(n.isOdd ? n ~/ 2 + 1 : n ~/ 2);
  return OneVarStats(
    n: n,
    mean: mean,
    sum: sum,
    sumSquares: sumSq,
    popSd: math.sqrt(ss / n),
    sampleSd: n > 1 ? math.sqrt(ss / (n - 1)) : null,
    min: s.first,
    q1: n > 1 ? _median(lower) : s.first,
    median: _median(s),
    q3: n > 1 ? _median(upper) : s.first,
    max: s.last,
  );
}

class LinearRegression {
  const LinearRegression(this.a, this.b, this.r, this.n);

  /// y = a + bx
  final double a, b, r;
  final int n;

  double estimateY(double x) => a + b * x;
  double estimateX(double y) => (y - a) / b;
}

LinearRegression linearRegression(List<double> xs, List<double> ys) {
  final n = xs.length;
  if (n < 2) throw ArgumentError('Need at least 2 points');
  final mx = xs.reduce((a, b) => a + b) / n;
  final my = ys.reduce((a, b) => a + b) / n;
  var sxx = 0.0, syy = 0.0, sxy = 0.0;
  for (var i = 0; i < n; i++) {
    sxx += (xs[i] - mx) * (xs[i] - mx);
    syy += (ys[i] - my) * (ys[i] - my);
    sxy += (xs[i] - mx) * (ys[i] - my);
  }
  if (sxx == 0) throw ArgumentError('All x values are equal');
  final b = sxy / sxx;
  final r = syy == 0 ? 1.0 : sxy / math.sqrt(sxx * syy);
  return LinearRegression(my - b * mx, b, r, n);
}
