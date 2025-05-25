// lib/screens/enhanced_capture_screen.dart
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class EnhancedCaptureScreen extends StatefulWidget {
  const EnhancedCaptureScreen({Key? key}) : super(key: key);

  @override
  _EnhancedCaptureScreenState createState() => _EnhancedCaptureScreenState();
}

class _EnhancedCaptureScreenState extends State<EnhancedCaptureScreen> {
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _searchNotesController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  // Image storage for all 5 categories
  File? _barcodeImage;
  File? _markingsImage;
  File? _packagingImage;
  File? _searchImage;
  File? _salesImage;

  // Analysis results for each category
  Map<String, String> _barcodeResults = {};
  Map<String, String> _markingsResults = {};
  Map<String, String> _packagingResults = {};
  Map<String, String> _searchResults = {};
  Map<String, String> _salesResults = {};

  // Conflict detection
  List<String> _detectedConflicts = [];
  bool _isAnalyzing = false;

  @override
  void dispose() {
    _searchNotesController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _captureImage(String category) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          switch (category) {
            case 'barcode':
              _barcodeImage = File(image.path);
              break;
            case 'markings':
              _markingsImage = File(image.path);
              break;
            case 'packaging':
              _packagingImage = File(image.path);
              break;
            case 'search':
              _searchImage = File(image.path);
              break;
            case 'sales':
              _salesImage = File(image.path);
              break;
          }
        });

        await _analyzeImage(category);
      }
    } catch (e) {
      _showSnackBar('Failed to capture image: $e', Colors.red);
    }
  }

  Future<void> _analyzeImage(String category) async {
    setState(() {
      _isAnalyzing = true;
    });

    // Simulate analysis delay
    await Future.delayed(Duration(seconds: 2));

    setState(() {
      _isAnalyzing = false;

      switch (category) {
        case 'barcode':
          _barcodeResults = {
            'upc': '012345678901',
            'product': 'Wireless Bluetooth Headphones',
            'brand': 'TechAudio',
            'category': 'Electronics',
          };
          break;

        case 'markings':
          _markingsResults = {
            'model': 'WH-1000XM4',
            'serial': 'SN: 4567890123',
            'manufacturer': 'TechAudio Corp',
            'origin': 'Made in China',
          };
          break;

        case 'packaging':
          _packagingResults = {
            'product': 'TechAudio Premium Wireless Headphones WH-1000XM4',
            'brand': 'TechAudio',
            'model': 'WH-1000XM4',
            'features': 'Noise Canceling, 30hr Battery, Quick Charge',
            'manufacturer': 'TechAudio Corporation',
            'weight': '254g',
          };
          break;

        case 'search':
          _searchResults = {
            'description': 'Black over-ear wireless headphones',
            'condition': 'Appears new/excellent',
            'color': 'Matte Black',
            'accessories': 'Carrying case, charging cable',
          };
          break;

        case 'sales':
          _salesResults = {
            'quality': 'High resolution, suitable for listings',
            'lighting': 'Good lighting, clear details',
            'background': 'Clean white background',
            'composition': 'Product well-centered',
          };
          break;
      }

      _detectConflicts();
    });
  }

  void _detectConflicts() {
    List<String> conflicts = [];

    // Check brand conflicts
    String? barcodeBrand = _barcodeResults['brand'];
    String? packagingBrand = _packagingResults['brand'];
    if (barcodeBrand != null && packagingBrand != null && barcodeBrand != packagingBrand) {
      conflicts.add('Brand mismatch: Barcode shows "$barcodeBrand" but packaging shows "$packagingBrand"');
    }

    // Check model conflicts
    String? markingsModel = _markingsResults['model'];
    String? packagingModel = _packagingResults['model'];
    if (markingsModel != null && packagingModel != null && markingsModel != packagingModel) {
      conflicts.add('Model mismatch: Markings show "$markingsModel" but packaging shows "$packagingModel"');
    }

    // Check product name conflicts
    String? barcodeProduct = _barcodeResults['product'];
    String? packagingProduct = _packagingResults['product'];
    if (barcodeProduct != null && packagingProduct != null) {
      if (!packagingProduct.toLowerCase().contains(barcodeProduct.toLowerCase().split(' ').first)) {
        conflicts.add('Product name mismatch between barcode and packaging');
      }
    }

    setState(() {
      _detectedConflicts = conflicts;
    });
  }

  void _searchUsingResults() {
    if (!_hasUsefulResults() && _searchNotesController.text.isEmpty) {
      _showSnackBar('Please capture at least one image or add search notes', Colors.orange);
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EnhancedResultsScreen(
          barcodeResults: _barcodeResults,
          markingsResults: _markingsResults,
          packagingResults: _packagingResults,
          searchResults: _searchResults,
          salesResults: _salesResults,
          searchNotes: _searchNotesController.text,
          description: _descriptionController.text,
          conflicts: _detectedConflicts,
        ),
      ),
    );
  }

  bool _hasUsefulResults() {
    return _barcodeResults.isNotEmpty ||
        _markingsResults.isNotEmpty ||
        _packagingResults.isNotEmpty ||
        _searchResults.isNotEmpty ||
        _salesResults.isNotEmpty;
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
      ),
    );
  }

  void _clearAll() {
    setState(() {
      _barcodeImage = null;
      _markingsImage = null;
      _packagingImage = null;
      _searchImage = null;
      _salesImage = null;
      _barcodeResults.clear();
      _markingsResults.clear();
      _packagingResults.clear();
      _searchResults.clear();
      _salesResults.clear();
      _detectedConflicts.clear();
      _searchNotesController.clear();
      _descriptionController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Enhanced Product Capture'),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.clear_all),
            onPressed: _clearAll,
            tooltip: 'Clear All',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // User Input Section
            _buildUserInputSection(),

            SizedBox(height: 24),

            // Image Capture Categories
            _buildImageCategoriesSection(),

            SizedBox(height: 24),

            // Conflicts Warning
            if (_detectedConflicts.isNotEmpty) _buildConflictsSection(),

            // Results Summary
            if (_hasUsefulResults()) _buildResultsSummary(),

            SizedBox(height: 24),

            // Search Button
            _buildSearchButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildUserInputSection() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Product Information',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blue[700],
              ),
            ),
            SizedBox(height: 16),
            TextField(
              controller: _searchNotesController,
              decoration: InputDecoration(
                labelText: 'Search Notes',
                hintText: 'Keywords, part numbers, model info...',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.search),
              ),
              maxLines: 2,
            ),
            SizedBox(height: 16),
            TextField(
              controller: _descriptionController,
              decoration: InputDecoration(
                labelText: 'Description Notes',
                hintText: 'Condition, features, notable details...',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.description),
              ),
              maxLines: 3,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageCategoriesSection() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Image Identification Categories',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blue[700],
              ),
            ),
            SizedBox(height: 16),

            _buildImageCaptureCard(
              'Barcode/QR Code',
              'barcode',
              _barcodeImage,
              _barcodeResults,
              Icons.qr_code,
              Colors.green,
              'UPC codes, QR codes, product identifiers',
            ),

            SizedBox(height: 12),

            _buildImageCaptureCard(
              'Product Markings',
              'markings',
              _markingsImage,
              _markingsResults,
              Icons.text_fields,
              Colors.orange,
              'Model numbers, serial numbers, manufacturer marks',
            ),

            SizedBox(height: 12),

            _buildImageCaptureCard(
              'Packaging/Labels ⭐',
              'packaging',
              _packagingImage,
              _packagingResults,
              Icons.inventory_2,
              Colors.purple,
              'PRIORITY: Package text often contains most complete info',
            ),

            SizedBox(height: 12),

            _buildImageCaptureCard(
              'Search Image',
              'search',
              _searchImage,
              _searchResults,
              Icons.image_search,
              Colors.blue,
              'General product photo for reverse image search',
            ),

            SizedBox(height: 12),

            _buildImageCaptureCard(
              'Sales Image',
              'sales',
              _salesImage,
              _salesResults,
              Icons.sell,
              Colors.indigo,
              'High-quality photo for marketplace listings',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageCaptureCard(
      String title,
      String category,
      File? image,
      Map<String, String> results,
      IconData icon,
      Color color,
      String description,
      ) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: color.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 24),
                SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: color,
                        ),
                      ),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _isAnalyzing ? null : () => _captureImage(category),
                  icon: Icon(Icons.camera_alt, size: 18),
                  label: Text('Capture'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ],
            ),

            if (image != null) ...[
              SizedBox(height: 12),
              Container(
                height: 80,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    image,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ],

            if (results.isNotEmpty) ...[
              SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Analysis Results:',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                    SizedBox(height: 8),
                    ...results.entries.take(3).map((entry) => Text(
                      '${entry.key.toUpperCase()}: ${entry.value}',
                      style: TextStyle(fontSize: 11),
                    )).toList(),
                    if (results.length > 3)
                      Text(
                        '... and ${results.length - 3} more',
                        style: TextStyle(
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                          color: Colors.grey[600],
                        ),
                      ),
                  ],
                ),
              ),
            ],

            if (_isAnalyzing && image != null) ...[
              SizedBox(height: 12),
              Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                    ),
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Analyzing image...',
                    style: TextStyle(color: color, fontSize: 12),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildConflictsSection() {
    return Card(
      elevation: 4,
      color: Colors.red[50],
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning, color: Colors.red[700], size: 24),
                SizedBox(width: 8),
                Text(
                  'Data Conflicts Detected',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.red[700],
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            ..._detectedConflicts.map((conflict) => Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.error_outline, size: 16, color: Colors.red[600]),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      conflict,
                      style: TextStyle(
                        color: Colors.red[700],
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            )).toList(),
            SizedBox(height: 8),
            Text(
              'Note: Packaging OCR is typically most reliable source',
              style: TextStyle(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: Colors.red[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsSummary() {
    return Card(
      elevation: 4,
      color: Colors.blue[50],
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.summarize, color: Colors.blue[700]),
                SizedBox(width: 8),
                Text(
                  'Identification Summary',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[700],
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),

            // Show packaging results first (highest priority)
            if (_packagingResults.isNotEmpty) ...[
              Text(
                'PRIMARY (Packaging OCR):',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.purple[700],
                  fontSize: 14,
                ),
              ),
              Text(
                _packagingResults['product'] ?? 'Product name detected',
                style: TextStyle(fontSize: 13),
              ),
              if (_packagingResults['brand'] != null)
                Text('Brand: ${_packagingResults['brand']}', style: TextStyle(fontSize: 12)),
              if (_packagingResults['model'] != null)
                Text('Model: ${_packagingResults['model']}', style: TextStyle(fontSize: 12)),
              SizedBox(height: 8),
            ],

            // Other sources
            if (_barcodeResults.isNotEmpty)
              Text('BARCODE: ${_barcodeResults['product'] ?? _barcodeResults['upc']}',
                  style: TextStyle(fontSize: 12)),
            if (_markingsResults.isNotEmpty)
              Text('MARKINGS: ${_markingsResults['model'] ?? _markingsResults['serial']}',
                  style: TextStyle(fontSize: 12)),

            SizedBox(height: 12),

            // Search recommendation
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green[300]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.lightbulb, color: Colors.green[700], size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _getSearchRecommendation(),
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.green[700],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getSearchRecommendation() {
    bool hasProductName = _packagingResults['product']?.isNotEmpty ?? false ||
        _barcodeResults['product']?.isNotEmpty ?? false;
    bool hasModel = _packagingResults['model']?.isNotEmpty ?? false ||
        _markingsResults['model']?.isNotEmpty ?? false;

    if (hasProductName && hasModel) {
      return 'Strong product identification found. Direct search recommended.';
    } else if (hasProductName || hasModel) {
      return 'Good product data found. Try direct search first, reverse image search as backup.';
    } else {
      return 'Limited text data. Reverse image search recommended.';
    }
  }

  Widget _buildSearchButton() {
    bool canSearch = _hasUsefulResults() || _searchNotesController.text.isNotEmpty;

    return ElevatedButton.icon(
      onPressed: canSearch ? _searchUsingResults : null,
      icon: Icon(Icons.search, size: 24),
      label: Text(
        'Search Using Results',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: canSearch ? Colors.blue[700] : Colors.grey,
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}

// Results Screen
class EnhancedResultsScreen extends StatelessWidget {
  final Map<String, String> barcodeResults;
  final Map<String, String> markingsResults;
  final Map<String, String> packagingResults;
  final Map<String, String> searchResults;
  final Map<String, String> salesResults;
  final String searchNotes;
  final String description;
  final List<String> conflicts;

  const EnhancedResultsScreen({
    Key? key,
    required this.barcodeResults,
    required this.markingsResults,
    required this.packagingResults,
    required this.searchResults,
    required this.salesResults,
    required this.searchNotes,
    required this.description,
    required this.conflicts,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Enhanced Search Results'),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Conflicts alert
            if (conflicts.isNotEmpty) ...[
              Card(
                color: Colors.orange[50],
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.warning, color: Colors.orange[700]),
                          SizedBox(width: 8),
                          Text(
                            'Conflicts Require Review',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.orange[700],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      ...conflicts.map((conflict) => Padding(
                        padding: EdgeInsets.symmetric(vertical: 2),
                        child: Text('• $conflict', style: TextStyle(fontSize: 13)),
                      )).toList(),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 16),
            ],

            // Search summary
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Search Summary',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 16),

                    if (packagingResults.isNotEmpty) ...[
                      Text(
                        '📦 Packaging Analysis (Priority):',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.purple[700]),
                      ),
                      ...packagingResults.entries.map((entry) =>
                          Text('  ${entry.key}: ${entry.value}', style: TextStyle(fontSize: 13))),
                      SizedBox(height: 12),
                    ],

                    if (barcodeResults.isNotEmpty) ...[
                      Text('🏷️ Barcode Data:', style: TextStyle(fontWeight: FontWeight.bold)),
                      ...barcodeResults.entries.map((entry) =>
                          Text('  ${entry.key}: ${entry.value}', style: TextStyle(fontSize: 13))),
                      SizedBox(height: 12),
                    ],

                    if (markingsResults.isNotEmpty) ...[
                      Text('🔤 Markings Data:', style: TextStyle(fontWeight: FontWeight.bold)),
                      ...markingsResults.entries.map((entry) =>
                          Text('  ${entry.key}: ${entry.value}', style: TextStyle(fontSize: 13))),
                      SizedBox(height: 12),
                    ],

                    if (searchNotes.isNotEmpty) ...[
                      Text('📝 Search Notes:', style: TextStyle(fontWeight: FontWeight.bold)),
                      Text('  $searchNotes', style: TextStyle(fontSize: 13)),
                      SizedBox(height: 12),
                    ],

                    if (description.isNotEmpty) ...[
                      Text('📋 Description:', style: TextStyle(fontWeight: FontWeight.bold)),
                      Text('  $description', style: TextStyle(fontSize: 13)),
                    ],
                  ],
                ),
              ),
            ),

            SizedBox(height: 24),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.arrow_back),
                    label: Text('Back to Capture'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[600],
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      // Implement actual search/API call
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Search functionality would be implemented here'),
                          backgroundColor: Colors.blue,
                        ),
                      );
                    },
                    icon: Icon(Icons.search),
                    label: Text('Start Search'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[700],
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 12),
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
}