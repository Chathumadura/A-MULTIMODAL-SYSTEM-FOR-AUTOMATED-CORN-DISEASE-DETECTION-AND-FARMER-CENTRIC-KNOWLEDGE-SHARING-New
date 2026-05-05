# 🌽 Corn Yield Prediction System — Technical Reference

## 1. System Overview

CornXpert is a multi-surface crop analytics system with two backend implementations and a Flutter frontend. The repository contains a unified FastAPI backend in [backend/main.py](backend/main.py), a yield-only FastAPI backend in [backend-yield/main.py](backend-yield/main.py), and a Flutter application in [frontend/corn_app/lib/main.dart](frontend/corn_app/lib/main.dart).

In practice, the codebase is organized around four user-facing capabilities:

1. Leaf-image nutrient diagnosis with fertilizer recommendations, served by the unified backend through `/nutrition/predict` and the lookup table in [backend/utils/fertilizer_recommendations.py](backend/utils/fertilizer_recommendations.py).
2. Yield prediction with SHAP explanations, served by the unified backend through `/yield/predict` and `/yield/explain` using [backend/utils/yield_model.py](backend/utils/yield_model.py) and [backend/services/yield_service.py](backend/services/yield_service.py).
3. Pest detection, served by the unified backend through `/pest/predict` in [backend/routes/pest_routes.py](backend/routes/pest_routes.py).
4. A Flutter front end that routes users to disease, nutrient, pest, and yield screens from [frontend/corn_app/lib/features/diagnosis/presentation/pages/main_dashboard_page.dart](frontend/corn_app/lib/features/diagnosis/presentation/pages/main_dashboard_page.dart).

The repository also contains a separate yield-only backend under [backend-yield/](backend-yield/) that exposes the same yield/fertilizer concept on a narrower service surface. The Flutter app and the Render deployment manifest point to the unified backend in [render.yaml](render.yaml), so the yield-only backend appears to be an alternate or experimental service rather than the primary deployed path.

## 2. Dataset & Features

The only explicit dataset artifact in the repository is [notebooks/corn-yield/anuradhapura_corn_yield_dataset.csv](notebooks/corn-yield/anuradhapura_corn_yield_dataset.csv). It contains 1,500 rows and 10 columns:

| Column                     | Type in CSV                                         | Role          |
| -------------------------- | --------------------------------------------------- | ------------- |
| district                   | categorical                                         | input feature |
| farm_size_acres            | numeric                                             | input feature |
| variety                    | categorical                                         | input feature |
| soil_type                  | categorical                                         | input feature |
| irrigation_type            | categorical                                         | input feature |
| seasonal_rainfall_mm       | numeric                                             | input feature |
| fertilizer_kg_per_acre     | numeric                                             | input feature |
| previous_yield_kg_per_acre | numeric                                             | input feature |
| pest_disease_level         | numeric in CSV, categorical after notebook cleaning | input feature |
| yield_kg_per_acre          | numeric                                             | target        |

The CSV is not raw field data. It is generated in [notebooks/corn-yield/dataset_creation.ipynb](notebooks/corn-yield/dataset_creation.ipynb) using probabilistic samplers and a rule-based yield formula. The notebook states the data sources it used in markdown, but the actual generated data is synthetic.

Important feature semantics from the notebook and code:

1. `district` is fixed to `Anuradhapura` in the generated dataset.
2. `variety` takes `Hybrid_A`, `Hybrid_B`, or `OPV_Local`.
3. `soil_type` takes `Loam`, `Sandy`, or `Clay`.
4. `irrigation_type` takes `Rainfed`, `Tank`, `Canal`, or `Tube well`.
5. `pest_disease_level` is written numerically in the CSV, then cleaned to `None`, `Low`, `Medium`, and `High` in the training notebook [notebooks/corn-yield/ResearchNew (1).ipynb](<notebooks/corn-yield/ResearchNew%20(1).ipynb>).

The notebook-generation logic in [notebooks/corn-yield/dataset_creation.ipynb](notebooks/corn-yield/dataset_creation.ipynb) explicitly models the dataset as:

1. Variety weights: hybrid vs OPV/local proportions.
2. Soil and irrigation weights based on Anuradhapura distribution assumptions.
3. Continuous samplers for rainfall, farm size, and fertilizer usage.
4. A deterministic-style yield computation function that multiplies several modifiers and adds Gaussian noise.

## 3. Machine Learning Pipeline

The repository contains one complete, explicit training pipeline for yield prediction in [notebooks/corn-yield/ResearchNew (1).ipynb](<notebooks/corn-yield/ResearchNew%20(1).ipynb>). Nutrition and pest classifiers are only present as serialized-model inference code; their training procedure is not clearly defined in code.

### 3.1 Data Preprocessing

The yield training notebook reads `anuradhapura_corn_yield_dataset.csv`, keeps the columns used by the app, and cleans categorical values before training.

Observed preprocessing steps in the notebook:

1. Trim and normalize categorical text.
2. Map category variants into canonical labels, for example `Hybrid A` to `Hybrid_A` and `Tube_well` to `Tube well`.
3. Convert numeric columns with `pd.to_numeric(..., errors="coerce")`.
4. Clip outliers with an IQR-based function before splitting the data.
5. Split into train/test sets with `train_test_split(..., test_size=0.2, random_state=42)`.

The notebook does not apply scaling. It uses a `ColumnTransformer` with two branches:

1. Categorical branch: `SimpleImputer(strategy="most_frequent")` + `OneHotEncoder(handle_unknown="ignore")`.
2. Numeric branch: `SimpleImputer(strategy="median")`.

This preprocessing pipeline is defined in [notebooks/corn-yield/ResearchNew (1).ipynb](<notebooks/corn-yield/ResearchNew%20(1).ipynb>) and is the core training contract for the yield model.

### 3.2 Feature Engineering

The notebook uses a fixed input feature set of 9 predictor columns:

1. district
2. variety
3. soil_type
4. irrigation_type
5. pest_disease_level
6. farm_size_acres
7. seasonal_rainfall_mm
8. fertilizer_kg_per_acre
9. previous_yield_kg_per_acre

The encoded feature names are derived from `OneHotEncoder.get_feature_names_out(cat_cols)` plus the numeric columns. The notebook also prints feature importance for tree models when the chosen estimator exposes `feature_importances_`.

There is no evidence of engineered interaction terms, normalization, or feature selection beyond the one-hot encoding and imputation above.

### 3.3 Model Training

The training notebook compares three estimators:

1. `RandomForestRegressor`
2. `GradientBoostingRegressor`
3. `XGBRegressor`

Each model is wrapped in a `Pipeline` that combines the `preprocessor` and the estimator. The notebook trains every candidate on the training set, predicts on the test set, and also runs 5-fold cross-validation with `cross_val_score(..., scoring="r2")`.

The notebook imports `scikit-learn`, `xgboost`, `joblib`, and uses `warnings.filterwarnings("ignore")` to suppress warnings during experimentation.

### 3.4 Model Evaluation

The notebook evaluates each candidate using:

1. MAE
2. RMSE
3. R² on the holdout test set
4. Mean and standard deviation of cross-validated R²

The evaluation is printed to notebook output, and the notebook also displays a results table sorted by RMSE.

No custom business metric is defined in code. The selection criterion is plain RMSE on the holdout test split.

### 3.5 Model Selection

The selected model is the one with the lowest RMSE among the three candidate pipelines. The notebook stores that pipeline in `best_pipeline` and persists it with:

`joblib.dump(best_pipeline, "corn_yield_model_best.pkl")`

That save step is visible in [notebooks/corn-yield/ResearchNew (1).ipynb](<notebooks/corn-yield/ResearchNew%20(1).ipynb>).

Important gap: the notebook saves `corn_yield_model_best.pkl`, but the backend code expects `corn_yield_model.pkl`. The repository does not clearly show the conversion or rename step that produces the deployed artifact.

### 3.6 Model Serialization

The yield backend loads a serialized scikit-learn pipeline with `joblib.load(...)`. In the unified backend this happens in [backend/utils/yield_model.py](backend/utils/yield_model.py), and in the yield-only backend it happens in [backend-yield/utils/yield_model.py](backend-yield/utils/yield_model.py).

For the image-based nutrient classifier, the unified backend loads a TensorFlow `.h5` model with `tf.keras.models.load_model(..., compile=False)` in [backend/utils/inference.py](backend/utils/inference.py). The code validates that the file is not a Git LFS pointer and that it has HDF5 magic bytes before loading.

For the pest classifier, the unified backend loads `models/pest_model_final.keras` directly inside [backend/routes/pest_routes.py](backend/routes/pest_routes.py) at import time.

## 4. Inference Pipeline

### Step-by-step execution

The live inference flow depends on which capability the user invokes. The repository contains three distinct runtime inference paths.

1. Nutrient diagnosis path
   1. The Flutter app uploads an image through `ApiClient.uploadImageForPrediction(...)` in [frontend/corn_app/lib/core/api/api_client.dart](frontend/corn_app/lib/core/api/api_client.dart).
   2. The request reaches `POST /nutrition/predict` in [backend/routes/nutrition_routes.py](backend/routes/nutrition_routes.py).
   3. The route validates content type, file size, and non-empty uploads before calling `run_nutrition_diagnosis(...)` in [backend/services/nutrition_service.py](backend/services/nutrition_service.py).
   4. `run_nutrition_diagnosis(...)` calls `predict_nutrient_status(...)` in [backend/utils/inference.py](backend/utils/inference.py).
   5. The image is decoded with PIL, resized to 224×224, converted to RGB, and normalized by dividing by 255.0.
   6. The TensorFlow model produces class probabilities.
   7. The service returns the top class, confidence, top-3 predictions, full probability map, inference time, and model version.
   8. `run_nutrition_diagnosis(...)` adds fertilizer recommendations from [backend/utils/fertilizer_recommendations.py](backend/utils/fertilizer_recommendations.py).
   9. If the top class is `Not_Corn` and confidence exceeds the threshold defined in [backend/services/nutrition_service.py](backend/services/nutrition_service.py), the response short-circuits with a non-corn message and no fertilizer advice.

2. Yield prediction path
   1. The Flutter form in [frontend/corn_app/lib/features/diagnosis/presentation/pages/corn_yield_page_enhanced.dart](frontend/corn_app/lib/features/diagnosis/presentation/pages/corn_yield_page_enhanced.dart) collects district, variety, soil type, irrigation type, farm size, rainfall, fertilizer, previous yield, and pest level.
   2. `_submit()` sends JSON to `POST /yield/predict` through `ApiClient.postJsonRaw(...)`.
   3. The route in [backend/routes/yield_routes.py](backend/routes/yield_routes.py) validates the request with a Pydantic `YieldRequest` model.
   4. The service in [backend/services/yield_service.py](backend/services/yield_service.py) calls `build_full_row(...)` from [backend/utils/yield_model.py](backend/utils/yield_model.py).
   5. `build_full_row(...)` creates a one-row pandas DataFrame with hard-coded defaults for features that the UI does not collect.
   6. The scikit-learn pipeline predicts yield.
   7. The preprocessor transforms the row, SHAP values are computed with `shap.TreeExplainer`, and the top features are returned by absolute SHAP magnitude.
   8. The API returns the predicted yield and the top contributing features.

3. Pest detection path
   1. The Flutter pest screen uploads an image through `uploadImageForPestDetection(...)` in [frontend/corn_app/lib/core/api/api_client.dart](frontend/corn_app/lib/core/api/api_client.dart).
   2. The request reaches `POST /pest/predict` in [backend/routes/pest_routes.py](backend/routes/pest_routes.py).
   3. The route reads the file bytes, checks that the file is non-empty, and attempts to decode it with PIL.
   4. The image is resized to 224×224, scaled to `[0, 1]`, and fed to the Keras model.
   5. The response returns `prediction`, `confidence` as a percentage value, and a message. If confidence is below 0.5, the backend returns `not_corn_leaf`.

## 5. Backend Architecture

### 5.1 API Layer (routes)

The unified backend registers routers in [backend/main.py](backend/main.py):

1. `/nutrition` from [backend/routes/nutrition_routes.py](backend/routes/nutrition_routes.py)
2. `/yield` from [backend/routes/yield_routes.py](backend/routes/yield_routes.py)
3. `/fertilizer` from [backend/routes/fertilizer_routes.py](backend/routes/fertilizer_routes.py)
4. `/pest` from [backend/routes/pest_routes.py](backend/routes/pest_routes.py)

Observed endpoint contracts in the unified backend:

1. `POST /nutrition/predict`
   - Input: multipart file field named `file`
   - Output: `status`, `predicted_class`, `confidence`, `is_corn`, `top_3`, `all_probabilities`, `fertilizer_recommendations`, `inference_time_ms`, `model_version`
   - Non-corn responses include multilingual messages (`message`, `message_si`, `message_ta`)

2. `POST /yield/predict`
   - Input: JSON payload validated by `YieldRequest`
   - Output: predicted yield plus top SHAP contributors

3. `POST /yield/explain`
   - Same payload and response structure as `/yield/predict`

4. `GET /fertilizer/recommendations/{label}`
   - Output: the recommendation dictionary for the class label

5. `GET /fertilizer/labels`
   - Output: supported labels list

6. `POST /pest/predict`
   - Input: multipart file field named `file`
   - Output: pest label, confidence, and message

The yield-only backend registers only `/yield` and `/fertilizer` in [backend-yield/main.py](backend-yield/main.py).

### 5.2 Service Layer

The unified backend uses a thin service layer for the image model and the yield model:

1. [backend/services/nutrition_service.py](backend/services/nutrition_service.py) orchestrates image inference, Not_Corn guarding, and fertilizer recommendation injection.
2. [backend/services/yield_service.py](backend/services/yield_service.py) orchestrates row building, prediction, SHAP extraction, and response shaping.
3. [backend/services/fertilizer_service.py](backend/services/fertilizer_service.py) is a simple wrapper around the lookup table.

The yield-only backend has analogous service modules in [backend-yield/services/](backend-yield/services/) with the same basic separation: route handlers stay thin, while business logic is in services.

### 5.3 Utility Layer

The unified backend utility layer contains the actual model loading and preprocessing logic:

1. [backend/utils/inference.py](backend/utils/inference.py)
   - Loads the TensorFlow model lazily.
   - Validates model file size and HDF5 magic bytes.
   - Preprocesses image bytes with PIL.
   - Produces top-1, top-3, and all-class probabilities.

2. [backend/utils/yield_model.py](backend/utils/yield_model.py)
   - Loads the yield pipeline lazily with joblib.
   - Builds SHAP feature names from the fitted preprocessor.
   - Creates the padded DataFrame row used for inference.
   - Provides human-readable feature label mapping for SHAP display.

3. [backend/utils/fertilizer_recommendations.py](backend/utils/fertilizer_recommendations.py)
   - Stores a static dictionary of nutrient-specific advice keyed by class label.

The yield-only backend contains its own utility layer in [backend-yield/utils/yield_model.py](backend-yield/utils/yield_model.py) and [backend-yield/utils/fertilizer_recommendations.py](backend-yield/utils/fertilizer_recommendations.py).

### 5.4 Model Integration

The unified backend integrates models in three different ways:

1. TensorFlow nutrient model in [backend/utils/inference.py](backend/utils/inference.py), loaded from `settings.TF_MODEL_PATH`.
2. Keras pest model in [backend/routes/pest_routes.py](backend/routes/pest_routes.py), loaded from `models/pest_model_final.keras` at import time.
3. scikit-learn yield pipeline in [backend/utils/yield_model.py](backend/utils/yield_model.py), loaded from `settings.YIELD_MODEL_PATH`.

The backend startup event in [backend/main.py](backend/main.py) warms both the TensorFlow model and the yield model, then logs readiness. The pest model is loaded earlier, during import of the route module.

## 6. End-to-End Prediction Flow

The end-to-end path depends on feature type, but the general flow is consistent:

User input → Flutter UI → ApiClient → FastAPI route → service layer → utility/model loading → preprocessing → model prediction → response shaping → UI rendering

Concrete examples:

1. Yield flow
   - User fills form in [frontend/corn_app/lib/features/diagnosis/presentation/pages/corn_yield_page_enhanced.dart](frontend/corn_app/lib/features/diagnosis/presentation/pages/corn_yield_page_enhanced.dart)
   - JSON is posted to `/yield/predict`
   - Backend validates numeric fields with Pydantic and converts the payload into a padded DataFrame row
   - Scikit-learn pipeline predicts yield
   - SHAP values are computed for the transformed row
   - Frontend groups one-hot SHAP features and displays the top factors in a card and chart

2. Nutrient flow
   - User selects an image in [frontend/corn_app/lib/features/diagnosis/presentation/pages/capture_leaf_page.dart](frontend/corn_app/lib/features/diagnosis/presentation/pages/capture_leaf_page.dart)
   - The capture screen launches [frontend/corn_app/lib/features/diagnosis/presentation/pages/nutrient_prediction_page.dart](frontend/corn_app/lib/features/diagnosis/presentation/pages/nutrient_prediction_page.dart)
   - The page uploads the image to `/nutrition/predict`
   - Backend returns class probabilities and fertilizer recommendations
   - Frontend renders the main class, confidence, top-3 distribution, and detailed fertilizer advice

3. Pest flow
   - User selects an image in [frontend/corn_app/lib/features/diagnosis/presentation/pages/pest_screen.dart](frontend/corn_app/lib/features/diagnosis/presentation/pages/pest_screen.dart)
   - The page uploads the image to `/pest/predict`
   - Backend returns a pest class or a `not_corn_leaf` guard response
   - Frontend shows an alert or a textual result depending on the classification

## 7. Frontend Integration (if available)

The frontend is a Flutter application, not React. The tech stack is visible in [frontend/corn_app/pubspec.yaml](frontend/corn_app/pubspec.yaml): Flutter SDK, `http`, `google_fonts`, `fl_chart`, `image_picker`, `path_provider`, and Flutter localization packages.

Entry and navigation:

1. The app starts in [frontend/corn_app/lib/main.dart](frontend/corn_app/lib/main.dart), initializes Flutter bindings, prints API config, and launches `CornNutrientApp`.
2. `CornNutrientApp` holds locale state locally and passes a language-change callback into the dashboard.
3. The main dashboard in [frontend/corn_app/lib/features/diagnosis/presentation/pages/main_dashboard_page.dart](frontend/corn_app/lib/features/diagnosis/presentation/pages/main_dashboard_page.dart) uses `Navigator.push` to open the different feature screens.

Observed frontend screens:

1. `CornDiseaseDetectionScreen` in [frontend/corn_app/lib/features/disease_detection/corn_disease_detection_screen.dart](frontend/corn_app/lib/features/disease_detection/corn_disease_detection_screen.dart)
   - This screen is not backend-backed in the examined code.
   - It defaults to `MockDiseaseClassifier` from [frontend/corn_app/lib/features/disease_detection/mock_disease_classifier.dart](frontend/corn_app/lib/features/disease_detection/mock_disease_classifier.dart).
   - `TfliteDiseaseClassifier` in [frontend/corn_app/lib/features/disease_detection/disease_classifier.dart](frontend/corn_app/lib/features/disease_detection/disease_classifier.dart) is explicitly unimplemented.

2. `CaptureLeafPage` in [frontend/corn_app/lib/features/diagnosis/presentation/pages/capture_leaf_page.dart](frontend/corn_app/lib/features/diagnosis/presentation/pages/capture_leaf_page.dart)
   - Handles gallery/camera selection and pushes `NutrientPredictionPage` with the image path.

3. `NutrientPredictionPage` in [frontend/corn_app/lib/features/diagnosis/presentation/pages/nutrient_prediction_page.dart](frontend/corn_app/lib/features/diagnosis/presentation/pages/nutrient_prediction_page.dart)
   - Calls `/nutrition/predict` through `ApiClient`.
   - Displays top class, confidence, probability bands, and fertilizer advice.
   - Shows a modal if the backend reports `not_corn_leaf`.

4. `PestDetectionScreen` in [frontend/corn_app/lib/features/diagnosis/presentation/pages/pest_screen.dart](frontend/corn_app/lib/features/diagnosis/presentation/pages/pest_screen.dart)
   - Calls `/pest/predict` through `ApiClient`.
   - Displays the returned pest message and handles non-corn-leaf alerts.

5. `CornYieldPageEnhanced` in [frontend/corn_app/lib/features/diagnosis/presentation/pages/corn_yield_page_enhanced.dart](frontend/corn_app/lib/features/diagnosis/presentation/pages/corn_yield_page_enhanced.dart)
   - Collects the yield form inputs.
   - Posts to `/yield/predict`.
   - Uses returned SHAP contributions to render both textual and visual explanations.

API resolution and environment handling:

1. [frontend/corn_app/lib/core/api/api_config.dart](frontend/corn_app/lib/core/api/api_config.dart) resolves the base URL by run mode.
2. [frontend/corn_app/lib/core/api/api_client.dart](frontend/corn_app/lib/core/api/api_client.dart) centralizes HTTP requests and logs the final URL before each call.
3. [frontend/corn_app/lib/core/config/env.dart](frontend/corn_app/lib/core/config/env.dart) is a compatibility facade over `ApiConfig`.

The frontend supports English, Sinhala, and Tamil through [frontend/corn_app/lib/core/localization/app_localizations.dart](frontend/corn_app/lib/core/localization/app_localizations.dart).

## 8. Fertilizer Recommendation Module

The fertilizer module is rule-based, not ML-based.

Unified backend behavior:

1. Recommendations are stored in the `_RECOMMENDATIONS` dictionary in [backend/utils/fertilizer_recommendations.py](backend/utils/fertilizer_recommendations.py).
2. `get_fertilizer_recommendations(label)` returns a static advice object for labels such as `Healthy`, `NAB`, `PAB`, `KAB`, and `ZNAB`.
3. The nutrition service in [backend/services/nutrition_service.py](backend/services/nutrition_service.py) injects the recommendation object into successful nutrient-diagnosis responses.
4. The nutrient frontend page reads the returned object and shows fertilizer details in a modal.

Yield-only backend behavior:

1. [backend-yield/utils/fertilizer_recommendations.py](backend-yield/utils/fertilizer_recommendations.py) contains a similar static recommendation map.
2. [backend-yield/services/fertilizer_service.py](backend-yield/services/fertilizer_service.py) wraps the dictionary lookup and lists supported labels.
3. [backend-yield/routes/fertilizer_routes.py](backend-yield/routes/fertilizer_routes.py) exposes `/fertilizer/recommendations/{label}` and `/fertilizer/labels`.

The module is integrated with the system mainly through the nutrient path, not through yield prediction itself.

## 9. Explainability Layer (SHAP)

SHAP is implemented only for the yield regression path.

In the unified backend:

1. `shap.TreeExplainer(model)` is created after loading the fitted model in [backend/utils/yield_model.py](backend/utils/yield_model.py).
2. The service transforms the single-row DataFrame with the fitted preprocessor before calling `explainer.shap_values(...)` in [backend/services/yield_service.py](backend/services/yield_service.py).
3. Top features are ranked by absolute SHAP value.
4. Each feature is sent back as `raw_name`, `display_name`, and `shap_value`.
5. `pretty_feature_name(...)` converts encoded names to human-readable labels.

Frontend handling:

1. `YieldResult.fromJson(...)` in [frontend/corn_app/lib/features/diagnosis/presentation/pages/corn_yield_page_enhanced.dart](frontend/corn_app/lib/features/diagnosis/presentation/pages/corn_yield_page_enhanced.dart) parses the feature list.
2. Categorical one-hot outputs are grouped into a single visible factor and relabeled to the user’s selected category.
3. `_ResultCard` renders a textual AI explanation and a SHAP contribution chart.

The API returns explanations directly; there is no separate explanation service outside the yield endpoint family in the visible code.

## 10. System Architecture Summary

Textual architecture view:

```text
Flutter app
  ├─ main dashboard
  ├─ yield page → POST /yield/predict
  ├─ nutrient page → POST /nutrition/predict
  ├─ pest page → POST /pest/predict
  └─ disease screen → local mock classifier

Unified FastAPI backend
  ├─ routes/
  │   ├─ nutrition_routes.py
  │   ├─ yield_routes.py
  │   ├─ fertilizer_routes.py
  │   └─ pest_routes.py
  ├─ services/
  │   ├─ nutrition_service.py
  │   ├─ yield_service.py
  │   └─ fertilizer_service.py
  └─ utils/
      ├─ inference.py
      ├─ yield_model.py
      └─ fertilizer_recommendations.py

Yield-only backend
  ├─ routes/yield_routes.py
  ├─ services/yield_service.py
  ├─ utils/yield_model.py
  └─ utils/fertilizer_recommendations.py
```

Layer separation is mostly conventional:

1. Routes handle HTTP validation and response codes.
2. Services handle orchestration and response shaping.
3. Utilities handle model loading, preprocessing, and static lookup tables.

The backend startup path in [backend/main.py](backend/main.py) warms the image and yield models so that first requests are faster.

## 11. Deployment & Runtime Behavior

Deployment is explicitly configured for Render in [render.yaml](render.yaml).

Observed Render setup:

1. Service type: Python web service
2. Working directory: `backend`
3. Build command: install requirements and run `python scripts/download_models.py`
4. Start command: `python -m uvicorn main:app --host 0.0.0.0 --port $PORT`
5. Health check: `/health`
6. Environment variables: `ALLOWED_ORIGINS`, `TF_MODEL_PATH`, `YIELD_MODEL_PATH`, `TF_MODEL_URL`, `YIELD_MODEL_URL`

Runtime behavior in code:

1. The unified backend uses `settings.TF_MODEL_PATH` and `settings.YIELD_MODEL_PATH` from [backend/core/config.py](backend/core/config.py).
2. TensorFlow model loading is lazy and guarded by file checks in [backend/utils/inference.py](backend/utils/inference.py).
3. The yield pipeline is also lazy-loaded with `joblib.load(...)` in [backend/utils/yield_model.py](backend/utils/yield_model.py).
4. `scripts/download_models.py` in [backend/scripts/download_models.py](backend/scripts/download_models.py) downloads large model binaries from URLs if they are not already present.
5. The local utility [backend/\_check.py](backend/_check.py) syntax-checks the Python modules and imports the app to enumerate routes.

Dependency declarations:

1. [backend/requirements.txt](backend/requirements.txt) declares FastAPI, Uvicorn, python-multipart, Starlette, Pillow, tensorflow-cpu, NumPy, pandas, joblib, scikit-learn, and SHAP.
2. [backend-yield/requirements.txt](backend-yield/requirements.txt) declares FastAPI, Uvicorn, python-multipart, Starlette, NumPy, pandas, joblib, scikit-learn, and SHAP.
3. [frontend/corn_app/pubspec.yaml](frontend/corn_app/pubspec.yaml) declares the Flutter dependencies needed by the app.

The repository includes the expected model artifact path `backend/corn_yield_model.pkl`, which is present in the workspace. The TF nutrient model and pest model binaries are also present under `backend/models/`.

## 12. Limitations & Technical Gaps

The following issues are visible directly in the code and notebooks:

1. The repository contains two different yield backends and two different yield contracts. The unified backend in [backend/](backend/) and the yield-only backend in [backend-yield/](backend-yield/) are not shown to share a single build artifact or a single source of truth.
2. The yield training notebook [notebooks/corn-yield/ResearchNew (1).ipynb](<notebooks/corn-yield/ResearchNew%20(1).ipynb>) trains on 9 input features and saves `corn_yield_model_best.pkl`, while the backend code expects `corn_yield_model.pkl` and pads input rows with hard-coded defaults. The repository does not clearly define the conversion step between those two contracts.
3. The unified backend’s yield utility [backend/utils/yield_model.py](backend/utils/yield_model.py) assumes a specific fitted transformer layout when reconstructing post-transform feature names. If the saved pipeline’s transformer order differs, the SHAP labels can become inaccurate or the loader can fail.
4. The yield-only utility [backend-yield/utils/yield_model.py](backend-yield/utils/yield_model.py) derives feature names more defensively, but its comments and the training notebook do not fully align with the 23-feature vs 9-feature story.
5. The pest model is loaded at module import time in [backend/routes/pest_routes.py](backend/routes/pest_routes.py), which is less defensive than the lazy-loading approach used for the nutrient and yield models.
6. The health endpoint in [backend/main.py](backend/main.py) reports TensorFlow and yield readiness, but not pest-model readiness, even though the pest model is part of the runtime surface.
7. The frontend disease screen in [frontend/corn_app/lib/features/disease_detection/corn_disease_detection_screen.dart](frontend/corn_app/lib/features/disease_detection/corn_disease_detection_screen.dart) is mock-based. `TfliteDiseaseClassifier` is explicitly unimplemented in [frontend/corn_app/lib/features/disease_detection/disease_classifier.dart](frontend/corn_app/lib/features/disease_detection/disease_classifier.dart).
8. The frontend test in [frontend/corn_app/test/widget_test.dart](frontend/corn_app/test/widget_test.dart) is a shallow smoke test and does not validate API integration, model responses, or UI correctness beyond initial rendering.
9. The training notebook for dataset creation is synthetic and formula-driven, so the model is trained on generated data rather than directly observed field measurements.
10. Some docstrings and comments describe older label conventions that do not fully match the active dictionaries. The actual runtime behavior follows the code, not the comments.

Where the code is unclear, the safe conclusion is: not clearly defined in code.
