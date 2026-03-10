"""
Yield prediction routes.

Prefix : /yield
Endpoints:
  POST /yield/predict  – predict yield (kg/acre) + top-5 SHAP contributions
  POST /yield/explain  – dedicated SHAP explanation (same payload, same response)
                         useful for a standalone "Why this prediction?" screen
"""

import logging

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field

from services.yield_service import explain_yield

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/yield", tags=["yield prediction"])


# ---------------------------------------------------------------------------
# Schemas
# ---------------------------------------------------------------------------
class YieldRequest(BaseModel):
    """9 fields collected from the farmer-facing form."""

    district: str
    farm_size_acres: float = Field(..., gt=0, description="Farm size in acres (> 0)")
    variety: str
    soil_type: str
    irrigation_type: str
    seasonal_rainfall_mm: float = Field(..., ge=0)
    fertilizer_kg_per_acre: float = Field(..., ge=0)
    previous_yield_kg_per_acre: float = Field(..., ge=0)
    pest_disease_incidence: int = Field(..., ge=0, le=10)


class FeatureContribution(BaseModel):
    raw_name: str
    display_name: str
    shap_value: float


class YieldExplainResponse(BaseModel):
    predicted_yield_kg_per_acre: float
    top_contributing_features: list[FeatureContribution]


# ---------------------------------------------------------------------------
# Shared error handler (keeps both endpoints DRY)
# ---------------------------------------------------------------------------
def _raise(exc: Exception) -> None:
    if isinstance(exc, RuntimeError):
        raise HTTPException(status_code=503, detail=str(exc))
    logger.exception("Unexpected yield error: %s", exc)
    raise HTTPException(
        status_code=500, detail="Yield prediction failed. See server logs."
    )


# ---------------------------------------------------------------------------
# Endpoints
# ---------------------------------------------------------------------------
@router.post(
    "/predict",
    responses={
        422: {"description": "Invalid input"},
        503: {"description": "Model not loaded"},
        500: {"description": "Server error"},
    },
)
def yield_predict(payload: YieldRequest) -> YieldExplainResponse:
    """
    Predict corn yield (kg/acre) and return top-5 SHAP feature contributions.

    Errors: 422 invalid input · 503 model not loaded · 500 server error
    """
    logger.info("POST /yield/predict  district=%s", payload.district)
    try:
        result = explain_yield(payload.model_dump())
        return YieldExplainResponse(**result)
    except Exception as exc:
        _raise(exc)


@router.post(
    "/explain",
    responses={
        422: {"description": "Invalid input"},
        503: {"description": "Model not loaded"},
        500: {"description": "Server error"},
    },
)
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
