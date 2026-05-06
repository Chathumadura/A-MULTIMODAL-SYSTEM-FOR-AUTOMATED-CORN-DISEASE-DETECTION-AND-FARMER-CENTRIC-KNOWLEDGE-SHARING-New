"""
CORNXPERT YIELD PREDICTION SERVICE - ENTRY POINT

This module initializes the FastAPI application for the yield prediction backend.
It sets up the following:
1. API Routing: Connects yield and fertilizer prediction endpoints.
2. Model Warm-up: Loads the machine learning model into memory during startup.
3. CORS Policy: Allows the mobile app to communicate with the server.
4. Health Monitoring: Provides a simple status check for deployment.

Exposed API surface:
  - POST /yield/predict   : Predict yield + provide SHAP factors.
  - POST /yield/explain   : Dedicated explainability endpoint.
  - GET  /fertilizer/...  : Fertilizer advice lookups.
  - GET  /health          : Verification of system readiness.
"""

# Python 3.10 is specifically required to ensure binary compatibility 
# with the pre-trained scikit-learn and SHAP model binaries.
import logging

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

# Internal imports for configuration and modularized routing
from core.config import settings
from routes.yield_routes import router as yield_router
from routes.fertilizer_routes import router as fertilizer_router
from utils.yield_model import get_yield_state

# Standard logging configuration for monitoring server activity
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s  %(levelname)-8s  %(name)s  %(message)s",
)
logger = logging.getLogger(__name__)

# Initialize the FastAPI application instance
app = FastAPI(
    title="Corn AI – Yield Backend",
    description="Precision yield forecasting service with integrated SHAP explainability.",
    version="1.0.0",
)

# Configure Cross-Origin Resource Sharing (CORS) 
# This is essential for allowing the Flutter mobile app to make network requests.
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.ALLOWED_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.on_event("startup")
async def startup_event() -> None:
    """
    FastAPI startup hook. Loads the machine learning model once during initialization
    to prevent latency during the first user request.
    """
    logger.info("=" * 60)
    logger.info("[startup] Warming up yield model …")
    state = get_yield_state()
    if state is None:
        logger.error("[startup] ✗ Yield model NOT loaded – /yield/predict will return 503.")
    else:
        logger.info("[startup] ✓ Yield model ready. Features: %d", len(state.all_feature_names))
    logger.info("=" * 60)


    # Register the modularized routers for different feature sets
app.include_router(yield_router)       # Handles all /yield related paths
app.include_router(fertilizer_router)  # Handles all /fertilizer related paths


@app.get("/", tags=["utility"])
def root() -> dict:
    """Simple greeting for the root path."""
    return {"message": "Corn AI Yield Backend is running.", "docs": "/docs"}


@app.get("/health", tags=["utility"])
def health() -> dict:
    """
    Health check endpoint for monitoring tools.
    Verifies that the server is alive and the ML model is successfully loaded.
    """
    state = get_yield_state()
    return {
        "status": "ok",
        "yield_model": state is not None,  # Boolean flag for model readiness
    }
