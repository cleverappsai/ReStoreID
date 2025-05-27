// ========================================
// lib/screens/home_screen.dart (Complete Enhanced Version)
// ========================================
import 'package:flutter/material.dart';
import '../models/item_job.dart';
import '../services/storage_service.dart';
import '../services/enhanced_analysis_service.dart';
import '../services/api_config_service.dart';
import 'item_screen.dart';
import 'job_list_screen.dart';
import 'item_detail_screen.dart';
import 'enhanced_settings_screen.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<ItemJob> _recentItems = [];
  Map<String, bool> _apiStatus = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    await Future.wait([
      _loadRecentItems(),
      _loadApiStatus(),
    ]);

    setState(() => _isLoading = false);
  }

  Future<void> _loadRecentItems() async {
    final items = await StorageService.getAllJobs();
    setState(() {
      _recentItems = items.take(5).toList();
    });
  }

  Future<void> _loadApiStatus() async {
    final status = await ApiConfigService.getApiStatus();
    setState(() {
      _apiStatus = status;
    });
  }

  void _navigateToItemCreation() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ItemScreen()), // No existing item = new item
    );
    if (result == true) {
      _loadRecentItems();
    }
  }

  void _navigateToItemList() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => JobListScreen()),
    );
    if (result == true) {
      _loadRecentItems();
    }
  }

  void _navigateToItemDetail(ItemJob item) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ItemDetailScreen(item: item)),
    );
    if (result != null) {
      _loadRecentItems();
    }
  }

  void _navigateToEnhancedSettings() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => EnhancedSettingsScreen()),
    );
    if (result == true) {
      _loadApiStatus(); // Reload API status after settings change
    }
  }

  void _showItemOptionsMenu(ItemJob item) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.visibility),
              title: Text('View Details'),
              onTap: () {
                Navigator.pop(context);
                _navigateToItemDetail(item);
              },
            ),
            ListTile(
              leading: Icon(Icons.edit),
              title: Text('Edit Item'),
              onTap: () async {
                Navigator.pop(context);
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ItemScreen(existingItem: item)), // Pass existing item for edit
                );
                if (result != null) {
                  _loadRecentItems();
                }
              },
            ),
            if (_apiStatus['allConfigured'] == true)
              ListTile(
                leading: Icon(Icons.auto_awesome, color: Colors.blue),
                title: Text('Enhanced Analysis'),
                subtitle: Text('Run AI-powered analysis'),
                onTap: () async {
                  Navigator.pop(context);
                  await _runEnhancedAnalysis(item);
                },
              ),
            ListTile(
              leading: Icon(Icons.copy),
              title: Text('Clone Item'),
              onTap: () async {
                Navigator.pop(context);
                await _cloneItem(item);
              },
            ),
            ListTile(
              leading: Icon(Icons.delete, color: Colors.red),
              title: Text('Delete Item', style: TextStyle(color: Colors.red)),
              onTap: () async {
                Navigator.pop(context);
                await _deleteItem(item);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _runEnhancedAnalysis(ItemJob item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Enhanced Analysis'),
        content: Text('Run comprehensive AI analysis for "${item.description}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Start Analysis'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        EnhancedAnalysisService.triggerBackgroundAnalysis(item);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Enhanced analysis started for "${item.description}"'),
            backgroundColor: Colors.green,
            action: SnackBarAction(
              label: 'VIEW',
              onPressed: () => _navigateToItemDetail(item),
            ),
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error starting analysis: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _cloneItem(ItemJob item) async {
    // Implementation will be added when ItemEditScreen with clone functionality is ready
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Clone functionality coming soon')),
    );
  }

  Future<void> _deleteItem(ItemJob item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Item'),
        content: Text('Are you sure you want to delete "${item.description}"?'),
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
      await StorageService.deleteJob(item.id);
      _loadRecentItems();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Item deleted')),
      );
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Widget _buildEnhancedAnalysisPromo() {
    final isConfigured = _apiStatus['allConfigured'] == true;

    return Card(
      elevation: 2,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isConfigured
                ? [Colors.blue[600]!, Colors.blue[800]!]
                : [Colors.orange[600]!, Colors.orange[800]!],
          ),
        ),
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isConfigured ? Icons.auto_awesome : Icons.settings,
                  color: Colors.white,
                  size: 24,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isConfigured ? 'Enhanced Analysis Ready' : 'Setup Enhanced Analysis',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              isConfigured
                  ? 'Get detailed product info using AI-powered targeted searches'
                  : 'Configure APIs to unlock advanced product identification',
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 14,
              ),
            ),
            SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: isConfigured ? null : _navigateToEnhancedSettings,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: isConfigured ? Colors.blue[700] : Colors.orange[700],
                    ),
                    child: Text(isConfigured ? 'Ready to Use' : 'Configure Now'),
                  ),
                ),
                if (isConfigured) ...[
                  SizedBox(width: 8),
                  IconButton(
                    onPressed: _navigateToEnhancedSettings,
                    icon: Icon(Icons.settings, color: Colors.white),
                    tooltip: 'Settings',
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalysisStatusIndicator() {
    final recentItemsWithAnalysis = _recentItems.where((item) =>
    item.analysisResult != null &&
        item.analysisResult!['analysisType'] == 'enhanced_targeted'
    ).length;

    if (recentItemsWithAnalysis == 0) return SizedBox.shrink();

    return Card(
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(Icons.analytics, color: Colors.green[600]),
            SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Enhanced Analysis Complete',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '$recentItemsWithAnalysis of ${_recentItems.length} recent items analyzed',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: _navigateToItemList,
              child: Text('View All'),
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
        title: Text('ReStoreID'),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _navigateToEnhancedSettings,
            icon: Icon(Icons.tune),
            tooltip: 'Enhanced Analysis Settings',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: SingleChildScrollView(
          physics: AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome Section
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Colors.blue[600]!, Colors.blue[800]!],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome to ReStoreID',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Identify and price your resale items with AI',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 24),

              // Enhanced Analysis Promo
              if (!_isLoading) _buildEnhancedAnalysisPromo(),

              SizedBox(height: 24),

              // Quick Actions
              Text(
                'Quick Actions',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildActionCard(
                      icon: Icons.add_photo_alternate,
                      title: 'Add New Item',
                      subtitle: 'Start identification',
                      color: Colors.green,
                      onTap: _navigateToItemCreation,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: _buildActionCard(
                      icon: Icons.list,
                      title: 'View All Items',
                      subtitle: 'Browse inventory',
                      color: Colors.orange,
                      onTap: _navigateToItemList,
                    ),
                  ),
                ],
              ),

              SizedBox(height: 24),

              // Analysis Status
              if (!_isLoading) _buildAnalysisStatusIndicator(),
              if (!_isLoading && _buildAnalysisStatusIndicator() != SizedBox.shrink())
                SizedBox(height: 16),

              // Recent Items Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Recent Items',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  TextButton(
                    onPressed: _navigateToItemList,
                    child: Text('View All'),
                  ),
                ],
              ),
              SizedBox(height: 12),

              if (_isLoading)
                Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (_recentItems.isEmpty)
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.inventory_2_outlined,
                        size: 48,
                        color: Colors.grey[400],
                      ),
                      SizedBox(height: 16),
                      Text(
                        'No items yet',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[600],
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Tap "Add New Item" to get started',
                        style: TextStyle(
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                )
              else
                ...(_recentItems.map((item) => _buildItemCard(item)).toList()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildItemCard(ItemJob item) {
    final analysisStatus = EnhancedAnalysisService.getAnalysisStatus(item);
    final isEnhanced = item.analysisResult?['analysisType'] == 'enhanced_targeted';
    final confidence = item.analysisResult?['overallConfidence'] ?? 0.0;

    return Container(
      margin: EdgeInsets.only(bottom: 8),
      child: Card(
        child: ListTile(
          leading: Stack(
            children: [
              CircleAvatar(
                backgroundColor: item.isCompleted ? Colors.green : Colors.orange,
                child: Icon(
                  item.isCompleted ? Icons.check : Icons.hourglass_empty,
                  color: Colors.white,
                ),
              ),
              if (isEnhanced)
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    padding: EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.auto_awesome,
                      color: Colors.white,
                      size: 12,
                    ),
                  ),
                ),
            ],
          ),
          title: Text(item.description),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_formatDate(item.createdAt)),
              if (item.quantity > 1)
                Text('Qty: ${item.quantity}', style: TextStyle(fontWeight: FontWeight.w600)),
              if (isEnhanced)
                Row(
                  children: [
                    Icon(Icons.auto_awesome, size: 12, color: Colors.blue),
                    SizedBox(width: 4),
                    Text(
                      'Enhanced Analysis (${(confidence * 100).toInt()}%)',
                      style: TextStyle(
                        color: Colors.blue,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              if (analysisStatus['status'] == 'in_progress')
                Row(
                  children: [
                    SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 4),
                    Text(
                      'Analyzing...',
                      style: TextStyle(
                        color: Colors.orange,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          trailing: IconButton(
            icon: Icon(Icons.more_vert),
            onPressed: () => _showItemOptionsMenu(item),
          ),
          onTap: () => _navigateToItemDetail(item),
        ),
      ),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}