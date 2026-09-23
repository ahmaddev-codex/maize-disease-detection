/// Compile-time environment configuration.
///
/// Values are injected via:
///   flutter run  --dart-define-from-file=.env.json
///   flutter build ... --dart-define-from-file=.env.json
abstract final class AppEnv {
  // ── Groq (Sole Online AI Assistant Provider) ────────────────────────────
  // Flagship 120B parameter model on Groq: top-tier agronomic reasoning.
  static const defaultGroqModel = 'openai/gpt-oss-120b';

  static const groqApiKey = String.fromEnvironment('GROQ_API_KEY');
  static const groqModel = String.fromEnvironment(
    'GROQ_MODEL',
    defaultValue: defaultGroqModel,
  );

  /// Models the advisor may try, in order. Every id here must appear in Groq's
  /// served model list — `test/fixtures/groq_models.json` holds a recorded copy
  /// and the test fails when an id drifts out of it (T26).
  static const groqFallbackModels = <String>[
    'openai/gpt-oss-120b',
    'openai/gpt-oss-20b',
    'llama-3.3-70b-versatile',
  ];

  /// [groqModel] first, then the fallbacks, without repeats.
  static List<String> get groqModels =>
      <String>{groqModel, ...groqFallbackModels}.toList();

  // ── YarnGPT (Nigerian-language TTS: Hausa, Yoruba, Igbo, Pidgin) ────────
  static const yarnGptApiKey = String.fromEnvironment('YARNGPT_API_KEY');
}
