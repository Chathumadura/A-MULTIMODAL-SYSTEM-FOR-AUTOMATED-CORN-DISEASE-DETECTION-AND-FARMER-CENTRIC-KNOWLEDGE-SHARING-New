from fastapi import FastAPI, File, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from PIL import Image
import numpy as np
import tensorflow as tf
import io

# ----------------------
# App initialization
# ----------------------
app = FastAPI(title="Pest Detection API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ----------------------
# Load model ONCE
# ----------------------
MODEL_PATH = "model/pest_model_final.keras"
model = tf.keras.models.load_model(MODEL_PATH, compile=False)

CLASS_NAMES = [
    "armyworm",
    "healthy",
    "leaf_blight",
    "zonocerus"
]

IMG_SIZE = 224

# ----------------------
# Utilities
# ----------------------
def preprocess_image(image: Image.Image):
    image = image.convert("RGB")
    image = image.resize((IMG_SIZE, IMG_SIZE))
    img_array = np.array(image) / 255.0
    img_array = np.expand_dims(img_array, axis=0)
    return img_array

# ----------------------
# Routes
# ----------------------
@app.get("/")
def root():
    return {"status": "Backend running"}

@app.post("/predict")
async def predict(file: UploadFile = File(...)):
    image_bytes = await file.read()
    image = Image.open(io.BytesIO(image_bytes))
    processed = preprocess_image(image)

    preds = model.predict(processed)
    class_id = int(np.argmax(preds))
    confidence = float(np.max(preds))

    return {
        "prediction": CLASS_NAMES[class_id],
        "confidence": round(confidence * 100, 2)
    }
