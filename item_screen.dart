// ========================================
// lib/screens/item_screen.dart - COMPLETE WITH OCR INTEGRATION
// ========================================
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../models/item_job.dart';
import '../services/storage_service.dart';
import '../services/ocr_service.dart';
import '../services/enhanced_analysis_service.dart';
import '../widgets/enhanced_summary_tab.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class ItemScreen extends StatefulWidget {
  final ItemJob? item;

  const ItemScreen({Key? key, this.item}) : super(key: key);

  @override
  State<ItemScreen> createState() => _ItemScreenState();
}

class _ItemScreenState extends State<ItemScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  late TextEditingController _descriptionController;
  late TextEditingController _searchDescriptionController;
  late TextEditingController _lengthController;
  late TextEditingController _widthController;
  late TextEditingController _heightController;
  late TextEditingController _weightController;
  late TextEditingController _quantityController;

  List<String> _images = [];
  bool _isSaving = false;
  bool _isProcessingOCR = false;
  ItemJob? _currentItem;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    _currentItem = widget.item;

    // Initialize controllers
    _descriptionController = TextEditingController(text: widget.item?.userDescription ?? '');
    _searchDescriptionController = TextEditingController(text: widget.item?.searchDescription ?? '');
    _lengthController = TextEditingController(text: widget.item?.length ?? '');
    _widthController = TextEditingController(text: widget.item?.width ?? '');
    _heightController = TextEditingController(text: widget.item?.height ?? '');
    _weightController = TextEditingController(text: widget.item?.weight ?? '');
    _quantityController = TextEditingController(text: widget.item?.quantity.toString() ?? '1');

    if (widget.item != null) {
      _images = List.from(widget.item!.images);
    }

    // Start OCR if item exists but OCR not completed
    if (widget.item != null && !widget.item!.ocrCompleted && widget.item!.images.isNotEmpty) {
      _startOCRProcessing();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _descriptionController.dispose();
    _searchDescriptionController.dispose();
    _lengthController.dispose();
    _widthController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.item == null ? 'Add Item' : 'Edit Item'),
        actions: [
          if (widget.item == null || !_hasUnsavedChanges())
            IconButton(
              onPressed: _isSaving ? null : _saveItem,
              icon: _isSaving
                  ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
                  : Icon(Icons.save),
            )
          else
            IconButton(
              onPressed: _saveChanges,
              icon: Icon(Icons.save, color: Colors.orange),
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'Details', icon: Icon(Icons.info)),
            Tab(text: 'Images', icon: Icon(Icons.photo_library)),
            Tab(text: 'Summary', icon: Icon(Icons.summarize)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildDetailsTab(),
          _buildImagesTab(),
          _buildSummaryTab(),
        ],
      ),
    );
  }

  Widget _buildDetailsTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Basic Info Card
          Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Basic Information',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  SizedBox(height: 16),

                  TextField(
                    controller: _descriptionController,
                    decoration: InputDecoration(
                      labelText: 'Item Description *',
                      hintText: 'Brief description of the item',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
                  SizedBox(height: 16),

                  TextField(
                    controller: _searchDescriptionController,
                    decoration: InputDecoration(
                      labelText: 'Search Keywords',
                      hintText: 'Keywords to help with product search',
                      border: OutlineInputBorder(),
                      helperText: 'Brand, model, specific features, etc.',
                    ),
                    maxLines: 2,
                  ),
                  SizedBox(height: 16),

                  TextField(
                    controller: _quantityController,
                    decoration: InputDecoration(
                      labelText: 'Quantity',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ],
              ),
            ),
          ),

          SizedBox(height: 16),

          // Measurements Card
          Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Measurements (Optional)',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _lengthController,
                          decoration: InputDecoration(
                            labelText: 'Length',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _widthController,
                          decoration: InputDecoration(
                            labelText: 'Width',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _heightController,
                          decoration: InputDecoration(
                            labelText: 'Height',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _weightController,
                          decoration: InputDecoration(
                            labelText: 'Weight',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          SizedBox(height: 16),

          // OCR Status Card
          if (widget.item != null) _buildOCRStatusCard(),
        ],
      ),
    );
  }

  Widget _buildOCRStatusCard() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _currentItem?.ocrCompleted == true ? Icons.check_circle : Icons.hourglass_empty,
                  color: _currentItem?.ocrCompleted == true ? Colors.green : Colors.orange,
                ),
                SizedBox(width: 8),
                Text(
                  'OCR Text Extraction',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Spacer(),
                if (_isProcessingOCR)
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            SizedBox(height: 12),

            Text(
              _currentItem?.ocrCompleted == true
                  ? 'Text extraction completed successfully'
                  : _isProcessingOCR
                  ? 'Processing images for text extraction...'
                  : 'Text extraction pending',
              style: Theme.of(context).textTheme.bodyMedium,
            ),

            if (_currentItem?.ocrCompleted == true && _currentItem?.ocrResults != null) ...[
              SizedBox(height: 12),
              Text(
                OCRService.getOCRSummary(_currentItem!),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],

            SizedBox(height: 12),

            Row(
              children: [
                if (_currentItem?.ocrCompleted != true && !_isProcessingOCR)
                  ElevatedButton.icon(
                    onPressed: _images.isNotEmpty ? _startOCRProcessing : null,
                    icon: Icon(Icons.play_arrow),
                    label: Text('Start OCR'),
                  ),

                if (_currentItem?.ocrCompleted == true)
                  OutlinedButton.icon(
                    onPressed: _retryOCR,
                    icon: Icon(Icons.refresh),
                    label: Text('Retry OCR'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagesTab() {
    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          // Add Image Buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _addImage(ImageSource.camera),
                  icon: Icon(Icons.camera_alt),
                  label: Text('Take Photo'),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _addImage(ImageSource.gallery),
                  icon: Icon(Icons.photo_library),
                  label: Text('From Gallery'),
                ),
              ),
            ],
          ),

          SizedBox(height: 16),

          // Images Grid
          Expanded(
            child: _images.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.photo_library, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No images added yet',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Add photos to enable OCR text extraction',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            )
                : GridView.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: _images.length,
              itemBuilder: (context, index) => _buildImageCard(index),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageCard(int index) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.file(
            File(_images[index]),
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Container(
              color: Colors.grey[300],
              child: Icon(Icons.error, color: Colors.red),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: CircleAvatar(
              radius: 16,
              backgroundColor: Colors.black54,
              child: IconButton(
                onPressed: () => _removeImage(index),
                icon: Icon(Icons.close, color: Colors.white, size: 16),
                padding: EdgeInsets.zero,
              ),
            ),
          ),
          Positioned(
            bottom: 8,
            left: 8,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Image ${index + 1}',
                style: TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryTab() {
    if (_currentItem == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.save, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Save item first',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            SizedBox(height: 8),
            Text(
              'Save the item to access enhanced analysis features',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      );
    }

    return EnhancedSummaryTab(
      item: _currentItem!,
      onItemUpdated: (updatedItem) {
        setState(() {
          _currentItem = updatedItem;
        });
      },
    );
  }

  // Image Management
  Future<void> _addImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (image != null) {
        // Copy image to app's document directory
        final appDir = await getApplicationDocumentsDirectory();
        final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
        final savedImage = await File(image.path).copy('${appDir.path}/$fileName');

        setState(() {
          _images.add(savedImage.path);
        });

        // If item exists, update it immediately
        if (_currentItem != null) {
          final updatedItem = _currentItem!.copyWith(
            images: _images,
            ocrCompleted: false, // Reset OCR status when new images added
          );
          await StorageService.saveJob(updatedItem);
          setState(() {
            _currentItem = updatedItem;
          });

          // Start OCR processing for the new image
          _startOCRProcessing();
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding image: $e')),
      );
    }
  }

  void _removeImage(int index) {
    setState(() {
      _images.removeAt(index);
    });

    // If item exists, update it immediately
    if (_currentItem != null) {
      _saveChanges();
    }
  }

  // OCR Processing
  Future<void> _startOCRProcessing() async {
    if (_images.isEmpty || _isProcessingOCR) return;

    setState(() {
      _isProcessingOCR = true;
    });

    try {
      if (_currentItem != null) {
        print('🔄 Starting OCR processing for ${_currentItem!.id}');

        await OCRService.processItemImages(_currentItem!);

        // Refresh the current item
        final updatedItem = await StorageService.getJob(_currentItem!.id);
        if (updatedItem != null) {
          setState(() {
            _currentItem = updatedItem;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ OCR processing completed!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      print('❌ OCR processing failed: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('OCR processing failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isProcessingOCR = false;
      });
    }
  }

  Future<void> _retryOCR() async {
    if (_currentItem != null) {
      // Reset OCR status
      final updatedItem = _currentItem!.copyWith(
        ocrCompleted: false,
        ocrResults: null,
        imageClassification: null,
      );
      await StorageService.saveJob(updatedItem);
      setState(() {
        _currentItem = updatedItem;
      });

      // Start OCR again
      _startOCRProcessing();
    }
  }

  // Save Operations
  Future<void> _saveItem() async {
    if (_descriptionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter an item description')),
      );
      return;
    }

    if (_images.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please add at least one image')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final newItem = ItemJob(
        id: const Uuid().v4(),
        userDescription: _descriptionController.text.trim(),
        searchDescription: _searchDescriptionController.text.trim(),
        length: _lengthController.text.trim().isEmpty ? null : _lengthController.text.trim(),
        width: _widthController.text.trim().isEmpty ? null : _widthController.text.trim(),
        height: _heightController.text.trim().isEmpty ? null : _heightController.text.trim(),
        weight: _weightController.text.trim().isEmpty ? null : _weightController.text.trim(),
        quantity: int.tryParse(_quantityController.text) ?? 1,
        images: _images,
        createdAt: DateTime.now(),
      );

      await StorageService.saveJob(newItem);

      setState(() {
        _currentItem = newItem;
      });

      print('✅ Item saved: ${newItem.id}');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Item saved successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      // Start OCR processing in background
      _startOCRProcessing();

      // Navigate back if this was a new item
      if (widget.item == null) {
        Navigator.of(context).pop(newItem);
      }

    } catch (e) {
      print('❌ Error saving item: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving item: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _saveChanges() async {
    if (_currentItem == null) return;

    setState(() => _isSaving = true);

    try {
      final updatedItem = _currentItem!.copyWith(
        userDescription: _descriptionController.text.trim(),
        searchDescription: _searchDescriptionController.text.trim(),
        length: _lengthController.text.trim().isEmpty ? null : _lengthController.text.trim(),
        width: _widthController.text.trim().isEmpty ? null : _widthController.text.trim(),
        height: _heightController.text.trim().isEmpty ? null : _heightController.text.trim(),
        weight: _weightController.text.trim().isEmpty ? null : _weightController.text.trim(),
        quantity: int.tryParse(_quantityController.text) ?? 1,
        images: _images,
      );

      await StorageService.saveJob(updatedItem);

      setState(() {
        _currentItem = updatedItem;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Changes saved!'),
          backgroundColor: Colors.green,
        ),
      );

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving changes: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }

  bool _hasUnsavedChanges() {
    if (_currentItem == null) return false;

    return _descriptionController.text.trim() != _currentItem!.userDescription ||
        _searchDescriptionController.text.trim() != _currentItem!.searchDescription ||
        _lengthController.text.trim() != (_currentItem!.length ?? '') ||
        _widthController.text.trim() != (_currentItem!.width ?? '') ||
        _heightController.text.trim() != (_currentItem!.height ?? '') ||
        _weightController.text.trim() != (_currentItem!.weight ?? '') ||
        (int.tryParse(_quantityController.text) ?? 1) != _currentItem!.quantity ||
        !_listsEqual(_images, _currentItem!.images);
  }

  bool _listsEqual(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}