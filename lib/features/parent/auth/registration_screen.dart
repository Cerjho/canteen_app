import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/utils/app_logger.dart';

class ParentRegistrationScreen extends ConsumerStatefulWidget {
  const ParentRegistrationScreen({super.key});

  @override
  ConsumerState<ParentRegistrationScreen> createState() => _ParentRegistrationScreenState();
}

class _ParentRegistrationScreenState extends ConsumerState<ParentRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();

  bool _isLoading = false;
  final bool _obscurePassword = true;
  final bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _handleRegistration() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final registrationService = ref.read(registrationServiceProvider);

      AppLogger.info('🔐 Starting parent registration for: ${_emailController.text.trim()}');

      await registrationService.registerParent(
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
        address: _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
        phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
      );

      AppLogger.info('✅ Parent registration successful!');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Parent account created successfully!'), backgroundColor: Colors.green, duration: Duration(seconds: 3)),
        );

        _formKey.currentState!.reset();
        _firstNameController.clear();
        _lastNameController.clear();
        _emailController.clear();
        _passwordController.clear();
        _confirmPasswordController.clear();
        _addressController.clear();
        _phoneController.clear();
      }
    } catch (e) {
      AppLogger.error('❌ Parent registration failed', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Registration failed: ${e.toString()}'), backgroundColor: Colors.red, duration: const Duration(seconds: 5)),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Icon(Icons.person_add, size: 64, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(height: 16),
                      Text('Create Parent Account', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                      const SizedBox(height: 24),
                      TextFormField(controller: _firstNameController, decoration: const InputDecoration(labelText: 'First Name *', prefixIcon: Icon(Icons.person_outline)), validator: (v) => v == null || v.trim().isEmpty ? 'Please enter first name' : null),
                      const SizedBox(height: 16),
                      TextFormField(controller: _lastNameController, decoration: const InputDecoration(labelText: 'Last Name *', prefixIcon: Icon(Icons.person_outline)), validator: (v) => v == null || v.trim().isEmpty ? 'Please enter last name' : null),
                      const SizedBox(height: 16),
                      TextFormField(controller: _emailController, decoration: const InputDecoration(labelText: 'Email Address *', prefixIcon: Icon(Icons.email_outlined)), keyboardType: TextInputType.emailAddress, validator: (v) => v == null || v.trim().isEmpty || !RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}\$').hasMatch(v) ? 'Please enter a valid email address' : null),
                      const SizedBox(height: 16),
                      TextFormField(controller: _passwordController, decoration: InputDecoration(labelText: 'Password *', prefixIcon: const Icon(Icons.lock_outline), helperText: 'Minimum 6 characters'), obscureText: _obscurePassword, validator: (v) => v == null || v.isEmpty ? 'Please enter password' : v.length < 6 ? 'Password must be at least 6 characters' : null),
                      const SizedBox(height: 16),
                      TextFormField(controller: _confirmPasswordController, decoration: InputDecoration(labelText: 'Confirm Password *', prefixIcon: const Icon(Icons.lock_outline)), obscureText: _obscureConfirmPassword, validator: (v) => v == null || v.isEmpty ? 'Please confirm password' : v != _passwordController.text ? 'Passwords do not match' : null),
                      const SizedBox(height: 24),
                      FilledButton(onPressed: _isLoading ? null : _handleRegistration, child: _isLoading ? const CircularProgressIndicator.adaptive() : const Text('Create Parent Account')),
                      const SizedBox(height: 16),
                      TextButton(onPressed: _isLoading ? null : () => context.go('/login'), child: const Text('Back to Login')),
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
