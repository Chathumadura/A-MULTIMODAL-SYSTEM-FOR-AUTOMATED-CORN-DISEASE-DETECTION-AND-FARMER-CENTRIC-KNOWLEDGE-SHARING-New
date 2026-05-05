from backend.utils.yield_model import _load
from core.config import settings

print("configured path:", settings.YIELD_MODEL_PATH)
state = _load()
print("state loaded:", state is not None)
print(state)
