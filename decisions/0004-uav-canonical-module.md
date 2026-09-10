# ADR-004: `src/phase5_uav` is the only UAV implementation

## Status
Accepted

## Date
2026-09-10

## Context
The UAV code exists in three places:
- `uav/` at the repo root: a stale copy; `heatmap.py` and `patch_runner.py` have drifted.
- `src/phase5_uav/`: the version tests and notebooks import.
- `deployment/uav/`: five-line shims re-exporting `src.phase5_uav`.

The README documents `deployment/uav` as the real code and never mentions `src/phase5_uav`.

## Decision
- `src/phase5_uav/` is canonical.
- Delete the root `uav/` once a diff confirms it holds nothing unique.
- Keep the `deployment/uav/` shims for one cycle, emitting `DeprecationWarning`, then remove them.
- Docs and scripts use `python -m src.phase5_uav.<module>`.

## Alternatives Considered

### Make `deployment/uav` canonical
- Pros: matches the current README commands.
- Cons: tests and notebooks already import `src.phase5_uav`, and `src/` holds every other phase.
- Rejected: `src/phase5_uav` is consistent with Phases 1–4.

## Consequences
- One place to fix bugs (T38–T40).
- `run_all.sh`, the README and notebook 5 must switch to the `src.phase5_uav` module paths (T37).
