import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

import 'package:aoj_sitekit/calc/sci/sci_engine.dart';
import 'package:aoj_sitekit/calc/sci/solvers.dart';

/// Splits a readable expression into key tokens, longest match first.
List<String> keys(String s) {
  const multi = [
    'sin⁻¹(', 'cos⁻¹(', 'tan⁻¹(', 'sinh⁻¹(', 'cosh⁻¹(', 'tanh⁻¹(', //
    'sinh(', 'cosh(', 'tanh(', 'sin(', 'cos(', 'tan(', 'log(', 'ln(',
    '10^(', 'e^(', '√(', '∛(', 'Abs(', '∫(', 'd/dx(', 'Σ(', 'Ans', '⁻¹',
    'ˣ√',
  ];
  final out = <String>[];
  var i = 0;
  outer:
  while (i < s.length) {
    if (s[i] == ' ') {
      i++;
      continue;
    }
    for (final m in multi) {
      if (s.startsWith(m, i)) {
        out.add(m);
        i += m.length;
        continue outer;
      }
    }
    out.add(s[i++]);
  }
  return out;
}

double calc(String s, {AngleMode angle = AngleMode.deg, double ans = 0}) =>
    evaluate(keys(s), EvalContext(angle: angle, ans: ans));

void main() {
  group('arithmetic and precedence', () {
    test('basic', () {
      expect(calc('2+3×4'), 14);
      expect(calc('(2+3)×4'), 20);
      expect(calc('7÷2'), 3.5);
      expect(calc('−2²'), -4);
      expect(calc('2^3^2'), 512); // right-associative
      expect(calc('2^−1'), 0.5);
    });

    test('implicit multiplication binds tighter than ÷', () {
      expect(calc('1÷2π'), closeTo(1 / (2 * math.pi), 1e-15));
      expect(calc('2(3+4)'), 14);
      expect(calc('(1+1)(2+2)'), 8);
    });

    test('postfix, roots and combinatorics', () {
      expect(calc('5!'), 120);
      expect(calc('3²+4²'), 25);
      expect(calc('2³'), 8);
      expect(calc('4⁻¹'), 0.25);
      expect(calc('50%'), 0.5);
      expect(calc('3ˣ√27'), closeTo(3, 1e-12));
      expect(calc('3ˣ√−8'), closeTo(-2, 1e-12));
      expect(calc('√(16)'), 4);
      expect(calc('∛(−27)'), closeTo(-3, 1e-12));
      expect(calc('5C2'), 10);
      expect(calc('5P2'), 20);
    });

    test('scientific E notation', () {
      expect(calc('1.5E3'), 1500);
      expect(calc('2E−3'), closeTo(0.002, 1e-18));
    });

    test('unclosed brackets are closed at the end', () {
      expect(calc('√(9'), 3);
      expect(calc('2×(3+4'), 14);
    });

    test('Ans recall', () {
      expect(calc('Ans×2', ans: 21), 42);
    });
  });

  group('functions', () {
    test('trig in degrees is exact at standard angles', () {
      expect(calc('sin(30)'), closeTo(0.5, 1e-15));
      expect(calc('sin(180)'), 0);
      expect(calc('cos(90)'), 0);
      expect(calc('tan(45)'), closeTo(1, 1e-15));
      expect(calc('sin⁻¹(0.5)'), closeTo(30, 1e-12));
    });

    test('radians and grads', () {
      expect(calc('sin(π÷2)', angle: AngleMode.rad), 1);
      expect(calc('cos(200)', angle: AngleMode.grad), -1);
    });

    test('logs and exponentials', () {
      expect(calc('log(1000)'), closeTo(3, 1e-15));
      expect(calc('ln(e)'), 1);
      expect(calc('10^(2)'), 100);
      expect(calc('e^(0)'), 1);
    });

    test('hyperbolic', () {
      expect(calc('sinh(0)'), 0);
      expect(calc('cosh(0)'), 1);
      expect(calc('tanh⁻¹(0)'), 0);
    });

    test('calculus and summation', () {
      expect(calc('∫(X², 0, 3)'), closeTo(9, 1e-9));
      expect(calc('∫(sin(X), 0, π)', angle: AngleMode.rad), closeTo(2, 1e-9));
      expect(calc('d/dx(X³, 2)'), closeTo(12, 1e-8));
      expect(calc('Σ(X, 1, 100)'), 5050);
    });
  });

  group('errors', () {
    test('Math ERROR', () {
      for (final s in [
        '1÷0',
        'ln(0)',
        '√(−1)',
        'tan(90)',
        'sin⁻¹(2)',
        '(−1)!',
        '171!',
      ]) {
        expect(() => calc(s), throwsA(CalcError.math), reason: s);
      }
    });

    test('Syntax ERROR', () {
      for (final s in ['', '2+', '×3', ')', '1..2', 'Abs(1,2)']) {
        expect(() => calc(s), throwsA(CalcError.syntax), reason: s);
      }
    });
  });

  group('formatting', () {
    test('10 significant digits and E notation', () {
      expect(formatNumber(1 / 3).toString(), '0.3333333333');
      expect(formatNumber(2).toString(), '2');
      expect(formatNumber(123456789012).toString(), '1.23456789E11');
      expect(formatNumber(0.0000001).toString(), '1E-7');
    });

    test('ENG notation uses multiples of 3', () {
      expect(formatNumber(12345, eng: true).toString(), '12.345E3');
      expect(formatNumber(0.0047, eng: true).toString(), '4.7E-3');
    });

    test('fractions', () {
      expect(toFraction(0.75), (3, 4));
      expect(toFraction(-1 / 3), (-1, 3));
      expect(toFraction(math.pi), isNull);
      expect(toFraction(4), isNull);
    });
  });

  group('solvers', () {
    test('quadratic with real and complex roots', () {
      final real = solveQuadratic(1, -3, 2);
      expect(real.map((z) => z.re), [2, 1]);
      final complex = solveQuadratic(1, 0, 1);
      expect(complex[0].re, 0);
      expect(complex[0].im, 1);
      expect(complex[1].im, -1);
      expect(quadraticVertex(1, -4, 3), (2, -1));
    });

    test('cubic', () {
      final roots = solveCubic(1, -6, 11, -6);
      expect(roots.map((z) => z.re), [3, 2, 1]);
      expect(roots.every((z) => z.isReal), isTrue);
      final mixed = solveCubic(1, 0, 0, -1); // x³ = 1
      expect(mixed.first.re, 1);
      expect(mixed[1].im.abs(), closeTo(math.sqrt(3) / 2, 1e-12));
    });

    test('linear systems', () {
      expect(
        solveLinear(
          [
            [2, 1],
            [1, -1],
          ],
          [5, 1],
        ),
        [2, 1],
      );
      expect(
        solveLinear(
          [
            [1, 1, 1],
            [0, 2, 5],
            [2, 5, -1],
          ],
          [6, -4, 27],
        ),
        [5, 3, -2],
      );
      expect(
        solveLinear(
          [
            [1, 2],
            [2, 4],
          ],
          [3, 6],
        ),
        isNull,
      );
    });

    test('one-variable statistics', () {
      final s = oneVarStats([2, 4, 4, 4, 5, 5, 7, 9]);
      expect(s.n, 8);
      expect(s.mean, 5);
      expect(s.popSd, 2);
      expect(s.sampleSd, closeTo(2.138089935, 1e-9));
      expect(s.median, 4.5);
      expect(s.q1, 4);
      expect(s.q3, 6);
    });

    test('linear regression', () {
      final r = linearRegression([1, 2, 3, 4], [3, 5, 7, 9]);
      expect(r.a, closeTo(1, 1e-12));
      expect(r.b, closeTo(2, 1e-12));
      expect(r.r, closeTo(1, 1e-12));
      expect(r.estimateY(10), closeTo(21, 1e-12));
    });
  });
}
