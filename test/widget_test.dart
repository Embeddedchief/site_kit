import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aoj_sitekit/main.dart';
import 'package:aoj_sitekit/screens/homepage.dart';
import 'package:aoj_sitekit/screens/onboarding_screen.dart';
import 'package:aoj_sitekit/screens/trade_page.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
    'splash leads to onboarding, which validates and saves the user',
    (tester) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(const SiteKitApp());
      expect(find.text('AOJ GLOBAL CONCEPT LIMITED'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 3300));
      await tester.pump(const Duration(seconds: 2));
      expect(find.byType(OnboardingScreen), findsOneWidget);

      await tester.tap(find.text('Get started'));
      await tester.pump();
      expect(find.text('Please enter your name'), findsOneWidget);
      expect(find.text('Please enter a valid email'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField).at(0), 'Ade Johnson');
      await tester.enterText(find.byType(TextFormField).at(1), 'ade@aoj.com');
      await tester.tap(find.text('Get started'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(HomePage), findsOneWidget);
      expect(find.textContaining(', Ade'), findsOneWidget);

      // Electrical: filter, favourite, and back to home.
      await tester.tap(find.text('ELEC'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(TradePage), findsOneWidget);
      expect(find.textContaining('16 tools'), findsOneWidget);

      await tester.tap(find.text('Protection'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Earthing Calculator'), findsOneWidget);
      expect(find.text('Voltage Drop'), findsNothing);

      await tester.tap(find.byIcon(Icons.star_border_rounded).first);
      await tester.pump();
      final favs = (await SharedPreferences.getInstance()).getStringList(
        'favourite_tools',
      );
      expect(favs, ['elec_breaker']);

      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.textContaining(', Ade'), findsOneWidget);

      await tester.tap(find.text('CIVIL'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('18 tools coming soon'), findsOneWidget);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('user_email'), 'ade@aoj.com');
    },
  );
}
