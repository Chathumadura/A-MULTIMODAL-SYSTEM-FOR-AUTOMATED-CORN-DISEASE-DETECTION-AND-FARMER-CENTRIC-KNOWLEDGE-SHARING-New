"""
Yield prediction model utilities.

The sklearn pipeline is loaded lazily so the full app can start (and serve
disease-detection requests) even when models/corn_yield_model.tflite is absent.
When the model file is missing, yield endpoints return HTTP 503.
"""

from __future__ import annotations

import logging
from typing import NamedTuple

import joblib
import numpy as np
import pandas as pd
import shap

from core.config import settings

logger = logging.getLogger(__name__)


# ---------------------------------------------------------------------------
# Model state container
# ---------------------------------------------------------------------------
class YieldModelState(NamedTuple):
    pipeline: object                  # full sklearn Pipeline
    preprocessor: object              # ColumnTransformer step
    model: object                     # underlying estimator (trees)
    explainer: shap.TreeExplainer
    all_feature_names: list[str]      # post-transform feature names


_state: YieldModelState | None = None


def _load() -> YieldModelState | None:
    """Load the sklearn pipeline and build the SHAP explainer (lazy, first call only)."""
    path = settings.YIELD_MODEL_PATH
    logger.info("[yield] Lazy loading yield pipeline (first request) …")
    logger.info("[yield] Resolved model path : %s", path.resolve())
    logger.info("[yield] File exists         : %s", path.exists())

    if not path.exists():
        logger.error("Yield model file not found: %s", path)
        return None

    try:
        pipeline = joblib.load(path)
        preprocessor = pipeline.named_steps["preprocessor"]
        model = pipeline.named_steps["model"]

        # Derive post-transform feature names
        numeric_features: list[str] = list(preprocessor.transformers_[0][2])
        categorical_features: list[str] = list(preprocessor.transformers_[1][2])
        ohe = preprocessor.named_transformers_["cat"]
        cat_feature_names: list[str] = list(
            ohe.get_feature_names_out(categorical_features)
        )
        all_feature_names = numeric_features + cat_feature_names

        explainer = shap.TreeExplainer(model)
        logger.info(
            "[yield] ✓ Yield pipeline loaded. Total features: %d",
            len(all_feature_names),
        )
        return YieldModelState(pipeline, preprocessor, model, explainer, all_feature_names)

    except Exception as exc:
        logger.error("[yield] ✗ Failed to load yield pipeline: %s", exc)
        return None


def get_yield_state() -> YieldModelState | None:
    """Return the loaded model state (lazy, cached after first call)."""
    global _state
    if _state is not None:
        logger.debug("[yield] Cache hit – returning already-loaded yield model.")
        return _state
    _state = _load()
    return _state


# ---------------------------------------------------------------------------
# Human-readable feature label mappings
# ---------------------------------------------------------------------------
_BASE_LABELS: dict[str, str] = {
    "farm_size_acres": "Farm size (acres)",
    "farmer_experience_years": "Farmer experience (years)",
    "access_to_credit": "Access to credit",
    "access_to_extension_services": "Access to extension services",
    "mechanization": "Use of machinery",
    "market_distance_km": "Distance to market (km)",
    "soil_ph": "Soil pH",
    "organic_matter_pct": "Organic matter (%)",
    "nitrogen_index": "Nitrogen level (index)",
    "phosphorus_index": "Phosphorus level (index)",
    "potassium_index": "Potassium level (index)",
    "seasonal_rainfall_mm": "Seasonal rainfall (mm)",
    "avg_temp_c": "Average temperature (°C)",
    "fertilizer_kg_per_acre": "Fertilizer (kg/acre)",
    "planting_density_plants_per_acre": "Planting density (plants/acre)",
    "previous_yield_kg_per_acre": "Previous yield (kg/acre)",
    "pest_disease_incidence": "Pest/disease level",
}

_CAT_LABELS: dict[str, str] = {
    "district": "District",
    "agro_ecological_zone": "Agro-ecological zone",
    "soil_type": "Soil type",
    "variety": "Variety",
    "irrigation_type": "Irrigation type",
}


def pretty_feature_name(raw_name: str) -> str:
    """Convert an internal sklearn feature name to a human-readable label."""
    if raw_name in _BASE_LABELS:
        return _BASE_LABELS[raw_name]

    # One-hot encoded: e.g. "soil_type_Sandy" → "Soil type: Sandy"
    for cat_key, cat_label in _CAT_LABELS.items():
        prefix = cat_key + "_"
        if raw_name.startswith(prefix):
            value = raw_name[len(prefix):].replace("_", " ")
            return f"{cat_label}: {value}"

    return raw_name.replace("_", " ").capitalize()


# ---------------------------------------------------------------------------
# Row builder – pads 9 user inputs to the full 23-feature row
# ---------------------------------------------------------------------------
def build_full_row(data: dict) -> pd.DataFrame:
    """
    The pipeline was trained on 23 features; the form only collects 9.
    Missing fields are filled with representative Sri Lankan averages.
    Changing these defaults affects predictions – keep aligned with training data.
    """
    row = {
        "farm_id": 1,                           # not used by the model
        "district": data["district"],
        "agro_ecological_zone": "IL2",          # most common zone in dataset
        "soil_type": data["soil_type"],
        "farm_size_acres": data["farm_size_acres"],
        "farmer_experience_years": 10,
        "access_to_credit": 1,
        "access_to_extension_services": 1,
        "mechanization": 0,
        "market_distance_km": 10.0,
        "variety": data["variety"],
        "soil_ph": 6.4,
        "organic_matter_pct": 2.5,
        "nitrogen_index": 55.0,
        "phosphorus_index": 50.0,
        "potassium_index": 52.0,
        "seasonal_rainfall_mm": data["seasonal_rainfall_mm"],
        "avg_temp_c": 27.0,
        "fertilizer_kg_per_acre": data["fertilizer_kg_per_acre"],
        "planting_density_plants_per_acre": 18000,
        "irrigation_type": data["irrigation_type"],
        "previous_yield_kg_per_acre": data["previous_yield_kg_per_acre"],
        "pest_disease_incidence": data["pest_disease_incidence"],
    }
    return pd.DataFrame([row])
