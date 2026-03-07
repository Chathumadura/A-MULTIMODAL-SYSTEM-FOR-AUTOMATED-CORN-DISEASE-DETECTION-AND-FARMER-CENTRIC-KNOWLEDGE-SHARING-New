class DiseasePrediction {
  final String label;
  final double confidence;
  final List<MapEntry<String, double>> topK;

  const DiseasePrediction({
    required this.label,
    required this.confidence,
    required this.topK,
  });
}
