// ========================================
// lib/models/item_job.dart - UPDATED WITH TARGETED SEARCH
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

  // NEW: Enhanced analysis results for targeted search
  TargetedSearchResults? targetedSearchResults;

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
    this.targetedSearchResults, // NEW
  });

  // Convenience getters for backward compatibility
  String get description => userDescription;
  List<String> get imagePaths => images;
  bool get isCompleted => analysisResult != null;

  // NEW: Targeted search getters
  bool get hasTargetedSearchResults => targetedSearchResults != null;
  bool get hasHighConfidenceProducts =>
      targetedSearchResults?.identifiedProducts.any((p) => p.confidence >= 0.8) ?? false;

  String get targetedSearchStatus {
    if (targetedSearchResults == null) return 'Not analyzed';
    final daysSince = DateTime.now().difference(targetedSearchResults!.analysisDate).inDays;
    if (daysSince == 0) return 'Analyzed today';
    if (daysSince == 1) return 'Analyzed yesterday';
    return 'Analyzed $daysSince days ago';
  }

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
      'targetedSearchResults': targetedSearchResults?.toJson(), // NEW
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
      targetedSearchResults: json['targetedSearchResults'] != null // NEW
          ? TargetedSearchResults.fromJson(json['targetedSearchResults'])
          : null,
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
    TargetedSearchResults? targetedSearchResults, // NEW
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
      targetedSearchResults: targetedSearchResults ?? this.targetedSearchResults, // NEW
    );
  }
}

// NEW: Targeted search results data structures
class TargetedSearchResults {
  final String summary;
  final List<ProductIdentifier> identifiedProducts;
  final List<SearchSource> searchSources;
  final DateTime analysisDate;
  final String? analysisVersion;
  final Map<String, dynamic>? rawData;

  TargetedSearchResults({
    required this.summary,
    required this.identifiedProducts,
    required this.searchSources,
    required this.analysisDate,
    this.analysisVersion,
    this.rawData,
  });

  TargetedSearchResults copyWith({
    String? summary,
    List<ProductIdentifier>? identifiedProducts,
    List<SearchSource>? searchSources,
    DateTime? analysisDate,
    String? analysisVersion,
    Map<String, dynamic>? rawData,
  }) {
    return TargetedSearchResults(
      summary: summary ?? this.summary,
      identifiedProducts: identifiedProducts ?? this.identifiedProducts,
      searchSources: searchSources ?? this.searchSources,
      analysisDate: analysisDate ?? this.analysisDate,
      analysisVersion: analysisVersion ?? this.analysisVersion,
      rawData: rawData ?? this.rawData,
    );
  }

  // Helper methods
  int get manufacturerSourcesCount =>
      searchSources.where((s) => s.sourceType == 'manufacturer').length;

  int get retailerSourcesCount =>
      searchSources.where((s) => s.sourceType == 'retailer').length;

  double get averageConfidence {
    if (identifiedProducts.isEmpty) return 0.0;
    return identifiedProducts.map((p) => p.confidence).reduce((a, b) => a + b) / identifiedProducts.length;
  }

  bool get hasHighConfidence {
    return identifiedProducts.isNotEmpty &&
        identifiedProducts.any((p) => p.confidence >= 0.8) &&
        manufacturerSourcesCount > 0;
  }

  Map<String, dynamic> toJson() => {
    'summary': summary,
    'identifiedProducts': identifiedProducts.map((p) => p.toJson()).toList(),
    'searchSources': searchSources.map((s) => s.toJson()).toList(),
    'analysisDate': analysisDate.toIso8601String(),
    'analysisVersion': analysisVersion,
    'rawData': rawData,
  };

  factory TargetedSearchResults.fromJson(Map<String, dynamic> json) => TargetedSearchResults(
    summary: json['summary'] ?? '',
    identifiedProducts: (json['identifiedProducts'] as List? ?? [])
        .map((p) => ProductIdentifier.fromJson(p))
        .toList(),
    searchSources: (json['searchSources'] as List? ?? [])
        .map((s) => SearchSource.fromJson(s))
        .toList(),
    analysisDate: DateTime.parse(json['analysisDate'] ?? DateTime.now().toIso8601String()),
    analysisVersion: json['analysisVersion'],
    rawData: json['rawData'],
  );
}

// Product identification from OCR
class ProductIdentifier {
  final String manufacturer;
  final String productName;
  final String modelNumber;
  final double confidence;
  final Map<String, dynamic>? specifications;
  final List<String>? alternativeNames;

  ProductIdentifier({
    required this.manufacturer,
    required this.productName,
    required this.modelNumber,
    required this.confidence,
    this.specifications,
    this.alternativeNames,
  });

  String get fullName => '$manufacturer $productName';

  String get confidenceLevel {
    if (confidence >= 0.9) return 'Very High';
    if (confidence >= 0.8) return 'High';
    if (confidence >= 0.6) return 'Medium';
    if (confidence >= 0.4) return 'Low';
    return 'Very Low';
  }

  Map<String, dynamic> toJson() => {
    'manufacturer': manufacturer,
    'productName': productName,
    'modelNumber': modelNumber,
    'confidence': confidence,
    'specifications': specifications,
    'alternativeNames': alternativeNames,
  };

  factory ProductIdentifier.fromJson(Map<String, dynamic> json) => ProductIdentifier(
    manufacturer: json['manufacturer'] ?? '',
    productName: json['productName'] ?? '',
    modelNumber: json['modelNumber'] ?? '',
    confidence: (json['confidence'] ?? 0.0).toDouble(),
    specifications: json['specifications'],
    alternativeNames: json['alternativeNames']?.cast<String>(),
  );
}

// Search source information
class SearchSource {
  final String url;
  final String title;
  final String sourceType;
  final double relevanceScore;
  final DateTime? lastAccessed;
  final Map<String, dynamic>? extractedData;
  final String? contentSummary;

  SearchSource({
    required this.url,
    required this.title,
    required this.sourceType,
    required this.relevanceScore,
    this.lastAccessed,
    this.extractedData,
    this.contentSummary,
  });

  String get domain {
    try {
      return Uri.parse(url).host;
    } catch (e) {
      return 'Unknown';
    }
  }

  bool get isOfficialSource => sourceType == 'manufacturer';

  String get relevanceDescription {
    if (relevanceScore >= 0.9) return 'Highly Relevant';
    if (relevanceScore >= 0.7) return 'Very Relevant';
    if (relevanceScore >= 0.5) return 'Relevant';
    if (relevanceScore >= 0.3) return 'Somewhat Relevant';
    return 'Low Relevance';
  }

  Map<String, dynamic> toJson() => {
    'url': url,
    'title': title,
    'sourceType': sourceType,
    'relevanceScore': relevanceScore,
    'lastAccessed': lastAccessed?.toIso8601String(),
    'extractedData': extractedData,
    'contentSummary': contentSummary,
  };

  factory SearchSource.fromJson(Map<String, dynamic> json) => SearchSource(
    url: json['url'] ?? '',
    title: json['title'] ?? '',
    sourceType: json['sourceType'] ?? '',
    relevanceScore: (json['relevanceScore'] ?? 0.0).toDouble(),
    lastAccessed: json['lastAccessed'] != null
        ? DateTime.parse(json['lastAccessed'])
        : null,
    extractedData: json['extractedData'],
    contentSummary: json['contentSummary'],
  );
}