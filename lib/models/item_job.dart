// ========================================
// lib/models/item_job.dart
// ========================================
class ItemJob {
  final String id;
  final String userDescription; // Brief first-glance description
  final String searchDescription; // User's guidance for search

  // Separate measurement fields
  final String? length;
  final String? width;
  final String? height;
  final String? weight;

  // Quantity field
  final int quantity;

  final List<String> images;
  final DateTime createdAt;
  final DateTime? completedAt;
  Map<String, dynamic>? analysisResult;
  Map<String, List<String>>? imageClassification;
  Map<String, String>? ocrResults;
  List<String>? barcodes;
  List<String>? upcs;
  bool ocrCompleted;
  bool barcodeCompleted;
  bool classificationCompleted;
  bool webSearchCompleted;
  bool pricingCompleted;

  ItemJob({
    required this.id,
    required this.userDescription,
    required this.searchDescription,
    this.length,
    this.width,
    this.height,
    this.weight,
    this.quantity = 1,
    required this.images,
    required this.createdAt,
    this.completedAt,
    this.analysisResult,
    this.imageClassification,
    this.ocrResults,
    this.barcodes,
    this.upcs,
    this.ocrCompleted = false,
    this.barcodeCompleted = false,
    this.classificationCompleted = false,
    this.webSearchCompleted = false,
    this.pricingCompleted = false,
  });

  // Convenience getters for backward compatibility
  String get description => userDescription;
  List<String> get imagePaths => images;
  bool get isCompleted => analysisResult != null;

  // Combined measurements getter for display
  String get measurementsDisplay {
    List<String> parts = [];
    if (length?.isNotEmpty == true) parts.add('L: $length');
    if (width?.isNotEmpty == true) parts.add('W: $width');
    if (height?.isNotEmpty == true) parts.add('H: $height');
    if (weight?.isNotEmpty == true) parts.add('Wt: $weight');
    return parts.isEmpty ? 'No measurements' : parts.join(' • ');
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userDescription': userDescription,
      'searchDescription': searchDescription,
      'length': length,
      'width': width,
      'height': height,
      'weight': weight,
      'quantity': quantity,
      'images': images,
      'createdAt': createdAt.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'analysisResult': analysisResult,
      'imageClassification': imageClassification,
      'ocrResults': ocrResults,
      'barcodes': barcodes,
      'upcs': upcs,
      'ocrCompleted': ocrCompleted,
      'barcodeCompleted': barcodeCompleted,
      'classificationCompleted': classificationCompleted,
      'webSearchCompleted': webSearchCompleted,
      'pricingCompleted': pricingCompleted,
    };
  }

  factory ItemJob.fromJson(Map<String, dynamic> json) {
    return ItemJob(
      id: json['id'],
      userDescription: json['userDescription'] ?? json['description'] ?? '',
      searchDescription: json['searchDescription'] ?? '',
      length: json['length'],
      width: json['width'],
      height: json['height'],
      weight: json['weight'],
      quantity: json['quantity'] ?? 1,
      images: List<String>.from(json['images'] ?? json['imagePaths'] ?? []),
      createdAt: DateTime.parse(json['createdAt']),
      completedAt: json['completedAt'] != null ? DateTime.parse(json['completedAt']) : null,
      analysisResult: json['analysisResult'],
      imageClassification: json['imageClassification'] != null
          ? Map<String, List<String>>.from(json['imageClassification'].map((k, v) => MapEntry(k, List<String>.from(v))))
          : null,
      ocrResults: json['ocrResults'] != null ? Map<String, String>.from(json['ocrResults']) : null,
      barcodes: json['barcodes'] != null ? List<String>.from(json['barcodes']) : null,
      upcs: json['upcs'] != null ? List<String>.from(json['upcs']) : null,
      ocrCompleted: json['ocrCompleted'] ?? false,
      barcodeCompleted: json['barcodeCompleted'] ?? false,
      classificationCompleted: json['classificationCompleted'] ?? false,
      webSearchCompleted: json['webSearchCompleted'] ?? false,
      pricingCompleted: json['pricingCompleted'] ?? false,
    );
  }

  ItemJob copyWith({
    String? id,
    String? userDescription,
    String? searchDescription,
    String? length,
    String? width,
    String? height,
    String? weight,
    int? quantity,
    List<String>? images,
    DateTime? createdAt,
    DateTime? completedAt,
    Map<String, dynamic>? analysisResult,
    Map<String, List<String>>? imageClassification,
    Map<String, String>? ocrResults,
    List<String>? barcodes,
    List<String>? upcs,
    bool? ocrCompleted,
    bool? barcodeCompleted,
    bool? classificationCompleted,
    bool? webSearchCompleted,
    bool? pricingCompleted,
  }) {
    return ItemJob(
      id: id ?? this.id,
      userDescription: userDescription ?? this.userDescription,
      searchDescription: searchDescription ?? this.searchDescription,
      length: length ?? this.length,
      width: width ?? this.width,
      height: height ?? this.height,
      weight: weight ?? this.weight,
      quantity: quantity ?? this.quantity,
      images: images ?? this.images,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
      analysisResult: analysisResult ?? this.analysisResult,
      imageClassification: imageClassification ?? this.imageClassification,
      ocrResults: ocrResults ?? this.ocrResults,
      barcodes: barcodes ?? this.barcodes,
      upcs: upcs ?? this.upcs,
      ocrCompleted: ocrCompleted ?? this.ocrCompleted,
      barcodeCompleted: barcodeCompleted ?? this.barcodeCompleted,
      classificationCompleted: classificationCompleted ?? this.classificationCompleted,
      webSearchCompleted: webSearchCompleted ?? this.webSearchCompleted,
      pricingCompleted: pricingCompleted ?? this.pricingCompleted,
    );
  }
}