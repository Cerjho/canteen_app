import 'package:flutter/material.dart';
import '../../../../../core/models/menu_item.dart';
import 'menu_item_card.dart';

/// Responsive grid layout for displaying menu items.
/// 
/// Automatically adjusts column count and card sizing based on screen width:
/// - Mobile (<600px): Smaller cards with tighter spacing
/// - Tablet (600-1024px): Medium cards
/// - Desktop (>1024px): Larger cards with more breathing room
class MenuGrid extends StatelessWidget {
  final List<MenuItem> items;
  final Set<String> selectedIds;
  final Function(MenuItem) onItemTap;
  final Function(MenuItem) onItemLongPress;
  final Function(String) onToggleSelection;
  final Function(MenuItem) onToggleAvailability;
  final Function(MenuItem) onEdit;
  final Function(MenuItem) onDelete;

  const MenuGrid({
    super.key,
    required this.items,
    required this.selectedIds,
    required this.onItemTap,
    required this.onItemLongPress,
    required this.onToggleSelection,
    required this.onToggleAvailability,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 1024;
    
    // Responsive grid sizing
    final maxCrossAxisExtent = isMobile ? 180.0 : (isTablet ? 240.0 : 320.0);
    final childAspectRatio = isMobile ? 0.75 : 0.68;
    final spacing = isMobile ? 12.0 : 16.0;
    
    return GridView.builder(
      padding: EdgeInsets.all(isMobile ? 12.0 : 16.0),
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: maxCrossAxisExtent,
        childAspectRatio: childAspectRatio,
        crossAxisSpacing: spacing,
        mainAxisSpacing: spacing,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final isSelected = selectedIds.contains(item.id);
        
        return MenuItemCard(
          item: item,
          isSelected: isSelected,
          onTap: () => onItemTap(item),
          onLongPress: () => onItemLongPress(item),
          onToggleSelection: () => onToggleSelection(item.id),
          onToggleAvailability: () => onToggleAvailability(item),
          onEdit: () => onEdit(item),
          onDelete: () => onDelete(item),
        );
      },
    );
  }
}
