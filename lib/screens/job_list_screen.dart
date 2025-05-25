// ========================================
// lib/screens/job_list_screen.dart
// ========================================
import 'package:flutter/material.dart';
import '../models/item_job.dart';
import '../services/storage_service.dart';
import 'item_detail_screen.dart';
import 'item_screen.dart';
import 'package:uuid/uuid.dart';

class JobListScreen extends StatefulWidget {
  @override
  _JobListScreenState createState() => _JobListScreenState();
}

class _JobListScreenState extends State<JobListScreen> {
  List<ItemJob> _items = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final items = await StorageService.getAllJobs();
      setState(() {
        _items = items;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading items: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _navigateToItemDetail(ItemJob item) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ItemDetailScreen(item: item)),
    );
    if (result != null) {
      _loadItems();
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
            Text(
              'Item Options',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
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
                  _loadItems();
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
    try {
      final clonedItem = ItemJob(
        id: Uuid().v4(), // New ID
        userDescription: '${item.userDescription} (Copy)',
        searchDescription: item.searchDescription,
        length: item.length,
        width: item.width,
        height: item.height,
        weight: item.weight,
        quantity: item.quantity,
        images: List.from(item.images), // Copy image list
        createdAt: DateTime.now(), // New creation time
        imageClassification: item.imageClassification != null
            ? Map<String, List<String>>.from(item.imageClassification!.map((k, v) => MapEntry(k, List<String>.from(v))))
            : null,
        // Don't copy processing results - new item needs fresh processing
      );

      await StorageService.saveJob(clonedItem);
      _loadItems();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Item cloned successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error cloning item: $e')),
      );
    }
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
      try {
        await StorageService.deleteJob(item.id);
        _loadItems();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Item deleted')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting item: $e')),
        );
      }
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Color _getStatusColor(ItemJob item) {
    if (item.isCompleted) return Colors.green;
    if (item.ocrCompleted || item.barcodeCompleted) return Colors.orange;
    return Colors.grey;
  }

  String _getStatusText(ItemJob item) {
    if (item.isCompleted) return 'Complete';
    if (item.ocrCompleted || item.barcodeCompleted) return 'Processing';
    return 'Pending';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('All Items'),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadItems,
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _items.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            SizedBox(height: 16),
            Text(
              'No items yet',
              style: TextStyle(
                fontSize: 20,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Add your first item to get started',
              style: TextStyle(
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      )
          : RefreshIndicator(
        onRefresh: _loadItems,
        child: ListView.builder(
          padding: EdgeInsets.all(16),
          itemCount: _items.length,
          itemBuilder: (context, index) {
            final item = _items[index];
            return Container(
              margin: EdgeInsets.only(bottom: 12),
              child: Card(
                elevation: 2,
                child: ListTile(
                  contentPadding: EdgeInsets.all(16),
                  leading: CircleAvatar(
                    backgroundColor: _getStatusColor(item),
                    child: Icon(
                      item.isCompleted ? Icons.check : Icons.hourglass_empty,
                      color: Colors.white,
                    ),
                  ),
                  title: Text(
                    item.description,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: 4),
                      Text('Created: ${_formatDate(item.createdAt)}'),
                      if (item.quantity > 1)
                        Text(
                          'Quantity: ${item.quantity}',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      SizedBox(height: 4),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: _getStatusColor(item).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _getStatusColor(item).withOpacity(0.3)),
                        ),
                        child: Text(
                          _getStatusText(item),
                          style: TextStyle(
                            color: _getStatusColor(item),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
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
          },
        ),
      ),
    );
  }
}