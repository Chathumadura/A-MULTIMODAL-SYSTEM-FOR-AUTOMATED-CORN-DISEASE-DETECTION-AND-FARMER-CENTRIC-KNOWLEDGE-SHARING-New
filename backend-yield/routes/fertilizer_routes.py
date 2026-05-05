"""
Fertilizer recommendation routes.

Prefix : /fertilizer
Endpoints:
  GET /fertilizer/recommendations/{label}  – look up recommendations for a class label
  GET /fertilizer/labels                   – list all supported class labels
"""

import logging

from fastapi import APIRouter, HTTPException

from services.fertilizer_service import get_recommendations, list_supported_labels

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/fertilizer", tags=["fertilizer recommendations"])


@router.get("/recommendations/{label}")
def fertilizer_recommendations(label: str) -> dict:
    """
    Return fertilizer recommendations for the given nutrient-deficiency label.

    Supported labels: Healthy | Nitrogen_deficiency |
                      Phosphorus_deficiency | Potassium_deficiency

    Errors:
    - 404  label not recognised
    """
    logger.info("GET /fertilizer/recommendations/%s", label)
    result = get_recommendations(label)
    if result is None:
        raise HTTPException(
            status_code=404,
            detail=(
                f"Label '{label}' not recognised. "
                f"Supported labels: {list_supported_labels()}"
            ),
        )
    return result


@router.get("/labels")
def fertilizer_labels() -> dict:
    """Return the list of all supported nutrient-deficiency class labels."""
    return {"supported_labels": list_supported_labels()}
