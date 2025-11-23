import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/app_providers.dart';

class LinkStudentScreen extends ConsumerStatefulWidget {
  const LinkStudentScreen({super.key});

  @override
  ConsumerState<LinkStudentScreen> createState() => _LinkStudentScreenState();
}

class _LinkStudentScreenState extends ConsumerState<LinkStudentScreen> {
  final _codeController = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Link a Student')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _codeController,
                  decoration: const InputDecoration(
                    labelText: 'Student ID / Code',
                    prefixIcon: Icon(Icons.confirmation_number_outlined),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _loading
                      ? null
                      : () async {
                          final code = _codeController.text.trim();
                          if (code.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please enter a student code')),
                            );
                            return;
                          }
                          setState(() => _loading = true);
                          try {
                            // 1. Find student by code
                            final student = await ref.read(studentServiceProvider).getStudentByCode(code);
                            if (student == null) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Invalid student code')),
                                );
                              }
                              return;
                            }

                            // 2. Link to current parent
                            final authUser = ref.read(authStateProvider).value;
                            if (authUser == null) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('You are not signed in')),
                                );
                              }
                              return;
                            }
                            final parentId = authUser.id;

                            // Prefer atomic link helper
                            await ref.read(registrationServiceProvider).linkStudentToParent(
                                  studentId: student.id,
                                  parentUserId: parentId,
                                );

                            // Optional: ensure student's parent_user_id is updated
                            await ref.read(studentServiceProvider).updateParentId(student.id, parentId);

                            if (mounted) context.go('/registration-success');
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Failed to link student: $e')),
                              );
                            }
                          } finally {
                            if (mounted) setState(() => _loading = false);
                          }
                        },
                  child: _loading
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Link Student'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => context.go('/registration-success'),
                  child: const Text('Skip for now'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
