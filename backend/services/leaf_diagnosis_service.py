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
    """Run both models on the same image bytes and return a final diagnosis."""
    nutrition_result = run_nutrition_diagnosis(file_bytes)
    disease_result = predict_disease_from_bytes(file_bytes)

    nutrition_label = nutrition_result.get("predicted_class")
    nutrition_conf = float(nutrition_result["confidence"])
    disease_label = disease_result.get("predicted_class")
    disease_conf = float(disease_result["confidence"])

    if nutrition_label == "Not_Corn" and nutrition_conf >= NOT_CORN_THRESHOLD:
        return _invalid_image_response(nutrition_result, disease_result)

    if (
        nutrition_label == "Healthy"
        and disease_label == "Healthy"
        and nutrition_conf >= HEALTHY_ACCEPTABLE_CONFIDENCE
        and disease_conf >= HEALTHY_ACCEPTABLE_CONFIDENCE
    ):
        return _healthy_response(nutrition_result, disease_result)

    confidence_gap = abs(nutrition_conf - disease_conf)
    if (
        nutrition_conf < LOW_CONFIDENCE_THRESHOLD
        and disease_conf < LOW_CONFIDENCE_THRESHOLD
    ) or confidence_gap <= CONFIDENCE_MARGIN:
        return _uncertain_response(nutrition_result, disease_result)

    if disease_conf >= nutrition_conf + CONFIDENCE_MARGIN and disease_label != "Healthy":
        return {
            "final_diagnosis_type": "disease",
            "final_prediction": disease_label,
            "confidence": round(disease_conf, 4),
            "message": "The symptoms are more likely related to a disease.",
            "nutrition_result": nutrition_result,
            "disease_result": disease_result,
            "model_versions": {
                "nutrition": nutrition_result.get("model_version"),
                "disease": disease_result.get("model_version"),
            },
        }

    if nutrition_conf >= disease_conf + CONFIDENCE_MARGIN and nutrition_label not in {"Healthy", "Not_Corn"}:
        fertilizer_recommendations = get_fertilizer_recommendations(nutrition_label)
        return {
            "final_diagnosis_type": "nutrient_deficiency",
            "final_prediction": nutrition_label,
            "confidence": round(nutrition_conf, 4),
            "message": "The symptoms are more likely related to a nutrient deficiency.",
            "nutrition_result": nutrition_result,
            "disease_result": disease_result,
            "fertilizer_recommendations": fertilizer_recommendations,
            "model_versions": {
                "nutrition": nutrition_result.get("model_version"),
                "disease": disease_result.get("model_version"),
            },
        }

    return _uncertain_response(nutrition_result, disease_result)
