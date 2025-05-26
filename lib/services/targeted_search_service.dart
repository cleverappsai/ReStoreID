// ========================================
// lib/services/targeted_search_service.dart - SIMPLE VERSION
// ========================================
import '../models/item_job.dart';

class TargetedSearchService {
  /// Main method to perform targeted search analysis on an ItemJob
  static Future<TargetedSearchResults> performTargetedSearch(ItemJob job) async {
    try {
      // Simulate analysis time
      await Future.delayed(Duration(seconds: 3));

      // Create dummy analysis for now
      final summary = _generateDummySummary(job);
      final products = _generateDummyProducts(job);
      final sources = _generateDummySources(job);

      return TargetedSearchResults(
        summary: summary,
        identifiedProducts: products,
        searchSources: sources,
        analysisDate: DateTime.now(),
        analysisVersion: '1.0-demo',
        rawData: {
          'searchQueries': [job.userDescription, job.searchDescription],
          'ocrText': job.ocrResults?.values.join(' ') ?? '',
        },
      );

    } catch (e) {
      // Return empty results with error info
      return TargetedSearchResults(
        summary: 'Analysis failed: ${e.toString()}',
        identifiedProducts: [],
        searchSources: [],
        analysisDate: DateTime.now(),
        rawData: {'error': e.toString()},
      );
    }
  }

  static String _generateDummySummary(ItemJob job) {
    final buffer = StringBuffer();

    buffer.writeln('Product Analysis Summary');
    buffer.writeln('Generated: ${DateTime.now().toString().split('.')[0]}');
    buffer.writeln();

    buffer.writeln('📝 Item Description:');
    buffer.writeln('${job.userDescription}');
    buffer.writeln();

    if (job.searchDescription.isNotEmpty) {
      buffer.writeln('🔍 Search Keywords:');
      buffer.writeln('${job.searchDescription}');
      buffer.writeln();
    }

    if (job.measurementsDisplay != 'No measurements') {
      buffer.writeln('📏 Measurements:');
      buffer.writeln('${job.measurementsDisplay}');
      buffer.writeln();
    }

    buffer.writeln('📊 Analysis Status:');
    buffer.writeln('• Images processed: ${job.images.length}');
    buffer.writeln('• OCR completed: ${job.ocrCompleted ? "Yes" : "No"}');
    buffer.writeln('• Text extracted: ${job.ocrResults?.length ?? 0} segments');

    if (job.barcodes?.isNotEmpty == true) {
      buffer.writeln('• Barcodes found: ${job.barcodes!.length}');
    }

    buffer.writeln();
    buffer.writeln('🎯 Demo Analysis Complete');
    buffer.writeln('This is a demonstration of the targeted search functionality.');
    buffer.writeln('Full search integration with Google Custom Search API will be available when API keys are configured.');

    return buffer.toString();
  }

  static List<ProductIdentifier> _generateDummyProducts(ItemJob job) {
    final products = <ProductIdentifier>[];

    // Extract potential brand/model from descriptions
    final allText = '${job.userDescription} ${job.searchDescription} ${job.ocrResults?.values.join(' ') ?? ''}'.toLowerCase();

    // Demo product based on common keywords
    if (allText.contains('camera') || allText.contains('canon') || allText.contains('nikon')) {
      products.add(ProductIdentifier(
        manufacturer: 'Canon',
        productName: 'Digital Camera',
        modelNumber: 'EOS-DEMO',
        confidence: 0.75,
        specifications: {
          'type': 'Digital SLR Camera',
          'resolution': 'Demo specifications',
        },
      ));
    } else if (allText.contains('phone') || allText.contains('samsung') || allText.contains('apple')) {
      products.add(ProductIdentifier(
        manufacturer: 'Samsung',
        productName: 'Smartphone',
        modelNumber: 'DEMO-123',
        confidence: 0.65,
        specifications: {
          'type': 'Mobile Phone',
          'screen': 'Demo specifications',
        },
      ));
    } else {
      // Generic product
      products.add(ProductIdentifier(
        manufacturer: 'Demo Brand',
        productName: 'Product Demo',
        modelNumber: 'DEMO-001',
        confidence: 0.50,
        specifications: {
          'note': 'This is demonstration data',
        },
      ));
    }

    return products;
  }

  static List<SearchSource> _generateDummySources(ItemJob job) {
    return [
      SearchSource(
        url: 'https://example.com/manufacturer',
        title: 'Manufacturer Product Page (Demo)',
        sourceType: 'manufacturer',
        relevanceScore: 0.85,
        lastAccessed: DateTime.now(),
        contentSummary: 'Official product information and specifications',
      ),
      SearchSource(
        url: 'https://example.com/retailer',
        title: 'Retailer Product Listing (Demo)',
        sourceType: 'retailer',
        relevanceScore: 0.70,
        lastAccessed: DateTime.now(),
        contentSummary: 'Product listing with pricing information',
      ),
      SearchSource(
        url: 'https://example.com/review',
        title: 'Product Review (Demo)',
        sourceType: 'review',
        relevanceScore: 0.60,
        lastAccessed: DateTime.now(),
        contentSummary: 'User review and product evaluation',
      ),
    ];
  }
}