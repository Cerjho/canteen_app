import 'package:flutter/material.dart';

class AdminAccessDeniedScreen extends StatelessWidget {
  const AdminAccessDeniedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.block, size: 64, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 16),
            Text('Access Denied', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Text('You do not have permission to view this page.', textAlign: TextAlign.center),
            ),
          ],
        ),
      ),
    );
  }
}
