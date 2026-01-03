# backend/utils/inference.py

import numpy as np
from PIL import Image
import io
import tensorflow as tf
from pathlib import Path
import logging

logger = logging.getLogger(__name__)

# Class order must match training - alphabetically sorted
CLASS_NAMES = ['Healthy', 'KAB', 'NAB', 'PAB', 'ZNAB']

# Load model once (when server starts)
MODEL_PATH = Path(__file__).resolve().parent.parent / "models" / "resnet50_multi_nutrient_finetuned.h5"
_model = None

def get_model():
    global _model
    if _model is None:
        logger.info(f"Loading model from {MODEL_PATH}")
        if not MODEL_PATH.exists():
            raise FileNotFoundError(f"Model file not found: {MODEL_PATH}")
        _model = tf.keras.models.load_model(str(MODEL_PATH), compile=False)
        logger.info("Model loaded successfully")
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
    x = preprocess_image_bytes(file_bytes)
    # Use verbose=0 to suppress prediction output
    proba = model.predict(x, verbose=0)[0]  # shape: (5,)
    idx = int(np.argmax(proba))
    label = CLASS_NAMES[idx]
    confidence = float(proba[idx])
    logger.info(f"Predicted: {label} with confidence {confidence:.2%}")
    return label, confidence, proba.tolist()
