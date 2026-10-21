import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/user_prefs.dart';
import '../theme/app_theme.dart';
import '../widgets/fade_route.dart';
import 'homepage.dart';
import 'onboarding_screen.dart';

/// Launch screen: the AOJ mark animates in at the centre, with the SiteKit
/// name below and "Powered by AOJ" at the bottom. Leads to onboarding on
/// first launch, otherwise straight to the homepage.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // One-shot intro: mark, then name, then the "powered by" line.
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2800),
  );

  // Looping rings rippling out from the mark.
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  )..repeat();

  late final Animation<double> _markIn = CurvedAnimation(
    parent: _intro,
    curve: const Interval(0.0, 0.45, curve: Curves.elasticOut),
  );
  late final Animation<double> _markFade = CurvedAnimation(
    parent: _intro,
    curve: const Interval(0.0, 0.15, curve: Curves.easeIn),
  );
  late final Animation<double> _name = CurvedAnimation(
    parent: _intro,
    curve: const Interval(0.35, 0.6, curve: Curves.easeOutCubic),
  );
  late final Animation<double> _poweredBy = CurvedAnimation(
    parent: _intro,
    curve: const Interval(0.55, 0.8, curve: Curves.easeOut),
  );

  @override
  void initState() {
    super.initState();
    _intro.forward().whenComplete(_goNext);
  }

  Future<void> _goNext() async {
    // Never leave the user stuck here: if the saved profile can't be read,
    // fall back to onboarding.
    String? name;
    try {
      name = await UserPrefs.name().timeout(const Duration(seconds: 3));
    } catch (e) {
      debugPrint('Reading profile failed: $e');
    }
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      fadeRoute(name != null ? HomePage(name: name) : const OnboardingScreen()),
    );
  }

  @override
  void dispose() {
    _intro.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppColors.white,
        body: SafeArea(
          child: Column(
            // Stretch so everything centres on the screen, not on the
            // widest line.
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(flex: 5),
              Center(
                child: SizedBox.square(
                  dimension: 220,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      AnimatedBuilder(
                        animation: _pulse,
                        builder: (_, _) => CustomPaint(
                          size: const Size.square(220),
                          painter: _RipplePainter(_pulse.value),
                        ),
                      ),
                      FadeTransition(
                        opacity: _markFade,
                        child: AnimatedBuilder(
                          animation: _markIn,
                          // Springs in with a small quarter-turn settle.
                          builder: (_, child) => Transform.rotate(
                            angle: (1 - _markIn.value) * -0.6,
                            child: Transform.scale(
                              scale: _markIn.value,
                              child: child,
                            ),
                          ),
                          child: Image.asset(
                            AppAssets.mark,
                            width: 120,
                            height: 120,
                            semanticLabel: 'AOJ',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              _Reveal(
                animation: _name,
                child: const Column(
                  children: [
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: 'Site',
                            style: TextStyle(color: AppColors.ink),
                          ),
                          TextSpan(
                            text: 'Kit',
                            style: TextStyle(color: AppColors.red),
                          ),
                        ],
                      ),
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Engineering tools for the site',
                      style: TextStyle(fontSize: 13, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              const Spacer(flex: 6),
              FadeTransition(opacity: _poweredBy, child: const _PoweredBy()),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _PoweredBy extends StatelessWidget {
  const _PoweredBy();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        Text(
          'Powered by',
          style: TextStyle(
            fontSize: 11,
            letterSpacing: 1.2,
            color: AppColors.faint,
          ),
        ),
        SizedBox(height: 4),
        Text(
          'AOJ GLOBAL CONCEPT LIMITED',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.6,
            color: AppColors.red,
          ),
        ),
      ],
    );
  }
}

class _Reveal extends StatelessWidget {
  const _Reveal({required this.animation, required this.child});

  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween(
          begin: const Offset(0, 0.4),
          end: Offset.zero,
        ).animate(animation),
        child: child,
      ),
    );
  }
}

class _RipplePainter extends CustomPainter {
  _RipplePainter(this.t);

  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final maxRadius = size.width / 2;
    // Three staggered rings expanding from the mark's edge and fading out.
    for (var i = 0; i < 3; i++) {
      final p = (t + i / 3) % 1.0;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = AppColors.red.withValues(alpha: (1 - p) * 0.3);
      canvas.drawCircle(center, maxRadius * (0.55 + 0.45 * p), paint);
    }
  }

  @override
  bool shouldRepaint(_RipplePainter old) => old.t != t;
}
