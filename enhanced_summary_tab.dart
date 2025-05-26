// ========================================
// lib/widgets/enhanced_summary_tab.dart
// ========================================
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/item_job.dart';
import '../services/enhanced_analysis_service.dart';
import '../services/storage_service.dart';

class EnhancedSummaryTab extends StatefulWidget {
  final ItemJob item;
  final Function(ItemJob) onItemUpdated;

  const EnhancedSummaryTab({
    Key? key,
    required this.item,
    required this.onItemUpdated,
  }) : super(key: key);

  @override
  State<EnhancedSummaryTab> createState() => _EnhancedSummaryTabState();
}

class _EnhancedSummaryTabState extends State<EnhancedSummaryTab> {
  bool _isAnalyzing = false;
  bool _isSummaryEdited = false;
  late TextEditingController _summaryController;
  String? _analysisError;

  @override
  void initState() {
    super.initState();
    _summaryController = TextEditingController(
      text: widget.item.targetedSearchResults?.summary ?? '',
    );
    _summaryController.addListener(_onSummaryChanged);
  }

  @override
  void dispose() {
    _summaryController.dispose();
    super.dispose();
  }

  void _onSummaryChanged() {
    setState(() {
      _isSummaryEdited = _summaryController.text !=
          (widget.item.targetedSearchResults?.summary ?? '');
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAnalysisHeader(),
          SizedBox(height: 16),

          if (!widget.item.hasTargetedSearchResults && !_isAnalyzing)
            _buildStartAnalysisCard()
          else if (_isAnalyzing)
            _buildAnalysisProgressCard()
          else if (_analysisError != null)
              _buildErrorCard()
            else
              _buildResultsSection(),
        ],
      ),
    );
  }

  Widget _buildAnalysisHeader() {
    return Row(
      children: [
        Icon(
          widget.item.hasTargetedSearchResults
              ? Icons.check_circle
              : Icons.search,
          color: widget.item.hasTargetedSearchResults
              ? Colors.green
              : Colors.orange,
        ),
        SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Product Analysis',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Text(
                widget.item.targetedSearchStatus,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        if (widget.item.hasTargetedSearchResults)
          PopupMenuButton<String>(
            onSelected: _handleMenuAction,
            itemBuilder: (context) => [
              PopupMenuItem(value: 'regenerate', child: Text('Regenerate Analysis')),
              PopupMenuItem(value: 'details', child: Text('View Details')),
            ],
            child: Icon(Icons.more_vert),
          ),
      ],
    );
  }

  Widget _buildStartAnalysisCard() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(
              Icons.auto_awesome,
              size: 48,
              color: Theme.of(context).primaryColor,
            ),
            SizedBox(height: 12),
            Text(
              'Smart Product Analysis',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            SizedBox(height: 8),
            Text(
              'Get detailed product identification, specifications, and market information using AI-powered search.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            SizedBox(height: 16),

            // Prerequisites check
            _buildPrerequisitesCheck(),

            SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _canStartAnalysis() ? _startAnalysis : null,
              icon: Icon(Icons.play_arrow),
              label: Text('Start Analysis'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrerequisitesCheck() {
    return Column(
      children: [
        _buildCheckItem(
          'Images captured',
          widget.item.images.isNotEmpty,
          widget.item.images.length.toString() + ' image(s)',
        ),
        _buildCheckItem(
          'OCR completed',
          widget.item.ocrCompleted,
          widget.item.ocrCompleted ? 'Text extracted' : 'Processing...',
        ),
        _buildCheckItem(
          'Network available',
          true, // Assume network is available
          'Ready for search',
        ),
      ],
    );
  }

  Widget _buildCheckItem(String label, bool isComplete, String subtitle) {
    return ListTile(
      dense: true,
      leading: Icon(
        isComplete ? Icons.check_circle : Icons.radio_button_unchecked,
        color: isComplete ? Colors.green : Colors.grey,
      ),
      title: Text(label),
      subtitle: Text(subtitle),
    );
  }

  bool _canStartAnalysis() {
    return widget.item.images.isNotEmpty &&
        widget.item.ocrCompleted &&
        !_isAnalyzing;
  }

  Widget _buildAnalysisProgressCard() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            StreamBuilder<AnalysisProgress>(
              stream: EnhancedAnalysisService.getAnalysisProgress(widget.item.id),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return CircularProgressIndicator();
                }

                final progress = snapshot.data!;

                if (progress.hasError) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    setState(() {
                      _isAnalyzing = false;
                      _analysisError = progress.error;
                    });
                  });
                  return Text('Analysis failed: ${progress.error}');
                }

                if (progress.isComplete && progress.results != null) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _onAnalysisComplete(progress.results!);
                  });
                }

                return Column(
                  children: [
                    LinearProgressIndicator(value: progress.progress),
                    SizedBox(height: 12),
                    Text(progress.step),
                    SizedBox(height: 16),
                    TextButton(
                      onPressed: _cancelAnalysis,
                      child: Text('Cancel'),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorCard() {
    return Card(
      color: Colors.red.shade50,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(Icons.error, color: Colors.red, size: 48),
            SizedBox(height: 12),
            Text(
              'Analysis Failed',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            SizedBox(height: 8),
            Text(
              _analysisError ?? 'Unknown error occurred',
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton(
                  onPressed: () => setState(() => _analysisError = null),
                  child: Text('Dismiss'),
                ),
                ElevatedButton(
                  onPressed: _startAnalysis,
                  child: Text('Retry'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsSection() {
    final results = widget.item.targetedSearchResults!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Summary Card
        Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.summarize),
                    SizedBox(width: 8),
                    Text(
                      'Analysis Summary',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Spacer(),
                    if (_isSummaryEdited)
                      Row(
                        children: [
                          TextButton(
                            onPressed: _resetSummary,
                            child: Text('Reset'),
                          ),
                          ElevatedButton(
                            onPressed: _saveSummary,
                            child: Text('Save'),
                          ),
                        ],
                      ),
                  ],
                ),
                SizedBox(height: 12),
                TextField(
                  controller: _summaryController,
                  maxLines: null,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Analysis summary will appear here...',
                  ),
                ),
              ],
            ),
          ),
        ),

        SizedBox(height: 16),

        // Quick Stats
        _buildQuickStats(results),

        SizedBox(height: 16),

        // Identified Products
        if (results.identifiedProducts.isNotEmpty)
          _buildIdentifiedProducts(results),

        SizedBox(height: 16),

        // Action Buttons
        _buildActionButtons(),
      ],
    );
  }

  Widget _buildQuickStats(TargetedSearchResults results) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: _buildStatItem(
                'Products Found',
                results.identifiedProducts.length.toString(),
                Icons.inventory,
              ),
            ),
            Expanded(
              child: _buildStatItem(
                'Confidence',
                '${(results.averageConfidence * 100).toInt()}%',
                Icons.trending_up,
              ),
            ),
            Expanded(
              child: _buildStatItem(
                'Sources',
                results.searchSources.length.toString(),
                Icons.source,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Theme.of(context).primaryColor),
        SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _buildIdentifiedProducts(TargetedSearchResults results) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Identified Products',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            SizedBox(height: 12),
            ...results.identifiedProducts.take(3).map((product) =>
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: _getConfidenceColor(product.confidence),
                    child: Text(
                      '${(product.confidence * 100).toInt()}%',
                      style: TextStyle(fontSize: 10, color: Colors.white),
                    ),
                  ),
                  title: Text(product.fullName),
                  subtitle: Text('Model: ${product.modelNumber}'),
                  trailing: Chip(
                    label: Text(product.confidenceLevel),
                    backgroundColor: _getConfidenceColor(product.confidence).withOpacity(0.2),
                  ),
                ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _copyToClipboard,
            icon: Icon(Icons.copy),
            label: Text('Copy Summary'),
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _showDetailedResults,
            icon: Icon(Icons.visibility),
            label: Text('View Details'),
          ),
        ),
      ],
    );
  }

  // Event Handlers
  void _startAnalysis() async {
    setState(() {
      _isAnalyzing = true;
      _analysisError = null;
    });

    try {
      await EnhancedAnalysisService.startTargetedAnalysis(widget.item.id);
    } catch (e) {
      setState(() {
        _isAnalyzing = false;
        _analysisError = e.toString();
      });
    }
  }

  void _cancelAnalysis() {
    EnhancedAnalysisService.cancelAnalysis(widget.item.id);
    setState(() {
      _isAnalyzing = false;
    });
  }

  void _onAnalysisComplete(TargetedSearchResults results) async {
    // Refresh the item from storage
    final updatedItem = await StorageService.getJob(widget.item.id);
    if (updatedItem != null) {
      setState(() {
        _isAnalyzing = false;
        _summaryController.text = results.summary;
        _isSummaryEdited = false;
      });
      widget.onItemUpdated(updatedItem);
    }
  }

  void _resetSummary() {
    setState(() {
      _summaryController.text = widget.item.targetedSearchResults?.summary ?? '';
      _isSummaryEdited = false;
    });
  }

  void _saveSummary() async {
    final currentResults = widget.item.targetedSearchResults;
    if (currentResults != null) {
      final updatedResults = currentResults.copyWith(
        summary: _summaryController.text,
      );

      await StorageService.updateJobWithTargetedSearch(widget.item.id, updatedResults);

      final updatedItem = await StorageService.getJob(widget.item.id);
      if (updatedItem != null) {
        setState(() {
          _isSummaryEdited = false;
        });
        widget.onItemUpdated(updatedItem);
      }
    }
  }

  void _copyToClipboard() {
    Clipboard.setData(ClipboardData(text: _summaryController.text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Summary copied to clipboard')),
    );
  }

  void _showDetailedResults() {
    // Simple popup for now - you can expand this
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Analysis Details'),
        content: Text('Detailed analysis view coming soon!'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'regenerate':
        _showRegenerateDialog();
        break;
      case 'details':
        _showDetailedResults();
        break;
    }
  }

  void _showRegenerateDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Regenerate Analysis'),
        content: Text(
            'This will re-analyze the item and generate a new summary. Current edits will be lost. Continue?'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _regenerateAnalysis();
            },
            child: Text('Regenerate'),
          ),
        ],
      ),
    );
  }

  void _regenerateAnalysis() async {
    setState(() {
      _isAnalyzing = true;
      _isSummaryEdited = false;
    });

    try {
      await EnhancedAnalysisService.reAnalyzeJob(widget.item.id);
    } catch (e) {
      setState(() {
        _isAnalyzing = false;
        _analysisError = e.toString();
      });
    }
  }

  Color _getConfidenceColor(double confidence) {
    if (confidence >= 0.8) return Colors.green;
    if (confidence >= 0.6) return Colors.orange;
    return Colors.red;
  }
}