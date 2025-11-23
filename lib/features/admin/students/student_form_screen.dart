import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:typed_data';
import '../../../core/models/student.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/providers/user_providers.dart';
import '../../../core/utils/validation_utils.dart';
 

/// Student Form Mode - add or edit
enum StudentFormMode { add, edit }

/// Student Form Screen - modal dialog for adding/editing students
class StudentFormScreen extends ConsumerStatefulWidget {
  final StudentFormMode mode;
  final Student? student;

  const StudentFormScreen({
    super.key,
    required this.mode,
    this.student,
  });

  @override
  ConsumerState<StudentFormScreen> createState() => _StudentFormScreenState();
}

class _StudentFormScreenState extends ConsumerState<StudentFormScreen> {
  final _formKey = GlobalKey<FormState>();
  
  late final TextEditingController _firstNameController;
  late final TextEditingController _lastNameController;
  late final TextEditingController _gradeController;
  late final TextEditingController _parentIdController;
  late final TextEditingController _allergiesController;
  late final TextEditingController _dietaryController;
  
  bool _isActive = true;
  bool _isLoading = false;
  Uint8List? _photoBytes;
  String? _photoUrl;

  @override
  void initState() {
    super.initState();
    final student = widget.student;
    
    _firstNameController = TextEditingController(text: student?.firstName ?? '');
    _lastNameController = TextEditingController(text: student?.lastName ?? '');
    _gradeController = TextEditingController(text: student?.grade ?? '');
    _parentIdController = TextEditingController(text: student?.parentId ?? '');
    _allergiesController = TextEditingController(text: student?.allergies ?? '');
    _dietaryController = TextEditingController(text: student?.dietaryRestrictions ?? '');
    _isActive = student?.isActive ?? true;
    _photoUrl = student?.photoUrl;
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _gradeController.dispose();
    _parentIdController.dispose();
    _allergiesController.dispose();
    _dietaryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 700,
        constraints: const BoxConstraints(maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Row(
                children: [
                  Icon(
                    widget.mode == StudentFormMode.add ? Icons.person_add : Icons.edit,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    widget.mode == StudentFormMode.add ? 'Add Student' : 'Edit Student',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ],
              ),
            ),

            // Form
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // First Name
                      TextFormField(
                        controller: _firstNameController,
                        decoration: const InputDecoration(
                          labelText: 'First Name *',
                          hintText: 'Enter first name',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        validator: (value) => ValidationUtils.required(value, 'First name'),
                      ),
                      const SizedBox(height: 16),

                      // Last Name
                      TextFormField(
                        controller: _lastNameController,
                        decoration: const InputDecoration(
                          labelText: 'Last Name *',
                          hintText: 'Enter last name',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        validator: (value) => ValidationUtils.required(value, 'Last name'),
                      ),
                      const SizedBox(height: 16),

                      // Grade
                      DropdownButtonFormField<String>(
                        initialValue: _gradeController.text.trim().isNotEmpty && ['Nursery', 'Kinder', 'Grade 1', 'Grade 2', 'Grade 3', 'Grade 4', 'Grade 5', 'Grade 6'].contains(_gradeController.text.trim()) ? _gradeController.text.trim() : null,
                        decoration: const InputDecoration(
                          labelText: 'Grade *',
                          hintText: 'Select grade',
                          prefixIcon: Icon(Icons.school_outlined),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'Nursery', child: Text('Nursery')),
                          DropdownMenuItem(value: 'Kinder', child: Text('Kinder')),
                          DropdownMenuItem(value: 'Grade 1', child: Text('Grade 1')),
                          DropdownMenuItem(value: 'Grade 2', child: Text('Grade 2')),
                          DropdownMenuItem(value: 'Grade 3', child: Text('Grade 3')),
                          DropdownMenuItem(value: 'Grade 4', child: Text('Grade 4')),
                          DropdownMenuItem(value: 'Grade 5', child: Text('Grade 5')),
                          DropdownMenuItem(value: 'Grade 6', child: Text('Grade 6')),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            _gradeController.text = value;
                          }
                        },
                        validator: (value) => ValidationUtils.required(value, 'Grade'),
                      ),
                      const SizedBox(height: 16),

                      // Parent ID
                      TextFormField(
                        controller: _parentIdController,
                        decoration: const InputDecoration(
                          labelText: 'Parent ID',
                          hintText: 'Enter parent ID (optional)',
                          prefixIcon: Icon(Icons.family_restroom_outlined),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Allergies
                      TextFormField(
                        controller: _allergiesController,
                        decoration: const InputDecoration(
                          labelText: 'Allergies',
                          hintText: 'e.g., Peanuts, Dairy, Eggs',
                          prefixIcon: Icon(Icons.warning_amber_outlined),
                          helperText: 'Separate multiple allergies with commas',
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 16),

                      // Dietary Restrictions
                      TextFormField(
                        controller: _dietaryController,
                        decoration: const InputDecoration(
                          labelText: 'Dietary Restrictions',
                          hintText: 'e.g., Vegetarian, Vegan, Gluten-free',
                          prefixIcon: Icon(Icons.restaurant_menu_outlined),
                          helperText: 'Separate multiple restrictions with commas',
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 24),

                      // Photo Upload Section
                      Text(
                        'Student Photo',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 150,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5),
                          ),
                        ),
                        child: _photoBytes != null
                            ? Stack(
                                fit: StackFit.expand,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.memory(
                                      _photoBytes!,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  Positioned(
                                    top: 8,
                                    right: 8,
                                    child: IconButton(
                                      onPressed: _isLoading
                                          ? null
                                          : () {
                                              setState(() {
                                                _photoBytes = null;
                                              });
                                            },
                                      icon: const Icon(Icons.close),
                                      style: IconButton.styleFrom(
                                        backgroundColor: Theme.of(context).colorScheme.error.withValues(alpha: 0.9),
                                        foregroundColor: Theme.of(context).colorScheme.onError,
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            : _photoUrl != null
                                ? Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: Image.network(
                                          _photoUrl!,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) {
                                            return Center(
                                              child: Icon(
                                                Icons.person,
                                                size: 48,
                                                color: Theme.of(context).colorScheme.outline,
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                      Positioned(
                                        top: 8,
                                        right: 8,
                                        child: IconButton(
                                          onPressed: _isLoading
                                              ? null
                                              : () {
                                                  setState(() {
                                                    _photoUrl = null;
                                                  });
                                                },
                                          icon: const Icon(Icons.close),
                                          style: IconButton.styleFrom(
                                            backgroundColor: Theme.of(context).colorScheme.error.withValues(alpha: 0.9),
                                            foregroundColor: Theme.of(context).colorScheme.onError,
                                          ),
                                        ),
                                      ),
                                    ],
                                  )
                                : Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.person_add_alt_1_outlined,
                                          size: 48,
                                          color: Theme.of(context).colorScheme.outline,
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'No photo selected',
                                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: _isLoading ? null : _pickPhoto,
                        icon: const Icon(Icons.upload_file),
                        label: const Text('Choose Photo'),
                      ),
                      const SizedBox(height: 16),

                      const SizedBox(height: 16),

                      // Is Active
                      SwitchListTile(
                        title: const Text('Active'),
                        subtitle: const Text('Student can place orders'),
                        value: _isActive,
                        onChanged: (value) {
                          setState(() => _isActive = value);
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Actions
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: Theme.of(context).dividerColor),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isLoading ? null : () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: _isLoading ? null : _handleSubmit,
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(widget.mode == StudentFormMode.add ? 'Add Student' : 'Save Changes'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final storageService = ref.read(storageServiceProvider);
      final studentId = widget.student?.id ?? const Uuid().v4();
      String? finalPhotoUrl = _photoUrl;

      // Upload new photo if selected
      if (_photoBytes != null) {
        finalPhotoUrl = await storageService.uploadStudentPhoto(
          _photoBytes!,
          studentId,
        );
      }

      final student = Student(
        id: studentId,
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        grade: _gradeController.text.trim(),
        // Store null (not empty string) when no parent is provided to avoid DB UUID cast issues
        parentId: _parentIdController.text.trim().isNotEmpty ? _parentIdController.text.trim() : null,
        allergies: _allergiesController.text.trim().isNotEmpty ? _allergiesController.text.trim() : null,
        dietaryRestrictions: _dietaryController.text.trim().isNotEmpty ? _dietaryController.text.trim() : null,
        photoUrl: finalPhotoUrl,
        isActive: _isActive,
        createdAt: widget.student?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final studentService = ref.read(studentServiceProvider);
      
      if (widget.mode == StudentFormMode.add) {
        await studentService.addStudent(student);
      } else {
        await studentService.updateStudent(student);
      }

      // Invalidate students provider to refresh UI immediately
      ref.invalidate(studentsProvider);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.mode == StudentFormMode.add
                  ? 'Student added successfully'
                  : 'Student updated successfully',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _pickPhoto() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        setState(() {
          _photoBytes = file.bytes;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pick photo: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }
}
