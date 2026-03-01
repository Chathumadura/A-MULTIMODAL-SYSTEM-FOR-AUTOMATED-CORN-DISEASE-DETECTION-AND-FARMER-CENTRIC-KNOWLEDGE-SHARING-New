"""
TensorFlow nutrient/disease inference utilities.

The model is loaded lazily on first use so the app starts even if the
.h5 file is absent – missing-model requests return HTTP 503.
"""

import io
import logging

import numpy as np
import tensorflow as tf
from PIL import Image

from core.config import settings

logger = logging.getLogger(__name__)

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

_model = None

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

def preprocess_image_bytes(file_bytes: bytes, target_size=(224, 224)):
    try:
        img = Image.open(io.BytesIO(file_bytes)).convert("RGB")
        img = img.resize(target_size)
        arr = np.array(img, dtype="float32") / 255.0
        arr = np.expand_dims(arr, axis=0)
        return arr
    except Exception as e:
        raise ValueError(f"Failed to preprocess image: {str(e)}")

def predict_nutrient_status(file_bytes: bytes):
    model = get_model()
    if model is None:
        raise ValueError("Model not available - model file may be missing or corrupted")
    x = preprocess_image_bytes(file_bytes)
    # Use verbose=0 to suppress prediction output
    proba = model.predict(x, verbose=0)[0]
    idx = int(np.argmax(proba))
    label = CLASS_NAMES[idx]
    confidence = float(proba[idx])
    logger.info(f"Predicted: {label} with confidence {confidence:.2%}")
    return label, confidence, proba.tolist()
