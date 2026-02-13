class SafetyRecommendation {
  final String severity;
  final String message;
  final List<String> actions;
  final String source;

  SafetyRecommendation({
    required this.severity,
    required this.message,
    required this.actions,
    required this.source,
  });

  factory SafetyRecommendation.fromJson(Map<String, dynamic> json) {
    return SafetyRecommendation(
      severity: json['severity'] ?? 'Unknown',
      message: json['message'] ?? '',
      actions: List<String>.from(json['actions'] ?? []),
      source: json['source'] ?? 'Guardianly AI',
    );
  }
}