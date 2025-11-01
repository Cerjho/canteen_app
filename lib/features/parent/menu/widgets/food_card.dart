import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/models/menu_item.dart';
import '../../../../core/utils/format_utils.dart';

/// FoodCard - Reusable card widget for displaying menu items in parent app
/// 
/// Features:
/// - Touch-friendly design (min 48px tap targets)
/// - Responsive sizing with flutter_screenutil
/// - Image, name, price display
/// - Add to cart button with quantity selector
/// - Dietary badges
/// - Accessibility support with Semantics
/// - Calorie/allergen icons for quick reference
class FoodCard extends StatefulWidget {
  final MenuItem item;
  final VoidCallback onTap;
  final Function(int quantity) onAddToCart; // Changed to accept quantity

  const FoodCard({
    super.key,
    required this.item,
    required this.onTap,
    required this.onAddToCart,
  });

  @override
  State<FoodCard> createState() => _FoodCardState();
}

class _FoodCardState extends State<FoodCard> {
  int _quantity = 1;
  bool _showQuantitySelector = false;

  void _handleAddToCart() {
    if (_showQuantitySelector) {
      // Add with selected quantity
      widget.onAddToCart(_quantity);
      // Reset
      setState(() {
        _quantity = 1;
        _showQuantitySelector = false;
      });
    } else {
      // Show quantity selector
      setState(() {
        _showQuantitySelector = true;
      });
    }
  }

  // Show allergens modal
  void _showAllergensModal(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber, color: Colors.orange[700], size: 24.sp),
            SizedBox(width: 8.w),
            Expanded(
              child: Text(
                'Allergen Information',
                style: TextStyle(fontSize: 18.sp),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.item.name,
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 12.h),
            Text(
              'This item contains the following allergens:',
              style: TextStyle(
                fontSize: 13.sp,
                color: Colors.grey[700],
              ),
            ),
            SizedBox(height: 12.h),
            ...widget.item.allergens.map(
              (allergen) => Padding(
                padding: EdgeInsets.only(bottom: 8.h),
                child: Row(
                  children: [
                    Icon(
                      Icons.circle,
                      size: 8.sp,
                      color: Colors.orange[700],
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Text(
                        allergen,
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                          color: Colors.orange[900],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 12.h),
            Container(
              padding: EdgeInsets.all(10.w),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(8.r),
                border: Border.all(color: Colors.orange[200]!),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16.sp,
                    color: Colors.orange[700],
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      'Please inform staff if you have any food allergies.',
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: Colors.orange[900],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Semantics(
      label:
          '${widget.item.name}, ${FormatUtils.currency(widget.item.price)}. '
          '${widget.item.isVegan ? 'Vegan. ' : ''}'
          '${widget.item.isVegetarian ? 'Vegetarian. ' : ''}'
          '${widget.item.isGlutenFree ? 'Gluten-free. ' : ''}'
          'Tap to view details',
      button: true,
      child: Card(
        clipBehavior: Clip.antiAlias,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(isMobile ? 10.r : 12.r),
        ),
        child: InkWell(
          onTap: widget.onTap,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Image Section (fixed width with proper clipping)
                ClipRRect(
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(isMobile ? 10.r : 12.r),
                    bottomLeft: Radius.circular(isMobile ? 10.r : 12.r),
                  ),
                  child: SizedBox(
                    width: isMobile ? 100.w : 120.w,
                    height: isMobile ? 100.h : 120.h,
                    child: _buildImageSection(theme, isMobile),
                  ),
                ),
                
                // Content Section (flexible)
                Expanded(
                  child: _buildContentSection(theme, isMobile),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Image section with gradient overlay and badges
  Widget _buildImageSection(ThemeData theme, bool isMobile) {
    return widget.item.imageUrl != null
        ? CachedNetworkImage(
            imageUrl: widget.item.imageUrl!,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            placeholder: (context, url) => Container(
              color: theme.colorScheme.surfaceContainerHighest,
              child: Center(
                child: CircularProgressIndicator(strokeWidth: 2.w),
              ),
            ),
            errorWidget: (context, url, error) => _buildPlaceholderImage(theme, isMobile),
          )
        : _buildPlaceholderImage(theme, isMobile);
  }

  // Placeholder image when no image URL
  Widget _buildPlaceholderImage(ThemeData theme, bool isMobile) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: theme.colorScheme.surfaceContainerHighest,
      child: Center(
        child: Icon(
          Icons.restaurant_menu,
          size: isMobile ? 50.sp : 60.sp,
          color: theme.colorScheme.outline.withAlpha((0.5 * 255).round()),
        ),
      ),
    );
  }

  // Content section with name, price, and add to cart button
  Widget _buildContentSection(ThemeData theme, bool isMobile) {
    return Padding(
      padding: EdgeInsets.all(isMobile ? 10.w : 12.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Top section: Name and badges
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Item Name
              Text(
                widget.item.name,
                style: TextStyle(
                  fontSize: isMobile ? 14.sp : 16.sp,
                  fontWeight: FontWeight.bold,
                  height: 1.2,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              
              // Description (if available) - directly under name
              if (widget.item.description.isNotEmpty) ...[
                SizedBox(height: 4.h),
                Text(
                  widget.item.description,
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: Colors.grey[600],
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              
              SizedBox(height: 6.h),
              
              // Category, Dietary, and Allergen badges in a row
              Wrap(
                spacing: 6.w,
                runSpacing: 4.h,
                children: [
                  // Category badge
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 8.w,
                      vertical: 3.h,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(4.r),
                    ),
                    child: Text(
                      widget.item.category,
                      style: TextStyle(
                        color: theme.colorScheme.onPrimaryContainer,
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),

                  // Dietary badges
                  if (widget.item.isVegan)
                    _buildInlineBadge('V+', Colors.green, 'Vegan'),
                  if (widget.item.isVegetarian && !widget.item.isVegan)
                    _buildInlineBadge('V', Colors.lightGreen, 'Vegetarian'),
                  if (widget.item.isGlutenFree)
                    _buildInlineBadge('GF', Colors.amber, 'Gluten-Free'),
                  
                  // Allergen badge (clickable)
                  if (widget.item.allergens.isNotEmpty)
                    GestureDetector(
                      onTap: () => _showAllergensModal(context),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 6.w,
                          vertical: 3.h,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange[700],
                          borderRadius: BorderRadius.circular(4.r),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.warning_amber,
                              size: 11.sp,
                              color: Colors.white,
                            ),
                            SizedBox(width: 3.w),
                            Text(
                              'Allergens',
                              style: TextStyle(
                                fontSize: 10.sp,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              
              SizedBox(height: 6.h),
              
              // Quick info row (calories only)
              Row(
                children: [
                  if (widget.item.calories != null) ...[
                    Icon(
                      Icons.local_fire_department,
                      size: 14.sp,
                      color: Colors.orange,
                    ),
                    SizedBox(width: 3.w),
                    Text(
                      '${widget.item.calories}cal',
                      style: TextStyle(
                        fontSize: 11.sp,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),

          SizedBox(height: 8.h),
          
          // Bottom section: Price and Add to Cart Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Price
              Text(
                FormatUtils.currency(widget.item.price * _quantity),
                style: TextStyle(
                  fontSize: isMobile ? 18.sp : 20.sp,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),

              // Quantity selector or add button
              _showQuantitySelector
                  ? _buildQuantitySelector(theme, isMobile)
                  : _buildAddButton(theme, isMobile),
            ],
          ),
        ],
      ),
    );
  }

  // Inline badge for horizontal layout
  Widget _buildInlineBadge(String label, Color color, String tooltip) {
    return Tooltip(
      message: tooltip,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 3.h),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(4.r),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontSize: 10.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  // Add to cart button (initial state)
  Widget _buildAddButton(ThemeData theme, bool isMobile) {
    return Semantics(
      label: 'Add ${widget.item.name} to cart',
      button: true,
      child: Material(
        color: theme.colorScheme.primary,
        borderRadius: BorderRadius.circular(isMobile ? 6.r : 8.r),
        child: InkWell(
          onTap: _handleAddToCart,
          borderRadius: BorderRadius.circular(isMobile ? 6.r : 8.r),
          child: Container(
            constraints: BoxConstraints(
              minWidth: isMobile ? 40.w : 48.w,
              minHeight: isMobile ? 40.h : 48.h,
            ),
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 10.w : 12.w,
              vertical: isMobile ? 6.h : 8.h,
            ),
            child: Icon(
              Icons.add_shopping_cart,
              color: theme.colorScheme.onPrimary,
              size: isMobile ? 18.sp : 20.sp,
            ),
          ),
        ),
      ),
    );
  }

  // Quantity selector (expanded state)
  Widget _buildQuantitySelector(ThemeData theme, bool isMobile) {
    return Row(
      children: [
        IconButton(
          onPressed: () {
            if (_quantity > 1) {
              setState(() => _quantity--);
            }
          },
          icon: Icon(
            Icons.remove_circle_outline,
            size: isMobile ? 18.sp : 20.sp,
          ),
          constraints: BoxConstraints(
            minWidth: isMobile ? 32.w : 36.w,
            minHeight: isMobile ? 32.h : 36.h,
          ),
          padding: EdgeInsets.zero,
        ),

        Container(
          width: isMobile ? 24.w : 28.w,
          alignment: Alignment.center,
          child: Text(
            '$_quantity',
            style: TextStyle(
              fontSize: isMobile ? 13.sp : 14.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),

        IconButton(
          onPressed: () {
            if (_quantity < 10) {
              setState(() => _quantity++);
            }
          },
          icon: Icon(
            Icons.add_circle_outline,
            size: isMobile ? 18.sp : 20.sp,
          ),
          constraints: BoxConstraints(
            minWidth: isMobile ? 32.w : 36.w,
            minHeight: isMobile ? 32.h : 36.h,
          ),
          padding: EdgeInsets.zero,
        ),

        SizedBox(width: isMobile ? 2.w : 4.w),

        IconButton(
          onPressed: _handleAddToCart,
          icon: Icon(
            Icons.check_circle,
            color: theme.colorScheme.primary,
            size: isMobile ? 22.sp : 24.sp,
          ),
          constraints: BoxConstraints(
            minWidth: isMobile ? 36.w : 40.w,
            minHeight: isMobile ? 36.h : 40.h,
          ),
          padding: EdgeInsets.zero,
          tooltip: 'Confirm and add to cart',
        ),
      ],
    );
  }
}
