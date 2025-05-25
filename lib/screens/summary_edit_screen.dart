// ========================================
// lib/screens/summary_edit_screen.dart
// ========================================
import 'package:flutter/material.dart';
import '../models/item_job.dart';
import '../services/storage_service.dart';

class SummaryEditScreen extends StatefulWidget {
  final ItemJob item;

  const SummaryEditScreen({Key? key, required this.item}) : super(key: key);

  @override
  _SummaryEditScreenState createState() => _SummaryEditScreenState();
}

class _SummaryEditScreenState extends State<SummaryEditScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Controllers for editable content
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _quantityController;
  late TextEditingController _estimatedValueController;

  List<TextEditingController> _specControllers = [];
  List<TextEditingController> _featureControllers = [];
  List<Map<String, dynamic>> _editablePrices = [];

  bool _isLoading = false;
  Map<String, dynamic>? _summaryData;
  Map<String, dynamic>? _pricingData;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadSummaryData();
  }

  void _loadSummaryData() {
    final analysisResult = widget.item.analysisResult;
    if (analysisResult != null) {
      _summaryData = analysisResult['summary'];
      _pricingData = analysisResult['pricing'];
    }

    // Initialize controllers
    _titleController = TextEditingController(
        text: _summaryData?['itemTitle'] ?? widget.item.userDescription
    );
    _descriptionController = TextEditingController(
        text: _summaryData?['description'] ?? 'Description pending...'
    );
    _quantityController = TextEditingController(
        text: widget.item.quantity?.toString() ?? '1'
    );
    _estimatedValueController = TextEditingController(
        text: _pricingData?['estimatedValue']?.toStringAsFixed(2) ?? '0.00'
    );

    // Initialize specification controllers
    final specs = _summaryData?['specifications'] as List? ?? [];
    for (int i = 0; i < specs.length; i++) {
      _specControllers.add(TextEditingController(text: specs[i]));
    }

    // Initialize feature controllers
    final features = _summaryData?['keyFeatures'] as List? ?? [];
    for (int i = 0; i < features.length; i++) {
      _featureControllers.add(TextEditingController(text: features[i]));
    }

    // Initialize editable prices
    final priceBreakdown = _pricingData?['priceBreakdown'] as List? ?? [];
    _editablePrices = List<Map<String, dynamic>>.from(priceBreakdown);
  }

  Future<void> _saveSummary() async {
    setState(() => _isLoading = true);

    try {
      // Collect edited data
      final updatedSummary = {
        ..._summaryData ?? {},
        'itemTitle': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'specifications': _specControllers.map((c) => c.text.trim()).where((s) => s.isNotEmpty).toList(),
        'keyFeatures': _featureControllers.map((c) => c.text.trim()).where((f) => f.isNotEmpty).toList(),
        'lastEditedAt': DateTime.now().toIso8601String(),
        'userEdited': true,
      };

      final updatedPricing = {
        ..._pricingData ?? {},
        'estimatedValue': double.tryParse(_estimatedValueController.text) ?? 0.0,
        'priceBreakdown': _editablePrices,
        'lastEditedAt': DateTime.now().toIso8601String(),
        'userEdited': true,
      };

      // Update item
      final updatedAnalysisResult = {
        ...widget.item.analysisResult ?? {},
        'summary': updatedSummary,
        'pricing': updatedPricing,
      };

      final updatedItem = widget.item.copyWith(
        analysisResult: updatedAnalysisResult,
        quantity: int.tryParse(_quantityController.text) ?? 1,
      );

      await StorageService.saveJob(updatedItem);

      Navigator.pop(context, updatedItem);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Summary updated successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving summary: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _addSpecification() {
    setState(() {
      _specControllers.add(TextEditingController());
    });
  }

  void _removeSpecification(int index) {
    setState(() {
      _specControllers[index].dispose();
      _specControllers.removeAt(index);
    });
  }

  void _addFeature() {
    setState(() {
      _featureControllers.add(TextEditingController());
    });
  }

  void _removeFeature(int index) {
    setState(() {
      _featureControllers[index].dispose();
      _featureControllers.removeAt(index);
    });
  }

  Widget _buildInfoTab() {
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
            decoration: InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'Enter item title',
            ),
            maxLines: 2,
          ),

          SizedBox(height: 20),

          // Quantity
          Row(
            children: [
              Expanded(
                child: Text('Quantity', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
              SizedBox(
                width: 100,
                child: TextFormField(
                  controller: _quantityController,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: '1',
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),

          SizedBox(height: 20),

          // Description
          Text('Description', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          SizedBox(height: 8),
          TextFormField(
            controller: _descriptionController,
            decoration: InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'Enter item description',
            ),
            maxLines: 8,
          ),
        ],
      ),
    );
  }

  Widget _buildSpecsTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Specifications', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Spacer(),
              IconButton(
                onPressed: _addSpecification,
                icon: Icon(Icons.add),
                tooltip: 'Add Specification',
              ),
            ],
          ),
          SizedBox(height: 16),

          if (_specControllers.isEmpty)
            Center(
              child: Text('No specifications yet. Tap + to add one.'),
            )
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
                          hintText: 'Enter specification',
                          prefixText: '• ',
                        ),
                        maxLines: 2,
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
        ],
      ),
    );
  }

  Widget _buildFeaturesTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Key Features', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Spacer(),
              IconButton(
                onPressed: _addFeature,
                icon: Icon(Icons.add),
                tooltip: 'Add Feature',
              ),
            ],
          ),
          SizedBox(height: 16),

          if (_featureControllers.isEmpty)
            Center(
              child: Text('No features yet. Tap + to add one.'),
            )
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
                          hintText: 'Enter key feature',
                          prefixText: '• ',
                        ),
                        maxLines: 2,
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

  Widget _buildPricingTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Estimated Value
          Text('Estimated Value', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          SizedBox(height: 8),
          TextFormField(
            controller: _estimatedValueController,
            decoration: InputDecoration(
              border: OutlineInputBorder(),
              prefixText: '\$',
              hintText: '0.00',
            ),
            keyboardType: TextInputType.numberWithOptions(decimal: true),
          ),

          SizedBox(height: 24),

          // Price Sources
          Text('Price Sources', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          SizedBox(height: 12),

          if (_editablePrices.isEmpty)
            Text('No price data collected yet.')
          else
            ...List.generate(_editablePrices.length, (index) {
              final priceData = _editablePrices[index];
              return Card(
                margin: EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              priceData['source'] ?? 'Unknown Source',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                          Text(
                            '\$${priceData['price']?.toStringAsFixed(2) ?? '0.00'}',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.green[700],
                            ),
                          ),
                        ],
                      ),
                      if (priceData['condition'] != null)
                        Text(
                          'Condition: ${priceData['condition']}',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      if (priceData['url'] != null)
                        TextButton(
                          onPressed: () {
                            // Could open URL
                          },
                          child: Text('View Source', style: TextStyle(fontSize: 12)),
                        ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Edit Item Summary'),
        backgroundColor: Colors.green[600],
        foregroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveSummary,
            child: Text(
              'SAVE',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(text: 'Info'),
            Tab(text: 'Specs'),
            Tab(text: 'Features'),
            Tab(text: 'Pricing'),
          ],
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : TabBarView(
        controller: _tabController,
        children: [
          _buildInfoTab(),
          _buildSpecsTab(),
          _buildFeaturesTab(),
          _buildPricingTab(),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _quantityController.dispose();
    _estimatedValueController.dispose();

    for (var controller in _specControllers) {
      controller.dispose();
    }
    for (var controller in _featureControllers) {
      controller.dispose();
    }

    super.dispose();
  }
}