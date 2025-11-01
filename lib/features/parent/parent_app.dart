import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:responsive_builder/responsive_builder.dart';
import 'dashboard/parent_dashboard_screen.dart';
import 'menu/parent_menu_screen.dart';
import 'orders/orders_screen.dart';
import 'wallet/wallet_screen.dart';
import 'settings/settings_screen.dart';

/// Parent App - Main entry point for parent-facing features
/// 
/// Core Features:
/// 1. Student Linking - Link to children using student ID/QR code
/// 2. Weekly Menu & Advance Ordering - Browse and order meals in advance
/// 3. Manage Orders - View, edit, cancel orders
/// 4. Payments & Wallet - Top-ups and balance management
/// 5. Dashboard - Quick summary and shortcuts
/// 6. Settings/Profile - Account management
/// 7. Multi-Platform Layout - Responsive design for all devices
/// 8. Auth & Security - Secure parent-only access

/// Navigation destination model
class NavDestination {
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final Widget screen;

  const NavDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.screen,
  });
}

/// Available navigation destinations
final List<NavDestination> navDestinations = [
  NavDestination(
    label: 'Dashboard',
    icon: Icons.dashboard_outlined,
    selectedIcon: Icons.dashboard,
    screen: const ParentDashboardScreen(),
  ),
  NavDestination(
    label: 'Menu',
    icon: Icons.restaurant_menu_outlined,
    selectedIcon: Icons.restaurant_menu,
    screen: const ParentMenuScreen(),
  ),
  NavDestination(
    label: 'Orders',
    icon: Icons.receipt_long_outlined,
    selectedIcon: Icons.receipt_long,
    screen: const OrdersScreen(),
  ),
  NavDestination(
    label: 'Wallet',
    icon: Icons.account_balance_wallet_outlined,
    selectedIcon: Icons.account_balance_wallet,
    screen: const WalletScreen(),
  ),
  NavDestination(
    label: 'Settings',
    icon: Icons.settings_outlined,
    selectedIcon: Icons.settings,
    screen: const SettingsScreen(),
  ),
];

/// Parent App with responsive navigation
class ParentApp extends ConsumerStatefulWidget {
  const ParentApp({super.key});

  @override
  ConsumerState<ParentApp> createState() => _ParentAppState();
}

class _ParentAppState extends ConsumerState<ParentApp> {
  int _selectedIndex = 0;

  void _onDestinationSelected(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
  // ScreenUtil is initialized at the app root level (main_parent_mobile.dart)
    return ResponsiveBuilder(
      builder: (context, sizingInformation) {
        final deviceType = sizingInformation.deviceScreenType;
        
        // Mobile: Bottom navigation
        if (deviceType == DeviceScreenType.mobile) {
          return _buildMobileLayout();
        }
        
        // Tablet: Navigation rail
        if (deviceType == DeviceScreenType.tablet) {
          return _buildTabletLayout();
        }
        
        // Desktop/Web: Sidebar navigation
        return _buildDesktopLayout();
      },
    );
  }

  /// Mobile layout with bottom navigation bar
  Widget _buildMobileLayout() {
    return Scaffold(
      body: navDestinations[_selectedIndex].screen,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onDestinationSelected,
        destinations: navDestinations.map((dest) {
          return NavigationDestination(
            icon: Icon(dest.icon),
            selectedIcon: Icon(dest.selectedIcon),
            label: dest.label,
          );
        }).toList(),
      ),
    );
  }

  /// Tablet layout with navigation rail
  Widget _buildTabletLayout() {
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: _onDestinationSelected,
            labelType: NavigationRailLabelType.all,
            destinations: navDestinations.map((dest) {
              return NavigationRailDestination(
                icon: Icon(dest.icon),
                selectedIcon: Icon(dest.selectedIcon),
                label: Text(dest.label),
              );
            }).toList(),
          ),
          const VerticalDivider(width: 1, thickness: 1),
          Expanded(
            child: navDestinations[_selectedIndex].screen,
          ),
        ],
      ),
    );
  }

  /// Larger-screen layout (tablet/desktop-sized devices) with sidebar navigation drawer
  /// Note: Parent app is mobile-first and mobile-only as an app binary; larger
  /// layouts are provided for tablets and foldables via responsive UI.
  Widget _buildDesktopLayout() {
    return Scaffold(
      body: Row(
        children: [
          // Permanent sidebar
          SizedBox(
            width: 280.w,
            child: Drawer(
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
                          Icons.restaurant,
                          size: 48.sp,
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                        SizedBox(height: 12.h),
                        Text(
                          'Loheca Canteen',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                color: Theme.of(context).colorScheme.onPrimaryContainer,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        Text(
                          'Parent Portal',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(context).colorScheme.onPrimaryContainer,
                              ),
                        ),
                      ],
                    ),
                  ),
                  ...navDestinations.asMap().entries.map((entry) {
                    final index = entry.key;
                    final dest = entry.value;
                    final isSelected = index == _selectedIndex;
                    
                    return ListTile(
                      leading: Icon(
                        isSelected ? dest.selectedIcon : dest.icon,
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.onSurface,
                      ),
                      title: Text(
                        dest.label,
                        style: TextStyle(
                          color: isSelected
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.onSurface,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      selected: isSelected,
                      onTap: () => _onDestinationSelected(index),
                    );
                  }),
                ],
              ),
            ),
          ),
          const VerticalDivider(width: 1, thickness: 1),
          Expanded(
            child: navDestinations[_selectedIndex].screen,
          ),
        ],
      ),
    );
  }
}
