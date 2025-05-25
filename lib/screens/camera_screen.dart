import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image_editor_plus/image_editor_plus.dart';
import 'dart:io';
import '../models/item_job.dart';
import '../widgets/category_selector.dart';
import '../widgets/image_gallery.dart';
import 'processing_screen.dart';

class CameraScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  final ItemJob job;

  const CameraScreen({Key? key, required this.cameras, required this.job}) : super(key: key);

  @override
  _CameraScreenState createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _controller;
  ImageCategory _selectedCategory = ImageCategory.itemSearch;
  List<CapturedImage> _capturedImages = [];
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    if (widget.cameras.isNotEmpty) {
      _controller = CameraController(
        widget.cameras.first,
        ResolutionPreset.high,
      );

      await _controller!.initialize();
      if (mounted) {
        setState(() => _isInitialized = true);
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized || _controller == null) {
      return Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Capture Photos'),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
        actions: [
          if (_capturedImages.isNotEmpty)
            TextButton(
              onPressed: _processImages,
              child: Text('Process (${_capturedImages.length})', 
                style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: Column(
        children: [
          // Category selector
          CategorySelector(
            selectedCategory: _selectedCategory,
            onCategoryChanged: (category) {
              setState(() => _selectedCategory = category);
            },
          ),
          // Camera preview
          Expanded(
            flex: 3,
            child: Container(
              width: double.infinity,
              child: CameraPreview(_controller!),
            ),
          ),
          // Image gallery
          Container(
            height: 120,
            child: ImageGallery(
              images: _capturedImages,
              onImageTap: _showImageOptions,
              onImageDelete: _deleteImage,
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _captureImage,
        child: Icon(Icons.camera),
        backgroundColor: Colors.blue[600],
      ),
    );
  }

  Future<void> _captureImage() async {
    try {
      final image = await _controller!.takePicture();
      
      // Get app directory for storing images
      final directory = await getApplicationDocumentsDirectory();
      final imagePath = '${directory.path}/${DateTime.now().millisecondsSinceEpoch}.jpg';
      
      // Copy image to app directory
      await File(image.path).copy(imagePath);
      
      final capturedImage = CapturedImage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        filePath: imagePath,
        category: _selectedCategory,
        capturedAt: DateTime.now(),
      );

      setState(() {
        _capturedImages.add(capturedImage);
      });

      // Show option to edit image
      _showEditOption(capturedImage);

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error capturing image: $e')),
      );
    }
  }

  void _showEditOption(CapturedImage image) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Image Captured'),
        content: Text('Would you like to edit this image?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Keep as is'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _editImage(image);
            },
            child: Text('Edit'),
          ),
        ],
      ),
    );
  }

  Future<void> _editImage(CapturedImage image) async {
    try {
      final editedImage = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ImageEditor(
            image: File(image.filePath).readAsBytesSync(),
          ),
        ),
      );

      if (editedImage != null) {
        // Save edited image
        final directory = await getApplicationDocumentsDirectory();
        final editedPath = '${directory.path}/edited_${DateTime.now().millisecondsSinceEpoch}.jpg';
        await File(editedPath).writeAsBytes(editedImage);

        // Update image path
        setState(() {
          image.filePath = editedPath;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error editing image: $e')),
      );
    }
  }

  void _showImageOptions(CapturedImage image) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.edit),
              title: Text('Edit Image'),
              onTap: () {
                Navigator.pop(context);
                _editImage(image);
              },
            ),
            ListTile(
              leading: Icon(Icons.category),
              title: Text('Change Category'),
              onTap: () {
                Navigator.pop(context);
                _changeCategoryDialog(image);
              },
            ),
            ListTile(
              leading: Icon(Icons.delete, color: Colors.red),
              title: Text('Delete Image'),
              onTap: () {
                Navigator.pop(context);
                _deleteImage(image);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _changeCategoryDialog(CapturedImage image) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Change Category'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: ImageCategory.values.map((category) {
            return RadioListTile<ImageCategory>(
              title: Text(_getCategoryDisplayName(category)),
              value: category,
              groupValue: image.category,
              onChanged: (newCategory) {
                setState(() {
                  image.category = newCategory!;
                });
                Navigator.pop(context);
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  String _getCategoryDisplayName(ImageCategory category) {
    switch (category) {
      case ImageCategory.packaging:
        return '📦 Packaging';
      case ImageCategory.itemSearch:
        return '🔍 Item Search';
      case ImageCategory.itemSales:
        return '📸 Sales Photos';
      case ImageCategory.markings:
        return '🏷️ Markings';
      case ImageCategory.barcode:
        return '📊 Barcode/UPC';
    }
  }

  void _deleteImage(CapturedImage image) {
    setState(() {
      _capturedImages.remove(image);
    });
    
    // Delete file
    File(image.filePath).delete().catchError((e) {
      print('Error deleting file: $e');
    });
  }

  void _processImages() {
    if (_capturedImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please capture at least one image')),
      );
      return;
    }

    // Update job with captured images
    widget.job.images = _capturedImages;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProcessingScreen(job: widget.job),
      ),
    );
  }
}