import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/models/menu_item.dart';
import '../../../../core/utils/format_utils.dart';

/// MenuDetailPanel - Detail view for selected menu item
/// Displayed on the right side in master-detail layout (desktop/tablet landscape)
/// 
/// Features:
/// - Full item details
/// - Large image
/// - Nutritional information
/// - Allergen warnings
/// - Quantity selector
/// - Add to cart action
class MenuDetailPanel extends StatefulWidget {
  final MenuItem item;
  final VoidCallback onClose;
  final VoidCallback onAddToCart;

  const MenuDetailPanel({
    super.key,
    required this.item,
    required this.onClose,
    required this.onAddToCart,
  });

  @override
  State<MenuDetailPanel> createState() => _MenuDetailPanelState();
}

class _MenuDetailPanelState extends State<MenuDetailPanel> {
  int _quantity = 1;

  void _incrementQuantity() {
    setState(() {
      if (_quantity < 10) _quantity++;
    });
  }

  void _decrementQuantity() {
    setState(() {
      if (_quantity > 1) _quantity--;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      label: 'Item details for ${widget.item.name}',
      child: Container(
        color: theme.colorScheme.surface,
        child: Column(
          children: [
            // Header with close button
            _buildHeader(theme),
            
            // Scrollable content
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(16.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Large Image
                    _buildImage(theme),
                    
                    SizedBox(height: 16.h),
                    
                    // Item Name
                    Text(
                      widget.item.name,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    
                    SizedBox(height: 8.h),
                    
                    // Category Badge
                    _buildCategoryBadge(theme),
                    
                    SizedBox(height: 16.h),
                    
                    // Price
                    Text(
                      FormatUtils.currency(widget.item.price),
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    
                    SizedBox(height: 16.h),
                    
                    // Description
                    Text(
                      widget.item.description,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        height: 1.5,
                      ),
                    ),
                    
                    SizedBox(height: 24.h),
                    
                    // Dietary Information
                    _buildDietaryInfo(theme),
                    
                    SizedBox(height: 24.h),
                    
                    // Nutritional Information
                    if (widget.item.calories != null)
                      _buildNutritionalInfo(theme),
                    
                    // Allergen Information
                    if (widget.item.allergens.isNotEmpty) ...[
                      SizedBox(height: 24.h),
                      _buildAllergenInfo(theme),
                    ],
                  ],
                ),
              ),
            ),
            
            // Footer with quantity selector and add to cart
            _buildFooter(theme),
          ],
        ),
      ),
    );
  }

  // Header with close button
  Widget _buildHeader(ThemeData theme) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: theme.dividerColor,
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Item Details',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: widget.onClose,
            tooltip: 'Close details',
          ),
        ],
      ),
    );
  }

  // Large image display
  Widget _buildImage(ThemeData theme) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12.r),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: widget.item.imageUrl != null
            ? CachedNetworkImage(
                imageUrl: widget.item.imageUrl!,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: theme.colorScheme.surfaceContainerHighest,
                  child: Center(
                    child: CircularProgressIndicator(strokeWidth: 2.w),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  color: theme.colorScheme.surfaceContainerHighest,
                  child: Center(
                    child: Icon(
                      Icons.restaurant_menu,
                      size: 64.sp,
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ),
              )
            : Container(
                color: theme.colorScheme.surfaceContainerHighest,
                child: Center(
                  child: Icon(
                    Icons.restaurant_menu,
                    size: 64.sp,
                    color: theme.colorScheme.outline,
                  ),
                ),
              ),
      ),
    );
  }

  // Category badge
  Widget _buildCategoryBadge(ThemeData theme) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Text(
        widget.item.category,
        style: TextStyle(
          color: theme.colorScheme.onSecondaryContainer,
          fontSize: 14.sp,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // Dietary information badges
  Widget _buildDietaryInfo(ThemeData theme) {
    final badges = <Widget>[];
    
    if (widget.item.isVegan) {
      badges.add(_buildInfoBadge(
        'Vegan',
        Icons.eco,
        Colors.green,
        'This item is vegan',
      ));
    } else if (widget.item.isVegetarian) {
      badges.add(_buildInfoBadge(
        'Vegetarian',
        Icons.spa,
        Colors.lightGreen,
        'This item is vegetarian',
      ));
    }
    
    if (widget.item.isGlutenFree) {
      badges.add(_buildInfoBadge(
        'Gluten-Free',
        Icons.grain,
        Colors.amber,
        'This item is gluten-free',
      ));
    }
    
    if (badges.isEmpty) return const SizedBox.shrink();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Dietary Information',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 8.h),
        Wrap(
          spacing: 8.w,
          runSpacing: 8.h,
          children: badges,
        ),
      ],
    );
  }

  // Info badge widget
  Widget _buildInfoBadge(
    String label,
    IconData icon,
    Color color,
    String tooltip,
  ) {
    return Tooltip(
      message: tooltip,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: 12.w,
          vertical: 8.h,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(8.r),
          border: Border.all(color: color, width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18.sp, color: color),
            SizedBox(width: 6.w),
            Text(
              label,
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Nutritional information
  Widget _buildNutritionalInfo(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Nutritional Information',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 8.h),
        Card(
          child: Padding(
            padding: EdgeInsets.all(12.w),
            child: Row(
              children: [
                Icon(
                  Icons.local_fire_department,
                  color: Colors.orange,
                  size: 24.sp,
                ),
                SizedBox(width: 8.w),
                Text(
                  '${widget.item.calories} calories per serving',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Allergen information
  Widget _buildAllergenInfo(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Allergen Warning',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.orange[800],
          ),
        ),
        SizedBox(height: 8.h),
        Card(
          color: Colors.orange[50],
          child: Padding(
            padding: EdgeInsets.all(12.w),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.warning_amber,
                  color: Colors.orange[800],
                  size: 24.sp,
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Contains:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14.sp,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        widget.item.allergens.join(', '),
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Footer with quantity selector and add to cart button
  Widget _buildFooter(ThemeData theme) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: theme.dividerColor,
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Quantity Selector
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Quantity:',
                style: theme.textTheme.titleMedium,
              ),
              SizedBox(width: 16.w),

              IconButton(
                onPressed: _decrementQuantity,
                icon: const Icon(Icons.remove_circle_outline),
                tooltip: 'Decrease quantity',
                constraints: BoxConstraints(
                  minWidth: 48.w,
                  minHeight: 48.h,
                ),
              ),

              Container(
                width: 40.w,
                alignment: Alignment.center,
                child: Text(
                  '$_quantity',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              IconButton(
                onPressed: _incrementQuantity,
                icon: const Icon(Icons.add_circle_outline),
                tooltip: 'Increase quantity',
                constraints: BoxConstraints(
                  minWidth: 48.w,
                  minHeight: 48.h,
                ),
              ),
            ],
          ),

          SizedBox(height: 16.h),

          // Add to Cart Button
          SizedBox(
            width: double.infinity,
            height: 56.h,
            child: ElevatedButton.icon(
              onPressed: widget.onAddToCart,
              icon: const Icon(Icons.shopping_cart),
              label: Text(
                'Add to Cart - '
                '${FormatUtils.currency(widget.item.price * _quantity)}',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
