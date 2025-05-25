// ========================================
// lib/screens/item_detail_screen.dart
// ========================================
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'dart:io';
import '../models/item_job.dart';
import '../services/storage_service.dart';
import 'image_processing_screen.dart';
import 'web_scraper_screen.dart';
import 'item_edit_screen.dart';

class ItemDetailScreen extends StatefulWidget {
  final ItemJob item;

  const ItemDetailScreen({Key? key, required this.item}) : super(key: key);

  @override
  _ItemDetailScreenState createState() => _ItemDetailScreenState();
}

class _ItemDetailScreenState extends State<ItemDetailScreen> {
  late ItemJob _currentItem;

  @override
  void initState() {
    super.initState();
    _currentItem = widget.item;
  }

  Future<void> _refreshItem() async {
    // Reload item from storage to get latest data
    final jobs = await StorageService.getAllJobs();
    final updatedItem = jobs.firstWhere((job) => job.id == _currentItem.id);
    setState(() {
      _currentItem = updatedItem;
    });
  }

  Future<void> _editImageClassification(String imagePath, String currentLabel) async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) => ImageProcessingScreen(
          imagePath: imagePath,
          currentLabel: currentLabel,
        ),
      ),
    );

    if (result != null) {
      final newLabel = result['label'] as String;

      // Update the image classification
      Map<String, List<String>> updatedClassification = Map.from(_currentItem.imageClassification ?? {});

      // Remove from old category
      for (String category in updatedClassification.keys) {
        updatedClassification[category]!.remove(imagePath);
      }

      // Add to new category
      if (!updatedClassification.containsKey(newLabel)) {
        updatedClassification[newLabel] = [];
      }
      updatedClassification[newLabel]!.add(imagePath);

      // Save updated item
      final updatedItem = _currentItem.copyWith(imageClassification: updatedClassification);
      await StorageService.saveJob(updatedItem);

      setState(() {
        _currentItem = updatedItem;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Image reclassified as $newLabel')),
      );
    }
  }

  Future<void> _editItem() async {
    final result = await Navigator.push<ItemJob>(
      context,
      MaterialPageRoute(
        builder: (context) => ItemEditScreen(item: _currentItem),
      ),
    );

    if (result != null) {
      setState(() {
        _currentItem = result;
      });
    }
  }

  Future<void> _cloneItem() async {
    final clonedItem = ItemJob(
      id: Uuid().v4(), // New ID
      userDescription: '${_currentItem.userDescription} (Copy)',
      searchDescription: _currentItem.searchDescription,
      length: _currentItem.length,
      width: _currentItem.width,
      height: _currentItem.height,
      weight: _currentItem.weight,
      images: List.from(_currentItem.images), // Copy image list
      createdAt: DateTime.now(), // New creation time
      imageClassification: _currentItem.imageClassification != null
          ? Map<String, List<String>>.from(_currentItem.imageClassification!.map((k, v) => MapEntry(k, List<String>.from(v))))
          : null,
      // Don't copy processing results - new item needs fresh processing
    );

    await StorageService.saveJob(clonedItem);

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => ItemDetailScreen(item: clonedItem),
      ),
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Item cloned successfully')),
    );
  }

  Future<void> _deleteItem() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Item'),
        content: Text('Are you sure you want to delete this item? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await StorageService.deleteJob(_currentItem.id);
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Item deleted')),
      );
    }
  }

  void _openWebScraper(String url, String title) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WebScraperScreen(
          url: url,
          title: title,
          onDataScrapped: (scrapedData) {
            _addScrapedData(scrapedData);
          },
        ),
      ),
    );
  }

  void _addScrapedData(Map<String, dynamic> scrapedData) {
    // Add scraped data to item's analysis result for AI processing
    Map<String, dynamic> updatedAnalysis = Map.from(_currentItem.analysisResult ?? {});

    if (!updatedAnalysis.containsKey('scrapedSources')) {
      updatedAnalysis['scrapedSources'] = [];
    }

    updatedAnalysis['scrapedSources'].add({
      'timestamp': DateTime.now().toIso8601String(),
      'data': scrapedData,
    });

    final updatedItem = _currentItem.copyWith(analysisResult: updatedAnalysis);
    StorageService.saveJob(updatedItem);

    setState(() {
      _currentItem = updatedItem;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Data added to item sources')),
    );
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

  Widget _buildImageGrid() {
    if (_currentItem.imageClassification == null || _currentItem.imageClassification!.isEmpty) {
      return Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('No images classified yet'),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _currentItem.imageClassification!.entries.map((entry) {
        final category = entry.key;
        final imagePaths = entry.value;

        if (imagePaths.isEmpty) return SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _getLabelColor(category),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${category.toUpperCase()} (${imagePaths.length})',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
            SizedBox(height: 8),
            Container(
              height: 120,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: imagePaths.length,
                itemBuilder: (context, index) {
                  final imagePath = imagePaths[index];
                  return Container(
                    width: 120,
                    margin: EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onDoubleTap: () => _editImageClassification(imagePath, category),
                      child: Stack(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: _getLabelColor(category), width: 2),
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
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            SizedBox(height: 16),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildSearchResults() {
    final analysisResult = _currentItem.analysisResult;
    if (analysisResult == null) return SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Search Results',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 16),

        // Show candidate matches with low confidence
        if (analysisResult['candidateMatches'] != null)
          _buildCandidateMatches(analysisResult['candidateMatches']),

        // Show analysis data
        if (analysisResult['analysis'] != null)
          _buildAnalysisSection(analysisResult['analysis']),
      ],
    );
  }

  Widget _buildCandidateMatches(List<dynamic> candidates) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Candidate Matches (Review Required)',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange[700]),
            ),
            SizedBox(height: 12),
            ...candidates.map((candidate) => ListTile(
              leading: candidate['imageUrl'] != null
                  ? Image.network(candidate['imageUrl'], width: 50, height: 50, fit: BoxFit.cover)
                  : Icon(Icons.image),
              title: Text(candidate['title'] ?? 'Unknown Product'),
              subtitle: Text('Confidence: ${((candidate['confidence'] ?? 0.0) * 100).toInt()}%'),
              trailing: ElevatedButton(
                onPressed: () => _openWebScraper(candidate['url'], candidate['title']),
                child: Text('Review'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
              ),
            )).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalysisSection(Map<String, dynamic> analysis) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Analysis Results',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            if (analysis['confidence'] != null)
              Text('Overall Confidence: ${(analysis['confidence'] * 100).toInt()}%'),
            if (analysis['ocrText'] != null)
              Text('Extracted Text: ${analysis['ocrText']}'),
            if (analysis['barcodes'] != null && analysis['barcodes'].isNotEmpty)
              Text('Barcodes: ${analysis['barcodes'].join(', ')}'),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Item Details'),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'edit':
                  _editItem();
                  break;
                case 'clone':
                  _cloneItem();
                  break;
                case 'delete':
                  _deleteItem();
                  break;
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit), SizedBox(width: 8), Text('Edit')])),
              PopupMenuItem(value: 'clone', child: Row(children: [Icon(Icons.copy), SizedBox(width: 8), Text('Clone')])),
              PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete), SizedBox(width: 8), Text('Delete')])),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Item Header
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _currentItem.userDescription,
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Search Keywords: ${_currentItem.searchDescription}',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    if (_currentItem.measurementsDisplay != 'No measurements') ...[
                      SizedBox(height: 8),
                      Text(
                        'Measurements: ${_currentItem.measurementsDisplay}',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                    SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.schedule, size: 16, color: Colors.grey[600]),
                        SizedBox(width: 4),
                        Text(
                          'Created: ${_currentItem.createdAt.toString().split('.')[0]}',
                          style: TextStyle(color: Colors.grey[600], fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 16),

            // Images Section
            Text(
              'Images (Double-tap to reclassify)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            _buildImageGrid(),

            SizedBox(height: 24),

            // Search Results
            _buildSearchResults(),
          ],
        ),
      ),
    );
  }
}