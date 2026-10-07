import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maizeguard/design_system/components/brand_logo.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MaizeGuard Brand Components Tests', () {
    testWidgets('MaizeGuardLogo renders in light and dark mode without error', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                MaizeGuardLogo(size: 32, isDark: false),
                MaizeGuardLogo(size: 48, isDark: true),
              ],
            ),
          ),
        ),
      );

      expect(find.byType(MaizeGuardLogo), findsNWidgets(2));
    });

    testWidgets('MaizeGuardWordmark renders in light and dark mode without error', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                MaizeGuardWordmark(height: 24, isDark: false),
                MaizeGuardWordmark(height: 28, isDark: true),
              ],
            ),
          ),
        ),
      );

      expect(find.byType(MaizeGuardWordmark), findsNWidgets(2));
    });

    testWidgets('MaizeGuardBrandCard renders brand assets and metadata cleanly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MaizeGuardBrandCard(),
          ),
        ),
      );

      expect(find.byType(MaizeGuardBrandCard), findsOneWidget);
      expect(find.byType(MaizeGuardWordmark), findsOneWidget);
      expect(find.text('Clinical'), findsOneWidget);
      expect(find.textContaining('v1.0.0'), findsOneWidget);
    });
  });
}
