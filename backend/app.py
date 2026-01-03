# backend/app.py

from fastapi import FastAPI, UploadFile, File, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from utils.inference import predict_nutrient_status, get_model
import logging

# Set up logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(title="Corn Nutrient Diagnosis API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],   # later restrict
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.on_event("startup")
async def startup_event():
    """Load model at startup to avoid first-request delays"""
    logger.info("Loading model at startup...")
    try:
        get_model()
        logger.info("Model loaded successfully")
    except Exception as e:
        logger.error(f"Failed to load model: {e}")

@app.get("/health")
def health():
    return {"status": "ok"}

@app.post("/predict")
async def predict(file: UploadFile = File(...)):
    try:
        logger.info(f"Received prediction request for file: {file.filename}")
        file_bytes = await file.read()
        logger.info(f"File size: {len(file_bytes)} bytes")
        
        label, confidence, probs = predict_nutrient_status(file_bytes)
        logger.info(f"Prediction complete: {label} ({confidence:.2%})")
        
        return {
            "predicted_class": label,
            "confidence": confidence,
            "probabilities": probs,
        }
    except ValueError as e:
        logger.error(f"Validation error: {e}")
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        logger.error(f"Prediction error: {e}")
        raise HTTPException(status_code=500, detail=f"Prediction failed: {str(e)}")
