# Copilot Instructions – Corn Yield Prediction System

## Project Overview

This is a multi-platform corn yield prediction system with explainable ML (SHAP) and a three-tier architecture:

- **Frontend**: Flutter app ([frontend/corn_app/]) for Android/iOS/Web/Desktop
- **Yield Backend**: FastAPI ([yield-prediction-backend/]) for ML inference and SHAP explanations
- **Disease Backend**: FastAPI stub ([backend/]) for future expansion

## Architecture & Patterns

### Flutter Frontend

- Feature-based, flat structure: see [lib/features/diagnosis/presentation/pages/]
- No domain/data layers yet; all logic in UI pages
- API calls are made directly in pages using the `http` package; some use [lib/core/api/api_client.dart], others hardcode URLs
- Navigation: `Navigator.push` + `MaterialPageRoute` (no routing package)
- Localization: custom `AppLocalizations` ([lib/core/localization/app_localizations.dart]), supports en/si/ta
- Environment config: [lib/core/config/env.dart] (note: Android emulator uses `10.0.2.2`, web uses `127.0.0.1`)
- UI: Plantix-inspired (green palette, rounded cards, Material 3, Google Fonts)

### Backend ML Service

- [yield-prediction-backend/main.py]: FastAPI, loads sklearn pipeline with SHAP
- **Critical**: Model expects 23 features; only 6 are user-supplied, the rest are filled with hardcoded defaults in `build_full_row_from_simple()`
- Changing defaults in backend will affect predictions; keep aligned with training data
- SHAP explanations: top 5 features, with human-readable mapping via `BASE_LABELS` and `CAT_LABELS`

## Developer Workflows

### Backend

- Start: `cd yield-prediction-backend; uvicorn main:app --reload --port 8000`
- Requires `corn_yield_model.pkl` in backend folder
- Install: `pip install fastapi uvicorn pandas numpy joblib shap scikit-learn`

### Flutter App

- Start: `cd frontend/corn_app; flutter pub get; flutter run` (Android)
- For web: `flutter run -d chrome` (update [env.dart] for baseUrl)
- API health: `curl http://localhost:8000/`
- Test prediction: see example in this file

## Key Files & Examples

- [frontend/corn_app/lib/features/diagnosis/presentation/pages/main_dashboard_page.dart]: Home, language switcher
- [frontend/corn_app/lib/features/diagnosis/presentation/pages/corn_yield_page_enhanced.dart]: Main yield predictor, SHAP UI
- [yield-prediction-backend/main.py]: ML API, SHAP logic, feature defaults

## Project-Specific Conventions

- No state management library; all state is local to widgets
- No routing/state packages; navigation and state are manual
- API URLs: some use [Env.baseUrl], others are hardcoded (inconsistency)
- All SHAP explanations are grouped and displayed with user-selected categorical values

## Common Issues

- CORS: allow_origins=["*"] for dev; restrict in prod
- Model loading: `corn_yield_model.pkl` must match sklearn version
- Android emulator: use `10.0.2.2` for host access

## Future/Expansion

- [backend/] is a stub for disease detection
- No domain/data layers yet; consider refactoring API logic into services

---

For questions or unclear patterns, see referenced files or ask for clarification.
