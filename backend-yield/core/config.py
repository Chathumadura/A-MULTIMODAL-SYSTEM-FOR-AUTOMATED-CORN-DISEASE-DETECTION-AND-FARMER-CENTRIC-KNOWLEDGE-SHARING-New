import os
from pathlib import Path

BASE_DIR: Path = Path(__file__).resolve().parent.parent          # = backend-yield/
WORKSPACE_ROOT: Path = BASE_DIR.parent                           # = cornxpert/


def _resolve_path(env_key: str, default_relative: str) -> Path:
    raw = os.getenv(env_key, "").strip()
    if raw:
        p = Path(raw)
        return p if p.is_absolute() else WORKSPACE_ROOT / p
    return WORKSPACE_ROOT / default_relative


class _Settings:
    HOST: str = os.getenv("HOST", "127.0.0.1")
    PORT: int = int(os.getenv("PORT", "8001"))

    _raw_origins: str = os.getenv("ALLOWED_ORIGINS", "*")
    ALLOWED_ORIGINS: list[str] = (
        ["*"]
        if _raw_origins == "*"
        else [o.strip() for o in _raw_origins.split(",")]
    )

    YIELD_MODEL_PATH: Path = _resolve_path(
        "YIELD_MODEL_PATH",
        "backend/corn_yield_model.pkl",
    )


settings = _Settings()
