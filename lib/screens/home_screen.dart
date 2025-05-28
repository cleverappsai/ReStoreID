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

  @override
  void initState() {
    super.initState();
    _loadRecentItems();
    _checkApiStatus();
  }

  Future<void> _loadRecentItems() async {
    final items = await StorageService.getAllJobs();
    setState(() {
      _recentItems = items.take(5).toList();
    });
  }

  Future<void> _checkApiStatus() async {
    final status = await ApiConfigService.getApiStatus();
    setState(() {
      _apiStatus = status;
    });
  }

  void _navigateToSettings() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => EnhancedSettingsScreen()),
    );
    if (result == true) {
      _checkApiStatus(); // Refresh API status after settings
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

  void _navigateToItemCreation() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ItemScreen()),
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

  // ✅ ENHANCED ANALYSIS - NOW USES CORRECT SERVICE
  Future<void> _runEnhancedAnalysis(ItemJob item) async {
    // Check API configuration first
    if (!(_apiStatus['allConfigured'] ?? false)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('⚠️ Please configure API keys in Settings before running Enhanced Analysis'),
          backgroundColor: Colors.orange,
          action: SnackBarAction(
            label: 'Settings',
            textColor: Colors.white,
            onPressed: () => _navigateToSettings(),
          ),
        ),
      );
      return;
    }

    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('🔍 Running Enhanced Analysis...'),
              Text(
                'This may take a minute',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
      );

      // ✅ FIXED: Now calls the correct service
      final result = await EnhancedAnalysisService.performCompleteAnalysis(item);

      // Close loading dialog
      Navigator.of(context).pop();

      if (result['success'] == true) {
        // Update item with results
        final updatedItem = item.copyWith(
          analysisResult: result,
        );
        await StorageService.saveJob(updatedItem);

        _loadRecentItems();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Enhanced Analysis completed successfully!'),
            backgroundColor: Colors.green,
          ),
        );

        // Navigate to results
        _navigateToItemDetail(updatedItem);
      } else {
        Navigator.of(context, rootNavigator: true).pop();

        final errorMessage = result['error'] ?? 'Unknown error occurred';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Enhanced Analysis failed: $errorMessage'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      Navigator.of(context, rootNavigator: true).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error during Enhanced Analysis: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showItemMenu(ItemJob item) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.info, color: Colors.blue),
              title: Text('View Details'),
              onTap: () {
                Navigator.pop(context);
                _navigateToItemDetail(item);
              },
            ),
            ListTile(
              leading: Icon(Icons.auto_awesome, color: Colors.purple),
              title: Text('Enhanced Analysis'),
              subtitle: Text('AI-powered product identification'),
              onTap: () {
                Navigator.pop(context);
                _runEnhancedAnalysis(item);
              },
            ),
            ListTile(
              leading: Icon(Icons.delete, color: Colors.red),
              title: Text('Delete Item'),
              onTap: () async {
                Navigator.pop(context);
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text('Delete Item'),
                    content: Text('Are you sure you want to delete this item?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: Text('Delete'),
                        style: TextButton.styleFrom(foregroundColor: Colors.red),
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
              },
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
          // Settings icon in top right corner
          IconButton(
            icon: Icon(Icons.settings),
            onPressed: _navigateToSettings,
            tooltip: 'API Settings',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Text(
              'Welcome to ReStoreID',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.blue[800],
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Identify and price items for resale',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),

            SizedBox(height: 24),

            // API Configuration Notice
            if (!(_apiStatus['allConfigured'] ?? false))
              Container(
                width: double.infinity,
                margin: EdgeInsets.only(bottom: 16),
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange[300]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning, color: Colors.orange[700], size: 24),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'API Configuration Required',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange[800],
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Configure your API keys to enable Enhanced Analysis',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.orange[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      onPressed: _navigateToSettings,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange[600],
                        foregroundColor: Colors.white,
                      ),
                      child: Text('Setup'),
                    ),
                  ],
                ),
              ),

            // Quick Actions
            Text(
              'Quick Actions',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildQuickActionCard(
                    icon: Icons.add_a_photo,
                    title: 'New Item',
                    subtitle: 'Add photos & details',
                    color: Colors.green,
                    onTap: _navigateToItemCreation,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: _buildQuickActionCard(
                    icon: Icons.list,
                    title: 'All Items',
                    subtitle: 'View all your items',
                    color: Colors.blue,
                    onTap: _navigateToItemList,
                  ),
                ),
              ],
            ),

            SizedBox(height: 24),

            // Recent Items Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recent Items',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton(
                  onPressed: _navigateToItemList,
                  child: Text('View All'),
                ),
              ],
            ),
            SizedBox(height: 12),

            // Recent Items List
            if (_recentItems.isEmpty)
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.photo_library_outlined,
                      size: 48,
                      color: Colors.grey[400],
                    ),
                    SizedBox(height: 16),
                    Text(
                      'No items yet',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[600],
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Take photos of items to get started',
                      style: TextStyle(
                        color: Colors.grey[500],
                      ),
                    ),
                    SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _navigateToItemCreation,
                      icon: Icon(Icons.add),
                      label: Text('Add First Item'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[600],
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              )
            else
              ...(_recentItems.map((item) => Container(
                margin: EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: ListTile(
                  contentPadding: EdgeInsets.all(16),
                  leading: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.grey[100],
                    ),
                    child: item.images.isNotEmpty
                        ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        item.images.first,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            Icon(Icons.image, color: Colors.grey),
                      ),
                    )
                        : Icon(Icons.image, color: Colors.grey),
                  ),
                  title: Text(
                    item.userDescription.isNotEmpty
                        ? item.userDescription
                        : 'Unnamed Item',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    '${item.images.length} photo${item.images.length == 1 ? '' : 's'} • ${_formatDate(item.createdAt)}',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  trailing: IconButton(
                    icon: Icon(Icons.more_vert, color: Colors.grey[600]),
                    onPressed: () => _showItemMenu(item),
                  ),
                  onTap: () => _navigateToItemDetail(item),
                ),
              )).toList()),

            SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionCard({
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
            Icon(icon, size: 32, color: color),
            SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.month}/${date.day}/${date.year}';
    }
  }
}