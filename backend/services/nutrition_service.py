"""
Nutrition service – orchestrates TF image inference and recommendation lookup.
All business logic lives here; the route layer only handles HTTP concerns.

Multi-condition support:
  The response always includes top_3 predictions so the Flutter UI (and
  researchers) can interpret co-occurring deficiencies – addressing the
  panel comment "consider multiple detection at a single time" without
  retraining the model.

Not_Corn guard:
  If the primary prediction is Not_Corn AND its probability >= NOT_CORN_THRESHOLD
  the response short-circuits with a user-friendly message.  The top_3 is still
  included for transparency / research logging.
"""

from __future__ import annotations

import logging

from utils.fertilizer_recommendations import get_fertilizer_recommendations
from utils.inference import get_model, predict_nutrient_status

logger = logging.getLogger(__name__)

# Probability threshold above which a Not_Corn prediction triggers the guard.
NOT_CORN_THRESHOLD: float = 0.70


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

    # predict_nutrient_status raises ValueError on bad image / RuntimeError on missing model
    result = predict_nutrient_status(file_bytes)

    label        = result["label"]
    confidence   = result["confidence"]
    top_3        = result["top_3"]
    all_probs    = result["all_probabilities"]
    infer_ms     = result["inference_time_ms"]
    model_ver    = result["model_version"]

    logger.info(
        "Nutrition diagnosis complete  label=%s  confidence=%.2f%%  inference_ms=%.1f",
        label, confidence * 100, infer_ms,
    )

    # ── Not_Corn guard ────────────────────────────────────────────────────────
    if label == "Not_Corn" and confidence >= NOT_CORN_THRESHOLD:
        return {
            "status": "not_corn",
            "predicted_class": label,
            "confidence": confidence,
            "is_corn": False,
            "message": (
                "Please upload a corn leaf image. "
                "The uploaded image does not appear to be a corn plant."
            ),
            "message_si": (
                "කරුණාකර බඩ ඉරු කොළයක් අපලෝඩ් කරන්න. "
                "මෙම රූපය බඩ ඉරු පැලක් නොවේ."
            ),
            "message_ta": (
                "சோள இலை படத்தை பதிவேற்றவும். "
                "இந்த படம் சோள செடி அல்ல."
            ),
            "top_3": top_3,
            "all_probabilities": all_probs,
            "fertilizer_recommendations": None,
            "inference_time_ms": infer_ms,
            "model_version": model_ver,
        }

    # ── Normal prediction ─────────────────────────────────────────────────────
    return {
        "status": "success",
        "predicted_class": label,
        "confidence": confidence,
        "is_corn": label != "Not_Corn",
        "top_3": top_3,
        "all_probabilities": all_probs,
        "fertilizer_recommendations": get_fertilizer_recommendations(label),
        "inference_time_ms": infer_ms,
        "model_version": model_ver,
    }
