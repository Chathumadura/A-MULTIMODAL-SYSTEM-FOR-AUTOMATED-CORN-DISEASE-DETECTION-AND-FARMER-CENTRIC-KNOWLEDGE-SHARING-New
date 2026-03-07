from fastapi import APIRouter, File, HTTPException, UploadFile
from PIL import Image
import numpy as np
import tensorflow as tf
import io
import logging


logger = logging.getLogger(__name__)

router = APIRouter(prefix="/pest", tags=["pest detection"])

MODEL_PATH = "models/pest_model_final.keras"

try:
    pest_model = tf.keras.models.load_model(MODEL_PATH, compile=False)
    logger.info("Pest detection model loaded from %s", MODEL_PATH)
except Exception as exc:  # pragma: no cover - startup diagnostics
    pest_model = None
    logger.error("Failed to load pest detection model from %s: %s", MODEL_PATH, exc)


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

