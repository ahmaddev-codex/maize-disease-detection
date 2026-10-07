import 'package:flutter_test/flutter_test.dart';
import 'package:maizeguard/services/ai_advisor.dart';

void main() {
  group('AiAdvisor Text Sanitization Tests', () {
    test('strips markdown headers (###, ##, #) and asterisks (**)', () {
      const rawText = '''
### 1. DISEASE SUMMARY
**Northern Corn Leaf Blight** is a fungal infection caused by *Exserohilum turcicum*.

### 2. IMMEDIATE TREATMENT
* Apply **Mancozeb** at 2.5 kg/ha.
* Mix with **Ridomil Gold** if lesion progression is severe.

### 3. PREVENTION
* Plant resistant hybrid seeds.
''';

      final sanitized = AiAdvisor.sanitizeAiText(rawText);

      // Must not contain markdown header hashtags or asterisks
      expect(sanitized.contains('#'), isFalse);
      expect(sanitized.contains('**'), isFalse);
      expect(sanitized.contains('*'), isFalse);
      expect(sanitized, contains('1. DISEASE SUMMARY'));
      expect(sanitized, contains('Northern Corn Leaf Blight is a fungal infection'));
      expect(sanitized, contains('Apply Mancozeb at 2.5 kg/ha'));
      expect(sanitized, contains('Mix with Ridomil Gold if lesion progression is severe'));
    });

    test('strips markdown tables and pipes', () {
      const tableText = '''
| Step | Action | Product |
|---|---|---|
| 1 | Spray | Mancozeb |
| 2 | Inspect | Field |
''';

      final sanitized = AiAdvisor.sanitizeAiText(tableText);
      expect(sanitized.contains('|'), isFalse);
      expect(sanitized, contains('Mancozeb'));
      expect(sanitized, contains('Inspect'));
    });

    test('removes backticks and excessive blank lines', () {
      const codeText = '''
Advisory:

`Mancozeb 80 WP` is recommended.



Re-inspect field in 5 days.
''';

      final sanitized = AiAdvisor.sanitizeAiText(codeText);
      expect(sanitized.contains('`'), isFalse);
      expect(sanitized.contains('\n\n\n'), isFalse);
      expect(sanitized, contains('Mancozeb 80 WP is recommended'));
      expect(sanitized, contains('Re-inspect field in 5 days'));
    });
  });
}
