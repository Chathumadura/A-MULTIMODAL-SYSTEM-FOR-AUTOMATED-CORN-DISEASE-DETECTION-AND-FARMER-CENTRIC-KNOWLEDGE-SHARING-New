"""
Fertilizer recommendation lookup.

Keyed on the class labels produced by the TensorFlow model (corn_final_model (1).h5):
  Healthy | KAB | NAB | Not_Corn | PAB | ZNAB
  (alphabetical – matching flow_from_directory index order)
"""

from __future__ import annotations

# ---------------------------------------------------------------------------
# Recommendation data
# ---------------------------------------------------------------------------
_RECOMMENDATIONS: dict[str, dict] = {
    "Healthy": {
        "summary": "Your corn plant appears healthy.",
        "summary_si": "ඔබේ බඩ ඉරු පැළය සෞඛ්‍ය සම්පන්නය.",
        "fertilizer": None,
        "application_rate": None,
        "application_timing": None,
        "additional_tips": [
            "Continue current fertilizer programme.",
            "Monitor regularly for early signs of stress.",
        ],
    },
    "NAB": {
        "summary": "Nitrogen deficiency detected. Yellowing typically starts on older lower leaves.",
        "summary_si": "නයිට්‍රජන් ඌනතාවය හඳුනාගෙන ඇත.",
        "fertilizer": "Urea (46-0-0) or Ammonium Nitrate (34-0-0)",
        "application_rate": "50–100 kg/acre of Urea, split into two applications",
        "application_timing": (
            "First application at planting; "
            "second application at knee-high stage (V6)."
        ),
        "additional_tips": [
            "Incorporate fertilizer into the soil or apply before rain to reduce volatilisation.",
            "Avoid over-application — excess N causes lodging and environmental run-off.",
            "Soil-test pH should be 6.0–7.0 for optimal N uptake.",
        ],
    },
    "PAB": {
        "summary": "Phosphorus deficiency detected. Purple or reddish discolouration on leaves is a key indicator.",
        "summary_si": "පොස්පරස් ඌනතාවය හඳුනාගෙන ඇත.",
        "fertilizer": "Triple Superphosphate (TSP 0-46-0) or Diammonium Phosphate (DAP 18-46-0)",
        "application_rate": "25–50 kg P₂O₅/acre",
        "application_timing": "Apply at or before planting, incorporated into the seed zone.",
        "additional_tips": [
            "Phosphorus is highly immobile in soil — banding near the root zone is more effective than broadcasting.",
            "Cold and wet soils restrict P uptake even when adequate P is present — consider row covers.",
            "Maintain soil pH 6.0–7.0 for best phosphorus availability.",
        ],
    },
    "KAB": {
        "summary": "Potassium deficiency detected. Scorching or firing of leaf margins (older leaves first) is characteristic.",
        "summary_si": "පොටෑසියම් ඌනතාවය හඳුනාගෙන ඇත.",
        "fertilizer": "Muriate of Potash (MOP 0-0-60) or Sulphate of Potash (SOP 0-0-50)",
        "application_rate": "50–80 kg K₂O/acre",
        "application_timing": "Broadcast and incorporate before planting, or split-apply with N.",
        "additional_tips": [
            "Sandy soils lose K more quickly — consider split applications.",
            "Excessive N or Mg can antagonise K uptake — ensure balanced fertilisation.",
            "Foliar K sprays can provide a quick fix but do not replace soil applications.",
        ],
    },
    "ZNAB": {
        "summary": "Zinc deficiency detected. Striping or white/pale banding between leaf veins on young leaves is characteristic.",
        "summary_si": "සින්ක් ඌනතාවය හඳුනාගෙන ඇත. තරුණ කොළ මත සුදු/නෙරළු රේඛා දිස් වේ.",
        "fertilizer": "Zinc Sulphate (ZnSO₄ – 33 % Zn) or Zinc EDTA chelate",
        "application_rate": "5–10 kg ZnSO₄/acre as soil application, or 0.5 % foliar spray",
        "application_timing": "Soil application before planting; foliar spray at V4–V6 stage for rapid correction.",
        "additional_tips": [
            "Zinc deficiency is common on high-pH (>7.5) or waterlogged soils — check drainage.",
            "Avoid applying Zn with phosphate fertilisers directly — P can precipitate Zn.",
            "Chelated Zn is more effective on alkaline soils than sulphate forms.",
        ],
    },
}

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

def get_fertilizer_recommendations(label: str) -> dict | None:
    """
    Return the recommendation dict for `label`, or None if not recognised.

    Args:
        label: Predicted class name from the TF model.

    Returns:
        Dict with keys: summary, fertilizer, application_rate,
        application_timing, additional_tips – or None.
    """
    return _RECOMMENDATIONS.get(label)
