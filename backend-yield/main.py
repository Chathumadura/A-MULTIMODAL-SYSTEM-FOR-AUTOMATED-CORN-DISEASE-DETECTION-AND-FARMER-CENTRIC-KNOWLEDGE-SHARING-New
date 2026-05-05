"""
Corn AI – Yield Prediction Backend (port 8001)

Serves:
  POST /yield/predict   – sklearn pipeline + SHAP explanations
  GET  /fertilizer/recommendations/{label}
  GET  /fertilizer/labels
  GET  /health
"""

# IMPORTANT:
# This service requires Python 3.10 due to ML dependency compatibility

import logging

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from core.config import settings
from routes.yield_routes import router as yield_router
from routes.fertilizer_routes import router as fertilizer_router
from utils.yield_model import get_yield_state

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s  %(levelname)-8s  %(name)s  %(message)s",
)
logger = logging.getLogger(__name__)

app = FastAPI(
    title="Corn AI – Yield Backend",
    description="Yield prediction (sklearn + SHAP) and fertilizer recommendations.",
    version="1.0.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.ALLOWED_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.on_event("startup")
async def startup_event() -> None:
    logger.info("=" * 60)
    logger.info("[startup] Warming up yield model …")
    state = get_yield_state()
    if state is None:
        logger.error("[startup] ✗ Yield model NOT loaded – /yield/predict will return 503.")
    else:
        logger.info("[startup] ✓ Yield model ready. Features: %d", len(state.all_feature_names))
    logger.info("=" * 60)


app.include_router(yield_router)       # /yield/predict  /yield/explain
app.include_router(fertilizer_router)  # /fertilizer/recommendations/{label}  /fertilizer/labels


@app.get("/", tags=["utility"])
def root() -> dict:
    return {"message": "Corn AI Yield Backend is running.", "docs": "/docs"}


@app.get("/health", tags=["utility"])
def health() -> dict:
    state = get_yield_state()
    return {
        "status": "ok",
        "yield_model": state is not None,
    }
