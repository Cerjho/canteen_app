import 'package:flutter/material.dart';

/// Loading indicator widget with optional text
class LoadingIndicator extends StatelessWidget {
  final String? text;
  
  const LoadingIndicator({super.key, this.text});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          if (text != null) ...[
            const SizedBox(height: 16),
            Text(
              text!,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ],
      ),
    );
  }
}
