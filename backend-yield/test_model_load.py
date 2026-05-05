import joblib

print("Loading model...")
model = joblib.load("corn_yield_model.pkl")
print("Model loaded successfully:", type(model))
