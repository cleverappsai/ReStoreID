// ========================================
// lib/screens/camera_screen.dart
// ========================================
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image_editor_plus/image_editor_plus.dart';
import 'dart:io';

class CameraScreen extends StatefulWidget {
  final List<CameraDescription> cameras;

  const CameraScreen({Key? key, required this.cameras}) : super(key: key);

  @override
  _CameraScreenState createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _controller;
  bool _isReady = false;
  bool _isCapturing = false;
  bool _isFlashOn = false;
  int _currentCameraIndex = 0;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    if (widget.cameras.isEmpty) return;

    _controller = CameraController(
      widget.cameras[_currentCameraIndex],
      ResolutionPreset.high,
      enableAudio: false,
    );

    try {
      await _controller!.initialize();
      if (mounted) {
        setState(() {
          _isReady = true;
        });
      }
    } catch (e) {
      print('Error initializing camera: $e');
    }
  }

  Future<void> _switchCamera() async {
    if (widget.cameras.length <= 1) return;

    await _controller?.dispose();
    _currentCameraIndex = (_currentCameraIndex + 1) % widget.cameras.length;
    await _initializeCamera();
  }

  Future<void> _toggleFlash() async {
    if (_controller == null) return;

    try {
      setState(() {
        _isFlashOn = !_isFlashOn;
      });

      await _controller!.setFlashMode(
        _isFlashOn ? FlashMode.torch : FlashMode.off,
      );
    } catch (e) {
      print('Error toggling flash: $e');
    }
  }

  Future<void> _capturePhoto() async {
    if (_controller == null || !_controller!.value.isInitialized || _isCapturing) {
      return;
    }

    setState(() {
      _isCapturing = true;
    });

    try {
      final directory = await getApplicationDocumentsDirectory();
      final imagePath = '${directory.path}/IMG_${DateTime.now().millisecondsSinceEpoch}.jpg';

      // Turn off flash before capture if it was on for torch
      if (_isFlashOn) {
        await _controller!.setFlashMode(FlashMode.auto);
      }

      final XFile image = await _controller!.takePicture();
      await image.saveTo(imagePath);

      // Reset flash
      if (_isFlashOn) {
        await _controller!.setFlashMode(FlashMode.torch);
      }

      // Navigate to image editing and labeling
      _navigateToImageProcessing(imagePath);

    } catch (e) {
      print('Error capturing photo: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error capturing photo: $e')),
      );
      setState(() {
        _isCapturing = false;
      });
    }
  }

  Future<void> _navigateToImageProcessing(String imagePath) async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) => ImageProcessingScreen(imagePath: imagePath),
      ),
    );

    setState(() {
      _isCapturing = false;
    });

    if (result != null) {
      Navigator.pop(context, result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _isReady
          ? Stack(
        children: [
          // Camera Preview
          Positioned.fill(
            child: CameraPreview(_controller!),
          ),

          // Top Controls
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 20,
            right: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Close Button
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),

                // Flash Toggle
                IconButton(
                  onPressed: _toggleFlash,
                  icon: Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _isFlashOn ? Icons.flash_on : Icons.flash_off,
                      color: _isFlashOn ? Colors.yellow : Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Grid Lines (optional helper)
          Positioned.fill(
            child: CustomPaint(
              painter: GridPainter(),
            ),
          ),

          // Bottom Controls
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 140,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.8),
                  ],
                ),
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 30, vertical: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Gallery Button
                    IconButton(
                      onPressed: () {
                        // Could implement gallery access here
                      },
                      icon: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white, width: 1),
                        ),
                        child: Icon(
                          Icons.photo_library,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),

                    // Capture Button
                    GestureDetector(
                      onTap: _capturePhoto,
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _isCapturing ? Colors.grey : Colors.white,
                          border: Border.all(
                            color: Colors.white,
                            width: 4,
                          ),
                        ),
                        child: _isCapturing
                            ? Center(
                          child: CircularProgressIndicator(
                            color: Colors.black,
                            strokeWidth: 3,
                          ),
                        )
                            : Container(
                          margin: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),

                    // Camera Switch Button
                    IconButton(
                      onPressed: widget.cameras.length > 1 ? _switchCamera : null,
                      icon: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white, width: 1),
                        ),
                        child: Icon(
                          Icons.cameraswitch,
                          color: widget.cameras.length > 1 ? Colors.white : Colors.grey,
                          size: 24,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Instructions
          Positioned(
            top: MediaQuery.of(context).padding.top + 80,
            left: 20,
            right: 20,
            child: Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Position item clearly in frame. After capture, you\'ll be able to edit and label the image.',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      )
          : Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 16),
            Text(
              'Initializing camera...',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }
}

// Grid lines painter for camera assistance
class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..strokeWidth = 1;

    // Draw rule of thirds grid
    canvas.drawLine(
      Offset(size.width / 3, 0),
      Offset(size.width / 3, size.height),
      paint,
    );
    canvas.drawLine(
      Offset(size.width * 2 / 3, 0),
      Offset(size.width * 2 / 3, size.height),
      paint,
    );
    canvas.drawLine(
      Offset(0, size.height / 3),
      Offset(size.width, size.height / 3),
      paint,
    );
    canvas.drawLine(
      Offset(0, size.height * 2 / 3),
      Offset(size.width, size.height * 2 / 3),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ========================================
// Image Processing Screen (Edit + Label)
// ========================================
class ImageProcessingScreen extends StatefulWidget {
  final String imagePath;

  const ImageProcessingScreen({Key? key, required this.imagePath}) : super(key: key);

  @override
  _ImageProcessingScreenState createState() => _ImageProcessingScreenState();
}

class _ImageProcessingScreenState extends State<ImageProcessingScreen> {
  String? _editedImagePath;
  String _selectedLabel = 'sales';

  final Map<String, String> _labelDescriptions = {
    'sales': 'Overall product view for listings',
    'id': 'Model numbers, serial numbers, specs',
    'markings': 'Brand logos, labels, stickers',
    'packaging': 'Boxes, manuals, accessories',
    'barcode': 'Barcodes, UPC codes, QR codes',
  };

  final Map<String, IconData> _labelIcons = {
    'sales': Icons.shopping_bag,
    'id': Icons.fingerprint,
    'markings': Icons.label,
    'packaging': Icons.inventory_2,
    'barcode': Icons.qr_code,
  };

  @override
  void initState() {
    super.initState();
    _editedImagePath = widget.imagePath;
  }

  Future<void> _editImage() async {
    try {
      final editedImage = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ImageEditor(
            image: File(_editedImagePath!).readAsBytesSync(),
          ),
        ),
      );

      if (editedImage != null) {
        final directory = await getApplicationDocumentsDirectory();
        final newPath = '${directory.path}/EDITED_${DateTime.now().millisecondsSinceEpoch}.jpg';

        final file = File(newPath);
        await file.writeAsBytes(editedImage);

        setState(() {
          _editedImagePath = newPath;
        });
      }
    } catch (e) {
      print('Error editing image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error editing image: $e')),
      );
    }
  }

  void _confirmImage() {
    Navigator.pop(context, {
      'imagePath': _editedImagePath!,
      'label': _selectedLabel,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('Edit & Label Image'),
        actions: [
          TextButton(
            onPressed: _confirmImage,
            child: Text(
              'Done',
              style: TextStyle(
                color: Colors.blue,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Image Preview
          Expanded(
            flex: 2,
            child: Container(
              width: double.infinity,
              margin: EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[700]!, width: 2),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.file(
                  File(_editedImagePath!),
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),

          // Edit Button
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _editImage,
                icon: Icon(Icons.edit),
                label: Text('Edit Image'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),

          SizedBox(height: 20),

          // Label Selection
          Expanded(
            flex: 1,
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Select Image Type',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Choose the primary purpose of this image:',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 14,
                    ),
                  ),
                  SizedBox(height: 16),

                  Expanded(
                    child: GridView.builder(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 3,
                      ),
                      itemCount: _labelDescriptions.length,
                      itemBuilder: (context, index) {
                        final label = _labelDescriptions.keys.elementAt(index);
                        final isSelected = _selectedLabel == label;

                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedLabel = label;
                            });
                          },
                          child: Container(
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isSelected ? Colors.blue : Colors.grey[800],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isSelected ? Colors.blue : Colors.grey[600]!,
                                width: 2,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _labelIcons[label],
                                  color: isSelected ? Colors.white : Colors.grey[400],
                                  size: 20,
                                ),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    label.toUpperCase(),
                                    style: TextStyle(
                                      color: isSelected ? Colors.white : Colors.grey[400],
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  // Selected label description
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.withOpacity(0.3)),
                    ),
                    child: Text(
                      _labelDescriptions[_selectedLabel]!,
                      style: TextStyle(
                        color: Colors.blue[300],
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}