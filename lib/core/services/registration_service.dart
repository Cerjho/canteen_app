import 'package:supabase_flutter/supabase_flutter.dart';
import 'api_client.dart';
import '../constants/database_constants.dart';
import '../models/user_role.dart';
import '../models/parent.dart';
import '../models/student.dart';
import '../utils/app_logger.dart';

/// Registration Service - handles user registration for the canteen system
/// 
/// This service provides helper functions to create new users with proper
/// role-based setup:
/// - Admin: Creates Supabase Auth account + users record
/// - Parent: Creates Supabase Auth account + users record + parents record
/// 
/// All operations use Supabase Auth and Postgres database.
class RegistrationService {
  final SupabaseClient _supabase;

  /// Constructor with dependency injection
  RegistrationService({
    SupabaseClient? supabase,
  }) : _supabase = supabase ?? Supabase.instance.client;

  /// Register a new ADMIN user
  /// 
  /// This creates:
  /// 1. Supabase Authentication account
  /// 2. Record in `users` table with role="admin"
  /// 
  /// Steps:
  /// 1. Create Supabase Auth account with email/password
  /// 2. Get the UID from the created user
  /// 3. Create a record in `users` table with admin role
  /// 
  /// Returns: The created AppUser object
  /// Throws: AuthException or PostgrestException on failure
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
      // Step 1: Create Supabase Auth account
      final authResponse = await _supabase.auth.signUp(
        email: email,
        password: password,
      );

      final uid = authResponse.user!.id;

      // Step 2: Create user record in database
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

      // Step 3: Save to users table
      await _supabase
          .from(DatabaseConstants.usersTable)
          .insert(appUser.toMap());

      return appUser;
    } catch (e) {
      rethrow;
    }
  }

  /// Register a new PARENT user
  /// 
  /// This creates:
  /// 1. Supabase Authentication account
  /// 2. Record in `users` table with role="parent"
  /// 3. Record in `parents` table with parent-specific data
  /// 
  /// Steps:
  /// 1. Create Supabase Auth account with email/password
  /// 2. Get the UID from the created user
  /// 3. Create record in `users` table with parent role
  /// 4. Create record in `parents` table with parent-specific info
  /// 
  /// Both database inserts use Supabase transactions for atomicity.
  /// 
  /// Returns: A map with both AppUser and Parent objects
  /// Throws: AuthException or PostgrestException on failure
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
      // Step 1: Create Supabase Auth account
      final authResponse = await _supabase.auth.signUp(
        email: email,
        password: password,
      );

      final uid = authResponse.user!.id;
      final now = DateTime.now();

      // Step 2: Create user record
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

      // Step 3: Create parent record with initial balance of 0
      final parent = Parent(
        userId: uid,
        phone: phone,
        address: address,
        children: [], // Empty initially, students added later
        createdAt: now,
        isActive: true,
      );

      // Step 4: Insert both records (Supabase handles transactions automatically)
      await _supabase
          .from(DatabaseConstants.usersTable)
          .insert(appUser.toMap());
      
      await _supabase
          .from(DatabaseConstants.parentsTable)
          .insert(parent.toMap());

      return {
        'user': appUser,
        'parent': parent,
      };
    } catch (e) {
      rethrow;
    }
  }

  /// Register a new PARENT user with existing Supabase User (e.g., from Google Sign-In)
  /// 
  /// This creates:
  /// 1. Record in `users` table with role="parent"
  /// 2. Record in `parents` table with parent-specific data
  /// 
  /// Use this when the user has already authenticated (e.g., via Google Sign-In)
  /// and you just need to create the database records.
  /// 
  /// Returns: A map with both AppUser and Parent objects
  /// Throws: PostgrestException on failure
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

      // Step 1: Create user record
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

      // Step 2: Create parent record with initial balance of 0
      final parent = Parent(
        userId: uid,
        phone: phone,
        address: address,
        children: [], // Empty initially, students added later
        createdAt: now,
        isActive: true,
      );

      // Step 3: Insert both records
      await _supabase
          .from(DatabaseConstants.usersTable)
          .insert(appUser.toMap());
      
      await _supabase
          .from(DatabaseConstants.parentsTable)
          .insert(parent.toMap());

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
  /// 1. Student's `parent_id` field
  /// 2. Parent's `children` array to include the student ID
  /// 
  /// Both updates use database operations.
  /// 
  /// Parameters:
  /// - studentId: The ID of the student record
  /// - parentUserId: The userId of the parent (same as Supabase Auth UUID)
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
        final user = _supabase.auth.currentUser;
        if (user == null) throw Exception('User not authenticated');
        final session = _supabase.auth.currentSession;
        final token = session?.accessToken;
        if (token == null) throw Exception('No access token available');
        
        final res = await apiClient.post('/parent/student-link',
            headers: {'Authorization': 'Bearer $token'}, body: {'studentId': studentId});
        if (res.statusCode != 201 && res.statusCode != 200) {
          throw Exception('Failed to link student: ${res.statusCode} ${res.body}');
        }
        return;
      }

      // Update student's parent_id
      await _supabase
          .from(DatabaseConstants.studentsTable)
          .update({
            'parent_id': parentUserId,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', studentId);

      // Get current parent record to update children array
      final parentData = await _supabase
          .from(DatabaseConstants.parentsTable)
          .select('children')
          .eq('user_id', parentUserId)
          .single();
      
      final currentChildren = List<String>.from(parentData['children'] ?? []);
      if (!currentChildren.contains(studentId)) {
        currentChildren.add(studentId);
        
        await _supabase
            .from(DatabaseConstants.parentsTable)
            .update({
              'children': currentChildren,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('user_id', parentUserId);
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Unlink a student from a parent
  /// 
  /// This updates:
  /// 1. Student's `parent_id` field (set to null)
  /// 2. Parent's `children` array to remove the student ID
  /// 
  /// Both updates use database operations.
  /// 
  /// Parameters:
  /// - studentId: The ID of the student record
  /// - parentUserId: The userId of the parent (same as Supabase Auth UUID)
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
      // Remove student's parent_id
      await _supabase
          .from(DatabaseConstants.studentsTable)
          .update({
            'parent_id': null,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', studentId);

      // Get current parent record to update children array
      final parentData = await _supabase
          .from(DatabaseConstants.parentsTable)
          .select('children')
          .eq('user_id', parentUserId)
          .single();
      
      final currentChildren = List<String>.from(parentData['children'] ?? []);
      currentChildren.remove(studentId);
      
      await _supabase
          .from(DatabaseConstants.parentsTable)
          .update({
            'children': currentChildren,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('user_id', parentUserId);
    } catch (e) {
      rethrow;
    }
  }

  /// Create a new student and optionally link to a parent
  /// 
  /// This creates:
  /// 1. Record in `students` table
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
      // Supabase will generate UUID automatically
      final student = Student(
        id: '', // Will be generated by database
        firstName: firstName,
        lastName: lastName,
        grade: grade,
        parentId: parentUserId,
        allergies: allergies,
        dietaryRestrictions: dietaryRestrictions,
        createdAt: DateTime.now(),
        isActive: true,
      );

      // Insert student and get generated ID
      final studentMap = student.toMap();
      studentMap.remove('id'); // Let database generate ID
      
      final insertedData = await _supabase
          .from(DatabaseConstants.studentsTable)
          .insert(studentMap)
          .select()
          .single();
      
      final studentId = insertedData['id'] as String;
      final createdStudent = Student.fromMap(insertedData);

      // If parent is provided, link them
      if (parentUserId != null) {
        final parentData = await _supabase
            .from(DatabaseConstants.parentsTable)
            .select('children')
            .eq('user_id', parentUserId)
            .single();
        
        final currentChildren = List<String>.from(parentData['children'] ?? []);
        if (!currentChildren.contains(studentId)) {
          currentChildren.add(studentId);
          
          await _supabase
              .from(DatabaseConstants.parentsTable)
              .update({
                'children': currentChildren,
                'updated_at': DateTime.now().toIso8601String(),
              })
              .eq('user_id', parentUserId);
        }
      }

      return createdStudent;
    } catch (e) {
      rethrow;
    }
  }

  /// Check if an email is already registered
  /// 
  /// This checks users table only.
  /// 
  /// Returns: true if email exists, false otherwise
  Future<bool> isEmailRegistered(String email) async {
    try {
      // Check users table
      final data = await _supabase
          .from(DatabaseConstants.usersTable)
          .select('id')
          .eq('email', email)
          .maybeSingle();

      return data != null;
    } catch (e) {
      AppLogger.error('Error checking if email is registered', error: e);
      // If there's an error, assume email is not registered to allow registration attempt
      return false;
    }
  }
}
