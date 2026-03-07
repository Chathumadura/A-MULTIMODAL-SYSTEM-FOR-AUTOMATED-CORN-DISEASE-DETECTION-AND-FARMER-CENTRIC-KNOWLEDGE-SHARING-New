"""
Nutrition (image-based nutrient diagnosis) routes.

Prefix : /nutrition
Endpoints:
  POST /nutrition/predict  – upload a corn leaf image; returns:
    - primary prediction + confidence
    - top-3 predictions (multi-condition research support)
    - all per-class probabilities
    - Not_Corn guard message when applicable
    - fertilizer recommendations
    - inference_time_ms + model_version

Validation (enforced here, before the service layer):
  - Content-Type must be image/jpeg, image/jpg, or image/png
  - File size must be <= 5 MB
  - File must not be empty

All error responses share the same JSON envelope:
  { "error": "<code>", "detail": "<human message>" }
"""

import logging

from fastapi import APIRouter, File, HTTPException, UploadFile
from fastapi.responses import JSONResponse

from services.nutrition_service import run_nutrition_diagnosis
from utils.inference import ALLOWED_CONTENT_TYPES, MAX_FILE_SIZE_BYTES

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/nutrition", tags=["nutrition diagnosis"])


def _error(status: int, code: str, detail: str) -> JSONResponse:
    """Uniform JSON error envelope used by every error path in this router."""
    return JSONResponse(
        status_code=status,
        content={"error": code, "detail": detail},
    )


@router.post("/predict")
async def nutrition_predict(file: UploadFile = File(...)):
    """
    Upload a corn leaf image (JPEG or PNG, max 5 MB) and receive:

    - **predicted_class** – top-1 label
    - **confidence** – top-1 probability (0-1)
    - **top_3** – top-3 labels with probabilities (for multi-condition research)
    - **all_probabilities** – full softmax output keyed by class name
    - **is_corn** – boolean guard
    - **fertilizer_recommendations** – actionable advice (null when not applicable)
    - **inference_time_ms** – model latency
    - **model_version** – identifier of the loaded TF model

    ### Error codes
    | HTTP | error code         | Reason                            |
    |------|--------------------|-----------------------------------|
    | 400  | empty_file         | Zero-byte upload                  |
    | 415  | unsupported_media  | Not JPEG/PNG                      |
    | 413  | file_too_large     | Exceeds 5 MB                      |
    | 422  | invalid_image      | Cannot be decoded / preprocessed  |
    | 503  | model_unavailable  | TF model not loaded               |
    | 500  | server_error       | Unexpected internal error         |
    """
    logger.info("POST /nutrition/predict  file=%s  content_type=%s", file.filename, file.content_type)

    # ── 1. Content-type validation ────────────────────────────────────────────
    ct = (file.content_type or "").lower()
    if ct not in ALLOWED_CONTENT_TYPES:
        return _error(
            415, "unsupported_media",
            f"Unsupported file type '{ct}'. Please upload a JPEG or PNG image.",
        )

    # When octet-stream is sent, verify the actual bytes are a valid image
    # after reading (handled in step 5 via PIL inside preprocess_image_bytes)

    # ── 2. Read bytes ─────────────────────────────────────────────────────────
    try:
        file_bytes = await file.read()
    except Exception as exc:
        logger.error("Failed to read uploaded file: %s", exc)
        return _error(400, "read_error", "Could not read the uploaded file.")

    # ── 3. Empty-file guard ───────────────────────────────────────────────────
    if not file_bytes:
        return _error(400, "empty_file", "Uploaded file is empty.")

    # ── 4. Size validation ────────────────────────────────────────────────────
    if len(file_bytes) > MAX_FILE_SIZE_BYTES:
        mb = len(file_bytes) / (1024 * 1024)
        return _error(
            413, "file_too_large",
            f"File size {mb:.1f} MB exceeds the 5 MB limit.",
        )

    # ── 5. Inference ──────────────────────────────────────────────────────────
    try:
        return run_nutrition_diagnosis(file_bytes)
    except RuntimeError as exc:
        logger.error("Model unavailable: %s", exc)
        return _error(503, "model_unavailable", str(exc))
    except ValueError as exc:
        logger.error("Image preprocessing error: %s", exc)
        return _error(422, "invalid_image", str(exc))
    except Exception as exc:
        logger.exception("Unexpected error in /nutrition/predict: %s", exc)
        return _error(500, "server_error", "Prediction failed – see server logs.")
