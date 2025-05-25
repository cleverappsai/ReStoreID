// ========================================
// lib/services/cloud_services.dart
// ========================================
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:google_ml_kit/google_ml_kit.dart';
import 'api_config_service.dart';

class CloudServices {
  // Test API Key validity
  static Future<Map<String, dynamic>> testApiKey(String apiKey) async {
    try {
      // Make a simple Vision API call to test the key
      final response = await http.post(
        Uri.parse('https://vision.googleapis.com/v1/images:annotate?key=$apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'requests': [
            {
              'image': {
                'content': 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==' // 1x1 transparent PNG
              },
              'features': [
                {'type': 'LABEL_DETECTION', 'maxResults': 1}
              ],
            },
          ],
        }),
      );

      if (response.statusCode == 200) {
        return {
          'valid': true,
          'message': 'API key is valid and Vision API is accessible.',
        };
      } else if (response.statusCode == 403) {
        return {
          'valid': false,
          'message': 'API key is invalid or Vision API is not enabled.',
        };
      } else {
        return {
          'valid': false,
          'message': 'API key test failed: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'valid': false,
        'message': 'Network error: $e',
      };
    }
  }

  // Search packaging images for OCR and product info
  static Future<Map<String, dynamic>> searchPackaging(List<String> imagePaths) async {
    if (imagePaths.isEmpty) {
      return {'confidence': 0.0, 'text': 'No packaging images provided'};
    }

    try {
      // Perform OCR on packaging images
      final textRecognizer = TextRecognizer();
      List<String> extractedTexts = [];

      for (String imagePath in imagePaths) {
        final inputImage = InputImage.fromFilePath(imagePath);
        final recognizedText = await textRecognizer.processImage(inputImage);
        if (recognizedText.text.isNotEmpty) {
          extractedTexts.add(recognizedText.text);
        }
      }

      await textRecognizer.close();

      final combinedText = extractedTexts.join(' ');

      // Extract potential product identifiers
      final products = _extractProductInfo(combinedText);

      return {
        'confidence': extractedTexts.isNotEmpty ? 0.8 : 0.2,
        'text': combinedText,
        'products': products,
        'barcodes': _extractBarcodes(combinedText),
        'modelNumbers': _extractModelNumbers(combinedText),
      };
    } catch (e) {
      return {
        'confidence': 0.0,
        'text': 'Error processing packaging: $e',
        'products': [],
      };
    }
  }

  // Search markings images for brand and identification
  static Future<Map<String, dynamic>> searchMarkings(List<String> imagePaths) async {
    if (imagePaths.isEmpty) {
      return {'confidence': 0.0, 'text': 'No marking images provided'};
    }

    try {
      final textRecognizer = TextRecognizer();
      List<String> extractedTexts = [];

      for (String imagePath in imagePaths) {
        final inputImage = InputImage.fromFilePath(imagePath);
        final recognizedText = await textRecognizer.processImage(inputImage);
        if (recognizedText.text.isNotEmpty) {
          extractedTexts.add(recognizedText.text);
        }
      }

      await textRecognizer.close();

      final combinedText = extractedTexts.join(' ');

      // Extract brands and markings
      final brands = _extractBrands(combinedText);
      final markings = _extractMarkings(combinedText);

      return {
        'confidence': extractedTexts.isNotEmpty ? 0.7 : 0.2,
        'text': combinedText,
        'brands': brands,
        'markings': markings,
        'products': _searchByBrands(brands),
      };
    } catch (e) {
      return {
        'confidence': 0.0,
        'text': 'Error processing markings: $e',
        'brands': [],
      };
    }
  }

  // Reverse image search for product identification
  static Future<Map<String, dynamic>> reverseImageSearch(List<String> imagePaths) async {
    if (imagePaths.isEmpty) {
      return {'confidence': 0.0, 'products': []};
    }

    try {
      final apiKey = await ApiConfigService.getGoogleApiKey();
      if (apiKey == null) {
        return {'confidence': 0.0, 'products': ['API key not configured']};
      }

      List<String> foundProducts = [];

      for (String imagePath in imagePaths) {
        final result = await _performReverseImageSearch(imagePath, apiKey);
        if (result.isNotEmpty) {
          foundProducts.addAll(result);
        }
      }

      return {
        'confidence': foundProducts.isNotEmpty ? 0.6 : 0.2,
        'products': foundProducts.take(5).toList(),
        'method': 'Reverse image search',
      };
    } catch (e) {
      return {
        'confidence': 0.0,
        'products': ['Error in reverse search: $e'],
      };
    }
  }

  static Future<List<String>> _performReverseImageSearch(String imagePath, String apiKey) async {
    try {
      final file = File(imagePath);
      final bytes = await file.readAsBytes();
      final base64Image = base64Encode(bytes);

      final response = await http.post(
        Uri.parse('https://vision.googleapis.com/v1/images:annotate?key=$apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'requests': [
            {
              'image': {'content': base64Image},
              'features': [
                {'type': 'WEB_DETECTION', 'maxResults': 10},
                {'type': 'LABEL_DETECTION', 'maxResults': 10},
              ],
            },
          ],
        }),
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        final webDetection = result['responses']?[0]?['webDetection'];
        final labels = result['responses']?[0]?['labelAnnotations'] ?? [];

        List<String> products = [];

        // Extract from web detection
        if (webDetection != null) {
          final webEntities = webDetection['webEntities'] ?? [];
          for (var entity in webEntities) {
            if (entity['description'] != null && entity['score'] > 0.3) { // Lowered threshold for candidates
              products.add(entity['description']);
            }
          }
        }

        // Extract from labels
        for (var label in labels) {
          if (label['score'] > 0.5) { // Lowered threshold for candidates
            products.add(label['description']);
          }
        }

        return products;
      }
    } catch (e) {
      print('Reverse image search error: $e');
    }

    return [];
  }

  // Enhanced reverse image search that returns candidate matches with URLs
  static Future<Map<String, dynamic>> reverseImageSearchWithCandidates(List<String> imagePaths) async {
    if (imagePaths.isEmpty) {
      return {'confidence': 0.0, 'products': [], 'candidates': []};
    }

    try {
      final apiKey = await ApiConfigService.getGoogleApiKey();
      if (apiKey == null) {
        return {'confidence': 0.0, 'products': ['API key not configured'], 'candidates': []};
      }

      List<Map<String, dynamic>> candidates = [];
      List<String> foundProducts = [];

      for (String imagePath in imagePaths) {
        final result = await _performReverseImageSearchWithDetails(imagePath, apiKey);
        if (result['products'].isNotEmpty) {
          foundProducts.addAll(List<String>.from(result['products']));
        }
        if (result['candidates'].isNotEmpty) {
          candidates.addAll(List<Map<String, dynamic>>.from(result['candidates']));
        }
      }

      return {
        'confidence': foundProducts.isNotEmpty ? 0.6 : 0.2,
        'products': foundProducts.take(5).toList(),
        'candidates': candidates.take(10).toList(),
        'method': 'Enhanced reverse image search',
      };
    } catch (e) {
      return {
        'confidence': 0.0,
        'products': ['Error in reverse search: $e'],
        'candidates': [],
      };
    }
  }

  static Future<Map<String, dynamic>> _performReverseImageSearchWithDetails(String imagePath, String apiKey) async {
    try {
      final file = File(imagePath);
      final bytes = await file.readAsBytes();
      final base64Image = base64Encode(bytes);

      final response = await http.post(
        Uri.parse('https://vision.googleapis.com/v1/images:annotate?key=$apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'requests': [
            {
              'image': {'content': base64Image},
              'features': [
                {'type': 'WEB_DETECTION', 'maxResults': 15},
                {'type': 'LABEL_DETECTION', 'maxResults': 10},
              ],
            },
          ],
        }),
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        final webDetection = result['responses']?[0]?['webDetection'];

        List<String> products = [];
        List<Map<String, dynamic>> candidates = [];

        if (webDetection != null) {
          // High confidence matches
          final webEntities = webDetection['webEntities'] ?? [];
          for (var entity in webEntities) {
            if (entity['description'] != null) {
              if (entity['score'] > 0.7) {
                products.add(entity['description']);
              } else if (entity['score'] > 0.3) {
                candidates.add({
                  'title': entity['description'],
                  'confidence': entity['score'],
                  'type': 'entity',
                });
              }
            }
          }

          // Add web pages with partial matches
          final pagesWithMatchingImages = webDetection['pagesWithMatchingImages'] ?? [];
          for (var page in pagesWithMatchingImages.take(5)) {
            if (page['url'] != null && page['pageTitle'] != null) {
              candidates.add({
                'title': page['pageTitle'],
                'url': page['url'],
                'confidence': 0.5, // Medium confidence for page matches
                'type': 'page',
              });
            }
          }

          // Add visually similar images
          final visuallySimilarImages = webDetection['visuallySimilarImages'] ?? [];
          for (var image in visuallySimilarImages.take(3)) {
            if (image['url'] != null) {
              candidates.add({
                'title': 'Similar Product Image',
                'url': image['url'],
                'imageUrl': image['url'],
                'confidence': 0.4,
                'type': 'similar_image',
              });
            }
          }
        }

        return {
          'products': products,
          'candidates': candidates,
        };
      }
    } catch (e) {
      print('Detailed reverse image search error: $e');
    }

    return {'products': [], 'candidates': []};
  }

  // Helper methods for text extraction
  static List<String> _extractProductInfo(String text) {
    List<String> products = [];

    // Look for common product patterns
    final patterns = [
      RegExp(r'\b[A-Z][a-z]+ [A-Z0-9-]+\b'), // Brand Model
      RegExp(r'\b[A-Z]{2,}\s*-?\s*[0-9]{3,}\b'), // Model numbers
    ];

    for (var pattern in patterns) {
      final matches = pattern.allMatches(text);
      for (var match in matches) {
        products.add(match.group(0)!);
      }
    }

    return products.toSet().toList(); // Remove duplicates
  }

  static List<String> _extractBarcodes(String text) {
    final barcodePattern = RegExp(r'\b\d{8,14}\b');
    return barcodePattern.allMatches(text)
        .map((m) => m.group(0)!)
        .toSet()
        .toList();
  }

  static List<String> _extractModelNumbers(String text) {
    final modelPattern = RegExp(r'\b[A-Z]{1,3}[-]?[0-9]{3,6}[A-Z]?\b');
    return modelPattern.allMatches(text)
        .map((m) => m.group(0)!)
        .toSet()
        .toList();
  }

  static List<String> _extractBrands(String text) {
    // Common brand patterns - this would be expanded with a comprehensive brand database
    final commonBrands = [
      'Apple', 'Samsung', 'Sony', 'LG', 'Panasonic', 'Canon', 'Nikon',
      'DeWalt', 'Makita', 'Bosch', 'Craftsman', 'Black+Decker',
      'KitchenAid', 'Cuisinart', 'Hamilton Beach', 'Oster',
      'Dell', 'HP', 'Lenovo', 'ASUS', 'Acer', 'Microsoft', 'Intel',
      'AMD', 'NVIDIA', 'Motorola', 'Nokia', 'Huawei', 'Xiaomi',
      'OnePlus', 'Google', 'Amazon', 'Facebook', 'Tesla'
    ];

    List<String> foundBrands = [];
    final upperText = text.toUpperCase();

    for (String brand in commonBrands) {
      if (upperText.contains(brand.toUpperCase())) {
        foundBrands.add(brand);
      }
    }

    return foundBrands;
  }

  static List<String> _extractMarkings(String text) {
    List<String> markings = [];

    // Extract patent numbers, part numbers, etc.
    final patterns = [
      RegExp(r'\bPAT\s*[#]?\s*[0-9,]+\b', caseSensitive: false),
      RegExp(r'\bPART\s*[#]?\s*[A-Z0-9-]+\b', caseSensitive: false),
      RegExp(r'\bSERIAL\s*[#]?\s*[A-Z0-9-]+\b', caseSensitive: false),
      RegExp(r'\bMODEL\s*[#]?\s*[A-Z0-9-]+\b', caseSensitive: false),
      RegExp(r'\bP/N\s*[:]?\s*[A-Z0-9-]+\b', caseSensitive: false),
      RegExp(r'\bS/N\s*[:]?\s*[A-Z0-9-]+\b', caseSensitive: false),
    ];

    for (var pattern in patterns) {
      final matches = pattern.allMatches(text);
      for (var match in matches) {
        markings.add(match.group(0)!);
      }
    }

    return markings;
  }

  static List<String> _searchByBrands(List<String> brands) {
    // Placeholder for brand-based product search
    List<String> products = [];

    for (String brand in brands) {
      products.add('$brand Product Line');
      products.add('$brand Electronics');
      products.add('$brand Home Appliances');
    }

    return products;
  }

  // Enhanced image classification using user labels + AI verification
  static Future<Map<String, dynamic>> classifyImages(List<String> imagePaths, {Map<String, List<String>>? userClassification}) async {
    final apiKey = await ApiConfigService.getGoogleApiKey();
    if (apiKey == null) throw Exception('Google API key not configured');

    Map<String, List<String>> classification = {
      'sales': [],
      'id': [],
      'markings': [],
      'packaging': [],
      'barcode': [],
    };

    // If user has already classified images, use that as the base
    if (userClassification != null) {
      classification = Map.from(userClassification);

      // Verify user classifications with AI (optional enhancement)
      for (String category in classification.keys) {
        for (String imagePath in classification[category]!) {
          if (imagePaths.contains(imagePath)) {
            final result = await _classifySingleImage(imagePath, apiKey);
            final aiCategory = _determineImageCategory(result, userHint: category);

            // If AI strongly disagrees with user classification, flag it
            if (aiCategory != category && _getClassificationConfidence(result) > 0.8) {
              print('Note: AI suggests $imagePath might be better classified as $aiCategory instead of $category');
            }
          }
        }
      }
    } else {
      // Fallback: classify all images with AI
      for (String imagePath in imagePaths) {
        final result = await _classifySingleImage(imagePath, apiKey);
        final category = _determineImageCategory(result);
        classification[category]!.add(imagePath);
      }
    }

    return {
      'classification': classification,
      'confidence': 0.95, // Higher confidence when user has pre-labeled
    };
  }

  static Future<Map<String, dynamic>> _classifySingleImage(String imagePath, String apiKey) async {
    final file = File(imagePath);
    final bytes = await file.readAsBytes();
    final base64Image = base64Encode(bytes);

    final response = await http.post(
      Uri.parse('https://vision.googleapis.com/v1/images:annotate?key=$apiKey'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'requests': [
          {
            'image': {'content': base64Image},
            'features': [
              {'type': 'LABEL_DETECTION', 'maxResults': 10},
              {'type': 'TEXT_DETECTION'},
              {'type': 'OBJECT_LOCALIZATION', 'maxResults': 10},
            ],
          },
        ],
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to classify image: ${response.body}');
    }
  }

  static String _determineImageCategory(Map<String, dynamic> visionResult, {String? userHint}) {
    final labels = visionResult['responses']?[0]?['labelAnnotations'] ?? [];
    final textAnnotations = visionResult['responses']?[0]?['textAnnotations'] ?? [];

    // If user provided a hint, give it weight
    if (userHint != null) {
      return userHint; // Trust user classification for now
    }

    // Check for barcodes/UPC patterns in text
    for (var textAnnotation in textAnnotations) {
      final text = textAnnotation['description'].toString();
      if (_containsBarcodePattern(text)) {
        return 'barcode';
      }
    }

    // Analyze labels for categorization
    for (var label in labels) {
      final description = label['description'].toString().toLowerCase();
      final confidence = label['score'] ?? 0.0;

      if (confidence > 0.7) {
        if (description.contains('package') || description.contains('box') ||
            description.contains('container') || description.contains('manual')) {
          return 'packaging';
        }
        if (description.contains('text') || description.contains('label') ||
            description.contains('tag') || description.contains('sticker')) {
          return 'markings';
        }
        if (description.contains('serial') || description.contains('model') ||
            description.contains('number') || description.contains('specification')) {
          return 'id';
        }
      }
    }

    return 'sales'; // Default category
  }

  static double _getClassificationConfidence(Map<String, dynamic> visionResult) {
    final labels = visionResult['responses']?[0]?['labelAnnotations'] ?? [];
    if (labels.isEmpty) return 0.0;

    double maxConfidence = 0.0;
    for (var label in labels) {
      final confidence = label['score'] ?? 0.0;
      if (confidence > maxConfidence) {
        maxConfidence = confidence;
      }
    }
    return maxConfidence;
  }

  static bool _containsBarcodePattern(String text) {
    // Check for common barcode patterns
    final barcodePatterns = [
      RegExp(r'\d{12,14}'), // UPC/EAN patterns
      RegExp(r'\d{8}'), // Short barcodes
      RegExp(r'[A-Z0-9]{6,}'), // Alphanumeric codes
    ];

    for (var pattern in barcodePatterns) {
      if (pattern.hasMatch(text)) {
        return true;
      }
    }
    return false;
  }

  // OCR using Google ML Kit (on-device) + Google Vision API (cloud)
  static Future<Map<String, String>> performOCR(List<String> imagePaths) async {
    Map<String, String> ocrResults = {};

    // First try on-device OCR with Google ML Kit
    final textRecognizer = TextRecognizer();

    for (String imagePath in imagePaths) {
      try {
        final inputImage = InputImage.fromFilePath(imagePath);
        final recognizedText = await textRecognizer.processImage(inputImage);

        if (recognizedText.text.isNotEmpty) {
          ocrResults[imagePath] = recognizedText.text;
        } else {
          // Fallback to cloud OCR if on-device returns nothing
          final cloudText = await _performCloudOCR(imagePath);
          if (cloudText != null) {
            ocrResults[imagePath] = cloudText;
          }
        }
      } catch (e) {
        print('OCR failed for $imagePath: $e');
      }
    }

    await textRecognizer.close();
    return ocrResults;
  }

  static Future<String?> _performCloudOCR(String imagePath) async {
    final apiKey = await ApiConfigService.getGoogleApiKey();
    if (apiKey == null) return null;

    final file = File(imagePath);
    final bytes = await file.readAsBytes();
    final base64Image = base64Encode(bytes);

    final response = await http.post(
      Uri.parse('https://vision.googleapis.com/v1/images:annotate?key=$apiKey'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'requests': [
          {
            'image': {'content': base64Image},
            'features': [{'type': 'TEXT_DETECTION'}],
          },
        ],
      }),
    );

    if (response.statusCode == 200) {
      final result = jsonDecode(response.body);
      return result['responses']?[0]?['fullTextAnnotation']?['text'];
    }
    return null;
  }

  // Barcode and UPC detection
  static Future<Map<String, List<String>>> detectBarcodesAndUPCs(List<String> imagePaths) async {
    final barcodeScanner = BarcodeScanner();
    Map<String, List<String>> results = {
      'barcodes': [],
      'upcs': [],
    };

    for (String imagePath in imagePaths) {
      try {
        final inputImage = InputImage.fromFilePath(imagePath);
        final barcodes = await barcodeScanner.processImage(inputImage);

        for (Barcode barcode in barcodes) {
          if (barcode.rawValue != null) {
            if (barcode.type == BarcodeType.product) {
              results['upcs']!.add(barcode.rawValue!);
            } else {
              results['barcodes']!.add(barcode.rawValue!);
            }
          }
        }
      } catch (e) {
        print('Barcode detection failed for $imagePath: $e');
      }
    }

    await barcodeScanner.close();
    return results;
  }

  // Product search using extracted data
  static Future<Map<String, dynamic>> searchProduct({
    required Map<String, String> ocrResults,
    required List<String> barcodes,
    required List<String> upcs,
    required String userDescription,
  }) async {
    // Combine all text data for search
    String searchQuery = userDescription;

    // Add OCR text
    for (String text in ocrResults.values) {
      searchQuery += ' $text';
    }

    // Add barcodes/UPCs
    for (String code in [...barcodes, ...upcs]) {
      searchQuery += ' $code';
    }

    // Use Google Custom Search API or OpenAI for product identification
    final productInfo = await _searchWithOpenAI(searchQuery, barcodes, upcs);

    return productInfo;
  }

  static Future<Map<String, dynamic>> _searchWithOpenAI(String searchQuery, List<String> barcodes, List<String> upcs) async {
    final apiKey = await ApiConfigService.getOpenAiApiKey();
    if (apiKey == null) {
      // Fallback to basic product info
      return _generateFallbackProductInfo(searchQuery);
    }

    // Placeholder for OpenAI integration - would implement actual API call here
    return _generateFallbackProductInfo(searchQuery);
  }

  static Map<String, dynamic> _generateFallbackProductInfo(String searchQuery) {
    return {
      'product': {
        'name': 'Identified Item',
        'brand': 'Unknown',
        'category': 'General',
        'condition': 'Unknown',
        'description': 'Item identified from: ${searchQuery.length > 100 ? searchQuery.substring(0, 100) + '...' : searchQuery}',
      },
      'specifications': {},
      'confidence': 0.3,
      'identifiers': {},
    };
  }

  // Pricing analysis using multiple sources
  static Future<Map<String, dynamic>> analyzePricing({
    required Map<String, dynamic> productInfo,
    required List<String> barcodes,
    required List<String> upcs,
  }) async {
    // Get pricing from multiple sources
    final ebayPrices = await _getEbayPricing(productInfo);
    final amazonPrices = await _getAmazonPricing(productInfo);

    // Analyze and combine pricing data
    final allPrices = [...ebayPrices, ...amazonPrices];
    if (allPrices.isEmpty) {
      return _generateFallbackPricing();
    }

    final prices = allPrices.map((p) => p['price'] as double).toList();
    prices.sort();

    final low = prices.first;
    final high = prices.last;
    final median = prices[prices.length ~/ 2];

    return {
      'estimatedValue': median,
      'priceRange': {'low': low, 'high': high},
      'confidence': allPrices.length > 3 ? 0.8 : 0.5,
      'references': allPrices.take(5).toList(),
    };
  }

  static Future<List<Map<String, dynamic>>> _getEbayPricing(Map<String, dynamic> productInfo) async {
    // Placeholder for eBay API integration
    // Would use eBay Browse API to search for similar items
    return [
      {'source': 'eBay', 'price': 25.99, 'condition': 'Used', 'url': 'https://ebay.com/...'},
      {'source': 'eBay', 'price': 35.50, 'condition': 'New', 'url': 'https://ebay.com/...'},
    ];
  }

  static Future<List<Map<String, dynamic>>> _getAmazonPricing(Map<String, dynamic> productInfo) async {
    // Placeholder for Amazon API integration
    // Would use Amazon Product Advertising API
    return [
      {'source': 'Amazon', 'price': 42.99, 'condition': 'New', 'url': 'https://amazon.com/...'},
    ];
  }

  static Map<String, dynamic> _generateFallbackPricing() {
    return {
      'estimatedValue': 20.0,
      'priceRange': {'low': 15.0, 'high': 25.0},
      'confidence': 0.2,
      'references': [
        {'source': 'Estimated', 'price': 20.0, 'condition': 'Used', 'url': ''},
      ],
    };
  }
}