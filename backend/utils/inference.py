"""
TensorFlow Lite nutrient/disease inference utilities.

The TFLite interpreter is loaded lazily on the very first request to
/nutrition/predict and then cached for all subsequent requests.  The app
starts even if the .tflite file is absent – missing-model requests return
HTTP 503 gracefully.

Why tf.lite.Interpreter instead of tf.keras.models.load_model?
──────────────────────────────────────────────────────────────
• .tflite files are FlatBuffer binaries, not HDF5/SavedModel archives.
  tf.keras.models.load_model() cannot read them.
• tf.lite.Interpreter is the correct runtime for TFLite models:  it maps
  the FlatBuffer directly into RAM, allocates fixed input/output tensor
  buffers, and runs inference via set_tensor → invoke → get_tensor.
• TFLite has a dramatically smaller RAM footprint than the full Keras graph
  runtime, which is critical for Render's free-tier 512 MB limit.

Normalisation: pixel values are scaled to [0, 1] (÷ 255) to match the
training pipeline.  Update preprocess_image_bytes() if a different
normalisation was used during training.
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
MODEL_VERSION: str = "corn_final_model_v1_tflite"

# Git-LFS pointer files start with this ASCII prefix.  If Render cloned the
# repo without LFS support the .tflite on disk is a tiny text pointer, not
# the real FlatBuffer binary, so TFLite would raise an opaque error instead
# of a clear "file not found".
_LFS_SIGNATURE: bytes = b"version https://git-lfs"
# Minimum realistic size for a real TFLite model file (1 MB).
# TFLite files are FlatBuffers – no universal magic-byte header to check.
_MIN_MODEL_BYTES: int = 1 * 1024 * 1024

# TFLite interpreter singleton – None until first call to get_model().
# Using tf.lite.Interpreter (not tf.keras.models.load_model) because
# .tflite files are FlatBuffer binaries that Keras cannot read.
_interpreter: "tf.lite.Interpreter | None" = None
_load_error: str = ""  # human-readable failure reason, set on first failed load


# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------
def _check_file(path: Path) -> tuple[bool, str]:
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
        # Read the first bytes to distinguish an LFS pointer from other small files.
        header = path.read_bytes()[:128]
        if header.startswith(_LFS_SIGNATURE):
            return False, (
                f"Git LFS pointer detected ({size} bytes). "
                "The real .tflite binary was not downloaded. "
                "Set TF_MODEL_URL on the Render dashboard to download it at startup."
            )
        return False, (
            f"File is suspiciously small ({size} bytes < {_MIN_MODEL_BYTES} bytes). "
            "It may be corrupt or an LFS pointer."
        )

    return True, ""


# ---------------------------------------------------------------------------
# Model loading (lazy, cached)
# ---------------------------------------------------------------------------
def get_model() -> "tf.lite.Interpreter | None":
    """
    Return the loaded TFLite interpreter (lazy, cached after first load).

    First call:
      1. Validates the .tflite file exists and is not an LFS pointer.
      2. Creates a tf.lite.Interpreter from the file path.
      3. Calls allocate_tensors() to pre-allocate input/output buffers.
      4. Caches the interpreter in the module-level _interpreter variable.

    Subsequent calls:
      Return the cached interpreter immediately (no file I/O, no allocation).

    Returns None on any failure; the caller should respond with HTTP 503.
    """
    global _interpreter, _load_error

    # ── Cache hit: interpreter already loaded ─────────────────────────────────
    if _interpreter is not None:
        logger.debug("[TFLite] Cache hit – returning cached nutrition interpreter.")
        return _interpreter

    # ── First call: load the TFLite model ────────────────────────────────────
    logger.info("[TFLite] Lazy loading nutrition model (first request) …")
    path: Path = settings.TF_MODEL_PATH.resolve()
    logger.info("[TFLite] Resolved model path : %s", path)
    logger.info("[TFLite] File exists          : %s", path.exists())
    if path.exists():
        logger.info("[TFLite] File size (bytes)    : %d", path.stat().st_size)

    ok, reason = _check_file(path)
    if not ok:
        _load_error = reason
        logger.error("[TFLite] Pre-load check FAILED: %s", reason)
        return None

    logger.info("[TFLite] Pre-load check passed. Creating tf.lite.Interpreter …")
    try:
        # tf.lite.Interpreter reads the .tflite FlatBuffer from disk.
        # allocate_tensors() pre-allocates the fixed input/output buffers
        # so inference can run without additional heap allocation per call.
        _interpreter = tf.lite.Interpreter(model_path=str(path))
        _interpreter.allocate_tensors()
        _load_error = ""

        input_details = _interpreter.get_input_details()
        output_details = _interpreter.get_output_details()
        logger.info(
            "[TFLite] ✓ Nutrition interpreter ready."
            "  Input : index=%d  shape=%s  dtype=%s"
            "  Output: index=%d  shape=%s  dtype=%s",
            input_details[0]["index"],  input_details[0]["shape"],
            input_details[0]["dtype"].__name__,
            output_details[0]["index"], output_details[0]["shape"],
            output_details[0]["dtype"].__name__,
        )
    except Exception as exc:
        _load_error = f"tf.lite.Interpreter raised: {exc}"
        # logger.exception logs the full traceback, not just the string – this
        # is critical for diagnosing mismatched TF ops, corrupt flatbuffers, etc.
        logger.exception("[TFLite] ✗ Load FAILED (full traceback follows): %s", _load_error)
        _interpreter = None
        return None

    return _interpreter


def get_load_error() -> str:
    """Return the human-readable load-failure reason, or empty string."""
    return _load_error


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
        "model_loaded": _interpreter is not None,
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
    logger.info("[nutrition] predict_nutrient_status called (%d bytes)", len(file_bytes))

    interpreter = get_model()
    if interpreter is None:
        reason = _load_error or "model file may be missing or failed to load"
        logger.error("[nutrition] ✗ Model not available. Reason: %s", reason)
        raise RuntimeError(f"TF model is not available. Reason: {reason}")

    logger.info("[nutrition] Model cache hit. Preprocessing image …")
    x = preprocess_image_bytes(file_bytes)

    # TFLite inference: write input → invoke → read output.
    # This is the correct pattern for tf.lite.Interpreter.
    # model.predict() does not exist on Interpreter objects.
    input_details  = interpreter.get_input_details()
    output_details = interpreter.get_output_details()

    logger.info(
        "[nutrition] Input tensor  : index=%d  shape=%s  dtype=%s",
        input_details[0]["index"], input_details[0]["shape"],
        input_details[0]["dtype"].__name__,
    )
    logger.info(
        "[nutrition] Output tensor : index=%d  shape=%s  dtype=%s",
        output_details[0]["index"], output_details[0]["shape"],
        output_details[0]["dtype"].__name__,
    )
    logger.info(
        "[nutrition] Preprocessed array: shape=%s  dtype=%s  min=%.4f  max=%.4f",
        x.shape, x.dtype, float(x.min()), float(x.max()),
    )

    t0 = time.perf_counter()
    try:
        interpreter.set_tensor(input_details[0]["index"], x)
        interpreter.invoke()
        proba = interpreter.get_tensor(output_details[0]["index"])[0]
    except Exception as exc:
        logger.exception("[nutrition] ✗ TFLite inference op failed: %s", exc)
        raise RuntimeError(f"TFLite inference failed: {exc}") from exc
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
