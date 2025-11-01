import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../interfaces/i_auth_service.dart';
import '../interfaces/i_user_service.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';
import '../services/registration_service.dart';
import '../models/user_role.dart';
import 'supabase_providers.dart';

// ============================================================================
// AUTHENTICATION & USER SERVICE PROVIDERS
// ============================================================================

/// Registration Service Provider
/// 
/// Used for creating new user accounts (admin/parent registration).
/// Must be created before AuthService since AuthService depends on it.
final registrationServiceProvider = Provider<RegistrationService>((ref) {
  return RegistrationService(
    supabase: ref.watch(supabaseProvider),
  );
});

/// User Service Provider
/// 
/// Handles user profile management (CRUD operations on user documents).
final userServiceProvider = Provider<IUserService>((ref) {
  return UserService(
    supabase: ref.watch(supabaseProvider),
  );
});

/// Auth Service Provider
/// 
/// Handles authentication operations (sign in, sign out, Google auth).
/// Depends on: Supabase, UserService, RegistrationService
final authServiceProvider = Provider<IAuthService>((ref) {
  return AuthService(
    supabase: ref.watch(supabaseProvider),
    userService: ref.watch(userServiceProvider) as UserService,
    registrationService: ref.watch(registrationServiceProvider),
  );
});

// ============================================================================
// AUTHENTICATION STATE PROVIDERS
// ============================================================================

/// Auth State Stream Provider
/// 
/// Emits Firebase Auth state changes (user signed in/out).
/// Returns: Stream<User?> - null when signed out
final authStateProvider = StreamProvider((ref) {
  return ref.watch(authServiceProvider).authStateChanges;
});

/// Current User Provider
/// 
/// Streams the complete AppUser profile for the currently signed-in user.
/// Automatically updates when user profile changes in Firestore.
/// Returns: Stream<AppUser?> - null when not signed in
final currentUserProvider = StreamProvider<AppUser?>((ref) {
  final authState = ref.watch(authStateProvider);
  final user = authState.value;
  if (user == null) return Stream.value(null);
  return ref.watch(userServiceProvider).getUserStream(user.uid);
});

/// User Role Provider
/// 
/// Fetches the current user's role (admin/parent).
/// Returns: Future<UserRole?> - null when not signed in
final userRoleProvider = FutureProvider<UserRole?>((ref) async {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return null;
  return await ref.watch(authServiceProvider).getCurrentUserRole();
});

/// Is Admin Provider
/// 
/// Checks if current user has admin role.
/// Returns: Future<bool>
final isAdminProvider = FutureProvider<bool>((ref) async {
  final role = await ref.watch(userRoleProvider.future);
  return role == UserRole.admin;
});

/// Is Parent Provider
/// 
/// Checks if current user has parent role.
/// Returns: Future<bool>
final isParentProvider = FutureProvider<bool>((ref) async {
  final role = await ref.watch(userRoleProvider.future);
  return role == UserRole.parent;
});
