import 'package:go_router/go_router.dart';
import '../features/parent/parent_app.dart';
import '../features/parent/auth/complete_registration_screen.dart';
import '../features/parent/auth/link_student_screen.dart';
import '../features/parent/auth/registration_success_screen.dart';

/// Parent-only routes
/// 
/// Includes parent-specific features:
/// - Parent dashboard (home screen)
/// - View student profiles and balances
/// - Browse menu and place orders
/// - Request balance top-ups
/// - View order history
/// - Manage profile
/// 
/// Note: Authentication routes (login/register) are now shared
/// and defined in router.dart for all users.
/// 
/// TODO: Expand with additional parent features:
/// - /parent-dashboard/students - View linked students
/// - /parent-dashboard/menu - Browse menu
/// - /parent-dashboard/orders - Order history
/// - /parent-dashboard/orders/:id - Order details
/// - /parent-dashboard/topups - Request top-ups
/// - /parent-dashboard/profile - Edit profile
List<RouteBase> buildParentRoutes() {
  return [
    // Parent Dashboard (with bottom navigation)
    GoRoute(
      path: '/parent-dashboard',
      builder: (context, state) => const ParentApp(),
    ),

    // Registration completion flow (post verification)
    GoRoute(
      path: '/complete-registration',
      builder: (context, state) => const CompleteRegistrationScreen(),
    ),
    GoRoute(
      path: '/link-student',
      builder: (context, state) => const LinkStudentScreen(),
    ),
    GoRoute(
      path: '/registration-success',
      builder: (context, state) => const RegistrationSuccessScreen(),
    ),
    
    // TODO: Add additional parent routes as they are implemented
    // Example:
    // GoRoute(
    //   path: '/parent-dashboard/students',
    //   builder: (context, state) => const ParentStudentsScreen(),
    // ),
    // GoRoute(
    //   path: '/parent-dashboard/menu',
    //   builder: (context, state) => const ParentMenuScreen(),
    // ),
    // GoRoute(
    //   path: '/parent-dashboard/orders',
    //   builder: (context, state) => const ParentOrdersScreen(),
    // ),
    // GoRoute(
    //   path: '/parent-dashboard/orders/:id',
    //   builder: (context, state) {
    //     final id = state.pathParameters['id']!;
    //     return ParentOrderDetailsScreen(orderId: id);
    //   },
    // ),
    // GoRoute(
    //   path: '/parent-dashboard/topups',
    //   builder: (context, state) => const ParentTopupsScreen(),
    // ),
    // GoRoute(
    //   path: '/parent-dashboard/profile',
    //   builder: (context, state) => const ParentProfileScreen(),
    // ),
  ];
}
