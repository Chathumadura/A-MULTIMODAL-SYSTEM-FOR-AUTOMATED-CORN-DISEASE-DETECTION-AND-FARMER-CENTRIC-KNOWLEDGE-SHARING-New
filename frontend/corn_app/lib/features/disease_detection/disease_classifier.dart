import 'dart:io';

import 'disease_prediction.dart';

abstract class DiseaseClassifier {
  Future<DiseasePrediction> predict(File imageFile);
}

// TODO: Implement TensorFlow Lite inference and label mapping.
class TfliteDiseaseClassifier implements DiseaseClassifier {
  @override
  Future<DiseasePrediction> predict(File imageFile) {
    throw UnimplementedError('TfliteDiseaseClassifier is not implemented yet.');
  }
}
