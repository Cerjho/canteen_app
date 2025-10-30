import '../../../core/models/student.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/app_providers.dart';

/// Helper to get active student (for AppBar subtitle)
Future<List<Student>?> getActiveStudent(WidgetRef ref) async {
  final studentsAsync = ref.read(parentStudentsProvider);
  final students = studentsAsync.value ?? [];
  // TODO: Replace with actual logic for active student selection
  return students.isNotEmpty ? [students.first] : null;
}
