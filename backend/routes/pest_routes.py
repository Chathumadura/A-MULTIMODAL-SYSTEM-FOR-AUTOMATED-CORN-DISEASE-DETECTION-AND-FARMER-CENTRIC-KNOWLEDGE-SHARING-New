from fastapi import APIRouter, File, HTTPException, UploadFile
from PIL import Image
import numpy as np
import tensorflow as tf
import io
import logging
from typing import Any

from core.config import settings

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/pest", tags=["pest detection"])

# ---------------------------------------------------------------------------
# Lazy model loader – model is NOT loaded at import time so that
# main.py can run the download step (startup event) before any load attempt.
# ---------------------------------------------------------------------------
_pest_model: Any = None
_pest_load_error: str = ""


def get_pest_model() -> Any:
    """Return the loaded pest TF model (lazy, cached after first load)."""
    global _pest_model, _pest_load_error
    if _pest_model is not None:
        logger.debug("[pest] Cache hit – returning already-loaded pest model.")
        return _pest_model

    logger.info("[pest] Lazy loading pest model (first request) …")
    path = settings.PEST_MODEL_PATH.resolve()
    logger.info("[pest] Resolved model path : %s", path)
    logger.info("[pest] File exists         : %s", path.exists())
    if path.exists():
        logger.info("[pest] File size (bytes)   : %d", path.stat().st_size)

    if not path.exists():
        _pest_load_error = f"File not found: {path}"
        logger.error("[pest] ✗ Model file missing at %s", path)
        return None

    try:
        _pest_model = tf.keras.models.load_model(str(path), compile=False)
        _pest_load_error = ""
        logger.info(
            "[pest] ✓ Pest model loaded successfully (input=%s)",
            _pest_model.input_shape,
        )
    except Exception as exc:
        _pest_load_error = str(exc)
        logger.error("[pest] ✗ Failed to load pest model from %s: %s", path, exc)
        return None

    return _pest_model


CLASS_NAMES = [
    "armyworm",
    "healthy",
    "leaf_blight",
    "zonocerus",
]

IMG_SIZE = 224


def _preprocess_image(image: Image.Image) -> np.ndarray:
    image = image.convert("RGB")
    image = image.resize((IMG_SIZE, IMG_SIZE))
    img_array = np.array(image, dtype=np.float32) / 255.0
    img_array = np.expand_dims(img_array, axis=0)
    return img_array


@router.get("/")
def pest_root() -> dict:
    return {"status": "Pest Detection backend running"}


@router.post("/predict")
async def pest_predict(file: UploadFile = File(...)) -> dict:
    pest_model = get_pest_model()
    if pest_model is None:
        raise HTTPException(status_code=503, detail="Pest detection model not loaded.")

    try:
        image_bytes = await file.read()
    except Exception:
        raise HTTPException(status_code=400, detail="Could not read uploaded file.")

    if not image_bytes:
        raise HTTPException(status_code=400, detail="Uploaded file is empty.")

    try:
        image = Image.open(io.BytesIO(image_bytes))
    except Exception:
        raise HTTPException(status_code=422, detail="Invalid image file.")

    processed = _preprocess_image(image)

    try:
        preds = pest_model.predict(processed)
    except Exception as exc:
        logger.exception("Pest model inference failed: %s", exc)
        raise HTTPException(status_code=500, detail="Prediction failed.")

    confidence = float(np.max(preds))
    class_id = int(np.argmax(preds))

    CONFIDENCE_THRESHOLD = 0.5

    if confidence < CONFIDENCE_THRESHOLD:
        return {
            "prediction": "not_corn_leaf",
            "confidence": round(confidence * 100, 2),
            "message": "Uploaded image is not a corn leaf. Please upload a clear corn leaf image.",
        }

    return {
        "prediction": CLASS_NAMES[class_id],
        "confidence": round(confidence * 100, 2),
        "message": "Corn leaf detected successfully",
    }

