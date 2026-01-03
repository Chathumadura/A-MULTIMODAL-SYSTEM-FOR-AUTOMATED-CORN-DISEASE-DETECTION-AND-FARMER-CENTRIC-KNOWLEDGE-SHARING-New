from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import pandas as pd
import numpy as np
import joblib
import shap

# ------------------- FastAPI app -------------------
app = FastAPI(
    title="Corn Yield Prediction API",
    description="Predict corn yield and explain main factors using SHAP",
    version="1.0.0",
)

# Allow frontend (browser) to call this API
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # in production, restrict this
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ------------------- Load model -------------------
MODEL_PATH = "corn_yield_model.pkl"  # must match the file in this folder

pipeline = joblib.load(MODEL_PATH)
preprocessor = pipeline.named_steps["preprocessor"]
model = pipeline.named_steps["model"]

# Get transformed feature names
numeric_features = preprocessor.transformers_[0][2]
categorical_features = preprocessor.transformers_[1][2]

ohe = preprocessor.named_transformers_["cat"]
cat_feature_names = ohe.get_feature_names_out(categorical_features)

all_feature_names = list(numeric_features) + list(cat_feature_names)

# Build SHAP explainer (tree-based model)
explainer = shap.TreeExplainer(model)

# ------------------- Pretty feature names -------------------
BASE_LABELS = {
    "farm_size_acres": "Farm size (acres)",
    "farmer_experience_years": "Farmer experience (years)",
    "access_to_credit": "Access to credit",
    "access_to_extension_services": "Access to extension services",
    "mechanization": "Use of machinery",
    "market_distance_km": "Distance to market (km)",
    "soil_ph": "Soil pH",
    "organic_matter_pct": "Organic matter (%)",
    "nitrogen_index": "Nitrogen level (index)",
    "phosphorus_index": "Phosphorus level (index)",
    "potassium_index": "Potassium level (index)",
    "seasonal_rainfall_mm": "Seasonal rainfall (mm)",
    "avg_temp_c": "Average temperature (°C)",
    "fertilizer_kg_per_acre": "Fertilizer (kg/acre)",
    "planting_density_plants_per_acre": "Planting density (plants/acre)",
    "previous_yield_kg_per_acre": "Previous yield (kg/acre)",
    "pest_disease_incidence": "Pest/disease level",
}

CAT_LABELS = {
    "district": "District",
    "agro_ecological_zone": "Agro-ecological zone",
    "soil_type": "Soil type",
    "variety": "Variety",
    "irrigation_type": "Irrigation type",
}

def pretty_feature_name(raw_name: str) -> str:
    if raw_name in BASE_LABELS:
        return BASE_LABELS[raw_name]

    parts = raw_name.split("_", 1)
    if len(parts) == 2:
        base_col, value = parts
        if base_col in CAT_LABELS:
            value_pretty = value.replace("_", " ")
            return f"{CAT_LABELS[base_col]}: {value_pretty}"

    fallback = raw_name.replace("_", " ")
    return fallback.capitalize()

# ------------------- Request / response models -------------------
class SimpleYieldRequest(BaseModel):
    # Fields the user will type in the form
    district: str
    farm_size_acres: float
    variety: str
    seasonal_rainfall_mm: float
    fertilizer_kg_per_acre: float
    previous_yield_kg_per_acre: float

class FeatureContribution(BaseModel):
    raw_name: str
    display_name: str
    shap_value: float

class YieldResponse(BaseModel):
    predicted_yield_kg_per_acre: float
    top_contributing_features: list[FeatureContribution]

# ------------------- Helper: build full feature row -------------------
def build_full_row_from_simple(req: SimpleYieldRequest) -> pd.DataFrame:
    # Defaults for fields not provided by user
    row = {
        "farm_id": 1,
        "district": req.district,
        "agro_ecological_zone": "IL2",
        "soil_type": "Loam",
        "farm_size_acres": req.farm_size_acres,
        "farmer_experience_years": 10,
        "access_to_credit": 1,
        "access_to_extension_services": 1,
        "mechanization": 0,
        "market_distance_km": 10.0,
        "variety": req.variety,
        "soil_ph": 6.4,
        "organic_matter_pct": 2.5,
        "nitrogen_index": 55.0,
        "phosphorus_index": 50.0,
        "potassium_index": 52.0,
        "seasonal_rainfall_mm": req.seasonal_rainfall_mm,
        "avg_temp_c": 27.0,
        "fertilizer_kg_per_acre": req.fertilizer_kg_per_acre,
        "planting_density_plants_per_acre": 18000,
        "irrigation_type": "Rainfed",
        "previous_yield_kg_per_acre": req.previous_yield_kg_per_acre,
        "pest_disease_incidence": 1,
    }
    return pd.DataFrame([row])

# ------------------- Endpoints -------------------
@app.get("/")
def root():
    return {"message": "Corn Yield API is running"}

@app.post("/predict_yield", response_model=YieldResponse)
def predict_yield(payload: SimpleYieldRequest):
    # 1. Build full row
    df = build_full_row_from_simple(payload)

    # 2. Predict
    pred = pipeline.predict(df)
    predicted_yield = float(pred[0])

    # 3. SHAP explanation
    X_transformed = preprocessor.transform(df)
    shap_values = explainer.shap_values(X_transformed)
    shap_instance = shap_values[0]

    # 4. Top N features
    top_n = 5
    idx_sorted = np.argsort(np.abs(shap_instance))[::-1]

    top_features = []
    for idx in idx_sorted[:top_n]:
        raw = all_feature_names[idx]
        display = pretty_feature_name(raw)
        top_features.append(
            FeatureContribution(
                raw_name=raw,
                display_name=display,
                shap_value=float(shap_instance[idx]),
            )
        )

    return YieldResponse(
        predicted_yield_kg_per_acre=predicted_yield,
        top_contributing_features=top_features,
    )
