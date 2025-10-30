import 'package:flutter/material.dart';

/// Empty state widget displayed when no menu items are available.
/// 
/// Shows different messages based on whether filters are active or not,
/// and provides a call-to-action button to add the first menu item.
class MenuEmptyState extends StatelessWidget {
  final bool hasActiveFilters;
  final VoidCallback onAddItem;

  const MenuEmptyState({
    super.key,
    required this.hasActiveFilters,
    required this.onAddItem,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inventory_2,
            size: 80,
            color: theme.colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            'No menu items in inventory',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            hasActiveFilters
                ? 'Try adjusting your filters'
                : 'Create your first food/drink item to build your menu catalog',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onAddItem,
            icon: const Icon(Icons.add),
            label: const Text('Add Menu Item'),
          ),
        ],
      ),
    );
  }
}
