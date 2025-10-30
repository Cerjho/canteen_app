import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/app_providers.dart';

/// Admin Scaffold with responsive navigation (Drawer for mobile, Rail for desktop)
class AdminScaffold extends ConsumerWidget {
  final Widget child;

  const AdminScaffold({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentRoute = GoRouterState.of(context).matchedLocation;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 1024;
    
    // For mobile and tablet, use Drawer navigation
    if (isMobile || isTablet) {
      return Scaffold(
        appBar: AppBar(
          title: Text(_getPageTitle(currentRoute)),
          centerTitle: false,
        ),
        drawer: _buildDrawer(context, ref, currentRoute),
        body: child,
      );
    }
    
    // For desktop, use NavigationRail
    return Scaffold(
      body: Row(
        children: [
          // Sidebar Navigation
          NavigationRail(
            extended: screenWidth > 1200,
            selectedIndex: _getSelectedIndex(currentRoute),
            onDestinationSelected: (index) {
              _navigateToIndex(context, index);
            },
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Icon(
                Icons.school,
                size: 40,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            trailing: Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: IconButton(
                    icon: const Icon(Icons.logout),
                    tooltip: 'Logout',
                    onPressed: () async {
                      await ref.read(authServiceProvider).signOut();
                    },
                  ),
                ),
              ),
            ),
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard),
                label: Text('Dashboard'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.people_outlined),
                selectedIcon: Icon(Icons.people),
                label: Text('Students'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.family_restroom_outlined),
                selectedIcon: Icon(Icons.family_restroom),
                label: Text('Parents'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.restaurant_menu_outlined),
                selectedIcon: Icon(Icons.restaurant_menu),
                label: Text('Menu'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.shopping_bag_outlined),
                selectedIcon: Icon(Icons.shopping_bag),
                label: Text('Orders'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.account_balance_wallet_outlined),
                selectedIcon: Icon(Icons.account_balance_wallet),
                label: Text('Top-ups'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.analytics_outlined),
                selectedIcon: Icon(Icons.analytics),
                label: Text('Reports'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings),
                label: Text('Settings'),
              ),
            ],
          ),
          const VerticalDivider(thickness: 1, width: 1),
          // Main Content
          Expanded(
            child: child,
          ),
        ],
      ),
    );
  }

  /// Build responsive drawer for mobile/tablet
  Widget _buildDrawer(BuildContext context, WidgetRef ref, String currentRoute) {
    final selectedIndex = _getSelectedIndex(currentRoute);
    
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.school,
                  size: 48,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 12),
                Text(
                  'Canteen Admin',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          _buildDrawerItem(
            context, 
            icon: Icons.dashboard_outlined, 
            selectedIcon: Icons.dashboard,
            title: 'Dashboard', 
            index: 0, 
            selectedIndex: selectedIndex,
          ),
          _buildDrawerItem(
            context, 
            icon: Icons.people_outlined, 
            selectedIcon: Icons.people,
            title: 'Students', 
            index: 1, 
            selectedIndex: selectedIndex,
          ),
          _buildDrawerItem(
            context, 
            icon: Icons.family_restroom_outlined, 
            selectedIcon: Icons.family_restroom,
            title: 'Parents', 
            index: 2, 
            selectedIndex: selectedIndex,
          ),
          _buildDrawerItem(
            context, 
            icon: Icons.restaurant_menu_outlined, 
            selectedIcon: Icons.restaurant_menu,
            title: 'Menu', 
            index: 3, 
            selectedIndex: selectedIndex,
          ),
          _buildDrawerItem(
            context, 
            icon: Icons.shopping_bag_outlined, 
            selectedIcon: Icons.shopping_bag,
            title: 'Orders', 
            index: 4, 
            selectedIndex: selectedIndex,
          ),
          _buildDrawerItem(
            context, 
            icon: Icons.account_balance_wallet_outlined, 
            selectedIcon: Icons.account_balance_wallet,
            title: 'Top-ups', 
            index: 5, 
            selectedIndex: selectedIndex,
          ),
          _buildDrawerItem(
            context, 
            icon: Icons.analytics_outlined, 
            selectedIcon: Icons.analytics,
            title: 'Reports', 
            index: 6, 
            selectedIndex: selectedIndex,
          ),
          _buildDrawerItem(
            context, 
            icon: Icons.settings_outlined, 
            selectedIcon: Icons.settings,
            title: 'Settings', 
            index: 7, 
            selectedIndex: selectedIndex,
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Logout'),
            onTap: () async {
              Navigator.of(context).pop(); // Close drawer
              await ref.read(authServiceProvider).signOut();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(
    BuildContext context, {
    required IconData icon,
    required IconData selectedIcon,
    required String title,
    required int index,
    required int selectedIndex,
  }) {
    final isSelected = index == selectedIndex;
    
    return ListTile(
      leading: Icon(isSelected ? selectedIcon : icon),
      title: Text(title),
      selected: isSelected,
      onTap: () {
        Navigator.of(context).pop(); // Close drawer
        _navigateToIndex(context, index);
      },
    );
  }

  String _getPageTitle(String route) {
    if (route.startsWith('/dashboard')) return 'Dashboard';
    if (route.startsWith('/students')) return 'Students';
    if (route.startsWith('/parents')) return 'Parents';
    if (route.startsWith('/menu')) return 'Menu';
    if (route.startsWith('/orders')) return 'Orders';
    if (route.startsWith('/topups')) return 'Top-ups';
    if (route.startsWith('/reports')) return 'Reports';
    if (route.startsWith('/settings')) return 'Settings';
    return 'Canteen Admin';
  }

  int _getSelectedIndex(String route) {
    if (route.startsWith('/dashboard')) return 0;
    if (route.startsWith('/students')) return 1;
    if (route.startsWith('/parents')) return 2;
    if (route.startsWith('/menu')) return 3;
    if (route.startsWith('/orders')) return 4;
    if (route.startsWith('/topups')) return 5;
    if (route.startsWith('/reports')) return 6;
    if (route.startsWith('/settings')) return 7;
    return 0;
  }

  void _navigateToIndex(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go('/dashboard');
        break;
      case 1:
        context.go('/students');
        break;
      case 2:
        context.go('/parents');
        break;
      case 3:
        context.go('/menu');
        break;
      case 4:
        context.go('/orders');
        break;
      case 5:
        context.go('/topups');
        break;
      case 6:
        context.go('/reports');
        break;
      case 7:
        context.go('/settings');
        break;
    }
  }
}
