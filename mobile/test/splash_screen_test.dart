import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maizeguard/design_system/components/brand_logo.dart';
import 'package:maizeguard/screens/splash_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SplashScreen Tests', () {
    testWidgets('SplashScreen renders centered pulsing logo container and brand identity cleanly', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: SplashScreen(),
          ),
        ),
      );

      // Verify presence of brand logo and root screen
      expect(find.byType(SplashScreen), findsOneWidget);
      expect(find.byType(MaizeGuardLogo), findsOneWidget);

      // Advance entrance animation partially
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byType(MaizeGuardLogo), findsOneWidget);

      // Verify brand title and agtech tagline
      expect(find.text('MaizeGuard'), findsOneWidget);
      expect(find.text('AI CROP DIAGNOSTICS & HEALTH'), findsOneWidget);

      // Verify offline edge badge and model info
      expect(find.text('ON-DEVICE NEURAL INFERENCE'), findsOneWidget);
      expect(find.text('OFFLINE FIRST'), findsOneWidget);
      expect(find.text('v1.0.0 • MobileNetV3 Quantized'), findsOneWidget);

      // Advance animation further to allow background timers to settle
      await tester.pump(const Duration(seconds: 3));
    });
  });
}
