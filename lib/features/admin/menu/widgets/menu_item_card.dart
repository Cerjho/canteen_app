import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../../../core/models/menu_item.dart';
import '../../../../../core/utils/format_utils.dart';

/// Individual menu item card displayed in the grid/list view.
/// 
/// Features:
/// - Image with gradient overlay and availability badge
/// - Item details (name, price, category, description)
/// - Dietary icons and allergen information
/// - Quick actions (toggle availability, edit, delete)
/// - Bulk selection support
/// - Responsive design for mobile and desktop
class MenuItemCard extends StatelessWidget {
  final MenuItem item;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onToggleSelection;
  final VoidCallback onToggleAvailability;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const MenuItemCard({
    super.key,
    required this.item,
    required this.isSelected,
    required this.onTap,
    required this.onLongPress,
    required this.onToggleSelection,
    required this.onToggleAvailability,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Semantics(
  label: '${item.name}, ${FormatUtils.currency(item.price)}, ${item.isAvailable ? 'Available' : 'Unavailable'}. ${item.dietaryLabels.isEmpty ? '' : '${item.dietaryLabels.join(', ')}.'}',
      button: true,
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              border: isSelected 
                  ? Border.all(color: theme.colorScheme.primary, width: 2)
                  : null,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Card(
              clipBehavior: Clip.antiAlias,
              elevation: isSelected ? 4 : 2,
              child: Stack(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Image Section
                      Expanded(
                        flex: 3,
                        child: _buildImageSection(context, theme, isMobile),
                      ),
                      // Content Section
                      Expanded(
                        flex: 2,
                        child: _buildContentSection(context, theme, isMobile),
                      ),
                    ],
                  ),
                  // Bulk Selection Checkbox Overlay
                  _buildSelectionCheckbox(context, theme),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImageSection(BuildContext context, ThemeData theme, bool isMobile) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Main Image
        item.imageUrl != null
            ? CachedNetworkImage(
                imageUrl: item.imageUrl!,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: theme.colorScheme.surfaceContainerHighest,
                  child: const Center(child: CircularProgressIndicator()),
                ),
                errorWidget: (context, url, error) => _buildPlaceholderImage(theme),
              )
            : _buildPlaceholderImage(theme),
        // Gradient Overlay
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: 60,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.25),
                ],
              ),
            ),
          ),
        ),
        // Availability Badge
        Positioned(
          top: 8,
          right: 8,
          child: Chip(
            label: Text(
              item.isAvailable ? 'Available' : 'Unavailable',
              style: TextStyle(
                color: item.isAvailable
                    ? theme.colorScheme.onPrimaryContainer
                    : theme.colorScheme.onErrorContainer,
                fontSize: 12,
              ),
            ),
            backgroundColor: item.isAvailable
                ? theme.colorScheme.primaryContainer
                : theme.colorScheme.errorContainer,
            padding: const EdgeInsets.symmetric(horizontal: 8),
          ),
        ),
      ],
    );
  }

  Widget _buildPlaceholderImage(ThemeData theme) {
    return Container(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Icon(
        Icons.restaurant_menu,
        size: 64,
        color: theme.colorScheme.outline,
      ),
    );
  }

  Widget _buildContentSection(BuildContext context, ThemeData theme, bool isMobile) {
    return Column(
      children: [
        // Scrollable Content Area
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              isMobile ? 10.0 : 12.0,
              isMobile ? 10.0 : 12.0,
              isMobile ? 10.0 : 12.0,
              isMobile ? 6.0 : 8.0,
            ),
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTitleAndPrice(theme, isMobile),
                SizedBox(height: isMobile ? 4 : 6),
                _buildCategoryBadge(theme, isMobile),
                SizedBox(height: isMobile ? 4 : 6),
                _buildDescription(theme, isMobile),
                SizedBox(height: isMobile ? 4 : 6),
                _buildDietaryAndAllergenInfo(theme, isMobile),
              ],
            ),
          ),
        ),
        // Fixed Footer Actions
        _buildActionFooter(theme, isMobile),
      ],
    );
  }

  Widget _buildTitleAndPrice(ThemeData theme, bool isMobile) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            item.name,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: isMobile ? 13 : 14,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          FormatUtils.currency(item.price),
          style: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.bold,
            fontSize: isMobile ? 13 : 14,
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryBadge(ThemeData theme, bool isMobile) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 6 : 8,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        item.category,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSecondaryContainer,
          fontWeight: FontWeight.w500,
          fontSize: isMobile ? 10 : 11,
        ),
      ),
    );
  }

  Widget _buildDescription(ThemeData theme, bool isMobile) {
    return Text(
      item.description,
      style: theme.textTheme.bodySmall?.copyWith(
        height: 1.3,
        fontSize: isMobile ? 11 : 12,
      ),
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildDietaryAndAllergenInfo(ThemeData theme, bool isMobile) {
    return Wrap(
      spacing: 4,
      runSpacing: 3,
      children: [
        // Display all dietary labels dynamically
        ...item.dietaryLabels.map((label) {
          if (label.toLowerCase() == 'vegetarian') {
            return _buildDietaryBadge('Vegetarian', 'Veg', Icons.eco, Colors.green, isMobile);
          } else if (label.toLowerCase() == 'vegan') {
            return _buildDietaryBadge('Vegan', 'Vegan', Icons.spa, Colors.green, isMobile, darker: true);
          } else if (label.toLowerCase().contains('gluten')) {
            return _buildDietaryBadge('Gluten Free', 'GF', Icons.grain, Colors.amber, isMobile);
          } else if (label.toLowerCase().contains('halal')) {
            return _buildDietaryBadge('Halal', 'Halal', Icons.mosque, Colors.teal, isMobile);
          } else if (label.toLowerCase().contains('kosher')) {
            return _buildDietaryBadge('Kosher', 'Kosher', Icons.star, Colors.blue, isMobile);
          } else if (label.toLowerCase().contains('dairy-free')) {
            return _buildDietaryBadge('Dairy-Free', 'DF', Icons.no_meals, Colors.cyan, isMobile);
          } else if (label.toLowerCase().contains('nut-free')) {
            return _buildDietaryBadge('Nut-Free', 'NF', Icons.block, Colors.brown, isMobile);
          } else {
            return _buildDietaryBadge(label, label.length > 4 ? label.substring(0, 4) : label, Icons.label, Colors.purple, isMobile);
          }
        }),
        if (item.allergens.isNotEmpty) _buildAllergenBadge(isMobile),
      ],
    );
  }

  Widget _buildDietaryBadge(String tooltip, String label, IconData icon, MaterialColor baseColor, bool isMobile, {bool darker = false}) {
    final colorShade = darker ? baseColor[900]! : baseColor[700]!;
    final bgColor = darker ? baseColor[100]! : baseColor[50]!;

    return Tooltip(
      message: tooltip,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 4 : 6,
          vertical: 2,
        ),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: colorShade, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: isMobile ? 12 : 13, color: colorShade),
            const SizedBox(width: 2),
            Text(label, style: TextStyle(fontSize: isMobile ? 9 : 10, color: colorShade)),
          ],
        ),
      ),
    );
  }

  Widget _buildAllergenBadge(bool isMobile) {
    return Tooltip(
      message: 'Allergens: ${item.allergens.join(", ")}',
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 4 : 6,
          vertical: 2,
        ),
        decoration: BoxDecoration(
          color: Colors.orange[50],
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.orange[700]!, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.warning_amber, size: isMobile ? 12 : 13, color: Colors.orange[700]),
            const SizedBox(width: 2),
            Text('Allergens', style: TextStyle(fontSize: isMobile ? 9 : 10, color: Colors.orange[700])),
          ],
        ),
      ),
    );
  }

  Widget _buildActionFooter(ThemeData theme, bool isMobile) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 4 : 6,
        vertical: isMobile ? 0 : 2,
      ),
      height: isMobile ? 36 : 40,
      child: Row(
        children: [
          // Availability Toggle
          Expanded(
            child: Transform.scale(
              scale: isMobile ? 0.75 : 0.8,
              child: Switch.adaptive(
                value: item.isAvailable,
                onChanged: (_) => onToggleAvailability(),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                thumbColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return theme.colorScheme.onPrimary;
                  }
                  return null;
                }),
                trackColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return theme.colorScheme.primary;
                  }
                  return null;
                }),
              ),
            ),
          ),
          // Edit Button
          IconButton(
            onPressed: onEdit,
            icon: Icon(Icons.edit_outlined, size: isMobile ? 18 : 19),
            tooltip: 'Edit',
            color: theme.colorScheme.primary,
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.all(isMobile ? 4 : 6),
            constraints: BoxConstraints(
              minWidth: isMobile ? 32 : 36,
              minHeight: isMobile ? 32 : 36,
            ),
          ),
          // Delete Button
          IconButton(
            onPressed: onDelete,
            icon: Icon(Icons.delete_outline, size: isMobile ? 18 : 19),
            tooltip: 'Delete',
            color: theme.colorScheme.error,
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.all(isMobile ? 4 : 6),
            constraints: BoxConstraints(
              minWidth: isMobile ? 32 : 36,
              minHeight: isMobile ? 32 : 36,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectionCheckbox(BuildContext context, ThemeData theme) {
    return Positioned(
      top: 8,
      left: 8,
      child: AnimatedOpacity(
        opacity: isSelected ? 1.0 : 0.3,
        duration: const Duration(milliseconds: 200),
        child: GestureDetector(
          onTap: onToggleSelection,
          child: Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected 
                    ? theme.colorScheme.primary 
                    : theme.colorScheme.outline,
                width: 2,
              ),
            ),
            child: Checkbox(
              value: isSelected,
              onChanged: (_) => onToggleSelection(),
              visualDensity: VisualDensity.compact,
            ),
          ),
        ),
      ),
    );
  }
}
