"""
scripts/download_models.py
──────────────────────────
Downloads large model files from URLs at build/start time so they are
available on Render (or any CI environment) without committing binaries to git.

Usage (called automatically by render.yaml buildCommand):
    python scripts/download_models.py

Environment variables (set on the Render dashboard):
    TF_MODEL_URL      – direct download URL for the TFLite nutrition model (.tflite)
    PEST_MODEL_URL    – direct download URL for the TFLite pest model (.tflite)
    YIELD_MODEL_URL   – direct download URL for the sklearn yield model (.pkl)
    DISEASE_MODEL_URL – direct download URL for the TFLite disease model (.tflite)
    TF_MODEL_PATH     – (optional) override destination path
    PEST_MODEL_PATH   – (optional) override destination path
    YIELD_MODEL_PATH  – (optional) override destination path
    DISEASE_MODEL_PATH – (optional) override destination path

If a URL variable is not set the script skips that file silently.
If the destination already contains a valid binary (not an LFS pointer,
size > 1 MB) the download is also skipped to save build time.

Supported URL sources
─────────────────────
• Direct HTTPS link (any CDN / cloud storage with public access)
• Google Drive  – paste the share link, the script rewrites it to the
  direct-download form automatically
• Dropbox       – ?dl=0 links are rewritten to ?dl=1 automatically
• Hugging Face  – standard resolve/download URLs work directly
"""

from __future__ import annotations

import hashlib
import os
import sys
import urllib.request
from pathlib import Path

# ── constants ────────────────────────────────────────────────────────────────
BASE_DIR    = Path(__file__).resolve().parent.parent   # backend/
CHUNK       = 8 * 1024 * 1024                          # 8 MB chunks
MIN_VALID   = 1 * 1024 * 1024                          # 1 MB minimum for "real" file
LFS_SIG     = b"version https://git-lfs"
# Note: all model files are TFLite FlatBuffers (.tflite) or pickle (.pkl).
# TFLite files have no universal magic-byte header – validation checks only
# the LFS pointer signature and minimum file size.

# ── helpers ───────────────────────────────────────────────────────────────────

def _rewrite_url(url: str) -> str:
    """Normalise hosted-storage share URLs to direct-download URLs."""
    # Google Drive: https://drive.google.com/file/d/FILE_ID/view?...
    #            → https://drive.google.com/uc?export=download&id=FILE_ID
    if "drive.google.com/file/d/" in url:
        file_id = url.split("/file/d/")[1].split("/")[0].split("?")[0]
        return f"https://drive.google.com/uc?export=download&id={file_id}&confirm=t"

    # Dropbox: ?dl=0 → ?dl=1
    if "dropbox.com" in url and "dl=0" in url:
        return url.replace("dl=0", "dl=1")

    return url


def _is_valid(path: Path) -> bool:
    """Return True if the file at *path* looks like a real binary (not LFS)."""
    if not path.exists():
        return False
    if path.stat().st_size < MIN_VALID:
        return False
    header = path.read_bytes()[:len(LFS_SIG)]
    return not header.startswith(LFS_SIG)


def _download(url: str, dest: Path) -> None:
    """Stream-download *url* to *dest*, showing a progress indicator."""
    url = _rewrite_url(url)
    dest.parent.mkdir(parents=True, exist_ok=True)
    tmp = dest.with_suffix(dest.suffix + ".tmp")

    print(f"  → Downloading from {url}")
    print(f"     to {dest}")

    try:
        req = urllib.request.Request(url, headers={"User-Agent": "CornAI-BuildScript/1.0"})
        with urllib.request.urlopen(req, timeout=300) as resp:
            total = int(resp.headers.get("Content-Length", 0))
            downloaded = 0
            with tmp.open("wb") as fh:
                while True:
                    chunk = resp.read(CHUNK)
                    if not chunk:
                        break
                    fh.write(chunk)
                    downloaded += len(chunk)
                    if total:
                        pct = downloaded / total * 100
                        mb  = downloaded / 1_000_000
                        print(f"\r     {mb:.1f} MB / {total/1_000_000:.1f} MB  ({pct:.0f}%)",
                              end="", flush=True)
        print()  # newline after progress

        # Validate before replacing
        downloaded_size = tmp.stat().st_size
        if downloaded_size < MIN_VALID:
            content_preview = tmp.read_bytes()[:200]
            tmp.unlink(missing_ok=True)
            raise RuntimeError(
                f"Downloaded file is too small ({downloaded_size} bytes).\n"
                f"Preview: {content_preview!r}\n"
                "This may be a redirect page (e.g. Google Drive virus-scan warning) "
                "or an invalid URL. Check the URL and try again."
            )

        tmp.rename(dest)
        print(f"  ✓ Saved {dest.stat().st_size / 1_000_000:.1f} MB → {dest.name}")

    except Exception as exc:
        tmp.unlink(missing_ok=True)
        raise RuntimeError(f"Download failed: {exc}") from exc


def _resolve_path(env_key: str, default_relative: str) -> Path:
    raw = os.getenv(env_key, "").strip()
    if raw:
        p = Path(raw)
        return p if p.is_absolute() else BASE_DIR / p
    return BASE_DIR / default_relative


# ── main ──────────────────────────────────────────────────────────────────────

def main() -> int:
    targets = [
        (
            "TF_MODEL_URL",
            _resolve_path("TF_MODEL_PATH", "models/corn_final_model.tflite"),
            "TF nutrition model (.tflite)",
        ),
        (
            "PEST_MODEL_URL",
            _resolve_path("PEST_MODEL_PATH", "models/pest_model.tflite"),
            "Pest detection model (.tflite)",
        ),
        (
            "YIELD_MODEL_URL",
            _resolve_path("YIELD_MODEL_PATH", "corn_yield_model.tflite"),
            "Yield model (.pkl)",
        ),
        (
            "DISEASE_MODEL_URL",
            _resolve_path("DISEASE_MODEL_PATH", "models/disease_model.tflite"),
            "Disease detection model (.tflite)",
        ),
    ]

    errors: list[str] = []

    for url_env, dest, label in targets:
        url = os.getenv(url_env, "").strip()
        print(f"\n{'─'*60}")
        print(f"  {label}")
        print(f"  Destination : {dest}")
        if not url:
            url_display = "(not set)"
        elif len(url) > 80:
            url_display = url[:80] + "…"
        else:
            url_display = url
        print(f"  URL env var : {url_env} = {url_display}")

        if _is_valid(dest):
            print(f"  ✓ Already present and valid ({dest.stat().st_size / 1_000_000:.1f} MB) – skipping download.")
            continue

        if not url:
            print(f"  ⚠ {url_env} is not set and no valid file exists at destination.")
            print("    The endpoint that requires this model will return HTTP 503.")
            continue

        try:
            _download(url, dest)
        except RuntimeError as exc:
            print(f"  ✗ ERROR: {exc}")
            errors.append(f"{label}: {exc}")

    print(f"\n{'='*60}")
    if errors:
        print("DOWNLOAD ERRORS – the following models could not be fetched:")
        for e in errors:
            print(f"  • {e}")
        print("The affected endpoints will return HTTP 503 at runtime.")
        return 1  # non-zero so Render marks the build as failed

    print("All model downloads complete (or already present).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
