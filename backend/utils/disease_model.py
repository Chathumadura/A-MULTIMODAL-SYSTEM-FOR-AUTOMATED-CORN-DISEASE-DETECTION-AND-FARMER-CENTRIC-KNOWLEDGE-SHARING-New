"""
Disease detection model utilities (disease_model.tflite).

The TFLite interpreter is loaded lazily on the very first prediction request so
that the app starts quickly and stays within Render free-tier memory limits.
When the model file is missing, disease endpoints return HTTP 503.

Why tf.lite.Interpreter instead of tf.keras.models.load_model?
──────────────────────────────────────────────────────────────
• .tflite files are FlatBuffer binaries, not HDF5/SavedModel archives.
  tf.keras.models.load_model() cannot read them and raises an HDF5 error.
• tf.lite.Interpreter is the correct runtime: it maps the FlatBuffer into
  RAM, allocates fixed input/output tensor buffers, and runs inference via
  set_tensor → invoke → get_tensor.

IMPORTANT – DISEASE_CLASS_NAMES must match the alphabetical flow_from_directory
order used when disease_model was trained.  Update the list below if your
training directory structure differs.
"""

from __future__ import annotations

import io
import logging

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

# Git-LFS pointer files start with this ASCII prefix.  If Render cloned the
# repo without LFS support the .tflite on disk is a tiny text pointer, not
# the real FlatBuffer binary.
_LFS_SIGNATURE: bytes = b"version https://git-lfs"
# Minimum realistic size for a real TFLite model file (1 MB).
_MIN_MODEL_BYTES: int = 1 * 1024 * 1024  # 1 MB

# Module-level singletons (populated on first call to get_disease_model).
_interpreter: "tf.lite.Interpreter | None" = None
_disease_load_error: str = ""


# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------
def _check_file(path) -> tuple[bool, str]:
    """
    Validate that *path* holds a real .tflite binary (not an LFS pointer).

    TFLite files use the FlatBuffers format – there is no universal magic-byte
    header to validate, so we check only for the LFS pointer signature and a
    minimum size threshold.

    Returns:
        (ok: bool, reason: str)  – reason is empty when ok is True.
    """
    if not path.exists():
        return False, f"File not found: {path}"

    size = path.stat().st_size
    if size < _MIN_MODEL_BYTES:
        header = path.read_bytes()[:128]
        if header.startswith(_LFS_SIGNATURE):
            return False, (
                f"Git LFS pointer detected ({size} bytes). "
                "The real .tflite binary was not downloaded. "
                "Set DISEASE_MODEL_URL on the Render dashboard to download it at startup."
            )
        return False, (
            f"File is suspiciously small ({size} bytes < {_MIN_MODEL_BYTES} bytes). "
            "It may be corrupt or an LFS pointer."
        )

    return True, ""


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------
def get_disease_model() -> "tf.lite.Interpreter | None":
    """Return the loaded TFLite disease interpreter (lazy, cached after first load).

    Returns:
        The tf.lite.Interpreter if successfully loaded, else None.
        None triggers an HTTP 503 response in the route handler.
    """
    global _interpreter, _disease_load_error

    # ── Cache hit ─────────────────────────────────────────────────────────────
    if _interpreter is not None:
        logger.debug("[disease] Cache hit – returning cached disease interpreter.")
        return _interpreter

    # ── First call: attempt to load ──────────────────────────────────────────
    logger.info("[disease] Lazy loading disease model (first request) …")
    path = settings.DISEASE_MODEL_PATH.resolve()
    logger.info("[disease] Resolved model path : %s", path)
    logger.info("[disease] File exists         : %s", path.exists())

    ok, reason = _check_file(path)
    if not ok:
        _disease_load_error = reason
        logger.error("[disease] Pre-load check FAILED: %s", reason)
        return None

    size = path.stat().st_size
    logger.info("[disease] File size (bytes)   : %d", size)

    logger.info("[disease] Creating tf.lite.Interpreter …")
    try:
        _interpreter = tf.lite.Interpreter(model_path=str(path))
        _interpreter.allocate_tensors()
        _disease_load_error = ""

        input_details = _interpreter.get_input_details()
        output_details = _interpreter.get_output_details()
        logger.info(
            "[disease] ✓ Disease interpreter ready."
            "  Input : index=%d  shape=%s  dtype=%s"
            "  Output: index=%d  shape=%s  dtype=%s",
            input_details[0]["index"],  input_details[0]["shape"],
            input_details[0]["dtype"].__name__,
            output_details[0]["index"], output_details[0]["shape"],
            output_details[0]["dtype"].__name__,
        )
    except Exception as exc:
        _disease_load_error = f"tf.lite.Interpreter raised: {exc}"
        logger.error(
            "[disease] ✗ Failed to load disease model from %s: %s", path, exc
        )
        _interpreter = None
        return None

    return _interpreter


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
