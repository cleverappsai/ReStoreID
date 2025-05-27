// ========================================
// lib/screens/analysis_results_screen.dart (Complete Enhanced Version)
// ========================================
import 'package:flutter/material.dart';
import 'dart:async';
import '../models/item_job.dart';
import '../services/storage_service.dart';
import '../services/enhanced_analysis_service.dart';
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
  Timer? _refreshTimer;

  // Editable controllers
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _estimatedValueController;
  List<TextEditingController> _specControllers = [];
  List<TextEditingController> _featureControllers = [];

  bool _isLoading = false;
  bool _hasUnsavedChanges = false;
  bool _isAnalyzing = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _currentItem = widget.item;
    _initializeControllers();
    _checkAnalysisStatus();
  }

  void _initializeControllers() {
    final analysisResult = _currentItem.analysisResult;
    final summary = analysisResult?['summary'] as Map<String, dynamic>?;
    final pricing = analysisResult?['pricing'] as Map<String, dynamic>?;

    _titleController = TextEditingController(
      text: summary?['itemTitle'] ?? _currentItem.userDescription,
    );
    _descriptionController = TextEditingController(
      text: summary?['description'] ?? '',
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

  void _checkAnalysisStatus() async {
    final status = EnhancedAnalysisService.getAnalysisStatus(_currentItem);

    if (status['status'] == 'pending' || status['status'] == 'in_progress') {
      setState(() => _isAnalyzing = true);

      // Start timer to check for updates
      _refreshTimer = Timer.periodic(Duration(seconds: 3), (timer) async {
        final updatedItem = await StorageService.getJob(_currentItem.id);
        if (updatedItem != null) {
          final newStatus = EnhancedAnalysisService.getAnalysisStatus(updatedItem);
          if (newStatus['status'] == 'completed') {
            timer.cancel();
            setState(() {
              _currentItem = updatedItem;
              _isAnalyzing = false;
            });
            _reinitializeControllers();
          }
        }
      });
    }
  }

  void _reinitializeControllers() {
    // Dispose old controllers
    _disposeControllers();

    // Initialize with new data
    _initializeControllers();

    setState(() {});
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

  Future<void> _triggerEnhancedAnalysis() async {
    setState(() => _isAnalyzing = true);

    try {
      // Trigger enhanced analysis
      EnhancedAnalysisService.triggerBackgroundAnalysis(_currentItem);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Enhanced analysis started...'),
          action: SnackBarAction(
            label: 'VIEW STATUS',
            onPressed: () => _showAnalysisProgress(),
          ),
        ),
      );

      // Start timer to check progress
      _refreshTimer = Timer.periodic(Duration(seconds: 3), (timer) async {
        final updatedItem = await StorageService.getJob(_currentItem.id);
        if (updatedItem != null) {
          final status = EnhancedAnalysisService.getAnalysisStatus(updatedItem);
          if (status['status'] == 'completed') {
            timer.cancel();
            setState(() {
              _currentItem = updatedItem;
              _isAnalyzing = false;
            });
            _reinitializeControllers();

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Enhanced analysis completed!'),
                backgroundColor: Colors.green,
              ),
            );
          }
        }
      });

    } catch (e) {
      setState(() => _isAnalyzing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error starting analysis: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showAnalysisProgress() {
    final status = EnhancedAnalysisService.getAnalysisStatus(_currentItem);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Analysis Progress'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Status: ${status['status']}'),
            SizedBox(height: 8),
            if (status['completedSteps'] != null) ...[
              Text('Completed:', style: TextStyle(fontWeight: FontWeight.bold)),
              ...List<String>.from(status['completedSteps']).map(
                    (step) => Text('✓ $step', style: TextStyle(color: Colors.green)),
              ),
            ],
            if (status['pendingSteps'] != null && status['pendingSteps'].isNotEmpty) ...[
              SizedBox(height: 8),
              Text('Pending:', style: TextStyle(fontWeight: FontWeight.bold)),
              ...List<String>.from(status['pendingSteps']).map(
                    (step) => Text('• $step', style: TextStyle(color: Colors.orange)),
              ),
            ],
            SizedBox(height: 12),
            LinearProgressIndicator(
              value: status['progress'] ?? 0.0,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _regenerateSummary() async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Regenerate Summary'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Add specific guidance for the AI summary generation:'),
            SizedBox(height: 12),
            TextField(
              decoration: InputDecoration(
                hintText: 'e.g., Focus on technical specifications',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              onChanged: (value) {
                // Store the guidance
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'regenerate'),
            child: Text('Regenerate'),
          ),
        ],
      ),
    );

    if (result == 'regenerate') {
      setState(() => _isLoading = true);

      try {
        final regenerateResult = await EnhancedAnalysisService.regenerateSummary(_currentItem);

        if (regenerateResult['success'] == true) {
          final updatedItem = await StorageService.getJob(_currentItem.id);
          if (updatedItem != null) {
            setState(() => _currentItem = updatedItem);
            _reinitializeControllers();

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Summary regenerated successfully!'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error regenerating summary: ${regenerateResult['error']}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error regenerating summary: $e'),
            backgroundColor: Colors.red,
          ),
        );
      } finally {
        setState(() => _isLoading = false);
      }
    }
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

    if (_isAnalyzing) {
      return _buildAnalyzingState();
    }

    if (!hasAnalysis) {
      return _buildAnalysisPrompt();
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Enhanced Analysis Badge
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.green[100],
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.green[300]!),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.auto_awesome, size: 16, color: Colors.green[700]),
                SizedBox(width: 4),
                Text(
                  'Enhanced Analysis',
                  style: TextStyle(
                    color: Colors.green[700],
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 16),

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

          SizedBox(height: 20),

          // Analysis Quality Indicator
          _buildAnalysisQualityIndicator(),
        ],
      ),
    );
  }

  Widget _buildAnalyzingState() {
    final status = EnhancedAnalysisService.getAnalysisStatus(_currentItem);

    return Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
            ),
            SizedBox(height: 24),
            Text(
              'Enhanced Analysis in Progress',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Using AI to analyze your item...',
              style: TextStyle(color: Colors.grey[600]),
            ),
            SizedBox(height: 16),
            LinearProgressIndicator(
              value: status['progress'] ?? 0.0,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
            ),
            SizedBox(height: 8),
            Text(
              'Progress: ${((status['progress'] ?? 0.0) * 100).toInt()}%',
              style: TextStyle(color: Colors.grey[600]),
            ),
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: _showAnalysisProgress,
              child: Text('View Details'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalysisPrompt() {
    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.auto_awesome, size: 64, color: Colors.blue[400]),
          SizedBox(height: 16),
          Text(
            'Enhanced Analysis Available',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            'Get detailed product information, specifications, and pricing using our enhanced AI analysis system.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[600]),
          ),
          SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _triggerEnhancedAnalysis,
            icon: Icon(Icons.psychology),
            label: Text('Start Enhanced Analysis'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[600],
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
          SizedBox(height: 16),
          Text(
            'This will use OCR, targeted searches, and AI to generate a comprehensive analysis.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[500], fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalysisQualityIndicator() {
    if (_currentItem.analysisResult == null) return SizedBox.shrink();

    final validation = EnhancedAnalysisService.validateAnalysisResults(_currentItem);
    final confidence = validation['overallConfidence'] ?? 0.0;

    Color confidenceColor = confidence > 0.7 ? Colors.green :
    confidence > 0.4 ? Colors.orange : Colors.red;

    return Card(
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.analytics, color: confidenceColor, size: 20),
                SizedBox(width: 8),
                Text(
                  'Analysis Quality',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Spacer(),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: confidenceColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: confidenceColor.withOpacity(0.3)),
                  ),
                  child: Text(
                    '${(confidence * 100).toInt()}%',
                    style: TextStyle(
                      color: confidenceColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),

            if (validation['issues'] != null && validation['issues'].isNotEmpty) ...[
              SizedBox(height: 8),
              ...List<String>.from(validation['issues']).map(
                    (issue) => Padding(
                  padding: EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Icon(Icons.warning, size: 16, color: Colors.orange),
                      SizedBox(width: 4),
                      Expanded(child: Text(issue, style: TextStyle(fontSize: 12))),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
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
    final rawData = analysisResult?['rawData'] as Map<String, dynamic>?;

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

          // Enhanced Analysis Sources
          if (rawData != null && rawData['searchResults'] != null) ...[
            Text('Enhanced Analysis Sources', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            SizedBox(height: 12),
            _buildEnhancedSourcesSummary(rawData),
            SizedBox(height: 24),
          ],

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

          if (scrapedSources.isEmpty && candidateMatches.isEmpty && rawData == null)
            Center(
              child: Column(
                children: [
                  Icon(Icons.web, size: 48, color: Colors.grey[400]),
                  SizedBox(height: 16),
                  Text(
                    'No sources available yet',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Run enhanced analysis to find authoritative sources',
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

  Widget _buildEnhancedSourcesSummary(Map<String, dynamic> rawData) {
    final searchResults = rawData['searchResults'] as Map<String, dynamic>?;
    final contentSummary = rawData['scrapedContent'] as Map<String, dynamic>?;

    return Card(
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (searchResults != null) ...[
              Row(
                children: [
                  Icon(Icons.search, color: Colors.blue, size: 16),
                  SizedBox(width: 4),
                  Text('Searches: ${searchResults['searchCount'] ?? 0} performed'),
                ],
              ),
              Row(
                children: [
                  Icon(Icons.link, color: Colors.green, size: 16),
                  SizedBox(width: 4),
                  Text('Results: ${searchResults['resultsFound'] ?? 0} found'),
                ],
              ),
            ],
            if (contentSummary != null) ...[
              SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.web, color: Colors.orange, size: 16),
                  SizedBox(width: 4),
                  Text('Content: ${contentSummary['contentScraped'] ?? 0} sources scraped'),
                ],
              ),
            ],
          ],
        ),
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
                _regenerateSummary();
              } else if (value == 'analyze') {
                _triggerEnhancedAnalysis();
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
                      Text('Regenerate Summary'),
                    ],
                  ),
                ),
              PopupMenuItem(
                value: 'analyze',
                child: Row(
                  children: [
                    Icon(Icons.auto_awesome),
                    SizedBox(width: 8),
                    Text('Enhanced Analysis'),
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
    _refreshTimer?.cancel();
    _disposeControllers();
    super.dispose();
  }
}