// ========================================
// lib/screens/analysis_results_screen.dart
// ========================================
import 'package:flutter/material.dart';
import '../models/item_job.dart';
import '../services/storage_service.dart';
// import '../services/summary_generation_service.dart';
import 'web_scraper_screen.dart';

class AnalysisResultsScreen extends StatefulWidget {
  final ItemJob item;

  const AnalysisResultsScreen({Key? key, required this.item}) : super(key: key);

  @override
  _AnalysisResultsScreenState createState() => _AnalysisResultsScreenState();
}

class _AnalysisResultsScreenState extends State<AnalysisResultsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late ItemJob _currentItem;

  // Editable controllers
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _estimatedValueController;
  List<TextEditingController> _specControllers = [];
  List<TextEditingController> _featureControllers = [];

  bool _isLoading = false;
  bool _hasUnsavedChanges = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _currentItem = widget.item;
    _initializeControllers();
  }

  void _initializeControllers() {
    final analysisResult = _currentItem.analysisResult;
    final summary = analysisResult?['summary'] as Map<String, dynamic>?;
    final pricing = analysisResult?['pricing'] as Map<String, dynamic>?;

    _titleController = TextEditingController(
      text: summary?['itemTitle'] ?? _currentItem.userDescription,
    );
    _descriptionController = TextEditingController(
      text: summary?['description'] ?? 'Analysis in progress...',
    );
    _estimatedValueController = TextEditingController(
      text: pricing?['estimatedValue']?.toStringAsFixed(2) ?? '0.00',
    );

    // Initialize spec controllers
    final specs = summary?['specifications'] as List? ?? [];
    for (int i = 0; i < specs.length; i++) {
      _specControllers.add(TextEditingController(text: specs[i]));
    }

    // Initialize feature controllers
    final features = summary?['keyFeatures'] as List? ?? [];
    for (int i = 0; i < features.length; i++) {
      _featureControllers.add(TextEditingController(text: features[i]));
    }

    // Add listeners for unsaved changes
    _titleController.addListener(_onTextChanged);
    _descriptionController.addListener(_onTextChanged);
    _estimatedValueController.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    if (!_hasUnsavedChanges) {
      setState(() {
        _hasUnsavedChanges = true;
      });
    }
  }

  Future<void> _saveChanges() async {
    setState(() => _isLoading = true);

    try {
      final analysisResult = Map<String, dynamic>.from(_currentItem.analysisResult ?? {});

      // Update summary
      final updatedSummary = {
        ...analysisResult['summary'] ?? {},
        'itemTitle': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'specifications': _specControllers.map((c) => c.text.trim()).where((s) => s.isNotEmpty).toList(),
        'keyFeatures': _featureControllers.map((c) => c.text.trim()).where((f) => f.isNotEmpty).toList(),
        'lastEditedAt': DateTime.now().toIso8601String(),
        'userEdited': true,
      };

      // Update pricing
      final updatedPricing = {
        ...analysisResult['pricing'] ?? {},
        'estimatedValue': double.tryParse(_estimatedValueController.text) ?? 0.0,
        'lastEditedAt': DateTime.now().toIso8601String(),
        'userEdited': true,
      };

      analysisResult['summary'] = updatedSummary;
      analysisResult['pricing'] = updatedPricing;

      final updatedItem = _currentItem.copyWith(analysisResult: analysisResult);
      await StorageService.saveJob(updatedItem);

      setState(() {
        _currentItem = updatedItem;
        _hasUnsavedChanges = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Changes saved successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving changes: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _regenerateSummary() async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Summary regeneration coming soon!')),
    );
  }

  List<Map<String, dynamic>> _collectDataSources() {
    List<Map<String, dynamic>> sources = [];
    final analysisResult = _currentItem.analysisResult;

    if (analysisResult != null) {
      // Add scraped sources
      final scrapedSources = analysisResult['scrapedSources'] as List? ?? [];
      for (var source in scrapedSources) {
        if (source['data'] != null) {
          sources.add(source['data']);
        }
      }

      // Add OCR data
      if (_currentItem.ocrResults?.isNotEmpty == true) {
        sources.add({
          'url': 'local://ocr',
          'title': 'OCR Data',
          'fullText': _currentItem.ocrResults!.values.join('\n'),
          'scrapedAt': DateTime.now().toIso8601String(),
          'confidence': 0.7,
          'dataType': 'ocr',
        });
      }
    }

    return sources;
  }

  void _addSpecification() {
    setState(() {
      _specControllers.add(TextEditingController());
      _hasUnsavedChanges = true;
    });
  }

  void _removeSpecification(int index) {
    setState(() {
      _specControllers[index].dispose();
      _specControllers.removeAt(index);
      _hasUnsavedChanges = true;
    });
  }

  void _addFeature() {
    setState(() {
      _featureControllers.add(TextEditingController());
      _hasUnsavedChanges = true;
    });
  }

  void _removeFeature(int index) {
    setState(() {
      _featureControllers[index].dispose();
      _featureControllers.removeAt(index);
      _hasUnsavedChanges = true;
    });
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
    final analysisResult = Map<String, dynamic>.from(_currentItem.analysisResult ?? {});

    if (!analysisResult.containsKey('scrapedSources')) {
      analysisResult['scrapedSources'] = [];
    }

    analysisResult['scrapedSources'].add({
      'timestamp': DateTime.now().toIso8601String(),
      'data': scrapedData,
    });

    final updatedItem = _currentItem.copyWith(analysisResult: analysisResult);
    StorageService.saveJob(updatedItem);

    setState(() {
      _currentItem = updatedItem;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Data added to item sources')),
    );
  }

  Widget _buildSummaryTab() {
    final hasAnalysis = _currentItem.analysisResult?['summary'] != null;

    if (!hasAnalysis) {
      return Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.pending_actions, size: 64, color: Colors.grey[400]),
            SizedBox(height: 16),
            Text(
              'Analysis Not Complete',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'This item needs to be analyzed to generate a summary.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
            SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Analysis features coming soon!')),
                );
              },
              icon: Icon(Icons.psychology),
              label: Text('Analyze Item'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[600],
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      );
    }

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
            decoration: InputDecoration(border: OutlineInputBorder()),
            maxLines: 2,
          ),

          SizedBox(height: 20),

          // Description
          Text('Description', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          SizedBox(height: 8),
          TextFormField(
            controller: _descriptionController,
            decoration: InputDecoration(border: OutlineInputBorder()),
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
              IconButton(onPressed: _addSpecification, icon: Icon(Icons.add)),
            ],
          ),
          SizedBox(height: 16),

          if (_specControllers.isEmpty)
            Center(child: Text('No specifications yet'))
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
                          prefixText: '• ',
                        ),
                        maxLines: 2,
                        onChanged: (_) => _onTextChanged(),
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
              IconButton(onPressed: _addFeature, icon: Icon(Icons.add)),
            ],
          ),
          SizedBox(height: 16),

          if (_featureControllers.isEmpty)
            Center(child: Text('No features yet'))
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
                          prefixText: '• ',
                        ),
                        maxLines: 2,
                        onChanged: (_) => _onTextChanged(),
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

  Widget _buildSourcesTab() {
    final analysisResult = _currentItem.analysisResult;
    final scrapedSources = analysisResult?['scrapedSources'] as List? ?? [];
    final candidateMatches = analysisResult?['candidateMatches'] as List? ?? [];

    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Pricing
          Text('Estimated Value', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          SizedBox(height: 8),
          TextFormField(
            controller: _estimatedValueController,
            decoration: InputDecoration(
              border: OutlineInputBorder(),
              prefixText: '\$',
            ),
            keyboardType: TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => _onTextChanged(),
          ),

          SizedBox(height: 24),

          // Candidate matches for web scraping
          if (candidateMatches.isNotEmpty) ...[
            Text('Web Sources to Review', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            SizedBox(height: 12),
            ...candidateMatches.map((candidate) => Card(
              margin: EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(candidate['title'] ?? 'Unknown Source'),
                subtitle: Text('Confidence: ${((candidate['confidence'] ?? 0.0) * 100).toInt()}%'),
                trailing: ElevatedButton(
                  onPressed: () => _openWebScraper(candidate['url'], candidate['title']),
                  child: Text('USE'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                ),
              ),
            )).toList(),
            SizedBox(height: 24),
          ],

          // Scraped sources
          if (scrapedSources.isNotEmpty) ...[
            Text('Data Sources Used', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            SizedBox(height: 12),
            ...scrapedSources.map((source) {
              final data = source['data'] as Map<String, dynamic>;
              return Card(
                margin: EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(data['title'] ?? 'Unknown Source'),
                  subtitle: Text('Scraped: ${source['timestamp'] ?? 'Unknown time'}'),
                  trailing: Icon(Icons.check_circle, color: Colors.green),
                ),
              );
            }).toList(),
          ],

          if (scrapedSources.isEmpty && candidateMatches.isEmpty)
            Center(
              child: Column(
                children: [
                  Icon(Icons.web, size: 48, color: Colors.grey[400]),
                  SizedBox(height: 16),
                  Text(
                    'No web sources available yet',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Run image searches to find candidate websites for scraping',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _disposeControllers() {
    _titleController.dispose();
    _descriptionController.dispose();
    _estimatedValueController.dispose();
    for (var controller in _specControllers) {
      controller.dispose();
    }
    for (var controller in _featureControllers) {
      controller.dispose();
    }
    _specControllers.clear();
    _featureControllers.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Analysis Results'),
        backgroundColor: Colors.green[600],
        foregroundColor: Colors.white,
        actions: [
          if (_hasUnsavedChanges)
            TextButton(
              onPressed: _isLoading ? null : _saveChanges,
              child: Text('SAVE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'regenerate') {
               // _regenerateSummary();
              }
            },
            itemBuilder: (context) => [
              if (_currentItem.analysisResult?['summary'] != null)
                PopupMenuItem(
                  value: 'regenerate',
                  child: Row(
                    children: [
                      Icon(Icons.refresh),
                      SizedBox(width: 8),
                      Text('Regenerate'),
                    ],
                  ),
                ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(text: 'Summary'),
            Tab(text: 'Specs'),
            Tab(text: 'Features'),
            Tab(text: 'Sources'),
          ],
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : TabBarView(
        controller: _tabController,
        children: [
          _buildSummaryTab(),
          _buildSpecsTab(),
          _buildFeaturesTab(),
          _buildSourcesTab(),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _disposeControllers();
    super.dispose();
  }
}