// ========================================
// lib/screens/item_screen.dart
// ========================================
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'dart:io';
import '../models/item_job.dart';
import '../services/storage_service.dart';
import '../services/cloud_services.dart';
import 'image_processing_screen.dart';
import 'analysis_results_screen.dart';
import 'web_scraper_screen.dart';
import 'debug_analysis_screen.dart';

class ItemScreen extends StatefulWidget {
  final ItemJob? existingItem; // null for new item, populated for edit

  const ItemScreen({Key? key, this.existingItem}) : super(key: key);

  @override
  _ItemScreenState createState() => _ItemScreenState();
}

class _ItemScreenState extends State<ItemScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _formKey = GlobalKey<FormState>();

  // Form controllers
  late TextEditingController _userDescriptionController;
  late TextEditingController _searchDescriptionController;
  late TextEditingController _lengthController;
  late TextEditingController _widthController;
  late TextEditingController _heightController;
  late TextEditingController _weightController;
  late TextEditingController _quantityController;

  // Summary controllers (for editing existing summaries)
  late TextEditingController _titleController;
  late TextEditingController _descriptionSummaryController;
  late TextEditingController _estimatedValueController;
  List<TextEditingController> _specControllers = [];
  List<TextEditingController> _featureControllers = [];

  List<Map<String, String>> _labeledImages = [];
  bool _isProcessing = false;
  bool _isEditMode = false;
  bool _hasSummaryData = false;
  bool _hasUnsavedChanges = false;

  // Current item data
  ItemJob? _currentItem;

  @override
  void initState() {
    super.initState();
    _isEditMode = widget.existingItem != null;
    _currentItem = widget.existingItem;

    // Determine if we have summary data
    _hasSummaryData = _currentItem?.analysisResult?['summary'] != null;

    // Initialize tab controller - 3 tabs for new items, 4 for items with summaries
    _tabController = TabController(
        length: _hasSummaryData ? 4 : 3,
        vsync: this
    );

    _initializeControllers();
    _loadExistingData();
  }

  void _initializeControllers() {
    // Basic form controllers
    _userDescriptionController = TextEditingController();
    _searchDescriptionController = TextEditingController();
    _lengthController = TextEditingController();
    _widthController = TextEditingController();
    _heightController = TextEditingController();
    _weightController = TextEditingController();
    _quantityController = TextEditingController(text: '1');

    // Summary controllers (if editing existing summary)
    _titleController = TextEditingController();
    _descriptionSummaryController = TextEditingController();
    _estimatedValueController = TextEditingController(text: '0.00');

    // Add listeners for unsaved changes
    _userDescriptionController.addListener(_onTextChanged);
    _searchDescriptionController.addListener(_onTextChanged);
    _quantityController.addListener(_onTextChanged);
  }

  void _loadExistingData() {
    if (!_isEditMode || _currentItem == null) return;

    final item = _currentItem!;

    // Load basic item data
    _userDescriptionController.text = item.userDescription;
    _searchDescriptionController.text = item.searchDescription;
    _lengthController.text = item.length ?? '';
    _widthController.text = item.width ?? '';
    _heightController.text = item.height ?? '';
    _weightController.text = item.weight ?? '';
    _quantityController.text = item.quantity.toString();

    // Load existing images with classifications
    if (item.imageClassification != null) {
      for (var entry in item.imageClassification!.entries) {
        final label = entry.key;
        final imagePaths = entry.value;
        for (var imagePath in imagePaths) {
          _labeledImages.add({
            'imagePath': imagePath,
            'label': label,
          });
        }
      }
    } else {
      // Fallback: load images without classifications
      for (var imagePath in item.images) {
        _labeledImages.add({
          'imagePath': imagePath,
          'label': 'sales', // Default label
        });
      }
    }

    // Load summary data if available
    if (_hasSummaryData) {
      final summary = item.analysisResult!['summary'] as Map<String, dynamic>;
      final pricing = item.analysisResult!['pricing'] as Map<String, dynamic>?;

      _titleController.text = summary['itemTitle'] ?? item.userDescription;
      _descriptionSummaryController.text = summary['description'] ?? '';
      _estimatedValueController.text = pricing?['estimatedValue']?.toStringAsFixed(2) ?? '0.00';

      // Load specifications
      final specs = summary['specifications'] as List? ?? [];
      for (int i = 0; i < specs.length; i++) {
        _specControllers.add(TextEditingController(text: specs[i]));
      }

      // Load features
      final features = summary['keyFeatures'] as List? ?? [];
      for (int i = 0; i < features.length; i++) {
        _featureControllers.add(TextEditingController(text: features[i]));
      }
    }

    setState(() {});
  }

  void _onTextChanged() {
    if (!_hasUnsavedChanges) {
      setState(() {
        _hasUnsavedChanges = true;
      });
    }
  }

  Color _getLabelColor(String label) {
    switch (label) {
      case 'sales':
        return Colors.green;
      case 'id':
        return Colors.blue;
      case 'markings':
        return Colors.orange;
      case 'packaging':
        return Colors.purple;
      case 'barcode':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Future<void> _captureImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.camera);

    if (pickedFile != null) {
      final result = await Navigator.push<Map<String, dynamic>>(
        context,
        MaterialPageRoute(
          builder: (context) => ImageProcessingScreen(
            imagePath: pickedFile.path,
            currentLabel: 'sales',
          ),
        ),
      );

      if (result != null) {
        setState(() {
          _labeledImages.add({
            'imagePath': result['imagePath'],
            'label': result['label'],
          });
          _hasUnsavedChanges = true;
        });
      }
    }
  }

  Future<void> _editImageClassification(int index) async {
    final currentImage = _labeledImages[index];
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) => ImageProcessingScreen(
          imagePath: currentImage['imagePath']!,
          currentLabel: currentImage['label'],
        ),
      ),
    );

    if (result != null) {
      setState(() {
        _labeledImages[index] = {
          'imagePath': result['imagePath'],
          'label': result['label'],
        };
        _hasUnsavedChanges = true;
      });
    }
  }

  void _removeImage(int index) {
    setState(() {
      _labeledImages.removeAt(index);
      _hasUnsavedChanges = true;
    });
  }

  Future<void> _runPackagingSearch() async {
    final packagingImages = _labeledImages
        .where((img) => img['label'] == 'packaging')
        .map((img) => img['imagePath'] as String)
        .toList();

    if (packagingImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No packaging images available'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Text('Analyzing packaging images...'),
          ],
        ),
      ),
    );

    try {
      final results = await CloudServices.searchPackaging(packagingImages);
      Navigator.pop(context); // Close loading dialog
      _showSearchResults('Packaging Analysis', results);
    } catch (e) {
      Navigator.pop(context); // Close loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error analyzing packaging: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _runMarkingsSearch() async {
    final markingImages = _labeledImages
        .where((img) => img['label'] == 'markings')
        .map((img) => img['imagePath'] as String)
        .toList();

    if (markingImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No marking images available'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Text('Analyzing markings...'),
          ],
        ),
      ),
    );

    try {
      final results = await CloudServices.searchMarkings(markingImages);
      Navigator.pop(context); // Close loading dialog

      // Enhance markings results with search candidates
      if (results['brands'] != null && (results['brands'] as List).isNotEmpty) {
        List<Map<String, dynamic>> candidates = [];

        for (String brand in (results['brands'] as List).take(3)) {
          candidates.add({
            'title': 'Search eBay for $brand products',
            'url': 'https://www.ebay.com/sch/i.html?_nkw=${Uri.encodeComponent(brand)}',
            'confidence': 0.7,
            'type': 'brand_search',
            'site': 'eBay',
            'searchTerm': brand,
          });
        }

        results['candidates'] = candidates;
      }

      _showSearchResults('Markings Analysis', results);
    } catch (e) {
      Navigator.pop(context); // Close loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error analyzing markings: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _runReverseImageSearch() async {
    final idImages = _labeledImages
        .where((img) => img['label'] == 'id')
        .map((img) => img['imagePath'] as String)
        .toList();

    if (idImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No ID images available'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Text('Searching with image recognition...'),
          ],
        ),
      ),
    );

    try {
      final results = await CloudServices.reverseImageSearchWithCandidates(idImages);
      Navigator.pop(context); // Close loading dialog
      _showSearchResults('Reverse Image Search', results);
    } catch (e) {
      Navigator.pop(context); // Close loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error in reverse search: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _runBarcodeSearch() async {
    final barcodeImages = _labeledImages
        .where((img) => img['label'] == 'barcode')
        .map((img) => img['imagePath'] as String)
        .toList();

    if (barcodeImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No barcode images available'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Text('Scanning barcodes...'),
          ],
        ),
      ),
    );

    try {
      final barcodeResults = await CloudServices.detectBarcodesAndUPCs(barcodeImages);
      Navigator.pop(context); // Close loading dialog

      List<Map<String, dynamic>> candidates = [];

      // Create candidates from detected barcodes
      final allCodes = [...barcodeResults['barcodes']!, ...barcodeResults['upcs']!];

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

      final results = {
        'confidence': allCodes.isNotEmpty ? 0.9 : 0.1,
        'barcodes': barcodeResults['barcodes'],
        'upcs': barcodeResults['upcs'],
        'candidates': candidates,
        'text': 'Found ${allCodes.length} barcodes/UPCs',
      };

      _showSearchResults('Barcode Scan Results', results);
    } catch (e) {
      Navigator.pop(context); // Close loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error scanning barcodes: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showSearchResults(String title, Map<String, dynamic> results) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Confidence: ${(results['confidence'] * 100).toInt()}% • Found ${(results['candidates'] as List?)?.length ?? 0} candidates',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.close),
                    ),
                  ],
                ),
              ),

              Divider(),

              // Content
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Extracted data summary
                      if (results['text'] != null && results['text'].toString().isNotEmpty) ...[
                        _buildSectionHeader('Extracted Text', Icons.text_fields),
                        Card(
                          child: Padding(
                            padding: EdgeInsets.all(12),
                            child: Text(
                              results['text'].toString().length > 200
                                  ? '${results['text'].toString().substring(0, 200)}...'
                                  : results['text'].toString(),
                              style: TextStyle(fontSize: 13),
                            ),
                          ),
                        ),
                        SizedBox(height: 20),
                      ],

                      // Products found
                      if (results['products'] != null && (results['products'] as List).isNotEmpty) ...[
                        _buildSectionHeader('Products Identified', Icons.inventory),
                        ...List.generate(
                          (results['products'] as List).length,
                              (index) => Card(
                            child: ListTile(
                              leading: Icon(Icons.check_circle, color: Colors.green),
                              title: Text(results['products'][index]),
                              dense: true,
                            ),
                          ),
                        ),
                        SizedBox(height: 20),
                      ],

                      // Candidate sources with USE buttons
                      if (results['candidates'] != null && (results['candidates'] as List).isNotEmpty) ...[
                        _buildSectionHeader('Web Sources to Review', Icons.public),
                        ...List.generate(
                          (results['candidates'] as List).length,
                              (index) => _buildCandidateCard(
                            (results['candidates'] as List)[index],
                            context,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.blue[700]),
          SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.blue[700],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCandidateCard(Map<String, dynamic> candidate, BuildContext context) {
    final confidence = candidate['confidence'] ?? 0.0;
    final title = candidate['title'] ?? 'Unknown Source';
    final site = candidate['site'] ?? 'Unknown';
    final type = candidate['type'] ?? 'unknown';
    final url = candidate['url'] ?? '';

    Color confidenceColor = confidence > 0.7 ? Colors.green :
    confidence > 0.4 ? Colors.orange : Colors.red;

    IconData typeIcon;
    Color cardColor;

    switch (type) {
      case 'product_page':
        typeIcon = Icons.shopping_bag;
        cardColor = Colors.blue;
        break;
      case 'barcode_lookup':
        typeIcon = Icons.qr_code;
        cardColor = Colors.green;
        break;
      case 'brand_model_search':
        typeIcon = Icons.search;
        cardColor = Colors.purple;
        break;
      case 'similar_image':
        typeIcon = Icons.image;
        cardColor = Colors.orange;
        break;
      default:
        typeIcon = Icons.link;
        cardColor = Colors.grey;
    }

    return Card(
      margin: EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: cardColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: cardColor.withOpacity(0.3)),
                  ),
                  child: Icon(typeIcon, size: 20, color: cardColor),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: confidenceColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: confidenceColor.withOpacity(0.3)),
                            ),
                            child: Text(
                              '${(confidence * 100).toInt()}%',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: confidenceColor,
                              ),
                            ),
                          ),
                          SizedBox(width: 8),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              site,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[700],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context); // Close the modal first
                      _openWebScraper(url, title);
                    },
                    icon: Icon(Icons.public, size: 16),
                    label: Text('VIEW SITE'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blue[700],
                      side: BorderSide(color: Colors.blue[300]!),
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context); // Close the modal first
                      _openWebScraperWithAutoScrape(url, title);
                    },
                    icon: Icon(Icons.download, size: 16),
                    label: Text('USE DATA'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[600],
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _openWebScraper(String url, String title) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WebScraperScreen(
          url: url,
          title: title,
          onDataScrapped: (scrapedData) {
            _addScrapedData(scrapedData);
          },
        ),
      ),
    );
  }

  void _openWebScraperWithAutoScrape(String url, String title) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WebScraperScreen(
          url: url,
          title: title,
          onDataScrapped: (scrapedData) {
            _addScrapedData(scrapedData);
          },
        ),
      ),
    );
  }

  void _addScrapedData(Map<String, dynamic> scrapedData) {
    if (_currentItem == null) return;

    // Add scraped data to item's analysis result
    Map<String, dynamic> updatedAnalysisResult = Map.from(_currentItem!.analysisResult ?? {});

    if (!updatedAnalysisResult.containsKey('scrapedSources')) {
      updatedAnalysisResult['scrapedSources'] = [];
    }

    updatedAnalysisResult['scrapedSources'].add({
      'timestamp': DateTime.now().toIso8601String(),
      'data': scrapedData,
    });

    final updatedItem = _currentItem!.copyWith(analysisResult: updatedAnalysisResult);
    StorageService.saveJob(updatedItem);

    setState(() {
      _currentItem = updatedItem;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✅ Data scraped: ${scrapedData['title'] ?? 'Unknown source'}'),
        backgroundColor: Colors.green,
        action: SnackBarAction(
          label: 'VIEW',
          textColor: Colors.white,
          onPressed: () {
            _showScrapedDataSummary(scrapedData);
          },
        ),
      ),
    );
  }

  void _showScrapedDataSummary(Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Scraped Data Summary'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (data['title'] != null) ...[
                Text('Title:', style: TextStyle(fontWeight: FontWeight.bold)),
                Text(data['title']),
                SizedBox(height: 8),
              ],
              if (data['prices'] != null && (data['prices'] as List).isNotEmpty) ...[
                Text('Prices Found:', style: TextStyle(fontWeight: FontWeight.bold)),
                Text('${(data['prices'] as List).length} prices'),
                SizedBox(height: 8),
              ],
              if (data['specifications'] != null && (data['specifications'] as List).isNotEmpty) ...[
                Text('Specifications:', style: TextStyle(fontWeight: FontWeight.bold)),
                Text('${(data['specifications'] as List).length} specs'),
                SizedBox(height: 8),
              ],
              if (data['dataQuality'] != null) ...[
                Text('Data Quality:', style: TextStyle(fontWeight: FontWeight.bold)),
                Text(data['dataQuality']['overallQuality'] ?? 'Unknown'),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  void _openDebugAnalysis() {
    // Save current item first if there are unsaved changes
    if (_hasUnsavedChanges) {
      _saveItem().then((_) {
        if (_currentItem != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DebugAnalysisScreen(item: _currentItem!),
            ),
          );
        }
      });
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => DebugAnalysisScreen(item: _currentItem ?? widget.existingItem!),
        ),
      );
    }
  }

  Future<void> _saveItem() async {
    if (!_formKey.currentState!.validate() || _labeledImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please fill all fields and add at least one image')),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      // Create image classification map
      Map<String, List<String>> imageClassification = {};
      for (var img in _labeledImages) {
        final label = img['label']!;
        final imagePath = img['imagePath']!;

        if (!imageClassification.containsKey(label)) {
          imageClassification[label] = [];
        }
        imageClassification[label]!.add(imagePath);
      }

      ItemJob item;

      if (_isEditMode && _currentItem != null) {
        // Update existing item
        Map<String, dynamic>? updatedAnalysisResult;

        // Update summary if we have summary data
        if (_hasSummaryData) {
          updatedAnalysisResult = Map<String, dynamic>.from(_currentItem!.analysisResult ?? {});

          final updatedSummary = {
            ...updatedAnalysisResult['summary'] ?? {},
            'itemTitle': _titleController.text.trim(),
            'description': _descriptionSummaryController.text.trim(),
            'specifications': _specControllers.map((c) => c.text.trim()).where((s) => s.isNotEmpty).toList(),
            'keyFeatures': _featureControllers.map((c) => c.text.trim()).where((f) => f.isNotEmpty).toList(),
            'lastEditedAt': DateTime.now().toIso8601String(),
            'userEdited': true,
          };

          final updatedPricing = {
            ...updatedAnalysisResult['pricing'] ?? {},
            'estimatedValue': double.tryParse(_estimatedValueController.text) ?? 0.0,
            'lastEditedAt': DateTime.now().toIso8601String(),
            'userEdited': true,
          };

          updatedAnalysisResult['summary'] = updatedSummary;
          updatedAnalysisResult['pricing'] = updatedPricing;
        }

        item = _currentItem!.copyWith(
          userDescription: _userDescriptionController.text.trim(),
          searchDescription: _searchDescriptionController.text.trim(),
          length: _lengthController.text.trim().isEmpty ? null : _lengthController.text.trim(),
          width: _widthController.text.trim().isEmpty ? null : _widthController.text.trim(),
          height: _heightController.text.trim().isEmpty ? null : _heightController.text.trim(),
          weight: _weightController.text.trim().isEmpty ? null : _weightController.text.trim(),
          quantity: int.tryParse(_quantityController.text.trim()) ?? 1,
          images: _labeledImages.map((img) => img['imagePath']!).toList(),
          imageClassification: imageClassification,
          analysisResult: updatedAnalysisResult,
        );
      } else {
        // Create new item
        item = ItemJob(
          id: Uuid().v4(),
          userDescription: _userDescriptionController.text.trim(),
          searchDescription: _searchDescriptionController.text.trim(),
          length: _lengthController.text.trim().isEmpty ? null : _lengthController.text.trim(),
          width: _widthController.text.trim().isEmpty ? null : _widthController.text.trim(),
          height: _heightController.text.trim().isEmpty ? null : _heightController.text.trim(),
          weight: _weightController.text.trim().isEmpty ? null : _weightController.text.trim(),
          quantity: int.tryParse(_quantityController.text.trim()) ?? 1,
          images: _labeledImages.map((img) => img['imagePath']!).toList(),
          createdAt: DateTime.now(),
          imageClassification: imageClassification,
        );
      }

      await StorageService.saveJob(item);

      setState(() {
        _hasUnsavedChanges = false;
        _currentItem = item;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_isEditMode ? 'Item updated successfully' : 'Item created successfully')),
      );

      // Navigate to analysis results if this is a new item
      if (!_isEditMode) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => AnalysisResultsScreen(item: item),
          ),
        );
      }

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving item: $e')),
      );
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _regenerateSummary() async {
    if (_currentItem == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Regenerate Summary'),
        content: Text('This will regenerate the summary from source data. Continue?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Regenerate'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isProcessing = true);

    try {
      // This would call the summary generation service
      // For now, just show a message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Summary regeneration coming soon')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error regenerating summary: $e')),
      );
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  void _addSpecification() {
    setState(() {
      _specControllers.add(TextEditingController());
      _hasUnsavedChanges = true;
    });
  }

  void _removeSpecification(int index) {
    setState(() {
      _specControllers[index].dispose();
      _specControllers.removeAt(index);
      _hasUnsavedChanges = true;
    });
  }

  void _addFeature() {
    setState(() {
      _featureControllers.add(TextEditingController());
      _hasUnsavedChanges = true;
    });
  }

  void _removeFeature(int index) {
    setState(() {
      _featureControllers[index].dispose();
      _featureControllers.removeAt(index);
      _hasUnsavedChanges = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'Edit Item' : 'Add New Item'),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
        actions: [
          if (_hasUnsavedChanges)
            TextButton(
              onPressed: _isProcessing ? null : _saveItem,
              child: Text('SAVE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          if (_isEditMode && _hasSummaryData)
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'regenerate') {
                  _regenerateSummary();
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'regenerate',
                  child: Row(children: [Icon(Icons.refresh), SizedBox(width: 8), Text('Regenerate Summary')]),
                ),
              ],
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(text: 'Item Info'),
            Tab(text: 'Images'),
            Tab(text: 'Actions'),
            if (_hasSummaryData) Tab(text: 'Summary'),
          ],
        ),
      ),
      body: _isProcessing
          ? Center(child: CircularProgressIndicator())
          : TabBarView(
        controller: _tabController,
        children: [
          _buildItemInfoTab(),
          _buildImagesTab(),
          _buildActionsTab(),
          if (_hasSummaryData) _buildSummaryTab(),
        ],
      ),
    );
  }

  Widget _buildItemInfoTab() {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Item Description
            Text('Item Description', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            SizedBox(height: 8),
            TextFormField(
              controller: _userDescriptionController,
              decoration: InputDecoration(
                hintText: 'Brief description of the item',
                border: OutlineInputBorder(),
              ),
              validator: (value) => value?.trim().isEmpty == true ? 'Please enter a description' : null,
              maxLines: 2,
            ),

            SizedBox(height: 20),

            // Search Description
            Text('Search Keywords', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            SizedBox(height: 8),
            TextFormField(
              controller: _searchDescriptionController,
              decoration: InputDecoration(
                hintText: 'Keywords to guide search (brand, model, etc.)',
                border: OutlineInputBorder(),
              ),
              validator: (value) => value?.trim().isEmpty == true ? 'Please enter search keywords' : null,
              maxLines: 2,
            ),

            SizedBox(height: 20),

            // Quantity
            Text('Quantity', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            SizedBox(height: 8),
            TextFormField(
              controller: _quantityController,
              decoration: InputDecoration(hintText: '1', border: OutlineInputBorder()),
              keyboardType: TextInputType.number,
              validator: (value) {
                final qty = int.tryParse(value?.trim() ?? '');
                return (qty == null || qty < 1) ? 'Please enter a valid quantity' : null;
              },
            ),

            SizedBox(height: 20),

            // Measurements
            Text('Measurements (Optional)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _lengthController,
                    decoration: InputDecoration(labelText: 'Length', hintText: '12"', border: OutlineInputBorder()),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _widthController,
                    decoration: InputDecoration(labelText: 'Width', hintText: '8"', border: OutlineInputBorder()),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _heightController,
                    decoration: InputDecoration(labelText: 'Height', hintText: '6"', border: OutlineInputBorder()),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _weightController,
                    decoration: InputDecoration(labelText: 'Weight', hintText: '2.5 lbs', border: OutlineInputBorder()),
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagesTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Add Image Button
          Container(
            width: double.infinity,
            height: 60,
            child: OutlinedButton.icon(
              onPressed: _captureImage,
              icon: Icon(Icons.add_a_photo),
              label: Text('Add Image'),
              style: OutlinedButton.styleFrom(side: BorderSide(color: Colors.blue[600]!)),
            ),
          ),

          SizedBox(height: 16),

          if (_labeledImages.isEmpty)
            Center(
              child: Column(
                children: [
                  Icon(Icons.add_photo_alternate, size: 64, color: Colors.grey[400]),
                  SizedBox(height: 16),
                  Text('No images added yet', style: TextStyle(color: Colors.grey[600])),
                ],
              ),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 1,
              ),
              itemCount: _labeledImages.length,
              itemBuilder: (context, index) {
                final imageData = _labeledImages[index];
                final imagePath = imageData['imagePath']!;
                final label = imageData['label']!;

                return Stack(
                  children: [
                    GestureDetector(
                      onTap: () => _editImageClassification(index),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _getLabelColor(label), width: 3),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(5),
                          child: Image.file(
                            File(imagePath),
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                          ),
                        ),
                      ),
                    ),
                    // Label
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getLabelColor(label),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          label.toUpperCase(),
                          style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    // Edit icon
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: Container(
                        padding: EdgeInsets.all(4),
                        decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(4)),
                        child: Icon(Icons.edit, color: Colors.white, size: 16),
                      ),
                    ),
                    // Remove button
                    Positioned(
                      top: 8,
                      right: 8,
                      child: GestureDetector(
                        onTap: () => _removeImage(index),
                        child: Container(
                          padding: EdgeInsets.all(4),
                          decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(4)),
                          child: Icon(Icons.close, color: Colors.white, size: 16),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildActionsTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_labeledImages.isEmpty)
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  children: [
                    Icon(Icons.info_outline, size: 48, color: Colors.grey[400]),
                    SizedBox(height: 16),
                    Text(
                      'Add images first',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Search functions will be available once you add and classify images.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            Text(
              'Quick Searches',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),

            // Search buttons grid
            GridView.count(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.5,
              children: [
                _buildSearchButton(
                  'Packaging\nSearch',
                  Icons.inventory_2,
                  Colors.purple,
                  _runPackagingSearch,
                  _labeledImages.any((img) => img['label'] == 'packaging'),
                ),
                _buildSearchButton(
                  'Markings\nSearch',
                  Icons.label,
                  Colors.orange,
                  _runMarkingsSearch,
                  _labeledImages.any((img) => img['label'] == 'markings'),
                ),
                _buildSearchButton(
                  'Reverse\nSearch',
                  Icons.search,
                  Colors.blue,
                  _runReverseImageSearch,
                  _labeledImages.any((img) => img['label'] == 'id'),
                ),
                _buildSearchButton(
                  'Barcode\nScan',
                  Icons.qr_code,
                  Colors.red,
                  _runBarcodeSearch,
                  _labeledImages.any((img) => img['label'] == 'barcode'),
                ),
              ],
            ),

            SizedBox(height: 24),

            // Debug Analysis Section
            Card(
              color: Colors.amber[50],
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.bug_report, color: Colors.amber[700]),
                        SizedBox(width: 8),
                        Text(
                          'Debug & Testing',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.amber[700],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Test individual search functions and view detailed logs',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _openDebugAnalysis(),
                        icon: Icon(Icons.science),
                        label: Text('OPEN DEBUG ANALYSIS'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber[600],
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 16),

            // Image classification summary
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Image Classification Summary',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 12),
                    ..._getImageClassificationSummary().entries.map((entry) {
                      return Padding(
                        padding: EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: _getLabelColor(entry.key),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            SizedBox(width: 8),
                            Text('${entry.key.toUpperCase()}: ${entry.value} images'),
                          ],
                        ),
                      );
                    }).toList(),
                  ],
                ),
              ),
            ),

            // Show scraped data if available
            if (_currentItem?.analysisResult?['scrapedSources'] != null) ...[
              SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Scraped Data Sources',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 8),
                      Text(
                        '${(_currentItem!.analysisResult!['scrapedSources'] as List).length} data sources collected',
                        style: TextStyle(color: Colors.green[700]),
                      ),
                      SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: () {
                          // TODO: Implement analyze function
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('AI Analysis coming soon!')),
                          );
                        },
                        icon: Icon(Icons.auto_awesome),
                        label: Text('ANALYZE WITH AI'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple[600],
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],

          SizedBox(height: 24),

          // Save button
          Container(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isProcessing ? null : _saveItem,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[600],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: _isProcessing
                  ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  SizedBox(width: 12),
                  Text(_isEditMode ? 'Updating Item...' : 'Creating Item...'),
                ],
              )
                  : Text(
                _isEditMode ? 'Update Item' : 'Create Item',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Text('Item Title', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          SizedBox(height: 8),
          TextFormField(
            controller: _titleController,
            decoration: InputDecoration(border: OutlineInputBorder()),
            maxLines: 2,
            onChanged: (_) => _onTextChanged(),
          ),

          SizedBox(height: 20),

          // Description
          Text('Description', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          SizedBox(height: 8),
          TextFormField(
            controller: _descriptionSummaryController,
            decoration: InputDecoration(border: OutlineInputBorder()),
            maxLines: 8,
            onChanged: (_) => _onTextChanged(),
          ),

          SizedBox(height: 20),

          // Estimated Value
          Text('Estimated Value', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          SizedBox(height: 8),
          TextFormField(
            controller: _estimatedValueController,
            decoration: InputDecoration(
                border: OutlineInputBorder(),
                prefixText: '\$',
            ),
            keyboardType: TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => _onTextChanged(),
          ),

          SizedBox(height: 20),

          // Specifications
          Row(
            children: [
              Text('Specifications', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Spacer(),
              IconButton(onPressed: _addSpecification, icon: Icon(Icons.add)),
            ],
          ),
          SizedBox(height: 8),

          if (_specControllers.isEmpty)
            Center(child: Text('No specifications yet'))
          else
            ...List.generate(_specControllers.length, (index) {
              return Container(
                margin: EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _specControllers[index],
                        decoration: InputDecoration(
                          border: OutlineInputBorder(),
                          prefixText: '• ',
                        ),
                        maxLines: 2,
                        onChanged: (_) => _onTextChanged(),
                      ),
                    ),
                    IconButton(
                      onPressed: () => _removeSpecification(index),
                      icon: Icon(Icons.remove_circle, color: Colors.red),
                    ),
                  ],
                ),
              );
            }),

          SizedBox(height: 20),

          // Key Features
          Row(
            children: [
              Text('Key Features', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Spacer(),
              IconButton(onPressed: _addFeature, icon: Icon(Icons.add)),
            ],
          ),
          SizedBox(height: 8),

          if (_featureControllers.isEmpty)
            Center(child: Text('No features yet'))
          else
            ...List.generate(_featureControllers.length, (index) {
              return Container(
                margin: EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _featureControllers[index],
                        decoration: InputDecoration(
                          border: OutlineInputBorder(),
                          prefixText: '• ',
                        ),
                        maxLines: 2,
                        onChanged: (_) => _onTextChanged(),
                      ),
                    ),
                    IconButton(
                      onPressed: () => _removeFeature(index),
                      icon: Icon(Icons.remove_circle, color: Colors.red),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildSearchButton(String title, IconData icon, Color color, VoidCallback onPressed, bool hasRequiredImages) {
    return ElevatedButton(
      onPressed: hasRequiredImages ? onPressed : null,
      style: ElevatedButton.styleFrom(
        backgroundColor: hasRequiredImages ? color : Colors.grey[300],
        foregroundColor: hasRequiredImages ? Colors.white : Colors.grey[600],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 24),
          SizedBox(height: 8),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Map<String, int> _getImageClassificationSummary() {
    Map<String, int> summary = {};
    for (var image in _labeledImages) {
      final label = image['label']!;
      summary[label] = (summary[label] ?? 0) + 1;
    }
    return summary;
  }

  void _disposeControllers() {
    _userDescriptionController.dispose();
    _searchDescriptionController.dispose();
    _lengthController.dispose();
    _widthController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _quantityController.dispose();
    _titleController.dispose();
    _descriptionSummaryController.dispose();
    _estimatedValueController.dispose();

    for (var controller in _specControllers) {
      controller.dispose();
    }
    for (var controller in _featureControllers) {
      controller.dispose();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _disposeControllers();
    super.dispose();
  }
}