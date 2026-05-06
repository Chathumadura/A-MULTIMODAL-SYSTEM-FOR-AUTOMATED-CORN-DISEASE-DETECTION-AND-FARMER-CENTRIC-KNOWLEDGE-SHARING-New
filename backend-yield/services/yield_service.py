"""
CORNXPERT SERVICE LAYER - YIELD LOGIC

This module orchestrates the end-to-end inference flow for yield prediction.
Key responsibilities:
1. Coordination: Bridges the API routes with the underlying ML model utilities.
2. Data Transformation: Aggregates one-hot encoded SHAP values back into base features.
3. Post-Model Logic: Applies domain-specific adjustments (like pest penalties).
4. Explainability: Ranks and normalizes factor impacts for user-friendly visualization.
"""

from __future__ import annotations

import logging

import numpy as np

from utils.yield_model import build_full_row, get_yield_state, pretty_feature_name, _PEST_MAP

logger = logging.getLogger(__name__)


# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------
def _ensure_model():
    """
    Dependency check: Ensures the machine learning model is loaded before processing.
    Raises RuntimeError if the model is unavailable (e.g., file missing).
    """
    state = get_yield_state()
    if state is None:
        raise RuntimeError("Yield model is not available.")
    return state


_CATEGORICAL_BASE_KEYS = (
    "district",
    "variety",
    "soil_type",
    "irrigation_type",
    "pest_disease_level",
)

_ALLOWED_FEATURES = {
    "variety",
    "soil_type",
    "irrigation_type",
    "pest_disease_level",
    "seasonal_rainfall_mm",
    "fertilizer_kg_per_acre",
}


def _group_shap_values(
    shap_instance: np.ndarray,
    feature_names: list[str],
) -> dict[str, float]:
    """
    Aggregates SHAP values for one-hot encoded categories.
    
    The model sees 'variety_Hybrid_A' and 'variety_Hybrid_B' as separate inputs.
    This function sums their impacts so the UI can show a single 'Variety' factor.
    """
    grouped: dict[str, float] = {}
    for i, name in enumerate(feature_names):
        base_name = name
        for key in _CATEGORICAL_BASE_KEYS:
            prefix = f"{key}_"
            if prefix in name:
                base_name = key
                break
        if base_name not in _ALLOWED_FEATURES:
            continue
        grouped[base_name] = grouped.get(base_name, 0.0) + float(shap_instance[i])
    if not grouped:
        grouped = {
            "variety": 0.0,
            "soil_type": 0.0,
            "irrigation_type": 0.0,
            "pest_disease_level": -1.0,
            "seasonal_rainfall_mm": 0.0,
            "fertilizer_kg_per_acre": 0.0,
        }
    return grouped


# ---------------------------------------------------------------------------
# Localization Support
# ---------------------------------------------------------------------------
_LOCALIZED_CONTENT = {
    "en": {
        "summary_template": "Your predicted yield of {predicted_yield_kg_per_acre:.0f} kg/acre is {trend} compared to the baseline of {base:.0f} kg/acre.",
        "trend_above": "higher",
        "trend_below": "lower",
        "trend_stable": "stable",
        "rec_rainfall": "Increase irrigation; current rainfall ({val:.0f}mm) is low.",
        "rec_fertilizer": "Increase NPK application; {val:.0f}kg/acre is below optimal.",
        "rec_pest": "Immediate pest control needed for {level} incidence.",
        "what_if_pest": "By eliminating pests, you could improve yield by approx {pct:.0f}% (+{gain:.0f} kg).",
        "what_if_fert": "Optimizing fertilizer could boost yield by {pct:.0f}%.",
        "factors_header": "Detailed Factor Analysis:",
    },
    "si": {
        "summary_template": "ඔබගේ පුරෝකථිත අස්වැන්න ({predicted_yield_kg_per_acre:.0f} kg/acre), සාමාන්‍ය අගය ({base:.0f} kg/acre) සමග සැසඳීමේදී {trend} අගයකි.",
        "trend_above": "වැඩි",
        "trend_below": "අඩු",
        "trend_stable": "සමාන",
        "rec_rainfall": "ජල සම්පාදනය වැඩි කරන්න; වර්ෂාපතනය ({val:.0f}mm) ප්‍රමාණවත් නැත.",
        "rec_fertilizer": "පොහොර භාවිතය වැඩි කරන්න; ({val:.0f}kg/acre) ප්‍රමාණවත් නැත.",
        "rec_pest": "{level} මට්ටමේ පලිබෝධ හානිය සඳහා වහාම පියවර ගන්න.",
        "what_if_pest": "පලිබෝධ පාලනය මගින් අස්වැන්න {pct:.0f}% කින් පමණ (+{gain:.0f} kg) වැඩි කරගත හැක.",
        "what_if_fert": "පොහොර භාවිතය ප්‍රශස්ත කිරීමෙන් අස්වැන්න {pct:.0f}% කින් වැඩි කළ හැක.",
        "factors_header": "සාධක පිළිබඳ විස්තරාත්මක විශ්ලේෂණය:",
    },
    "ta": {
        "summary_template": "உங்கள் கணிக்கப்பட்ட மகசூல் ({predicted_yield_kg_per_acre:.0f} kg/acre), சராசரி மகசூலை ({base:.0f} kg/acre) விட {trend} உள்ளது.",
        "trend_above": "அதிகம்",
        "trend_below": "குறைவு",
        "trend_stable": "சமநிலை",
        "rec_rainfall": "நீர்ப்பாசனத்தை அதிகரிக்கவும்; மழையளவு ({val:.0f}mm) குறைவாக உள்ளது.",
        "rec_fertilizer": "உரப் பயன்பாட்டை அதிகரிக்கவும்; {val:.0f}kg/acre போதுமானதாக இல்லை.",
        "rec_pest": "{level} மட்டத்திலான பூச்சித் தாக்கத்திற்கு உடனடி நடவடிக்கை தேவை.",
        "what_if_pest": "பூச்சிகளைக் கட்டுப்படுத்துவதன் மூலம் மகசூலை {pct:.0f}% (+{gain:.0f} kg) அதிகரிக்கலாம்.",
        "what_if_fert": "உரப் பயன்பாட்டைச் சீராக்குவதன் மூலம் மகசூலை {pct:.0f}% அதிகரிக்கலாம்.",
        "factors_header": "காரணிகளின் விரிவான பகுப்பாய்வு:",
    }
}


def _get_localized_reason(feature: str, value: any, lang: str) -> str:
    """
    Returns a localized reason for a feature's impact.
    """
    reasons = {
        "en": {
            "rainfall_low": "Low rainfall ({val:.0f}mm) restricts grain filling.",
            "rainfall_opt": "Optimal rainfall supports high biomass.",
            "pest_high": "High pest level ({val}) causes severe tissue damage.",
            "fert_low": "Insufficient fertilizer ({val:.0f}kg) limits nutrient uptake.",
            "variety": "The chosen variety ({val}) is a key determinant."
        },
        "si": {
            "rainfall_low": "අඩු වර්ෂාපතනය ({val:.0f}mm) බීජ වර්ධනය සීමා කරයි.",
            "rainfall_opt": "ප්‍රශස්ත වර්ෂාපතනය ඉහළ අස්වැන්නකට සහාය වේ.",
            "pest_high": "අධික පලිබෝධ හානිය ({val}) පටක විනාශ කරයි.",
            "fert_low": "පොහොර මදිකම ({val:.0f}kg) පෝෂක අවශෝෂණය සීමා කරයි.",
            "variety": "තෝරාගත් ප්‍රභේදය ({val}) අස්වැන්න තීරණය කරන ප්‍රධාන සාධකයකි."
        },
        "ta": {
            "rainfall_low": "குறைந்த மழையளவு ({val:.0f}mm) தானிய விளைச்சலைக் கட்டுப்படுத்துகிறது.",
            "rainfall_opt": "சிறந்த மழையளவு அதிக விளைச்சலுக்கு உதவுகிறது.",
            "pest_high": "அதிக பூச்சித் தாக்கம் ({val}) திசுக்களைப் பாதிக்கிறது.",
            "fert_low": "குறைந்த உரப் பயன்பாடு ({val:.0f}kg) ஊட்டச்சத்துக்களைக் குறைக்கிறது.",
            "variety": "தேர்ந்தெடுக்கப்பட்ட இனம் ({val}) முக்கிய காரணியாகும்."
        }
    }
    
    l = reasons.get(lang, reasons["en"])
    if feature == "seasonal_rainfall_mm":
        return l["rainfall_low"].format(val=value) if value < 800 else l["rainfall_opt"]
    if feature == "pest_disease_level" and value in ["High", "Medium"]:
        return l["pest_high"].format(val=value)
    if feature == "fertilizer_kg_per_acre" and value < 100:
        return l["fert_low"].format(val=value)
    if feature == "variety":
        return l["variety"].format(val=value)
    
    return f"{feature} is affecting yield."


def _generate_detailed_explanation(top_features: list[dict], lang: str) -> str:
    """
    Combines top positive and negative factors into a multi-factor explanation.
    Now includes impact percentages and a concluding agricultural insight.
    """
    content = _LOCALIZED_CONTENT.get(lang, _LOCALIZED_CONTENT["en"])
    pos = [f for f in top_features if f["impact_value"] > 0]
    neg = [f for f in top_features if f["impact_value"] < 0]
    
    explanation = f"{content['factors_header']}\n"
    
    # Reasoning: 1 Positive + 2 Negative with percentages
    if pos:
        f = pos[0]
        explanation += f"• {f['display_name']} ({f['impact_percentage']:.1f}%): {f['reason']}\n"
    
    for f in neg[:2]:
        explanation += f"• {f['display_name']} ({f['impact_percentage']:.1f}%): {f['reason']}\n"
    
    # Concluding insight based on the overall trend
    if len(neg) > len(pos):
        explanation += "\nFocus on mitigating the limiting factors mentioned above to maximize your harvest potential."
    else:
        explanation += "\nYour current management practices are effectively supporting high productivity."
        
    return explanation

# ---------------------------------------------------------------------------
# Public service functions
# ---------------------------------------------------------------------------
def predict_yield(data: dict) -> dict:
    """
    Core prediction function. Calculates the harvest estimate in kg/acre.
    """
    state = _ensure_model()
    
    # 1. Convert raw input dictionary into a formatted Pandas DataFrame
    df = build_full_row(data)
    
    # 2. Run the scikit-learn pipeline (preprocessing + XGBoost/RF)
    predicted_yield = round(float(state.pipeline.predict(df)[0]), 2)
    
    # 3. Post-model adjustment: Apply manual penalties based on pest incidence
    # This logic compensates for risks not fully captured by the training data.
    pest_level = int(data.get("pest_disease_incidence", 0))
    if pest_level == 0:
        penalty = 0
    elif pest_level == 1:
        penalty = -50
    elif pest_level == 2:
        penalty = -150
    else:
        penalty = -300
        
    predicted_yield = round(predicted_yield + penalty, 2)
    logger.info("Yield predicted: %.2f kg/acre", predicted_yield)
    return {"predicted_yield_kg_per_acre": predicted_yield}


def explain_yield(data: dict, top_n: int = 5) -> dict:
    """
    Predict corn yield AND return top SHAP feature contributions.

    Args:
        data:  Dict matching SimpleYieldRequest fields.
        top_n: Number of top SHAP features to return (default 5).

    Returns:
        {
          "predicted_yield_kg_per_acre": float,
          "top_contributing_features": [{"raw_name", "display_name", "shap_value"}, ...]
        }

    Raises:
        RuntimeError: when the model is not loaded.
    """
    state = _ensure_model()
    df = build_full_row(data)

    # 1. Generate prediction with pest adjustments
    predicted_yield = round(float(state.pipeline.predict(df)[0]), 2)
    pest_level = int(data.get("pest_disease_incidence", 0))
    if pest_level == 0:
        penalty = 0
    elif pest_level == 1:
        penalty = -50
    elif pest_level == 2:
        penalty = -150
    else:
        penalty = -300
    predicted_yield = round(predicted_yield + penalty, 2)

    # 2. Extract SHAP values (model explanations)
    # SHAP values are computed on the preprocessed (transformed) feature matrix
    x_transformed = state.preprocessor.transform(df)
    shap_values = state.explainer.shap_values(x_transformed)
    shap_instance: np.ndarray = np.array(shap_values[0])

    grouped = _group_shap_values(shap_instance, state.all_feature_names)
    if "pest_disease_level" in grouped:
        grouped["pest_disease_level"] = -abs(grouped["pest_disease_level"]) * 1.2

    total_impact = sum(abs(value) for value in grouped.values())
    if total_impact == 0:
        total_impact = 1.0
    sorted_features = sorted(
        grouped.items(), key=lambda item: abs(item[1]), reverse=True
    )
    top_features: list[dict] = []
    lang = data.get("language", "en")
    content = _LOCALIZED_CONTENT.get(lang, _LOCALIZED_CONTENT["en"])

    for base_name, shap_value in sorted_features[:top_n]:
        impact_percentage = (abs(shap_value) / total_impact) * 100
        impact_value = float(shap_value) if shap_value is not None else 0.0
        
        direction = "increases" if impact_value > 0 else "reduces"
        input_val = data.get(base_name) if base_name in data else "N/A"
        
        # Use localized reason
        reason = _get_localized_reason(base_name, input_val, lang)

        top_features.append(
            {
                "feature": base_name,
                "display_name": pretty_feature_name(base_name),
                "impact_value": round(impact_value, 4),
                "impact_percentage": round(impact_percentage, 1),
                "direction": direction,
                "reason": reason,
            }
        )

    # 3. Compute base yield and delta
    expected_value = state.explainer.expected_value
    base_value = float(np.array(expected_value).ravel()[0]) if isinstance(expected_value, (list, np.ndarray)) else float(expected_value)
    delta = predicted_yield - base_value
    
    # 4. Localized Summary
    trend_key = "trend_above" if delta > 50 else ("trend_below" if delta < -50 else "trend_stable")
    summary = content["summary_template"].format(
        predicted_yield_kg_per_acre=predicted_yield,
        base=base_value,
        trend=content[trend_key]
    )

    # 5. Localized Recommendations
    recommendations = []
    rainfall = float(data.get("seasonal_rainfall_mm", 0))
    if rainfall < 850: recommendations.append(content["rec_rainfall"].format(val=rainfall))
    
    fert = float(data.get("fertilizer_kg_per_acre", 0))
    if fert < 110: recommendations.append(content["rec_fertilizer"].format(val=fert))
    
    pest_idx = int(data.get("pest_disease_incidence", 0))
    if pest_idx > 1: recommendations.append(content["rec_pest"].format(level=_PEST_MAP.get(min(pest_idx, 3), "High")))
    
    if not recommendations:
        recommendations.append("Condition is optimal. Maintain current standards.")

    # 6. Improved Percentage-based What-If
    if pest_idx > 0:
        gain = predicted_yield * 0.12 # Estimate 12% loss from pests
        what_if = content["what_if_pest"].format(pct=12, gain=gain)
    else:
        what_if = content["what_if_fert"].format(pct=8)

    return {
        "predicted_yield_kg_per_acre": predicted_yield,
        "base_yield": round(base_value, 2),
        "delta": round(delta, 2),
        "summary": summary,
        "detailed_explanation": _generate_detailed_explanation(top_features, lang),
        "top_contributing_features": top_features,
        "recommendations": recommendations[:3],
        "what_if": what_if,
    }
