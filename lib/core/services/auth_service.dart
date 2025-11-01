import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/user_role.dart';
import '../interfaces/i_auth_service.dart';
import 'user_service.dart';
import 'registration_service.dart';
import '../utils/app_logger.dart';

/// Authentication Service - handles user authentication with Supabase Auth
class AuthService implements IAuthService {
  final SupabaseClient _supabase;
  final GoogleSignIn _googleSignIn;
  final UserService _userService;
  final RegistrationService _registrationService;

  /// Constructor with dependency injection
  /// 
  /// [supabase] - Optional SupabaseClient instance for testing
  /// [googleSignIn] - Optional GoogleSignIn instance for testing
  /// [userService] - Optional UserService instance for testing
  /// [registrationService] - Required RegistrationService for post-sign-in provisioning
  AuthService({
    SupabaseClient? supabase,
    GoogleSignIn? googleSignIn,
    UserService? userService,
    required RegistrationService registrationService,
  })  : _supabase = supabase ?? Supabase.instance.client,
        _googleSignIn = googleSignIn ?? GoogleSignIn(
          scopes: const ['email', 'profile'],
        ),
        _userService = userService ?? UserService(),
        _registrationService = registrationService;

  /// Get user's email from Supabase User object
  static String? getUserEmail(User? user) {
    return user?.email;
  }

  /// Get user's display name from Supabase User object
  static String? getUserDisplayName(User? user) {
    return user?.userMetadata?['full_name'] ?? user?.userMetadata?['name'];
  }

  /// Get current user
  @override
  User? get currentUser => _supabase.auth.currentUser;

  /// Auth state changes stream
  @override
  Stream<User?> get authStateChanges => _supabase.auth.onAuthStateChange.map((state) => state.session?.user);

  /// Get current user's role from database
  @override
  Future<UserRole?> getCurrentUserRole() async {
    final user = currentUser;
    if (user == null) return null;
    
    try {
      // Get role from database (Supabase doesn't have custom claims like Firebase)
      return await _userService.getUserRole(user.id);
    } catch (e) {
      rethrow;
    }
  }

  /// Check if current user is admin
  Future<bool> isCurrentUserAdmin() async {
    final role = await getCurrentUserRole();
    return role == UserRole.admin;
  }

  /// Check if current user is parent
  Future<bool> isCurrentUserParent() async {
    final role = await getCurrentUserRole();
    return role == UserRole.parent;
  }

  // Interface-compliant wrapper methods for IAuthService
  @override
  Future<bool> isAdmin() async => await isCurrentUserAdmin();

  @override
  Future<bool> isParent() async => await isCurrentUserParent();

  /// Get current user's app user data
  Future<AppUser?> getCurrentAppUser() async {
    final user = currentUser;
    if (user == null) return null;
    
    return await _userService.getUser(user.id);
  }

  /// Sign in with email and password
  @override
  Future<AuthResponse> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    try {
      return await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Sign in with Google
  /// Uses Supabase OAuth on both web and mobile
  @override
  Future<AuthResponse?> signInWithGoogle() async {
    try {
      AppLogger.debug('signInWithGoogle(): start');
      
      if (kIsWeb) {
        AppLogger.debug('signInWithGoogle(): using web OAuth flow');
        // Web: Use Supabase OAuth
        await _supabase.auth.signInWithOAuth(
          OAuthProvider.google,
          redirectTo: kIsWeb ? null : 'io.supabase.canteenapp://login-callback/',
        );
        
        // For web, the browser handles the redirect, so we return null
        return null; // Web OAuth redirects, no immediate response
      } else {
        // Mobile: Use google_sign_in package for better UX
        AppLogger.debug('signInWithGoogle(): calling GoogleSignIn.signIn()');
        final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
        AppLogger.debug('signInWithGoogle(): GoogleSignIn.signIn() returned: $googleUser');
        
        if (googleUser == null) {
          AppLogger.info('signInWithGoogle(): user cancelled Google sign-in');
          throw Exception('Google sign-in was cancelled');
        }

        // Get auth details
        final googleAuth = await googleUser.authentication;
        final accessToken = googleAuth.accessToken;
        final idToken = googleAuth.idToken;

        if (accessToken == null) {
          throw Exception('No access token found.');
        }
        if (idToken == null) {
          throw Exception('No ID token found.');
        }

        // Sign in to Supabase with Google credentials
        final response = await _supabase.auth.signInWithIdToken(
          provider: OAuthProvider.google,
          idToken: idToken,
          accessToken: accessToken,
        );

        AppLogger.info('signInWithGoogle(): Supabase signInWithIdToken returned user id=${response.user?.id}');

        // Post sign-in: ensure database 'users' and 'parents' records exist
        try {
          final user = response.user;
          if (user != null) {
            final existingUser = await _userService.getUser(user.id);
            if (existingUser == null) {
              // Create parent and user records
              final fullName = user.userMetadata?['full_name'] ?? user.userMetadata?['name'] ?? 'Google User';
              final nameParts = fullName.split(' ');
              final firstName = nameParts.first;
              final lastName = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';
              final email = user.email ?? '';

              try {
                await _registrationService.registerParentWithExistingAuth(
                  uid: user.id,
                  firstName: firstName,
                  lastName: lastName,
                  email: email,
                  phone: user.phone,
                  address: null,
                );
                AppLogger.info('Created missing user/parent documents for id=${user.id}');
              } catch (regErr) {
                AppLogger.warning('Failed to create user/parent documents for id=${user.id}: $regErr');
              }
            }
          }
        } catch (e) {
          AppLogger.warning('Post sign-in database check/create failed: $e');
        }

        AppLogger.debug('signInWithGoogle(): returning success');
        return response;
      }
    } catch (e) {
      AppLogger.error('signInWithGoogle(): error: $e', error: e);
      rethrow;
    }
  }

  /// Sign out
  @override
  Future<void> signOut() async {
    await _supabase.auth.signOut();
    await _googleSignIn.signOut();
  }

  /// Reset password
  @override
  Future<void> sendPasswordResetEmail(String email) async {
    await _supabase.auth.resetPasswordForEmail(email);
  }

  /// Reset password (legacy method - kept for backward compatibility)
  Future<void> resetPassword(String email) async {
    await sendPasswordResetEmail(email);
  }

  /// Create user with email and password (for admin registration)
  Future<AuthResponse> createUserWithEmailAndPassword(
    String email,
    String password,
  ) async {
    try {
      return await _supabase.auth.signUp(
        email: email,
        password: password,
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Update user email
  Future<UserResponse> updateEmail(String newEmail) async {
    return await _supabase.auth.updateUser(
      UserAttributes(email: newEmail),
    );
  }

  /// Update user password
  @override
  Future<UserResponse> updatePassword(String newPassword) async {
    return await _supabase.auth.updateUser(
      UserAttributes(password: newPassword),
    );
  }

  /// Send email verification
  Future<void> sendEmailVerification() async {
    // Supabase handles email verification automatically during signup
    // This method is kept for interface compatibility
    AppLogger.warning('sendEmailVerification() called - Supabase handles this automatically');
  }

  /// Check if email is verified
  bool get isEmailVerified {
    final user = currentUser;
    return user?.emailConfirmedAt != null;
  }

  /// Reload current user
  Future<void> reloadUser() async {
    // Supabase automatically keeps user data fresh
    // This method is kept for interface compatibility
    await _supabase.auth.refreshSession();
  }

  /// Reauthenticate with password (required before sensitive operations)
  @override
  Future<void> reauthenticateWithPassword(String password) async {
    final user = currentUser;
    if (user == null || user.email == null) {
      throw Exception('No user is currently signed in');
    }

    // Supabase doesn't have a direct reauthentication method
    // We need to sign in again to verify the password
    try {
      await _supabase.auth.signInWithPassword(
        email: user.email!,
        password: password,
      );
    } catch (e) {
      throw Exception('Reauthentication failed: $e');
    }
  }

  /// Delete current user account
  @override
  Future<void> deleteAccount() async {
    final user = currentUser;
    if (user == null) {
      throw Exception('No user is currently signed in');
    }

    // Delete user document from database first
    final userId = user.id;
    await _userService.deleteUser(userId);

    // Supabase Admin API is needed to delete auth users
    // This should be done via an Edge Function with proper authorization
    // For now, we'll just sign out the user
    // TODO: Implement proper user deletion via Edge Function
    await signOut();
    AppLogger.warning('User data deleted, but auth account requires admin API to delete');
  }
}
