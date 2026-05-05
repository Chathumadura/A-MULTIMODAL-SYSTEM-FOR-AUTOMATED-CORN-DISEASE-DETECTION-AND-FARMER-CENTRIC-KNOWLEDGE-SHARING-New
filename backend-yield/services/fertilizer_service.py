"""
Fertilizer service – wraps the recommendation lookup table.
Keeping this in a service layer means the route handler stays thin and
the lookup logic can be extended (e.g., DB-backed) without touching routes.
"""

from __future__ import annotations

import logging

from utils.fertilizer_recommendations import (
    _RECOMMENDATIONS,
    get_fertilizer_recommendations,
)

logger = logging.getLogger(__name__)


def get_recommendations(label: str) -> dict | None:
    """
    Return the recommendation dict for `label`, or None if not recognised.

    Args:
        label: Predicted class name (e.g. 'Nitrogen_deficiency').

    Returns:
        Recommendation dict or None.
    """
    result = get_fertilizer_recommendations(label)
    if result is None:
        logger.warning("Unknown label requested: %s", label)
    return result


def list_supported_labels() -> list[str]:
    """Return all class labels that have recommendation entries."""
    return list(_RECOMMENDATIONS.keys())
