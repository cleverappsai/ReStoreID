// ========================================
// lib/screens/web_scraper_screen.dart
// ========================================
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import 'dart:convert';

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
            _autoScrapeBasicData();
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  Future<void> _autoScrapeBasicData() async {
    try {
      // Auto-scrape basic data when page loads
      final response = await http.get(Uri.parse(widget.url));
      if (response.statusCode == 200) {
        final document = html_parser.parse(response.body);

        // Extract basic information
        final title = document.querySelector('title')?.text ?? '';
        final description = document.querySelector('meta[name="description"]')?.attributes['content'] ?? '';

        // Look for price patterns
        final priceElements = document.querySelectorAll('[class*="price"], [id*="price"], [data-price]');
        List<String> prices = [];
        for (var element in priceElements) {
          final priceText = element.text.trim();
          if (priceText.isNotEmpty && _containsPricePattern(priceText)) {
            prices.add(priceText);
          }
        }

        // Look for product specifications
        final specElements = document.querySelectorAll('[class*="spec"], [class*="feature"], [class*="detail"]');
        List<String> specifications = [];
        for (var element in specElements) {
          final specText = element.text.trim();
          if (specText.isNotEmpty && specText.length < 200) {
            specifications.add(specText);
          }
        }

        setState(() {
          _scrapedData = {
            'url': widget.url,
            'title': title,
            'description': description,
            'prices': prices,
            'specifications': specifications,
            'fullText': document.body?.text ?? '',
            'scrapedAt': DateTime.now().toIso8601String(),
          };
        });
      }
    } catch (e) {
      print('Auto-scrape error: $e');
    }
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

  Future<void> _performDetailedScrape() async {
    setState(() {
      _isScraping = true;
    });

    try {
      // Get current page content from WebView
      final pageContent = await _controller.runJavaScriptReturningResult(
          'document.documentElement.outerHTML'
      );

      final htmlContent = pageContent.toString().replaceAll('"', '');
      final document = html_parser.parse(htmlContent);

      // Enhanced scraping
      Map<String, dynamic> detailedData = Map.from(_scrapedData);

      // Extract product images
      final imgElements = document.querySelectorAll('img[src*="product"], img[class*="product"]');
      List<String> productImages = [];
      for (var img in imgElements) {
        final src = img.attributes['src'];
        if (src != null && src.isNotEmpty) {
          productImages.add(src);
        }
      }

      // Extract brand information
      final brandElements = document.querySelectorAll('[class*="brand"], [data-brand], [itemprop="brand"]');
      List<String> brands = [];
      for (var element in brandElements) {
        final brandText = element.text.trim();
        if (brandText.isNotEmpty) {
          brands.add(brandText);
        }
      }

      // Extract model numbers
      final modelElements = document.querySelectorAll('[class*="model"], [data-model], [itemprop="model"]');
      List<String> models = [];
      for (var element in modelElements) {
        final modelText = element.text.trim();
        if (modelText.isNotEmpty) {
          models.add(modelText);
        }
      }

      // Extract reviews/ratings
      final ratingElements = document.querySelectorAll('[class*="rating"], [class*="star"], [data-rating]');
      List<String> ratings = [];
      for (var element in ratingElements) {
        final ratingText = element.text.trim();
        if (ratingText.isNotEmpty) {
          ratings.add(ratingText);
        }
      }

      detailedData.addAll({
        'productImages': productImages,
        'brands': brands,
        'models': models,
        'ratings': ratings,
        'detailedScrapeAt': DateTime.now().toIso8601String(),
      });

      setState(() {
        _scrapedData = detailedData;
        _isScraping = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Detailed scraping completed')),
      );

    } catch (e) {
      setState(() {
        _isScraping = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Scraping error: $e')),
      );
    }
  }

  void _useScrapedData() {
    if (_scrapedData.isNotEmpty) {
      widget.onDataScrapped(_scrapedData);
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No data scraped yet')),
      );
    }
  }

  Widget _buildScrapedDataPreview() {
    if (_scrapedData.isEmpty) return SizedBox.shrink();

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
                Text(
                  'Scraped Data Preview',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                SizedBox(height: 8),
                if (_scrapedData['title']?.isNotEmpty == true) ...[
                  Text('Title: ${_scrapedData['title']}', style: TextStyle(fontSize: 12)),
                  SizedBox(height: 4),
                ],
                if (_scrapedData['prices']?.isNotEmpty == true) ...[
                  Text('Prices: ${(_scrapedData['prices'] as List).join(', ')}', style: TextStyle(fontSize: 12)),
                  SizedBox(height: 4),
                ],
                if (_scrapedData['brands']?.isNotEmpty == true) ...[
                  Text('Brands: ${(_scrapedData['brands'] as List).join(', ')}', style: TextStyle(fontSize: 12)),
                  SizedBox(height: 4),
                ],
                if (_scrapedData['models']?.isNotEmpty == true) ...[
                  Text('Models: ${(_scrapedData['models'] as List).join(', ')}', style: TextStyle(fontSize: 12)),
                  SizedBox(height: 4),
                ],
                if (_scrapedData['specifications']?.isNotEmpty == true) ...[
                  Text('Specs Found: ${(_scrapedData['specifications'] as List).length} items', style: TextStyle(fontSize: 12)),
                  SizedBox(height: 4),
                ],
              ],
            ),
          ),
        ),
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
          if (!_isScraping)
            IconButton(
              icon: Icon(Icons.refresh),
              onPressed: _performDetailedScrape,
              tooltip: 'Enhanced Scrape',
            ),
          if (_isScraping)
            Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
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
      floatingActionButton: _scrapedData.isNotEmpty
          ? FloatingActionButton.extended(
        onPressed: _useScrapedData,
        backgroundColor: Colors.green,
        icon: Icon(Icons.check),
        label: Text('USE INFO'),
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
                onPressed: _isScraping ? null : _performDetailedScrape,
                icon: _isScraping
                    ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : Icon(Icons.scanner),
                label: Text(_isScraping ? 'Scraping...' : 'Deep Scrape'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple[600],
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _scrapedData.isNotEmpty ? _useScrapedData : null,
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