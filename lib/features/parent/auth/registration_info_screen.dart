import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/providers/app_providers.dart';

class RegistrationInfoScreen extends ConsumerWidget {
  const RegistrationInfoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingEmail = ref.watch(authStateProvider).value?.email;
    return Scaffold(
      appBar: AppBar(title: const Text('Verify Your Email')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "We've sent a link to your email. Tap it to verify your account.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () async {
                  final email = pendingEmail;
                  if (email == null || email.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Email not available. Please open the link from your inbox.')),
                    );
                    return;
                  }
                  try {
                    await Supabase.instance.client.auth.resend(
                      type: OtpType.signup,
                      email: email,
                    );
                    // ignore: use_build_context_synchronously
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Verification email resent')),
                    );
                  } catch (e) {
                    // ignore: use_build_context_synchronously
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to resend: $e')),
                    );
                  }
                },
                child: const Text('Resend verification email'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
