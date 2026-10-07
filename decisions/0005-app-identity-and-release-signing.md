# ADR-005: One app identity and real release signing

## Status
Accepted (app ID taken from the existing iOS bundle identifier; amend here if a different ID is wanted)

## Date
2026-09-10

## Context
- Android `applicationId` and `namespace` are `com.example.maizeguard`, which Google Play rejects.
- The iOS Runner uses `com.ahmaddev.maizeguard`; the iOS test target still uses `com.example.maizeguard.RunnerTests`.
- The map's tile user-agent uses a third ID, `com.maizeguard.app`.
- Android release builds are signed with the debug keystore.

## Decision
- Use `com.ahmaddev.maizeguard` on Android, iOS and as the OSM tile user-agent package name.
- Sign Android release builds with a keystore described in `android/key.properties`, which is gitignored and never committed. If it is missing, release builds fail instead of silently using debug keys.

## Alternatives Considered

### Keep `com.example.maizeguard` until publishing
- Pros: no reinstall for existing testers.
- Cons: stores reject it, and changing the ID later wipes installed data and secure storage anyway.
- Rejected: change it now, while only test installs exist.

## Consequences
- Existing Android test installs must be uninstalled once; scan history on those devices is lost.
- The `MainActivity` Kotlin package moves to match the new namespace (T04).
- Whoever builds releases keeps the keystore and its passwords outside the repo.
