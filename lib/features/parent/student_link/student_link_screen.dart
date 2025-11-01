import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:responsive_builder/responsive_builder.dart';
import '../../../core/models/student.dart';
import '../../../core/providers/app_providers.dart';
import 'edit_student_screen.dart';
import '../../../core/utils/format_utils.dart';

/// Student Linking Screen - Link/Unlink students to parent account
/// 
/// **Features:**
/// - Manual ID entry with validation
/// - Display linked students
/// - Unlink students
/// - Refresh linked students
/// - Responsive layout (mobile/tablet/desktop)
/// 
/// **User Flow:**
/// 1. Parent enters student ID manually
/// 2. System validates student ID exists
/// 3. System links student to parent account
/// 4. Show linked students with unlink option
class StudentLinkScreen extends ConsumerStatefulWidget {
  const StudentLinkScreen({super.key});

  @override
  ConsumerState<StudentLinkScreen> createState() => _StudentLinkScreenState();
}

class _StudentLinkScreenState extends ConsumerState<StudentLinkScreen> {
  final _studentIdController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  @override
  void dispose() {
    _studentIdController.dispose();
    super.dispose();
  }

  /// Link student to parent account
  Future<void> _linkStudent() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final studentId = _studentIdController.text.trim();
      final currentUser = ref.read(currentUserProvider).value;

      if (currentUser == null) {
        throw Exception('User not logged in');
      }

      // Check if student exists
      final studentService = ref.read(studentServiceProvider);
      final student = await studentService.getStudentById(studentId);

      if (student == null) {
        throw Exception('Student ID not found');
      }

      // Check if student is already linked to another parent
      if (student.parentId != null && student.parentId != currentUser.uid) {
        throw Exception(
          'This student is already linked to another parent account',
        );
      }

      // Check if student is already linked to this parent
      if (student.parentId == currentUser.uid) {
        throw Exception('This student is already linked to your account');
      }

      // Link student to parent
      final registrationService = ref.read(registrationServiceProvider);
      await registrationService.linkStudentToParent(
        studentId: studentId,
        parentUserId: currentUser.uid,
      );

      setState(() {
        _successMessage = '${student.fullName} linked successfully!';
        _studentIdController.clear();
      });

      // Clear success message after 3 seconds
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _successMessage = null;
          });
        }
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Unlink student from parent account
  Future<void> _unlinkStudent(Student student) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unlink Student'),
        content: Text(
          'Are you sure you want to unlink ${student.fullName}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Unlink'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final currentUser = ref.read(currentUserProvider).value;
      if (currentUser == null) {
        throw Exception('User not logged in');
      }

      final registrationService = ref.read(registrationServiceProvider);
      await registrationService.unlinkStudentFromParent(
        studentId: student.id,
        parentUserId: currentUser.uid,
      );

      setState(() {
        _successMessage = '${student.fullName} unlinked successfully!';
      });

      // Clear success message after 3 seconds
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _successMessage = null;
          });
        }
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveBuilder(
      builder: (context, sizingInfo) {
        final isMobile = sizingInfo.isMobile;
        final isTablet = sizingInfo.isTablet;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Link Students'),
            elevation: 0,
          ),
          body: SingleChildScrollView(
            padding: EdgeInsets.all(isMobile ? 16.w : 24.w),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: isTablet ? 700.w : (isMobile ? double.infinity : 900.w),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Instructions Card
                    _buildInstructionsCard(isMobile),
                    SizedBox(height: 24.h),

                    // Manual ID Entry Card
                    _buildManualEntryCard(isMobile),
                    SizedBox(height: 24.h),

                    // Linked Students Section
                    _buildLinkedStudentsSection(isMobile),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Build instructions card
  Widget _buildInstructionsCard(bool isMobile) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 16.w : 20.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: Theme.of(context).colorScheme.primary,
                  size: 24.sp,
                ),
                SizedBox(width: 12.w),
                Text(
                  'How to Link Students',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            SizedBox(height: 16.h),
            _buildInstructionItem(
              '1.',
              'Get your child\'s Student ID from the school admin',
              isMobile,
            ),
            SizedBox(height: 8.h),
            _buildInstructionItem(
              '2.',
              'Enter the Student ID in the form below',
              isMobile,
            ),
            SizedBox(height: 8.h),
            _buildInstructionItem(
              '3.',
              'Click "Link Student" to link your child to your account',
              isMobile,
            ),
            SizedBox(height: 8.h),
            _buildInstructionItem(
              '4.',
              'Once linked, you can place orders and manage their account',
              isMobile,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructionItem(String number, String text, bool isMobile) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          number,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
        ),
        SizedBox(width: 8.w),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }

  /// Build manual ID entry card
  Widget _buildManualEntryCard(bool isMobile) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 16.w : 20.w),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Enter Student ID',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              SizedBox(height: 16.h),

              // Student ID Input
              TextFormField(
                controller: _studentIdController,
                decoration: InputDecoration(
                  labelText: 'Student ID',
                  hintText: 'e.g., STU-2024-001',
                  prefixIcon: const Icon(Icons.badge_outlined),
                  border: const OutlineInputBorder(),
                  suffixIcon: _studentIdController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _studentIdController.clear();
                            setState(() {});
                          },
                        )
                      : null,
                ),
                textInputAction: TextInputAction.done,
                onChanged: (value) => setState(() {}),
                onFieldSubmitted: (_) => _linkStudent(),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a Student ID';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16.h),

              // Error Message
              if (_errorMessage != null) ...[
                Container(
                  padding: EdgeInsets.all(12.w),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: Theme.of(context).colorScheme.error,
                        size: 20.sp,
                      ),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                            fontSize: 14.sp,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16.h),
              ],

              // Success Message
              if (_successMessage != null) ...[
                Container(
                  padding: EdgeInsets.all(12.w),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        color: Colors.green.shade700,
                        size: 20.sp,
                      ),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: Text(
                          _successMessage!,
                          style: TextStyle(
                            color: Colors.green.shade700,
                            fontSize: 14.sp,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16.h),
              ],

              // Link Button
              FilledButton.icon(
                onPressed: _isLoading ? null : _linkStudent,
                icon: _isLoading
                    ? SizedBox(
                        width: 20.w,
                        height: 20.h,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Theme.of(context).colorScheme.onPrimary,
                          ),
                        ),
                      )
                    : const Icon(Icons.link),
                label: Text(_isLoading ? 'Linking...' : 'Link Student'),
                style: FilledButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 16.h),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build linked students section
  Widget _buildLinkedStudentsSection(bool isMobile) {
    final linkedStudentsAsync = ref.watch(parentStudentsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Linked Students',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh',
              onPressed: () {
                ref.invalidate(parentStudentsProvider);
              },
            ),
          ],
        ),
        SizedBox(height: 16.h),

        linkedStudentsAsync.when(
          data: (students) {
            if (students.isEmpty) {
              return _buildEmptyState(isMobile);
            }
            return _buildStudentsList(students, isMobile);
          },
          loading: () => Center(
            child: Padding(
              padding: EdgeInsets.all(32.h),
              child: const CircularProgressIndicator(),
            ),
          ),
          error: (error, stack) => _buildErrorState(error.toString(), isMobile),
        ),
      ],
    );
  }

  /// Build empty state
  Widget _buildEmptyState(bool isMobile) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 32.w : 48.w),
        child: Column(
          children: [
            Icon(
              Icons.person_add_outlined,
              size: isMobile ? 64.sp : 80.sp,
              color: Theme.of(context).colorScheme.outline,
            ),
            SizedBox(height: 16.h),
            Text(
              'No Linked Students',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            SizedBox(height: 8.h),
            Text(
              'Link your first student using their Student ID',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /// Build error state
  Widget _buildErrorState(String error, bool isMobile) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 32.w : 48.w),
        child: Column(
          children: [
            Icon(
              Icons.error_outline,
              size: isMobile ? 64.sp : 80.sp,
              color: Theme.of(context).colorScheme.error,
            ),
            SizedBox(height: 16.h),
            Text(
              'Error Loading Students',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.error,
                  ),
            ),
            SizedBox(height: 8.h),
            Text(
              error,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16.h),
            FilledButton.icon(
              onPressed: () {
                ref.invalidate(parentStudentsProvider);
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  /// Build students list
  Widget _buildStudentsList(List<Student> students, bool isMobile) {
    return Column(
      children: students
          .map((student) => _buildStudentCard(student, isMobile))
          .toList(),
    );
  }

  /// Build individual student card
  Widget _buildStudentCard(Student student, bool isMobile) {
    return Card(
      margin: EdgeInsets.only(bottom: 16.h),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 16.w : 20.w),
        child: Row(
          children: [
            // Avatar
            CircleAvatar(
              radius: isMobile ? 24.r : 28.r,
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              backgroundImage:
                  student.photoUrl != null ? NetworkImage(student.photoUrl!) : null,
              child: student.photoUrl == null
                  ? Text(
                      student.firstName[0].toUpperCase(),
                      style: TextStyle(
                        fontSize: isMobile ? 18.sp : 20.sp,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    )
                  : null,
            ),
            SizedBox(width: 16.w),
            
            // Student Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name
                  Text(
                    student.fullName,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: isMobile ? 16.sp : 18.sp,
                        ),
                  ),
                  SizedBox(height: 6.h),
                  
                  // Grade & ID
                  Row(
                    children: [
                      Icon(
                        Icons.school_outlined,
                        size: 16.sp,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      SizedBox(width: 4.w),
                      Text(
                        student.grade,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                              fontSize: isMobile ? 13.sp : 14.sp,
                            ),
                      ),
                      SizedBox(width: 8.w),
                      Text(
                        '•',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      SizedBox(width: 8.w),
                      Text(
                        'ID: ${student.id.substring(0, 8)}...',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                              fontSize: isMobile ? 12.sp : 13.sp,
                            ),
                      ),
                    ],
                  ),
                  
                  // Allergies Warning
                  if (student.allergies != null && student.allergies!.isNotEmpty) ...[
                    SizedBox(height: 8.h),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 8.w,
                        vertical: 4.h,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            size: 14.sp,
                            color: Theme.of(context).colorScheme.error,
                          ),
                          SizedBox(width: 4.w),
                          Flexible(
                            child: Text(
                              'Allergies: ${student.allergies}',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                                fontSize: 11.sp,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  
                  SizedBox(height: 12.h),
                  
                  // Balance & Actions Row
                  Row(
                    children: [
                      // Parent wallet snapshot (show parent's available wallet instead of student.balance)
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 16.w,
                              vertical: 8.h,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.secondaryContainer,
                              borderRadius: BorderRadius.circular(20.r),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.account_balance_wallet_outlined,
                                  size: 16.sp,
                                  color: Theme.of(context).colorScheme.onSecondaryContainer,
                                ),
                                SizedBox(width: 6.w),
                                // Show parent's wallet balance for clarity (students are imported entities)
                                Consumer(
                                  builder: (context, ref2, _) {
                                    final parent = ref2.watch(currentParentProvider).value;
                                    final balance = parent?.balance ?? 0.0;
                                    return Text(
                                      FormatUtils.currency(balance),
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: isMobile ? 14.sp : 15.sp,
                                        color: Theme.of(context).colorScheme.onSecondaryContainer,
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                      const Spacer(),
                      
                      // Edit Button
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        tooltip: 'Edit Details',
                        onPressed: _isLoading
                            ? null
                            : () async {
                                final result = await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => EditStudentScreen(
                                      student: student,
                                    ),
                                  ),
                                );
                                // Refresh list if changes were made
                                if (result == true) {
                                  ref.invalidate(parentStudentsProvider);
                                }
                              },
                        color: Theme.of(context).colorScheme.primary,
                        iconSize: isMobile ? 20.sp : 22.sp,
                      ),
                      
                      // Unlink Button
                      IconButton(
                        icon: const Icon(Icons.link_off),
                        tooltip: 'Unlink Student',
                        onPressed: _isLoading ? null : () => _unlinkStudent(student),
                        color: Theme.of(context).colorScheme.error,
                        iconSize: isMobile ? 20.sp : 22.sp,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
