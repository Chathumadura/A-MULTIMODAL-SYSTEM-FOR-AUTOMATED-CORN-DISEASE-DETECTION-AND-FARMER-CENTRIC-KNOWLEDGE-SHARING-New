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
from utils.inference import get_model
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
    # TensorFlow model
    logger.info("Warming up TF model …")
    tf_model = get_model()
    if tf_model is None:
        logger.warning(
            "TF model not loaded at startup – POST /nutrition/predict will return 503."
        )
    else:
        logger.info("TF model ready.")

    # Sklearn pipeline + SHAP
    logger.info("Warming up yield model …")
    yield_state = get_yield_state()
    if yield_state is None:
        logger.warning(
            "Yield model not loaded at startup – "
            "POST /yield/predict and /yield/explain will return 503."
        )
    else:
        logger.info("Yield model ready.")


# ---------------------------------------------------------------------------
# Routers – each module owns its own URL prefix
# ---------------------------------------------------------------------------
app.include_router(yield_router)       # /yield/predict   /yield/explain
app.include_router(nutrition_router)   # /nutrition/predict
app.include_router(fertilizer_router)  # /fertilizer/recommendations/{label}  /fertilizer/labels


# ---------------------------------------------------------------------------
# Root / health
# ---------------------------------------------------------------------------
@app.get("/", tags=["utility"])
def root() -> dict:
    return {"message": "Corn AI Backend is running.", "docs": "/docs"}


@app.get("/health", tags=["utility"])
def health() -> dict:
    return {
        "status": "ok",
        "tf_model": get_model() is not None,
        "yield_model": get_yield_state() is not None,
    }
