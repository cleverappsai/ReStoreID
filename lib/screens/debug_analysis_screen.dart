// ========================================
// lib/screens/debug_analysis_screen.dart
// ========================================
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import '../models/item_job.dart';
import '../services/enhanced_analysis_service.dart';
import '../services/targeted_search_service.dart';
import '../services/storage_service.dart';
import '../services/cloud_services.dart';
import '../services/ai_product_identification_service.dart';

class DebugAnalysisScreen extends StatefulWidget {
  final ItemJob? item;

  const DebugAnalysisScreen({Key? key, this.item}) : super(key: key);

  @override
  _DebugAnalysisScreenState createState() => _DebugAnalysisScreenState();
}

class _DebugAnalysisScreenState extends State<DebugAnalysisScreen> {
  final ScrollController _scrollController = ScrollController();
  final List<String> _debugLogs = [];
  bool _isAnalyzing = false;
  bool _autoScroll = true;
  String? _logFilePath;
  ItemJob? _currentItem;

  @override
  void initState() {
    super.initState();
    _currentItem = widget.item;
    _initializeLogging();
    if (_currentItem != null) {
      _addLog('=== DEBUG ANALYSIS SESSION ===');
      _addLog('Item: ${_currentItem!.userDescription}');
      _addLog('Created: ${_currentItem!.createdAt}');
      _addLog('Images: ${_currentItem!.images.length}');
      _addLog('Current OCR Results: ${_currentItem!.ocrResults?.isNotEmpty == true ? "Available (${_currentItem!.ocrResults!.length} images)" : "None"}');
      _addLog('================================\n');
    }
  }

  Future<void> _initializeLogging() async {
    try {
      Directory logDirectory;

      if (Platform.isAndroid) {
        // Android: Use external storage Downloads folder
        final externalDir = await getExternalStorageDirectory();
        if (externalDir != null) {
          logDirectory = Directory('${externalDir.path}/Download');
        } else {
          // Fallback to application documents if external storage not available
          logDirectory = await getApplicationDocumentsDirectory();
        }
      } else {
        // iOS: Use application documents directory
        logDirectory = await getApplicationDocumentsDirectory();
      }

      // Create directory if it doesn't exist
      if (!await logDirectory.exists()) {
        await logDirectory.create(recursive: true);
      }

      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.')[0];
      _logFilePath = '${logDirectory.path}/restoreid_debug_$timestamp.log';

      _addLog('Log file location: $_logFilePath');
      _addLog('Platform: ${Platform.operatingSystem}');
      _addLog('Log directory: ${logDirectory.path}');

      // Test write access
      await _writeLogToFile('=== ReStoreID Debug Log Session Started ===\n');
      _addLog('✓ Log file write access confirmed\n');

    } catch (e) {
      _addLog('❌ Error initializing log file: $e');
      _logFilePath = null;
    }
  }

  void _addLog(String message) {
    final timestamp = DateTime.now().toIso8601String();
    final logEntry = '[$timestamp] $message';

    setState(() {
      _debugLogs.add(logEntry);
    });

    // Write to file if available
    if (_logFilePath != null) {
      _writeLogToFile('$logEntry\n');
    }

    // Auto-scroll to bottom
    if (_autoScroll) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }

    print(logEntry); // Also print to console
  }

  Future<void> _writeLogToFile(String content) async {
    if (_logFilePath == null) return;

    try {
      final file = File(_logFilePath!);
      await file.writeAsString(content, mode: FileMode.append);
    } catch (e) {
      print('Error writing to log file: $e');
    }
  }

  Future<void> _testOCR() async {
    if (_currentItem == null || _currentItem!.images.isEmpty) {
      _addLog('❌ No item or images available for OCR test');
      return;
    }

    setState(() {
      _isAnalyzing = true;
    });

    try {
      _addLog('\n🔍 TESTING OCR PROCESSING');
      _addLog('Images to process: ${_currentItem!.images.length}');

      for (int i = 0; i < _currentItem!.images.length; i++) {
        final imagePath = _currentItem!.images[i];
        _addLog('\n--- Processing Image ${i + 1} ---');
        _addLog('Image path: $imagePath');

        // Check if file exists
        final file = File(imagePath);
        if (!await file.exists()) {
          _addLog('❌ ERROR: Image file does not exist');
          continue;
        }

        final fileSize = await file.length();
        _addLog('✓ File exists, size: ${fileSize} bytes');

        try {
          _addLog('🚀 Calling CloudServices.performOCR...');
          _addLog('Image path: $imagePath');

          // Check CloudServices configuration first
          _addLog('🔧 Checking CloudServices configuration...');

          final ocrResults = await CloudServices.performOCR([imagePath]);

          if (ocrResults.isNotEmpty) {
            _addLog('✅ OCR SUCCESS for image ${i + 1}');
            _addLog('Raw OCR Results:');
            ocrResults.forEach((imagePath, text) {
              _addLog('Image: ${imagePath.split('/').last}');
              _addLog('OCR Text Length: ${text.length} characters');
              if (text.length > 0) {
                _addLog('OCR Text Content:');
                _addLog('--- START OCR TEXT ---');
                _addLog(text);
                _addLog('--- END OCR TEXT ---');
              } else {
                _addLog('⚠️ OCR returned empty text');
              }
            });
          } else {
            _addLog('⚠️ OCR returned empty results for image ${i + 1}');
            _addLog('This could indicate:');
            _addLog('- OCR service not configured');
            _addLog('- API key missing or invalid');
            _addLog('- Network connectivity issues');
            _addLog('- Image format not supported');
          }

        } catch (e, stackTrace) {
          _addLog('❌ OCR ERROR for image ${i + 1}: $e');
          _addLog('Error type: ${e.runtimeType}');
          _addLog('Stack trace: $stackTrace');

          // Additional debugging for common OCR issues
          if (e.toString().contains('API')) {
            _addLog('💡 Possible API configuration issue - check CloudServices setup');
          }
          if (e.toString().contains('network') || e.toString().contains('connection')) {
            _addLog('💡 Network issue - check internet connection');
          }
          if (e.toString().contains('key') || e.toString().contains('auth')) {
            _addLog('💡 Authentication issue - check API keys');
          }
        }
      }

      // Test full OCR processing
      _addLog('\n🔄 Testing full batch OCR processing...');
      try {
        final allOcrResults = await CloudServices.performOCR(_currentItem!.images);
        _addLog('✅ Batch OCR completed');
        _addLog('Total results: ${allOcrResults.length}');

        if (allOcrResults.isNotEmpty) {
          // Update item with results
          final updatedItem = _currentItem!.copyWith(
            ocrResults: allOcrResults,
            ocrCompleted: true,
          );
          await StorageService.saveJob(updatedItem);
          setState(() {
            _currentItem = updatedItem;
          });
          _addLog('💾 Updated item with OCR results');
        }

      } catch (e, stackTrace) {
        _addLog('❌ Batch OCR ERROR: $e');
        _addLog('Stack trace: $stackTrace');
      }

    } finally {
      setState(() {
        _isAnalyzing = false;
      });
    }
  }

  Future<void> _testAIIdentification() async {
    if (_currentItem == null || _currentItem!.images.isEmpty) {
      _addLog('❌ No item or images available for AI identification test');
      return;
    }

    setState(() {
      _isAnalyzing = true;
    });

    try {
      _addLog('\n🤖 TESTING AI PRODUCT IDENTIFICATION');
      _addLog('Images to analyze: ${_currentItem!.images.length}');

      // Test each image individually first
      for (int i = 0; i < _currentItem!.images.length; i++) {
        final imagePath = _currentItem!.images[i];
        _addLog('\n--- AI Analysis Image ${i + 1} ---');
        _addLog('Image path: $imagePath');

        // Check if file exists
        final file = File(imagePath);
        if (!await file.exists()) {
          _addLog('❌ ERROR: Image file does not exist');
          continue;
        }

        final fileSize = await file.length();
        _addLog('✓ File exists, size: ${fileSize} bytes');

        try {
          _addLog('🚀 Calling AI analysis for single image...');

          // Call the individual image analysis method directly
          final imageResult = await AIProductIdentificationService.analyzeImage(imagePath);

          _addLog('📊 AI Image Analysis Result:');
          _addLog('Success: ${imageResult['success']}');

          if (imageResult['success'] == true) {
            _addLog('✅ AI analysis successful for image ${i + 1}');

            if (imageResult['rawResponse'] != null) {
              _addLog('Raw AI Response:');
              _addLog('--- START AI RESPONSE ---');
              _addLog(imageResult['rawResponse']);
              _addLog('--- END AI RESPONSE ---');
            }

            if (imageResult['aiResults'] != null) {
              _addLog('Parsed AI Results:');
              final aiResults = imageResult['aiResults'];
              _addLog(JsonEncoder.withIndent('  ').convert(aiResults));
            }

            if (imageResult['parseError'] != null) {
              _addLog('⚠️ Parse Warning: ${imageResult['parseError']}');
            }

          } else {
            _addLog('❌ AI analysis failed for image ${i + 1}');
            _addLog('Error: ${imageResult['error']}');
          }

        } catch (e, stackTrace) {
          _addLog('❌ AI ANALYSIS ERROR for image ${i + 1}: $e');
          _addLog('Stack trace: $stackTrace');
        }
      }

      // Test full batch AI processing
      _addLog('\n🔄 Testing full batch AI identification...');
      try {
        final aiResults = await AIProductIdentificationService.analyzeMultipleImages(_currentItem!.images);

        _addLog('✅ Batch AI identification completed');
        _addLog('Overall Success: ${aiResults['success']}');
        _addLog('Images Processed: ${aiResults['imagesProcessed']}');

        if (aiResults['success'] == true) {
          _addLog('📊 Consolidated AI Results:');
          _addLog(JsonEncoder.withIndent('  ').convert(aiResults['results']));

          if (aiResults['results']['validation'] != null) {
            _addLog('🔍 Validation Results:');
            _addLog(JsonEncoder.withIndent('  ').convert(aiResults['results']['validation']));
          }
        } else {
          _addLog('❌ Batch AI identification failed: ${aiResults['error']}');
        }

      } catch (e, stackTrace) {
        _addLog('❌ Batch AI identification ERROR: $e');
        _addLog('Stack trace: $stackTrace');
      }

    } finally {
      setState(() {
        _isAnalyzing = false;
      });
    }
  }

  Future<void> _testSearchQueries() async {
    if (_currentItem == null) {
      _addLog('❌ No item available for search query test');
      return;
    }

    setState(() {
      _isAnalyzing = true;
    });

    try {
      _addLog('\n🔍 TESTING SEARCH QUERY GENERATION');

      // First test with current OCR results if available
      if (_currentItem!.ocrResults != null && _currentItem!.ocrResults!.isNotEmpty) {
        _addLog('\n📝 Testing with existing OCR results...');
        _addLog('OCR Results count: ${_currentItem!.ocrResults!.length}');
        _currentItem!.ocrResults!.forEach((imagePath, text) {
          _addLog('\nImage: ${imagePath.split('/').last}');
          _addLog('OCR Text (${text.length} chars): ${text.substring(0, text.length > 300 ? 300 : text.length)}${text.length > 300 ? '...' : ''}');
        });

        try {
          _addLog('\n🎯 Extracting product identifiers using TargetedSearchService...');
          final productInfo = TargetedSearchService.extractProductIdentifiers(_currentItem!.ocrResults!);

          _addLog('\n📊 Product Identification Results:');
          _addLog('Raw productInfo keys: ${productInfo.keys.toList()}');
          _addLog(JsonEncoder.withIndent('  ').convert(productInfo));

          // Test search query generation with detailed logging
          _addLog('\n🚀 Generating targeted search queries...');
          _addLog('Input parameters:');
          _addLog('  manufacturer: "${productInfo['manufacturer'] ?? ''}"');
          _addLog('  productName: "${productInfo['productName'] ?? ''}"');
          _addLog('  modelNumber: "${productInfo['modelNumber'] ?? ''}"');
          _addLog('  partNumber: "${productInfo['partNumber'] ?? ''}"');

          // Check if we have enough data for search
          final manufacturer = productInfo['manufacturer']?.toString() ?? '';
          final productName = productInfo['productName']?.toString() ?? '';

          if (manufacturer.isEmpty && productName.isEmpty) {
            _addLog('⚠️ WARNING: Both manufacturer and productName are empty!');
            _addLog('This will likely cause search to fail or return no results');

            // Test with manual data from what we know works
            _addLog('\n🔧 Testing with manually extracted data from successful AI results...');
            final manualProductInfo = {
              'manufacturer': 'Seeed Studio',
              'productName': 'reCamera 2002 Series',
              'modelNumber': 'reCamera 2002w 64GB',
              'partNumber': '',
            };

            _addLog('Manual test parameters:');
            _addLog('  manufacturer: "${manualProductInfo['manufacturer']}"');
            _addLog('  productName: "${manualProductInfo['productName']}"');
            _addLog('  modelNumber: "${manualProductInfo['modelNumber']}"');

            final manualSearchResults = await TargetedSearchService.performTargetedSearch(
              manufacturer: manualProductInfo['manufacturer']!,
              productName: manualProductInfo['productName']!,
              modelNumber: manualProductInfo['modelNumber'],
              partNumber: manualProductInfo['partNumber'],
            );

            _addLog('\n📊 Manual Search Results:');
            _addLog('Success: ${manualSearchResults['success']}');
            _addLog('Search Count: ${manualSearchResults['searchCount']}');
            _addLog('Results Found: ${manualSearchResults['resultsFound']}');
            _addLog('Manufacturer Used: "${manualSearchResults['manufacturer']}"');
            _addLog('Product Name Used: "${manualSearchResults['productName']}"');

            if (manualSearchResults['searchResults'] != null) {
              final results = List<Map<String, dynamic>>.from(manualSearchResults['searchResults']);
              _addLog('\n🔗 Manual Search Individual Results:');
              for (int i = 0; i < results.length && i < 3; i++) {
                final result = results[i];
                _addLog('\n--- Manual Result ${i + 1} ---');
                _addLog('Title: ${result['title']}');
                _addLog('URL: ${result['url']}');
                _addLog('Search Type: ${result['searchType']}');
                _addLog('Confidence: ${result['confidence']}');
              }
            }
          }

          // Continue with original search
          final searchResults = await TargetedSearchService.performTargetedSearch(
            manufacturer: manufacturer,
            productName: productName,
            modelNumber: productInfo['modelNumber'],
            partNumber: productInfo['partNumber'],
          );

          _addLog('\n📊 OCR-based Search Query Results:');
          _addLog('Success: ${searchResults['success']}');
          _addLog('Search Count: ${searchResults['searchCount']}');
          _addLog('Results Found: ${searchResults['resultsFound']}');
          _addLog('Manufacturer Used: "${searchResults['manufacturer']}"');
          _addLog('Product Name Used: "${searchResults['productName']}"');

          // Log the raw search results structure
          _addLog('\n🔍 Raw Search Results Structure:');
          _addLog('Keys in searchResults: ${searchResults.keys.toList()}');

          if (searchResults['searchResults'] != null) {
            final results = List<Map<String, dynamic>>.from(searchResults['searchResults']);
            _addLog('\n🔗 Individual Search Results:');
            _addLog('Total results: ${results.length}');

            for (int i = 0; i < results.length && i < 5; i++) {
              final result = results[i];
              _addLog('\n--- Search Result ${i + 1} ---');
              _addLog('Keys: ${result.keys.toList()}');
              _addLog('Title: ${result['title']}');
              _addLog('URL: ${result['url']}');
              _addLog('Search Type: ${result['searchType']}');
              _addLog('Confidence: ${result['confidence']}');
              _addLog('Found At: ${result['foundAt']}');
              if (result['snippet'] != null) {
                final snippet = result['snippet'].toString();
                _addLog('Snippet: ${snippet.length > 200 ? snippet.substring(0, 200) + '...' : snippet}');
              }
            }

            if (results.length > 5) {
              _addLog('\n... and ${results.length - 5} more results');
            }
          } else {
            _addLog('⚠️ searchResults[\'searchResults\'] is null');
          }

        } catch (e, stackTrace) {
          _addLog('❌ Search query generation ERROR: $e');
          _addLog('Stack trace: $stackTrace');
        }

      } else {
        _addLog('⚠️ No OCR results available - testing with user descriptions...');

        // Create mock OCR from user descriptions for testing
        Map<String, String> mockOCR = {};
        if (_currentItem!.userDescription.isNotEmpty) {
          mockOCR['user_description'] = _currentItem!.userDescription;
        }
        if (_currentItem!.searchDescription.isNotEmpty) {
          mockOCR['search_description'] = _currentItem!.searchDescription;
        }

        if (mockOCR.isNotEmpty) {
          _addLog('📝 Testing with mock OCR from user input...');
          _addLog('Mock OCR: $mockOCR');

          try {
            final productInfo = TargetedSearchService.extractProductIdentifiers(mockOCR);
            _addLog('📊 Product Identification from User Input:');
            _addLog(JsonEncoder.withIndent('  ').convert(productInfo));

            // Test search with user data
            final searchResults = await TargetedSearchService.performTargetedSearch(
              manufacturer: productInfo['manufacturer'] ?? '',
              productName: productInfo['productName'] ?? '',
              modelNumber: productInfo['modelNumber'],
              partNumber: productInfo['partNumber'],
            );

            _addLog('📊 User-based Search Results:');
            _addLog(JsonEncoder.withIndent('  ').convert(searchResults));

          } catch (e, stackTrace) {
            _addLog('❌ Mock search ERROR: $e');
            _addLog('Stack trace: $stackTrace');
          }
        } else {
          _addLog('❌ No user descriptions available for testing');
        }
      }

    } finally {
      setState(() {
        _isAnalyzing = false;
      });
    }
  }

  Future<void> _runFullAnalysis() async {
    if (_currentItem == null) {
      _addLog('❌ No item selected for analysis');
      return;
    }

    setState(() {
      _isAnalyzing = true;
    });

    try {
      _addLog('\n🔍 STARTING FULL ENHANCED ANALYSIS');
      _addLog('Item ID: ${_currentItem!.id}');
      _addLog('Description: ${_currentItem!.userDescription}');
      _addLog('Search Keywords: ${_currentItem!.searchDescription}');
      _addLog('Images: ${_currentItem!.images.length}');

      // Log all image paths
      for (int i = 0; i < _currentItem!.images.length; i++) {
        _addLog('Image ${i + 1}: ${_currentItem!.images[i]}');
      }

      _addLog('\n🚀 Calling EnhancedAnalysisService.performCompleteAnalysis...');

      final analysisResult = await EnhancedAnalysisService.performCompleteAnalysis(_currentItem!);

      _addLog('\n📋 COMPLETE ANALYSIS RESULT:');
      _addLog('Success: ${analysisResult['success']}');

      if (analysisResult['success'] == true) {
        final analysis = analysisResult['analysis'];
        _addLog('Overall Confidence: ${(analysis['overallConfidence'] * 100).toStringAsFixed(1)}%');
        _addLog('Analysis Type: ${analysis['analysisType']}');
        _addLog('Identification Method: ${analysis['identificationMethod']}');

        // Product Info
        _addLog('\n🏷️ PRODUCT INFORMATION:');
        if (analysis['productInfo'] != null) {
          _addLog(JsonEncoder.withIndent('  ').convert(analysis['productInfo']));
        }

        // Search Summary
        _addLog('\n🔍 SEARCH SUMMARY:');
        if (analysis['searchSummary'] != null) {
          _addLog(JsonEncoder.withIndent('  ').convert(analysis['searchSummary']));
        }

        // Content Summary
        _addLog('\n📄 CONTENT SUMMARY:');
        if (analysis['contentSummary'] != null) {
          _addLog(JsonEncoder.withIndent('  ').convert(analysis['contentSummary']));
        }

        // Summary
        _addLog('\n📝 GENERATED SUMMARY:');
        if (analysis['summary'] != null) {
          _addLog(JsonEncoder.withIndent('  ').convert(analysis['summary']));
        }

        // Pricing
        _addLog('\n💰 PRICING ANALYSIS:');
        if (analysis['pricing'] != null) {
          _addLog(JsonEncoder.withIndent('  ').convert(analysis['pricing']));
        }

        // Raw Data (for detailed debugging)
        _addLog('\n🔧 RAW DEBUG DATA:');
        if (analysis['rawData'] != null) {
          _addLog('Raw data contains: ${analysis['rawData'].keys}');

          // Log each raw data section
          analysis['rawData'].forEach((key, value) {
            _addLog('\n--- Raw $key ---');
            try {
              _addLog(JsonEncoder.withIndent('  ').convert(value));
            } catch (e) {
              _addLog('Error serializing $key: $e');
              _addLog('Value: $value');
            }
          });
        }

      } else {
        _addLog('❌ Analysis Error: ${analysisResult['error']}');
        if (analysisResult['stackTrace'] != null) {
          _addLog('Stack trace: ${analysisResult['stackTrace']}');
        }
      }

      // Reload item to get updated data
      final updatedItem = await StorageService.getJob(_currentItem!.id);
      if (updatedItem != null) {
        setState(() {
          _currentItem = updatedItem;
        });
        _addLog('🔄 Reloaded updated item from storage');
      }

      _addLog('\n✅ FULL ANALYSIS COMPLETE');

    } catch (e, stackTrace) {
      _addLog('❌ FULL ANALYSIS FAILED: $e');
      _addLog('Stack trace: $stackTrace');
    } finally {
      setState(() {
        _isAnalyzing = false;
      });
    }
  }

  Future<void> _exportLogs() async {
    if (_logFilePath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No log file available')),
      );
      return;
    }

    try {
      // Copy log path to clipboard
      await Clipboard.setData(ClipboardData(text: _logFilePath!));

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Log file path copied to clipboard:\n$_logFilePath'),
          duration: Duration(seconds: 5),
        ),
      );

      _addLog('📋 Log file path copied to clipboard');

    } catch (e) {
      _addLog('❌ Error exporting logs: $e');
    }
  }

  Future<void> _clearLogs() async {
    setState(() {
      _debugLogs.clear();
    });

    _addLog('🧹 Logs cleared');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Debug Analysis'),
        backgroundColor: Colors.orange[600],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.file_download),
            onPressed: _exportLogs,
            tooltip: 'Export Log File',
          ),
          IconButton(
            icon: Icon(Icons.clear_all),
            onPressed: _clearLogs,
            tooltip: 'Clear Logs',
          ),
        ],
      ),
      body: Column(
        children: [
          // Controls
          Container(
            padding: EdgeInsets.all(16),
            color: Colors.grey[100],
            child: Column(
              children: [
                // Item Selection
                if (_currentItem != null)
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Current Item: ${_currentItem!.userDescription}',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.blue[800],
                          ),
                        ),
                        Text(
                          'Images: ${_currentItem!.images.length} • OCR: ${_currentItem!.ocrResults?.isNotEmpty == true ? "Available" : "None"} • Created: ${_currentItem!.createdAt.toString().split('.')[0]}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue[600],
                          ),
                        ),
                      ],
                    ),
                  ),

                SizedBox(height: 12),

                // Test Buttons
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isAnalyzing ? null : _testOCR,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple[600],
                          foregroundColor: Colors.white,
                        ),
                        child: Text('Test OCR'),
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isAnalyzing ? null : _testAIIdentification,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigo[600],
                          foregroundColor: Colors.white,
                        ),
                        child: Text('Test AI ID'),
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 8),

                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isAnalyzing ? null : _testSearchQueries,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange[600],
                          foregroundColor: Colors.white,
                        ),
                        child: Text('Test Search'),
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isAnalyzing ? null : _runFullAnalysis,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[600],
                          foregroundColor: Colors.white,
                        ),
                        child: _isAnalyzing
                            ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            ),
                            SizedBox(width: 8),
                            Text('Running...'),
                          ],
                        )
                            : Text('Full Analysis'),
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 8),

                // Auto-scroll toggle
                Row(
                  children: [
                    Checkbox(
                      value: _autoScroll,
                      onChanged: (value) {
                        setState(() {
                          _autoScroll = value ?? true;
                        });
                      },
                    ),
                    Text('Auto-scroll to bottom'),
                    Spacer(),
                    if (_logFilePath != null)
                      Text(
                        'Log: ${_logFilePath!.split('/').last}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.green[600],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),

          // Log Display
          Expanded(
            child: Container(
              color: Colors.black,
              child: ListView.builder(
                controller: _scrollController,
                padding: EdgeInsets.all(8),
                itemCount: _debugLogs.length,
                itemBuilder: (context, index) {
                  final log = _debugLogs[index];
                  Color textColor = Colors.green[300]!;

                  if (log.contains('❌') || log.contains('ERROR') || log.contains('FAILED')) {
                    textColor = Colors.red[300]!;
                  } else if (log.contains('⚠️') || log.contains('WARNING')) {
                    textColor = Colors.orange[300]!;
                  } else if (log.contains('✅') || log.contains('SUCCESS') || log.contains('✓')) {
                    textColor = Colors.green[300]!;
                  } else if (log.contains('🔍') || log.contains('STEP') || log.contains('===')) {
                    textColor = Colors.cyan[300]!;
                  } else if (log.contains('🤖') || log.contains('AI ')) {
                    textColor = Colors.purple[300]!;
                  } else if (log.contains('🚀') || log.contains('Calling')) {
                    textColor = Colors.yellow[300]!;
                  }

                  return Padding(
                    padding: EdgeInsets.symmetric(vertical: 1),
                    child: SelectableText(
                      log,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}