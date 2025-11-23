import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/utils/validation_utils.dart';

class ParentRegistrationScreen extends ConsumerStatefulWidget {
  const ParentRegistrationScreen({super.key});

  @override
  ConsumerState<ParentRegistrationScreen> createState() => _ParentRegistrationScreenState();
}

class _ParentRegistrationScreenState extends ConsumerState<ParentRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  final bool _obscurePassword = true;
  String? _emailError;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegistration() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final supabase = ref.read(supabaseProvider);
      final email = _emailController.text.trim();
      final password = _passwordController.text;

      await supabase.auth.signUp(
        email: email,
        password: password,
        emailRedirectTo: 'mycanteen://auth-callback',
      );

      if (mounted) context.go('/registration-info');
    } catch (e) {
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
                      TextFormField(
                        controller: _emailController,
                        decoration: InputDecoration(
                          labelText: 'Email Address *',
                          prefixIcon: const Icon(Icons.email_outlined),
                          errorText: _emailError,
                        ),
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) {
                          final base = ValidationUtils.email(v);
                          if (base != null) return base;
                          if (_emailError != null) return _emailError;
                          return null;
                        },
                        onChanged: (value) async {
                          final email = value.trim();
                          if (ValidationUtils.email(email) != null) {
                            setState(() => _emailError = null);
                            return;
                          }
                          final exists = await ref.read(registrationServiceProvider).isEmailRegistered(email);
                          if (!mounted) return;
                          setState(() => _emailError = exists ? 'Email is already registered' : null);
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        decoration: const InputDecoration(
                          labelText: 'Password *',
                          prefixIcon: Icon(Icons.lock_outline),
                          helperText: 'Minimum 6 characters',
                        ),
                        obscureText: _obscurePassword,
                        validator: (v) => v == null || v.isEmpty
                            ? 'Please enter password'
                            : v.length < 6
                                ? 'Password must be at least 6 characters'
                                : null,
                      ),
                      const SizedBox(height: 24),
                      FilledButton(onPressed: _isLoading ? null : _handleRegistration, child: _isLoading ? const CircularProgressIndicator.adaptive() : const Text('Register')),
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
