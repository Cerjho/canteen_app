import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/student.dart';

/// Holds the currently selected student for parent menu actions
final selectedStudentProvider = StateProvider<Student?>((ref) => null);