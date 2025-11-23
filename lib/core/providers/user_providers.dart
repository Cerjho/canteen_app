import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../interfaces/i_student_service.dart';
import '../interfaces/i_parent_service.dart';
import '../services/student_service.dart';
import '../services/parent_service.dart';
import '../services/user_service.dart';
import '../models/student.dart';
import '../models/parent.dart';
import '../models/user_role.dart';
import 'supabase_providers.dart';
import 'auth_providers.dart';

// ============================================================================
// STUDENT & PARENT SERVICE PROVIDERS
// ============================================================================

/// UUID Provider
/// 
/// Used for generating unique IDs across the application.
final uuidProvider = Provider<Uuid>((ref) => const Uuid());

/// Student Service Provider
/// 
/// Handles student management operations (CRUD, balance, import/export).
final studentServiceProvider = Provider<IStudentService>((ref) {
  return StudentService(
    supabase: ref.watch(supabaseProvider),
    uuid: ref.watch(uuidProvider),
  );
});

/// Parent Service Provider
/// 
/// Handles parent management operations (CRUD, linking students, balance).
final parentServiceProvider = Provider<IParentService>((ref) {
  return ParentService(
    supabase: ref.watch(supabaseProvider),
    userService: ref.watch(userServiceProvider) as UserService,
  );
});

// ============================================================================
// STUDENT & PARENT DATA PROVIDERS
// ============================================================================

/// All Users Provider
/// 
/// Streams all users in the system (admin view).
/// Returns: Stream<List<AppUser>>
final allUsersProvider = StreamProvider((ref) {
  return ref.watch(userServiceProvider).getAllUsers();
});

/// User by ID Provider Family
///
/// Streams a specific user by their UID.
/// Usage: ref.watch(userByIdProvider(userId))
final userByIdProvider = StreamProvider.family<AppUser?, String>((ref, userId) {
  return ref.watch(userServiceProvider).getUserStream(userId);
});

/// All Students Provider
/// 
/// Streams all students in the system (admin view).
/// Returns: Stream<List<Student>>
final studentsProvider = StreamProvider((ref) {
  return ref.watch(studentServiceProvider).getStudents();
});

/// All Parents Provider
/// 
/// Streams all parents in the system (admin view).
/// Returns: Stream<List<Parent>>
final parentsProvider = StreamProvider((ref) {
  return ref.watch(parentServiceProvider).getParents();
});

// ============================================================================
// PARENT-SPECIFIC PROVIDERS
// ============================================================================

/// Parent Students Provider
/// 
/// Streams students linked to the currently signed-in parent.
/// Returns: Stream<List<Student>> - empty list if not a parent or not signed in
final parentStudentsProvider = StreamProvider<List<Student>>((ref) {
  final currentUser = ref.watch(currentUserProvider).value;
  if (currentUser == null) return Stream.value([]);

  // Get students by parent ID
  return ref.watch(studentServiceProvider).getStudentsByParent(currentUser.uid);
});

/// Current Parent Profile Provider
/// 
/// Streams the complete parent profile with photo URL and other details.
/// Returns: Stream<Parent?> - null if not a parent or not found
final currentParentProvider = StreamProvider<Parent?>((ref) {
  final currentUser = ref.watch(currentUserProvider).value;
  if (currentUser == null) return Stream.value(null);

  // Watch parent profile in real-time
  return ref.watch(parentServiceProvider).getParentStream(currentUser.uid);
});

/// Student by ID Provider Family
/// 
/// Streams a specific student by ID.
/// Usage: ref.watch(studentByIdProvider(studentId))
/// Returns: Stream<Student?>
final studentByIdProvider = StreamProvider.family<Student?, String>((ref, studentId) {
  return ref.watch(studentServiceProvider).getStudentStream(studentId);
});

/// Parent by ID Provider Family
/// 
/// Streams a specific parent by ID.
/// Usage: ref.watch(parentByIdProvider(parentId))
/// Returns: Stream<Parent?>
final parentByIdProvider = StreamProvider.family<Parent?, String>((ref, parentId) {
  return ref.watch(parentServiceProvider).getParentStream(parentId);
});
