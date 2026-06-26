import 'package:flutter/foundation.dart';

/// Compile-time environment configuration.
///
/// Values are injected via:
///   flutter run  --dart-define-from-file=.env.json
///   flutter build ... --dart-define-from-file=.env.json
///
/// Copy .env.json.example → .env.json and fill in your values.
abstract final class AppEnv {
  // ── Ollama (development) ────────────────────────────────────────────────
  static const ollamaHost = String.fromEnvironment(
    'OLLAMA_HOST',
    defaultValue: 'http://localhost:11434',
  );

  static const ollamaModel = String.fromEnvironment(
    'OLLAMA_MODEL',
    defaultValue: 'llama3.1:8b',
  );

  // ── Gemini (production) ─────────────────────────────────────────────────
  // Optional: supply at build time for CI / staging.
  // End-users enter their key in Settings → it is stored in FlutterSecureStorage.
  static const geminiApiKey = String.fromEnvironment('GEMINI_API_KEY');

  // ── Backend selector ────────────────────────────────────────────────────
  // debug build  →  Ollama (local, no key required)
  // release build →  Gemini (API key from env or user settings)
  static bool get useOllama => kDebugMode;
}
