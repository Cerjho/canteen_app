import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/utils/validation_utils.dart';
import '../../../core/utils/app_logger.dart';
// imports adjusted for parent auth screen

class ParentLoginScreen extends ConsumerStatefulWidget {
  const ParentLoginScreen({super.key});

  @override
  ConsumerState<ParentLoginScreen> createState() => _ParentLoginScreenState();
}

// The implementation is adapted from the shared login screen but scoped to parent feature
class _ParentLoginScreenState extends ConsumerState<ParentLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text;
      AppLogger.debug('🔐 Parent login attempt with email: $email');

      final userCredential = await ref.read(authServiceProvider).signInWithEmailAndPassword(email, password);
      AppLogger.info('✅ Parent login successful for: ${userCredential.user?.email}');

      // After sign-in, routing will be handled by router redirect logic
      if (mounted) context.go('/parent-dashboard');
    } catch (e) {
      AppLogger.error('❌ Parent login failed', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Login failed: ${e.toString()}'), backgroundColor: Colors.red),
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
                      Icon(Icons.school, size: 64, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(height: 16),
                      Text('Parent Sign In', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                      const SizedBox(height: 24),
                      TextFormField(controller: _emailController, decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_outlined)), keyboardType: TextInputType.emailAddress, validator: ValidationUtils.email, enabled: !_isLoading),
                      const SizedBox(height: 16),
                      TextFormField(controller: _passwordController, decoration: InputDecoration(labelText: 'Password', prefixIcon: const Icon(Icons.lock_outlined), suffixIcon: IconButton(icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined), onPressed: () => setState(() => _obscurePassword = !_obscurePassword),),), obscureText: _obscurePassword, validator: ValidationUtils.password, enabled: !_isLoading, onFieldSubmitted: (_) => _handleLogin()),
                      const SizedBox(height: 24),
                      FilledButton(onPressed: _isLoading ? null : _handleLogin, child: _isLoading ? const CircularProgressIndicator.adaptive() : const Text('Sign In')),
                      const SizedBox(height: 16),
                      Row(mainAxisAlignment: MainAxisAlignment.center, children: [Text('Don\'t have an account?'), TextButton(onPressed: () => context.go('/register'), child: const Text('Register'))]),
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
