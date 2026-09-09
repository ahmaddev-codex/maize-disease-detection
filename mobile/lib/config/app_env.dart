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

  // ── YarnGPT (Nigerian-language TTS: Hausa, Yoruba, Igbo, Pidgin) ────────
  static const yarnGptApiKey = String.fromEnvironment('YARNGPT_API_KEY');
}
