import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/splash_screen.dart';
import 'services/notes_repository.dart';
import 'services/reminder_service.dart';
import 'theme/app_theme.dart';

/// Widest the phone layout is allowed to stretch on tablets.
const _maxContentWidth = 600.0;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // Log errors instead of crashing; a failing service must not block launch.
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
  };

  await Future.wait([
    _guard('notes', NotesRepository.instance.init),
    _guard('reminders', ReminderService.instance.init),
  ]);

  runApp(const SiteKitApp());
}

Future<void> _guard(String name, Future<void> Function() init) async {
  try {
    await init();
  } catch (e, s) {
    debugPrint('Startup: $name failed: $e\n$s');
  }
}

class SiteKitApp extends StatelessWidget {
  const SiteKitApp({super.key});

  /// App-wide layout rules; also used by tests to mirror the real shell.
  static Widget responsiveBuilder(BuildContext context, Widget? child) =>
      _Responsive(child: child!);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SiteKit',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      scrollBehavior: const MaterialScrollBehavior().copyWith(
        scrollbars: false,
      ),
      builder: responsiveBuilder,
      home: const SplashScreen(),
    );
  }
}

/// Keeps layouts readable on any device: caps very large system font sizes
/// that would break fixed-height controls, and centres the phone layout on
/// tablets instead of stretching it.
class _Responsive extends StatelessWidget {
  const _Responsive({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final width = math.min(mq.size.width, _maxContentWidth);
    final data = mq.copyWith(
      textScaler: mq.textScaler.clamp(
        minScaleFactor: 0.85,
        maxScaleFactor: 1.3,
      ),
      size: Size(width, mq.size.height),
    );
    final content = MediaQuery(data: data, child: child);
    if (mq.size.width <= _maxContentWidth) return content;
    return ColoredBox(
      color: AppColors.border,
      child: Center(
        child: SizedBox(width: width, child: content),
      ),
    );
  }
}
