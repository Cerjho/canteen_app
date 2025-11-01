import 'package:go_router/go_router.dart';
import '../features/admin/dashboard/dashboard_screen.dart';
import '../features/admin/students/students_screen.dart';
import '../features/admin/students/student_form_screen.dart';
import '../features/admin/parents/parents_screen.dart';
import '../features/admin/parents/parent_form_screen.dart';
import '../features/admin/menu/menu_screen.dart';
import '../features/admin/menu/menu_item_form_screen.dart';
import '../features/admin/orders/orders_screen.dart';
import '../features/admin/orders/order_details_screen.dart';
import '../features/admin/topups/topups_screen.dart';
import '../features/admin/reports/reports_screen.dart';
import '../features/admin/settings/settings_screen.dart';
import '../features/admin/widgets/admin_scaffold.dart';

/// Admin-only routes for web dashboard
/// 
/// Includes full admin features:
/// - Dashboard with analytics
/// - Student management (CRUD, CSV import/export)
/// - Parent management (CRUD, balance management)
/// - Menu management (items, weekly menus, analytics)
/// - Order management (list, details, status updates)
/// - Top-up management (approve/decline workflow)
/// - Reports (analytics, exports)
/// - Settings (configuration, data seeding)
List<RouteBase> buildAdminRoutes() {
  return [
    // Admin Routes (with scaffold wrapper for navigation rail)
    ShellRoute(
      builder: (context, state, child) {
        return AdminScaffold(child: child);
      },
      routes: [
        // Dashboard
        GoRoute(
          path: '/dashboard',
          builder: (context, state) => const DashboardScreen(),
        ),
        
        // Students Management
        GoRoute(
          path: '/students',
          builder: (context, state) => const StudentsScreen(),
        ),
        GoRoute(
          path: '/students/new',
          builder: (context, state) => const StudentFormScreen(mode: StudentFormMode.add),
        ),
        GoRoute(
          path: '/students/:id/edit',
          builder: (context, state) {
            // Note: Student editing is handled via dialog in StudentsScreen
            // This route redirects back to the students list
            return const StudentsScreen();
          },
        ),

        // Parents Management
        GoRoute(
          path: '/parents',
          builder: (context, state) => const ParentsScreen(),
        ),
        GoRoute(
          path: '/parents/new',
          builder: (context, state) => const ParentFormScreen(),
        ),
        GoRoute(
          path: '/parents/:id/edit',
          builder: (context, state) {
            final id = state.pathParameters['id']!;
            return ParentFormScreen(parentId: id);
          },
        ),

        // Menu Management
        GoRoute(
          path: '/menu',
          builder: (context, state) => const MenuScreen(),
        ),
        GoRoute(
          path: '/menu/new',
          builder: (context, state) => const MenuItemFormScreen(mode: MenuItemFormMode.add),
        ),
        GoRoute(
          path: '/menu/:id/edit',
          builder: (context, state) {
            // Note: Menu item editing is handled via dialog in MenuScreen
            // This route redirects back to the menu list
            return const MenuScreen();
          },
        ),

        // Orders Management
        GoRoute(
          path: '/orders',
          builder: (context, state) => const OrdersScreen(),
        ),
        GoRoute(
          path: '/orders/:id',
          builder: (context, state) {
            final id = state.pathParameters['id']!;
            return OrderDetailsScreen(orderId: id);
          },
        ),

        // Top-ups Management
        GoRoute(
          path: '/topups',
          builder: (context, state) => const TopupsScreen(),
        ),

        // Reports
        GoRoute(
          path: '/reports',
          builder: (context, state) => const ReportsScreen(),
        ),

        // Settings
        GoRoute(
          path: '/settings',
          builder: (context, state) => const SettingsScreen(),
        ),
      ],
    ),
  ];
}
