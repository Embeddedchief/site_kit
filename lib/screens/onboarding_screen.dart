import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/user_prefs.dart';
import '../theme/app_theme.dart';
import '../widgets/fade_route.dart';
import '../widgets/reveal.dart';
import 'homepage.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  bool _saving = false;

  // Staggered entrance: logo, headline, chips, form card, button.
  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..forward();

  Animation<double> _step(double start, double end) => CurvedAnimation(
    parent: _entrance,
    curve: Interval(start, end, curve: Curves.easeOutCubic),
  );

  @override
  void dispose() {
    _entrance.dispose();
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final name = _nameController.text.trim();
    try {
      await UserPrefs.save(name: name, email: _emailController.text.trim());
    } catch (e) {
      // Carry on: the worst case is being asked again next launch.
      debugPrint('Saving profile failed: $e');
    }
    if (!mounted) return;
    Navigator.of(context).pushReplacement(fadeRoute(HomePage(name: name)));
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        resizeToAvoidBottomInset: true,
        body: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(AppAssets.onboardingBg, fit: BoxFit.cover),
            // Darken the photo so white text and the form stay readable.
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0.0, 0.35, 0.65, 1.0],
                  colors: [
                    Color(0xCC000000),
                    Color(0x55000000),
                    Color(0xAA2A0000),
                    Color(0xF0000000),
                  ],
                ),
              ),
            ),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: IntrinsicHeight(child: _buildContent()),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    return Column(
      children: [
        const SizedBox(height: 24),
        Reveal(animation: _step(0.0, 0.35), child: const _LogoBadge()),
        const Spacer(),
        Reveal(
          animation: _step(0.15, 0.5),
          child: Column(
            children: [
              Text.rich(
                const TextSpan(
                  children: [
                    TextSpan(text: 'Site'),
                    TextSpan(
                      text: 'Kit',
                      style: TextStyle(color: AppColors.red),
                    ),
                  ],
                ),
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  shadows: const [
                    Shadow(blurRadius: 16, color: Colors.black54),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Calculations, checklists and site tools\nfor Civil & MEP engineers, all in one kit.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Reveal(
          animation: _step(0.3, 0.6),
          child: const Row(
            children: [
              _DisciplineTile(icon: Icons.foundation, label: 'Civil'),
              SizedBox(width: 8),
              _DisciplineTile(icon: Icons.settings, label: 'Mechanical'),
              SizedBox(width: 8),
              _DisciplineTile(icon: Icons.bolt, label: 'Electrical'),
              SizedBox(width: 8),
              _DisciplineTile(icon: Icons.plumbing, label: 'Plumbing'),
            ],
          ),
        ),
        const SizedBox(height: 28),
        Reveal(
          animation: _step(0.45, 0.8),
          child: _GlassCard(
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Let's get you set up",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _GlassField(
                    controller: _nameController,
                    label: 'Full name',
                    hint: 'e.g. Ade Johnson',
                    icon: Icons.person_outline,
                    textInputAction: TextInputAction.next,
                    textCapitalization: TextCapitalization.words,
                    validator: (v) => (v == null || v.trim().length < 2)
                        ? 'Please enter your name'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  _GlassField(
                    controller: _emailController,
                    label: 'Email address',
                    hint: 'you@company.com',
                    icon: Icons.mail_outline,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _submit(),
                    validator: (v) {
                      final email = v?.trim() ?? '';
                      final valid = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                          .hasMatch(email);
                      return valid ? null : 'Please enter a valid email';
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        Reveal(
          animation: _step(0.6, 1.0),
          child: SizedBox(
            width: double.infinity,
            height: 56,
            child: FilledButton(
              onPressed: _saving ? null : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.red,
                disabledBackgroundColor: AppColors.redDark,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 6,
                shadowColor: AppColors.red.withValues(alpha: 0.5),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Get started',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(width: 8),
                        Icon(Icons.arrow_forward_rounded, size: 20),
                      ],
                    ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'by AOJ Global Concept Limited',
          style: TextStyle(color: Colors.white54, fontSize: 11),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _LogoBadge extends StatelessWidget {
  const _LogoBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(40),
        boxShadow: const [BoxShadow(blurRadius: 20, color: Colors.black38)],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(AppAssets.mark, width: 36, height: 36),
          const SizedBox(width: 10),
          const Text(
            'AOJ SiteKit',
            style: TextStyle(
              color: AppColors.ink,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _DisciplineTile extends StatelessWidget {
  const _DisciplineTile({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white24),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: AppColors.red,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 16, color: Colors.white),
            ),
            const SizedBox(height: 6),
            FittedBox(
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  const _GlassCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white24),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _GlassField extends StatelessWidget {
  const _GlassField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.validator,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final FormFieldValidator<String>? validator;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: color, width: width),
        );

    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      textCapitalization: textCapitalization,
      onFieldSubmitted: onSubmitted,
      style: const TextStyle(color: Colors.white),
      cursorColor: AppColors.red,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(color: Colors.white70),
        floatingLabelStyle: const TextStyle(color: Colors.white),
        hintStyle: const TextStyle(color: Colors.white38),
        errorStyle: const TextStyle(color: Color(0xFFFF8A80)),
        prefixIcon: Icon(icon, color: Colors.white70),
        filled: true,
        fillColor: Colors.black.withValues(alpha: 0.25),
        enabledBorder: border(Colors.white24),
        focusedBorder: border(AppColors.red, 1.6),
        errorBorder: border(const Color(0xFFFF8A80)),
        focusedErrorBorder: border(const Color(0xFFFF8A80), 1.6),
      ),
    );
  }
}
