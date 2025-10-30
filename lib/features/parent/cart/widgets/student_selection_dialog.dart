import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:canteen_app/core/models/student.dart';
import 'package:canteen_app/core/utils/format_utils.dart';
import 'package:canteen_app/core/providers/app_providers.dart';
// ignore_for_file: deprecated_member_use

/// Displays a dialog to select a linked student. Returns the selected Student or null if cancelled.
Future<List<Student>?> showStudentSelectionDialog(BuildContext context, WidgetRef ref, {required double orderTotal, bool allowMultiple = false}) {
  final studentsAsync = ref.read(parentStudentsProvider);
  final students = studentsAsync.value ?? [];

  if (students.isEmpty) {
    return showDialog<List<Student>?>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('No Linked Students'),
        content: const Text('Please link a student to your account before placing orders.'),
        actions: [
          FilledButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
        ],
      ),
    );
  }

  Student? singleSelected = students.length == 1 ? students.first : null;
  final selectedIds = <String>{};

  if (singleSelected != null && allowMultiple) selectedIds.add(singleSelected.id);

  final parent = ref.read(currentParentProvider).value;
  final parentBalance = parent?.balance ?? 0.0;

  return showDialog<List<Student>?>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(allowMultiple ? 'Select Students' : 'Select Student'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ...students.map((student) {
                // Students are imported into system; payment is charged to parent wallet
                final hasSufficient = parentBalance >= orderTotal;

                final isSelectedSingle = (!allowMultiple) ? (singleSelected?.id == student.id) : selectedIds.contains(student.id);

                return Card(
                  margin: EdgeInsets.only(bottom: 8.h),
                  color: isSelectedSingle ? Theme.of(context).colorScheme.primaryContainer : null,
                  child: InkWell(
                    onTap: () => setState(() {
                      if (allowMultiple) {
                        if (selectedIds.contains(student.id)) {
                          selectedIds.remove(student.id);
                        } else {
                          selectedIds.add(student.id);
                        }
                      } else {
                        singleSelected = student;
                      }
                    }),
                    child: Padding(
                      padding: EdgeInsets.all(12.w),
                      child: Row(
                        children: [
                          if (allowMultiple)
                            Checkbox(
                              value: selectedIds.contains(student.id),
                              onChanged: (v) => setState(() => v == true ? selectedIds.add(student.id) : selectedIds.remove(student.id)),
                            )
                          else
                            Radio<String>(
                              value: student.id,
                              groupValue: singleSelected?.id,
                              onChanged: (_) => setState(() => singleSelected = student),
                            ),
                          CircleAvatar(
                            radius: 32.r,
                            backgroundImage: student.photoUrl != null ? NetworkImage(student.photoUrl!) : null,
                            child: student.photoUrl == null ? Text(student.firstName[0].toUpperCase(), style: TextStyle(fontSize: 24.sp)) : null,
                          ),
                          SizedBox(width: 12.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(student.fullName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.sp)),
                                SizedBox(height: 4.h),
                                Text(student.grade, style: TextStyle(fontSize: 12.sp, color: Colors.grey[600])),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              // Show parent wallet balance since payments are charged to parent
                              Text(FormatUtils.currency(parentBalance), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.sp, color: hasSufficient ? Colors.green[700] : Colors.red[700])),
                              if (!hasSufficient) ...[
                                SizedBox(height: 2.h),
                                Text('Parent wallet insufficient', style: TextStyle(fontSize: 10.sp, color: Colors.red[700])),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
              const Divider(),
              SizedBox(height: 8.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Order Total:', style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold)),
                  Text(FormatUtils.currency(orderTotal), style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (allowMultiple) {
                final selected = students.where((s) => selectedIds.contains(s.id)).toList();
                Navigator.pop(context, selected);
              } else {
                if (singleSelected == null) return;
                Navigator.pop(context, [singleSelected!]);
              }
            },
            child: const Text('Place Order'),
          ),
        ],
      ),
    ),
  );
}
