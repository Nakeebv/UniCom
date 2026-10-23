import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:unicom/features/onboarding/onboarding_screen.dart';

void main() {
  testWidgets('welcome page: no standalone A glyph; CTAs render', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: OnboardingScreen()));
    await tester.pump(const Duration(milliseconds: 50));

    // CTAs present and labelled correctly.
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('Sign up with Email'), findsOneWidget);

    // Headline present.
    expect(find.textContaining('Connect friends'), findsOneWidget);

    // The decorative glyph orbs (including the standalone "A") are gone.
    expect(find.text('A'), findsNothing);
    expect(find.text('文'), findsNothing);
    expect(find.text('あ'), findsNothing);

    // All five slideshow frames stay mounted (stacked crossfade design)
    // plus the brand emblem image.
    expect(find.byType(Image), findsNWidgets(6));

    // Slideshow advances: pump past the 10s slide period + fade.
    await tester.pump(const Duration(seconds: 10));
    await tester.pump(const Duration(milliseconds: 900));
    expect(tester.takeException(), isNull);
  });
}
