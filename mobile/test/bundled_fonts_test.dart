import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:maizeguard/design_system/tokens/app_typography.dart';

/// T57: the app must never fetch fonts over the network. On a phone without
/// internet google_fonts threw unhandled exceptions for every DM Sans weight.
void main() {
  test('every DM Sans weight the design system uses is bundled as an asset', () {
    const weightFiles = [
      'DMSans-Regular.ttf',   // w400
      'DMSans-Medium.ttf',    // w500
      'DMSans-SemiBold.ttf',  // w600
      'DMSans-Bold.ttf',      // w700
      'DMSans-ExtraBold.ttf', // w800
    ];

    final missing = weightFiles.where((f) => !File('google_fonts/$f').existsSync()).toList();
    expect(missing, isEmpty, reason: 'not bundled: $missing');
    expect(File('google_fonts/OFL.txt').existsSync(), isTrue, reason: 'font licence must ship');
  });

  test('configureBundledFonts turns off runtime font fetching', () {
    GoogleFonts.config.allowRuntimeFetching = true;

    AppTypography.configureBundledFonts();

    expect(GoogleFonts.config.allowRuntimeFetching, isFalse);
  });

  testWidgets('text renders with bundled fonts and no runtime fetch', (tester) async {
    AppTypography.configureBundledFonts();

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: Text('SAMMAZ 15', style: AppTypography.h2)),
    ));

    expect(tester.takeException(), isNull);
  });
}
