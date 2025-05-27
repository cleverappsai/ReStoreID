// ========================================
// lib/services/content_scraping_service.dart
// ========================================
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class ContentScrapingService {

  /// Scrape content from multiple URLs in priority order
  static Future<Map<String, dynamic>> scrapeTargetedContent({
    required List<Map<String, dynamic>> searchResults,
    required String manufacturer,
    required String productName,
  }) async {

    List<Map<String, dynamic>> scrapedContent = [];
    Map<String, int> contentTypes = {};

    // Sort results by priority (confidence and type)
    final prioritizedResults = _prioritizeResults(searchResults);

    // Scrape up to 8 high-value URLs
    for (var result in prioritizedResults.take(8)) {
      try {
        final content = await _scrapeUrl(result['url'], result['searchType']);

        if (content['success'] == true && content['extractedData'] != null) {
          content['originalResult'] = result;
          scrapedContent.add(content);

          // Track content types
          final type = result['searchType'] ?? 'unknown';
          contentTypes[type] = (contentTypes[type] ?? 0) + 1;
        }

        // Small delay between scrapes
        await Future.delayed(Duration(milliseconds: 800));

      } catch (e) {
        print('Scraping failed for ${result['url']}: $e');
      }
    }

    // Process and structure the scraped content
    final processedContent = _processScrapedContent(scrapedContent, manufacturer, productName);

    return {
      'success': scrapedContent.isNotEmpty,
      'manufacturer': manufacturer,
      'productName': productName,
      'contentScraped': scrapedContent.length,
      'contentTypes': contentTypes,
      'processedData': processedContent,
      'rawContent': scrapedContent,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  /// Prioritize results for scraping
  static List<Map<String, dynamic>> _prioritizeResults(List<Map<String, dynamic>> results) {
    // Define priority order for content types
    final typePriority = {
      'datasheet': 1,
      'manufacturer_site': 2,
      'manual': 3,
      'specifications': 4,
      'part_datasheet': 5,
      'pricing': 6,
      'retail_pricing': 7,
      'resale_pricing': 8,
    };

    results.sort((a, b) {
      final aType = a['searchType'] ?? 'unknown';
      final bType = b['searchType'] ?? 'unknown';
      final aPriority = typePriority[aType] ?? 99;
      final bPriority = typePriority[bType] ?? 99;

      // First sort by type priority
      if (aPriority != bPriority) {
        return aPriority.compareTo(bPriority);
      }

      // Then by confidence
      return (b['confidence'] ?? 0.0).compareTo(a['confidence'] ?? 0.0);
    });

    return results;
  }

  /// Scrape content from a single URL
  static Future<Map<String, dynamic>> _scrapeUrl(String url, String contentType) async {
    try {
      // Check if it's a PDF
      if (url.toLowerCase().endsWith('.pdf') || url.contains('filetype:pdf')) {
        return await _scrapePDF(url, contentType);
      }

      // Regular web page scraping
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
          'Accept-Language': 'en-US,en;q=0.5',
          'Accept-Encoding': 'gzip, deflate',
          'Connection': 'keep-alive',
        },
      );

      if (response.statusCode == 200) {
        final extractedData = _extractStructuredData(response.body, contentType, url);

        return {
          'success': true,
          'url': url,
          'contentType': contentType,
          'scrapedAt': DateTime.now().toIso8601String(),
          'extractedData': extractedData,
          'rawContentLength': response.body.length,
        };
      } else {
        return {
          'success': false,
          'url': url,
          'error': 'HTTP ${response.statusCode}',
        };
      }

    } catch (e) {
      return {
        'success': false,
        'url': url,
        'error': e.toString(),
      };
    }
  }

  /// Scrape PDF content (simplified - would need actual PDF parsing library)
  static Future<Map<String, dynamic>> _scrapePDF(String url, String contentType) async {
    try {
      // For now, return PDF metadata and suggest manual processing
      // In a full implementation, you'd use a PDF parsing library
      return {
        'success': true,
        'url': url,
        'contentType': contentType,
        'scrapedAt': DateTime.now().toIso8601String(),
        'extractedData': {
          'dataType': 'pdf_document',
          'title': 'PDF Document - $contentType',
          'description': 'PDF document found at $url. Manual processing recommended for detailed specifications.',
          'specifications': ['PDF document - requires manual review'],
          'needsManualReview': true,
        },
        'isPDF': true,
      };
    } catch (e) {
      return {
        'success': false,
        'url': url,
        'error': 'PDF processing error: $e',
      };
    }
  }

  /// Extract structured data from HTML content
  static Map<String, dynamic> _extractStructuredData(String html, String contentType, String url) {
    final cleanText = _cleanHtmlText(html);

    switch (contentType) {
      case 'datasheet':
      case 'specifications':
        return _extractSpecificationData(cleanText, url);
      case 'manual':
        return _extractManualData(cleanText, url);
      case 'manufacturer_site':
        return _extractManufacturerData(cleanText, url);
      case 'pricing':
      case 'retail_pricing':
      case 'resale_pricing':
        return _extractPricingData(cleanText, url);
      default:
        return _extractGeneralData(cleanText, url);
    }
  }

  /// Clean HTML and extract readable text
  static String _cleanHtmlText(String html) {
    // Remove script and style tags
    html = html.replaceAll(RegExp(r'<script[^>]*>.*?</script>', caseSensitive: false, dotAll: true), '');
    html = html.replaceAll(RegExp(r'<style[^>]*>.*?</style>', caseSensitive: false, dotAll: true), '');

    // Remove HTML tags but keep the content
    html = html.replaceAll(RegExp(r'<[^>]+>'), ' ');

    // Clean up whitespace
    html = html.replaceAll(RegExp(r'\s+'), ' ');
    html = html.replaceAll(RegExp(r'\n\s*\n'), '\n');

    // Decode HTML entities
    html = html.replaceAll('&nbsp;', ' ');
    html = html.replaceAll('&amp;', '&');
    html = html.replaceAll('&lt;', '<');
    html = html.replaceAll('&gt;', '>');
    html = html.replaceAll('&quot;', '"');
    html = html.replaceAll('&#39;', "'");

    return html.trim();
  }

  /// Extract specification data
  static Map<String, dynamic> _extractSpecificationData(String text, String url) {
    List<String> specifications = [];
    List<String> features = [];
    String description = '';

    // Look for specification patterns
    final specPatterns = [
      RegExp(r'(?:Dimensions?|Size):?\s*([^\n.]+)', caseSensitive: false),
      RegExp(r'(?:Weight):?\s*([^\n.]+)', caseSensitive: false),
      RegExp(r'(?:Power|Voltage|Current):?\s*([^\n.]+)', caseSensitive: false),
      RegExp(r'(?:Capacity|Storage|Memory):?\s*([^\n.]+)', caseSensitive: false),
      RegExp(r'(?:Speed|Rate|Frequency):?\s*([^\n.]+)', caseSensitive: false),
      RegExp(r'(?:Material|Construction):?\s*([^\n.]+)', caseSensitive: false),
      RegExp(r'(?:Operating|Temperature|Humidity):?\s*([^\n.]+)', caseSensitive: false),
    ];

    for (var pattern in specPatterns) {
      final matches = pattern.allMatches(text);
      for (var match in matches) {
        final spec = match.group(0)?.trim();
        if (spec != null && spec.length > 5 && spec.length < 200) {
          specifications.add(spec);
        }
      }
    }

    // Look for feature lists
    final featurePatterns = [
      RegExp(r'(?:Features?|Benefits?|Includes?):?\s*([^\n]+(?:\n[^\n]+)*)', caseSensitive: false),
      RegExp(r'•\s*([^\n•]+)', caseSensitive: false),
      RegExp(r'-\s*([^\n-]+)', caseSensitive: false),
    ];

    for (var pattern in featurePatterns) {
      final matches = pattern.allMatches(text);
      for (var match in matches) {
        final feature = match.group(1)?.trim();
        if (feature != null && feature.length > 5 && feature.length < 150) {
          features.add(feature);
        }
      }
    }

    // Extract a general description (first substantial paragraph)
    final paragraphs = text.split('\n').where((p) => p.trim().length > 50).toList();
    if (paragraphs.isNotEmpty) {
      description = paragraphs.first.trim();
      if (description.length > 500) {
        description = description.substring(0, 500) + '...';
      }
    }

    return {
      'dataType': 'specifications',
      'title': _extractTitle(text),
      'description': description,
      'specifications': specifications.take(15).toList(),
      'features': features.take(10).toList(),
      'sourceUrl': url,
      'confidence': _calculateContentConfidence(specifications, features, description),
    };
  }

  /// Extract manual/documentation data
  static Map<String, dynamic> _extractManualData(String text, String url) {
    List<String> instructions = [];
    List<String> safety = [];
    List<String> maintenance = [];
    String overview = '';

    // Look for instruction patterns
    final instructionPatterns = [
      RegExp(r'(?:Instructions?|How to|Setup|Installation):?\s*([^\n]+(?:\n[^\n]+)*)', caseSensitive: false),
      RegExp(r'(?:Step \d+|First|Then|Next|Finally):?\s*([^\n.]+)', caseSensitive: false),
    ];

    for (var pattern in instructionPatterns) {
      final matches = pattern.allMatches(text);
      for (var match in matches) {
        final instruction = match.group(1)?.trim();
        if (instruction != null && instruction.length > 10 && instruction.length < 200) {
          instructions.add(instruction);
        }
      }
    }

    // Look for safety information
    final safetyPatterns = [
      RegExp(r'(?:Warning|Caution|Safety|Danger):?\s*([^\n.]+)', caseSensitive: false),
      RegExp(r'(?:Do not|Never|Always|Ensure):?\s*([^\n.]+)', caseSensitive: false),
    ];

    for (var pattern in safetyPatterns) {
      final matches = pattern.allMatches(text);
      for (var match in matches) {
        final safetyNote = match.group(0)?.trim();
        if (safetyNote != null && safetyNote.length > 10 && safetyNote.length < 150) {
          safety.add(safetyNote);
        }
      }
    }

    // Look for maintenance information
    final maintenancePatterns = [
      RegExp(r'(?:Maintenance|Care|Cleaning|Storage):?\s*([^\n]+)', caseSensitive: false),
      RegExp(r'(?:Replace|Clean|Check|Inspect):?\s*([^\n.]+)', caseSensitive: false),
    ];

    for (var pattern in maintenancePatterns) {
      final matches = pattern.allMatches(text);
      for (var match in matches) {
        final maintenanceItem = match.group(0)?.trim();
        if (maintenanceItem != null && maintenanceItem.length > 10 && maintenanceItem.length < 150) {
          maintenance.add(maintenanceItem);
        }
      }
    }

    // Extract overview
    final paragraphs = text.split('\n').where((p) => p.trim().length > 100).toList();
    if (paragraphs.isNotEmpty) {
      overview = paragraphs.first.trim();
      if (overview.length > 400) {
        overview = overview.substring(0, 400) + '...';
      }
    }

    return {
      'dataType': 'manual',
      'title': _extractTitle(text),
      'overview': overview,
      'instructions': instructions.take(10).toList(),
      'safety': safety.take(8).toList(),
      'maintenance': maintenance.take(5).toList(),
      'sourceUrl': url,
      'confidence': _calculateContentConfidence(instructions, safety, overview),
    };
  }

  /// Extract manufacturer website data
  static Map<String, dynamic> _extractManufacturerData(String text, String url) {
    List<String> features = [];
    List<String> specifications = [];
    String productDescription = '';
    List<String> applications = [];

    // Look for official product descriptions
    final descPatterns = [
      RegExp(r'(?:Product Description|Overview|About):?\s*([^\n]+(?:\n[^\n]+)*)', caseSensitive: false),
      RegExp(r'(?:The .+ is|This .+ features|Our .+ provides):?\s*([^\n.]+)', caseSensitive: false),
    ];

    for (var pattern in descPatterns) {
      final match = pattern.firstMatch(text);
      if (match != null && match.group(1) != null) {
        productDescription = match.group(1)!.trim();
        if (productDescription.length > 400) {
          productDescription = productDescription.substring(0, 400) + '...';
        }
        break;
      }
    }

    // Extract key features
    final featurePatterns = [
      RegExp(r'(?:Key Features?|Highlights?):?\s*([^\n]+(?:\n[^\n]+)*)', caseSensitive: false),
      RegExp(r'•\s*([^\n•]+)', caseSensitive: false),
      RegExp(r'✓\s*([^\n✓]+)', caseSensitive: false),
    ];

    for (var pattern in featurePatterns) {
      final matches = pattern.allMatches(text);
      for (var match in matches) {
        final feature = match.group(1)?.trim();
        if (feature != null && feature.length > 10 && feature.length < 150) {
          features.add(feature);
        }
      }
    }

    // Extract applications/uses
    final appPatterns = [
      RegExp(r'(?:Applications?|Uses?|Ideal for):?\s*([^\n]+)', caseSensitive: false),
      RegExp(r'(?:Perfect for|Great for|Designed for):?\s*([^\n.]+)', caseSensitive: false),
    ];

    for (var pattern in appPatterns) {
      final matches = pattern.allMatches(text);
      for (var match in matches) {
        final application = match.group(1)?.trim();
        if (application != null && application.length > 5 && application.length < 100) {
          applications.add(application);
        }
      }
    }

    return {
      'dataType': 'manufacturer_info',
      'title': _extractTitle(text),
      'productDescription': productDescription,
      'features': features.take(12).toList(),
      'applications': applications.take(6).toList(),
      'sourceUrl': url,
      'confidence': _calculateContentConfidence(features, applications, productDescription),
    };
  }

  /// Extract pricing data
  static Map<String, dynamic> _extractPricingData(String text, String url) {
    List<String> prices = [];
    List<String> conditions = [];
    String availability = '';

    // Look for price patterns
    final pricePatterns = [
      RegExp(r'\$\s*(\d{1,3}(?:,\d{3})*(?:\.\d{2})?)', caseSensitive: false),
      RegExp(r'(\d{1,3}(?:,\d{3})*(?:\.\d{2})?)\s*dollars?', caseSensitive: false),
      RegExp(r'Price:?\s*\$?(\d{1,3}(?:,\d{3})*(?:\.\d{2})?)', caseSensitive: false),
      RegExp(r'(\d{1,3}(?:,\d{3})*(?:\.\d{2})?)\s*USD', caseSensitive: false),
    ];

    Set<String> foundPrices = {};
    for (var pattern in pricePatterns) {
      final matches = pattern.allMatches(text);
      for (var match in matches) {
        final priceMatch = match.group(0)?.trim();
        if (priceMatch != null) {
          foundPrices.add(priceMatch);
        }
      }
    }
    prices = foundPrices.toList();

    // Look for condition information
    final conditionPatterns = [
      RegExp(r'(?:Condition|State):?\s*([^\n.]+)', caseSensitive: false),
      RegExp(r'\b(New|Used|Refurbished|Open Box|Like New|Very Good|Good|Acceptable|For Parts)\b', caseSensitive: false),
    ];

    Set<String> foundConditions = {};
    for (var pattern in conditionPatterns) {
      final matches = pattern.allMatches(text);
      for (var match in matches) {
        final condition = match.group(1)?.trim() ?? match.group(0)?.trim();
        if (condition != null && condition.length < 50) {
          foundConditions.add(condition);
        }
      }
    }
    conditions = foundConditions.toList();

    // Look for availability
    final availabilityPatterns = [
      RegExp(r'(?:In Stock|Out of Stock|Available|Unavailable|Ships in|Delivery)', caseSensitive: false),
      RegExp(r'(?:Available|Stock):?\s*([^\n.]+)', caseSensitive: false),
    ];

    for (var pattern in availabilityPatterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        availability = match.group(0)?.trim() ?? '';
        break;
      }
    }

    return {
      'dataType': 'pricing',
      'title': _extractTitle(text),
      'prices': prices.take(10).toList(),
      'conditions': conditions.take(5).toList(),
      'availability': availability,
      'sourceUrl': url,
      'confidence': _calculateContentConfidence(prices, conditions, availability),
    };
  }

  /// Extract general data
  static Map<String, dynamic> _extractGeneralData(String text, String url) {
    final title = _extractTitle(text);
    final description = _extractDescription(text);
    final keyPoints = _extractKeyPoints(text);

    return {
      'dataType': 'general',
      'title': title,
      'description': description,
      'keyPoints': keyPoints,
      'sourceUrl': url,
      'confidence': _calculateContentConfidence(keyPoints, [], description),
    };
  }

  /// Extract title from text
  static String _extractTitle(String text) {
    final lines = text.split('\n');

    // Look for title-like patterns
    for (String line in lines.take(10)) {
      line = line.trim();
      if (line.length > 10 && line.length < 150 &&
          !line.contains('©') && !line.contains('Privacy') &&
          !line.toLowerCase().contains('cookie')) {
        return line;
      }
    }

    // Fallback to first substantial line
    for (String line in lines.take(20)) {
      line = line.trim();
      if (line.length > 20 && line.length < 100) {
        return line;
      }
    }

    return 'Product Information';
  }

  /// Extract description from text
  static String _extractDescription(String text) {
    final paragraphs = text.split('\n')
        .where((p) => p.trim().length > 50)
        .toList();

    if (paragraphs.isNotEmpty) {
      String description = paragraphs.first.trim();
      if (description.length > 300) {
        description = description.substring(0, 300) + '...';
      }
      return description;
    }

    return '';
  }

  /// Extract key points from text
  static List<String> _extractKeyPoints(String text) {
    List<String> points = [];

    // Look for bullet points and lists
    final patterns = [
      RegExp(r'•\s*([^\n•]+)', caseSensitive: false),
      RegExp(r'-\s*([^\n-]+)', caseSensitive: false),
      RegExp(r'\d+\.\s*([^\n\d]+)', caseSensitive: false),
      RegExp(r'✓\s*([^\n✓]+)', caseSensitive: false),
    ];

    for (var pattern in patterns) {
      final matches = pattern.allMatches(text);
      for (var match in matches) {
        final point = match.group(1)?.trim();
        if (point != null && point.length > 10 && point.length < 150) {
          points.add(point);
        }
      }
    }

    return points.take(10).toList();
  }

  /// Calculate confidence score for extracted content
  static double _calculateContentConfidence(List<String> primary, List<String> secondary, String description) {
    double confidence = 0.2; // Base confidence

    if (primary.isNotEmpty) confidence += 0.3;
    if (secondary.isNotEmpty) confidence += 0.2;
    if (description.isNotEmpty && description.length > 50) confidence += 0.3;

    // Boost confidence based on content richness
    if (primary.length >= 5) confidence += 0.1;
    if (secondary.length >= 3) confidence += 0.1;

    return confidence.clamp(0.0, 1.0);
  }

  /// Process all scraped content into a unified structure
  static Map<String, dynamic> _processScrapedContent(
      List<Map<String, dynamic>> scrapedContent,
      String manufacturer,
      String productName,
      ) {

    Map<String, List<String>> consolidatedSpecs = {};
    Map<String, List<String>> consolidatedFeatures = {};
    List<String> descriptions = [];
    List<Map<String, dynamic>> pricingData = [];
    List<String> applications = [];
    List<String> safety = [];

    for (var content in scrapedContent) {
      final data = content['extractedData'];
      if (data == null) continue;

      final dataType = data['dataType'] ?? 'unknown';

      // Consolidate specifications
      if (data['specifications'] != null) {
        consolidatedSpecs[dataType] = List<String>.from(data['specifications']);
      }

      // Consolidate features
      if (data['features'] != null) {
        consolidatedFeatures[dataType] = List<String>.from(data['features']);
      }

      // Collect descriptions
      if (data['description'] != null && data['description'].toString().isNotEmpty) {
        descriptions.add('${data['description']} (Source: ${dataType})');
      }
      if (data['productDescription'] != null && data['productDescription'].toString().isNotEmpty) {
        descriptions.add('${data['productDescription']} (Source: ${dataType})');
      }

      // Collect pricing data
      if (dataType == 'pricing' && data['prices'] != null) {
        pricingData.add({
          'prices': data['prices'],
          'conditions': data['conditions'] ?? [],
          'availability': data['availability'] ?? '',
          'sourceUrl': data['sourceUrl'],
        });
      }

      // Collect applications
      if (data['applications'] != null) {
        applications.addAll(List<String>.from(data['applications']));
      }

      // Collect safety information
      if (data['safety'] != null) {
        safety.addAll(List<String>.from(data['safety']));
      }
    }

    return {
      'manufacturer': manufacturer,
      'productName': productName,
      'specifications': consolidatedSpecs,
      'features': consolidatedFeatures,
      'descriptions': descriptions,
      'pricingData': pricingData,
      'applications': applications.toSet().toList(),
      'safety': safety.toSet().toList(),
      'contentSources': scrapedContent.length,
      'overallConfidence': _calculateOverallConfidence(scrapedContent),
      'processedAt': DateTime.now().toIso8601String(),
    };
  }

  /// Calculate overall confidence from all scraped content
  static double _calculateOverallConfidence(List<Map<String, dynamic>> scrapedContent) {
    if (scrapedContent.isEmpty) return 0.0;

    double totalConfidence = 0.0;
    int validContent = 0;

    for (var content in scrapedContent) {
      final data = content['extractedData'];
      if (data != null && data['confidence'] != null) {
        totalConfidence += data['confidence'];
        validContent++;
      }
    }

    if (validContent == 0) return 0.2;

    double averageConfidence = totalConfidence / validContent;

    // Boost confidence based on number of sources
    if (validContent >= 5) averageConfidence += 0.1;
    if (validContent >= 3) averageConfidence += 0.05;

    return averageConfidence.clamp(0.0, 1.0);
  }
}