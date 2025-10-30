import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/student.dart';

final activeStudentProvider = StateProvider<Student?>((ref) => null);
