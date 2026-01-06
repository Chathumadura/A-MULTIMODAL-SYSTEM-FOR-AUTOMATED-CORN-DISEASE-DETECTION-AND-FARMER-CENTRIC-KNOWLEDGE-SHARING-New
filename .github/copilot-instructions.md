# Copilot Instructions - Corn Yield Prediction System

## Project Overview
Multi-platform corn yield prediction system with ML-driven SHAP explanations. Three-tier architecture:
- **Frontend**: Flutter app ([frontend/corn_app/](../frontend/corn_app/)) - cross-platform (Android/iOS/Web/Desktop)
- **Yield Backend**: FastAPI server ([yield-prediction-backend/](../yield-prediction-backend/)) - ML inference with SHAP
- **Disease Backend**: FastAPI stub ([backend/](../backend/)) - planned future expansion

## Architecture Patterns

### Flutter Frontend Structure
Feature-based organization following clean architecture principles:
```
lib/
├── main.dart                    # App entry, locale management
├── core/
│   ├── api/api_client.dart      # HTTP wrapper using Env.baseUrl
│   ├── config/env.dart          # Environment config (API URLs)
│   └── localization/            # i18n support (en/si/ta)
└── features/
    └── diagnosis/
        └── presentation/pages/  # UI pages (no domain/data layers yet)
```

**Key conventions**:
- Pages use stateful widgets with form validation and HTTP calls directly (no repositories yet)
- Navigation via `Navigator.push` + `MaterialPageRoute` (no routing package)
- Localization uses custom `AppLocalizations` delegate (see [lib/core/localization/app_localizations.dart](../frontend/corn_app/lib/core/localization/app_localizations.dart))
- API calls hardcoded in pages with `http` package - both via `ApiClient` and direct calls coexist

### Backend ML Service
**Critical**: Model expects specific features with exact defaults for unspecified fields.

[yield-prediction-backend/main.py](../yield-prediction-backend/main.py) structure:
- `SimpleYieldRequest`: Minimal user input (6 fields: district, farm_size, variety, rainfall, fertilizer, previous_yield)
- `build_full_row_from_simple()`: Fills 17 additional fields with hardcoded defaults (lines 110-135)
- SHAP explainer requires all 23 features transformed through sklearn pipeline
- Feature names mapping: `BASE_LABELS` (numeric) + `CAT_LABELS` (categorical) for human-readable display

**Default values matter**: Changing defaults in `build_full_row_from_simple()` affects predictions. Keep aligned with training data.

## Development Workflows

### Running the Backend
```powershell
cd yield-prediction-backend
# Install: pip install fastapi uvicorn pandas numpy joblib shap scikit-learn
uvicorn main:app --reload --port 8000
```
**Required**: `corn_yield_model.pkl` must exist in `yield-prediction-backend/` (trained sklearn pipeline).

### Running Flutter App
```powershell
cd frontend/corn_app
flutter pub get
flutter run  # For Android emulator
# flutter run -d chrome  # For web testing
```

**API connectivity**:
- Android emulator: Uses `http://10.0.2.2:8000` (see [lib/core/config/env.dart](../frontend/corn_app/lib/core/config/env.dart))
- Web/Desktop: Change to `http://127.0.0.1:8000`
- Inconsistency exists: Some pages use `Env.baseUrl`, others hardcode the URL

### Testing API Connection
```powershell
# Health check
curl http://localhost:8000/
# Test prediction
curl -X POST http://localhost:8000/predict_yield -H "Content-Type: application/json" -d '{
  "district": "Ampara", "farm_size_acres": 5.0, "variety": "CP808",
  "seasonal_rainfall_mm": 1200.0, "fertilizer_kg_per_acre": 50.0,
  "previous_yield_kg_per_acre": 3000.0
}'
```

## UI/UX Patterns

### Plantix-Inspired Design
- Green color scheme (`ColorScheme.fromSeed(seedColor: Colors.green)`)
- Rounded cards with bold CTAs
- Material 3 design system
- Google Fonts integration for typography

### Key Pages
- [main_dashboard_page.dart](../frontend/corn_app/lib/features/diagnosis/presentation/pages/main_dashboard_page.dart): Home with language switcher (🇬🇧/🇱🇰)
- [corn_yield_page_enhanced.dart](../frontend/corn_app/lib/features/diagnosis/presentation/pages/corn_yield_page_enhanced.dart): Production yield predictor with animations
- [corn_yield_page.dart](../frontend/corn_app/lib/features/diagnosis/presentation/pages/corn_yield_page.dart): Simpler yield predictor (legacy)
- [nutrient_prediction_page.dart](../frontend/corn_app/lib/features/diagnosis/presentation/pages/nutrient_prediction_page.dart): Placeholder for future nutrient analysis

## Common Issues & Solutions

### CORS Errors
Backend configured with `allow_origins=["*"]` for development. Restrict in production.

### Model Loading Failures
Ensure `corn_yield_model.pkl` is present and matches the expected sklearn version. Pipeline requires `preprocessor` and `model` steps.

### Android Emulator Network
Flutter cannot reach `localhost` - must use `10.0.2.2` to access host machine's ports.

## Dependencies

### Backend (Python)
```
fastapi==0.115.0
uvicorn==0.30.6
pandas, numpy, joblib, shap, scikit-learn (versions in training environment)
```

### Frontend (Flutter)
```yaml
http: ^1.2.0            # HTTP client
google_fonts: ^6.2.1    # Typography
path_provider: ^2.1.1   # File system access
flutter_localizations   # i18n SDK
```

## Future Architecture Notes
- `backend/` exists as placeholder for disease detection (only has health check endpoint)
- No domain/data layers in Flutter yet - all logic in presentation
- No state management library - local state only
- Consider refactoring API calls from pages into repositories/services
