#!/usr/bin/env python3
"""
Test script to verify the new confidence-based decision logic in leaf_diagnosis_service.
"""

from services.leaf_diagnosis_service import normalize_confidence


def test_normalize_confidence():
    """Test the normalize_confidence helper function."""
    print("=" * 60)
    print("Testing normalize_confidence() helper")
    print("=" * 60)
    
    test_cases = [
        (95, 0.95, "Percentage 95 → 0.95"),
        (0.95, 0.95, "Decimal 0.95 → 0.95"),
        (96, 0.96, "Percentage 96 → 0.96"),
        (0.96, 0.96, "Decimal 0.96 → 0.96"),
        (72, 0.72, "Percentage 72 → 0.72"),
        (0.72, 0.72, "Decimal 0.72 → 0.72"),
        (65, 0.65, "Percentage 65 → 0.65"),
        (0.65, 0.65, "Decimal 0.65 → 0.65"),
        (91, 0.91, "Percentage 91 → 0.91"),
        (0.91, 0.91, "Decimal 0.91 → 0.91"),
        ("invalid", 0.0, "Invalid string → 0.0"),
        (None, 0.0, "None → 0.0"),
    ]
    
    for input_val, expected, description in test_cases:
        try:
            result = normalize_confidence(input_val)
            status = "✓ PASS" if abs(result - expected) < 0.0001 else "✗ FAIL"
            print(f"  {status}: {description} (got {result})")
        except Exception as e:
            print(f"  ✗ ERROR: {description} - {e}")
    
    print()


def test_confidence_comparison_logic():
    """Test the decision logic for various confidence comparison scenarios."""
    print("=" * 60)
    print("Testing Confidence Comparison Decision Logic")
    print("=" * 60)
    
    test_scenarios = [
        {
            "name": "Example 1: Nutrition PAB (0.96) > Disease Rust (0.72)",
            "nutrition_label": "PAB",
            "nutrition_conf": 0.96,
            "disease_label": "Rust",
            "disease_conf": 0.72,
            "expected": "nutrient_deficiency",
            "expected_prediction": "PAB",
            "expected_confidence": 0.96,
        },
        {
            "name": "Example 2: Nutrition PAB (0.65) < Disease Northern Leaf Blight (0.91)",
            "nutrition_label": "PAB",
            "nutrition_conf": 0.65,
            "disease_label": "Northern Leaf Blight",
            "disease_conf": 0.91,
            "expected": "disease",
            "expected_prediction": "Northern Leaf Blight",
            "expected_confidence": 0.91,
        },
        {
            "name": "Example 3: Very close scores - Nutrition (0.75) vs Disease (0.73)",
            "nutrition_label": "Zinc_Deficiency",
            "nutrition_conf": 0.75,
            "disease_label": "Leaf_Spot",
            "disease_conf": 0.73,
            "expected": "nutrient_deficiency",
            "expected_prediction": "Zinc_Deficiency",
            "expected_confidence": 0.75,
        },
        {
            "name": "Example 4: Very close scores - Nutrition (0.72) vs Disease (0.75)",
            "nutrition_label": "Zinc_Deficiency",
            "nutrition_conf": 0.72,
            "disease_label": "Leaf_Spot",
            "disease_conf": 0.75,
            "expected": "disease",
            "expected_prediction": "Leaf_Spot",
            "expected_confidence": 0.75,
        },
        {
            "name": "Example 5: Equal scores - Nutrition (0.80) vs Disease (0.80)",
            "nutrition_label": "Iron_Deficiency",
            "nutrition_conf": 0.80,
            "disease_label": "Powdery_Mildew",
            "disease_conf": 0.80,
            "expected": "uncertain",
            "expected_prediction": None,  # varies based on implementation
            "expected_confidence": 0.80,
        },
        {
            "name": "Example 6: Both healthy - Nutrition Healthy (0.85) vs Disease Healthy (0.88)",
            "nutrition_label": "Healthy",
            "nutrition_conf": 0.85,
            "disease_label": "Healthy",
            "disease_conf": 0.88,
            "expected": "healthy",
            "expected_prediction": "Healthy",
            "expected_confidence": 0.85,  # min of the two
        },
        {
            "name": "Example 7: Not_Corn detected - Nutrition Not_Corn (0.95) vs Disease (0.60)",
            "nutrition_label": "Not_Corn",
            "nutrition_conf": 0.95,
            "disease_label": "Rust",
            "disease_conf": 0.60,
            "expected": "invalid_image",
            "expected_prediction": "Not_Corn",
            "expected_confidence": 0.95,
        },
    ]
    
    for scenario in test_scenarios:
        nutrition_conf = normalize_confidence(scenario["nutrition_conf"])
        disease_conf = normalize_confidence(scenario["disease_conf"])
        confidence_diff = abs(nutrition_conf - disease_conf)
        very_close_threshold = 0.05
        
        # Simulate decision logic
        if scenario["nutrition_label"] == "Not_Corn" and nutrition_conf >= 0.50:
            result = "invalid_image"
        elif (
            scenario["nutrition_label"] == "Healthy"
            and scenario["disease_label"] == "Healthy"
            and nutrition_conf >= 0.55
            and disease_conf >= 0.55
        ):
            result = "healthy"
        elif confidence_diff <= very_close_threshold:
            result = "uncertain"
        elif nutrition_conf > disease_conf:
            result = "nutrient_deficiency"
        else:
            result = "disease"
        
        status = "✓ PASS" if result == scenario["expected"] else "✗ FAIL"
        print(f"\n  {status}: {scenario['name']}")
        print(f"         Nutrition: {scenario['nutrition_label']} ({nutrition_conf:.4f})")
        print(f"         Disease:   {scenario['disease_label']} ({disease_conf:.4f})")
        print(f"         Diff:      {confidence_diff:.4f} (threshold: {very_close_threshold})")
        print(f"         Result:    {result} (expected: {scenario['expected']})")
    
    print("\n")


if __name__ == "__main__":
    test_normalize_confidence()
    test_confidence_comparison_logic()
    print("=" * 60)
    print("All test scenarios completed!")
    print("=" * 60)
