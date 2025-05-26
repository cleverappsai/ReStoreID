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

  // Reverse image search with candidate URLs
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
        final result = await _performReverseImageSearch(imagePath, apiKey);
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

  // Perform OCR using Google ML Kit
  static Future<Map<String, String>> performOCR(List<String> imagePaths) async {
    Map<String, String> ocrResults = {};

    final textRecognizer = TextRecognizer();

    for (String imagePath in imagePaths) {
      try {
        final inputImage = InputImage.fromFilePath(imagePath);
        final recognizedText = await textRecognizer.processImage(inputImage);

        if (recognizedText.text.isNotEmpty) {
          ocrResults[imagePath] = recognizedText.text;
        }
      } catch (e) {
        print('OCR failed for $imagePath: $e');
      }
    }

    await textRecognizer.close();
    return ocrResults;
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

  // Private helper methods
  static Future<Map<String, dynamic>> _performReverseImageSearch(String imagePath, String apiKey) async {
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
                'confidence': 0.5,
                'type': 'page',
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
      print('Reverse image search error: $e');
    }

    return {'products': [], 'candidates': []};
  }

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

    return products.toSet().toList();
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
    final commonBrands = [
      'Apple', 'Samsung', 'Sony', 'LG', 'Panasonic', 'Canon', 'Nikon',
      'DeWalt', 'Makita', 'Bosch', 'Craftsman', 'Black+Decker',
      'KitchenAid', 'Cuisinart', 'Hamilton Beach', 'Oster',
      'Dell', 'HP', 'Lenovo', 'ASUS', 'Acer', 'Microsoft',
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

    final patterns = [
      RegExp(r'\bPAT\s*[#]?\s*[0-9,]+\b', caseSensitive: false),
      RegExp(r'\bPART\s*[#]?\s*[A-Z0-9-]+\b', caseSensitive: false),
      RegExp(r'\bSERIAL\s*[#]?\s*[A-Z0-9-]+\b', caseSensitive: false),
      RegExp(r'\bMODEL\s*[#]?\s*[A-Z0-9-]+\b', caseSensitive: false),
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
    List<String> products = [];

    for (String brand in brands) {
      products.add('$brand Product Line');
      products.add('$brand Electronics');
    }

    return products;
  }
}