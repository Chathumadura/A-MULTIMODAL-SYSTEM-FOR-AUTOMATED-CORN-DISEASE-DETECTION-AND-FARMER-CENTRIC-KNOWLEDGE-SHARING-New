"""
Nutrition (image-based nutrient diagnosis) routes.

Prefix : /nutrition
Endpoints:
  POST /nutrition/predict  – upload a corn leaf image, returns diagnosis
                             + embedded fertilizer recommendations
"""

import logging

from fastapi import APIRouter, File, HTTPException, UploadFile

from services.nutrition_service import run_nutrition_diagnosis

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/nutrition", tags=["nutrition diagnosis"])


@router.post("/predict")
async def nutrition_predict(file: UploadFile = File(...)) -> dict:
    """
    Accept a JPEG/PNG corn leaf image and return:
    - predicted nutrient class
    - confidence score (0-1)
    - per-class probability list
    - is_corn flag
    - fertilizer recommendations (null when healthy or non-corn image)

    Errors:
    - 400  file could not be read or is empty
    - 422  image could not be decoded / pre-processed
    - 503  TF model not loaded
    - 500  unexpected server error
    """
    logger.info("POST /nutrition/predict  file=%s", file.filename)

    try:
        file_bytes = await file.read()
    except Exception as exc:
        logger.error("Failed to read uploaded file: %s", exc)
        raise HTTPException(status_code=400, detail="Could not read the uploaded file.")

    if not file_bytes:
        raise HTTPException(status_code=400, detail="Uploaded file is empty.")

    try:
        return run_nutrition_diagnosis(file_bytes)
    except RuntimeError as exc:
        raise HTTPException(status_code=503, detail=str(exc))
    except ValueError as exc:
        logger.error("Image error: %s", exc)
        raise HTTPException(status_code=422, detail=str(exc))
    except Exception as exc:
        logger.exception("Unexpected error in /nutrition/predict: %s", exc)
        raise HTTPException(
            status_code=500, detail="Prediction failed. See server logs."
        )
