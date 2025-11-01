import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../core/providers/app_providers.dart';
import '../core/models/user_role.dart';
import '../features/admin/auth/admin_signin_screen.dart';
import '../features/admin/auth/access_denied_screen.dart';
import '../features/parent/auth/login_screen.dart';
import '../features/parent/auth/registration_screen.dart';
import 'admin_routes.dart';
import 'parent_routes.dart';

/// Main router provider with unified authentication and role-based routing
/// 
/// **Architecture:**
/// - Single shared login screen for all users
/// - Automatic role-based routing after authentication
/// - All routes (admin + parent) available in single app
/// 
/// **Security:**
/// - Role-based redirect logic enforces proper access
/// - Admin users → `/dashboard` (Admin Dashboard)
/// - Parent users → `/parent-dashboard` (Parent Dashboard)
/// - No role/Invalid → Access denied
/// 
/// **Usage:**
/// Users are automatically routed to the correct dashboard based on their role.
/// No need for separate app variants or app config.
final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/login',
    redirect: (context, state) async {
      final isLoggedIn = authState.value != null;
      final isLoginRoute = state.matchedLocation == '/login';
      final isRegisterRoute = state.matchedLocation == '/register';
      final isAccessDeniedRoute = state.matchedLocation == '/access-denied';
      final isAuthRoute = isLoginRoute || isRegisterRoute;

      // Not logged in, redirect to login (except if already on auth routes)
      if (!isLoggedIn && !isAuthRoute) {
        return '/login';
      }

      // Logged in, check role-based access (exclude auth and access denied routes)
      if (isLoggedIn && !isAuthRoute && !isAccessDeniedRoute) {
        final userRole = await ref.read(authServiceProvider).getCurrentUserRole();
        
        // If user has no role, deny access
        if (userRole == null) {
          return '/access-denied';
        }
        
        // Role-based route protection
        final location = state.matchedLocation;
        
        // Admin routes protection
        if (location.startsWith('/dashboard') || 
            location.startsWith('/menu') || 
            location.startsWith('/orders') ||
            location.startsWith('/students') ||
            location.startsWith('/parents-management') ||
            location.startsWith('/topups') ||
            location.startsWith('/settings') ||
            location.startsWith('/reports')) {
          // Only admins can access admin routes
          if (userRole != UserRole.admin) {
            return '/access-denied';
          }
        }
        
        // Parent routes protection
        if (location.startsWith('/parent-dashboard') ||
            location.startsWith('/parent-menu') ||
            location.startsWith('/parent-orders') ||
            location.startsWith('/parent-wallet') ||
            location.startsWith('/parent-students') ||
            location.startsWith('/parent-settings')) {
          // Parent routes are mobile-only; deny access on web or if not a parent
          if (kIsWeb || userRole != UserRole.parent) {
            return '/access-denied';
          }
        }
      }

      // If logged in and on login page, redirect based on role
      if (isLoggedIn && isLoginRoute) {
        final userRole = await ref.read(authServiceProvider).getCurrentUserRole();
        
        // For first-time Google sign-in, role might be null initially
        // Wait briefly and retry to handle Firestore write latency
        if (userRole == null) {
          await Future.delayed(const Duration(milliseconds: 500));
          final retryRole = await ref.read(authServiceProvider).getCurrentUserRole();
          
          if (retryRole == UserRole.admin) {
            return '/dashboard';
          } else if (retryRole == UserRole.parent) {
            return '/parent-dashboard';
          }
          
          // Still no valid role found - deny access
          return '/access-denied';
        }
        
        // Route based on role
        if (userRole == UserRole.admin) {
          return '/dashboard';
        } else if (userRole == UserRole.parent) {
          // Parent users cannot access the app on web
          if (kIsWeb) return '/access-denied';
          return '/parent-dashboard';
        }
        
        // No valid role found
        return '/access-denied';
      }

      return null;
    },
    routes: _buildRoutes(),
  );
});

/// Build complete route list with shared auth routes + all app routes
/// 
/// Combines:
/// 1. Shared authentication routes (login, register, access denied)
/// 2. All app routes (admin + parent routes)
/// 
/// Role-based access control is handled by the redirect logic above.
List<RouteBase> _buildRoutes() {
  // Authentication routes (platform-aware):
  // - Admin uses AdminSignInScreen on web
  // - Parent uses ParentLoginScreen / ParentRegistrationScreen on mobile
  // - Access denied screen lives under admin features
  final authRoutes = [
    GoRoute(
      path: '/login',
      builder: (context, state) => kIsWeb ? const AdminSignInScreen() : const ParentLoginScreen(),
    ),
    GoRoute(
      path: '/register',
      builder: (context, state) => const ParentRegistrationScreen(),
    ),
    GoRoute(
      path: '/access-denied',
      builder: (context, state) => const AdminAccessDeniedScreen(),
    ),
  ];

  // Include both admin and parent routes
  // Access control is handled by redirect logic
  final adminRoutes = buildAdminRoutes();
  // Only register parent routes for non-web platforms (parent is mobile-only)
  final parentRoutes = kIsWeb ? <RouteBase>[] : buildParentRoutes();

  // Combine and return all routes
  return [...authRoutes, ...adminRoutes, ...parentRoutes];
}
