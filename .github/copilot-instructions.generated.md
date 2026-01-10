# Copilot Instructions — Corn Yield Prediction

Purpose: help AI coding agents be productive quickly in this repo: frontend Flutter app, a yield ML backend, and a stub disease backend.

Quick architecture

- Frontend: `frontend/corn_app/` — Flutter (feature pages under `lib/features/diagnosis/presentation/pages/`). UI-heavy; logic lives in pages.
- Yield ML backend: `yield-prediction-backend/` — FastAPI service that loads `corn_yield_model.pkl`, predicts and returns SHAP explanations.
- Disease backend stub: `backend/` — placeholder FastAPI service for future work.

Essential run commands

- Backend (dev):
  - `cd yield-prediction-backend`
  - `pip install -r requirements.txt` (or `pip install fastapi uvicorn pandas numpy joblib shap scikit-learn`)
  - `uvicorn main:app --reload --port 8000`
  - Health: `GET /` responds with a simple JSON
- Frontend (dev):
  - `cd frontend/corn_app`
  - `flutter pub get`
  - Android emulator: `flutter run` (ensure `lib/core/config/env.dart` uses `10.0.2.2` for host)
  - Web: `flutter run -d chrome` (use `127.0.0.1` for local web calls)

Critical backend details to preserve

- Endpoint: `POST /predict_yield` in `yield-prediction-backend/main.py` — accepts `SimpleYieldRequest` and returns `YieldResponse` with `top_contributing_features` (SHAP).
- Model expectations: pipeline expects ~23 features. The helper `build_full_row_from_simple()` (in `yield-prediction-backend/main.py`) fills many defaults — changing these defaults will change predictions. Keep defaults in sync with training data and `corn_yield_model.pkl`.
- SHAP: `TreeExplainer(model)` is used; feature names come from the preprocessor OHE. Human-friendly names are in `BASE_LABELS` and `CAT_LABELS`.

Frontend conventions & patterns

- No global state library: state is local to widgets and pages. See `main_dashboard_page.dart` and `corn_yield_page_enhanced.dart` for patterns.
- API calls: mostly direct `http` requests inside pages. There is an `api_client.dart` but some pages hardcode URLs — search for `Env.baseUrl` and `http.` to find usages.
- Routing: `Navigator.push` + `MaterialPageRoute` everywhere (no router package).
- Localization: custom `AppLocalizations` at `lib/core/localization/app_localizations.dart` (languages: en/si/ta).

Integration notes

- The frontend calls the yield backend `POST /predict_yield` with the small `SimpleYieldRequest` form; backend expands it via `build_full_row_from_simple()` before prediction.
- Ensure `corn_yield_model.pkl` is present in `yield-prediction-backend/` and built with a compatible sklearn version.
- CORS is wide-open in dev (`allow_origins=["*"]`) — tighten this for production.

Where to look first (examples)

- UI + entry: `frontend/corn_app/lib/main.dart`
- Dashboard page: `frontend/corn_app/lib/features/diagnosis/presentation/pages/main_dashboard_page.dart`
- Yield page + SHAP UI: `frontend/corn_app/lib/features/diagnosis/presentation/pages/corn_yield_page_enhanced.dart`
- Backend ML API: `yield-prediction-backend/main.py`

Editing guidance for agents

- Do not change `build_full_row_from_simple()` defaults without a corresponding retrain or note — it's the single source of truth for missing features.
- Prefer adding small service wrappers for API calls rather than editing many pages; the codebase is page-centric and inconsistent about `Env.baseUrl` usage.
- When modifying model behavior, include a test script or small example request showing the input -> output change.

If anything here is unclear or you'd like more examples (endpoints, sample requests, or a small test harness), tell me which part to expand.
