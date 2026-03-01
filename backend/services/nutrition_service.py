"""
Nutrition service – orchestrates TF image inference and recommendation lookup.
All business logic lives here; the route layer only handles HTTP concerns.
"""

from __future__ import annotations

import logging

from utils.fertilizer_recommendations import get_fertilizer_recommendations
from utils.inference import get_model, predict_nutrient_status

logger = logging.getLogger(__name__)


def run_nutrition_diagnosis(file_bytes: bytes) -> dict:
    """
    Run nutrient / disease diagnosis on raw image bytes.

    Returns a structured dict ready to be JSON-serialised by the route handler.

    Raises:
        RuntimeError: TF model is not loaded (route converts to HTTP 503).
        ValueError:   Image could not be decoded (route converts to HTTP 422).
    """
    if get_model() is None:
        raise RuntimeError("TF model is not available.")

    # predict_nutrient_status raises ValueError on bad image data
    label, confidence, probs = predict_nutrient_status(file_bytes)
    logger.info(
        "Nutrition diagnosis complete  label=%s  confidence=%.2f%%",
        label,
        confidence * 100,
    )

    if label == "Not_Corn":
        return {
            "predicted_class": label,
            "confidence": round(confidence, 4),
            "probabilities": probs,
            "is_corn": False,
            "message": (
                "This image does not appear to be a corn plant. "
                "Please upload a corn leaf image."
            ),
            "message_si": (
                "මෙම රූපය බඩ ඉරු පැලක් නොවේ. "
                "කරුණාකර බඩ ඉරු කොළයක් අපලෝඩ් කරන්න."
            ),
            "fertilizer_recommendations": None,
        }

    return {
        "predicted_class": label,
        "confidence": round(confidence, 4),
        "probabilities": probs,
        "is_corn": True,
        "fertilizer_recommendations": get_fertilizer_recommendations(label),
    }
