# backend/utils/fertilizer_recommendations.py

"""
Fertilizer recommendations for different nutrient deficiencies in corn.
Based on agricultural best practices and farmer feedback.
"""

FERTILIZER_DATA = {
    "NAB": {
        "deficiency": "Nitrogen Deficiency",
        "description_en": "Your corn plant is showing signs of nitrogen deficiency. This nutrient is critical for leaf growth and overall vigor.",
        "description_si": "ඔබගේ ගeither පැල නයිට්‍රජන් ඌනතාවයේ ලක්ෂණ පෙන්වයි. මෙම පෝෂකය කොළ වර්ධනය සහ සামාන්‍ය ශක්තිය සඳහා ඉතා වැදගත්ය.",
        "fertilizer_options": [
            {
                "name": "Urea",
                "concentration": "46% N",
                "application": "Dry application",
                "dosage_en": "Apply 50-80 kg/hectare depending on soil status",
            
                "notes": "Best applied during active growth phase"
            },
            {
                "name": "Foliar Spray - Urea Solution",
                "concentration": "2% to 4% urea solution",
                "application": "Foliar spray",
                "dosage_en": "8–16 kg of urea in 400 liters of water per hectare",
                
                "notes": "Quick absorption through leaves. Spray during morning or evening."
            },
            {
                "name": "Calcium Ammonium Nitrate (CAN)",
                "concentration": "27% N",
                "application": "Dry application",
                "dosage_en": "Apply 60-100 kg/hectare",
                "dosage_si": "60-100 කිලෝග්‍රෑම්/හෙක්ටයාර් යොදන්න",
                "notes": "Suitable for sandy soils. Provides both nitrogen and calcium."
            },
            {
                "name": "Liquid Nitrogen",
                "concentration": "Variable concentration",
                "application": "Liquid spray or fertigation",
                "dosage_en": "Follow product instructions (typically 5-10 liters/hectare)",
                "dosage_si": "නිෂ්පාදන ලේබලයේ උපදෙස් අනුගමනය කරන්න (සාමාන්‍යයෙන් 5-10 ලීටර්/හෙක්ටයාර්)",
                "notes": "Fast-acting, can be applied with irrigation water"
            },
            {
                "name": "Nano Nitrogen",
                "concentration": "Nano-particle form",
                "application": "Foliar spray or soil application",
                "dosage_en": "Follow product instructions (typically 2-5 kg/hectare)",
                "dosage_si": "නිෂ්පාදන ලේබලයේ උපදෙස් අනුගමනය කරන්න (සාමාන්‍යයෙන් 2-5 කිලෝග්‍රෑම්/හෙක්ටයාර්)",
                "notes": "Enhanced absorption due to nano-particles, reduces application rates"
            }
        ],
        "timing": "Apply immediately when deficiency is detected",
        "precautions": "Avoid excessive nitrogen application as it can promote vegetative growth at the expense of grain"
    },
    
    "PAB": {
        "deficiency": "Phosphorus Deficiency",
        "description_en": "Your corn plant shows phosphorus deficiency symptoms. Phosphorus is essential for root development and energy transfer.",
        "description_si": "ඔබගේ පැල පොස්පරස් ඌනතාවයේ ලක්ෂණ පෙන්වයි. පොස්පරස් මූල සංවර්ධනය හා ශක්තිමත්වීම සඳහා අත්‍යවශ්‍ය වේ.",
        "fertilizer_options": [
            {
                "name": "Triple Super Phosphate (TSP)",
                "concentration": "46% P2O5",
                "application": "Dry application - soil incorporation",
                "dosage_en": "Apply 40-80 kg/hectare depending on soil test",
                "dosage_si": "මට්ටමේ පරීක්ෂණ අනුව 40-80 කිලෝග්‍රෑම්/හෙක්ටයාර් යොදන්න",
                "notes": "Most popular phosphate fertilizer. Best applied before planting."
            },
            {
                "name": "Mada Pohora (Mud Fertilizer)",
                "concentration": "Low P2O5 but organic rich",
                "application": "Soil incorporation",
                "dosage_en": "Apply 2-3 tons/hectare",
                "dosage_si": "2-3 ටොන්/හෙක්ටයාර් යොදන්න",
                "notes": "Traditional local fertilizer. Improves soil structure alongside phosphorus supply."
            },
            {
                "name": "Single Super Phosphate (SSP)",
                "concentration": "18% P2O5",
                "application": "Dry application - soil incorporation",
                "dosage_en": "Apply 100-150 kg/hectare",
                "dosage_si": "100-150 කිලෝග්‍රෑම්/හෙක්ටයාර් යොදන්න",
                "notes": "Also provides sulfur. Slower acting than TSP but effective."
            },
            {
                "name": "Diammonium Phosphate (DAP)",
                "concentration": "18% N + 46% P2O5",
                "application": "Dry application - soil incorporation",
                "dosage_en": "Apply 50-100 kg/hectare",
                "dosage_si": "50-100 කිලෝග්‍රෑම්/හෙක්ටයාර් යොදන්න",
                "notes": "Best option if both nitrogen and phosphorus are deficient. Dual benefit."
            }
        ],
        "timing": "Apply at planting or as soon as deficiency is detected",
        "precautions": "Phosphorus moves slowly in soil, so incorporate well. Excess can interfere with zinc absorption."
    },
    
    "KAB": {
        "deficiency": "Potassium Deficiency",
        "description_en": "Your corn plant shows potassium deficiency. Potassium improves disease resistance and grain quality.",
        "description_si": "ඔබගේ පැල පොටෑසියම් ඌනතාවයේ ලක්ෂණ පෙන්වයි. පොටෑසියම් රෝග ප්‍රතිරෝධය හා ධාන්‍ය ගුණාත්මකත්වය වැඩි කරයි.",
        "fertilizer_options": [
            {
                "name": "Muriate of Potash (MOP)",
                "concentration": "60% K2O",
                "application": "Dry application - soil incorporation",
                "dosage_en": "Apply 40-60 kg/hectare K2O equivalent",
                "dosage_si": "40-60 කිලෝග්‍රෑම්/හෙක්ටයාර් (K2O සමාන ප්‍රමාණයෙන්) යොදන්න",
                "notes": "Most economical potassium source. Contains chloride which some crops are sensitive to."
            },
            {
                "name": "Bandi Pohora (Local Potash)",
                "concentration": "Variable K2O",
                "application": "Soil incorporation",
                "dosage_en": "Apply 1-2 tons/hectare",
                "dosage_si": "1-2 ටොන්/හෙක්ටයාර් යොදන්න",
                "notes": "Traditional source. Improves soil structure and microbial activity."
            },
            {
                "name": "Sulphate of Potash (SOP)",
                "concentration": "50% K2O + 18% S",
                "application": "Dry application - soil incorporation",
                "dosage_en": "Apply 50-75 kg/hectare K2O equivalent",
                "dosage_si": "50-75 කිලෝග්‍රෑම්/හෙක්ටයාර් (K2O සමාන ප්‍රමාණයෙන්) යොදන්න",
                "notes": "Chloride-free. Better for sensitive crops. Also provides sulfur."
            },
            {
                "name": "Potassium Nitrate",
                "concentration": "13.5% N + 46% K2O",
                "application": "Dry application or fertigation",
                "dosage_en": "Apply 30-50 kg/hectare K2O equivalent",
                "dosage_si": "30-50 කිලෝග්‍රෑම්/හෙක්ටයාර් (K2O සමාන ප්‍රමාණයෙන්) යොදන්න",
                "notes": "Provides both nitrogen and potassium. Excellent for foliar application."
            },
            {
                "name": "Liquid Nano-Potassium",
                "concentration": "Nano-particle form",
                "application": "Foliar spray or fertigation",
                "dosage_en": "Follow product instructions (typically 2-4 liters/hectare)",
                "dosage_si": "නිෂ්පාදන ලේබලයේ උපදෙස් අනුගමනය කරන්න (සාමාන්‍යයෙන් 2-4 ලීටර්/හෙක්ටයාර්)",
                "notes": "Rapid absorption. Best for quick deficiency correction during growing season."
            }
        ],
        "timing": "Apply during early-mid growth stages for best results",
        "precautions": "Excess potassium can interfere with magnesium absorption. Maintain proper balance."
    },
    
    "ZNAB": {
        "deficiency": "Zinc Deficiency",
        "description_en": "Your corn plant shows zinc deficiency. Zinc is crucial for enzyme activity and protein synthesis.",
        "description_si": "ඔබගේ පැල සින්ක් ඌනතාවයේ ලක්ෂණ පෙන්වයි. සින්ක් එන්සයිම ක්‍රියාකාරිත්වය හා ප්‍රෝටීන් සංශලේෂණයට අවශ්‍ය වේ.",
        "fertilizer_options": [
            {
                "name": "Zinc Sulphate (ZnSO4)",
                "concentration": "33% Zn",
                "application": "Foliar spray or soil application",
                "dosage_en": "Soil: 10-15 kg/hectare | Foliar: 2-5 kg in 400 liters water/hectare",
                "dosage_si": "භූමිය: 10-15 කිලෝග්‍රෑම්/හෙක්ටයාර් | පත්‍ර: ජල ලීටර් 400 කට සින්ක් 2-5 කිලෝග්‍රෑම් යොදන්න",
                "notes": "Most effective form of zinc. Quick absorption when sprayed on leaves."
            },
            {
                "name": "Chelated Zinc (Zinc EDTA)",
                "concentration": "9-14% Zn (chelated)",
                "application": "Foliar spray preferred",
                "dosage_en": "Foliar: 1-2 kg in 400 liters water/hectare | Soil: 5-10 kg/hectare",
                "dosage_si": "පත්‍ර: ජල ලීටර් 400 කට සින්ක් 1-2 කිලෝග්‍රෑම් | භූමිය: 5-10 කිලෝග්‍රෑම්/හෙක්ටයාර්",
                "notes": "Better availability to plants. More expensive but highly effective."
            },
            {
                "name": "Micro-Maize (AgStar PLC)",
                "concentration": "Micronutrient complex including Zn",
                "application": "Foliar spray",
                "dosage_en": "Follow product label (typically 1-2 liters/hectare)",
                "dosage_si": "නිෂ්පාදන ලේබලයේ උපදෙස් අනුගමනය කරන්න (සාමාන්‍යයෙන් 1-2 ලීටර්/හෙක්ටයාර්)",
                "notes": "Balanced micronutrient formula. Contains multiple nutrients including zinc."
            },
            {
                "name": "ZN Sulphate (Hayleys Agriculture)",
                "concentration": "33% Zn",
                "application": "Foliar spray or soil application",
                "dosage_en": "Follow product instructions (typically 2-5 kg/hectare foliar)",
                "dosage_si": "නිෂ්පාදන ලේබලයේ උපදෙස් අනුගමනය කරන්න (සාමාන්‍යයෙන් පත්‍ර 2-5 කිලෝග්‍රෑම්/හෙක්ටයාර්)",
                "notes": "Branded product from trusted supplier. Reliable quality."
            },
            {
                "name": "Speed / Supercell (Opex Holdings)",
                "concentration": "Micronutrient fortified",
                "application": "Foliar spray",
                "dosage_en": "Follow product instructions (typically 1-2 liters/hectare)",
                "dosage_si": "නිෂ්පාදන ලේබලයේ උපදෙස් අනුගමනය කරන්න (සාමාන්‍යයෙන් 1-2 ලීටර්/හෙක්ටයාර්)",
                "notes": "Premium product with enhanced formulation. Works well for zinc deficiency correction."
            }
        ],
        "timing": "Apply at first sign of symptoms for best results. Can be applied throughout growing season.",
        "precautions": "Zinc and copper can interact. Avoid over-application as it can cause toxicity."
    },
    
    "Healthy": {
        "deficiency": "No Deficiency",
        "description_en": "Your corn plant is healthy with optimal nutrient levels. Maintain current management practices.",
        "description_si": "ඔබගේ පැල සෞඛ්‍ය සම්පන්නයි හා පෝෂක මට්ටම් සාධාරණය. වර්තමාන කළමනාකරණ පියවර පවත්වා ගන්න.",
        "fertilizer_options": [
            {
                "name": "Balanced NPK Fertilizer",
                "concentration": "e.g., 10-10-10 or similar",
                "application": "Regular maintenance application",
                "dosage_en": "Follow soil test recommendations (typically 30-40 kg/hectare)",
                "dosage_si": "මට්ටමේ පරීක්ෂණ අනුව 30-40 කිලෝග්‍රෑම්/හෙක්ටයාර් යොදන්න",
                "notes": "For preventive maintenance to sustain health. Apply based on soil testing."
            }
        ],
        "timing": "Regular maintenance schedule based on crop stage and soil testing",
        "precautions": "Continue monitoring plant health. Re-test soil periodically."
    }
}

def get_fertilizer_recommendations(predicted_class: str) -> dict:
    """
    Get detailed fertilizer recommendations for a given nutrient deficiency.
    
    Args:
        predicted_class: One of 'NAB', 'PAB', 'KAB', 'ZNAB', or 'Healthy'
    
    Returns:
        Dictionary containing detailed fertilizer recommendations
    """
    if predicted_class in FERTILIZER_DATA:
        return FERTILIZER_DATA[predicted_class]
    else:
        return {
            "deficiency": "Unknown",
            "description_en": "Unable to determine nutrient deficiency.",
            "description_si": "පෝෂක ඌනතාවය තීරණය කළ නොහැකි.",
            "fertilizer_options": [],
            "timing": "Consult local agricultural expert",
            "precautions": "Contact agricultural extension service"
        }
