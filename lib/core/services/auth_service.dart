import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/user_role.dart';
import '../interfaces/i_auth_service.dart';
import 'user_service.dart';
import 'registration_service.dart';
import '../utils/app_logger.dart';

/// Authentication Service - handles user authentication with Firebase Auth
class AuthService implements IAuthService {
  final FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn;
  final UserService _userService;
  final RegistrationService _registrationService;

  /// Constructor with dependency injection
  /// 
  /// [auth] - Optional FirebaseAuth instance for testing
  /// [googleSignIn] - Optional GoogleSignIn instance for testing
  /// [userService] - Optional UserService instance for testing
  /// [registrationService] - Required RegistrationService for post-sign-in provisioning
  AuthService({
    FirebaseAuth? auth,
    GoogleSignIn? googleSignIn,
    UserService? userService,
    required RegistrationService registrationService,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _googleSignIn = googleSignIn ?? GoogleSignIn(
          serverClientId: dotenv.env['GOOGLE_CLIENT_ID'],
        ),
        _userService = userService ?? UserService(),
        _registrationService = registrationService;

  /// Get user's email from User object, checking providerData if needed.
  /// This is necessary on Android where user.email may be null after Google Sign-In.
  /// The email is available in user.providerData[0].email instead.
  static String? getUserEmail(User? user) {
    if (user == null) return null;
    
    // Try user.email first
    if (user.email != null && user.email!.isNotEmpty) {
      return user.email;
    }
    
    // Fallback to providerData (for Android Google Sign-In)
    if (user.providerData.isNotEmpty) {
      final providerEmail = user.providerData.first.email;
      if (providerEmail != null && providerEmail.isNotEmpty) {
        return providerEmail;
      }
    }
    
    return null;
  }

  /// Get user's display name from User object, checking providerData if needed.
  /// Similar to getUserEmail, display name may need to be extracted from providerData.
  static String? getUserDisplayName(User? user) {
    if (user == null) return null;
    
    if (user.displayName != null && user.displayName!.isNotEmpty) {
      return user.displayName;
    }
    
    if (user.providerData.isNotEmpty) {
      return user.providerData.first.displayName;
    }
    
    return null;
  }

  /// Get current user
  @override
  User? get currentUser => _auth.currentUser;

  /// Auth state changes stream
  @override
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Get current user's role from Firestore
  @override
  Future<UserRole?> getCurrentUserRole() async {
    final user = currentUser;
    if (user == null) return null;
    
    try {
      // Try to get from custom claims first (faster)
      final idTokenResult = await user.getIdTokenResult();
      final adminClaim = idTokenResult.claims?['admin'];
      if (adminClaim == true) {
        return UserRole.admin;
      }
      
      // Fall back to Firestore
      return await _userService.getUserRole(user.uid);
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
    
    return await _userService.getUser(user.uid);
  }

  /// Sign in with email and password
  @override
  Future<UserCredential> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Sign in with Google
  /// Uses Firebase Auth popup on web (recommended) and GoogleSignIn on mobile
  @override
  Future<UserCredential> signInWithGoogle() async {
    try {
      AppLogger.debug('signInWithGoogle(): start');
  UserCredential userCredential;
  String effectiveEmail = '';
      if (kIsWeb) {
        AppLogger.debug('signInWithGoogle(): using web popup flow');
        // Web: Use Firebase Auth popup (recommended for web)
        // This avoids the deprecated google_sign_in web implementation
        final GoogleAuthProvider googleProvider = GoogleAuthProvider();
        
        // Optional: Add scopes if needed
        googleProvider.addScope('email');
        googleProvider.addScope('profile');
        
        // Use popup instead of redirect for better UX
        userCredential = await _auth.signInWithPopup(googleProvider);
        AppLogger.info('signInWithGoogle(): web popup returned user uid=${userCredential.user?.uid} email=${userCredential.user?.email}');
        // Set effectiveEmail for downstream use (web)
        final webUser = userCredential.user;
        effectiveEmail = webUser?.email ??
            (webUser?.providerData.isNotEmpty == true ? webUser!.providerData.first.email ?? '' : '');
      } else {
        // Mobile: Use google_sign_in package (works well on mobile)
        AppLogger.debug('signInWithGoogle(): calling GoogleSignIn.signIn()');
        final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
        AppLogger.debug('signInWithGoogle(): GoogleSignIn.signIn() returned: $googleUser');
        
        if (googleUser == null) {
          AppLogger.info('signInWithGoogle(): user cancelled Google sign-in (googleUser==null)');
          throw Exception('Google sign-in was cancelled');
        }

        // Obtain the auth details from the request
        final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

        // Create a new credential
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        // Sign in to Firebase with the Google credential
        userCredential = await _auth.signInWithCredential(credential);
        AppLogger.info('signInWithGoogle(): firebase signInWithCredential returned uid=${userCredential.user?.uid} email=${userCredential.user?.email}');

        // Force reload to populate email if available from backend
        final firebaseUser = userCredential.user ?? _auth.currentUser;
        if (firebaseUser != null) {
          await firebaseUser.reload();
          AppLogger.info('signInWithGoogle(): after reload, uid=${firebaseUser.uid} email=${firebaseUser.email}');
        }

        // Log provider data for diagnostics
        AppLogger.debug('GoogleSignIn providerData: ${firebaseUser?.providerData}');

        // Extract email safely (prioritize user.email post-reload, fallback to providerData)
        final effectiveEmailLocal = firebaseUser?.email ??
            (firebaseUser?.providerData.isNotEmpty == true ? firebaseUser!.providerData.first.email : null) ??
            '';
        AppLogger.info('Effective email for downstream use: $effectiveEmailLocal');
        effectiveEmail = effectiveEmailLocal;
      }

      // Post sign-in: ensure Firestore 'users' and 'parents' documents exist for parent users
      try {
        final firebaseUser = userCredential.user ?? _auth.currentUser;
        if (firebaseUser != null) {
          final existingUser = await _userService.getUser(firebaseUser.uid);
          if (existingUser == null) {
            // Create parent document and user document using RegistrationService
            final displayName = firebaseUser.displayName ??
                (firebaseUser.providerData.isNotEmpty ? firebaseUser.providerData.first.displayName : null) ??
                'Google User';
            final nameParts = displayName.split(' ');
            final firstName = nameParts.first;
            final lastName = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';

      // Use effectiveEmail determined after sign-in/reload
      final providerEmail = effectiveEmail;

            try {
              // Best-effort create parent and users docs. If this fails, do not
              // block the sign-in flow; log the error for diagnostics.
              await _registrationService.registerParentWithExistingAuth(
                uid: firebaseUser.uid,
                firstName: firstName,
                lastName: lastName,
                email: providerEmail,
                phone: firebaseUser.phoneNumber,
                address: null,
              );
              AppLogger.info('Created missing user/parent documents for uid=${firebaseUser.uid}');
            } catch (regErr) {
              AppLogger.warning('Failed to create user/parent documents for uid=${firebaseUser.uid}: $regErr');
            }
          }
        }
      } catch (e) {
  AppLogger.warning('Post sign-in Firestore check/create failed: $e');
      }

      AppLogger.debug('signInWithGoogle(): returning userCredential');
      return userCredential;
    } catch (e) {
      AppLogger.error('signInWithGoogle(): error: $e', error: e);
      rethrow;
    }
  }

  /// Sign out
  @override
  Future<void> signOut() async {
    await _auth.signOut();
    await _googleSignIn.signOut();
  }

  /// Reset password
  @override
  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  /// Reset password (legacy method - kept for backward compatibility)
  Future<void> resetPassword(String email) async {
    await sendPasswordResetEmail(email);
  }

  /// Create user with email and password (for admin registration)
  Future<UserCredential> createUserWithEmailAndPassword(
    String email,
    String password,
  ) async {
    try {
      return await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Update user email
  Future<void> updateEmail(String newEmail) async {
    await currentUser?.verifyBeforeUpdateEmail(newEmail);
  }

  /// Update user password
  @override
  Future<void> updatePassword(String newPassword) async {
    await currentUser?.updatePassword(newPassword);
  }

  /// Send email verification
  Future<void> sendEmailVerification() async {
    await currentUser?.sendEmailVerification();
  }

  /// Check if email is verified
  bool get isEmailVerified => currentUser?.emailVerified ?? false;

  /// Reload current user
  Future<void> reloadUser() async {
    await currentUser?.reload();
  }

  /// Reauthenticate with password (required before sensitive operations)
  @override
  Future<void> reauthenticateWithPassword(String password) async {
    final user = currentUser;
    if (user == null || user.email == null) {
      throw Exception('No user is currently signed in');
    }

    final credential = EmailAuthProvider.credential(
      email: user.email!,
      password: password,
    );

    await user.reauthenticateWithCredential(credential);
  }

  /// Delete current user account
  @override
  Future<void> deleteAccount() async {
    final user = currentUser;
    if (user == null) {
      throw Exception('No user is currently signed in');
    }

    // Delete user document from Firestore first
    final userId = user.uid;
    await _userService.deleteUser(userId);

    // Then delete the Firebase Auth account
    await user.delete();
  }
}
