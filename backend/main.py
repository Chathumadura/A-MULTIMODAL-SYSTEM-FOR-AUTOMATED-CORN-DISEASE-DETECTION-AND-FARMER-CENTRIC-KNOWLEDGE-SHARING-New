"""
Corn AI Backend – unified FastAPI application.

Responsibilities of this file (only):
  1. Create the FastAPI app instance
  2. Configure middleware (CORS, logging)
  3. Register startup/shutdown events
  4. Include API routers

All business logic lives in services/.
All route definitions live in routes/.
All configuration comes from core/config.py.
"""

import logging
import sys
import platform

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from core.config import settings
from routes.yield_routes import router as yield_router
from routes.nutrition_routes import router as nutrition_router
from routes.fertilizer_routes import router as fertilizer_router
from routes.pest_routes import router as pest_router
from routes.disease_routes import router as disease_router
from utils.inference import get_tf_diagnostics
from utils.model_downloader import download_model_if_needed
from utils.yield_model import get_yield_state

# Version diagnostics
import numpy
import pandas
import joblib
import scikit_learn
import shap

# ---------------------------------------------------------------------------
# Logging – configured exactly once; every module uses logging.getLogger()
# ---------------------------------------------------------------------------
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s  %(levelname)-8s  %(name)s  %(message)s",
)
logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Application
# ---------------------------------------------------------------------------
app = FastAPI(
    title="Corn AI Backend",
    description=(
        "Unified API for corn nutrient/disease diagnosis (image-based) "
        "and corn yield prediction with SHAP explanations."
    ),
    version="2.0.0",
)

# ---------------------------------------------------------------------------
# Middleware – CORS (single definition; origins controlled via env var)
# ---------------------------------------------------------------------------
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.ALLOWED_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ---------------------------------------------------------------------------
# Startup – download model files only; intentionally NO model loading here.
#
# Memory budget on Render free tier is 512 MB.  Loading all three models
# at startup (two TF graphs + sklearn + SHAP) easily exceeds that limit.
# Models are loaded lazily on first request and cached in their respective
# modules (utils/inference.py, routes/pest_routes.py, utils/yield_model.py).
#
# Environment variables that MUST be set in the Render dashboard
# (do NOT put blank value: "" in render.yaml – that overwrites dashboard values):
#   TF_MODEL_URL      → direct download URL for corn_final_model.tflite
#   PEST_MODEL_URL    → direct download URL for pest_model.tflite
#   YIELD_MODEL_URL   → direct download URL for models/corn_yield_model.pkl
#   DISEASE_MODEL_URL → direct download URL for disease_model.keras
# ---------------------------------------------------------------------------
@app.on_event("startup")
async def startup_event() -> None:
    logger.info("=" * 60)
    logger.info("[startup] === ENVIRONMENT & VERSION DIAGNOSTICS ===")
    logger.info("[startup] Python version     : %s", sys.version.replace('\n', ' '))
    logger.info("[startup] Platform           : %s", platform.platform())
    logger.info("[startup] Python executable  : %s", sys.executable)
    logger.info("[startup] ")
    logger.info("[startup] === DEPENDENCY VERSIONS ===")
    logger.info("[startup] numpy              : %s", numpy.__version__)
    logger.info("[startup] pandas             : %s", pandas.__version__)
    logger.info("[startup] scikit-learn       : %s", scikit_learn.__version__)
    logger.info("[startup] joblib             : %s", joblib.__version__)
    logger.info("[startup] shap               : %s", shap.__version__)
    try:
        import tensorflow as tf
        logger.info("[startup] tensorflow-cpu    : %s", tf.__version__)
    except ImportError:
        logger.info("[startup] tensorflow-cpu    : (not installed)")
    logger.info("[startup] ")
    logger.info("[startup] === MODEL DOWNLOAD PHASE ===")
    logger.info("[startup] Downloads run before any model is loaded into RAM.")

    # min_valid_bytes: TFLite image models are 5-30 MB (threshold 1 MB).
    # The yield model is a small sklearn joblib pipeline (~70 KB); use 32 KB threshold.
    _MB = 1_048_576
    _32KB = 32 * 1024
    _models = [
        ("TF_MODEL_URL",      settings.TF_MODEL_PATH,      "corn_final_model.tflite", _MB),
        ("PEST_MODEL_URL",    settings.PEST_MODEL_PATH,    "pest_model.tflite",        _MB),
        ("YIELD_MODEL_URL",   settings.YIELD_MODEL_PATH,   "corn_yield_model.pkl", _32KB),
        ("DISEASE_MODEL_URL", settings.DISEASE_MODEL_PATH, "disease_model.tflite",    _MB),
    ]

    results: list[tuple[str, bool]] = []
    for env_var, local_path, label, min_bytes in _models:
        download_model_if_needed(env_var, local_path, min_valid_bytes=min_bytes)
        # Post-download confirmation: re-check disk regardless of return value
        exists_now = local_path.exists()
        size_now   = local_path.stat().st_size if exists_now else 0
        if exists_now and size_now >= min_bytes:
            logger.info(
                "[startup] ✓ %-28s ready at %s  (%d bytes)",
                label, local_path, size_now,
            )
        else:
            if exists_now:
                logger.warning(
                    "[startup] ⚠ %-28s found but suspiciously small (%d bytes) at %s",
                    label, size_now, local_path,
                )
            else:
                logger.warning(
                    "[startup] ✗ %-28s NOT found at %s  "
                    "– dependent endpoints will return HTTP 503",
                    label, local_path,
                )
        results.append((label, exists_now and size_now >= min_bytes))

    # Extra sanity check for yield path misconfiguration
    if settings.YIELD_MODEL_PATH.suffix.lower() == ".tflite":
        logger.warning(
            "[startup] YIELD_MODEL_PATH is set to a .tflite file (%s). "
            "This endpoint expects a pickled sklearn pipeline (.pkl).",
            settings.YIELD_MODEL_PATH,
        )

    logger.info("[startup] === MODEL DOWNLOAD SUMMARY ===")
    for label, ready in results:
        status = "READY   ✓" if ready else "MISSING ✗"
        logger.info("[startup]   %-28s %s", label, status)

    logger.info("[startup] Models will be loaded lazily on first request.")
    logger.info("[startup] ")
    logger.info("[startup] YIELD MODEL DIAGNOSTICS:")
    logger.info("[startup]   Path     : %s", settings.YIELD_MODEL_PATH.resolve())
    logger.info("[startup]   Exists   : %s", settings.YIELD_MODEL_PATH.exists())
    if settings.YIELD_MODEL_PATH.exists():
        logger.info("[startup]   Size     : %d bytes", settings.YIELD_MODEL_PATH.stat().st_size)
    logger.info("=" * 60)


# ---------------------------------------------------------------------------
# Routers – each module owns its own URL prefix
# ---------------------------------------------------------------------------
app.include_router(yield_router)       # /yield/predict   /yield/explain
app.include_router(nutrition_router)   # /nutrition/predict
app.include_router(fertilizer_router)  # /fertilizer/recommendations/{label}  /fertilizer/labels
app.include_router(pest_router)        # /pest/  /pest/predict
app.include_router(disease_router)     # /disease/  /disease/predict


# ---------------------------------------------------------------------------
# Root / health
# ---------------------------------------------------------------------------
@app.get("/", tags=["utility"])
def root() -> dict:
    return {"message": "Corn AI Backend is running.", "docs": "/docs"}


@app.get("/health", tags=["utility"])
def health() -> dict:
    """
    Liveness + readiness probe.

    Returns:
    - **status** – always "ok" (process is alive)
    - **tf_model** – True only when the TF model is loaded and ready
    - **yield_model** – True only when the sklearn pipeline is loaded
    - **tf_diagnostics** – detailed path / file / LFS / error info for the TF model
    """
    tf_diag = get_tf_diagnostics()
    yield_exists = settings.YIELD_MODEL_PATH.exists()
    return {
        "status": "ok",
        "tf_model": tf_diag["model_loaded"],
        "yield_model": get_yield_state() is not None,
        # extra fields for easier debugging of yield path
        "yield_model_path": str(settings.YIELD_MODEL_PATH.resolve()),
        "yield_file_exists": yield_exists,
        "tf_diagnostics": tf_diag,
    }
