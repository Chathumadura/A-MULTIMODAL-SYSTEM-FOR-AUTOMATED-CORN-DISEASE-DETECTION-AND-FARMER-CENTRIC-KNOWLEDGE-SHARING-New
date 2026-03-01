"""
TensorFlow nutrient/disease inference utilities.

The model is loaded lazily on first use so the app starts even if the
.h5 file is absent – missing-model requests return HTTP 503.

Normalisation choice: pixel values are scaled to [0, 1] (divided by 255).
This matches the normalisation confirmed in the existing project codebase.
If the model was instead trained with tf.keras.applications.resnet50.preprocess_input
(channel-wise mean subtraction), replace the /255.0 block with that call.
"""

import io
import logging
import time

import numpy as np
import tensorflow as tf
from PIL import Image

from core.config import settings

logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------
# Class labels – order matches flow_from_directory alphabetical assignment
# for corn_final_model (1).h5  (confirmed output_shape=(None, 6)):
#   0=Healthy  1=KAB  2=NAB  3=Not_Corn  4=PAB  5=ZNAB
CLASS_NAMES: list[str] = [
    "Healthy",    # index 0
    "KAB",        # index 1 – Potassium deficiency
    "NAB",        # index 2 – Nitrogen deficiency
    "Not_Corn",   # index 3
    "PAB",        # index 4 – Phosphorus deficiency
    "ZNAB",       # index 5 – Zinc deficiency
]

ALLOWED_CONTENT_TYPES: frozenset[str] = frozenset({
    "image/jpeg",
    "image/jpg",
    "image/png",
    # Some mobile clients (Flutter http package) send octet-stream when
    # no explicit content-type is set; PIL validates the actual bytes.
    "application/octet-stream",
})

MAX_FILE_SIZE_BYTES: int = 5 * 1024 * 1024  # 5 MB

MODEL_VERSION: str = "resnet50_multi_nutrient_finetuned_v1"

_model = None


# ---------------------------------------------------------------------------
# Model loading
# ---------------------------------------------------------------------------
def get_model():
    """Return the TF model, loading from disk on first call."""
    global _model
    if _model is None:
        path = settings.TF_MODEL_PATH
        logger.info("Loading TF model from %s …", path)
        if not path.exists():
            logger.error("TF model file not found: %s", path)
            return None
        try:
            _model = tf.keras.models.load_model(str(path), compile=False)
            logger.info("TF model loaded successfully.")
        except Exception as exc:
            logger.error("Failed to load TF model: %s", exc)
            return None
    return _model


# ---------------------------------------------------------------------------
# Preprocessing
# ---------------------------------------------------------------------------
def preprocess_image_bytes(file_bytes: bytes, target_size: tuple[int, int] = (224, 224)) -> np.ndarray:
    """
    Decode raw image bytes and prepare a (1, H, W, 3) float32 tensor.

    Normalisation: [0, 1] scaling (divide by 255) – confirmed from existing code.
    If the model used tf.keras.applications.resnet50.preprocess_input during
    training, replace the division with that call.
    """
    try:
        img = Image.open(io.BytesIO(file_bytes)).convert("RGB")
        img = img.resize(target_size, Image.LANCZOS)
        arr = np.array(img, dtype="float32") / 255.0
        arr = np.expand_dims(arr, axis=0)
        return arr
    except Exception as exc:
        raise ValueError(f"Failed to preprocess image: {exc}")


# ---------------------------------------------------------------------------
# Prediction
# ---------------------------------------------------------------------------
def predict_nutrient_status(file_bytes: bytes) -> dict:
    """
    Run inference and return a structured result dict containing:
      - primary prediction (label + confidence)
      - top_3: list of {class, probability} for multi-condition interpretation
      - all_probabilities: full softmax vector keyed by class name
      - inference_time_ms: wall-clock time of model.predict() in milliseconds
      - model_version: string identifier of the loaded model

    Raises:
        RuntimeError: model not loaded (caller should return HTTP 503).
        ValueError:   image could not be decoded (caller should return HTTP 422).
    """
    model = get_model()
    if model is None:
        raise RuntimeError("TF model is not available – file may be missing or failed to load.")

    x = preprocess_image_bytes(file_bytes)

    t0 = time.perf_counter()
    proba = model.predict(x, verbose=0)[0]
    inference_time_ms = round((time.perf_counter() - t0) * 1000, 2)

    # Primary prediction
    idx = int(np.argmax(proba))
    label = CLASS_NAMES[idx]
    confidence = float(proba[idx])

    # Top-3 predictions (sorted by probability, descending)
    top3_indices = np.argsort(proba)[::-1][:3]
    top_3 = [
        {"class": CLASS_NAMES[int(i)], "probability": round(float(proba[i]), 4)}
        for i in top3_indices
    ]

    # Full probability map keyed by class name
    all_probabilities = {
        cls: round(float(p), 4) for cls, p in zip(CLASS_NAMES, proba)
    }

    logger.info(
        "Nutrition prediction | label=%s confidence=%.2f%% inference_ms=%.1f",
        label, confidence * 100, inference_time_ms,
    )

    return {
        "label": label,
        "confidence": round(confidence, 4),
        "top_3": top_3,
        "all_probabilities": all_probabilities,
        "inference_time_ms": inference_time_ms,
        "model_version": MODEL_VERSION,
    }
