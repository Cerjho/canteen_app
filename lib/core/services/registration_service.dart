import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'api_client.dart';
import '../constants/firestore_constants.dart';
import '../models/user_role.dart';
import '../models/parent.dart';
import '../models/student.dart';
import '../utils/app_logger.dart';

/// Registration Service - handles user registration for the canteen system
/// 
/// This service provides helper functions to create new users with proper
/// role-based setup:
/// - Admin: Creates Firebase Auth account + users document
/// - Parent: Creates Firebase Auth account + users document + parents document
/// 
/// All operations are atomic where possible to ensure data consistency.
class RegistrationService {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  /// Constructor with dependency injection
  RegistrationService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  /// Register a new ADMIN user
  /// 
  /// This creates:
  /// 1. Firebase Authentication account
  /// 2. Document in `users` collection with role="admin"
  /// 
  /// Steps:
  /// 1. Create Firebase Auth account with email/password
  /// 2. Get the UID from the created user
  /// 3. Create a document in `users/{uid}` with admin role
  /// 
  /// Returns: The created AppUser object
  /// Throws: FirebaseAuthException or FirebaseException on failure
  /// 
  /// Example:
  /// ```dart
  /// final admin = await registrationService.registerAdmin(
  ///   firstName: 'John',
  ///   lastName: 'Admin',
  ///   email: 'admin@school.com',
  ///   password: 'SecurePassword123!',
  /// );
  /// ```
  Future<AppUser> registerAdmin({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
  }) async {
    try {
      // Step 1: Create Firebase Auth account
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final uid = userCredential.user!.uid;

      // Step 2: Create user document in Firestore
      final appUser = AppUser(
        uid: uid,
        firstName: firstName,
        lastName: lastName,
        email: email,
        isAdmin: true,
        isParent: false,
        createdAt: DateTime.now(),
        isActive: true,
      );

      // Step 3: Save to Firestore users collection
      await _firestore.collection(FirestoreConstants.usersCollection).doc(uid).set(appUser.toMap());

      return appUser;
    } catch (e) {
      // If Firestore write fails, we should ideally delete the Auth account
      // but we'll let the caller handle cleanup for now
      rethrow;
    }
  }

  /// Register a new PARENT user
  /// 
  /// This creates:
  /// 1. Firebase Authentication account
  /// 2. Document in `users` collection with role="parent"
  /// 3. Document in `parents` collection with parent-specific data
  /// 
  /// Steps:
  /// 1. Create Firebase Auth account with email/password
  /// 2. Get the UID from the created user
  /// 3. Create document in `users/{uid}` with parent role
  /// 4. Create document in `parents/{uid}` with parent-specific info
  /// 
  /// Both Firestore writes happen in a batch for atomicity.
  /// 
  /// Returns: A map with both AppUser and Parent objects
  /// Throws: FirebaseAuthException or FirebaseException on failure
  /// 
  /// Example:
  /// ```dart
  /// final result = await registrationService.registerParent(
  ///   firstName: 'Jane',
  ///   lastName: 'Parent',
  ///   email: 'jane@example.com',
  ///   password: 'SecurePassword123!',
  ///   phone: '+1234567890',
  ///   address: '123 Main St, City',
  /// );
  /// 
  /// print('User: ${result['user'].name}');
  /// print('Parent balance: ${result['parent'].balance}');
  /// ```
  Future<Map<String, dynamic>> registerParent({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    String? phone,
    String? address,
  }) async {
    try {
      // Step 1: Create Firebase Auth account
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final uid = userCredential.user!.uid;
      final now = DateTime.now();

      // Step 2: Create user document
      final appUser = AppUser(
        uid: uid,
        firstName: firstName,
        lastName: lastName,
        email: email,
        isAdmin: false,
        isParent: true,
        createdAt: now,
        isActive: true,
      );

      // Step 3: Create parent document with initial balance of 0
      final parent = Parent(
        userId: uid,
        phone: phone,
        address: address,
        // Parent balance initialized inside Parent model/service; omit here
        children: [], // Empty initially, students added later
        createdAt: now,
        isActive: true,
      );

      // Step 4: Write both documents in a batch (atomic operation)
      final batch = _firestore.batch();
      
      batch.set(
        _firestore.collection(FirestoreConstants.usersCollection).doc(uid),
        appUser.toMap(),
      );
      
      batch.set(
        _firestore.collection(FirestoreConstants.parentsCollection).doc(uid),
        parent.toMap(),
      );

      await batch.commit();

      // If a backend API is configured, request the backend to set custom claims
      // for the newly created user. Setting custom claims requires admin
      // privileges and cannot be done from the client directly, so we delegate
      // to the backend. The backend should verify the request and call the
      // Firebase Admin SDK to set the claims.
      if (apiClient.enabled) {
        try {
          final user = _auth.currentUser;
          String? token;
          if (user != null) token = await user.getIdToken();

          final headers = token != null ? {'Authorization': 'Bearer $token'} : null;
          final res = await apiClient.post('/admin/set-claims', headers: headers, body: {
            'uid': uid,
            'claims': {'parent': true, 'admin': false}
          });

          if (res.statusCode != 200 && res.statusCode != 201) {
            AppLogger.warning('Backend did not accept set-claims request: ${res.statusCode} ${res.body}');
          }
        } catch (e) {
          // Non-fatal: registration succeeded locally, but custom claims were
          // not set. Log the issue and continue.
          AppLogger.error('Failed to request backend to set custom claims', error: e);
        }
      }

      return {
        'user': appUser,
        'parent': parent,
      };
    } catch (e) {
      // If anything fails, the auth account may exist but Firestore docs won't
      // Caller should handle cleanup if needed
      rethrow;
    }
  }

  /// Register a new PARENT user with existing Firebase User (e.g., from Google Sign-In)
  /// 
  /// This creates:
  /// 1. Document in `users` collection with role="parent"
  /// 2. Document in `parents` collection with parent-specific data
  /// 
  /// Use this when the user has already authenticated (e.g., via Google Sign-In)
  /// and you just need to create the Firestore documents.
  /// 
  /// Returns: A map with both AppUser and Parent objects
  /// Throws: FirebaseException on failure
  Future<Map<String, dynamic>> registerParentWithExistingAuth({
    required String uid,
    required String firstName,
    required String lastName,
    required String email,
    String? phone,
    String? address,
  }) async {
    try {
      final now = DateTime.now();

      // Step 1: Create user document
      final appUser = AppUser(
        uid: uid,
        firstName: firstName,
        lastName: lastName,
        email: email,
        isAdmin: false,
        isParent: true,
        createdAt: now,
        isActive: true,
      );

      // Step 2: Create parent document with initial balance of 0
      final parent = Parent(
        userId: uid,
        phone: phone,
        address: address,
        // Parent balance initialized inside Parent model/service; omit here
        children: [], // Empty initially, students added later
        createdAt: now,
        isActive: true,
      );

      // Step 3: Write both documents in a batch (atomic operation)
      final batch = _firestore.batch();
      
      batch.set(
        _firestore.collection(FirestoreConstants.usersCollection).doc(uid),
        appUser.toMap(),
      );
      
      batch.set(
        _firestore.collection(FirestoreConstants.parentsCollection).doc(uid),
        parent.toMap(),
      );

      await batch.commit();

      return {
        'user': appUser,
        'parent': parent,
      };
    } catch (e) {
      rethrow;
    }
  }

  /// Link a student to a parent
  /// 
  /// This updates:
  /// 1. Student's `parentId` field
  /// 2. Parent's `children` array to include the student ID
  /// 
  /// Both updates happen in a batch for atomicity.
  /// 
  /// Parameters:
  /// - studentId: The ID of the student document
  /// - parentUserId: The userId of the parent (same as Firebase Auth UID)
  /// 
  /// Example:
  /// ```dart
  /// await registrationService.linkStudentToParent(
  ///   studentId: 'student_123',
  ///   parentUserId: 'parent_uid_456',
  /// );
  /// ```
  Future<void> linkStudentToParent({
    required String studentId,
    required String parentUserId,
  }) async {
    try {
      // If a backend API is configured, use it to perform the operation
      if (apiClient.enabled) {
        final user = _auth.currentUser;
        if (user == null) throw Exception('User not authenticated');
        final token = await user.getIdToken();
        final res = await apiClient.post('/parent/student-link',
            headers: {'Authorization': 'Bearer $token'}, body: {'studentId': studentId});
        if (res.statusCode != 201 && res.statusCode != 200) {
          throw Exception('Failed to link student: ${res.statusCode} ${res.body}');
        }
        return;
      }

      final batch = _firestore.batch();

      // Update student's parentId
      batch.update(
        _firestore.collection(FirestoreConstants.studentsCollection).doc(studentId),
        {
          'parentId': parentUserId,
          'updatedAt': FieldValue.serverTimestamp(),
        },
      );

      // Add student to parent's children array
      batch.update(
        _firestore.collection(FirestoreConstants.parentsCollection).doc(parentUserId),
        {
          'children': FieldValue.arrayUnion([studentId]),
          'updatedAt': FieldValue.serverTimestamp(),
        },
      );

      await batch.commit();
    } catch (e) {
      rethrow;
    }
  }

  /// Unlink a student from a parent
  /// 
  /// This updates:
  /// 1. Student's `parentId` field (set to null)
  /// 2. Parent's `children` array to remove the student ID
  /// 
  /// Both updates happen in a batch for atomicity.
  /// 
  /// Parameters:
  /// - studentId: The ID of the student document
  /// - parentUserId: The userId of the parent (same as Firebase Auth UID)
  /// 
  /// Example:
  /// ```dart
  /// await registrationService.unlinkStudentFromParent(
  ///   studentId: 'student_123',
  ///   parentUserId: 'parent_uid_456',
  /// );
  /// ```
  Future<void> unlinkStudentFromParent({
    required String studentId,
    required String parentUserId,
  }) async {
    try {
      final batch = _firestore.batch();

      // Remove student's parentId
      batch.update(
        _firestore.collection(FirestoreConstants.studentsCollection).doc(studentId),
        {
          'parentId': null,
          'updatedAt': FieldValue.serverTimestamp(),
        },
      );

      // Remove student from parent's children array
      batch.update(
        _firestore.collection(FirestoreConstants.parentsCollection).doc(parentUserId),
        {
          'children': FieldValue.arrayRemove([studentId]),
          'updatedAt': FieldValue.serverTimestamp(),
        },
      );

      await batch.commit();
    } catch (e) {
      rethrow;
    }
  }

  /// Create a new student and optionally link to a parent
  /// 
  /// This creates:
  /// 1. Document in `students` collection
  /// 2. Optionally links to parent if parentUserId is provided
  /// 
  /// Parameters:
  /// - firstName: Student's first name
  /// - lastName: Student's last name
  /// - grade: Student's grade level (e.g., "Grade 7")
  /// - parentUserId: Optional parent UID to link immediately
  /// - allergies: Optional allergies information
  /// - dietaryRestrictions: Optional dietary restrictions
  /// - initialBalance: Starting balance (default 0.0)
  /// 
  /// Returns: The created Student object
  /// 
  /// Example:
  /// ```dart
  /// final student = await registrationService.createStudent(
  ///   firstName: 'Tommy',
  ///   lastName: 'Smith',
  ///   grade: 'Grade 5',
  ///   parentUserId: 'parent_uid_123',
  ///   allergies: 'Peanuts',
  ///   initialBalance: 50.0,
  /// );
  /// ```
  Future<Student> createStudent({
    required String firstName,
    required String lastName,
    required String grade,
    String? parentUserId,
    String? allergies,
    String? dietaryRestrictions,
    double initialBalance = 0.0,
  }) async {
    try {
      // Generate a new document ID
      final docRef = _firestore.collection(FirestoreConstants.studentsCollection).doc();
      final studentId = docRef.id;

      final student = Student(
        id: studentId,
        firstName: firstName,
        lastName: lastName,
        grade: grade,
        parentId: parentUserId,
        allergies: allergies,
        dietaryRestrictions: dietaryRestrictions,
        createdAt: DateTime.now(),
        isActive: true,
      );

      // If parent is provided, link them atomically
      if (parentUserId != null) {
        final batch = _firestore.batch();
        
        // Create student document
        batch.set(docRef, student.toMap());
        
        // Add to parent's children array
        batch.update(
          _firestore.collection(FirestoreConstants.parentsCollection).doc(parentUserId),
          {
            'children': FieldValue.arrayUnion([studentId]),
            'updatedAt': FieldValue.serverTimestamp(),
          },
        );

        await batch.commit();
      } else {
        // No parent, just create student
        await docRef.set(student.toMap());
      }

      return student;
    } catch (e) {
      rethrow;
    }
  }

  /// Check if an email is already registered
  /// 
  /// This checks Firestore users collection only.
  /// Note: We removed the deprecated fetchSignInMethodsForEmail() for security reasons.
  /// See: https://cloud.google.com/identity-platform/docs/admin/email-enumeration-protection
  /// 
  /// Returns: true if email exists, false otherwise
  Future<bool> isEmailRegistered(String email) async {
    try {
      // Check Firestore users collection
      final querySnapshot = await _firestore
          .collection(FirestoreConstants.usersCollection)
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      return querySnapshot.docs.isNotEmpty;
    } catch (e) {
      AppLogger.error('Error checking if email is registered', error: e);
      // If there's an error, assume email is not registered to allow registration attempt
      return false;
    }
  }
}
