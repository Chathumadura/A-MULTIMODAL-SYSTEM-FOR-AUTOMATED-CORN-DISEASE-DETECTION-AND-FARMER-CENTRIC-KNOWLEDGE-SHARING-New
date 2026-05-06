"""
CORNXPERT UTILITY LAYER - MACHINE LEARNING MODEL MANAGEMENT

This module handles the technical details of the scikit-learn model:
1. Persistence: Loads the pre-trained .pkl file lazily.
2. Structure: Deconstructs the pipeline into its preprocessor and estimator components.
3. Feature Engineering: Reconstructs post-transformation feature names for SHAP.
4. Data Prep: Maps mobile app inputs to the precise DataFrame format expected by the model.
"""

from __future__ import annotations

import logging
import os
import sys
from typing import NamedTuple

import joblib
import numpy as np
import pandas as pd
import pickle
import shap
import sklearn

logger = logging.getLogger(__name__)

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MODEL_PATH = os.path.join(BASE_DIR, "corn_yield_model.pkl")


# ---------------------------------------------------------------------------
# Model state container
# ---------------------------------------------------------------------------
class YieldModelState(NamedTuple):
    """
    Container for the loaded machine learning artifacts.
    Storing them together ensures consistency between prediction and explanation.
    """
    pipeline: object                  # Full scikit-learn Pipeline
    preprocessor: object              # The ColumnTransformer part of the pipeline
    model: object                     # The actual tree-based estimator (e.g., XGBoost)
    explainer: shap.TreeExplainer     # Pre-initialized SHAP explainer
    all_feature_names: list[str]      # Names of the features after one-hot encoding


_state: YieldModelState | None = None


def _load() -> YieldModelState | None:
    """
    Technical implementation of the model loader.
    Accesses the filesystem to read the serialized pipeline.
    """
    logger.info("Python version: %s", sys.version.replace("\n", " "))
    logger.info("scikit-learn version: %s", sklearn.__version__)
    logger.info("numpy version: %s", np.__version__)
    logger.info("Loading yield pipeline from %s", MODEL_PATH)

    if not os.path.exists(MODEL_PATH):
        raise RuntimeError(f"Model file not found at {MODEL_PATH}")

    try:
        try:
            with open(MODEL_PATH, "rb") as f:
                pipeline = pickle.load(f)
        except Exception:
            pipeline = joblib.load(MODEL_PATH)
        preprocessor = pipeline.named_steps["preprocessor"]
        model = pipeline.named_steps["model"]

        # Reconstruct feature names after transformation
        # This is critical for mapping SHAP values back to human-readable factors.
        cat_idx = 0 if preprocessor.transformers_[0][0] == "cat" else 1
        num_idx = 1 - cat_idx
        categorical_features: list[str] = list(preprocessor.transformers_[cat_idx][2])
        numeric_features: list[str] = list(preprocessor.transformers_[num_idx][2])
        cat_transformer = preprocessor.named_transformers_["cat"]
        cat_feature_names: list[str] = list(
            cat_transformer.get_feature_names_out(categorical_features)
        )
        all_feature_names = cat_feature_names + numeric_features

        explainer = shap.TreeExplainer(model)
        logger.info(
            "Yield pipeline loaded successfully. Total features: %d",
            len(all_feature_names),
        )
        return YieldModelState(pipeline, preprocessor, model, explainer, all_feature_names)

    except Exception as exc:
        raise RuntimeError(f"Failed to load yield pipeline: {exc}") from exc


def get_yield_state() -> YieldModelState | None:
    """Return the loaded model state, initialising on first call."""
    global _state
    if _state is None:
        _state = _load()
    return _state


# ---------------------------------------------------------------------------
# Human-readable feature label mappings
# ---------------------------------------------------------------------------
_BASE_LABELS: dict[str, str] = {
    "farm_size_acres": "Farm size",
    "seasonal_rainfall_mm": "Seasonal rainfall",
    "fertilizer_kg_per_acre": "Fertilizer",
    "previous_yield_kg_per_acre": "Previous yield",
}

_CAT_LABELS: dict[str, str] = {
    "district": "District",
    "variety": "Variety",
    "soil_type": "Soil type",
    "irrigation_type": "Irrigation type",
    "pest_disease_level": "Pest/disease level",
}


def pretty_feature_name(raw_name: str) -> str:
    """Convert an internal sklearn feature name to a base label."""
    if raw_name in _BASE_LABELS:
        return _BASE_LABELS[raw_name]

    for cat_key, cat_label in _CAT_LABELS.items():
        if raw_name == cat_key or raw_name.startswith(f"{cat_key}_"):
            return cat_label

    return raw_name.replace("_", " ").capitalize()


# ---------------------------------------------------------------------------
# Pest level mapping (form sends int 0-3, model expects string)
# ---------------------------------------------------------------------------
_PEST_MAP = {0: "None", 1: "Low", 2: "Medium", 3: "High"}


# ---------------------------------------------------------------------------
# Row builder – maps 9 form inputs to the 9 model features
# ---------------------------------------------------------------------------
def build_full_row(data: dict) -> pd.DataFrame:
    """
    Translates mobile app inputs into a structured Pandas DataFrame.
    
    Important: The model expects 9 specific features. We must also map
    the pest_disease_incidence (integer) to the categorical labels (string)
    used during the model's training phase.
    """
    row = {
        "district": data["district"],
        "variety": data["variety"],
        "soil_type": data["soil_type"],
        "irrigation_type": data["irrigation_type"],
        "pest_disease_level": _PEST_MAP.get(
            data.get("pest_disease_incidence", 0), "None"
        ),
        "farm_size_acres": data["farm_size_acres"],
        "seasonal_rainfall_mm": data["seasonal_rainfall_mm"],
        "fertilizer_kg_per_acre": data["fertilizer_kg_per_acre"],
        "previous_yield_kg_per_acre": data["previous_yield_kg_per_acre"],
    }
    return pd.DataFrame([row])
