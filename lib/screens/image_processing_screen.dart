// ========================================
// lib/screens/image_processing_screen.dart
// ========================================
import 'package:flutter/material.dart';
import 'dart:io';

class ImageProcessingScreen extends StatefulWidget {
  final String imagePath;
  final String? currentLabel;

  const ImageProcessingScreen({
    Key? key,
    required this.imagePath,
    this.currentLabel,
  }) : super(key: key);

  @override
  _ImageProcessingScreenState createState() => _ImageProcessingScreenState();
}

class _ImageProcessingScreenState extends State<ImageProcessingScreen> {
  String _selectedLabel = 'sales';

  final Map<String, String> _labelDescriptions = {
    'sales': 'Overall item views for sales listings - best angles, clean shots',
    'id': 'For reverse image searches - clear product shots, front/side views',
    'markings': 'Areas of interest on product - logos, model stamps, serial numbers',
    'packaging': 'Labels, barcodes, UPC, manufacturer info, part numbers (PRIMARY ID SOURCE)',
    'barcode': 'Direct barcode/UPC captures - clean, straight-on shots',
  };

  final Map<String, IconData> _labelIcons = {
    'sales': Icons.shopping_cart,
    'id': Icons.search,
    'markings': Icons.label,
    'packaging': Icons.inventory_2,
    'barcode': Icons.qr_code,
  };

  @override
  void initState() {
    super.initState();
    _selectedLabel = widget.currentLabel ?? 'sales';
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

  void _saveAndReturn() {
    Navigator.pop(context, {
      'imagePath': widget.imagePath,
      'label': _selectedLabel,
    });
  }

  void _showQuickSelector() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select Image Purpose',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: _labelDescriptions.length,
                itemBuilder: (context, index) {
                  final label = _labelDescriptions.keys.elementAt(index);
                  final description = _labelDescriptions[label]!;
                  final isSelected = _selectedLabel == label;

                  return Container(
                    margin: EdgeInsets.only(bottom: 8),
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedLabel = label;
                        });
                        Navigator.pop(context);
                      },
                      child: Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isSelected ? _getLabelColor(label).withOpacity(0.1) : Colors.grey[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? _getLabelColor(label) : Colors.grey[300]!,
                            width: isSelected ? 3 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: _getLabelColor(label),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                _labelIcons[label],
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                            SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    label.toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: isSelected ? _getLabelColor(label) : Colors.grey[700],
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    description,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey[600],
                                      height: 1.3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (isSelected)
                              Icon(
                                Icons.check_circle,
                                color: _getLabelColor(label),
                                size: 28,
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Classify Image'),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: _saveAndReturn,
            child: Text(
              'SAVE',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Image Preview
            Container(
              width: double.infinity,
              height: MediaQuery.of(context).size.height * 0.4,
              margin: EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!, width: 2),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.file(
                  File(widget.imagePath),
                  fit: BoxFit.contain,
                ),
              ),
            ),

            // Current Selection Display
            Container(
              margin: EdgeInsets.symmetric(horizontal: 16),
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _getLabelColor(_selectedLabel).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _getLabelColor(_selectedLabel)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _getLabelColor(_selectedLabel),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _labelIcons[_selectedLabel],
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Current: ${_selectedLabel.toUpperCase()}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: _getLabelColor(_selectedLabel),
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          _labelDescriptions[_selectedLabel]!,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 24),

            // Change Selection Button
            Container(
              margin: EdgeInsets.symmetric(horizontal: 16),
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _showQuickSelector,
                icon: Icon(Icons.edit),
                label: Text('Change Classification'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[600],
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),

            SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}