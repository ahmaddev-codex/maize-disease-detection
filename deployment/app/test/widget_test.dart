import 'package:flutter_test/flutter_test.dart';
import 'package:maize_disease_detector/main.dart';

void main() {
  testWidgets('App renders without crash', (WidgetTester tester) async {
    await tester.pumpWidget(const MaizeApp());
    expect(find.byType(MaizeApp), findsOneWidget);
  });
}
