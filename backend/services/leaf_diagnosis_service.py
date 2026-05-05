"""
Combined leaf diagnosis service.

This service reuses the existing nutrition inference pipeline and a shared
disease inference helper so one uploaded corn leaf image can be evaluated by
both models before a final diagnosis is chosen.
"""

from __future__ import annotations

import logging

import numpy as np
import tensorflow as tf

from services.nutrition_service import NOT_CORN_THRESHOLD, run_nutrition_diagnosis
from utils.disease_model import (
    DISEASE_CLASS_NAMES,
    get_disease_load_error,
    get_disease_model,
    preprocess_disease_image,
)
from utils.fertilizer_recommendations import get_fertilizer_recommendations

logger = logging.getLogger(__name__)

DISEASE_CONFIDENCE_THRESHOLD: float = 0.50
HEALTHY_ACCEPTABLE_CONFIDENCE: float = 0.55
CONFIDENCE_MARGIN: float = 0.15
LOW_CONFIDENCE_THRESHOLD: float = 0.35

DISEASE_MODEL_VERSION: str = "disease_model_tflite_v1"


def normalize_confidence(value) -> float:
    """
    Normalize confidence value to 0.0-1.0 range.
    
    If value > 1, assume it's a percentage (0-100) and divide by 100.
    Otherwise, return as-is.
    """
    try:
        num_value = float(value)
        return num_value / 100.0 if num_value > 1 else num_value
    except (TypeError, ValueError):
        return 0.0


def predict_disease_from_bytes(file_bytes: bytes) -> dict:
    """Run the disease model on raw image bytes and return a normalised result."""
    model = get_disease_model()
    if model is None:
        reason = get_disease_load_error() or "Disease model file may be missing or failed to load."
        logger.error("[leaf-diagnosis] Disease model unavailable: %s", reason)
        raise RuntimeError(reason)

    processed = preprocess_disease_image(file_bytes)
    logger.info(
        "[leaf-diagnosis] disease image preprocessed shape=%s dtype=%s range=[%.3f, %.3f]",
        processed.shape,
        processed.dtype,
        float(np.min(processed)),
        float(np.max(processed)),
    )

    input_details = model.get_input_details()
    output_details = model.get_output_details()
    model.set_tensor(input_details[0]["index"], processed)
    model.invoke()
    preds = model.get_tensor(output_details[0]["index"])

    pred_sum = float(np.sum(preds))
    if pred_sum < 0.99 or pred_sum > 1.01:
        logger.info("[leaf-diagnosis] disease output looked like logits; applying softmax")
        preds = tf.nn.softmax(preds, axis=-1).numpy()

    confidence = float(np.max(preds))
    class_id = int(np.argmax(preds))
    label = DISEASE_CLASS_NAMES[class_id]

    all_probabilities = {
        DISEASE_CLASS_NAMES[i]: round(float(preds[0][i]), 4)
        for i in range(len(DISEASE_CLASS_NAMES))
    }

    result = {
        "status": "success" if confidence >= DISEASE_CONFIDENCE_THRESHOLD else "uncertain",
        "predicted_class": label,
        "confidence": round(confidence, 4),
        "all_probabilities": all_probabilities,
        "model_version": DISEASE_MODEL_VERSION,
    }

    if confidence < DISEASE_CONFIDENCE_THRESHOLD:
        result["message"] = (
            "Could not confidently identify a disease symptom. Please upload a clear corn leaf image."
        )

    return result


def _healthy_response(nutrition_result: dict, disease_result: dict) -> dict:
    confidence = round(
        min(float(nutrition_result["confidence"]), float(disease_result["confidence"])),
        4,
    )
    return {
        "final_diagnosis_type": "healthy",
        "final_prediction": "Healthy",
        "confidence": confidence,
        "message": "Both models indicate the leaf is healthy with acceptable confidence.",
        "secondary_possibility": None,
        "nutrition_result": nutrition_result,
        "disease_result": disease_result,
        "model_versions": {
            "nutrition": nutrition_result.get("model_version"),
            "disease": disease_result.get("model_version"),
        },
    }


def _invalid_image_response(nutrition_result: dict, disease_result: dict) -> dict:
    return {
        "final_diagnosis_type": "invalid_image",
        "final_prediction": nutrition_result.get("predicted_class", "Not_Corn"),
        "confidence": round(float(nutrition_result["confidence"]), 4),
        "message": nutrition_result.get(
            "message",
            "The uploaded image does not appear to be a corn leaf.",
        ),
        "secondary_possibility": None,
        "nutrition_result": nutrition_result,
        "disease_result": disease_result,
        "model_versions": {
            "nutrition": nutrition_result.get("model_version"),
            "disease": disease_result.get("model_version"),
        },
    }


def _uncertain_response(nutrition_result: dict, disease_result: dict) -> dict:
    nutrition_label = nutrition_result.get("predicted_class")
    disease_label = disease_result.get("predicted_class")
    nutrition_conf = float(nutrition_result["confidence"])
    disease_conf = float(disease_result["confidence"])

    return {
        "final_diagnosis_type": "uncertain",
        "final_prediction": nutrition_label if nutrition_conf >= disease_conf else disease_label,
        "confidence": round(max(nutrition_conf, disease_conf), 4),
        "message": "The two models produced similar confidence scores. Please review both possibilities.",
        "secondary_possibility": None,
        "possible_diagnoses": [
            {
                "source": "nutrition",
                "prediction": nutrition_label,
                "confidence": round(nutrition_conf, 4),
            },
            {
                "source": "disease",
                "prediction": disease_label,
                "confidence": round(disease_conf, 4),
            },
        ],
        "nutrition_result": nutrition_result,
        "disease_result": disease_result,
        "model_versions": {
            "nutrition": nutrition_result.get("model_version"),
            "disease": disease_result.get("model_version"),
        },
    }


def analyze_leaf_diagnosis(file_bytes: bytes) -> dict:
    """
    Run both models on the same image bytes and return a final diagnosis.
    
    Decision logic:
    1. If nutrition model predicts "Not_Corn" with high confidence → invalid_image
    2. If both models predict "Healthy" → healthy
    3. Compare normalized confidence values:
       - If nutrition confidence > disease confidence → nutrient_deficiency
       - If disease confidence > nutrition confidence → disease
       - If very close (within 0.05) → uncertain
    """
    nutrition_result = run_nutrition_diagnosis(file_bytes)
    disease_result = predict_disease_from_bytes(file_bytes)

    nutrition_label = nutrition_result.get("predicted_class")
    nutrition_conf_raw = float(nutrition_result["confidence"])
    nutrition_conf = normalize_confidence(nutrition_conf_raw)
    
    disease_label = disease_result.get("predicted_class")
    disease_conf_raw = float(disease_result["confidence"])
    disease_conf = normalize_confidence(disease_conf_raw)

    logger.info(
        "[leaf-diagnosis] nutrition: %s (%.4f) vs disease: %s (%.4f)",
        nutrition_label,
        nutrition_conf,
        disease_label,
        disease_conf,
    )

    # Rule 1: Check for invalid image (not a corn leaf)
    if nutrition_label == "Not_Corn" and nutrition_conf >= NOT_CORN_THRESHOLD:
        logger.info("[leaf-diagnosis] Returning invalid_image: Not_Corn detected with confidence %.4f", nutrition_conf)
        return _invalid_image_response(nutrition_result, disease_result)

    # Rule 2: Check if both models predict healthy
    if (
        nutrition_label == "Healthy"
        and disease_label == "Healthy"
        and nutrition_conf >= HEALTHY_ACCEPTABLE_CONFIDENCE
        and disease_conf >= HEALTHY_ACCEPTABLE_CONFIDENCE
    ):
        logger.info("[leaf-diagnosis] Returning healthy: both models confident")
        return _healthy_response(nutrition_result, disease_result)

    # Rule 3-5: Compare confidence scores directly
    confidence_diff = abs(nutrition_conf - disease_conf)
    very_close_threshold = 0.05  # Within 5 percentage points

    if confidence_diff <= very_close_threshold:
        # Confidence values are very close → uncertain
        logger.info(
            "[leaf-diagnosis] Returning uncertain: confidence values very close (diff=%.4f)",
            confidence_diff,
        )
        return _uncertain_response(nutrition_result, disease_result)

    if nutrition_conf > disease_conf:
        # Nutrient deficiency has higher confidence
        logger.info(
            "[leaf-diagnosis] Returning nutrient_deficiency: nutrition confidence (%.4f) > disease (%.4f)",
            nutrition_conf,
            disease_conf,
        )
        fertilizer_recommendations = get_fertilizer_recommendations(nutrition_label)
        return {
            "final_diagnosis_type": "nutrient_deficiency",
            "final_prediction": nutrition_label,
            "confidence": round(nutrition_conf, 4),
            "message": f"The nutrient deficiency model showed the higher confidence ({nutrition_conf:.1%}), "
                       f"so this image is classified as a nutrient deficiency.",
            "secondary_possibility": "disease",
            "nutrition_result": nutrition_result,
            "disease_result": disease_result,
            "fertilizer_recommendations": fertilizer_recommendations,
            "model_versions": {
                "nutrition": nutrition_result.get("model_version"),
                "disease": disease_result.get("model_version"),
            },
        }

    else:
        # Disease has higher confidence
        logger.info(
            "[leaf-diagnosis] Returning disease: disease confidence (%.4f) > nutrition (%.4f)",
            disease_conf,
            nutrition_conf,
        )
        return {
            "final_diagnosis_type": "disease",
            "final_prediction": disease_label,
            "confidence": round(disease_conf, 4),
            "message": f"The disease detection model showed the higher confidence ({disease_conf:.1%}), "
                       f"so this image is classified as a disease.",
            "secondary_possibility": "nutrient_deficiency",
            "nutrition_result": nutrition_result,
            "disease_result": disease_result,
            "model_versions": {
                "nutrition": nutrition_result.get("model_version"),
                "disease": disease_result.get("model_version"),
            },
        }


