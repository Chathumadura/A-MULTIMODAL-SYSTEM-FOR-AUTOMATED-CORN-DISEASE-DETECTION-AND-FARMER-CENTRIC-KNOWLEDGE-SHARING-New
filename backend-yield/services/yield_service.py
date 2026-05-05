"""
Yield prediction service – orchestrates the sklearn pipeline and SHAP explainer.
All business logic lives here; the route layer only handles HTTP concerns.
"""

from __future__ import annotations

import logging

import numpy as np

from utils.yield_model import build_full_row, get_yield_state, pretty_feature_name

logger = logging.getLogger(__name__)


# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------
def _ensure_model():
    """Return the loaded YieldModelState, or raise RuntimeError if unavailable."""
    state = get_yield_state()
    if state is None:
        raise RuntimeError("Yield model is not available.")
    return state


def _top_shap_features(shap_instance: np.ndarray, all_feature_names: list[str], top_n: int = 5) -> list[dict]:
    """Return the top-N features by absolute SHAP value."""
    top_indices = np.argsort(np.abs(shap_instance))[::-1][:top_n]
    return [
        {
            "raw_name": all_feature_names[i],
            "display_name": pretty_feature_name(all_feature_names[i]),
            "shap_value": round(float(shap_instance[i]), 4),
        }
        for i in top_indices
    ]


# ---------------------------------------------------------------------------
# Public service functions
# ---------------------------------------------------------------------------
def predict_yield(data: dict) -> dict:
    """
    Predict corn yield (kg/acre) without SHAP explanation.

    Args:
        data: Dict matching SimpleYieldRequest fields.

    Returns:
        {"predicted_yield_kg_per_acre": float}

    Raises:
        RuntimeError: when the model is not loaded.
    """
    state = _ensure_model()
    df = build_full_row(data)
    predicted_yield = round(float(state.pipeline.predict(df)[0]), 2)
    logger.info("Yield predicted: %.2f kg/acre", predicted_yield)
    return {"predicted_yield_kg_per_acre": predicted_yield}


def explain_yield(data: dict, top_n: int = 5) -> dict:
    """
    Predict corn yield AND return top SHAP feature contributions.

    Args:
        data:  Dict matching SimpleYieldRequest fields.
        top_n: Number of top SHAP features to return (default 5).

    Returns:
        {
          "predicted_yield_kg_per_acre": float,
          "top_contributing_features": [{"raw_name", "display_name", "shap_value"}, ...]
        }

    Raises:
        RuntimeError: when the model is not loaded.
    """
    state = _ensure_model()
    df = build_full_row(data)

    predicted_yield = round(float(state.pipeline.predict(df)[0]), 2)

    # SHAP values are computed on the preprocessed (transformed) feature matrix
    x_transformed = state.preprocessor.transform(df)
    shap_values = state.explainer.shap_values(x_transformed)
    shap_instance: np.ndarray = np.array(shap_values[0])

    top_features = _top_shap_features(shap_instance, state.all_feature_names, top_n)

    logger.info(
        "Yield explained: %.2f kg/acre  top_feature=%s",
        predicted_yield,
        top_features[0]["raw_name"] if top_features else "n/a",
    )
    return {
        "predicted_yield_kg_per_acre": predicted_yield,
        "top_contributing_features": top_features,
    }
