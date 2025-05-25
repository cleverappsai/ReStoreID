import 'package:flutter/material.dart';
import '../models/item_job.dart';

class CategorySelector extends StatelessWidget {
  final ImageCategory selectedCategory;
  final Function(ImageCategory) onCategoryChanged;

  const CategorySelector({
    Key? key,
    required this.selectedCategory,
    required this.onCategoryChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 70,
      padding: EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            offset: Offset(0, 2),
            blurRadius: 4,
          ),
        ],
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 8),
        children: [
          _buildCategoryChip('📦', 'Packaging', ImageCategory.packaging),
          _buildCategoryChip('🔍', 'Search', ImageCategory.itemSearch),
          _buildCategoryChip('📸', 'Sales', ImageCategory.itemSales),
          _buildCategoryChip('🏷️', 'Markings', ImageCategory.markings),
          _buildCategoryChip('📊', 'Barcode', ImageCategory.barcode),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(String emoji, String label, ImageCategory category) {
    final isSelected = selectedCategory == category;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4),
      child: ChoiceChip(
        avatar: Text(emoji, style: TextStyle(fontSize: 16)),
        label: Text(label, style: TextStyle(fontSize: 12)),
        selected: isSelected,
        onSelected: (_) => onCategoryChanged(category),
        selectedColor: Colors.blue[200],
        backgroundColor: Colors.white,
        elevation: isSelected ? 4 : 1,
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),
    );
  }
}