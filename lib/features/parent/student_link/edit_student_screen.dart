// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:responsive_builder/responsive_builder.dart';
import '../../../core/models/student.dart';
import '../../../core/providers/app_providers.dart';


/// Edit Student Details Screen - Parents can edit their linked children's details
///
/// **Features:**
/// - Edit allergies information
/// - Edit dietary restrictions
/// - View-only fields: Name, Grade, Balance (managed by admin)
/// - Form validation
/// - Responsive layout
/// - Success/Error feedback
///
/// **Parent Permissions:**
/// - ✅ Can edit: Allergies, Dietary Restrictions
/// - ❌ Cannot edit: Name, Grade, Balance, ID
class EditStudentScreen extends ConsumerStatefulWidget {
  final Student student;

  const EditStudentScreen({
    super.key,
    required this.student,
  });

  @override
  ConsumerState<EditStudentScreen> createState() => _EditStudentScreenState();
}

class _EditStudentScreenState extends ConsumerState<EditStudentScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _allergiesController;
  late TextEditingController _dietaryRestrictionsController;
  bool _isLoading = false;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _allergiesController = TextEditingController(
      text: widget.student.allergies ?? '',
    );
    _dietaryRestrictionsController = TextEditingController(
      text: widget.student.dietaryRestrictions ?? '',
    );

    // Listen for changes
    _allergiesController.addListener(_onFieldChanged);
    _dietaryRestrictionsController.addListener(_onFieldChanged);
  }

  void _onFieldChanged() {
    final hasChanges = _allergiesController.text != (widget.student.allergies ?? '') ||
        _dietaryRestrictionsController.text != (widget.student.dietaryRestrictions ?? '');

    if (hasChanges != _hasChanges) {
      setState(() {
        _hasChanges = hasChanges;
      });
    }
  }

  @override
  void dispose() {
    _allergiesController.dispose();
    _dietaryRestrictionsController.dispose();
    super.dispose();
  }

  /// Save student details
  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    // Check if there are any changes
    if (!_hasChanges) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No changes to save'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Update student with new details
      final updatedStudent = widget.student.copyWith(
        allergies: _allergiesController.text.trim().isEmpty
            ? null
            : _allergiesController.text.trim(),
        dietaryRestrictions: _dietaryRestrictionsController.text.trim().isEmpty
            ? null
            : _dietaryRestrictionsController.text.trim(),
        updatedAt: DateTime.now(),
      );

      // Save to database
      await ref.read(studentServiceProvider).updateStudent(updatedStudent);

      if (!mounted) return;

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8.w),
              const Expanded(
                child: Text('Student details updated successfully!'),
              ),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );

      // Go back
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              SizedBox(width: 8.w),
              Expanded(
                child: Text('Error: ${e.toString().replaceAll('Exception: ', '')}'),
              ),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Confirm discard changes
  Future<bool> _onWillPop() async {
    if (!_hasChanges) return true;

    final shouldPop = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Discard Changes?'),
        content: const Text(
          'You have unsaved changes. Are you sure you want to discard them?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );

    return shouldPop ?? false;
  }

  @override
  Widget build(BuildContext context) {
  // ignore: use_build_context_synchronously
  return PopScope(
      canPop: !_hasChanges,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        // Capture NavigatorState before awaiting to avoid using BuildContext
        // across an async gap (avoids analyzer warnings).
        final navigator = Navigator.of(context);
        final shouldPop = await _onWillPop();
        if (!mounted) return;
        if (shouldPop) {
          navigator.pop();
        }
      },
      child: ResponsiveBuilder(
        builder: (context, sizingInfo) {
          final isMobile = sizingInfo.isMobile;

          return Scaffold(
            appBar: AppBar(
              title: const Text('Edit Student Details'),
              elevation: 0,
              actions: [
                // Save Button
                if (_hasChanges)
                  TextButton.icon(
                    onPressed: _isLoading ? null : _saveChanges,
                    icon: _isLoading
                        ? SizedBox(
                            width: 16.w,
                            height: 16.h,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          )
                        : const Icon(Icons.check),
                    label: const Text('Save'),
                  ),
                SizedBox(width: 8.w),
              ],
            ),
            body: SingleChildScrollView(
              padding: EdgeInsets.all(isMobile ? 16.w : 24.w),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: isMobile ? double.infinity : 700.w,
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Student Info Card (Read-only)
                        _buildStudentInfoCard(isMobile),
                        SizedBox(height: 24.h),

                        // Editable Fields Card
                        _buildEditableFieldsCard(isMobile),
                        SizedBox(height: 24.h),

                        // Info about restricted fields
                        _buildInfoCard(isMobile),
                        SizedBox(height: 24.h),

                        // Save Button (Bottom)
                        FilledButton.icon(
                          onPressed: _isLoading || !_hasChanges ? null : _saveChanges,
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
                              : const Icon(Icons.save),
                          label: Text(_isLoading ? 'Saving...' : 'Save Changes'),
                          style: FilledButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: 16.h),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Build student info card (read-only)
  Widget _buildStudentInfoCard(bool isMobile) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 16.w : 20.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: isMobile ? 32.r : 40.r,
                  backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                  backgroundImage: widget.student.photoUrl != null
                      ? NetworkImage(widget.student.photoUrl!)
                      : null,
                  child: widget.student.photoUrl == null
                      ? Text(
                          widget.student.firstName[0].toUpperCase(),
                          style: TextStyle(
                            fontSize: isMobile ? 24.sp : 32.sp,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                          ),
                        )
                      : null,
                ),
                SizedBox(width: 16.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.student.fullName,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        widget.student.grade,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 20.h),
            Divider(height: 1.h),
            SizedBox(height: 16.h),
            _buildReadOnlyField(
              'Student ID',
              widget.student.id,
              Icons.badge_outlined,
              isMobile,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReadOnlyField(
    String label,
    String value,
    IconData icon,
    bool isMobile,
  ) {
    return Row(
      children: [
        Icon(
          icon,
          size: 20.sp,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              SizedBox(height: 2.h),
              Text(
                value,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Build editable fields card
  Widget _buildEditableFieldsCard(bool isMobile) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 16.w : 20.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Health & Dietary Information',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            SizedBox(height: 8.h),
            Text(
              'Keep this information up to date to ensure your child\'s safety',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            SizedBox(height: 20.h),

            // Allergies Field
            TextFormField(
              controller: _allergiesController,
              decoration: InputDecoration(
                labelText: 'Allergies',
                hintText: 'e.g., Peanuts, Shellfish, Dairy',
                helperText: 'Enter known allergies separated by commas',
                prefixIcon: Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.orange[700],
                ),
                border: const OutlineInputBorder(),
                suffixIcon: _allergiesController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _allergiesController.clear();
                        },
                      )
                    : null,
              ),
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
            ),
            SizedBox(height: 20.h),

            // Dietary Restrictions Field
            TextFormField(
              controller: _dietaryRestrictionsController,
              decoration: InputDecoration(
                labelText: 'Dietary Restrictions',
                hintText: 'e.g., Vegetarian, Halal, No Pork',
                helperText: 'Enter dietary restrictions or preferences',
                prefixIcon: const Icon(Icons.restaurant_menu),
                border: const OutlineInputBorder(),
                suffixIcon: _dietaryRestrictionsController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _dietaryRestrictionsController.clear();
                        },
                      )
                    : null,
              ),
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
            ),
          ],
        ),
      ),
    );
  }

  /// Build info card about restrictions
  Widget _buildInfoCard(bool isMobile) {
    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
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
                  size: 20.sp,
                ),
                SizedBox(width: 8.w),
                Text(
                  'Note',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                ),
              ],
            ),
            SizedBox(height: 12.h),
            Text(
              'Some information like student name, grade, and balance can only be updated by school administrators for security reasons.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            SizedBox(height: 8.h),
            Text(
              'If you need to update this information, please contact the school admin.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
