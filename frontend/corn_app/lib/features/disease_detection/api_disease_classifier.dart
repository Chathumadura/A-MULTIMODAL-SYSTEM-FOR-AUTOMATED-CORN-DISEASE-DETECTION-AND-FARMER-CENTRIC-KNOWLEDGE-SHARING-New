import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint;

import '../../core/api/api_client.dart';
import 'disease_classifier.dart';
import 'disease_prediction.dart';

class ApiDiseaseClassifier implements DiseaseClassifier {
  final ApiClient _apiClient;

  ApiDiseaseClassifier({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  @override
  Future<DiseasePrediction> predict(File imageFile) async {
    debugPrint(
      '🔍 [DiseaseClassifier] Starting disease prediction for ${imageFile.path}',
    );

    try {
      final response = await _apiClient.uploadImageForDiseaseDetection(
        imageFile,
      );
      debugPrint('✅ [DiseaseClassifier] API response received: $response');

      final prediction = response['prediction'] as String;
      final confidence = (response['confidence'] as num).toDouble();
      final allProbabilities =
          (response['all_probabilities'] as Map<String, dynamic>?)?.map(
            (key, value) => MapEntry(key, (value as num).toDouble()),
          );

      final topK =
          allProbabilities?.entries
              .map((entry) => MapEntry(entry.key, entry.value))
              .toList()
            ?..sort((a, b) => b.value.compareTo(a.value));

      debugPrint(
        '✅ [DiseaseClassifier] Parsed prediction: $prediction, confidence: $confidence',
      );

      return DiseasePrediction(
        label: prediction,
        confidence: confidence,
        topK: topK ?? [],
      );
    } catch (e) {
      debugPrint('❌ [DiseaseClassifier] Error: $e');
      rethrow;
    }
  }
}
