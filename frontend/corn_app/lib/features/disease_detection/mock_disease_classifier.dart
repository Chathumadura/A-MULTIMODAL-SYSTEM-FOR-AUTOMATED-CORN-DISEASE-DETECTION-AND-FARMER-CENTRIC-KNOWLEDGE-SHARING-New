import 'dart:io';

import 'disease_classifier.dart';
import 'disease_prediction.dart';

class MockDiseaseClassifier implements DiseaseClassifier {
  static const List<String> _classes = [
    'Blight',
    'Common_Rust',
    'Gray_Leaf_Spot',
    'Healthy',
  ];

  @override
  Future<DiseasePrediction> predict(File imageFile) async {
    final bytes = await imageFile.readAsBytes();
    final seed = _stableHash(bytes, imageFile.path);

    final ordered = List<int>.generate(_classes.length, (i) => i)
      ..sort((a, b) => _classScore(seed, b).compareTo(_classScore(seed, a)));

    final top3Indices = ordered.take(3).toList();
    final raw = top3Indices
        .map((index) => 0.2 + (_classScore(seed, index) / 1000.0) * 0.8)
        .toList();

    final normalized = _normalize(raw);
    final topK = List<MapEntry<String, double>>.generate(
      3,
      (i) => MapEntry(_classes[top3Indices[i]], normalized[i]),
    );

    return DiseasePrediction(
      label: topK.first.key,
      confidence: topK.first.value,
      topK: topK,
    );
  }

  int _stableHash(List<int> bytes, String path) {
    var hash = 2166136261;
    for (final value in bytes) {
      hash ^= value;
      hash = (hash * 16777619) & 0x7fffffff;
    }
    for (final codeUnit in path.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 16777619) & 0x7fffffff;
    }
    return hash;
  }

  int _classScore(int seed, int classIndex) {
    final mixed = (seed ^ ((classIndex + 1) * 0x45d9f3b)) & 0x7fffffff;
    return mixed % 1000;
  }

  List<double> _normalize(List<double> values) {
    final sum = values.reduce((a, b) => a + b);
    final first = double.parse((values[0] / sum).toStringAsFixed(4));
    final second = double.parse((values[1] / sum).toStringAsFixed(4));
    final third = double.parse((1.0 - first - second).toStringAsFixed(4));
    return [first, second, third];
  }
}
