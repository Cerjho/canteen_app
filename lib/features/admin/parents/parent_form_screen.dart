import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/providers/user_providers.dart';

/// Parent Form Screen - Edit parent information
/// 
/// Features:
/// - Edit parent contact information (phone, address)
/// - Update account balance
/// - View and manage linked students
/// - Activate/deactivate parent account
/// 
/// Note: This screen only edits the parent-specific data.
/// User authentication data (email, name) is managed separately.
class ParentFormScreen extends ConsumerStatefulWidget {
  final String? parentId;
  
  const ParentFormScreen({super.key, this.parentId});

  @override
  ConsumerState<ParentFormScreen> createState() => _ParentFormScreenState();
}

class _ParentFormScreenState extends ConsumerState<ParentFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _balanceController = TextEditingController();
  bool _isLoading = false;
  bool _isActive = true;
  bool _initialized = false;
  bool _sendingReset = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _addressController.dispose();
    _balanceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.parentId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Parent Information')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Parent accounts are created through the mobile app registration.\n\n'
              'Use this screen to edit existing parent information only.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final parentAsync = ref.watch(parentByIdProvider(widget.parentId!));
    final userAsync = ref.watch(userByIdProvider(widget.parentId!));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Parent'),
        actions: [
          if (!_isLoading)
            TextButton(
              onPressed: _saveChanges,
              child: const Text('SAVE'),
            ),
        ],
      ),
      body: parentAsync.when(
        data: (parent) {
          if (parent == null) {
            return const Center(child: Text('Parent not found'));
          }

          // Initialize form fields once on first data load
          if (!_initialized) {
            if (parent.phone != null) {
              _phoneController.text = parent.phone!;
            }
            if (parent.address != null) {
              _addressController.text = parent.address!;
            }
            _balanceController.text = parent.balance.toString();
            _isActive = parent.isActive;
            _initialized = true;
          }

          return userAsync.when(
            data: (user) {
              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // User Info Card (Read-only)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'User Information',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),
                              _buildReadOnlyField('Name', '${user?.firstName ?? ''} ${user?.lastName ?? ''}'),
                              _buildReadOnlyField('Email', user?.email ?? ''),
                              _buildReadOnlyField('User ID', parent.userId),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Editable Fields Card
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Contact Information',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _phoneController,
                                decoration: const InputDecoration(
                                  labelText: 'Phone Number',
                                  prefixIcon: Icon(Icons.phone),
                                  border: OutlineInputBorder(),
                                  hintText: '+63 XXX XXX XXXX',
                                ),
                                keyboardType: TextInputType.phone,
                                validator: (value) {
                                  if (value != null && value.isNotEmpty && value.length < 10) {
                                    return 'Enter a valid phone number';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _addressController,
                                decoration: const InputDecoration(
                                  labelText: 'Address',
                                  prefixIcon: Icon(Icons.location_on),
                                  border: OutlineInputBorder(),
                                  hintText: 'Enter address',
                                ),
                                maxLines: 3,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Balance Card
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Account Balance',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _balanceController,
                                decoration: const InputDecoration(
                                  labelText: 'Balance',
                                  prefixIcon: Icon(Icons.account_balance_wallet),
                                  prefixText: '₱ ',
                                  border: OutlineInputBorder(),
                                ),
                                keyboardType: TextInputType.number,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Balance is required';
                                  }
                                  final balance = double.tryParse(value);
                                  if (balance == null || balance < 0) {
                                    return 'Enter a valid balance';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Warning: Changing balance directly should only be done for corrections. Use the "Add Balance" button in the parent list for normal top-ups.',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Colors.orange,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Account Status Card
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Account Status',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),
                              SwitchListTile(
                                title: const Text('Active'),
                                subtitle: Text(_isActive 
                                  ? 'Parent can access the app and place orders'
                                  : 'Parent account is disabled'),
                                value: _isActive,
                                onChanged: (value) {
                                  setState(() => _isActive = value);
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Account Security Card
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Account Security',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Send a password reset email to this parent. They will receive a link to set a new password.',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              const SizedBox(height: 12),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: ElevatedButton.icon(
                                  onPressed: _sendingReset || (user?.email.isEmpty ?? true)
                                      ? null
                                      : () async {
                                          final email = user?.email;
                                          if (email == null || email.isEmpty) return;
                                          setState(() => _sendingReset = true);
                                          try {
                                            await ref.read(userServiceProvider).sendPasswordResetEmail(email);
                                            if (mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                  content: Text('Password reset email sent to $email'),
                                                  backgroundColor: Colors.green,
                                                ),
                                              );
                                            }
                                          } catch (e) {
                                            if (mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(content: Text('Error sending reset email: $e')),
                                              );
                                            }
                                          } finally {
                                            if (mounted) setState(() => _sendingReset = false);
                                          }
                                        },
                                  icon: _sendingReset
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        )
                                      : const Icon(Icons.lock_reset),
                                  label: const Text('Send password reset email'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      // Linked Students Card
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Linked Students',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),
                              if (parent.children.isEmpty)
                                const Text('No students linked to this parent')
                              else
                                ...parent.children.map((studentId) {
                                  return ListTile(
                                    leading: const Icon(Icons.child_care),
                                    title: Text('Student ID: $studentId'),
                                    trailing: const Icon(Icons.arrow_forward),
                                    onTap: () {
                                      context.go('/students');
                                    },
                                  );
                                }),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Center(child: Text('Error: $error')),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error: $error'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReadOnlyField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 16),
          ),
        ],
      ),
    );
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final parent = await ref.read(parentServiceProvider).getParentById(widget.parentId!);
      if (parent == null) {
        throw Exception('Parent not found');
      }

      final balance = double.parse(_balanceController.text);
      
      final updatedParent = parent.copyWith(
        phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
        address: _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
        balance: balance,
        isActive: _isActive,
        updatedAt: DateTime.now(),
      );

      await ref.read(parentServiceProvider).updateParent(updatedParent);

      // Invalidate parents provider to refresh UI immediately
      ref.invalidate(parentsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Parent updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
        context.go('/parents');
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
}
