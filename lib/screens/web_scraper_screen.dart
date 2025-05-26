// ========================================
// lib/screens/web_scraper_screen.dart
// ========================================
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;

class WebScraperScreen extends StatefulWidget {
  final String url;
  final String title;
  final Function(Map<String, dynamic>) onDataScrapped;

  const WebScraperScreen({
    Key? key,
    required this.url,
    required this.title,
    required this.onDataScrapped,
  }) : super(key: key);

  @override
  _WebScraperScreenState createState() => _WebScraperScreenState();
}

class _WebScraperScreenState extends State<WebScraperScreen> {
  late WebViewController _controller;
  bool _isLoading = true;
  bool _isScraping = false;
  Map<String, dynamic> _scrapedData = {};
  String _scrapingStatus = 'Ready to scrape';

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            setState(() {
              _isLoading = false;
            });
            _performInitialScrape();
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  Future<void> _performInitialScrape() async {
    if (_isScraping) return;

    setState(() {
      _isScraping = true;
      _scrapingStatus = 'Scraping page content...';
    });

    try {
      // Method 1: Try to scrape via HTTP request
      final response = await http.get(Uri.parse(widget.url)).timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        final document = html_parser.parse(response.body);
        final scrapedData = _extractDataFromDocument(document);

        setState(() {
          _scrapedData = scrapedData;
          _isScraping = false;
          _scrapingStatus = 'Scraping completed';
        });
        return;
      }
    } catch (e) {
      print('HTTP scraping failed: $e');
    }

    // Method 2: Fallback to WebView JavaScript extraction
    try {
      final pageContent = await _controller.runJavaScriptReturningResult(
          'document.documentElement.outerHTML'
      );

      final htmlContent = pageContent.toString().replaceAll('"', '');
      final document = html_parser.parse(htmlContent);
      final scrapedData = _extractDataFromDocument(document);

      setState(() {
        _scrapedData = scrapedData;
        _isScraping = false;
        _scrapingStatus = 'Scraping completed';
      });
    } catch (e) {
      setState(() {
        _scrapedData = {
          'url': widget.url,
          'title': widget.title,
          'error': 'Failed to scrape: $e',
          'scrapedAt': DateTime.now().toIso8601String(),
        };
        _isScraping = false;
        _scrapingStatus = 'Scraping failed';
      });
    }
  }

  Map<String, dynamic> _extractDataFromDocument(dynamic document) {
    try {
      // Extract basic information
      final title = document.querySelector('title')?.text?.trim() ?? widget.title;
      final description = document.querySelector('meta[name="description"]')?.attributes['content']?.trim() ?? '';

      // Extract prices
      final prices = _extractPrices(document);

      // Extract specifications
      final specifications = _extractSpecifications(document);

      // Extract features
      final features = _extractFeatures(document);

      // Extract product info
      final productInfo = _extractProductInfo(document);

      // Extract brand information
      final brands = _extractBrands(document);

      return {
        'url': widget.url,
        'title': title,
        'description': description,
        'prices': prices,
        'specifications': specifications,
        'features': features,
        'brands': brands,
        'productInfo': productInfo,
        'fullText': _getCleanBodyText(document),
        'scrapedAt': DateTime.now().toIso8601String(),
        'dataType': 'web_scrape',
        'confidence': 0.7,
        'dataQuality': _assessDataQuality(prices, specifications, features),
      };
    } catch (e) {
      return {
        'url': widget.url,
        'title': widget.title,
        'error': 'Extraction failed: $e',
        'scrapedAt': DateTime.now().toIso8601String(),
      };
    }
  }

  List<String> _extractPrices(dynamic document) {
    List<String> prices = [];

    // Look for price elements
    final priceSelectors = [
      '[class*="price"]',
      '[id*="price"]',
      '[data-price]',
      '.price-current',
      '.price-now',
      '.sale-price',
      '.regular-price',
    ];

    for (String selector in priceSelectors) {
      try {
        final elements = document.querySelectorAll(selector);
        for (var element in elements) {
          final priceText = element.text?.trim() ?? '';
          if (priceText.isNotEmpty && _containsPricePattern(priceText)) {
            prices.add(priceText);
          }
        }
      } catch (e) {
        // Skip invalid selectors
      }
    }

    return prices.toSet().take(10).toList(); // Remove duplicates and limit
  }

  List<String> _extractSpecifications(dynamic document) {
    List<String> specifications = [];

    final specSelectors = [
      '[class*="spec"]',
      '[class*="detail"]',
      '[class*="feature"]',
      '.specifications',
      '.product-details',
      '.tech-specs',
    ];

    for (String selector in specSelectors) {
      try {
        final elements = document.querySelectorAll(selector);
        for (var element in elements) {
          final specText = element.text?.trim() ?? '';
          if (specText.isNotEmpty && specText.length < 200 && specText.length > 5) {
            specifications.add(specText);
          }
        }
      } catch (e) {
        // Skip invalid selectors
      }
    }

    return specifications.toSet().take(20).toList();
  }

  List<String> _extractFeatures(dynamic document) {
    List<String> features = [];

    final featureSelectors = [
      '[class*="feature"]',
      '[class*="highlight"]',
      '.key-features',
      '.product-features',
      '.highlights',
    ];

    for (String selector in featureSelectors) {
      try {
        final elements = document.querySelectorAll(selector);
        for (var element in elements) {
          final featureText = element.text?.trim() ?? '';
          if (featureText.isNotEmpty && featureText.length < 150 && featureText.length > 3) {
            features.add(featureText);
          }
        }
      } catch (e) {
        // Skip invalid selectors
      }
    }

    return features.toSet().take(15).toList();
  }

  Map<String, String> _extractProductInfo(dynamic document) {
    Map<String, String> productInfo = {};

    try {
      // Look for structured data
      final jsonLdElements = document.querySelectorAll('script[type="application/ld+json"]');
      for (var element in jsonLdElements) {
        try {
          final jsonContent = element.text;
          // Would parse JSON-LD here for structured product data
          // For now, just note that structured data exists
          productInfo['hasStructuredData'] = 'true';
        } catch (e) {
          // Skip invalid JSON
        }
      }

      // Look for product name
      final nameSelectors = ['h1', '.product-name', '.product-title', '[class*="title"]'];
      for (String selector in nameSelectors) {
        try {
          final element = document.querySelector(selector);
          if (element != null && element.text?.trim().isNotEmpty == true) {
            productInfo['productName'] = element.text.trim();
            break;
          }
        } catch (e) {
          // Skip
        }
      }

      // Look for brand
      final brandSelectors = ['[class*="brand"]', '[data-brand]', '[itemprop="brand"]'];
      for (String selector in brandSelectors) {
        try {
          final element = document.querySelector(selector);
          if (element != null && element.text?.trim().isNotEmpty == true) {
            productInfo['brand'] = element.text.trim();
            break;
          }
        } catch (e) {
          // Skip
        }
      }

      // Look for model
      final modelSelectors = ['[class*="model"]', '[data-model]', '[itemprop="model"]'];
      for (String selector in modelSelectors) {
        try {
          final element = document.querySelector(selector);
          if (element != null && element.text?.trim().isNotEmpty == true) {
            productInfo['model'] = element.text.trim();
            break;
          }
        } catch (e) {
          // Skip
        }
      }
    } catch (e) {
      productInfo['extractionError'] = e.toString();
    }

    return productInfo;
  }

  List<String> _extractBrands(dynamic document) {
    List<String> brands = [];

    try {
      final brandElements = document.querySelectorAll('[class*="brand"], [data-brand], [itemprop="brand"]');
      for (var element in brandElements) {
        final brandText = element.text?.trim() ?? '';
        if (brandText.isNotEmpty && brandText.length < 50) {
          brands.add(brandText);
        }
      }
    } catch (e) {
      // Skip
    }

    return brands.toSet().take(5).toList();
  }

  String _getCleanBodyText(dynamic document) {
    try {
      final bodyText = document.body?.text ?? '';
      // Clean up the text - remove extra whitespace, newlines, etc.
      return bodyText.replaceAll(RegExp(r'\s+'), ' ').trim();
    } catch (e) {
      return '';
    }
  }

  Map<String, dynamic> _assessDataQuality(List<String> prices, List<String> specifications, List<String> features) {
    int score = 0;
    List<String> issues = [];

    if (prices.isNotEmpty) {
      score += 30;
    } else {
      issues.add('No pricing information found');
    }

    if (specifications.length >= 3) {
      score += 25;
    } else if (specifications.length >= 1) {
      score += 15;
    } else {
      issues.add('Limited specification data');
    }

    if (features.length >= 3) {
      score += 25;
    } else if (features.length >= 1) {
      score += 15;
    } else {
      issues.add('Few product features identified');
    }

    score += 20; // Base score for successful scraping

    String quality;
    if (score >= 80) {
      quality = 'Excellent';
    } else if (score >= 60) {
      quality = 'Good';
    } else if (score >= 40) {
      quality = 'Fair';
    } else {
      quality = 'Poor';
    }

    return {
      'score': score,
      'quality': quality,
      'issues': issues,
    };
  }

  bool _containsPricePattern(String text) {
    final pricePatterns = [
      RegExp(r'\$[\d,]+\.?\d*'),
      RegExp(r'USD\s*[\d,]+\.?\d*'),
      RegExp(r'[\d,]+\.?\d*\s*dollars?'),
      RegExp(r'Price:?\s*\$?[\d,]+\.?\d*'),
    ];

    return pricePatterns.any((pattern) => pattern.hasMatch(text));
  }

  void _useScrapedData() {
    if (_scrapedData.isNotEmpty && _scrapedData['error'] == null) {
      widget.onDataScrapped(_scrapedData);
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No valid data to use')),
      );
    }
  }

  Widget _buildScrapedDataPreview() {
    if (_scrapedData.isEmpty) {
      return Card(
        margin: EdgeInsets.all(8),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            children: [
              if (_isScraping) ...[
                CircularProgressIndicator(),
                SizedBox(height: 8),
                Text(_scrapingStatus),
              ] else
                Text('No data scraped yet. Page will be automatically scraped when loaded.'),
            ],
          ),
        ),
      );
    }

    final quality = _scrapedData['dataQuality'] as Map<String, dynamic>? ?? {};
    final confidence = _scrapedData['confidence'] ?? 0.0;

    Color qualityColor = Colors.grey;
    if (quality['score'] != null) {
      final score = quality['score'] as int;
      if (score >= 80) {
        qualityColor = Colors.green;
      } else if (score >= 60) {
        qualityColor = Colors.orange;
      } else {
        qualityColor = Colors.red;
      }
    }

    return Container(
      height: 200,
      child: Card(
        margin: EdgeInsets.all(8),
        child: Padding(
          padding: EdgeInsets.all(12),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Scraped Data Preview',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    Spacer(),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: qualityColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: qualityColor),
                      ),
                      child: Text(
                        quality['quality'] ?? 'Unknown',
                        style: TextStyle(
                          color: qualityColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),

                if (_scrapedData['title']?.isNotEmpty == true)
                  _buildPreviewItem('Title', _scrapedData['title'], Icons.title),

                if (_scrapedData['prices']?.isNotEmpty == true)
                  _buildPreviewItem('Prices', '${(_scrapedData['prices'] as List).length} found', Icons.attach_money),

                if (_scrapedData['specifications']?.isNotEmpty == true)
                  _buildPreviewItem('Specs', '${(_scrapedData['specifications'] as List).length} found', Icons.list),

                if (_scrapedData['features']?.isNotEmpty == true)
                  _buildPreviewItem('Features', '${(_scrapedData['features'] as List).length} found', Icons.star),

                if (_scrapedData['brand']?.isNotEmpty == true)
                  _buildPreviewItem('Brand', _scrapedData['brand'], Icons.business),

                SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.schedule, size: 14, color: Colors.grey[600]),
                    SizedBox(width: 4),
                    Text(
                      'Scraped: ${DateTime.parse(_scrapedData['scrapedAt']).toString().split('.')[0]}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPreviewItem(String label, String value, IconData icon) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.grey[600]),
          SizedBox(width: 6),
          Text(
            '$label: ',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Web Scraper'),
        backgroundColor: Colors.purple[600],
        foregroundColor: Colors.white,
        actions: [
          if (!_isScraping && _scrapedData.isNotEmpty)
            IconButton(
              icon: Icon(Icons.refresh),
              onPressed: _performInitialScrape,
              tooltip: 'Re-scrape',
            ),
        ],
      ),
      body: Column(
        children: [
          // Scraped data preview at top
          _buildScrapedDataPreview(),

          // WebView
          Expanded(
            child: Stack(
              children: [
                WebViewWidget(controller: _controller),
                if (_isLoading)
                  Center(
                    child: CircularProgressIndicator(),
                  ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: (_scrapedData.isNotEmpty && !_isScraping)
          ? FloatingActionButton.extended(
        onPressed: _useScrapedData,
        backgroundColor: Colors.green,
        icon: Icon(Icons.check),
        label: Text('USE DATA'),
      )
          : null,
      bottomNavigationBar: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          border: Border(top: BorderSide(color: Colors.grey[300]!)),
        ),
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isScraping ? null : _performInitialScrape,
                icon: _isScraping
                    ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : Icon(Icons.refresh),
                label: Text(_isScraping ? 'Scraping...' : 'Re-scrape'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple[600],
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: (_scrapedData.isNotEmpty && !_isScraping) ? _useScrapedData : null,
                icon: Icon(Icons.download),
                label: Text('USE DATA'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[600],
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}