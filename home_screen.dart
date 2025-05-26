// ========================================
// lib/screens/home_screen.dart
// ========================================
import 'package:flutter/material.dart';
import '../models/item_job.dart';
import '../services/storage_service.dart';
import 'item_screen.dart';
import 'job_list_screen.dart';
import 'item_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<ItemJob> _recentItems = [];

  @override
  void initState() {
    super.initState();
    _loadRecentItems();
  }

  Future<void> _loadRecentItems() async {
    final items = await StorageService.getAllJobs();
    setState(() {
      _recentItems = items.take(5).toList();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('ReStoreID'),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
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

            if (_recentItems.isEmpty)
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
              ...(_recentItems.map((item) => Container(
                margin: EdgeInsets.only(bottom: 8),
                child: Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: item.isCompleted ? Colors.green : Colors.orange,
                      child: Icon(
                        item.isCompleted ? Icons.check : Icons.hourglass_empty,
                        color: Colors.white,
                      ),
                    ),
                    title: Text(item.description),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_formatDate(item.createdAt)),
                        if (item.quantity > 1)
                          Text('Qty: ${item.quantity}', style: TextStyle(fontWeight: FontWeight.w600)),
                      ],
                    ),
                    trailing: IconButton(
                      icon: Icon(Icons.more_vert),
                      onPressed: () => _showItemOptionsMenu(item),
                    ),
                    onTap: () => _navigateToItemDetail(item),
                  ),
                ),
              )).toList()),
          ],
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