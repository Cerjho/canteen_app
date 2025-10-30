import 'dart:convert';
import 'dart:math' show min;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../../../core/models/student.dart';
import '../../../core/services/student_service.dart';
import '../../../core/providers/app_providers.dart';
// format_utils no longer used in this admin screen after removing student.balance
import '../../../core/utils/file_download.dart' as file_download;
import '../../../core/utils/app_logger.dart';
import '../../../shared/components/loading_indicator.dart';
import 'student_form_screen.dart';
import '../../../core/providers/date_refresh_provider.dart';

/// Students Management Screen - displays and manages all students
class StudentsScreen extends ConsumerStatefulWidget {
  const StudentsScreen({super.key});

  @override
  ConsumerState<StudentsScreen> createState() => _StudentsScreenState();
}

class _StudentsScreenState extends ConsumerState<StudentsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedGrade;
  bool _activeOnly = false;
  int _rowsPerPage = 10;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final studentsAsync = ref.watch(studentsProvider);
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Scaffold(
      body: Padding(
        padding: EdgeInsets.all(isMobile ? 16 : 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  Icons.school,
                  size: isMobile ? 24 : 32,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Students Management',
                    style: (isMobile ? Theme.of(context).textTheme.titleLarge : Theme.of(context).textTheme.headlineMedium)?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            SizedBox(height: isMobile ? 16 : 24),

            // Action Buttons Row
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton.icon(
                  onPressed: () => _showAddStudentDialog(context),
                  icon: const Icon(Icons.add),
                  label: const Text('Add Student'),
                ),
                OutlinedButton.icon(
                  onPressed: _handleImport,
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Import CSV'),
                ),
                OutlinedButton.icon(
                  onPressed: _handleExport,
                  icon: const Icon(Icons.download),
                  label: const Text('Export CSV'),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Filters Row
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                // Search
                SizedBox(
                  width: 300,
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search by name...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    onChanged: (value) {
                      setState(() => _searchQuery = value.toLowerCase());
                    },
                  ),
                ),

                // Grade Filter
                SizedBox(
                  width: 180,
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedGrade,
                    decoration: const InputDecoration(
                      labelText: 'Grade',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 16),
                    ),
                    items: const [
                      DropdownMenuItem(value: null, child: Text('All Grades')),
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
                      setState(() => _selectedGrade = value);
                    },
                  ),
                ),

                // Active Only Filter
                FilterChip(
                  label: const Text('Active Only'),
                  selected: _activeOnly,
                  onSelected: (selected) {
                    setState(() => _activeOnly = selected);
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Data Table
            Expanded(
              child: studentsAsync.when(
                data: (students) {
                  // Apply filters
                  var filteredStudents = students.where((student) {
                    // Search filter
                    if (_searchQuery.isNotEmpty &&
                        !student.fullName.toLowerCase().contains(_searchQuery)) {
                      return false;
                    }
                    
                    // Grade filter
                    if (_selectedGrade != null && student.grade != _selectedGrade) {
                      return false;
                    }
                    
                    // Active filter
                    if (_activeOnly && !student.isActive) {
                      return false;
                    }
                    
                    return true;
                  }).toList();

                  if (filteredStudents.isEmpty) {
                    return _buildEmptyState();
                  }

                  return _buildDataTable(filteredStudents);
                },
                loading: () => const LoadingIndicator(text: 'Loading students...'),
                error: (error, stack) => Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Error loading students',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(error.toString()),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: () => ref.refresh(studentsProvider),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.school_outlined,
            size: 80,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            'No students found',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty || _selectedGrade != null
                ? 'Try adjusting your filters'
                : 'Add your first student to get started',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => _showAddStudentDialog(context),
            icon: const Icon(Icons.add),
            label: const Text('Add Student'),
          ),
        ],
      ),
    );
  }

  Widget _buildDataTable(List<Student> students) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final availableWidth = screenWidth - 32; // Account for padding
    
    return Card(
      child: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: min(600, availableWidth), // Don't exceed available width
              maxWidth: availableWidth,
            ),
            child: PaginatedDataTable(
              header: Text(
                '${students.length} student(s)',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              rowsPerPage: isMobile ? 5 : _rowsPerPage,
              onRowsPerPageChanged: isMobile ? null : (value) {
                if (value != null) {
                  setState(() => _rowsPerPage = value);
                }
              },
              availableRowsPerPage: isMobile ? const [5] : const [5, 10, 25, 50],
              columnSpacing: isMobile ? 16 : 56,
              horizontalMargin: isMobile ? 8 : 24,
              columns: const [
                DataColumn(label: Text('Name')),
                DataColumn(label: Text('Grade')),
                DataColumn(label: Text('Parent ID')),
                DataColumn(label: Text('Balance (admin)')),
                DataColumn(label: Text('Allergies')),
                DataColumn(label: Text('Status')),
                DataColumn(label: Text('Actions')),
              ],
              source: _StudentsDataSource(
                students: students,
                context: context,
                onEdit: _showEditStudentDialog,
                onDelete: _handleDelete,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showAddStudentDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const StudentFormScreen(mode: StudentFormMode.add),
    );
  }

  void _showEditStudentDialog(BuildContext context, Student student) {
    showDialog(
      context: context,
      builder: (context) => StudentFormScreen(
        mode: StudentFormMode.edit,
        student: student,
      ),
    );
  }

  Future<void> _handleDelete(String studentId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Student'),
        content: const Text(
          'Are you sure you want to delete this student? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await ref.read(studentServiceProvider).deleteStudent(studentId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Student deleted successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting student: $e')),
          );
        }
      }
    }
  }

  Future<void> _handleImport() async {
    try {
      // Pick CSV file only
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      if (file.bytes == null) {
        throw Exception('No file data');
      }

      if (!mounted) return;

      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const LoadingIndicator(text: 'Importing students...'),
      );

      // Import students
      final importResult = await (ref.read(studentServiceProvider) as StudentService).importStudentsFromFile(
            fileBytes: file.bytes!,
            fileName: file.name,
          );

      if (!mounted) return;
      
      // Close loading dialog using root navigator
      Navigator.of(context, rootNavigator: true).pop();

      // Small delay to allow Firestore stream to update
      await Future.delayed(const Duration(milliseconds: 300));

      // Show result dialog
      final hasErrors = importResult['failed'].isNotEmpty;
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(
                hasErrors ? Icons.warning_amber : Icons.check_circle,
                color: hasErrors
                    ? Theme.of(context).colorScheme.error
                    : Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              const Text('Import Complete'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('✅ Successfully imported: ${importResult['success']} student(s)'),
              if (importResult['duplicates'] > 0)
                Text('⚠️  Skipped duplicates: ${importResult['duplicates']} student(s)'),
              if (importResult['failed'].isNotEmpty)
                Text('❌ Failed: ${importResult['failed'].length} student(s)'),
              if (importResult['failed'].isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'Failed entries:',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                Container(
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: importResult['failed']
                          .map<Widget>(
                            (error) => Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text(
                                '• ${error['row']}: ${error['error']}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        // Close loading dialog if open using root navigator
        try {
          Navigator.of(context, rootNavigator: true).pop();
        } catch (popError) {
          AppLogger.debug('Failed to pop loading dialog: $popError');
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error importing students: $e')),
        );
      }
    }
  }

  Future<void> _handleExport() async {
    try {
      final students = ref.read(studentsProvider).value ?? [];
      
      if (students.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No students to export')),
        );
        return;
      }

      final service = ref.read(studentServiceProvider);
  final timestamp = ref.read(dateRefreshProvider).toIso8601String().split('T')[0];
      final fileName = 'students_$timestamp.csv';

      final String csvData = await (service as StudentService).exportStudentsToCsv(students);
      final bytes = utf8.encode(csvData);
      _downloadFile(bytes, fileName, 'text/csv');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Exported ${students.length} students to $fileName')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error exporting students: $e')),
        );
      }
    }
  }

  void _downloadFile(List<int> bytes, String fileName, String mimeType) {
    file_download.downloadFile(bytes, fileName, mimeType);
  }
}

/// Data source for paginated data table
class _StudentsDataSource extends DataTableSource {
  final List<Student> students;
  final BuildContext context;
  final Function(BuildContext, Student) onEdit;
  final Function(String) onDelete;

  _StudentsDataSource({
    required this.students,
    required this.context,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  DataRow? getRow(int index) {
    if (index >= students.length) return null;
    final student = students[index];

    return DataRow(
      cells: [
        // Name with avatar
        DataCell(
          Row(
            children: [
              CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                child: Text(
                  student.firstName[0].toUpperCase(),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  student.fullName,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        // Grade
        DataCell(Text(student.grade)),
        // Parent ID
        DataCell(Text(student.parentId ?? '-')),
        // Balance column removed (admin only) - preserved in database for migration/reference
        // Allergies
        DataCell(
          (student.allergies == null || student.allergies!.isEmpty)
              ? const Text('-')
              : Tooltip(
                  message: student.allergies!,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.warning_amber,
                        size: 16,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          student.allergies!,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ],
                  ),
                ),
        ),
        // Status
        DataCell(
          Chip(
            label: Text(
              student.isActive ? 'Active' : 'Inactive',
              style: const TextStyle(fontSize: 12),
            ),
            backgroundColor: student.isActive
                ? Theme.of(context).colorScheme.primaryContainer
                : Theme.of(context).colorScheme.surfaceContainerHighest,
            side: BorderSide.none,
            padding: EdgeInsets.zero,
            labelPadding: const EdgeInsets.symmetric(horizontal: 8),
          ),
        ),
        // Actions
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 20),
                onPressed: () => onEdit(context, student),
                tooltip: 'Edit',
                color: Theme.of(context).colorScheme.primary,
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 20),
                onPressed: () => onDelete(student.id),
                tooltip: 'Delete',
                color: Theme.of(context).colorScheme.error,
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  bool get isRowCountApproximate => false;

  @override
  int get rowCount => students.length;

  @override
  int get selectedRowCount => 0;
}
