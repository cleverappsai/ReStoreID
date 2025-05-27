// ========================================
// lib/widgets/basic_image_editor.dart
// ========================================
import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

class BasicImageEditor extends StatefulWidget {
  final String imagePath;
  final Function(String) onSave;

  const BasicImageEditor({
    Key? key,
    required this.imagePath,
    required this.onSave,
  }) : super(key: key);

  @override
  _BasicImageEditorState createState() => _BasicImageEditorState();
}

class _BasicImageEditorState extends State<BasicImageEditor> {
  double _brightness = 0.0;
  double _contrast = 1.0;
  double _saturation = 1.0;
  double _rotation = 0.0;
  bool _flipHorizontal = false;
  bool _flipVertical = false;
  bool _isProcessing = false;

  // Crop variables
  bool _isCropping = false;
  Rect? _cropRect;
  GlobalKey _imageKey = GlobalKey();
  Size? _imageSize;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Edit Image'),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
        actions: [
          if (_isProcessing)
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
              onPressed: _saveImage,
              child: Text('SAVE', style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: Column(
        children: [
          // Image Display
          Expanded(
            flex: 3,
            child: Container(
              width: double.infinity,
              color: Colors.grey[200],
              child: Center(
                child: GestureDetector(
                  onTapDown: _isCropping ? _onTapDown : null,
                  onPanUpdate: _isCropping ? _onPanUpdate : null,
                  onPanEnd: _isCropping ? _onPanEnd : null,
                  child: Stack(
                    children: [
                      Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.identity()
                          ..scale(_flipHorizontal ? -1.0 : 1.0, _flipVertical ? -1.0 : 1.0)
                          ..rotateZ(_rotation * 3.14159 / 180),
                        child: ColorFiltered(
                          colorFilter: ColorFilter.matrix(_buildColorMatrix()),
                          child: Image.file(
                            File(widget.imagePath),
                            key: _imageKey,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                padding: EdgeInsets.all(32),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.broken_image, size: 64, color: Colors.grey[400]),
                                    SizedBox(height: 16),
                                    Text('Error loading image', style: TextStyle(color: Colors.grey[600])),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      if (_isCropping && _cropRect != null)
                        Positioned.fromRect(
                          rect: _cropRect!,
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.blue, width: 2),
                            ),
                            child: Container(
                              color: Colors.blue.withOpacity(0.1),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Controls
          Expanded(
            flex: 2,
            child: Container(
              padding: EdgeInsets.all(16),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Quick Actions
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildQuickActionButton(
                          icon: Icons.crop,
                          label: 'Crop',
                          onTap: _toggleCrop,
                          isActive: _isCropping,
                        ),
                        _buildQuickActionButton(
                          icon: Icons.flip,
                          label: 'Flip H',
                          onTap: () => setState(() => _flipHorizontal = !_flipHorizontal),
                          isActive: _flipHorizontal,
                        ),
                        _buildQuickActionButton(
                          icon: Icons.flip,
                          label: 'Flip V',
                          onTap: () => setState(() => _flipVertical = !_flipVertical),
                          isActive: _flipVertical,
                        ),
                        _buildQuickActionButton(
                          icon: Icons.rotate_right,
                          label: 'Rotate',
                          onTap: () => setState(() => _rotation = (_rotation + 90) % 360),
                        ),
                      ],
                    ),

                    SizedBox(height: 24),

                    // Adjustment Sliders
                    _buildSlider(
                      'Brightness',
                      _brightness,
                      -100,
                      100,
                          (value) => setState(() => _brightness = value),
                    ),

                    _buildSlider(
                      'Contrast',
                      _contrast,
                      0.5,
                      2.0,
                          (value) => setState(() => _contrast = value),
                    ),

                    _buildSlider(
                      'Saturation',
                      _saturation,
                      0.0,
                      2.0,
                          (value) => setState(() => _saturation = value),
                    ),

                    SizedBox(height: 16),

                    // Reset Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _resetAdjustments,
                        child: Text('Reset All Adjustments'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[600],
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isActive = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: isActive ? Colors.blue[600] : Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isActive ? Colors.white : Colors.grey[600],
              size: 24,
            ),
            SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isActive ? Colors.white : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSlider(
      String label,
      double value,
      double min,
      double max,
      Function(double) onChanged,
      ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(fontWeight: FontWeight.w500)),
            Text(value.toStringAsFixed(1), style: TextStyle(color: Colors.grey[600])),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          onChanged: onChanged,
          activeColor: Colors.blue[600],
        ),
      ],
    );
  }

  List<double> _buildColorMatrix() {
    // Create color matrix for brightness, contrast, and saturation adjustments
    double brightness = _brightness / 100.0;
    double contrast = _contrast;
    double saturation = _saturation;

    return [
      contrast * saturation, 0, 0, 0, brightness * 255,
      0, contrast * saturation, 0, 0, brightness * 255,
      0, 0, contrast * saturation, 0, brightness * 255,
      0, 0, 0, 1, 0,
    ];
  }

  void _toggleCrop() {
    setState(() {
      _isCropping = !_isCropping;
      if (!_isCropping) {
        _cropRect = null;
      }
    });
  }

  void _onTapDown(TapDownDetails details) {
    if (_isCropping) {
      setState(() {
        _cropRect = Rect.fromLTWH(
          details.localPosition.dx,
          details.localPosition.dy,
          0,
          0,
        );
      });
    }
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_isCropping && _cropRect != null) {
      setState(() {
        _cropRect = Rect.fromLTRB(
          _cropRect!.left,
          _cropRect!.top,
          details.localPosition.dx,
          details.localPosition.dy,
        );
      });
    }
  }

  void _onPanEnd(DragEndDetails details) {
    // Crop rectangle is complete
    if (_cropRect != null && (_cropRect!.width.abs() < 10 || _cropRect!.height.abs() < 10)) {
      setState(() {
        _cropRect = null;
      });
    }
  }

  void _resetAdjustments() {
    setState(() {
      _brightness = 0.0;
      _contrast = 1.0;
      _saturation = 1.0;
      _rotation = 0.0;
      _flipHorizontal = false;
      _flipVertical = false;
      _isCropping = false;
      _cropRect = null;
    });
  }

  Future<void> _saveImage() async {
    setState(() {
      _isProcessing = true;
    });

    try {
      // For now, just copy the original file with a new timestamp
      // In a real implementation, you would apply the actual transformations
      final directory = await getApplicationDocumentsDirectory();
      final fileName = 'edited_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final newPath = '${directory.path}/$fileName';

      await File(widget.imagePath).copy(newPath);

      widget.onSave(newPath);

      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Image saved successfully!'),
          backgroundColor: Colors.green,
        ),
      );

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving image: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }
}