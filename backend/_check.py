import traceback, sys, os
os.environ["TF_CPP_MIN_LOG_LEVEL"] = "3"
os.environ["TF_ENABLE_ONEDNN_OPTS"] = "0"

# ── 1. Syntax-check every Python file ──────────────────────────────────────
import ast, pathlib

files = [
    "main.py",
    "core/__init__.py", "core/config.py",
    "routes/__init__.py",
    "routes/yield_routes.py",
    "routes/nutrition_routes.py",
    "routes/fertilizer_routes.py",
    "services/__init__.py",
    "services/yield_service.py",
    "services/nutrition_service.py",
    "services/fertilizer_service.py",
    "utils/__init__.py",
    "utils/inference.py",
    "utils/yield_model.py",
    "utils/fertilizer_recommendations.py",
]
syntax_ok = True
for f in files:
    p = pathlib.Path(f)
    if not p.exists():
        print(f"MISSING  {f}"); syntax_ok = False; continue
    try:
        ast.parse(p.read_text(encoding="utf-8"))
        print(f"OK       {f}")
    except SyntaxError as e:
        print(f"SYNTAX   {f}  {e}"); syntax_ok = False

if not syntax_ok:
    sys.exit(1)

# ── 2. Import app and list routes ───────────────────────────────────────────
try:
    from main import app
    print("\nAPP:", app.title, "v" + app.version)
    print("ROUTES:")
    for r in app.routes:
        methods = getattr(r, "methods", None)
        print(f"  {str(methods or '').ljust(16)}  {getattr(r, 'path', '')}")
    print("\nSUCCESS")
except Exception:
    traceback.print_exc()
    sys.exit(1)
