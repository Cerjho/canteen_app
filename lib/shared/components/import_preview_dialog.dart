import 'package:flutter/material.dart';

/// Import Preview Dialog - shows parsed data before confirming import
class ImportPreviewDialog extends StatelessWidget {
  final List<Map<String, dynamic>> data;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;
  final String title;

  const ImportPreviewDialog({
    super.key,
    required this.data,
    required this.onConfirm,
    required this.onCancel,
    this.title = 'Import Preview',
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return AlertDialog(
        title: Text(title),
        content: const Text('No valid data found in the file.'),
        actions: [
          TextButton(
            onPressed: onCancel,
            child: const Text('Close'),
          ),
        ],
      );
    }

    // Get all unique keys from the data
    final Set<String> allKeys = {};
    for (var row in data) {
      allKeys.addAll(row.keys);
    }
    final List<String> headers = allKeys.toList();

    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.8,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Row(
              children: [
                Icon(
                  Icons.preview,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: onCancel,
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Info Text
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Found ${data.length} row(s). Review the data below and click "Confirm Import" to proceed.',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Data Table
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.vertical,
                    child: DataTable(
                      border: TableBorder.all(
                        color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                      ),
                      headingRowColor: WidgetStateProperty.all(
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                      ),
                      columns: headers
                          .map(
                            (header) => DataColumn(
                              label: Text(
                                header.toUpperCase(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                      rows: data.asMap().entries.map((entry) {
                        final index = entry.key;
                        final row = entry.value;
                        
                        return DataRow(
                          color: WidgetStateProperty.all(
                            index.isEven
                                ? Colors.transparent
                                : Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest
                                    .withValues(alpha: 0.3),
                          ),
                          cells: headers
                              .map(
                                (header) => DataCell(
                                  Text(row[header]?.toString() ?? ''),
                                ),
                              )
                              .toList(),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: onCancel,
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: onConfirm,
                  icon: const Icon(Icons.check),
                  label: const Text('Confirm Import'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
