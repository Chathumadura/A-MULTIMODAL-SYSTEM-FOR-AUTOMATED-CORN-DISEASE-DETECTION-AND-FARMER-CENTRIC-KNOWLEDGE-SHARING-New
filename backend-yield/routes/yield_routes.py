"""
CORNXPERT API ROUTES - YIELD PREDICTION

This module defines the RESTful endpoints for the corn yield prediction feature.
It uses FastAPI and Pydantic for:
1. Input Validation: Ensuring the farmer-facing form data is correct.
2. Response Serialization: Formatting prediction and SHAP insights for the UI.
3. Error Handling: Managing model unavailability or processing failures.

Primary Endpoints:
- /yield/predict: Predicts harvest weight and provides top drivers.
- /yield/explain: A dedicated SHAP breakdown for detailed UI analysis.
"""

import logging

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field

# Business logic is imported from the service layer to keep routes clean
from services.yield_service import explain_yield

logger = logging.getLogger(__name__)

# Create the router instance with a common prefix and tags for Swagger docs
router = APIRouter(prefix="/yield", tags=["yield prediction"])


# ---------------------------------------------------------------------------
# Schemas
# ---------------------------------------------------------------------------
class YieldRequest(BaseModel):
    """
    Validation schema for the 9 agricultural fields collected from the mobile app.
    Pydantic 'Field' annotations ensure that inputs like farm size are logically valid.
    """

    district: str
    farm_size_acres: float = Field(..., gt=0, description="Farm size in acres (> 0)")
    variety: str
    soil_type: str
    irrigation_type: str
    seasonal_rainfall_mm: float = Field(..., ge=0)
    fertilizer_kg_per_acre: float = Field(..., ge=0)
    previous_yield_kg_per_acre: float = Field(..., ge=0)
    pest_disease_incidence: int = Field(..., ge=0, le=10)  # Input from a 0-10 slider or scale
    language: str = Field("en", description="Preferred language (en, si, ta)")


class FeatureContribution(BaseModel):
    """Represents a single agricultural factor's impact on the final yield."""
    feature: str             # Machine-readable key
    display_name: str        # Human-readable name (e.g., "Seasonal Rainfall")
    impact_value: float      # Absolute SHAP value
    impact_percentage: float # Normalized impact (0-100%)
    direction: str           # "increases" or "reduces" the total yield
    reason: str              # Context-aware reason (e.g., "Below optimal rainfall")


class YieldExplainResponse(BaseModel):
    """Final JSON response structure for the yield analysis UI."""
    predicted_yield_kg_per_acre: float
    base_yield: float        # The starting point (expected value) of the model
    delta: float             # The difference between base and predicted yield
    summary: str             # Narrative summary of the prediction
    detailed_explanation: str # NEW: Detailed multi-factor reasoning
    top_contributing_features: list[FeatureContribution]
    recommendations: list[str] # Actionable suggestions for the farmer
    what_if: str             # Hypothetical 'what-if' scenario for yield improvement


# ---------------------------------------------------------------------------
# Shared error handler (keeps both endpoints DRY)
# ---------------------------------------------------------------------------
def _raise(exc: Exception) -> None:
    """Centralized error handling to map Python exceptions to HTTP status codes."""
    if isinstance(exc, RuntimeError):
        # 503 Service Unavailable (e.g., when the model file is missing)
        raise HTTPException(status_code=503, detail=str(exc))
    
    logger.exception("Unexpected yield error: %s", exc)
    raise HTTPException(
        status_code=500, detail="Yield prediction failed. See server logs."
    )


# ---------------------------------------------------------------------------
# Endpoints
# ---------------------------------------------------------------------------
@router.post("/predict", response_model=YieldExplainResponse)
def yield_predict(payload: YieldRequest) -> YieldExplainResponse:
    """
    Predict corn yield (kg/acre) and provide a breakdown of the top factors.
    Used by the main prediction screen in the mobile app.
    """
    logger.info("POST /yield/predict  district=%s", payload.district)
    try:
        # Call the service layer to perform inference and SHAP calculation
        result = explain_yield(payload.model_dump())
        return YieldExplainResponse(**result)
    except Exception as exc:
        _raise(exc)


@router.post("/explain", response_model=YieldExplainResponse)
def yield_explain(payload: YieldRequest) -> YieldExplainResponse:
    """
    Dedicated SHAP explanation endpoint – identical response to /yield/predict.
    Kept as a separate URL for UI screens that only need the explanation.

    Errors: 422 invalid input · 503 model not loaded · 500 server error
    """
    logger.info("POST /yield/explain  district=%s", payload.district)
    try:
        result = explain_yield(payload.model_dump(), top_n=5)
        return YieldExplainResponse(**result)
    except Exception as exc:
        _raise(exc)
