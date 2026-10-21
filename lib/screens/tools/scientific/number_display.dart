import 'package:flutter/material.dart';

import '../../../calc/sci/sci_engine.dart';
import '../../../theme/app_theme.dart';

/// Shows a number textbook-style: stacked fractions and raised exponents.
class NumberDisplay extends StatelessWidget {
  const NumberDisplay({
    super.key,
    required this.value,
    this.fraction = false,
    this.eng = false,
    this.fontSize = 32,
    this.color = AppColors.ink,
  });

  final double value;
  final bool fraction;
  final bool eng;
  final double fontSize;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: fontSize,
      fontWeight: FontWeight.w600,
      color: color,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    final frac = fraction ? toFraction(value) : null;
    if (frac != null) {
      final (n, d) = frac;
      final small = style.copyWith(fontSize: fontSize * 0.62);
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (n < 0) Text('−', style: style),
          IntrinsicWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('${n.abs()}', textAlign: TextAlign.center, style: small),
                Container(height: 2, color: color),
                Text('$d', textAlign: TextAlign.center, style: small),
              ],
            ),
          ),
        ],
      );
    }

    final n = formatNumber(value, eng: eng);
    final mantissa = n.mantissa.replaceFirst('-', '−');
    if (n.exponent == null) return Text(mantissa, style: style);
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$mantissa×10', style: style),
        Text(
          '${n.exponent}'.replaceFirst('-', '−'),
          style: style.copyWith(fontSize: fontSize * 0.5),
        ),
      ],
    );
  }
}

/// Text with `^{…}` superscripts drawn as raised small text, so labels like
/// x^{−1} render in fonts without Unicode superscript glyphs.
class MathText extends StatelessWidget {
  const MathText(this.markup, {super.key, required this.style});

  final String markup;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    if (!markup.contains('^{')) return Text(markup, style: style);
    return Text.rich(TextSpan(children: mathSpans(markup, style)));
  }
}

final _sup = RegExp(r'\^\{([^}]*)\}');

List<InlineSpan> mathSpans(String markup, TextStyle style) {
  final size = style.fontSize ?? 14;
  final spans = <InlineSpan>[];
  var last = 0;
  for (final m in _sup.allMatches(markup)) {
    if (m.start > last) {
      spans.add(TextSpan(text: markup.substring(last, m.start), style: style));
    }
    spans.add(
      WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: Transform.translate(
          offset: Offset(0, -size * 0.38),
          child: Text(m[1]!, style: style.copyWith(fontSize: size * 0.62)),
        ),
      ),
    );
    last = m.end;
  }
  if (last < markup.length) {
    spans.add(TextSpan(text: markup.substring(last), style: style));
  }
  return spans;
}

/// Display markup for an expression token (see [MathText]).
String tokenMarkup(String token) => switch (token) {
  Tok.root => '^{x}√',
  Tok.cbrt => '^{3}√(',
  Tok.sum => '∑(',
  _ => token.replaceAll('⁻¹', '^{−1}'),
};

/// Plain-text form, e.g. for the equation and statistics results.
String formatPlain(double v) {
  final n = formatNumber(v);
  final m = n.mantissa.replaceFirst('-', '−');
  return n.exponent == null ? m : '$m×10^${n.exponent}';
}
