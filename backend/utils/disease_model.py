"""
Disease detection model utilities (disease_model.keras).

The Keras model is loaded lazily on the very first prediction request so
that the app starts quickly and stays within Render free-tier memory limits.
When the model file is missing, disease endpoints return HTTP 503.

IMPORTANT – CLASS_NAMES must match the alphabetical flow_from_directory
order used when disease_model.keras was trained.  Update the list below
if your training directory structure differs.
"""

from __future__ import annotations

import io
import logging
from typing import Any

import numpy as np
import tensorflow as tf
from PIL import Image

from core.config import settings

logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Class labels
# Update to match the exact alphabetical order produced by flow_from_directory
# (or ImageDataGenerator) when the model was trained.
# ---------------------------------------------------------------------------
DISEASE_CLASS_NAMES: list[str] = [
    "Blight",
    "Common_Rust",
    "Gray_Leaf_Spot",
    "Healthy",
    "Not_Corn",
]

# Image preprocessing constants – must match the training pipeline.
IMG_SIZE: int = 224

# Any file smaller than this is treated as corrupt or an LFS pointer.
_MIN_MODEL_BYTES: int = 1 * 1024 * 1024  # 1 MB

# Module-level singletons (populated on first call to get_disease_model).
_disease_model: Any = None
_disease_load_error: str = ""


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------
def get_disease_model() -> Any:
    """Return the loaded Keras disease model (lazy, cached after first load).

    Returns:
        The tf.keras.Model if successfully loaded, else None.
        None triggers an HTTP 503 response in the route handler.
    """
    global _disease_model, _disease_load_error

    # ── Cache hit ─────────────────────────────────────────────────────────────
    if _disease_model is not None:
        logger.debug("[disease] Cache hit – returning already-loaded disease model.")
        return _disease_model

    # ── First call: attempt to load ──────────────────────────────────────────
    logger.info("[disease] Lazy loading disease model (first request) …")
    path = settings.DISEASE_MODEL_PATH.resolve()
    logger.info("[disease] Resolved model path : %s", path)
    logger.info("[disease] File exists         : %s", path.exists())

    if not path.exists():
        _disease_load_error = f"File not found: {path}"
        logger.error("[disease] ✗ Model file missing at %s", path)
        return None

    size = path.stat().st_size
    logger.info("[disease] File size (bytes)   : %d", size)

    if size < _MIN_MODEL_BYTES:
        _disease_load_error = (
            f"File is suspiciously small ({size} bytes) – "
            "corrupt or Git LFS pointer."
        )
        logger.error("[disease] ✗ %s", _disease_load_error)
        return None

    try:
        _disease_model = tf.keras.models.load_model(str(path), compile=False)
        _disease_load_error = ""
        logger.info(
            "[disease] ✓ Disease model loaded successfully (input=%s).",
            _disease_model.input_shape,
        )
    except Exception as exc:
        _disease_load_error = str(exc)
        logger.error(
            "[disease] ✗ Failed to load disease model from %s: %s", path, exc
        )
        return None

    return _disease_model


def get_disease_load_error() -> str:
    """Return the human-readable load-failure reason, or empty string."""
    return _disease_load_error


def preprocess_disease_image(image_bytes: bytes) -> np.ndarray:
    """Decode *image_bytes* into a normalised (1, 224, 224, 3) float32 batch.

    Raises:
        Exception: if the bytes cannot be decoded as an image by PIL.
    """
    image = Image.open(io.BytesIO(image_bytes)).convert("RGB")
    image = image.resize((IMG_SIZE, IMG_SIZE))
    arr = np.array(image, dtype=np.float32) / 255.0
    return np.expand_dims(arr, axis=0)
