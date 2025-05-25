// ========================================
// lib/screens/job_creation_screen.dart
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

class JobCreationScreen extends StatefulWidget {
  @override
  _JobCreationScreenState createState() => _JobCreationScreenState();
}

class _JobCreationScreenState extends State<JobCreationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _userDescriptionController = TextEditingController();
  final _searchDescriptionController = TextEditingController();
  final _lengthController = TextEditingController();
  final _widthController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');

  List<Map<String, String>> _labeledImages = [];
  bool _isProcessing = false;

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
      // Navigate to image processing screen for immediate classification
      final result = await Navigator.push<Map<String, dynamic>>(
        context,
        MaterialPageRoute(
          builder: (context) => ImageProcessingScreen(
            imagePath: pickedFile.path,
            currentLabel: 'sales', // Default label
          ),
        ),
      );

      if (result != null) {
        setState(() {
          _labeledImages.add({
            'imagePath': result['imagePath'],
            'label': result['label'],
          });
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
      });
    }
  }

  void _removeImage(int index) {
    setState(() {
      _labeledImages.removeAt(index);
    });
  }

  Future<void> _runPackagingSearch() async {
    final packagingImages = _labeledImages
        .where((img) => img['label'] == 'packaging')
        .map((img) => img['imagePath'] as String)
        .toList();

    if (packagingImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No packaging images available')),
      );
      return;
    }

    final results = await CloudServices.searchPackaging(packagingImages);
    _showSearchResults('Packaging Search', results);
  }

  Future<void> _runMarkingsSearch() async {
    final markingImages = _labeledImages
        .where((img) => img['label'] == 'markings')
        .map((img) => img['imagePath'] as String)
        .toList();

    if (markingImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No marking images available')),
      );
      return;
    }

    final results = await CloudServices.searchMarkings(markingImages);
    _showSearchResults('Markings Search', results);
  }

  Future<void> _runReverseImageSearch() async {
    final idImages = _labeledImages
        .where((img) => img['label'] == 'id')
        .map((img) => img['imagePath'] as String)
        .toList();

    if (idImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No ID images available')),
      );
      return;
    }

    final results = await CloudServices.reverseImageSearchWithCandidates(idImages);
    _showSearchResults('Reverse Image Search', results);
  }

  void _showSearchResults(String title, Map<String, dynamic> results) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Confidence: ${(results['confidence'] * 100).toInt()}%'),
              SizedBox(height: 8),
              if (results['text'] != null) ...[
                Text('Extracted Text:', style: TextStyle(fontWeight: FontWeight.bold)),
                Text(results['text']),
                SizedBox(height: 8),
              ],
              if (results['products'] != null) ...[
                Text('Products Found:', style: TextStyle(fontWeight: FontWeight.bold)),
                ...List.generate(
                  (results['products'] as List).length,
                      (index) => Text('• ${results['products'][index]}'),
                ),
                SizedBox(height: 8),
              ],
              if (results['candidates'] != null && (results['candidates'] as List).isNotEmpty) ...[
                Text('Candidate Matches:', style: TextStyle(fontWeight: FontWeight.bold)),
                ...List.generate(
                  (results['candidates'] as List).length.clamp(0, 3), // Show max 3 in dialog
                      (index) {
                    final candidate = (results['candidates'] as List)[index];
                    return ListTile(
                      dense: true,
                      title: Text(candidate['title'] ?? 'Unknown', style: TextStyle(fontSize: 12)),
                      subtitle: Text('Confidence: ${((candidate['confidence'] ?? 0.0) * 100).toInt()}%', style: TextStyle(fontSize: 10)),
                      trailing: candidate['url'] != null
                          ? TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _openWebView(candidate['url'], candidate['title']);
                        },
                        child: Text('View', style: TextStyle(fontSize: 10)),
                      )
                          : null,
                    );
                  },
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  void _openWebView(String url, String title) {
    // This would open the web scraper screen
    // For now, just show a placeholder
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Would open: $url')),
    );
  }

  Future<void> _createItem() async {
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

      final item = ItemJob(
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

      await StorageService.saveJob(item);

      // Navigate to analysis results screen
      await Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => AnalysisResultsScreen(item: item),
        ),
      );

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error creating item: $e')),
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
        title: Text('Add New Item'),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Item Description
              Text(
                'Item Description',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
              SizedBox(height: 8),
              TextFormField(
                controller: _userDescriptionController,
                decoration: InputDecoration(
                  hintText: 'Brief description of the item',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a description';
                  }
                  return null;
                },
                maxLines: 2,
              ),

              SizedBox(height: 20),

              // Search Description
              Text(
                'Search Keywords',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
              SizedBox(height: 8),
              TextFormField(
                controller: _searchDescriptionController,
                decoration: InputDecoration(
                  hintText: 'Keywords to guide search (brand, model, etc.)',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter search keywords';
                  }
                  return null;
                },
                maxLines: 2,
              ),

              SizedBox(height: 20),

              // Quantity
              Text(
                'Quantity',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
              SizedBox(height: 8),
              TextFormField(
                controller: _quantityController,
                decoration: InputDecoration(
                  hintText: '1',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter quantity';
                  }
                  final qty = int.tryParse(value.trim());
                  if (qty == null || qty < 1) {
                    return 'Please enter a valid quantity';
                  }
                  return null;
                },
              ),

              SizedBox(height: 20),

              // Measurements
              Text(
                'Measurements (Optional)',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
              SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _lengthController,
                      decoration: InputDecoration(
                        labelText: 'Length',
                        hintText: '12"',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _widthController,
                      decoration: InputDecoration(
                        labelText: 'Width',
                        hintText: '8"',
                        border: OutlineInputBorder(),
                      ),
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
                      decoration: InputDecoration(
                        labelText: 'Height',
                        hintText: '6"',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _weightController,
                      decoration: InputDecoration(
                        labelText: 'Weight',
                        hintText: '2.5 lbs',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                ],
              ),

              SizedBox(height: 24),

              // Images Section
              Text(
                'Images',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
              SizedBox(height: 8),

              // Add Image Button
              Container(
                width: double.infinity,
                height: 60,
                child: OutlinedButton.icon(
                  onPressed: _captureImage,
                  icon: Icon(Icons.add_a_photo),
                  label: Text('Add Image'),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.blue[600]!),
                  ),
                ),
              ),

              if (_labeledImages.isNotEmpty) ...[
                SizedBox(height: 16),
                Container(
                  height: 120,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _labeledImages.length,
                    itemBuilder: (context, index) {
                      final imageData = _labeledImages[index];
                      final imagePath = imageData['imagePath']!;
                      final label = imageData['label']!;

                      return Container(
                        width: 120,
                        margin: EdgeInsets.only(right: 8),
                        child: Stack(
                          children: [
                            GestureDetector(
                              onTap: () => _editImageClassification(index),
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: _getLabelColor(label), width: 2),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
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
                              top: 4,
                              left: 4,
                              child: Container(
                                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _getLabelColor(label),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  label.toUpperCase(),
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            // Edit icon
                            Positioned(
                              bottom: 4,
                              right: 4,
                              child: Container(
                                padding: EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Icon(
                                  Icons.edit,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            ),
                            // Remove button
                            Positioned(
                              top: 4,
                              right: 4,
                              child: GestureDetector(
                                onTap: () => _removeImage(index),
                                child: Container(
                                  padding: EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Icon(
                                    Icons.close,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],

              SizedBox(height: 24),

              // Quick Search Buttons
              if (_labeledImages.isNotEmpty) ...[
                Text(
                  'Quick Searches',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
                ),
                SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _runPackagingSearch,
                        child: Text('Packaging\nSearch'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _runMarkingsSearch,
                        child: Text('Markings\nSearch'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _runReverseImageSearch,
                        child: Text('Reverse\nSearch'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 24),
              ],

              // Create Item Button
              Container(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isProcessing ? null : _createItem,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[600],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
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
                      Text('Creating Item...'),
                    ],
                  )
                      : Text(
                    'Create Item',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _userDescriptionController.dispose();
    _searchDescriptionController.dispose();
    _lengthController.dispose();
    _widthController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _quantityController.dispose();
    super.dispose();
  }
}