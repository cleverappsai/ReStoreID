// ========================================
// lib/services/enhanced_analysis_service.dart
// ========================================
import 'dart:convert';
import '../models/item_job.dart';
import '../services/targeted_search_service.dart';
import '../services/content_scraping_service.dart';
import '../services/summary_generation_service.dart';
import '../services/cloud_services.dart';
import '../services/storage_service.dart';

class EnhancedAnalysisService {

  /// Complete analysis pipeline for an item
  static Future<Map<String, dynamic>> performCompleteAnalysis(ItemJob item) async {
    try {
      // Step 1: Extract product identifiers from OCR results
      final productInfo = await _analyzeProductInformation(item);

      // Step 2: Perform targeted searches
      final searchResults = await _performTargetedSearches(productInfo);

      // Step 3: Scrape content from search results
      final scrapedContent = await _scrapeTargetedContent(searchResults, productInfo);

      // Step 4: Generate enhanced summary
      final summary = await _generateEnhancedSummary(item, productInfo, scrapedContent);

      // Step 5: Compile final analysis result
      final analysisResult = _compileAnalysisResult(item, productInfo, searchResults, scrapedContent, summary);

      // Step 6: Update item with results
      await _updateItemWithResults(item, analysisResult);

      return {
        'success': true,
        'analysis': analysisResult,
        'timestamp': DateTime.now().toIso8601String(),
      };

    } catch (e) {
      print('Enhanced analysis failed: $e');
      return {
        'success': false,
        'error': e.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }

  /// Step 1: Analyze product information from OCR and images
  static Future<Map<String, dynamic>> _analyzeProductInformation(ItemJob item) async {
    Map<String, dynamic> productInfo = {
      'manufacturer': '',
      'productName': '',
      'modelNumber': '',
      'partNumber': '',
      'serialNumber': '',
      'upc': '',
      'searchTerms': <String>[],
      'confidence': 0.0,
    };

    // Extract from existing OCR results if available
    if (item.ocrResults != null && item.ocrResults!.isNotEmpty) {
      productInfo = TargetedSearchService.extractProductIdentifiers(item.ocrResults!);
    } else {
      // Perform OCR on all images
      final ocrResults = await CloudServices.performOCR(item.images);
      if (ocrResults.isNotEmpty) {
        productInfo = TargetedSearchService.extractProductIdentifiers(ocrResults);

        // Update item with OCR results
        final updatedItem = item.copyWith(
          ocrResults: ocrResults,
          ocrCompleted: true,
        );
        await StorageService.saveJob(updatedItem);
      }
    }

    // Enhance with user descriptions
    if (productInfo['manufacturer'].toString().isEmpty && item.userDescription.isNotEmpty) {
      final userDescription = item.userDescription.toLowerCase();
      final possibleManufacturer = _extractManufacturerFromDescription(userDescription);
      if (possibleManufacturer.isNotEmpty) {
        productInfo['manufacturer'] = possibleManufacturer;
      }
    }

    if (productInfo['productName'].toString().isEmpty && item.userDescription.isNotEmpty) {
      productInfo['productName'] = item.userDescription;
    }

    // Add search guidance from user
    if (item.searchDescription.isNotEmpty) {
      final searchTerms = List<String>.from(productInfo['searchTerms']);
      searchTerms.addAll(item.searchDescription.split(' ').where((term) => term.length > 2));
      productInfo['searchTerms'] = searchTerms.toSet().toList();
    }

    return productInfo;
  }

  /// Step 2: Perform targeted searches
  static Future<Map<String, dynamic>> _performTargetedSearches(Map<String, dynamic> productInfo) async {
    if (productInfo['manufacturer'].toString().isEmpty && productInfo['productName'].toString().isEmpty) {
      return {
        'success': false,
        'message': 'Insufficient product information for targeted search',
        'searchResults': <Map<String, dynamic>>[],
      };
    }

    return await TargetedSearchService.performTargetedSearch(
      manufacturer: productInfo['manufacturer'] ?? '',
      productName: productInfo['productName'] ?? '',
      modelNumber: productInfo['modelNumber'],
      partNumber: productInfo['partNumber'],
    );
  }

  /// Step 3: Scrape content from search results
  static Future<Map<String, dynamic>> _scrapeTargetedContent(
      Map<String, dynamic> searchResults,
      Map<String, dynamic> productInfo,
      ) async {

    if (searchResults['success'] != true ||
        (searchResults['searchResults'] as List).isEmpty) {
      return {
        'success': false,
        'message': 'No search results available for content scraping',
      };
    }

    final results = List<Map<String, dynamic>>.from(searchResults['searchResults']);

    return await ContentScrapingService.scrapeTargetedContent(
      searchResults: results,
      manufacturer: productInfo['manufacturer'] ?? '',
      productName: productInfo['productName'] ?? '',
    );
  }

  /// Step 4: Generate enhanced summary
  static Future<Map<String, dynamic>> _generateEnhancedSummary(
      ItemJob item,
      Map<String, dynamic> productInfo,
      Map<String, dynamic> scrapedContent,
      ) async {

    List<Map<String, dynamic>> dataSources = [];

    // Prepare data sources for summary generation
    if (scrapedContent['success'] == true && scrapedContent['rawContent'] != null) {
      final rawContent = List<Map<String, dynamic>>.from(scrapedContent['rawContent']);

      for (var content in rawContent) {
        if (content['success'] == true && content['extractedData'] != null) {
          final extractedData = content['extractedData'];

          // Build full text from extracted data
          List<String> textParts = [];

          if (extractedData['title'] != null) {
            textParts.add('Title: ${extractedData['title']}');
          }

          if (extractedData['description'] != null) {
            textParts.add('Description: ${extractedData['description']}');
          }

          if (extractedData['productDescription'] != null) {
            textParts.add('Product Description: ${extractedData['productDescription']}');
          }

          if (extractedData['specifications'] != null) {
            final specs = List<String>.from(extractedData['specifications']);
            if (specs.isNotEmpty) {
              textParts.add('Specifications: ${specs.join('; ')}');
            }
          }

          if (extractedData['features'] != null) {
            final features = List<String>.from(extractedData['features']);
            if (features.isNotEmpty) {
              textParts.add('Features: ${features.join('; ')}');
            }
          }

          if (extractedData['applications'] != null) {
            final applications = List<String>.from(extractedData['applications']);
            if (applications.isNotEmpty) {
              textParts.add('Applications: ${applications.join('; ')}');
            }
          }

          dataSources.add({
            'url': content['url'],
            'title': extractedData['title'] ?? 'Scraped Content',
            'fullText': textParts.join('\n\n'),
            'confidence': extractedData['confidence'] ?? 0.5,
            'dataType': extractedData['dataType'] ?? 'web_scrape',
            'scrapedAt': content['scrapedAt'],
          });
        }
      }
    }

    // Add fallback content if no scraped data
    if (dataSources.isEmpty) {
      // Use OCR results as fallback
      if (item.ocrResults != null) {
        dataSources.add({
          'url': 'internal_ocr',
          'title': 'OCR Extracted Text',
          'fullText': item.ocrResults!.values.join('\n\n'),
          'confidence': 0.3,
          'dataType': 'ocr',
          'scrapedAt': DateTime.now().toIso8601String(),
        });
      }
    }

    // Generate summary using enhanced data
    return await SummaryGenerationService.generateItemSummary(
      dataSources: dataSources,
      userDescription: item.userDescription,
      searchKeywords: [
        productInfo['manufacturer'] ?? '',
        productInfo['productName'] ?? '',
        productInfo['modelNumber'] ?? '',
        item.searchDescription,
      ].where((s) => s.isNotEmpty).join(' '),
    );
  }

  /// Step 5: Compile final analysis result
  static Map<String, dynamic> _compileAnalysisResult(
      ItemJob item,
      Map<String, dynamic> productInfo,
      Map<String, dynamic> searchResults,
      Map<String, dynamic> scrapedContent,
      Map<String, dynamic> summary,
      ) {

    // Calculate overall confidence
    double overallConfidence = 0.2;
    int confidenceFactors = 0;

    if (productInfo['confidence'] != null) {
      overallConfidence += (productInfo['confidence'] as double) * 0.3;
      confidenceFactors++;
    }

    if (scrapedContent['overallConfidence'] != null) {
      overallConfidence += (scrapedContent['overallConfidence'] as double) * 0.4;
      confidenceFactors++;
    }

    if (summary['confidence'] != null) {
      overallConfidence += (summary['confidence'] as double) * 0.3;
      confidenceFactors++;
    }

    if (confidenceFactors > 0) {
      overallConfidence = overallConfidence / confidenceFactors;
    }

    // Compile pricing information
    Map<String, dynamic> pricingInfo = {};
    if (scrapedContent['processedData'] != null &&
        scrapedContent['processedData']['pricingData'] != null) {
      final pricingData = scrapedContent['processedData']['pricingData'];
      if (pricingData is List && pricingData.isNotEmpty) {
        pricingInfo = SummaryGenerationService.generatePricingSummary(
            List<Map<String, dynamic>>.from(pricingData)
        );
      }
    }

    return {
      'itemId': item.id,
      'analysisVersion': '2.0',
      'analysisType': 'enhanced_targeted',
      'completedAt': DateTime.now().toIso8601String(),
      'overallConfidence': overallConfidence,

      // Product Information
      'productInfo': productInfo,

      // Search Results Summary
      'searchSummary': {
        'success': searchResults['success'] ?? false,
        'searchCount': searchResults['searchCount'] ?? 0,
        'resultsFound': searchResults['resultsFound'] ?? 0,
        'manufacturer': searchResults['manufacturer'] ?? '',
        'productName': searchResults['productName'] ?? '',
      },

      // Content Summary
      'contentSummary': {
        'success': scrapedContent['success'] ?? false,
        'contentScraped': scrapedContent['contentScraped'] ?? 0,
        'contentTypes': scrapedContent['contentTypes'] ?? {},
        'overallConfidence': scrapedContent['overallConfidence'] ?? 0.0,
      },

      // Generated Summary
      'summary': summary,

      // Pricing Information
      'pricing': pricingInfo,

      // Processing Stats
      'processingStats': {
        'ocrCompleted': item.ocrCompleted,
        'classificationCompleted': item.classificationCompleted,
        'searchesPerformed': searchResults['searchCount'] ?? 0,
        'contentScraped': scrapedContent['contentScraped'] ?? 0,
        'summaryGenerated': summary['success'] ?? false,
      },

      // Raw Data (for debugging/review)
      'rawData': {
        'searchResults': searchResults,
        'scrapedContent': scrapedContent,
        'productIdentification': productInfo,
      },
    };
  }

  /// Step 6: Update item with results
  static Future<void> _updateItemWithResults(ItemJob item, Map<String, dynamic> analysisResult) async {
    final updatedItem = item.copyWith(
      analysisResult: analysisResult,
      completedAt: DateTime.now(),
      webSearchCompleted: true,
      pricingCompleted: analysisResult['pricing']?.isNotEmpty == true,
    );

    await StorageService.saveJob(updatedItem);
  }

  /// Extract manufacturer from user description
  static String _extractManufacturerFromDescription(String description) {
    final knownBrands = [
      'apple', 'samsung', 'sony', 'lg', 'panasonic', 'canon', 'nikon',
      'dewalt', 'makita', 'bosch', 'craftsman', 'black+decker', 'ryobi',
      'kitchenaid', 'cuisinart', 'hamilton beach', 'oster', 'ninja',
      'dell', 'hp', 'lenovo', 'asus', 'acer', 'microsoft',
    ];

    final words = description.toLowerCase().split(' ');
    for (String word in words) {
      if (knownBrands.contains(word)) {
        // Capitalize first letter
        return word[0].toUpperCase() + word.substring(1);
      }
    }

    return '';
  }

  /// Trigger background analysis for a newly created item
  static Future<void> triggerBackgroundAnalysis(ItemJob item) async {
    try {
      // Run analysis in background (don't await)
      Future.microtask(() async {
        await performCompleteAnalysis(item);
      });
    } catch (e) {
      print('Background analysis trigger failed: $e');
    }
  }

  /// Get analysis status for an item
  static Map<String, dynamic> getAnalysisStatus(ItemJob item) {
    if (item.analysisResult != null) {
      final result = item.analysisResult!;
      return {
        'status': 'completed',
        'completedAt': result['completedAt'],
        'confidence': result['overallConfidence'] ?? 0.0,
        'analysisType': result['analysisType'] ?? 'standard',
        'hasProductInfo': result['productInfo'] != null,
        'hasSearchResults': result['searchSummary']?['success'] == true,
        'hasContentScraped': result['contentSummary']?['success'] == true,
        'hasSummary': result['summary']?['success'] == true,
        'hasPricing': result['pricing']?['success'] == true,
      };
    }

    // Check individual completion flags
    List<String> completedSteps = [];
    List<String> pendingSteps = [];

    if (item.ocrCompleted) {
      completedSteps.add('OCR Processing');
    } else {
      pendingSteps.add('OCR Processing');
    }

    if (item.classificationCompleted) {
      completedSteps.add('Image Classification');
    } else {
      pendingSteps.add('Image Classification');
    }

    if (item.webSearchCompleted) {
      completedSteps.add('Web Search');
    } else {
      pendingSteps.add('Web Search');
    }

    if (item.pricingCompleted) {
      completedSteps.add('Pricing Analysis');
    } else {
      pendingSteps.add('Pricing Analysis');
    }

    String status = 'in_progress';
    if (pendingSteps.isEmpty) {
      status = 'completed';
    } else if (completedSteps.isEmpty) {
      status = 'pending';
    }

    return {
      'status': status,
      'completedSteps': completedSteps,
      'pendingSteps': pendingSteps,
      'progress': completedSteps.length / (completedSteps.length + pendingSteps.length),
    };
  }

  /// Regenerate summary for an existing item
  static Future<Map<String, dynamic>> regenerateSummary(ItemJob item, {
    String? additionalGuidance,
    bool useAIGeneration = true,
  }) async {

    if (item.analysisResult == null) {
      return {
        'success': false,
        'error': 'No analysis data available for summary regeneration',
      };
    }

    try {
      final analysisResult = item.analysisResult!;
      final rawData = analysisResult['rawData'] ?? {};
      final scrapedContent = rawData['scrapedContent'] ?? {};

      // Prepare data sources from existing scraped content
      List<Map<String, dynamic>> dataSources = [];

      if (scrapedContent['rawContent'] != null) {
        final rawContent = List<Map<String, dynamic>>.from(scrapedContent['rawContent']);

        for (var content in rawContent) {
          if (content['success'] == true && content['extractedData'] != null) {
            final extractedData = content['extractedData'];

            List<String> textParts = [];

            if (extractedData['title'] != null) {
              textParts.add('Title: ${extractedData['title']}');
            }

            if (extractedData['description'] != null) {
              textParts.add('Description: ${extractedData['description']}');
            }

            if (extractedData['specifications'] != null) {
              final specs = List<String>.from(extractedData['specifications']);
              if (specs.isNotEmpty) {
                textParts.add('Specifications: ${specs.join('; ')}');
              }
            }

            if (extractedData['features'] != null) {
              final features = List<String>.from(extractedData['features']);
              if (features.isNotEmpty) {
                textParts.add('Features: ${features.join('; ')}');
              }
            }

            dataSources.add({
              'url': content['url'],
              'title': extractedData['title'] ?? 'Scraped Content',
              'fullText': textParts.join('\n\n'),
              'confidence': extractedData['confidence'] ?? 0.5,
              'dataType': extractedData['dataType'] ?? 'web_scrape',
              'scrapedAt': content['scrapedAt'],
            });
          }
        }
      }

      // Add additional guidance to search keywords
      String searchKeywords = item.searchDescription;
      if (additionalGuidance?.isNotEmpty == true) {
        searchKeywords = '$searchKeywords $additionalGuidance';
      }

      // Generate new summary
      final newSummary = await SummaryGenerationService.generateItemSummary(
        dataSources: dataSources,
        userDescription: item.userDescription,
        searchKeywords: searchKeywords,
      );

      // Update analysis result with new summary
      final updatedAnalysisResult = Map<String, dynamic>.from(analysisResult);
      updatedAnalysisResult['summary'] = newSummary;
      updatedAnalysisResult['summaryRegeneratedAt'] = DateTime.now().toIso8601String();
      if (additionalGuidance?.isNotEmpty == true) {
        updatedAnalysisResult['summaryGuidance'] = additionalGuidance;
      }

      // Update item
      final updatedItem = item.copyWith(analysisResult: updatedAnalysisResult);
      await StorageService.saveJob(updatedItem);

      return {
        'success': true,
        'summary': newSummary,
        'regeneratedAt': DateTime.now().toIso8601String(),
      };

    } catch (e) {
      return {
        'success': false,
        'error': 'Summary regeneration failed: $e',
      };
    }
  }

  /// Validate analysis results for completeness
  static Map<String, dynamic> validateAnalysisResults(ItemJob item) {
    final issues = <String>[];
    final suggestions = <String>[];

    if (item.analysisResult == null) {
      return {
        'valid': false,
        'issues': ['No analysis results available'],
        'suggestions': ['Run complete analysis on this item'],
      };
    }

    final result = item.analysisResult!;

    // Check product identification
    final productInfo = result['productInfo'] ?? {};
    if (productInfo['manufacturer']?.toString().isEmpty != false) {
      issues.add('Manufacturer not identified');
      suggestions.add('Review OCR results or add manufacturer to item description');
    }

    if (productInfo['productName']?.toString().isEmpty != false) {
      issues.add('Product name not identified');
      suggestions.add('Add more descriptive product name in item description');
    }

    // Check search results
    final searchSummary = result['searchSummary'] ?? {};
    if (searchSummary['success'] != true) {
      issues.add('No search results found');
      suggestions.add('Try different search terms or verify product information');
    } else if ((searchSummary['resultsFound'] ?? 0) < 3) {
      issues.add('Limited search results');
      suggestions.add('Consider adding more specific model numbers or part numbers');
    }

    // Check content scraping
    final contentSummary = result['contentSummary'] ?? {};
    if (contentSummary['success'] != true) {
      issues.add('No content scraped from search results');
      suggestions.add('Search results may not contain scrapable content');
    }

    // Check summary quality
    final summary = result['summary'] ?? {};
    if (summary['success'] != true) {
      issues.add('Summary generation failed');
      suggestions.add('Try regenerating summary or add more detailed descriptions');
    } else if ((summary['confidence'] ?? 0.0) < 0.5) {
      issues.add('Low confidence summary');
      suggestions.add('Review and edit generated summary for accuracy');
    }

    // Check pricing
    final pricing = result['pricing'] ?? {};
    if (pricing['success'] != true) {
      issues.add('No pricing information found');
      suggestions.add('Pricing data may not be available for this product type');
    }

    return {
      'valid': issues.isEmpty,
      'issues': issues,
      'suggestions': suggestions,
      'overallConfidence': result['overallConfidence'] ?? 0.0,
      'analysisComplete': issues.length < 3, // Allow some minor issues
    };
  }
}