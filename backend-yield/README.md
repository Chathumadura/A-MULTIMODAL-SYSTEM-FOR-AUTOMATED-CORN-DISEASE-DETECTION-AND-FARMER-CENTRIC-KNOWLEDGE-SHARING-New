# backend-yield

Yield-only FastAPI service for CornXpert.

## Python Version

This service requires **Python 3.10** to ensure binary-compatible ML dependencies
(numpy, scikit-learn, xgboost). Newer versions (e.g., Python 3.14) can cause
build failures or runtime import errors when loading the existing `.pkl` model.

## Setup (Windows PowerShell)

```powershell
cd backend-yield
.\setup_env.ps1
```

## Run

```powershell
uvicorn main:app --reload --port 8081
```

Expected log:

```
[startup] ✓ Yield model ready.
```

## Quick Model Load Test

```powershell
python test_model_load.py
```

## Frontend Routing

- Yield prediction: `http://10.0.2.2:8081/yield/predict`
- All other APIs (nutrition/pest/fertilizer): `http://10.0.2.2:8080`
