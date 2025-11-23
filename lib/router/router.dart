import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart' show kIsWeb, ChangeNotifier;
import 'package:supabase_flutter/supabase_flutter.dart' show User;
import '../core/providers/app_providers.dart';
import '../core/models/user_role.dart';
import '../features/admin/auth/admin_signin_screen.dart';
import '../features/admin/auth/access_denied_screen.dart';
import '../features/parent/auth/login_screen.dart';
import '../features/parent/auth/registration_screen.dart';
import '../features/parent/auth/registration_info_screen.dart';
import 'admin_routes.dart';
import 'parent_routes.dart';

/// Router refresh notifier - only notifies when auth state actually changes
class RouterRefreshNotifier extends ChangeNotifier {
  String? _lastUserId;
  
  void onAuthStateChange(String? userId) {
    if (_lastUserId != userId) {
      _lastUserId = userId;
      notifyListeners();
    }
  }
}

final _routerRefreshNotifier = RouterRefreshNotifier();

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
  // Start post-auth provisioning side-effect
  ref.watch(authProvisioningListener);
  // Listen to auth state but only notify router when user actually changes
  ref.listen<AsyncValue<User?>>(authStateProvider, (previous, next) {
    _routerRefreshNotifier.onAuthStateChange(next.value?.id);
  });

  return GoRouter(
    initialLocation: '/login',
    refreshListenable: _routerRefreshNotifier,
    redirect: (context, state) async {
      // Handle Android/iOS auth callback deep links
      try {
        final uri = state.uri; // GoRouterState exposes the full uri
        final pathHit = uri.path.contains('/auth-callback') || uri.path.contains('auth-callback');
        final hostHit = (uri.host).contains('auth-callback');
        final typeSignup = uri.queryParameters['type'] == 'signup';
        final errorCode = uri.queryParameters['error_code'];
        if (pathHit || hostHit || typeSignup) {
          // If the deep link reports an error (e.g., otp_expired), send to info screen to allow resend
          if (errorCode != null) {
            return '/registration-info';
          }
          return '/complete-registration';
        }
      } catch (_) {
        // Ignore if state.uri isn't available on older go_router versions
      }

      final authState = ref.read(authStateProvider);
      final isLoggedIn = authState.value != null;
      final isLoginRoute = state.matchedLocation == '/login';
      final isRegisterRoute = state.matchedLocation == '/register';
      final isRegistrationInfoRoute = state.matchedLocation == '/registration-info';
      // Registration completion flow routes (allowed before role exists)
      final isCompleteRegistrationRoute = state.matchedLocation == '/complete-registration';
      final isLinkStudentRoute = state.matchedLocation == '/link-student';
      final isRegistrationSuccessRoute = state.matchedLocation == '/registration-success';
      final isAccessDeniedRoute = state.matchedLocation == '/access-denied';
      // Treat registration-info and registration completion flow as auth routes
      // so users without roles can access them
      final isAuthRoute = isLoginRoute ||
          isRegisterRoute ||
          isRegistrationInfoRoute ||
          isCompleteRegistrationRoute ||
          isLinkStudentRoute ||
          isRegistrationSuccessRoute;

      // Not logged in, redirect to login (except if already on auth routes)
      if (!isLoggedIn && !isAuthRoute) {
        return '/login';
      }

      // Logged in, enforce onboarding and check role-based access (exclude auth/onboarding and access denied routes)
      if (isLoggedIn && !isAuthRoute && !isAccessDeniedRoute) {
        // If user still needs onboarding, force them to complete it
        final currentUser = ref.read(currentUserProvider).value;
        if (currentUser?.needsOnboarding == true) {
          if (kIsWeb) return '/access-denied';
          return '/complete-registration';
        }
        // Use cached userRoleProvider instead of calling getCurrentUserRole repeatedly
        final userRoleAsync = ref.read(userRoleProvider);
        
        // If role check is loading, allow navigation (prevents redirect loops)
        if (userRoleAsync is AsyncLoading) {
          return null;
        }
        
        UserRole? userRole;
        if (userRoleAsync is AsyncData<UserRole?>) {
          userRole = userRoleAsync.value;
        } else if (userRoleAsync is AsyncError) {
          print('Router: Error getting user role: ${userRoleAsync.error}');
          // Allow navigation on error to prevent loops
          return null;
        }
        
        // If user has no role, send them to complete-registration flow
        if (userRole == null) {
          print('Router: User role is null, redirecting to complete-registration');
          // Parents are mobile-only; if on web, deny.
          if (kIsWeb) return '/access-denied';
          return '/complete-registration';
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

      // If logged in and on login or registration info page, redirect based on role
      if (isLoggedIn && (isLoginRoute || isRegistrationInfoRoute)) {
        // If onboarding required, go directly to onboarding
        final currentUser = ref.read(currentUserProvider).value;
        if (currentUser?.needsOnboarding == true) {
          if (kIsWeb) return '/access-denied';
          return '/complete-registration';
        }
        UserRole? userRole;
        try {
          userRole = await ref.read(authServiceProvider).getCurrentUserRole();
        } catch (e) {
          print('Router: Error getting user role on login redirect: $e');
          // Stay on login page if there's an error
          return null;
        }
        
        // For first-time Google sign-in, role might be null initially
        // Wait briefly and retry to handle Supabase write latency
        if (userRole == null) {
          print('Router: User role is null on login, retrying...');
          await Future.delayed(const Duration(milliseconds: 500));
          try {
            final retryRole = await ref.read(authServiceProvider).getCurrentUserRole();
            
            if (retryRole == UserRole.admin) {
              print('Router: Retry found admin role, redirecting to dashboard');
              return '/dashboard';
            } else if (retryRole == UserRole.parent) {
              print('Router: Retry found parent role, redirecting to parent-dashboard');
              return '/parent-dashboard';
            }
          } catch (e) {
            print('Router: Error on retry: $e');
          }
          
          // Still no valid role found - send to complete registration
          print('Router: Still no valid role after retry, redirecting to complete-registration');
          if (kIsWeb) return '/access-denied';
          return '/complete-registration';
        }
        
        // Route based on role
        if (userRole == UserRole.admin) {
          return '/dashboard';
        } else if (userRole == UserRole.parent) {
          // Parent users cannot access the app on web
          if (kIsWeb) return '/access-denied';
          // Default to parent dashboard on normal app start
          // Deep-link flow to complete-registration is handled above when auth-callback is present
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
    // Registration info can be accessed without being logged in
    GoRoute(
      path: '/registration-info',
      builder: (context, state) => const RegistrationInfoScreen(),
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
