// ========================================
// lib/services/summary_generation_service.dart
// ========================================
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_config_service.dart';

class SummaryGenerationService {

  // Generate AI summary from multiple data sources
  static Future<Map<String, dynamic>> generateItemSummary({
    required List<Map<String, dynamic>> dataSources,
    required String userDescription,
    required String searchKeywords,
  }) async {

    // Combine all source texts
    List<String> sourceTexts = [];
    List<Map<String, dynamic>> preservedSources = [];

    for (var source in dataSources) {
      if (source['fullText'] != null && source['fullText'].toString().isNotEmpty) {
        sourceTexts.add(source['fullText']);

        // Preserve source metadata
        preservedSources.add({
          'url': source['url'],
          'title': source['title'],
          'scrapedAt': source['scrapedAt'],
          'sourceText': source['fullText'],
          'confidence': source['confidence'] ?? 0.5,
          'dataType': source['dataType'] ?? 'web_scrape',
        });
      }
    }

    if (sourceTexts.isEmpty) {
      return _createFallbackSummary(userDescription, searchKeywords, preservedSources);
    }

    // Try AI generation first
    final aiSummary = await _generateAISummary(sourceTexts, userDescription, searchKeywords);
    if (aiSummary != null) {
      return {
        'success': true,
        'itemTitle': aiSummary['title'],
        'description': aiSummary['description'],
        'specifications': aiSummary['specifications'],
        'keyFeatures': aiSummary['keyFeatures'],
        'generatedAt': DateTime.now().toIso8601String(),
        'confidence': aiSummary['confidence'],
        'sourcesUsed': preservedSources,
        'sourceTextBlob': sourceTexts.join('\n\n--- SOURCE BREAK ---\n\n'),
        'generationMethod': 'ai',
      };
    }

    // Fallback to rule-based summary
    return _createRuleBasedSummary(sourceTexts, userDescription, searchKeywords, preservedSources);
  }

  // Generate pricing summary with source preservation
  static Map<String, dynamic> generatePricingSummary(List<Map<String, dynamic>> priceSources) {
    List<Map<String, dynamic>> prices = [];
    List<Map<String, dynamic>> preservedPriceSources = [];

    for (var source in priceSources) {
      if (source['prices'] != null) {
        for (var priceText in source['prices']) {
          final extractedPrice = _extractPrice(priceText);
          if (extractedPrice != null) {
            prices.add({
              'price': extractedPrice,
              'priceText': priceText,
              'source': source['title'] ?? 'Unknown Source',
              'url': source['url'],
              'condition': _inferCondition(priceText),
              'scrapedAt': source['scrapedAt'],
            });
          }
        }

        preservedPriceSources.add({
          'url': source['url'],
          'title': source['title'],
          'allPrices': source['prices'],
          'scrapedAt': source['scrapedAt'],
        });
      }
    }

    if (prices.isEmpty) {
      return {
        'success': false,
        'estimatedValue': null,
        'priceRange': null,
        'confidence': 0.0,
        'priceSources': preservedPriceSources,
      };
    }

    // Calculate price statistics
    final priceValues = prices.map((p) => p['price'] as double).toList()..sort();
    final low = priceValues.first;
    final high = priceValues.last;
    final median = priceValues[priceValues.length ~/ 2];
    final average = priceValues.reduce((a, b) => a + b) / priceValues.length;

    return {
      'success': true,
      'estimatedValue': median,
      'averageValue': average,
      'priceRange': {'low': low, 'high': high},
      'priceCount': prices.length,
      'confidence': _calculatePriceConfidence(prices.length),
      'priceBreakdown': prices,
      'priceSources': preservedPriceSources,
      'generatedAt': DateTime.now().toIso8601String(),
    };
  }

  static Future<Map<String, dynamic>?> _generateAISummary(
      List<String> sourceTexts,
      String userDescription,
      String searchKeywords
      ) async {
    final apiKey = await ApiConfigService.getOpenAiApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      return null;
    }

    final combinedText = sourceTexts.join('\n\n--- SOURCE BREAK ---\n\n');

    try {
      final response = await http.post(
        Uri.parse('https://api.openai.com/v1/chat/completions'),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': 'gpt-4',
          'messages': [
            {
              'role': 'system',
              'content': '''You are an expert product listing writer for a resale store. Create professional, accurate item descriptions from source material.

Generate a JSON response with:
{
  "title": "Clear, specific product name",
  "description": "3-4 paragraph description for resale listing",
  "specifications": ["bulleted", "technical", "specs"],
  "keyFeatures": ["main", "selling", "points"],
  "confidence": 0.0-1.0
}

Focus on condition, functionality, compatibility, and value. Be honest about any limitations.'''
            },
            {
              'role': 'user',
              'content': '''Create a professional resale listing from this information:

User Description: $userDescription
Search Keywords: $searchKeywords

Source Material:
$combinedText

Generate a complete listing with accurate details from the source material.'''
            }
          ],
          'temperature': 0.3,
          'max_tokens': 1500,
        }),
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        final content = result['choices']?[0]?['message']?['content'];
        if (content != null) {
          try {
            return jsonDecode(content);
          } catch (e) {
            print('AI response parsing error: $e');
            return null;
          }
        }
      }
    } catch (e) {
      print('AI summary generation error: $e');
    }

    return null;
  }

  static Map<String, dynamic> _createRuleBasedSummary(
      List<String> sourceTexts,
      String userDescription,
      String searchKeywords,
      List<Map<String, dynamic>> sources
      ) {
    final combinedText = sourceTexts.join(' ');

    // Extract key information using pattern matching
    final brands = _extractBrands(combinedText);
    final models = _extractModels(combinedText);
    final features = _extractFeatures(combinedText);
    final specs = _extractSpecifications(combinedText);

    // Generate title
    String title = userDescription;
    if (brands.isNotEmpty && models.isNotEmpty) {
      title = '${brands.first} ${models.first}';
    } else if (brands.isNotEmpty) {
      title = '${brands.first} $userDescription';
    }

    // Generate description
    String description = '''${title}

This ${userDescription.toLowerCase()} is being offered from our resale inventory. ''';

    if (features.isNotEmpty) {
      description += 'Key features include: ${features.take(3).join(', ')}. ';
    }

    description += '''

Item details have been researched from multiple sources to ensure accuracy. Please review the specifications below for complete technical information.

All items are sold as-is. Please ask questions before purchasing.''';

    return {
      'success': true,
      'itemTitle': title,
      'description': description,
      'specifications': specs.take(10).toList(),
      'keyFeatures': features.take(5).toList(),
      'generatedAt': DateTime.now().toIso8601String(),
      'confidence': 0.6,
      'sourcesUsed': sources,
      'sourceTextBlob': sourceTexts.join('\n\n--- SOURCE BREAK ---\n\n'),
      'generationMethod': 'rule_based',
    };
  }

  static Map<String, dynamic> _createFallbackSummary(
      String userDescription,
      String searchKeywords,
      List<Map<String, dynamic>> sources
      ) {
    return {
      'success': false,
      'itemTitle': userDescription,
      'description': 'Item identification in progress. Additional research needed to generate complete description.',
      'specifications': [],
      'keyFeatures': [],
      'generatedAt': DateTime.now().toIso8601String(),
      'confidence': 0.2,
      'sourcesUsed': sources,
      'sourceTextBlob': '',
      'generationMethod': 'fallback',
      'requiresMoreData': true,
    };
  }

  // Helper methods for text extraction
  static List<String> _extractBrands(String text) {
    final brandPatterns = [
      RegExp(r'\b(Apple|Samsung|Sony|LG|Dell|HP|Canon|Nikon|DeWalt|Makita)\b', caseSensitive: false),
      RegExp(r'\b[A-Z][a-z]+(?:\s+[A-Z][a-z]+)?\b'), // General brand patterns
    ];

    Set<String> brands = {};
    for (var pattern in brandPatterns) {
      brands.addAll(pattern.allMatches(text).map((m) => m.group(0)!));
    }

    return brands.take(3).toList();
  }

  static List<String> _extractModels(String text) {
    final modelPatterns = [
      RegExp(r'\b[A-Z]{2,4}[-]?[0-9]{3,6}[A-Z]?\b'),
      RegExp(r'\bModel:?\s*([A-Z0-9-]+)\b', caseSensitive: false),
    ];

    Set<String> models = {};
    for (var pattern in modelPatterns) {
      models.addAll(pattern.allMatches(text).map((m) => m.group(0)!));
    }

    return models.take(3).toList();
  }

  static List<String> _extractFeatures(String text) {
    final featurePatterns = [
      RegExp(r'(?:features?|includes?):?\s*([^.!?]+)', caseSensitive: false),
      RegExp(r'(?:•|-)?\s*([A-Z][^.!?]+(?:technology|control|system|display))', caseSensitive: false),
    ];

    Set<String> features = {};
    for (var pattern in featurePatterns) {
      features.addAll(pattern.allMatches(text).map((m) => m.group(1)?.trim() ?? '').where((f) => f.isNotEmpty));
    }

    return features.take(8).toList();
  }

  static List<String> _extractSpecifications(String text) {
    final specPatterns = [
      RegExp(r'(?:dimensions?|size):?\s*([^.!?]+)', caseSensitive: false),
      RegExp(r'(?:weight):?\s*([^.!?]+)', caseSensitive: false),
      RegExp(r'(?:power|voltage):?\s*([^.!?]+)', caseSensitive: false),
      RegExp(r'(?:capacity|storage):?\s*([^.!?]+)', caseSensitive: false),
    ];

    Set<String> specs = {};
    for (var pattern in specPatterns) {
      specs.addAll(pattern.allMatches(text).map((m) => m.group(0)?.trim() ?? '').where((s) => s.isNotEmpty));
    }

    return specs.take(10).toList();
  }

  static double? _extractPrice(String priceText) {
    final pricePattern = RegExp(r'\$?([\d,]+\.?\d*)');
    final match = pricePattern.firstMatch(priceText);
    if (match != null) {
      final priceString = match.group(1)?.replaceAll(',', '');
      return double.tryParse(priceString ?? '');
    }
    return null;
  }

  static String _inferCondition(String priceText) {
    final lowerText = priceText.toLowerCase();
    if (lowerText.contains('new') || lowerText.contains('mint')) return 'New';
    if (lowerText.contains('used') || lowerText.contains('pre-owned')) return 'Used';
    if (lowerText.contains('refurb')) return 'Refurbished';
    if (lowerText.contains('parts') || lowerText.contains('repair')) return 'For Parts';
    return 'Unknown';
  }

  static double _calculatePriceConfidence(int priceCount) {
    if (priceCount >= 5) return 0.9;
    if (priceCount >= 3) return 0.7;
    if (priceCount >= 2) return 0.5;
    return 0.3;
  }
}