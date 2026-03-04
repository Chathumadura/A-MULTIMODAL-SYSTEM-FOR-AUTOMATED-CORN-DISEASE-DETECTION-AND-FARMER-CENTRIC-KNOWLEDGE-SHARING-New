"""
Centralised application configuration.

All values are read from environment variables at import time.
Defaults are safe for local development (localhost binding, open CORS).
Copy .env.example to .env and adjust before running.
"""

import os
from pathlib import Path

# Absolute path to the backend/ directory (one level up from core/).
# Resolved via __file__ so it is correct on every OS and regardless of
# the process working directory (important for Render / Docker deployments).
BASE_DIR: Path = Path(__file__).resolve().parent.parent


def _resolve_path(env_key: str, default_relative: str) -> Path:
    """Return an absolute Path for a model file.

    Resolution rules (in priority order):
      1. ``env_key`` env var is set and is already an absolute path → use as-is.
      2. ``env_key`` env var is set and is a relative path → join with BASE_DIR.
      3. Env var is not set → join ``default_relative`` with BASE_DIR.

    This makes the app portable: works locally on Windows (C:\\…), in a
    Docker container, and on Render's Linux environment without any manual
    path editing.
    """
    raw = os.getenv(env_key, "").strip()
    if raw:
        p = Path(raw)
        return p if p.is_absolute() else BASE_DIR / p
    return BASE_DIR / default_relative


class _Settings:
    # ------------------------------------------------------------------
    # Server
    # ------------------------------------------------------------------
    HOST: str = os.getenv("HOST", "127.0.0.1")
    PORT: int = int(os.getenv("PORT", "8000"))

    # ------------------------------------------------------------------
    # CORS
    # ------------------------------------------------------------------
    _raw_origins: str = os.getenv("ALLOWED_ORIGINS", "*")
    ALLOWED_ORIGINS: list[str] = (
        ["*"]
        if _raw_origins == "*"
        else [o.strip() for o in _raw_origins.split(",")]
    )

    # ------------------------------------------------------------------
    # TensorFlow model – nutrient / disease detection
    # 6-class ResNet-50 model (alphabetical flow_from_directory order):
    #   0=Healthy  1=KAB  2=NAB  3=Not_Corn  4=PAB  5=ZNAB
    #
    # Set TF_MODEL_PATH in your .env or on the Render dashboard.
    # Accepts both absolute paths and paths relative to backend/.
    # ------------------------------------------------------------------
    TF_MODEL_PATH: Path = _resolve_path(
        "TF_MODEL_PATH",
        "models/resnet50_multi_nutrient_finetuned.h5",
    )

    # ------------------------------------------------------------------
    # Sklearn pipeline – yield prediction + SHAP
    # Set YIELD_MODEL_PATH in your .env or on the Render dashboard.
    # ------------------------------------------------------------------
    YIELD_MODEL_PATH: Path = _resolve_path(
        "YIELD_MODEL_PATH",
        "corn_yield_model.pkl",
    )


settings = _Settings()
