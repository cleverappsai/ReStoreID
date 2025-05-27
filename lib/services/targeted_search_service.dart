// ========================================
// lib/services/targeted_search_service.dart
// ========================================
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../services/api_config_service.dart';

class TargetedSearchService {

  /// Extract structured product information from OCR results
  static Map<String, dynamic> extractProductIdentifiers(Map<String, String> ocrResults) {
    List<String> allText = ocrResults.values.toList();
    String combinedText = allText.join(' ');

    return {
      'manufacturer': _extractManufacturer(combinedText),
      'productName': _extractProductName(combinedText),
      'modelNumber': _extractModelNumber(combinedText),
      'partNumber': _extractPartNumber(combinedText),
      'serialNumber': _extractSerialNumber(combinedText),
      'upc': _extractUPC(combinedText),
      'searchTerms': _generateSearchTerms(combinedText),
      'confidence': _calculateExtractionConfidence(combinedText),
    };
  }

  /// Perform targeted searches for product documentation
  static Future<Map<String, dynamic>> performTargetedSearch({
    required String manufacturer,
    required String productName,
    String? modelNumber,
    String? partNumber,
  }) async {

    List<Map<String, dynamic>> searchResults = [];

    // Generate search queries with priority order
    List<Map<String, String>> searchQueries = _generateTargetedQueries(
      manufacturer: manufacturer,
      productName: productName,
      modelNumber: modelNumber,
      partNumber: partNumber,
    );

    // Perform searches in priority order
    for (var query in searchQueries.take(5)) { // Limit to top 5 searches
      try {
        final results = await _performGoogleSearch(query['query']!, query['type']!);
        if (results.isNotEmpty) {
          searchResults.addAll(results);
        }

        // Small delay between searches to be respectful
        await Future.delayed(Duration(milliseconds: 500));
      } catch (e) {
        print('Search failed for ${query['query']}: $e');
      }
    }

    // Filter and rank results
    final filteredResults = _filterAndRankResults(searchResults, manufacturer, productName);

    return {
      'success': filteredResults.isNotEmpty,
      'manufacturer': manufacturer,
      'productName': productName,
      'modelNumber': modelNumber,
      'searchResults': filteredResults,
      'searchCount': searchQueries.length,
      'resultsFound': filteredResults.length,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  /// Extract manufacturer from text using multiple strategies
  static String _extractManufacturer(String text) {
    // Common manufacturer patterns and known brands
    final knownBrands = [
      'Apple', 'Samsung', 'Sony', 'LG', 'Panasonic', 'Canon', 'Nikon', 'Olympus',
      'DeWalt', 'Makita', 'Bosch', 'Craftsman', 'Black+Decker', 'Ryobi', 'Milwaukee',
      'KitchenAid', 'Cuisinart', 'Hamilton Beach', 'Oster', 'Ninja', 'Vitamix',
      'Dell', 'HP', 'Lenovo', 'ASUS', 'Acer', 'Microsoft', 'Intel', 'AMD', 'Nvidia',
      'Whirlpool', 'GE', 'Frigidaire', 'Kenmore', 'Maytag', 'Electrolux',
      'Ford', 'GM', 'Toyota', 'Honda', 'BMW', 'Mercedes', 'Audi',
      'Honeywell', '3M', 'Philips', 'Siemens', 'Schneider', 'ABB',
    ];

    final upperText = text.toUpperCase();

    // Look for known brands first (highest confidence)
    for (String brand in knownBrands) {
      if (upperText.contains(brand.toUpperCase())) {
        return brand;
      }
    }

    // Pattern-based extraction for unknown brands
    final patterns = [
      RegExp(r'(?:Made by|Manufactured by|Brand:?)\s*([A-Z][A-Za-z]+)', caseSensitive: false),
      RegExp(r'©\s*([A-Z][A-Za-z]+)', caseSensitive: false),
      RegExp(r'\b([A-Z][A-Za-z]+)\s*(?:Corp|Inc|LLC|Ltd|Co)', caseSensitive: false),
      RegExp(r'^([A-Z][A-Za-z]+)\s+[A-Z0-9-]+', multiLine: true), // Brand followed by model
    ];

    for (var pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null && match.group(1) != null) {
        return match.group(1)!;
      }
    }

    return '';
  }

  /// Extract product name from text
  static String _extractProductName(String text) {
    final patterns = [
      RegExp(r'(?:Product|Model|Name):?\s*([^.\n]+)', caseSensitive: false),
      RegExp(r'\b([A-Z][A-Za-z\s]+(?:Phone|Camera|Drill|Mixer|Computer|Monitor|Speaker))\b', caseSensitive: false),
      RegExp(r'\b([A-Z][A-Za-z\s]+ (?:Pro|Plus|Max|Ultra|Mini|Lite))\b', caseSensitive: false),
    ];

    for (var pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null && match.group(1) != null) {
        return match.group(1)!.trim();
      }
    }

    // If no specific product found, try to extract meaningful text
    final lines = text.split('\n');
    for (String line in lines) {
      line = line.trim();
      if (line.length > 5 && line.length < 50 &&
          RegExp(r'^[A-Za-z0-9\s-]+$').hasMatch(line) &&
          !RegExp(r'^\d+$').hasMatch(line)) {
        return line;
      }
    }

    return '';
  }

  /// Extract model number from text
  static String _extractModelNumber(String text) {
    final patterns = [
      RegExp(r'(?:Model|Mod|M):?\s*([A-Z0-9-]{3,15})', caseSensitive: false),
      RegExp(r'\b([A-Z]{1,3}[-]?[0-9]{3,8}[A-Z]?)\b'),
      RegExp(r'\b([0-9]{1,3}[A-Z]{1,3}[0-9]{2,6})\b'),
      RegExp(r'#\s*([A-Z0-9-]{4,12})', caseSensitive: false),
    ];

    for (var pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null && match.group(1) != null) {
        return match.group(1)!;
      }
    }

    return '';
  }

  /// Extract part number from text
  static String _extractPartNumber(String text) {
    final patterns = [
      RegExp(r'(?:Part|P/N|PN):?\s*([A-Z0-9-]{4,20})', caseSensitive: false),
      RegExp(r'Part\s*#\s*([A-Z0-9-]+)', caseSensitive: false),
    ];

    for (var pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null && match.group(1) != null) {
        return match.group(1)!;
      }
    }

    return '';
  }

  /// Extract serial number from text
  static String _extractSerialNumber(String text) {
    final patterns = [
      RegExp(r'(?:Serial|S/N|SN):?\s*([A-Z0-9]{6,20})', caseSensitive: false),
      RegExp(r'Serial\s*#\s*([A-Z0-9]+)', caseSensitive: false),
    ];

    for (var pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null && match.group(1) != null) {
        return match.group(1)!;
      }
    }

    return '';
  }

  /// Extract UPC/Barcode from text
  static String _extractUPC(String text) {
    final patterns = [
      RegExp(r'\b(\d{12,14})\b'), // UPC/EAN codes
      RegExp(r'UPC:?\s*(\d{8,14})', caseSensitive: false),
    ];

    for (var pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null && match.group(1) != null) {
        return match.group(1)!;
      }
    }

    return '';
  }

  /// Generate targeted search terms
  static List<String> _generateSearchTerms(String text) {
    Set<String> terms = {};

    // Extract meaningful words (not common words)
    final commonWords = {'the', 'and', 'or', 'but', 'in', 'on', 'at', 'to', 'for', 'of', 'with', 'by', 'is', 'are', 'was', 'were'};
    final words = text.split(RegExp(r'\s+'));

    for (String word in words) {
      word = word.replaceAll(RegExp(r'[^\w]'), '').toLowerCase();
      if (word.length > 2 && !commonWords.contains(word) && word.contains(RegExp(r'[a-zA-Z]'))) {
        terms.add(word);
      }
    }

    return terms.take(10).toList();
  }

  /// Calculate confidence score for extraction
  static double _calculateExtractionConfidence(String text) {
    double confidence = 0.0;

    // Boost confidence based on what we found
    if (text.contains(RegExp(r'(?:Model|Product|Brand)', caseSensitive: false))) confidence += 0.3;
    if (text.contains(RegExp(r'\b[A-Z]{2,}\s*[-]?\s*[0-9]{3,}\b'))) confidence += 0.3;
    if (text.contains(RegExp(r'(?:Made|Manufactured|©)', caseSensitive: false))) confidence += 0.2;
    if (text.length > 50) confidence += 0.2;

    return confidence.clamp(0.0, 1.0);
  }

  /// Generate targeted search queries in priority order
  static List<Map<String, String>> _generateTargetedQueries({
    required String manufacturer,
    required String productName,
    String? modelNumber,
    String? partNumber,
  }) {
    List<Map<String, String>> queries = [];

    // High priority: Official documentation
    if (manufacturer.isNotEmpty && modelNumber?.isNotEmpty == true) {
      queries.add({
        'query': '"$manufacturer" "$modelNumber" datasheet filetype:pdf',
        'type': 'datasheet',
        'priority': '1',
      });

      queries.add({
        'query': '"$manufacturer" "$modelNumber" manual filetype:pdf',
        'type': 'manual',
        'priority': '1',
      });

      queries.add({
        'query': 'site:${_getManufacturerSite(manufacturer)} "$modelNumber"',
        'type': 'manufacturer_site',
        'priority': '1',
      });
    }

    // Medium priority: Product information
    if (manufacturer.isNotEmpty && productName.isNotEmpty) {
      queries.add({
        'query': '"$manufacturer" "$productName" specifications',
        'type': 'specifications',
        'priority': '2',
      });

      queries.add({
        'query': '"$manufacturer" "$productName" price',
        'type': 'pricing',
        'priority': '2',
      });
    }

    // Part number searches
    if (partNumber?.isNotEmpty == true) {
      queries.add({
        'query': '"$partNumber" datasheet specifications',
        'type': 'part_datasheet',
        'priority': '2',
      });
    }

    // Retail/pricing searches
    if (manufacturer.isNotEmpty && (modelNumber?.isNotEmpty == true || productName.isNotEmpty)) {
      String searchTerm = modelNumber?.isNotEmpty == true ? modelNumber! : productName;

      queries.add({
        'query': 'site:amazon.com "$manufacturer" "$searchTerm"',
        'type': 'retail_pricing',
        'priority': '3',
      });

      queries.add({
        'query': 'site:ebay.com "$manufacturer" "$searchTerm"',
        'type': 'resale_pricing',
        'priority': '3',
      });
    }

    // Sort by priority
    queries.sort((a, b) => a['priority']!.compareTo(b['priority']!));

    return queries;
  }

  /// Get manufacturer website domain
  static String _getManufacturerSite(String manufacturer) {
    final siteMap = {
      'Apple': 'apple.com',
      'Samsung': 'samsung.com',
      'Sony': 'sony.com',
      'LG': 'lg.com',
      'DeWalt': 'dewalt.com',
      'Makita': 'makitausa.com',
      'Bosch': 'boschtools.com',
      'Canon': 'canon.com',
      'Nikon': 'nikon.com',
      'Dell': 'dell.com',
      'HP': 'hp.com',
      'Lenovo': 'lenovo.com',
    };

    return siteMap[manufacturer] ?? '${manufacturer.toLowerCase()}.com';
  }

  /// Perform Google search using Custom Search API
  static Future<List<Map<String, dynamic>>> _performGoogleSearch(String query, String searchType) async {
    final apiKey = await ApiConfigService.getGoogleApiKey();
    final searchEngineId = await ApiConfigService.getGoogleSearchEngineId();

    if (apiKey == null || searchEngineId == null) {
      print('Google Search API not configured');
      return [];
    }

    try {
      final uri = Uri.parse('https://www.googleapis.com/customsearch/v1').replace(
        queryParameters: {
          'key': apiKey,
          'cx': searchEngineId,
          'q': query,
          'num': '5', // Limit results per search
        },
      );

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final items = data['items'] ?? [];

        List<Map<String, dynamic>> results = [];

        for (var item in items) {
          results.add({
            'title': item['title'] ?? '',
            'url': item['link'] ?? '',
            'snippet': item['snippet'] ?? '',
            'searchType': searchType,
            'confidence': _calculateResultConfidence(item, searchType),
            'foundAt': DateTime.now().toIso8601String(),
          });
        }

        return results;
      }
    } catch (e) {
      print('Google search error: $e');
    }

    return [];
  }

  /// Calculate confidence score for search result
  static double _calculateResultConfidence(Map<String, dynamic> item, String searchType) {
    double confidence = 0.5; // Base confidence

    final title = (item['title'] ?? '').toLowerCase();
    final url = (item['link'] ?? '').toLowerCase();

    // Boost confidence for official sources
    if (url.contains('.com') && !url.contains('amazon') && !url.contains('ebay')) {
      confidence += 0.2;
    }

    // Boost confidence for PDF documents
    if (url.contains('.pdf') || title.contains('pdf')) {
      confidence += 0.3;
    }

    // Type-specific confidence boosts
    switch (searchType) {
      case 'datasheet':
        if (title.contains('datasheet') || title.contains('specification')) confidence += 0.3;
        break;
      case 'manual':
        if (title.contains('manual') || title.contains('guide')) confidence += 0.3;
        break;
      case 'manufacturer_site':
        confidence += 0.4; // High confidence for manufacturer sites
        break;
      case 'pricing':
        if (title.contains('price') || title.contains('\$')) confidence += 0.2;
        break;
    }

    return confidence.clamp(0.0, 1.0);
  }

  /// Filter and rank search results
  static List<Map<String, dynamic>> _filterAndRankResults(
      List<Map<String, dynamic>> results,
      String manufacturer,
      String productName,
      ) {

    // Filter out low-quality results
    final filtered = results.where((result) {
      final title = (result['title'] ?? '').toLowerCase();
      final url = (result['url'] ?? '').toLowerCase();

      // Skip generic shopping sites unless they're for pricing
      if ((url.contains('shopping') || url.contains('compare')) &&
          result['searchType'] != 'pricing') {
        return false;
      }

      // Skip results that don't contain manufacturer or product info
      if (!title.contains(manufacturer.toLowerCase()) &&
          !title.contains(productName.toLowerCase())) {
        return false;
      }

      return true;
    }).toList();

    // Sort by confidence score
    filtered.sort((a, b) => (b['confidence'] ?? 0.0).compareTo(a['confidence'] ?? 0.0));

    // Return top results
    return filtered.take(15).toList();
  }
}