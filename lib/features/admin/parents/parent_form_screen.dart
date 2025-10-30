import 'package:flutter/material.dart';

class ParentFormScreen extends StatelessWidget {
  final String? parentId;
  
  const ParentFormScreen({super.key, this.parentId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(parentId == null ? 'Add Parent' : 'Edit Parent')),
      body: const Center(child: Text('Parent Form - Coming Soon')),
    );
  }
}
