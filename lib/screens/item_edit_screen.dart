// ========================================
// lib/screens/item_edit_screen.dart
// ========================================
import 'package:flutter/material.dart';
import '../models/item_job.dart';
import '../services/storage_service.dart';

class ItemEditScreen extends StatefulWidget {
  final ItemJob item;

  const ItemEditScreen({Key? key, required this.item}) : super(key: key);

  @override
  _ItemEditScreenState createState() => _ItemEditScreenState();
}

class _ItemEditScreenState extends State<ItemEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _userDescriptionController;
  late TextEditingController _searchDescriptionController;
  late TextEditingController _lengthController;
  late TextEditingController _widthController;
  late TextEditingController _heightController;
  late TextEditingController _weightController;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _userDescriptionController = TextEditingController(text: widget.item.userDescription);
    _searchDescriptionController = TextEditingController(text: widget.item.searchDescription);
    _lengthController = TextEditingController(text: widget.item.length ?? '');
    _widthController = TextEditingController(text: widget.item.width ?? '');
    _heightController = TextEditingController(text: widget.item.height ?? '');
    _weightController = TextEditingController(text: widget.item.weight ?? '');
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final updatedItem = widget.item.copyWith(
        userDescription: _userDescriptionController.text.trim(),
        searchDescription: _searchDescriptionController.text.trim(),
        length: _lengthController.text.trim().isEmpty ? null : _lengthController.text.trim(),
        width: _widthController.text.trim().isEmpty ? null : _widthController.text.trim(),
        height: _heightController.text.trim().isEmpty ? null : _heightController.text.trim(),
        weight: _weightController.text.trim().isEmpty ? null : _weightController.text.trim(),
      );

      await StorageService.saveJob(updatedItem);

      Navigator.pop(context, updatedItem);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Item updated successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating item: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Edit Item'),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveChanges,
            child: Text(
              'SAVE',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // User Description
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

              // Measurements
              Text(
                'Measurements',
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
                    ),
                  ),
                ],
              ),

              SizedBox(height: 32),

              // Save Button
              Container(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveChanges,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[600],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isLoading
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
                      Text('Saving...'),
                    ],
                  )
                      : Text(
                    'Save Changes',
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
    super.dispose();
  }
}