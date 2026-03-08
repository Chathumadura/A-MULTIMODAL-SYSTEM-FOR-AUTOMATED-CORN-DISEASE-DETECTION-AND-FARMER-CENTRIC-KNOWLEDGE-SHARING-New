"""
Model downloader utility.

Downloads model files from remote URLs at startup.

Rules:
  - Only downloads when a URL env var is set.
  - Skips download when the local file already exists AND is >= 1 MB
    (i.e. not a Git-LFS pointer stub).
  - Creates parent directories automatically.
  - Streams the response so large files do not blow memory.
  - Logs every step clearly so Render logs are easy to read.
"""

import logging
import os
from pathlib import Path

import requests

logger = logging.getLogger(__name__)

# Any file smaller than this is treated as missing / LFS pointer.
_MIN_VALID_BYTES: int = 1 * 1024 * 1024  # 1 MB


def download_model_if_needed(env_var: str, local_path: Path) -> bool:
    """
    Ensure *local_path* holds a real model file, downloading from *env_var* URL
    if needed.

    Args:
        env_var:    Name of the environment variable that holds the download URL.
        local_path: Absolute Path where the file should be stored locally.

    Returns:
        True  – file is present and appears valid after this call.
        False – file is missing and could not be downloaded.
    """
    logger.info("[downloader] ─── %s ───", local_path.name)
    logger.info("[downloader] Resolved local path : %s", local_path)

    # ── Check whether a valid file already exists ────────────────────────────
    if local_path.exists():
        size = local_path.stat().st_size
        logger.info("[downloader] File exists         : True  (%d bytes)", size)
        if size >= _MIN_VALID_BYTES:
            logger.info("[downloader] File appears valid – skipping download.")
            return True
        logger.warning(
            "[downloader] File exists but is suspiciously small (%d bytes) – "
            "treating as corrupt / LFS pointer and re-downloading.",
            size,
        )
    else:
        logger.info("[downloader] File exists         : False")

    # ── Get the download URL from env ────────────────────────────────────────
    url = os.getenv(env_var, "").strip()
    if not url:
        logger.warning(
            "[downloader] ⚠  WARNING: environment variable %s is not set. "
            "Cannot download %s. "
            "Endpoints that depend on this model will return 503.",
            env_var,
            local_path.name,
        )
        # Return True only if the file somehow exists already (edge-case)
        return local_path.exists()

    # ── Create parent directory ──────────────────────────────────────────────
    local_path.parent.mkdir(parents=True, exist_ok=True)

    # ── Stream download ──────────────────────────────────────────────────────
    logger.info("[downloader] Download start      : %s", url)
    try:
        response = requests.get(url, stream=True, timeout=300)
        response.raise_for_status()

        bytes_written = 0
        with open(local_path, "wb") as fh:
            for chunk in response.iter_content(chunk_size=65_536):
                if chunk:
                    fh.write(chunk)
                    bytes_written += len(chunk)

        logger.info(
            "[downloader] ✓ Download SUCCESS : %s  (%d bytes written)",
            local_path.name,
            bytes_written,
        )
        return True

    except requests.exceptions.HTTPError as exc:
        logger.error(
            "[downloader] ✗ Download FAILED (HTTP error) for %s : %s",
            local_path.name,
            exc,
        )
    except requests.exceptions.ConnectionError as exc:
        logger.error(
            "[downloader] ✗ Download FAILED (connection error) for %s : %s",
            local_path.name,
            exc,
        )
    except requests.exceptions.Timeout:
        logger.error(
            "[downloader] ✗ Download FAILED (timeout after 300 s) for %s",
            local_path.name,
        )
    except requests.exceptions.RequestException as exc:
        logger.error(
            "[downloader] ✗ Download FAILED (request error) for %s : %s",
            local_path.name,
            exc,
        )
    except OSError as exc:
        logger.error(
            "[downloader] ✗ Download FAILED (could not write file) %s : %s",
            local_path,
            exc,
        )

    return False
