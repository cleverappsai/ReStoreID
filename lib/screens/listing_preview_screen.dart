import 'package:flutter/material.dart';
import 'dart:io';  // Add this missing import
import '../models/item_job.dart';

class ListingPreviewScreen extends StatefulWidget {
  final ItemJob job;

  const ListingPreviewScreen({Key? key, required this.job}) : super(key: key);

  @override
  State<ListingPreviewScreen> createState() => _ListingPreviewScreenState();
}

class _ListingPreviewScreenState extends State<ListingPreviewScreen> {
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _startingPriceController;
  late TextEditingController _buyItNowPriceController;

  @override
  void initState() {
    super.initState();
    
    final result = widget.job.result;
    _titleController = TextEditingController(
      text: result?.productName ?? 'Item for Sale',
    );
    _descriptionController = TextEditingController(
      text: result?.suggestedDescription ?? 'Description needed',
    );
    _startingPriceController = TextEditingController(
      text: result?.pricing.suggestedStartingPrice?.toStringAsFixed(2) ?? '0.99',
    );
    _buyItNowPriceController = TextEditingController(
      text: result?.pricing.suggestedBuyItNowPrice?.toStringAsFixed(2) ?? '9.99',
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _startingPriceController.dispose();
    _buyItNowPriceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('eBay Listing Preview'),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: _exportListing,
            child: Text(
              'Export',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildImageSection(),
            SizedBox(height: 20),
            _buildListingForm(),
            SizedBox(height: 20),
            _buildPricingSection(),
            SizedBox(height: 20),
            _buildConfidenceIndicators(),
          ],
        ),
      ),
    );
  }

  Widget _buildImageSection() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Images',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            SizedBox(height: 12),
            Container(
              height: 120,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: widget.job.images.length,
                itemBuilder: (context, index) {
                  final image = widget.job.images[index];
                  return Container(
                    width: 120,
                    margin: EdgeInsets.only(right: 8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        File(image.filePath),
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.grey[200],
                            child: Icon(Icons.broken_image),
                          );
                        },
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

  Widget _buildListingForm() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Listing Details',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            SizedBox(height: 16),
            TextFormField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(),
                counterText: '${_titleController.text.length}/80',
              ),
              maxLength: 80,
            ),
            SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              decoration: InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              maxLines: 6,
              minLines: 4,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPricingSection() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pricing',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _startingPriceController,
                    decoration: InputDecoration(
                      labelText: 'Starting Price',
                      prefixText: '\$',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _buyItNowPriceController,
                    decoration: InputDecoration(
                      labelText: 'Buy It Now Price',
                      prefixText: '\$',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
              ],
            ),
            if (widget.job.result?.pricing.references.isNotEmpty ?? false) ...[
              SizedBox(height: 16),
              Text(
                'Price References',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              SizedBox(height: 8),
              ...widget.job.result!.pricing.references.take(3).map(
                (ref) => ListTile(
                  dense: true,
                  title: Text(ref.source),
                  subtitle: Text(ref.condition),
                  trailing: Text(
                    '\$${ref.price.toStringAsFixed(2)}',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildConfidenceIndicators() {
    final result = widget.job.result;
    if (result == null) return Container();

    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Analysis Confidence',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            SizedBox(height: 16),
            _buildConfidenceBar(
              'Overall Confidence',
              result.overallConfidence,
            ),
            SizedBox(height: 8),
            _buildConfidenceBar(
              'Pricing Confidence',
              result.pricing.confidence,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfidenceBar(String label, double confidence) {
    Color color = confidence >= 0.8
        ? Colors.green
        : confidence >= 0.6
            ? Colors.orange
            : Colors.red;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label),
            Text(
              '${(confidence * 100).toInt()}%',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        SizedBox(height: 4),
        LinearProgressIndicator(
          value: confidence,
          backgroundColor: Colors.grey[300],
          valueColor: AlwaysStoppedAnimation<Color>(color),
        ),
      ],
    );
  }

  void _exportListing() {
    // TODO: Implement export functionality
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Export functionality coming soon!'),
        backgroundColor: Colors.blue[600],
      ),
    );
  }
}