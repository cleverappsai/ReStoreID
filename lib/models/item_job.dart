// ========================================
// lib/models/item_job.dart
// ========================================
class ItemJob {
  final String id;
  final String description;
  final List<String> imagePaths;
  final DateTime createdAt;
  final DateTime? completedAt;
  Map<String, dynamic>? analysisResult;

  ItemJob({
    required this.id,
    required this.description,
    required this.imagePaths,
    required this.createdAt,
    this.completedAt,
    this.analysisResult,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'description': description,
      'imagePaths': imagePaths,
      'createdAt': createdAt.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'analysisResult': analysisResult,
    };
  }

  factory ItemJob.fromJson(Map<String, dynamic> json) {
    return ItemJob(
      id: json['id'],
      description: json['description'],
      imagePaths: List<String>.from(json['imagePaths']),
      createdAt: DateTime.parse(json['createdAt']),
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'])
          : null,
      analysisResult: json['analysisResult'],
    );
  }
}
