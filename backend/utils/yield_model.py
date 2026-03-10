"""
Yield prediction model utilities.

The sklearn pipeline is loaded lazily so the full app can start (and serve
disease-detection requests) even when models/corn_yield_model.pkl is absent.
When the model file is missing, yield endpoints return HTTP 503.
"""

from __future__ import annotations

import logging
import sys
import platform
from typing import NamedTuple

import joblib
import numpy as np
import pandas as pd
import shap
import sklearn

from core.config import settings

logger = logging.getLogger(__name__)

# Constants for logging
YIELD_LOG_PREFIX = "[yield] "
SEPARATOR_LINE = "=" * 70
BLOCK_SEPARATOR = "═" * 60
DIAG_HEADER = "============================================================"
EMPTY_LINE = ""


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


def _log_sklearn_compatibility() -> None:
    """Log sklearn version compatibility warnings."""
    sklearn_version = tuple(map(int, sklearn.__version__.split('.')[:2]))
    if sklearn_version < (1, 7):
        logger.warning(
            f"{YIELD_LOG_PREFIX}WARNING: scikit-learn %s detected. "
            "The model was pickled with sklearn 1.7.2. "
            "Versions <1.7 may cause AttributeError on ColumnTransformer. "
            "Please upgrade to scikit-learn>=1.7.2",
            sklearn.__version__
        )
    else:
        logger.info(f"{YIELD_LOG_PREFIX}scikit-learn version %s should be compatible with 1.7.x pickled models", sklearn.__version__)


def _log_version_diagnostics() -> None:
    """Log comprehensive version diagnostics for debugging pickle issues."""
    logger.info(SEPARATOR_LINE)
    logger.info(f"{YIELD_LOG_PREFIX}{DIAG_HEADER}")
    logger.info(f"{YIELD_LOG_PREFIX} YIELD MODEL LOADING - VERSION DIAGNOSTICS")
    logger.info(f"{YIELD_LOG_PREFIX}{DIAG_HEADER}")
    logger.info(f"{YIELD_LOG_PREFIX}Python version     : %s", sys.version.replace('\n', ' '))
    logger.info(f"{YIELD_LOG_PREFIX}Platform           : %s", platform.platform())
    logger.info(f"{YIELD_LOG_PREFIX}Python executable  : %s", sys.executable)
    logger.info(f"{YIELD_LOG_PREFIX}{EMPTY_LINE}")
    logger.info(f"{YIELD_LOG_PREFIX}--- CRITICAL PACKAGE VERSIONS ---")
    logger.info(f"{YIELD_LOG_PREFIX}numpy              : %s", np.__version__)
    logger.info(f"{YIELD_LOG_PREFIX}pandas             : %s", pd.__version__)
    logger.info(f"{YIELD_LOG_PREFIX}scikit-learn       : %s", sklearn.__version__)
    logger.info(f"{YIELD_LOG_PREFIX}joblib             : %s", joblib.__version__)
    logger.info(f"{YIELD_LOG_PREFIX}shap               : %s", shap.__version__)
    logger.info(f"{YIELD_LOG_PREFIX}{EMPTY_LINE}")
    
    _log_sklearn_compatibility()
    
    logger.info(f"{YIELD_LOG_PREFIX}{DIAG_HEADER}")
    logger.info(SEPARATOR_LINE)


def _check_model_file(path) -> str | None:
    """Check and resolve the model file path, returning the resolved path or None if invalid."""
    resolved = path.resolve()
    suffix = resolved.suffix.lower()
    logger.info(f"{YIELD_LOG_PREFIX}Resolved model path : %s", resolved)
    logger.info(f"{YIELD_LOG_PREFIX}File exists         : %s", resolved.exists())
    if resolved.exists():
        logger.info(f"{YIELD_LOG_PREFIX}File size (bytes)    : %d", resolved.stat().st_size)
    logger.info(f"{YIELD_LOG_PREFIX}File extension       : %s", suffix)

    # guard against common misconfiguration where a .tflite is pointed at
    if suffix == ".tflite" or suffix == ".lite":
        logger.warning(
            f"{YIELD_LOG_PREFIX}YIELD_MODEL_PATH points to a TFLite file; this service expects a pickled sklearn pipeline (.pkl)." 
            " Attempting to locate a sibling .pkl file as a fallback."
        )
        alt = resolved.with_suffix(".pkl")
        if alt.exists():
            logger.info(f"{YIELD_LOG_PREFIX}Found alternate .pkl at %s – will load this instead", alt)
            resolved = alt
            suffix = resolved.suffix.lower()
        else:
            logger.error(
                f"{YIELD_LOG_PREFIX}No .pkl sibling found next to %s; cannot load yield model.",
                resolved,
            )
            return None

    # final sanity check: only load known file types
    if suffix not in (".pkl", ".joblib"):
        logger.error(
            f"{YIELD_LOG_PREFIX}Unsupported file extension '%s' for yield model. "
            "Expected .pkl or .joblib.",
            suffix,
        )
        return None

    if not resolved.exists():
        logger.error("Yield model file not found: %s", resolved)
        return None

    return str(resolved)


def _load_pipeline(resolved_path: str) -> YieldModelState | None:
    """Load the pipeline from the resolved path and build the state."""
    try:
        logger.info(f"{YIELD_LOG_PREFIX}Loading sklearn pipeline from %s", resolved_path)
        logger.debug(
            f"{YIELD_LOG_PREFIX}Load environment: numpy=%s, pandas=%s, joblib=%s, scikit-learn=%s",
            np.__version__, pd.__version__, joblib.__version__, sklearn.__version__,
        )
        
        pipeline = joblib.load(resolved_path)
        
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
            f"{YIELD_LOG_PREFIX}✓ Yield pipeline loaded. Total features: %d",
            len(all_feature_names),
        )
        return YieldModelState(pipeline, preprocessor, model, explainer, all_feature_names)

    except ModuleNotFoundError as exc:
        _handle_module_not_found_error(exc)
        return None

    except Exception as exc:
        # include full traceback, exception type, and message
        exc_type = type(exc).__name__
        exc_msg = str(exc)
        logger.error(
            f"{YIELD_LOG_PREFIX}✗ Failed to load yield pipeline."
            "  Exception: %s(%s)",
            exc_type, exc_msg,
        )
        logger.exception(f"{YIELD_LOG_PREFIX}Full traceback for yield model load failure:")
        return None


def _handle_module_not_found_error(exc: ModuleNotFoundError) -> None:
    """Handle ModuleNotFoundError with special case for sklearn version mismatches."""
    if '_loss' in str(exc) or 'sklearn' in str(exc).lower():
        logger.error(f"{YIELD_LOG_PREFIX}{BLOCK_SEPARATOR}")
        logger.error(f"{YIELD_LOG_PREFIX} MODEL LOAD FAILED DUE TO VERSION MISMATCH")
        logger.error(f"{YIELD_LOG_PREFIX}{BLOCK_SEPARATOR}")
        logger.error(
            f"{YIELD_LOG_PREFIX}The error '%s' indicates the model was pickled with a different "
            "scikit-learn version than what's currently installed.", 
            str(exc)
        )
        logger.error(f"{YIELD_LOG_PREFIX}CURRENT scikit-learn: %s", sklearn.__version__)
        logger.error(f"{YIELD_LOG_PREFIX}")
        logger.error(f"{YIELD_LOG_PREFIX}TO FIX THIS ISSUE:")
        logger.error(f"{YIELD_LOG_PREFIX}1. Re-export the model from the ORIGINAL training environment using:")
        logger.error(f"{YIELD_LOG_PREFIX}     import joblib")
        logger.error(f"{YIELD_LOG_PREFIX}     joblib.dump(your_pipeline, 'corn_yield_model.pkl')")
        logger.error(f"{YIELD_LOG_PREFIX}2. OR match the training environment's package versions:")
        logger.error(f"{YIELD_LOG_PREFIX}     pip install numpy==1.26.4 pandas==2.1.4 scikit-learn>=1.7.2 joblib==1.3.2")
        logger.error(f"{YIELD_LOG_PREFIX}3. Upload the new .pkl file to your model storage and update YIELD_MODEL_URL")
        logger.error(f"{YIELD_LOG_PREFIX}{BLOCK_SEPARATOR}")
    else:
        exc_type = type(exc).__name__
        exc_msg = str(exc)
        logger.error(
            f"{YIELD_LOG_PREFIX}✗ Failed to load yield pipeline (ModuleNotFoundError)."
            "  Exception: %s(%s)",
            exc_type, exc_msg,
        )
    logger.exception(f"{YIELD_LOG_PREFIX}Full traceback for yield model load failure:")


def _load() -> YieldModelState | None:
    """Load the sklearn pipeline and build the SHAP explainer (lazy, first call only)."""
    path = settings.YIELD_MODEL_PATH
    
    _log_version_diagnostics()
    
    logger.info(f"{YIELD_LOG_PREFIX}Lazy loading yield pipeline (first request) …")

    resolved_path = _check_model_file(path)
    if resolved_path is None:
        return None

    return _load_pipeline(resolved_path)


def get_yield_state() -> YieldModelState | None:
    """Return the loaded model state (lazy, cached after first call)."""
    global _state
    if _state is not None:
        logger.debug(f"{YIELD_LOG_PREFIX}Cache hit – returning already-loaded yield model.")
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
