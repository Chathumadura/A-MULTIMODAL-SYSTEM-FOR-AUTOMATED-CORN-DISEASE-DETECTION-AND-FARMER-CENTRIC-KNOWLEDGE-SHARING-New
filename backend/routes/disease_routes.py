"""
Disease detection routes.

Prefix : /disease
Endpoints:
  GET  /disease/         – liveness check
  POST /disease/predict  – upload a corn leaf image; returns predicted
                           disease class + confidence score

Model loading is intentionally lazy: the TFLite interpreter is loaded into RAM
only on the first call to POST /disease/predict, then cached for
subsequent requests.  This keeps startup memory usage low on Render.
"""

import logging

from fastapi import APIRouter, File, HTTPException, UploadFile

from services.leaf_diagnosis_service import predict_disease_from_bytes
from utils.disease_model import get_disease_load_error, get_disease_model

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
    - **all_probabilities** – dict of all class probabilities (0–100 %)

    ### Error codes
    | HTTP | Reason                                       |
    |------|----------------------------------------------|
    | 400  | Empty or unreadable upload                   |
    | 422  | Bytes cannot be decoded as an image          |
    | 500  | Internal model inference error               |
    | 503  | Disease model file missing / not yet loaded  |
    """
    logger.info("[disease] /predict route hit, file: %s, size: %d bytes", file.filename, len(await file.read()))
    await file.seek(0)  # Reset file pointer

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

    # ── 3. Infer ──────────────────────────────────────────────────────────────
    try:
        result = predict_disease_from_bytes(image_bytes)
    except RuntimeError as exc:
        logger.warning("[disease] /predict called but model is not available: %s", exc)
        raise HTTPException(
            status_code=503,
            detail=f"Disease detection model not available. {get_disease_load_error()}".strip(),
        )
    except ValueError:
        raise HTTPException(status_code=422, detail="Invalid image file.")
    except Exception as exc:
        logger.exception("[disease] Inference failed: %s", exc)
        raise HTTPException(status_code=500, detail="Prediction failed.")

    confidence_pct = round(float(result["confidence"]) * 100, 2)
    all_probabilities = {
        key: round(float(value) * 100, 2)
        for key, value in result["all_probabilities"].items()
    }

    if result["status"] == "uncertain":
        return {
            "prediction": "uncertain",
            "confidence": confidence_pct,
            "all_probabilities": all_probabilities,
            "message": result.get(
                "message",
                "Could not confidently identify a disease. Please upload a clear corn leaf image.",
            ),
        }

    return {
        "prediction": result["predicted_class"],
        "confidence": confidence_pct,
        "all_probabilities": all_probabilities,
    }
