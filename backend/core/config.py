"""
Centralised application configuration.

All values are read from environment variables at import time.
Defaults are safe for local development (localhost binding, open CORS).
Copy .env.example to .env and adjust before running.
"""

import os
from pathlib import Path

# Absolute path to the backend/ directory (one level above this file)
BASE_DIR: Path = Path(__file__).resolve().parent.parent


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
    # 6-class model trained with flow_from_directory (alphabetical index):
    #   0=Healthy  1=KAB  2=NAB  3=Not_Corn  4=PAB  5=ZNAB
    # ------------------------------------------------------------------
    TF_MODEL_PATH: Path = Path(
        os.getenv(
            "TF_MODEL_PATH",
            str(BASE_DIR / "models" / "corn_final_model (1).h5"),
        )
    )

    # ------------------------------------------------------------------
    # Sklearn pipeline – yield prediction + SHAP
    # ------------------------------------------------------------------
    YIELD_MODEL_PATH: Path = Path(
        os.getenv(
            "YIELD_MODEL_PATH",
            str(BASE_DIR / "corn_yield_model.pkl"),
        )
    )


settings = _Settings()
