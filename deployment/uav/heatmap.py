"""Deprecated import path. The UAV modules live in `src.phase5_uav` (ADR-004).

Kept so existing commands and notebooks keep working; it re-exports the
canonical module and warns once.
"""
import warnings

from src.phase5_uav.heatmap import *  # noqa: F401,F403
from src.phase5_uav.heatmap import main  # noqa: F401

warnings.warn(
    "deployment.uav.heatmap is deprecated; use src.phase5_uav.heatmap instead.",
    DeprecationWarning,
    stacklevel=2,
)

if __name__ == "__main__":
    main()
