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
from pathlib import Path
from typing import Any

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

# Git-LFS pointer files start with this ASCII prefix.  If Render cloned the
# repo without LFS support the .h5 on disk is a tiny text pointer, not the
# real binary, so TF would fail with a cryptic HDF5 error instead of a clear
# "file not found".
_LFS_SIGNATURE: bytes = b"version https://git-lfs"
# Real .h5 HDF5 files start with the HDF5 superblock magic bytes.
_HDF5_MAGIC: bytes = b"\x89HDF\r\n\x1a\n"
# Minimum realistic size for a real model file (1 MB)
_MIN_MODEL_BYTES: int = 1 * 1024 * 1024

_model: Any = None
_load_error: str = ""  # human-readable failure reason, set on first failed load


# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------
def _check_file(path: Path) -> tuple[bool, str]:
    """
    Validate that *path* points to a real HDF5 model file.

    Returns:
        (ok: bool, reason: str)  – reason is empty when ok is True.
    """
    if not path.exists():
        return False, f"File not found: {path}"

    size = path.stat().st_size
    if size < _MIN_MODEL_BYTES:
        # Read first bytes to distinguish LFS pointer from other small files
        header = path.read_bytes()[:128]
        if header.startswith(_LFS_SIGNATURE):
            return False, (
                f"Git LFS pointer detected ({size} bytes). "
                "The real model binary was not downloaded. "
                "Run 'git lfs pull' or set TF_MODEL_URL to download it during build."
            )
        return False, (
            f"File is suspiciously small ({size} bytes < {_MIN_MODEL_BYTES} bytes). "
            "It may be corrupt or an LFS pointer."
        )

    # Check HDF5 magic bytes.
    header = path.read_bytes()[:8]
    if header != _HDF5_MAGIC:
        return False, (
            f"File does not start with HDF5 magic bytes (got {header!r}). "
            "The file may be corrupt or the wrong format."
        )

    return True, ""


# ---------------------------------------------------------------------------
# Model loading
# ---------------------------------------------------------------------------
def get_model() -> Any:
    """Return the loaded TF model, or None if loading failed."""
    global _model, _load_error
    if _model is not None:
        return _model

    path: Path = settings.TF_MODEL_PATH.resolve()
    logger.info("[TF] Resolved model path : %s", path)
    logger.info("[TF] File exists          : %s", path.exists())
    if path.exists():
        logger.info("[TF] File size (bytes)    : %s", path.stat().st_size)

    ok, reason = _check_file(path)
    if not ok:
        _load_error = reason
        logger.error("[TF] Pre-load check FAILED: %s", reason)
        return None

    logger.info("[TF] Pre-load check passed. Loading with tf.keras …")
    try:
        _model = tf.keras.models.load_model(str(path), compile=False)
        _load_error = ""
        logger.info("[TF] Model loaded successfully. Input shape: %s", _model.input_shape)
    except Exception as exc:
        _load_error = f"tf.keras.models.load_model raised: {exc}"
        logger.error("[TF] Load FAILED: %s", _load_error)
        return None

    return _model


def get_tf_diagnostics() -> dict:
    """
    Return a diagnostic snapshot used by /health.

    Always safe to call; never raises.
    """
    path: Path = settings.TF_MODEL_PATH.resolve()
    exists = path.exists()
    size_bytes = path.stat().st_size if exists else None

    is_lfs = False
    if exists and size_bytes is not None and size_bytes < _MIN_MODEL_BYTES:
        try:
            header = path.read_bytes()[:128]
            is_lfs = header.startswith(_LFS_SIGNATURE)
        except OSError:
            pass

    return {
        "model_loaded": _model is not None,
        "model_path": str(path),
        "file_exists": exists,
        "file_size_bytes": size_bytes,
        "is_lfs_pointer": is_lfs,
        "load_error": _load_error or None,
        "model_version": MODEL_VERSION,
    }


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
