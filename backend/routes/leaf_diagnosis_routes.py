"""
Combined leaf diagnosis routes.

Prefix : /leaf-diagnosis
Endpoints:
  POST /leaf-diagnosis/predict  – upload one corn leaf image and run both
                                  the nutrient and disease models before
                                  returning a final diagnosis.
"""

from __future__ import annotations

import logging
from typing import Annotated

from fastapi import APIRouter, File, HTTPException, UploadFile

from services.leaf_diagnosis_service import analyze_leaf_diagnosis
from utils.inference import ALLOWED_CONTENT_TYPES, MAX_FILE_SIZE_BYTES

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/leaf-diagnosis", tags=["leaf diagnosis"])


@router.post(
    "/predict",
    responses={
        400: {"description": "Empty or unreadable upload"},
        413: {"description": "File too large"},
        415: {"description": "Unsupported media type"},
        422: {"description": "Invalid image file"},
        500: {"description": "Server error"},
        503: {"description": "Model unavailable"},
    },
)
async def leaf_diagnosis_predict(
    file: Annotated[UploadFile, File(...)],
) -> dict:
    """Run nutrient and disease diagnosis on the same uploaded leaf image."""
    content_type = (file.content_type or "").lower()
    if content_type not in ALLOWED_CONTENT_TYPES:
        raise HTTPException(
            status_code=415,
            detail=f"Unsupported file type '{content_type}'. Please upload a JPEG or PNG image.",
        )

    try:
        file_bytes = await file.read()
    except Exception as exc:
        logger.error("[leaf-diagnosis] Failed to read uploaded file: %s", exc)
        raise HTTPException(status_code=400, detail="Could not read the uploaded file.")

    if not file_bytes:
        raise HTTPException(status_code=400, detail="Uploaded file is empty.")

    if len(file_bytes) > MAX_FILE_SIZE_BYTES:
        mb = len(file_bytes) / (1024 * 1024)
        raise HTTPException(
            status_code=413,
            detail=f"File size {mb:.1f} MB exceeds the 5 MB limit.",
        )

    logger.info(
        "[leaf-diagnosis] /predict file=%s size=%d bytes content_type=%s",
        file.filename,
        len(file_bytes),
        content_type,
    )

    try:
        return analyze_leaf_diagnosis(file_bytes)
    except RuntimeError as exc:
        logger.warning("[leaf-diagnosis] Model unavailable: %s", exc)
        raise HTTPException(status_code=503, detail=str(exc))
    except ValueError as exc:
        logger.warning("[leaf-diagnosis] Invalid image: %s", exc)
        raise HTTPException(status_code=422, detail=str(exc))
    except HTTPException:
        raise
    except Exception as exc:
        logger.exception("[leaf-diagnosis] Unexpected error: %s", exc)
        raise HTTPException(status_code=500, detail="Leaf diagnosis failed. See server logs.")
