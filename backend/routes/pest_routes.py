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


# Minimum size for a real model binary (rules out Git LFS pointer stubs).
_MIN_PEST_MODEL_BYTES: int = 1 * 1024 * 1024  # 1 MB
_LFS_SIG: bytes = b"version https://git-lfs"


def get_pest_model() -> Any:
    """
    Return the loaded pest TFLite interpreter (lazy, cached after first load).

    The pest model is now a .tflite FlatBuffer.  tf.keras.models.load_model()
    cannot read .tflite files – tf.lite.Interpreter is the correct runtime.

    First call  → load, allocate_tensors(), cache.
    Later calls → return the cached interpreter immediately.
    """
    global _pest_model, _pest_load_error

    # ── Cache hit ─────────────────────────────────────────────────────────────
    if _pest_model is not None:
        logger.debug("[pest] Cache hit – returning cached pest interpreter.")
        return _pest_model

    # ── First call: load the TFLite model ─────────────────────────────────────
    logger.info("[pest] Lazy loading pest model (first request) …")
    path = settings.PEST_MODEL_PATH.resolve()
    logger.info("[pest] Resolved model path : %s", path)
    logger.info("[pest] File exists         : %s", path.exists())

    if not path.exists():
        _pest_load_error = f"File not found: {path}"
        logger.error("[pest] ✗ Model file missing at %s", path)
        return None

    size = path.stat().st_size
    logger.info("[pest] File size (bytes)   : %d", size)

    if size < _MIN_PEST_MODEL_BYTES:
        header = path.read_bytes()[:128]
        if header.startswith(_LFS_SIG):
            _pest_load_error = f"Git LFS pointer detected ({size} bytes). Real .tflite not downloaded."
        else:
            _pest_load_error = f"File suspiciously small ({size} bytes). May be corrupt."
        logger.error("[pest] ✗ %s", _pest_load_error)
        return None

    logger.info("[pest] Creating tf.lite.Interpreter …")
    try:
        _pest_model = tf.lite.Interpreter(model_path=str(path))
        _pest_model.allocate_tensors()
        _pest_load_error = ""
        input_details = _pest_model.get_input_details()
        logger.info(
            "[pest] ✓ Pest interpreter ready. Input: index=%d shape=%s dtype=%s",
            input_details[0]["index"],
            input_details[0]["shape"],
            input_details[0]["dtype"].__name__,
        )
    except Exception as exc:
        _pest_load_error = str(exc)
        logger.error("[pest] ✗ Failed to create pest interpreter from %s: %s", path, exc)
        _pest_model = None
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
    logger.info("[pest] /predict route hit, file: %s, size: %d bytes", file.filename, len(await file.read()))
    await file.seek(0)  # Reset file pointer

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
    logger.info("[pest] preprocessed image shape: %s, dtype: %s, range: [%.3f, %.3f]", 
               processed.shape, processed.dtype, np.min(processed), np.max(processed))

    try:
        # TFLite inference: set input → invoke → read output.
        # Interpreter.predict() does not exist; this is the correct pattern.
        input_details  = pest_model.get_input_details()
        output_details = pest_model.get_output_details()
        pest_model.set_tensor(input_details[0]["index"], processed)
        pest_model.invoke()
        preds = pest_model.get_tensor(output_details[0]["index"])
        logger.info("[pest] raw TFLite output: %s", preds)
    except Exception as exc:
        logger.exception("[pest] Inference failed: %s", exc)
        raise HTTPException(status_code=500, detail="Prediction failed.")

    confidence = float(np.max(preds))
    class_id = int(np.argmax(preds))

    # Build a map of all class probabilities (percentage, rounded)
    try:
        probs = preds.reshape(-1).tolist()
    except Exception:
        probs = list(map(float, preds[0]))
    all_probabilities = {CLASS_NAMES[i]: round(float(probs[i]) * 100, 2) for i in range(len(CLASS_NAMES))}

    logger.info(
        "[pest] prediction: class=%s (id=%d), confidence=%.2f%%, file=%s",
        CLASS_NAMES[class_id],
        class_id,
        confidence * 100,
        file.filename,
    )

    CONFIDENCE_THRESHOLD = 0.5

    if confidence < CONFIDENCE_THRESHOLD:
        return {
            "prediction": "not_corn_leaf",
            "confidence": round(confidence * 100, 2),
            "message": "Uploaded image is not a corn leaf. Please upload a clear corn leaf image.",
            "all_probabilities": all_probabilities,
        }

    return {
        "prediction": CLASS_NAMES[class_id],
        "confidence": round(confidence * 100, 2),
        "message": "Corn leaf detected successfully",
        "all_probabilities": all_probabilities,
    }

