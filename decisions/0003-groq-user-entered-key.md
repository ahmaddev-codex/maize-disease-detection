# ADR-003: Groq as the only cloud AI provider, with user-entered keys

## Status
Accepted

## Date
2026-09-10

## Context
The app calls Groq (`openai/gpt-oss-120b` plus fallbacks) for agronomic advice and YarnGPT for Yoruba, Igbo and Hausa speech. The research papers describe a Gemini → Groq → Ollama chain that is not in the code.

Keys come from `--dart-define-from-file=.env.json`. Values injected that way are compiled into the app binary and can be recovered from the APK or IPA, contrary to the papers' claim that they "cannot be extracted". The app also re-writes the compiled-in key into secure storage on every launch, so "Remove key" does not stick, and it reads `.env.json` from a hard-coded developer path.

## Decision
- **Provider:** Groq is the only cloud provider for advice. When no key is set or the request fails, the app uses on-device offline guidance, clearly labelled as offline.
- **No embedded keys:** release builds ship no Groq or YarnGPT key. Users enter keys in Settings, and they are stored in `flutter_secure_storage`.
- **Debug builds:** may still seed a key from `.env.json` once, for local development. A key the user removes stays removed.

## Alternatives Considered

### Embed a demo key
- Pros: works out of the box.
- Cons: anyone can extract it and spend against the account.
- Rejected: secrets must not ship in client binaries.

### Backend proxy holding the key
- Pros: most secure, and allows rate limiting.
- Cons: a hosted service to build, secure and pay for.
- Deferred: revisit for a public release beyond research demos.

## Consequences
- First-run AI advice requires a key or an internet connection; offline guidance must be good enough on its own (T25, T27).
- The papers must correct the key-security statement and the provider chain (T44).
- A release check verifies no `gsk_` string exists in the APK (T28, T49).
