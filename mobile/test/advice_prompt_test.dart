import 'package:flutter_test/flutter_test.dart';
import 'package:maizeguard/constants/diseases.dart';
import 'package:maizeguard/l10n/voice_scripts.dart';
import 'package:maizeguard/providers/app_provider.dart' show DisplayLanguage;
import 'package:maizeguard/services/advice_prompt.dart';

/// T25: one prompt asked for "three treatment steps with dosage" for every
/// class — healthy leaves included — and named Ridomil Gold (metalaxyl, for
/// oomycetes) and Funguran (copper) for fungal diseases they do not control.
void main() {
  // Products that must never be recommended for these four classes.
  const wrongProducts = ['ridomil', 'funguran'];

  bool mentionsAny(String text, List<String> needles) {
    final lower = text.toLowerCase();
    return needles.any(lower.contains);
  }

  group('prompt mode', () {
    test('a healthy leaf is monitoring advice, never a spray plan', () {
      final prompt = buildAdvicePrompt(classId: kHealthyClassId, confidence: 0.96);

      expect(adviceModeFor(classId: kHealthyClassId, confidence: 0.96), AdviceMode.healthy);
      expect(mentionsAny(prompt, ['dosage', 'fungicide brand', 'spray schedule']), isFalse);
      expect(prompt.toLowerCase(), contains('no fungicide'));
      expect(mentionsAny(prompt, wrongProducts), isFalse);
    });

    test('a low-confidence result asks for a better photo, not a treatment', () {
      final prompt = buildAdvicePrompt(classId: 0, confidence: 0.42);

      expect(adviceModeFor(classId: 0, confidence: 0.42), AdviceMode.uncertain);
      expect(prompt.toLowerCase(), isNot(contains('immediate treatment')));
      expect(mentionsAny(prompt, ['fungicide', 'dosage']), isFalse);
      expect(prompt.toLowerCase(), anyOf(contains('retake'), contains('verify')));
    });

    test('a confident rust diagnosis names the right chemistry and no brands', () {
      final prompt = buildAdvicePrompt(classId: 1, confidence: 0.93, cropVariety: 'SAMMAZ 15');

      expect(adviceModeFor(classId: 1, confidence: 0.93), AdviceMode.disease);
      expect(prompt.toLowerCase(), contains('triazole'));
      expect(mentionsAny(prompt, wrongProducts), isFalse);
      expect(prompt, contains('SAMMAZ 15'));
      // Dosage belongs on the product label, not in a language model's output.
      expect(prompt.toLowerCase(), contains('label'));
      expect(prompt.toLowerCase(), contains('extension'));
      expect(prompt.toLowerCase(), isNot(contains('invent')));
      expect(prompt, isNot(matches(RegExp(r'\d+\s?(ml|g)\s?(per|/)\s?(litre|l|ha)', caseSensitive: false))));
    });

    test('no prompt for any class names a product that cannot control it', () {
      for (final disease in kDiseases) {
        for (final confidence in [0.95, 0.5]) {
          final prompt = buildAdvicePrompt(classId: disease.classId, confidence: confidence);
          expect(mentionsAny(prompt, wrongProducts), isFalse,
              reason: 'class ${disease.classId} at $confidence still names a wrong product');
        }
      }
    });

    test('a non-English request asks for that language and keeps actives in English', () {
      final prompt = buildAdvicePrompt(classId: 2, confidence: 0.9, language: 'Hausa');
      expect(prompt, contains('Hausa'));
      expect(prompt.toLowerCase(), contains('strobilurin'));
    });
  });

  group('the actives table', () {
    test('every disease lists active ingredients, and healthy lists none', () {
      for (final disease in kDiseases) {
        if (disease.classId == kHealthyClassId) {
          expect(disease.actives, isEmpty);
        } else {
          expect(disease.actives, isNotEmpty, reason: '${disease.name} has no actives');
        }
      }
      expect(diseaseForClass(1).actives.join(' ').toLowerCase(), contains('triazole'));
      expect(diseaseForClass(2).actives.join(' ').toLowerCase(), contains('strobilurin'));
    });

    test('carries its review status and sources, and claims no sign-off it does not have', () {
      expect(kActivesReview.sources, isNotEmpty);
      expect(kActivesReview.updated, isNotEmpty);
      if (kActivesReview.isSignedOff) {
        expect(kActivesReview.reviewer, isNotEmpty);
      } else {
        expect(kActivesReview.reviewer, isNull);
        expect(kActivesReview.status, 'pending-agronomist-review');
      }
    });
  });

  group('voice scripts', () {
    test('every language names the same chemistry for rust', () {
      final rust = diseaseForClass(1);
      for (final lang in DisplayLanguage.values) {
        final script = treatmentScript(lang, rust, isLowConfidence: false);
        expect(script.toLowerCase(), contains('triazole'),
            reason: '${lang.name} script does not name the active ingredient');
        expect(mentionsAny(script, wrongProducts), isFalse,
            reason: '${lang.name} script still names a wrong product');
      }
    });

    test('healthy plants are never told to spray, in any language', () {
      final healthy = diseaseForClass(kHealthyClassId);
      for (final lang in DisplayLanguage.values) {
        final script = treatmentScript(lang, healthy, isLowConfidence: false);
        expect(mentionsAny(script, ['triazole', 'strobilurin', 'mancozeb', ...wrongProducts]), isFalse,
            reason: '${lang.name} healthy script mentions a chemical');
      }
    });

    test('a low-confidence scan asks for another photo instead of a treatment', () {
      final nclb = diseaseForClass(0);
      for (final lang in DisplayLanguage.values) {
        final script = treatmentScript(lang, nclb, isLowConfidence: true);
        expect(mentionsAny(script, ['triazole', 'strobilurin', 'mancozeb', ...wrongProducts]), isFalse,
            reason: '${lang.name} low-confidence script prescribes chemistry');
      }
    });
  });
}
