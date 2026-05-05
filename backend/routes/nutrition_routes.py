

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
