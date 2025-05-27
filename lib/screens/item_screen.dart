// ========================================
// lib/screens/item_screen.dart (Complete Enhanced Version)
// ========================================
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'dart:io';
import '../models/item_job.dart';
import '../services/storage_service.dart';
import '../services/cloud_services.dart';
import '../services/enhanced_analysis_service.dart';
import 'image_processing_screen.dart';
import 'analysis_results_screen.dart';
import 'web_scraper_screen.dart';

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

  Future<void> _runEnhancedAnalysis() async {
    if (_currentItem == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please save the item first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Enhanced Analysis'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('This will perform a comprehensive analysis using:'),
            SizedBox(height: 8),
            Text('• OCR text extraction from images'),
            Text('• Targeted searches for product documentation'),
            Text('• Content scraping from authoritative sources'),
            Text('• AI-powered summary generation'),
            SizedBox(height: 12),
            Text(
              'This process may take a few minutes.',
              style: TextStyle(fontStyle: FontStyle.italic),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Start Analysis'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Text('Starting enhanced analysis...'),
          ],
        ),
      ),
    );

    try {
      // Trigger enhanced analysis
      EnhancedAnalysisService.triggerBackgroundAnalysis(_currentItem!);

      Navigator.pop(context); // Close loading dialog

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Enhanced analysis started! Check the analysis results screen for progress.'),
          backgroundColor: Colors.green,
          action: SnackBarAction(
            label: 'VIEW',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AnalysisResultsScreen(item: _currentItem!),
                ),
              );
            },
          ),
        ),
      );

    } catch (e) {
      Navigator.pop(context); // Close loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error starting enhanced analysis: $e'),
          backgroundColor: Colors.red,
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

      // For new items, offer to start enhanced analysis
      if (!_isEditMode) {
        final startAnalysis = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Item Created Successfully'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Would you like to start enhanced analysis now?'),
                SizedBox(height: 8),
                Text(
                  'This will provide detailed product information and pricing.',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Later'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text('Start Analysis'),
              ),
            ],
          ),
        );

        if (startAnalysis == true) {
          // Trigger enhanced analysis
          EnhancedAnalysisService.triggerBackgroundAnalysis(item);
        }

        // Navigate to analysis results
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
            // Enhanced Analysis Card
            Card(
              color: Colors.blue[50],
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.auto_awesome, color: Colors.blue[700]),
                        SizedBox(width: 8),
                        Text(
                          'Enhanced Analysis',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[700],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Get comprehensive product information using AI-powered analysis.',
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                    SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _currentItem != null ? _runEnhancedAnalysis : null,
                        icon: Icon(Icons.psychology),
                        label: Text('Start Enhanced Analysis'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[600],
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    if (_currentItem == null)
                      Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text(
                          'Save the item first to enable enhanced analysis',
                          style: TextStyle(
                            color: Colors.orange[700],
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
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