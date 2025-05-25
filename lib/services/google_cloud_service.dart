import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:googleapis/vision/v1.dart' as vision;
import 'package:googleapis/customsearch/v1.dart' as search;
import 'package:googleapis_auth/auth_io.dart';
import '../models/item_job.dart';

class GoogleCloudService {
  static String? _apiKey;
  static String? _searchEngineId;
  static AuthClient? _authClient;

  static Future<void> initialize() async {
    // In production, store these securely
    _apiKey = 'YOUR_GOOGLE_CLOUD_API_KEY';
    _searchEngineId = 'YOUR_CUSTOM_SEARCH_ENGINE_ID';
    
    // For Vision API authentication (service account)
    final serviceAccountJson = {
      // Your service account JSON key
    };
    
    final accountCredentials = ServiceAccountCredentials.fromJson(serviceAccountJson);
    _authClient = await clientViaServiceAccount(
      accountCredentials,
      [vision.VisionApi.cloudPlatformScope],
    );
  }

  // OCR using Google Cloud Vision API
  static Future<List<String>> extractTextFromImage(String imagePath) async {
    try {
      final visionApi = vision.VisionApi(_authClient!);
      
      // Read image file
      final imageBytes = await File(imagePath).readAsBytes();
      final base64Image = base64Encode(imageBytes);
      
      // Create Vision API request
      final request = vision.BatchAnnotateImagesRequest(
        requests: [
          vision.AnnotateImageRequest(
            image: vision.Image(content: base64Image),
            features: [
              vision.Feature(type: 'TEXT_DETECTION', maxResults: 10),
            ],
          ),
        ],
      );
      
      final response = await visionApi.images.annotate(request);
      
      List<String> extractedTexts = [];
      if (response.responses != null && response.responses!.isNotEmpty) {
        final textAnnotations = response.responses!.first.textAnnotations;
        if (textAnnotations != null) {
          for (final annotation in textAnnotations) {
            if (annotation.description != null) {
              extractedTexts.add(annotation.description!);
            }
          }
        }
      }
      
      return extractedTexts;
    } catch (e) {
      print('Error extracting text: $e');
      return [];
    }
  }

  // Barcode detection using ML Kit
  static Future<List<String>> extractBarcodesFromImage(String imagePath) async {
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final barcodeScanner = BarcodeScanner();
      
      final barcodes = await barcodeScanner.processImage(inputImage);
      
      List<String> barcodeValues = [];
      for (final barcode in barcodes) {
        if (barcode.displayValue != null) {
          barcodeValues.add(barcode.displayValue!);
        }
      }
      
      await barcodeScanner.close();
      return barcodeValues;
    } catch (e) {
      print('Error extracting barcodes: $e');
      return [];
    }
  }

  // Reverse image search using Google Custom Search
  static Future<List<WebSearchResult>> reverseImageSearch(String imagePath) async {
    try {
      // Upload image to temporary hosting (you'd need a service for this)
      // For POC, we'll use web search with extracted text instead
      final extractedText = await extractTextFromImage(imagePath);
      if (extractedText.isEmpty) return [];
      
      return await webSearch(extractedText.first);
    } catch (e) {
      print('Error in reverse image search: $e');
      return [];
    }
  }

  // Web search using Google Custom Search API
  static Future<List<WebSearchResult>> webSearch(String query) async {
    try {
      final url = Uri.parse(
        'https://www.googleapis.com/customsearch/v1'
        '?key=$_apiKey'
        '&cx=$_searchEngineId'
        '&q=${Uri.encodeComponent(query)}'
        '&num=10'
      );
      
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final items = data['items'] as List<dynamic>? ?? [];
        
        return items.map((item) => WebSearchResult(
          title: item['title'] ?? '',
          url: item['link'] ?? '',
          snippet: item['snippet'] ?? '',
          imageUrl: item['pagemap']?['cse_image']?[0]?['src'],
          relevanceScore: 0.8, // Would calculate based on relevance metrics
        )).toList();
      }
      
      return [];
    } catch (e) {
      print('Error in web search: $e');
      return [];
    }
  }

  // Product information extraction from search results
  static Future<List<ProductInfo>> extractProductInfo(List<WebSearchResult> searchResults) async {
    List<ProductInfo> products = [];
    
    for (final result in searchResults) {
      try {
        // Simple heuristic parsing - in production would use more sophisticated extraction
        String name = result.title;
        String? brand = _extractBrand(result.title + ' ' + result.snippet);
        String? model = _extractModel(result.title + ' ' + result.snippet);
        double? price = _extractPrice(result.snippet);
        
        products.add(ProductInfo(
          name: name,
          brand: brand,
          model: model,
          description: result.snippet,
          price: price,
          source: result.url,
          matchConfidence: result.relevanceScore,
        ));
      } catch (e) {
        print('Error extracting product info: $e');
      }
    }
    
    return products;
  }

  // Helper methods for extraction
  static String? _extractBrand(String text) {
    final brands = ['Apple', 'Samsung', 'Sony', 'Nintendo', 'Microsoft', 'Dell', 'HP'];
    for (final brand in brands) {
      if (text.toLowerCase().contains(brand.toLowerCase())) {
        return brand;
      }
    }
    return null;
  }

  static String? _extractModel(String text) {
    // Simple regex to find model numbers
    final modelRegex = RegExp(r'\b[A-Z0-9-]{3,}\b');
    final match = modelRegex.firstMatch(text);
    return match?.group(0);
  }

  static double? _extractPrice(String text) {
    final priceRegex = RegExp(r'\$(\d+(?:\.\d{2})?)');
    final match = priceRegex.firstMatch(text);
    if (match != null) {
      return double.tryParse(match.group(1)!);
    }
    return null;
  }

  // UPC lookup using external API
  static Future<ProductInfo?> lookupUPC(String upc) async {
    try {
      // Using UPCitemdb.com API (free tier available)
      final url = Uri.parse('https://api.upcitemdb.com/prod/trial/lookup?upc=$upc');
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final items = data['items'] as List<dynamic>? ?? [];
        
        if (items.isNotEmpty) {
          final item = items.first;
          return ProductInfo(
            name: item['title'] ?? '',
            brand: item['brand'] ?? '',
            model: item['model'] ?? '',
            description: item['description'] ?? '',
            price: null, // UPC database typically doesn't have pricing
            source: 'UPC Database',
            matchConfidence: 0.9,
          );
        }
      }
      
      return null;
    } catch (e) {
      print('Error looking up UPC: $e');
      return null;
    }
  }
}
