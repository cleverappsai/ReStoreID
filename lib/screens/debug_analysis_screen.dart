// ========================================
// lib/screens/debug_analysis_screen.dart
// ========================================
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:convert';
import '../models/item_job.dart';
import '../services/cloud_services.dart';
import '../services/targeted_search_service.dart';

enum LogLevel {
  info,
  success,
  warning,
  error,
}

class DebugLogEntry {
  final DateTime timestamp;
  final String operation;
  final String message;
  final LogLevel level;
  final Map<String, dynamic>? data;

  DebugLogEntry({
    required this.timestamp,
    required this.operation,
    required this.message,
    required this.level,
    this.data,
  });
}

class DebugAnalysisScreen extends StatefulWidget {
  final ItemJob item;

  const DebugAnalysisScreen({Key? key, required this.item}) : super(key: key);

  @override
  _DebugAnalysisScreenState createState() => _DebugAnalysisScreenState();
}

class _DebugAnalysisScreenState extends State<DebugAnalysisScreen> {
  final ScrollController _scrollController = ScrollController();
  List<DebugLogEntry> _debugLogs = [];
  bool _isRunning = false;
  String _currentOperation = '';

  @override
  void initState() {
    super.initState();
    _addDebugLog('DEBUG SESSION STARTED', 'System initialized for item: ${widget.item.userDescription}', LogLevel.info);
  }

  void _addDebugLog(String operation, String message, LogLevel level, [Map<String, dynamic>? data]) {
    setState(() {
      _debugLogs.add(DebugLogEntry(
        timestamp: DateTime.now(),
        operation: operation,
        message: message,
        level: level,
        data: data,
      ));
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });

    _saveLogToFile(operation, message, level, data);
  }

  Future<void> _saveLogToFile(String operation, String message, LogLevel level, [Map<String, dynamic>? data]) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/debug_analysis_${widget.item.id}.txt');

      final timestamp = DateTime.now().toIso8601String();
      final logEntry = '[$timestamp] [$level] [$operation] $message\n';

      await file.writeAsString(logEntry, mode: FileMode.append);

      if (data != null) {
        final dataJson = JsonEncoder.withIndent('  ').convert(data);
        await file.writeAsString('DATA: $dataJson\n\n', mode: FileMode.append);
      }
    } catch (e) {
      print('Failed to save debug log: $e');
    }
  }

  Future<void> _runPackagingSearch() async {
    if (_isRunning) return;

    setState(() {
      _isRunning = true;
      _currentOperation = 'Packaging Search';
    });

    _addDebugLog('PACKAGING_SEARCH', 'Starting packaging search analysis', LogLevel.info);

    try {
      final packagingImages = _getImagesByLabel('packaging');
      _addDebugLog('PACKAGING_SEARCH', 'Found ${packagingImages.length} packaging images', LogLevel.info, {
        'images': packagingImages,
      });

      if (packagingImages.isEmpty) {
        _addDebugLog('PACKAGING_SEARCH', 'No packaging images available - cannot proceed', LogLevel.warning);
        return;
      }

      _addDebugLog('PACKAGING_SEARCH', 'Step 1: Performing intelligent analysis on packaging images', LogLevel.info);

      Map<String, String> ocrResults = {};
      for (int i = 0; i < packagingImages.length; i++) {
        final imagePath = packagingImages[i];
        _addDebugLog('PACKAGING_SEARCH', 'Processing image ${i + 1}/${packagingImages.length}: ${imagePath.split('/').last}', LogLevel.info);

        try {
          final result = await CloudServices.analyzeProductLabel(imagePath, imageType: 'packaging');

          if (result['success'] == true) {
            final analysis = result['analysis'] as Map<String, dynamic>;

            _addDebugLog('PACKAGING_SEARCH', 'Analysis Result ${i + 1}: Found product data', LogLevel.success, {
              'imagePath': imagePath,
              'extractedText': result['extractedText'],
              'manufacturer': analysis['manufacturer'],
              'productName': analysis['productName'],
              'modelNumber': analysis['modelNumber'],
              'productType': analysis['productType'],
              'confidence': result['confidence'],
              'fullAnalysis': analysis,
            });

            ocrResults['packaging_$i'] = result['extractedText'];
          } else {
            _addDebugLog('PACKAGING_SEARCH', 'Analysis failed for image ${i + 1}: ${result['error']}', LogLevel.error);
          }
        } catch (e) {
          _addDebugLog('PACKAGING_SEARCH', 'Processing failed for image ${i + 1}: $e', LogLevel.error);
        }
      }

      _addDebugLog('PACKAGING_SEARCH', 'Step 2: Calling CloudServices.searchPackaging()', LogLevel.info);

      final searchResults = await CloudServices.searchPackaging(packagingImages);
      _addDebugLog('PACKAGING_SEARCH', 'Packaging search API call completed', LogLevel.success, {
        'searchResults': searchResults,
      });

      final confidence = searchResults['confidence'] ?? 0.0;
      final candidatesCount = (searchResults['candidates'] as List?)?.length ?? 0;

      _addDebugLog('PACKAGING_SEARCH', 'Search analysis complete', LogLevel.success, {
        'confidence': confidence,
        'candidatesFound': candidatesCount,
        'summary': 'Confidence: ${(confidence * 100).toInt()}%, Results found: ${searchResults['products']?.length ?? 0}',
      });

    } catch (e) {
      _addDebugLog('PACKAGING_SEARCH', 'Packaging search failed with error: $e', LogLevel.error, {
        'error': e.toString(),
      });
    } finally {
      setState(() {
        _isRunning = false;
        _currentOperation = '';
      });
      _addDebugLog('PACKAGING_SEARCH', 'Packaging search operation completed', LogLevel.info);
    }
  }

  Future<void> _runBarcodeSearch() async {
    if (_isRunning) return;

    setState(() {
      _isRunning = true;
      _currentOperation = 'Barcode Search';
    });

    _addDebugLog('BARCODE_SEARCH', 'Starting barcode search analysis', LogLevel.info);

    try {
      final barcodeImages = _getImagesByLabel('barcode');
      _addDebugLog('BARCODE_SEARCH', 'Found ${barcodeImages.length} barcode images', LogLevel.info, {
        'images': barcodeImages,
      });

      if (barcodeImages.isEmpty) {
        _addDebugLog('BARCODE_SEARCH', 'No barcode images available - cannot proceed', LogLevel.warning);
        return;
      }

      _addDebugLog('BARCODE_SEARCH', 'Step 1: Detecting barcodes and UPCs', LogLevel.info);

      final barcodeResults = await CloudServices.detectBarcodesAndUPCs(barcodeImages);
      _addDebugLog('BARCODE_SEARCH', 'Barcode detection completed', LogLevel.success, {
        'barcodeResults': barcodeResults,
      });

      final barcodes = List<String>.from(barcodeResults['barcodes'] ?? []);
      final upcs = List<String>.from(barcodeResults['upcs'] ?? []);
      final allCodes = [...barcodes, ...upcs];

      _addDebugLog('BARCODE_SEARCH', 'Detected codes: ${barcodes.length} barcodes, ${upcs.length} UPCs', LogLevel.info, {
        'barcodes': barcodes,
        'upcs': upcs,
        'allCodes': allCodes,
      });

      _addDebugLog('BARCODE_SEARCH', 'Step 2: Generating search candidates', LogLevel.info);

      List<Map<String, dynamic>> candidates = [];
      for (String code in allCodes.take(5)) {
        candidates.add({
          'title': 'UPC Database: $code',
          'url': 'https://www.upcitemdb.com/upc/$code',
          'confidence': 0.9,
          'type': 'barcode_lookup',
          'site': 'UPC Database',
          'searchTerm': code,
        });

        candidates.add({
          'title': 'eBay Search: $code',
          'url': 'https://www.ebay.com/sch/i.html?_nkw=${Uri.encodeComponent(code)}',
          'confidence': 0.8,
          'type': 'barcode_search',
          'site': 'eBay',
          'searchTerm': code,
        });
      }

      _addDebugLog('BARCODE_SEARCH', 'Search candidates generated', LogLevel.success, {
        'candidatesGenerated': candidates.length,
        'allCandidates': candidates,
      });

      for (int i = 0; i < candidates.length; i++) {
        final candidate = candidates[i];
        _addDebugLog('BARCODE_SEARCH', 'Candidate ${i + 1}: ${candidate['title']}', LogLevel.info, {
          'candidate': candidate,
        });
      }

    } catch (e) {
      _addDebugLog('BARCODE_SEARCH', 'Barcode search failed with error: $e', LogLevel.error, {
        'error': e.toString(),
      });
    } finally {
      setState(() {
        _isRunning = false;
        _currentOperation = '';
      });
      _addDebugLog('BARCODE_SEARCH', 'Barcode search operation completed', LogLevel.info);
    }
  }

  Future<void> _runReverseImageSearch() async {
    if (_isRunning) return;

    setState(() {
      _isRunning = true;
      _currentOperation = 'Reverse Image Search';
    });

    _addDebugLog('REVERSE_SEARCH', 'Starting reverse image search analysis', LogLevel.info);

    try {
      final idImages = _getImagesByLabel('id');
      _addDebugLog('REVERSE_SEARCH', 'Found ${idImages.length} ID images', LogLevel.info, {
        'images': idImages,
      });

      if (idImages.isEmpty) {
        _addDebugLog('REVERSE_SEARCH', 'No ID images available - cannot proceed', LogLevel.warning);
        return;
      }

      _addDebugLog('REVERSE_SEARCH', 'Step 1: Preparing images for reverse search', LogLevel.info);

      for (int i = 0; i < idImages.length; i++) {
        final imagePath = idImages[i];
        final file = File(imagePath);
        final exists = await file.exists();
        final size = exists ? await file.length() : 0;

        _addDebugLog('REVERSE_SEARCH', 'Image ${i + 1}: ${imagePath.split('/').last} (${size} bytes)',
            exists ? LogLevel.info : LogLevel.warning, {
              'imagePath': imagePath,
              'exists': exists,
              'sizeBytes': size,
            });
      }

      _addDebugLog('REVERSE_SEARCH', 'Step 2: Calling CloudServices.reverseImageSearchWithCandidates()', LogLevel.info);

      final searchResults = await CloudServices.reverseImageSearchWithCandidates(idImages);
      _addDebugLog('REVERSE_SEARCH', 'Reverse image search API call completed', LogLevel.success, {
        'searchResults': searchResults,
      });

      final confidence = searchResults['confidence'] ?? 0.0;
      final candidatesCount = (searchResults['candidates'] as List?)?.length ?? 0;
      final text = searchResults['text'] ?? '';

      _addDebugLog('REVERSE_SEARCH', 'Search analysis complete', LogLevel.success, {
        'confidence': confidence,
        'candidatesFound': candidatesCount,
        'extractedText': text.length > 100 ? '${text.substring(0, 100)}...' : text,
        'summary': 'Confidence: ${(confidence * 100).toInt()}%, Candidates: $candidatesCount',
      });

      if (candidatesCount > 0) {
        final candidates = searchResults['candidates'] as List;
        for (int i = 0; i < candidates.length; i++) {
          final candidate = candidates[i];
          _addDebugLog('REVERSE_SEARCH', 'Candidate ${i + 1}: ${candidate['title'] ?? 'Unknown'}', LogLevel.info, {
            'candidate': candidate,
          });
        }
      }

    } catch (e) {
      _addDebugLog('REVERSE_SEARCH', 'Reverse image search failed with error: $e', LogLevel.error, {
        'error': e.toString(),
      });
    } finally {
      setState(() {
        _isRunning = false;
        _currentOperation = '';
      });
      _addDebugLog('REVERSE_SEARCH', 'Reverse image search operation completed', LogLevel.info);
    }
  }

  Future<void> _runIntelligentAnalysis() async {
    if (_isRunning) return;

    setState(() {
      _isRunning = true;
      _currentOperation = 'Intelligent Analysis';
    });

    _addDebugLog('INTELLIGENT_ANALYSIS', 'Starting intelligent product analysis on all images', LogLevel.info);

    try {
      Map<String, Map<String, dynamic>> allAnalyses = {};

      for (int i = 0; i < widget.item.images.length; i++) {
        final imagePath = widget.item.images[i];
        final fileName = imagePath.split('/').last;

        String imageType = 'label';
        if (widget.item.imageClassification != null) {
          for (var entry in widget.item.imageClassification!.entries) {
            if (entry.value.contains(imagePath)) {
              imageType = entry.key;
              break;
            }
          }
        }

        _addDebugLog('INTELLIGENT_ANALYSIS', 'Analyzing image ${i + 1}/${widget.item.images.length}: $fileName as $imageType', LogLevel.info);

        try {
          final result = await CloudServices.analyzeProductLabel(imagePath, imageType: imageType);

          if (result['success'] == true) {
            final analysis = result['analysis'] as Map<String, dynamic>;
            allAnalyses[fileName] = {
              'imageType': imageType,
              'extractedText': result['extractedText'],
              'analysis': analysis,
              'confidence': result['confidence'],
            };

            _addDebugLog('INTELLIGENT_ANALYSIS', 'Analysis completed for $fileName', LogLevel.success, {
              'imageType': imageType,
              'manufacturer': analysis['manufacturer'],
              'productName': analysis['productName'],
              'modelNumber': analysis['modelNumber'],
              'confidence': result['confidence'],
            });
          } else {
            _addDebugLog('INTELLIGENT_ANALYSIS', 'Analysis failed for $fileName: ${result['error']}', LogLevel.error);
          }
        } catch (e) {
          _addDebugLog('INTELLIGENT_ANALYSIS', 'Error analyzing $fileName: $e', LogLevel.error);
        }
      }

      _addDebugLog('INTELLIGENT_ANALYSIS', 'Synthesis completed with ${allAnalyses.length} analyzed images', LogLevel.success, {
        'totalAnalyzed': allAnalyses.length,
      });

    } catch (e) {
      _addDebugLog('INTELLIGENT_ANALYSIS', 'Intelligent analysis failed with error: $e', LogLevel.error, {
        'error': e.toString(),
      });
    } finally {
      setState(() {
        _isRunning = false;
        _currentOperation = '';
      });
      _addDebugLog('INTELLIGENT_ANALYSIS', 'Intelligent analysis operation completed', LogLevel.info);
    }
  }

  List<String> _getImagesByLabel(String label) {
    if (widget.item.imageClassification == null) {
      return [];
    }
    return widget.item.imageClassification![label] ?? [];
  }

  Future<void> _clearLogs() async {
    setState(() {
      _debugLogs.clear();
    });
    _addDebugLog('SYSTEM', 'Debug logs cleared', LogLevel.info);
  }

  Future<void> _exportLogs() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/debug_analysis_${widget.item.id}.txt');

      if (await file.exists()) {
        final content = await file.readAsString();
        _addDebugLog('EXPORT', 'Logs exported to: ${file.path}', LogLevel.success, {
          'filePath': file.path,
          'fileSize': content.length,
          'directoryPath': directory.path,
        });

        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Logs Exported'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('File saved to:', style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                SelectableText(file.path, style: TextStyle(fontFamily: 'monospace', fontSize: 12)),
                SizedBox(height: 16),
                Text('Directory:', style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(height: 4),
                SelectableText(directory.path, style: TextStyle(fontFamily: 'monospace', fontSize: 12)),
                SizedBox(height: 16),
                Text('File size: ${content.length} characters'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('OK'),
              ),
            ],
          ),
        );
      } else {
        _addDebugLog('EXPORT', 'No log file found to export', LogLevel.warning);
      }
    } catch (e) {
      _addDebugLog('EXPORT', 'Export failed: $e', LogLevel.error);
    }
  }

  Color _getLogLevelColor(LogLevel level) {
    switch (level) {
      case LogLevel.success:
        return Colors.green;
      case LogLevel.warning:
        return Colors.orange;
      case LogLevel.error:
        return Colors.red;
      case LogLevel.info:
      default:
        return Colors.blue;
    }
  }

  IconData _getLogLevelIcon(LogLevel level) {
    switch (level) {
      case LogLevel.success:
        return Icons.check_circle;
      case LogLevel.warning:
        return Icons.warning;
      case LogLevel.error:
        return Icons.error;
      case LogLevel.info:
      default:
        return Icons.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Debug Analysis'),
        backgroundColor: Colors.indigo[600],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _clearLogs,
            icon: Icon(Icons.clear_all),
            tooltip: 'Clear Logs',
          ),
          IconButton(
            onPressed: _exportLogs,
            icon: Icon(Icons.file_download),
            tooltip: 'Export Logs',
          ),
        ],
      ),
      body: Column(
        children: [
          // Control Panel
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Item: ${widget.item.userDescription}',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text(
                  'Search Keywords: ${widget.item.searchDescription}',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                SizedBox(height: 16),

                // Test Buttons
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isRunning ? null : _runPackagingSearch,
                        icon: Icon(Icons.inventory_2),
                        label: Text('Test Packaging'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple[600],
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isRunning ? null : _runBarcodeSearch,
                        icon: Icon(Icons.qr_code),
                        label: Text('Test Barcode'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red[600],
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isRunning ? null : _runReverseImageSearch,
                        icon: Icon(Icons.search),
                        label: Text('Test Reverse'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[600],
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 12),

                // Intelligent Analysis Button
                Container(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isRunning ? null : _runIntelligentAnalysis,
                    icon: Icon(Icons.psychology),
                    label: Text('TEST INTELLIGENT ANALYSIS'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal[600],
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),

                if (_isRunning) ...[
                  SizedBox(height: 12),
                  Row(
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 8),
                      Text('Running: $_currentOperation...'),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // Debug Log Display
          Expanded(
            child: _debugLogs.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.bug_report, size: 64, color: Colors.grey[400]),
                  SizedBox(height: 16),
                  Text(
                    'Debug logs will appear here',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Click a test button to start debugging',
                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                  ),
                ],
              ),
            )
                : ListView.builder(
              controller: _scrollController,
              padding: EdgeInsets.all(8),
              itemCount: _debugLogs.length,
              itemBuilder: (context, index) {
                final log = _debugLogs[index];
                return Card(
                  margin: EdgeInsets.only(bottom: 8),
                  child: ExpansionTile(
                    leading: Icon(
                      _getLogLevelIcon(log.level),
                      color: _getLogLevelColor(log.level),
                    ),
                    title: Text(
                      log.operation,
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(log.message),
                        SizedBox(height: 4),
                        Text(
                          '${log.timestamp.hour.toString().padLeft(2, '0')}:${log.timestamp.minute.toString().padLeft(2, '0')}:${log.timestamp.second.toString().padLeft(2, '0')}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                    children: log.data != null
                        ? [
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(16),
                        color: Colors.grey[50],
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Debug Data:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[700],
                              ),
                            ),
                            SizedBox(height: 8),
                            Container(
                              width: double.infinity,
                              padding: EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                border: Border.all(color: Colors.grey[300]!),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                JsonEncoder.withIndent('  ').convert(log.data),
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ]
                        : [],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}