// ========================================
// lib/screens/results_screen.dart
// ========================================
import 'package:flutter/material.dart';
import 'dart:io';
import '../models/item_job.dart';

class ResultsScreen extends StatelessWidget {
  final ItemJob job;

  const ResultsScreen({Key? key, required this.job}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final result = job.analysisResult!;
    final product = result['product'];
    final specifications = result['specifications'];
    final pricing = result['pricing'];
    final analysis = result['analysis'];

    return Scaffold(
      appBar: AppBar(
        title: Text('Analysis Results'),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.share),
            onPressed: () {
              // Implement sharing functionality
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Sharing functionality would be implemented here')),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Images
            if (job.imagePaths.isNotEmpty) ...[
              Card(
                elevation: 4,
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Images',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 12),
                      Container(
                        height: 100,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: job.imagePaths.length,
                          itemBuilder: (context, index) {
                            return Container(
                              width: 100,
                              margin: EdgeInsets.only(right: 8),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.file(
                                  File(job.imagePaths[index]),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 16),
            ],

            // Product Information
            _buildProductCard(context, product),
            SizedBox(height: 16),

            // Specifications
            _buildSpecificationsCard(context, specifications),
            SizedBox(height: 16),

            // Pricing
            _buildPricingCard(context, pricing),
            SizedBox(height: 16),

            // Analysis Info
            _buildAnalysisCard(context, analysis),
          ],
        ),
      ),
    );
  }

  Widget _buildProductCard(BuildContext context, Map<String, dynamic> product) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Product Information',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blue[700],
              ),
            ),
            SizedBox(height: 12),
            _buildInfoRow('Name', product['name']),
            _buildInfoRow('Brand', product['brand']),
            _buildInfoRow('Category', product['category']),
            _buildInfoRow('Condition', product['condition']),
            if (product['description'] != null) ...[
              SizedBox(height: 8),
              Text(
                'Description:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 4),
              Text(product['description']),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSpecificationsCard(BuildContext context, Map<String, dynamic> specs) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Specifications',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.green[700],
              ),
            ),
            SizedBox(height: 12),
            ...specs.entries.map((entry) =>
                _buildInfoRow(entry.key, entry.value.toString())).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildPricingCard(BuildContext context, Map<String, dynamic> pricing) {
    final priceRange = pricing['priceRange'];
    final references = pricing['references'] as List;

    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pricing Analysis',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.orange[700],
              ),
            ),
            SizedBox(height: 12),

            // Estimated Value
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange[200]!),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Estimated Value',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '\$${pricing['estimatedValue'].toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange[700],
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 12),

            _buildInfoRow('Price Range',
                '\$${priceRange['low'].toStringAsFixed(2)} - \$${priceRange['high'].toStringAsFixed(2)}'),
            _buildInfoRow('Confidence',
                '${(pricing['confidence'] * 100).toInt()}%'),

            SizedBox(height: 16),

            Text(
              'Price References',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 8),

            ...references.take(3).map((ref) => _buildPriceReferenceRow(context, ref)).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalysisCard(BuildContext context, Map<String, dynamic> analysis) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Analysis Details',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.purple[700],
              ),
            ),
            SizedBox(height: 12),
            _buildInfoRow('Confidence', '${(analysis['confidence'] * 100).toInt()}%'),
            _buildInfoRow('Processing Time', analysis['processingTime']),
            _buildInfoRow('Images Processed', analysis['imagesProcessed'].toString()),
            _buildInfoRow('Data Source', analysis['dataSource']),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceReferenceRow(BuildContext context, Map<String, dynamic> ref) {
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                ref['source'],
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              Text(
                ref['condition'],
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          Text(
            '\$${ref['price'].toStringAsFixed(2)}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Colors.green[700],
            ),
          ),
        ],
      ),
    );
  }
}