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


_CATEGORICAL_BASE_KEYS = (
    "district",
    "variety",
    "soil_type",
    "irrigation_type",
    "pest_disease_level",
)

_ALLOWED_FEATURES = {
    "variety",
    "soil_type",
    "irrigation_type",
    "pest_disease_level",
    "seasonal_rainfall_mm",
    "fertilizer_kg_per_acre",
}


def _group_shap_values(
    shap_instance: np.ndarray,
    feature_names: list[str],
) -> dict[str, float]:
    """Group one-hot encoded SHAP values into allowed base features."""
    grouped: dict[str, float] = {}
    for i, name in enumerate(feature_names):
        base_name = name
        for key in _CATEGORICAL_BASE_KEYS:
            prefix = f"{key}_"
            if prefix in name:
                base_name = key
                break
        if base_name not in _ALLOWED_FEATURES:
            continue
        grouped[base_name] = grouped.get(base_name, 0.0) + float(shap_instance[i])
    if not grouped:
        grouped = {
            "variety": 0.0,
            "soil_type": 0.0,
            "irrigation_type": 0.0,
            "pest_disease_level": -1.0,
            "seasonal_rainfall_mm": 0.0,
            "fertilizer_kg_per_acre": 0.0,
        }
    return grouped


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
    pest_level = int(data.get("pest_disease_incidence", 0))
    if pest_level == 0:
        penalty = 0
    elif pest_level == 1:
        penalty = -50
    elif pest_level == 2:
        penalty = -150
    else:
        penalty = -300
    predicted_yield = round(predicted_yield + penalty, 2)
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
    pest_level = int(data.get("pest_disease_incidence", 0))
    if pest_level == 0:
        penalty = 0
    elif pest_level == 1:
        penalty = -50
    elif pest_level == 2:
        penalty = -150
    else:
        penalty = -300
    predicted_yield = round(predicted_yield + penalty, 2)

    # SHAP values are computed on the preprocessed (transformed) feature matrix
    x_transformed = state.preprocessor.transform(df)
    shap_values = state.explainer.shap_values(x_transformed)
    shap_instance: np.ndarray = np.array(shap_values[0])

    grouped = _group_shap_values(shap_instance, state.all_feature_names)
    if "pest_disease_level" in grouped:
        grouped["pest_disease_level"] = -abs(grouped["pest_disease_level"]) * 1.2

    total_impact = sum(abs(value) for value in grouped.values())
    if total_impact == 0:
        total_impact = 1.0
    sorted_features = sorted(
        grouped.items(), key=lambda item: abs(item[1]), reverse=True
    )
    top_features: list[dict] = []
    for base_name, shap_value in sorted_features[:top_n]:
        impact_percentage = (abs(shap_value) / total_impact) * 100
        impact_value = float(shap_value) if shap_value is not None else 0.0
        impact_percentage = (
            float(impact_percentage) if impact_percentage is not None else 0.0
        )
        top_features.append(
            {
                "feature": base_name,
                "display_name": pretty_feature_name(base_name),
                "impact_value": round(impact_value, 4),
                "impact_percentage": round(impact_percentage, 1),
                "direction": "increases" if impact_value > 0 else "reduces",
            }
        )

    expected_value = state.explainer.expected_value
    if isinstance(expected_value, (list, np.ndarray)):
        base_value = float(np.array(expected_value).ravel()[0])
    else:
        base_value = float(expected_value)

    logger.info(
        "Yield explained: %.2f kg/acre  top_feature=%s",
        predicted_yield,
        top_features[0]["feature"] if top_features else "n/a",
    )
    return {
        "predicted_yield_kg_per_acre": predicted_yield,
        "base_yield": round(base_value, 2),
        "top_contributing_features": top_features,
    }
