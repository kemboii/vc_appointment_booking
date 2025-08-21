import 'package:flutter/material.dart';

class ReasonSelectionWidget extends StatefulWidget {
  final Function(String) onReasonSelected;
  final String role; // 'Student', 'Staff Member', or 'Parent'

  const ReasonSelectionWidget(
      {super.key, required this.onReasonSelected, required this.role});

  @override
  State<ReasonSelectionWidget> createState() => _ReasonSelectionWidgetState();
}

class _ReasonSelectionWidgetState extends State<ReasonSelectionWidget> {
  String? _selectedReason;
  final TextEditingController _otherReasonController = TextEditingController();

  List<String> _reasonsForRole(String role) {
    switch (role) {
      case 'Student':
        return [
          'Academic Consultation',
          'Financial Aid Discussion',
          'Registration/Units',
          'Accommodation',
          'Disciplinary Meeting',
          'General Inquiry',
          'Other',
        ];
      case 'Staff Member':
        return [
          'Departmental Matters',
          'HR/Contracts',
          'Budget/Procurement',
          'Project Update',
          'General Inquiry',
          'Other',
        ];
      case 'Parent':
        return [
          'Fee Discussion',
          'Student Performance',
          'Welfare/Accommodation',
          'Disciplinary Concern',
          'General Inquiry',
          'Other',
        ];
      default:
        return [
          'General Inquiry',
          'Other',
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final reasons = _reasonsForRole(widget.role);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        DropdownButtonFormField<String>(
          value: _selectedReason,
          hint: const Text('Select a reason for your visit'),
          decoration: const InputDecoration(
            labelText: 'Reason for Visit',
            border: OutlineInputBorder(),
          ),
          onChanged: (value) {
            setState(() {
              _selectedReason = value;
              if (_selectedReason != 'Other' && _selectedReason != null) {
                widget.onReasonSelected(_selectedReason!);
              }
            });
          },
          items: reasons.map((String reason) {
            return DropdownMenuItem<String>(
              value: reason,
              child: Text(reason),
            );
          }).toList(),
        ),
        if (_selectedReason == 'Other') ...[
          const SizedBox(height: 16),
          TextField(
            controller: _otherReasonController,
            decoration: const InputDecoration(
              labelText: 'Please specify your reason',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
            onChanged: (value) {
              widget.onReasonSelected(value);
            },
          ),
        ],
      ],
    );
  }
}
