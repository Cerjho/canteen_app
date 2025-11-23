import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/models/user_role.dart';

class CompleteRegistrationScreen extends ConsumerStatefulWidget {
  const CompleteRegistrationScreen({super.key});

  @override
  ConsumerState<CompleteRegistrationScreen> createState() => _CompleteRegistrationScreenState();
}

class _CompleteRegistrationScreenState extends ConsumerState<CompleteRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Complete Registration')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Profile picture placeholder
                      CircleAvatar(radius: 36, child: Icon(Icons.person, size: 36, color: Theme.of(context).colorScheme.primary)),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _fullNameController,
                        decoration: const InputDecoration(labelText: 'Full Name'),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter your full name' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(labelText: 'Phone Number'),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return null; // optional
                          final value = v.trim();
                          if (!RegExp(r'^\+?[\d\s\-\(\)]+$').hasMatch(value)) {
                            return 'Invalid phone number';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _addressController,
                        decoration: const InputDecoration(labelText: 'Address'),
                        maxLines: 2,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return null; // optional
                          if (v.trim().length < 10) {
                            return 'Address must be at least 10 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _submitting
                              ? null
                              : () async {
                                  if (!_formKey.currentState!.validate()) return;
                                  setState(() => _submitting = true);
                                  try {
                                    // Ensure we have a signed-in user
                                    final auth = ref.read(authStateProvider).value;
                                    if (auth == null) {
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('You are not signed in. Please sign in again.')),
                                        );
                                      }
                                      return;
                                    }

                                    final uid = auth.id;
                                    final email = auth.email ?? '';
                                    final fullName = _fullNameController.text.trim();
                                    final parts = fullName.split(RegExp(r"\s+"));
                                    final firstName = parts.isNotEmpty ? parts.first : 'Parent';
                                    final lastName = parts.length > 1 ? parts.sublist(1).join(' ') : '';

                                    // If user already exists, update; else create user + parent
                                    final userService = ref.read(userServiceProvider);
                                    final existing = await userService.getUser(uid);

                                    // Update or create basic user record (names/flags)
                                    final targetUser = (existing ?? AppUser(
                                      uid: uid,
                                      firstName: firstName,
                                      lastName: lastName,
                                      email: email,
                                      isAdmin: false,
                                      isParent: true,
                                      createdAt: DateTime.now(),
                                      isActive: true,
                                      needsOnboarding: true,
                                    ))
                                        .copyWith(
                                      firstName: firstName,
                                      lastName: lastName,
                                      email: email.isNotEmpty ? email : (existing?.email ?? ''),
                                      updatedAt: DateTime.now(),
                                      isParent: true,
                                    );
                                    if (existing == null) {
                                      await userService.createUser(targetUser);
                                    } else {
                                      await userService.updateUser(targetUser);
                                    }

                                    // Ensure parent profile exists or update contact details
                                    await ref.read(registrationServiceProvider).upsertParentProfile(
                                          uid: uid,
                                          phone: _phoneController.text.trim().isNotEmpty ? _phoneController.text.trim() : null,
                                          address: _addressController.text.trim().isNotEmpty ? _addressController.text.trim() : null,
                                        );

                                    // Mark onboarding complete
                                    final updated = targetUser.copyWith(
                                      needsOnboarding: false,
                                      updatedAt: DateTime.now(),
                                    );
                                    await userService.updateUser(updated);

                                    // Wait for currentUser stream to emit, then proceed
                                    final user = await ref.watch(currentUserProvider.future).timeout(
                                          const Duration(seconds: 10),
                                          onTimeout: () => null,
                                        );

                                    if (mounted && user != null) {
                                      context.go('/link-student');
                                    }
                                  } catch (e) {
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Failed to save profile: $e')),
                                      );
                                    }
                                  } finally {
                                    if (mounted) setState(() => _submitting = false);
                                  }
                                },
                          child: _submitting
                              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Text('Next'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
