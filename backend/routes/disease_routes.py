"""
Disease detection routes.

Prefix : /disease
Endpoints:
  GET  /disease/         – liveness check
  POST /disease/predict  – upload a corn leaf image; returns predicted
                           disease class + confidence score

Model loading is intentionally lazy: the Keras model is loaded into RAM
only on the first call to POST /disease/predict, then cached for
subsequent requests.  This keeps startup memory usage low on Render.
"""

import logging

import numpy as np
from fastapi import APIRouter, File, HTTPException, UploadFile

from utils.disease_model import (
    DISEASE_CLASS_NAMES,
    get_disease_load_error,
    get_disease_model,
    preprocess_disease_image,
)

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/disease", tags=["disease detection"])

# Minimum confidence required before returning a named prediction.
# Below this threshold the response indicates an uncertain / non-corn image.
CONFIDENCE_THRESHOLD: float = 0.50


# ---------------------------------------------------------------------------
# Endpoints
# ---------------------------------------------------------------------------
@router.get("/")
def disease_root() -> dict:
    """Liveness probe for the disease-detection module."""
    return {"status": "Disease Detection backend running"}


@router.post("/predict")
async def disease_predict(file: UploadFile = File(...)) -> dict:
    """
    Upload a corn leaf image (JPEG or PNG, max 5 MB) and receive:

    - **prediction** – top-1 disease class name
    - **confidence** – top-1 probability (0–100 %)

    ### Error codes
    | HTTP | Reason                                       |
    |------|----------------------------------------------|
    | 400  | Empty or unreadable upload                   |
    | 422  | Bytes cannot be decoded as an image          |
    | 500  | Internal model inference error               |
    | 503  | Disease model file missing / not yet loaded  |
    """
    # ── 1. Ensure the model is loaded ─────────────────────────────────────────
    model = get_disease_model()
    if model is None:
        err = get_disease_load_error()
        logger.warning("[disease] /predict called but model is not available: %s", err)
        raise HTTPException(
            status_code=503,
            detail=f"Disease detection model not available. {err}".strip(),
        )

    # ── 2. Read upload ────────────────────────────────────────────────────────
    try:
        image_bytes = await file.read()
    except Exception:
        raise HTTPException(status_code=400, detail="Could not read uploaded file.")

    if not image_bytes:
        raise HTTPException(status_code=400, detail="Uploaded file is empty.")

    # ── 3. Preprocess ─────────────────────────────────────────────────────────
    try:
        processed = preprocess_disease_image(image_bytes)
    except Exception:
        raise HTTPException(status_code=422, detail="Invalid image file.")

    # ── 4. Infer ──────────────────────────────────────────────────────────────
    try:
        preds = model.predict(processed)
    except Exception as exc:
        logger.exception("[disease] Inference failed: %s", exc)
        raise HTTPException(status_code=500, detail="Prediction failed.")

    confidence = float(np.max(preds))
    class_id = int(np.argmax(preds))

    logger.info(
        "[disease] /predict  class=%s  confidence=%.2f%%  file=%s",
        DISEASE_CLASS_NAMES[class_id],
        confidence * 100,
        file.filename,
    )

    # ── 5. Low-confidence guard ───────────────────────────────────────────────
    if confidence < CONFIDENCE_THRESHOLD:
        return {
            "prediction": "uncertain",
            "confidence": round(confidence * 100, 2),
            "message": (
                "Could not confidently identify a disease. "
                "Please upload a clear corn leaf image."
            ),
        }

    return {
        "prediction": DISEASE_CLASS_NAMES[class_id],
        "confidence": round(confidence * 100, 2),
    }
