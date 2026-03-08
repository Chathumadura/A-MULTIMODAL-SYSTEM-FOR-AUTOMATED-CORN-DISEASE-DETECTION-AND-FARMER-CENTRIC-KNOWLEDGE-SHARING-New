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

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from core.config import settings
from routes.yield_routes import router as yield_router
from routes.nutrition_routes import router as nutrition_router
from routes.fertilizer_routes import router as fertilizer_router
from routes.pest_routes import router as pest_router, get_pest_model
from utils.inference import get_model, get_tf_diagnostics
from utils.model_downloader import download_model_if_needed
from utils.yield_model import get_yield_state

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
# Startup – eagerly warm both models so first requests are fast
# ---------------------------------------------------------------------------
@app.on_event("startup")
async def startup_event() -> None:
    logger.info("=" * 60)
    logger.info("[startup] ── Phase 1: Downloading models if needed ──")

    # ── Download all three model files before any loading attempt ────────────
    # Environment variables that must be set on Render (or locally in .env):
    #   TF_MODEL_URL    → URL for corn_final_model.h5
    #   PEST_MODEL_URL  → URL for pest_model_final.keras
    #   YIELD_MODEL_URL → URL for corn_yield_model.pkl
    download_model_if_needed("TF_MODEL_URL",   settings.TF_MODEL_PATH)
    download_model_if_needed("PEST_MODEL_URL",  settings.PEST_MODEL_PATH)
    download_model_if_needed("YIELD_MODEL_URL", settings.YIELD_MODEL_PATH)

    logger.info("-" * 60)
    logger.info("[startup] ── Phase 2: Loading models into memory ──")

    # ── TensorFlow nutrition model ───────────────────────────────────────────
    logger.info("[startup] Warming up TF nutrition model …")
    tf_diag = get_tf_diagnostics()  # logs path + exists + LFS check internally
    logger.info("[startup] TF model path    : %s", tf_diag["model_path"])
    logger.info("[startup] TF file exists   : %s", tf_diag["file_exists"])
    logger.info("[startup] TF file size     : %s bytes", tf_diag["file_size_bytes"])
    logger.info("[startup] TF LFS pointer   : %s", tf_diag["is_lfs_pointer"])

    tf_model = get_model()
    if tf_model is None:
        logger.error(
            "[startup] ✗ TF nutrition model NOT loaded – "
            "POST /nutrition/predict will return 503.\n"
            "          Reason: %s\n"
            "          Fix   : Set TF_MODEL_URL env var on Render.",
            tf_diag["load_error"],
        )
    else:
        logger.info("[startup] ✓ TF nutrition model ready (input=%s).", tf_model.input_shape)

    # ── TensorFlow pest model ────────────────────────────────────────────────
    logger.info("-" * 60)
    logger.info("[startup] Warming up pest detection model …")
    pest_model = get_pest_model()
    if pest_model is None:
        logger.error(
            "[startup] ✗ Pest model NOT loaded – "
            "POST /pest/predict will return 503.\n"
            "          Fix   : Set PEST_MODEL_URL env var on Render."
        )
    else:
        logger.info("[startup] ✓ Pest model ready (input=%s).", pest_model.input_shape)

    # ── Sklearn pipeline + SHAP ─────────────────────────────────────────────
    logger.info("-" * 60)
    logger.info("[startup] Warming up yield model …")
    yield_state = get_yield_state()
    if yield_state is None:
        logger.error(
            "[startup] ✗ Yield model NOT loaded – "
            "/yield/predict and /yield/explain will return 503.\n"
            "          Fix   : Set YIELD_MODEL_URL env var on Render."
        )
    else:
        logger.info("[startup] ✓ Yield model ready.")
    logger.info("=" * 60)


# ---------------------------------------------------------------------------
# Routers – each module owns its own URL prefix
# ---------------------------------------------------------------------------
app.include_router(yield_router)       # /yield/predict   /yield/explain
app.include_router(nutrition_router)   # /nutrition/predict
app.include_router(fertilizer_router)  # /fertilizer/recommendations/{label}  /fertilizer/labels
app.include_router(pest_router)        # /pest/  /pest/predict


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
    return {
        "status": "ok",
        "tf_model": tf_diag["model_loaded"],
        "yield_model": get_yield_state() is not None,
        "tf_diagnostics": tf_diag,
    }
