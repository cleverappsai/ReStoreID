// ========================================
// lib/screens/edit_item_screen.dart - COMPLETE VERSION
// ========================================
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../models/item_job.dart';
//import '../services/database_service.dart';
//import '../widgets/image_classification_widget.dart';
//import '../widgets/basic_image_editor.dart';
import '../services/enhanced_analysis_service.dart';
import 'debug_analysis_screen.dart';

class EditItemScreen extends StatefulWidget {
  final ItemJob item;

  const EditItemScreen({Key? key, required this.item}) : super(key: key);

  @override
  _EditItemScreenState createState() => _EditItemScreenState();
}

class _EditItemScreenState extends State<EditItemScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Controllers for form fields
  final _userDescriptionController = TextEditingController();
  final _searchDescriptionController = TextEditingController();

  // State variables
  List<String> _images = [];
  Map<String, List<String>>? _imageClassification;
  bool _isLoading = false;
  bool _isAnalyzing = false;
  String _analysisProgress = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);

    // Initialize form with existing item data
    _userDescriptionController.text = widget.item.userDescription;
    _searchDescriptionController.text = widget.item.searchDescription ?? '';
    _images = List.from(widget.item.images);
    _imageClassification = widget.item.imageClassification != null
        ? Map.from(widget.item.imageClassification!)
        : null;
  }

  @override
  void dispose() {
    _tabController.dispose();
    _userDescriptionController.dispose();
    _searchDescriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final pickedFiles = await picker.pickMultiImage(
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (pickedFiles.isNotEmpty) {
        final directory = await getApplicationDocumentsDirectory();
        final itemDir = Directory('${directory.path}/items/${widget.item.id}');
        await itemDir.create(recursive: true);

        for (var pickedFile in pickedFiles) {
          final fileName = 'image_${DateTime.now().millisecondsSinceEpoch}_${_images.length}.jpg';
          final newPath = '${itemDir.path}/$fileName';
          await File(pickedFile.path).copy(newPath);

          setState(() {
            _images.add(newPath);
          });
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking images: $e')),
      );
    }
  }

  Future<void> _removeImage(int index) async {
    try {
      final imagePath = _images[index];
      final file = File(imagePath);
      if (await file.exists()) {
        await file.delete();
      }

      setState(() {
        _images.removeAt(index);
        // Update classification to remove deleted image
        if (_imageClassification != null) {
          _imageClassification = _imageClassification!.map((key, value) =>
              MapEntry(key, value.where((path) => path != imagePath).toList()));
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error removing image: $e')),
      );
    }
  }

  Future<void> _editImage(int index) async {
    final imagePath = _images[index];
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BasicImageEditor(
          imagePath: imagePath,
          onSave: (editedPath) {
            setState(() {
              _images[index] = editedPath;
            });
          },
        ),
      ),
    );
  }

  Future<void> _saveItem() async {
    if (_userDescriptionController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter a description')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final updatedItem = ItemJob(
        id: widget.item.id,
        userDescription: _userDescriptionController.text,
        searchDescription: _searchDescriptionController.text.isEmpty
            ? null
            : _searchDescriptionController.text,
        images: _images,
        imageClassification: _imageClassification,
        status: widget.item.status,
        createdAt: widget.item.createdAt,
        updatedAt: DateTime.now(),
        searchResults: widget.item.searchResults,
        enhancedAnalysisResults: widget.item.enhancedAnalysisResults,
      );

      await DatabaseService.updateItem(updatedItem);

      Navigator.pop(context, updatedItem);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving item: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _runEnhancedAnalysis() async {
    if (_images.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please add images before running analysis')),
      );
      return;
    }

    setState(() {
      _isAnalyzing = true;
      _analysisProgress = 'Starting enhanced analysis...';
    });

    try {
      final currentItem = ItemJob(
        id: widget.item.id,
        userDescription: _userDescriptionController.text,
        searchDescription: _searchDescriptionController.text.isEmpty
            ? null
            : _searchDescriptionController.text,
        images: _images,
        imageClassification: _imageClassification,
        status: widget.item.status,
        createdAt: widget.item.createdAt,
        updatedAt: DateTime.now(),
        searchResults: widget.item.searchResults,
        enhancedAnalysisResults: widget.item.enhancedAnalysisResults,
      );

      final results = await EnhancedAnalysisService.performEnhancedAnalysis(
        currentItem,
        onProgress: (progress) {
          setState(() {
            _analysisProgress = progress;
          });
        },
      );

      // Update the item with results
      final updatedItem = currentItem.copyWith(
        enhancedAnalysisResults: results,
        status: ItemStatus.analyzed,
        updatedAt: DateTime.now(),
      );

      await DatabaseService.updateItem(updatedItem);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Enhanced analysis completed!'),
          backgroundColor: Colors.green,
        ),
      );

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Analysis failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isAnalyzing = false;
        _analysisProgress = '';
      });
    }
  }

  void _openDebugAnalysis() {
    final currentItem = ItemJob(
      id: widget.item.id,
      userDescription: _userDescriptionController.text,
      searchDescription: _searchDescriptionController.text.isEmpty
          ? null
          : _searchDescriptionController.text,
      images: _images,
      imageClassification: _imageClassification,
      status: widget.item.status,
      createdAt: widget.item.createdAt,
      updatedAt: DateTime.now(),
      searchResults: widget.item.searchResults,
      enhancedAnalysisResults: widget.item.enhancedAnalysisResults,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DebugAnalysisScreen(item: currentItem),
      ),
    );
  }

  void _buildDescriptionSummary() {
    // TODO: Implement description summary builder
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Description summary builder coming soon!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Edit Item'),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: [
            Tab(icon: Icon(Icons.edit), text: 'Details'),
            Tab(icon: Icon(Icons.photo_library), text: 'Images'),
            Tab(icon: Icon(Icons.category), text: 'Classification'),
            Tab(icon: Icon(Icons.settings), text: 'Actions'),
          ],
        ),
        actions: [
          if (_isLoading)
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
            )
          else
            TextButton(
              onPressed: _saveItem,
              child: Text('SAVE', style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildDetailsTab(),
          _buildImagesTab(),
          _buildClassificationTab(),
          _buildActionsTab(),
        ],
      ),
    );
  }

  Widget _buildDetailsTab() {
    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Item Description', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          SizedBox(height: 8),
          TextField(
            controller: _userDescriptionController,
            decoration: InputDecoration(
              hintText: 'Describe the item you want to identify',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
          SizedBox(height: 24),

          Text('Search Keywords (Optional)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          SizedBox(height: 8),
          TextField(
            controller: _searchDescriptionController,
            decoration: InputDecoration(
              hintText: 'Additional keywords to help with search',
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
          ),
          SizedBox(height: 24),

          // Item Stats
          _buildItemStats(),
        ],
      ),
    );
  }

  Widget _buildItemStats() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Item Information', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            SizedBox(height: 12),
            _buildStatRow('Status', widget.item.status.toString().split('.').last),
            _buildStatRow('Created', _formatDate(widget.item.createdAt)),
            _buildStatRow('Updated', _formatDate(widget.item.updatedAt)),
            _buildStatRow('Images', '${_images.length}'),
            if (_imageClassification != null)
              _buildStatRow('Classified', '${_imageClassification!.values.expand((x) => x).length}/${_images.length}'),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600])),
          Text(value, style: TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildImagesTab() {
    return Column(
      children: [
        // Add Image Button
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(16),
          child: ElevatedButton.icon(
            onPressed: _pickImage,
            icon: Icon(Icons.add_a_photo),
            label: Text('Add Images'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green[600],
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),

        // Images Grid
        Expanded(
          child: _images.isEmpty
              ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.photo_library, size: 64, color: Colors.grey[400]),
                SizedBox(height: 16),
                Text('No images added yet', style: TextStyle(color: Colors.grey[600])),
              ],
            ),
          )
              : GridView.builder(
            padding: EdgeInsets.all(16),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: _images.length,
            itemBuilder: (context, index) {
              return Card(
                child: Column(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
                        child: Image.file(
                          File(_images[index]),
                          fit: BoxFit.cover,
                          width: double.infinity,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: Colors.grey[300],
                              child: Icon(Icons.broken_image, color: Colors.grey[600]),
                            );
                          },
                        ),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        IconButton(
                          onPressed: () => _editImage(index),
                          icon: Icon(Icons.edit, size: 20),
                          tooltip: 'Edit Image',
                        ),
                        IconButton(
                          onPressed: () => _removeImage(index),
                          icon: Icon(Icons.delete, size: 20, color: Colors.red),
                          tooltip: 'Remove Image',
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildClassificationTab() {
    return ImageClassificationWidget(
      images: _images,
      initialClassification: _imageClassification,
      onClassificationChanged: (newClassification) {
        setState(() {
          _imageClassification = newClassification;
        });
      },
    );
  }

  Widget _buildActionsTab() {
    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Analysis & Debugging',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 16),

          // Enhanced Analysis Section
          Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Enhanced Analysis',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Run comprehensive analysis using OCR, barcode detection, and image search.',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  SizedBox(height: 16),

                  if (_isAnalyzing) ...[
                    LinearProgressIndicator(),
                    SizedBox(height: 8),
                    Text(_analysisProgress, style: TextStyle(fontSize: 12)),
                    SizedBox(height: 16),
                  ],

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isAnalyzing ? null : _runEnhancedAnalysis,
                      icon: Icon(Icons.analytics),
                      label: Text(_isAnalyzing ? 'ANALYZING...' : 'RUN ENHANCED ANALYSIS'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[600],
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

          // Debug Tools Section
          Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Debug Tools',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Access detailed logging and analysis debugging tools.',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  SizedBox(height: 16),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _openDebugAnalysis,
                      icon: Icon(Icons.bug_report),
                      label: Text('OPEN DEBUG ANALYSIS'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple[600],
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

          // Summary Tools Section
          Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Summary Tools',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Generate description summaries from analysis results.',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  SizedBox(height: 16),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _buildDescriptionSummary,
                      icon: Icon(Icons.summarize),
                      label: Text('BUILD DESCRIPTION SUMMARY'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal[600],
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          Spacer(),

          // Item Status
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _getStatusColor(widget.item.status).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _getStatusColor(widget.item.status)),
            ),
            child: Row(
              children: [
                Icon(_getStatusIcon(widget.item.status), color: _getStatusColor(widget.item.status)),
                SizedBox(width: 12),
                Text(
                  'Status: ${widget.item.status.toString().split('.').last.toUpperCase()}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _getStatusColor(widget.item.status),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(ItemStatus status) {
    switch (status) {
      case ItemStatus.draft:
        return Colors.grey;
      case ItemStatus.processing:
        return Colors.orange;
      case ItemStatus.analyzed:
        return Colors.green;
      case ItemStatus.failed:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(ItemStatus status) {
    switch (status) {
      case ItemStatus.draft:
        return Icons.edit;
      case ItemStatus.processing:
        return Icons.hourglass_empty;
      case ItemStatus.analyzed:
        return Icons.check_circle;
      case ItemStatus.failed:
        return Icons.error;
      default:
        return Icons.help;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}