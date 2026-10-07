#!/usr/bin/env bash
# Fails when the repository re-acquires a claim it cannot support, or a stale
# platform reference. Run locally or in CI:  bash scripts/check_claims.sh
set -uo pipefail

status=0

report() {           # report <label> <grep-output>
  if [ -n "$2" ]; then
    echo "FAIL: $1"
    echo "$2" | sed 's/^/    /'
    status=1
  else
    echo "ok:   $1"
  fi
}

# ── Claims the app cannot back (T29) ─────────────────────────────────────────
ui_claims='Offline Verified|Verified by MaizeGuard|Agronomist Verification|works fully offline|Field Validation|Optimized for direct sunlight|verified agronomic'
report "no overclaiming copy in mobile/lib" \
  "$(grep -rniE "$ui_claims" mobile/lib --include='*.dart' || true)"

# ── Numbers no artifact supports (T43) ───────────────────────────────────────
# 95.8 / +5.8: a fusion accuracy gain measured on synthetic metadata (ADR-002).
# 89.2: an INT8 accuracy that no evaluation produced.
# 850 ms: a device latency nobody has measured (T12).
stale_numbers='95\.8|\+5\.8|89\.2%|850 ?ms'
report "no unsupported figures in research-papers" \
  "$(grep -rnE "$stale_numbers" research-papers/*.md || true)"

# ── Components the project does not use (T44, T45, T46) ──────────────────────
stale_platform='Gemini|Ollama|llama-3\.3|React Native|deployment/app|24-d'
report "no stale platform references in the live docs" \
  "$(grep -rnE "$stale_platform" README.md SYSTEM.md REQUIREMENTS.md DIAGRAMS.md research-papers/*.md mobile/README.md 2>/dev/null \
      | grep -v 'never happened\|does not exist\|is inaccurate and is kept\|not dependencies of this project\|kept at .deployment/app\|The Flutter equivalents are listed' || true)"

# ── Secrets (ADR-003) ────────────────────────────────────────────────────────
# Groq keys start gsk_, Google keys AIza. Neither belongs in the tree.
# Tracked files only: a developer's own .env.json is gitignored and is theirs.
secrets="$(git ls-files -z | xargs -0 grep -nIE '(gsk_[A-Za-z0-9]{20,}|AIza[A-Za-z0-9_-]{30,})' 2>/dev/null \
  | grep -v 'scripts/check_claims.sh' || true)"
report "no API keys committed" "$secrets"

# ── Class names defined in one place (ADR-006) ───────────────────────────────
report "class names defined only in src/common" \
  "$(grep -rn '^CLASS_NAMES *=' src --include='*.py' | grep -v 'src/common/' | grep -v 'phase5_uav' || true)"

exit $status
