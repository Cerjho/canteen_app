import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../interfaces/i_auth_service.dart';
import '../interfaces/i_user_service.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';
import '../services/registration_service.dart';
import '../models/user_role.dart';
import 'supabase_providers.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;
import 'package:flutter/foundation.dart' show kIsWeb;

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
  return ref.watch(userServiceProvider).getUserStream(user.id);
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

// ============================================================================
// POST-AUTH PROVISIONING LISTENER
// ============================================================================
/// Ensures that after a successful sign-in (email link or OAuth), the corresponding
/// rows in `users` and `parents` tables exist. If missing, creates minimal parent
/// profile so onboarding can proceed.
///
/// This addresses the common case where signUp requires email verification, so
/// DB inserts during registration fail due to RLS until the user confirms and
/// signs in. On the first real session, we provision the records.
final authProvisioningListener = Provider<void>((ref) {
  ref.listen<AsyncValue<User?>>(authStateProvider, (previous, next) async {
    final supaUser = next.value;
    if (supaUser == null) return;
    // Do NOT provision on web for parent flows
    if (kIsWeb) return;

    try {
      // If user row already exists, nothing to do
      final existing = await ref.read(userServiceProvider).getUser(supaUser.id);
      if (existing != null) return;

      // Derive basic names from metadata or email
      final email = supaUser.email ?? '';
      final fullName = (supaUser.userMetadata?['full_name'] ?? supaUser.userMetadata?['name'] ?? email.split('@').first) as String;
      final parts = fullName.trim().split(RegExp(r"\s+"));
      final firstName = parts.isNotEmpty ? parts.first : 'Parent';
      final lastName = parts.length > 1 ? parts.sublist(1).join(' ') : '';

      // Create a minimal users row only; parent profile will be created
      // during the complete-registration flow.
      final now = DateTime.now();
      final appUser = AppUser(
        uid: supaUser.id,
        firstName: firstName,
        lastName: lastName,
        email: email,
        isAdmin: false,
        isParent: true,
        createdAt: now,
        isActive: true,
        needsOnboarding: true,
      );
      await ref.read(userServiceProvider).createUser(appUser);
    } catch (_) {
      // Best-effort; failures are logged by the underlying services
    }
  });
});
