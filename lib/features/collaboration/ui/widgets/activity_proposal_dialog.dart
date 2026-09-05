import 'package:flutter/material.dart';

class ActivityProposalDialog extends StatefulWidget {
  const ActivityProposalDialog({
    required this.onPropose,
    required this.onCreatePoll,
    this.proposalMode = true,
    this.allowPoll = true,
    super.key,
  });

  final Future<void> Function(String title, String? location) onPropose;
  final Future<void> Function(String question, List<String> options)
  onCreatePoll;
  final bool proposalMode;
  final bool allowPoll;

  @override
  State<ActivityProposalDialog> createState() => _ActivityProposalDialogState();
}

class _ActivityProposalDialogState extends State<ActivityProposalDialog> {
  final _titleController = TextEditingController();
  final _locationController = TextEditingController();
  final _optionOneController = TextEditingController();
  final _optionTwoController = TextEditingController();
  bool _creatingPoll = false;
  bool _submitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    _optionOneController.dispose();
    _optionTwoController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter an activity title or poll question.'),
        ),
      );
      return;
    }
    if (_creatingPoll &&
        (_optionOneController.text.trim().isEmpty ||
            _optionTwoController.text.trim().isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter both voting options.')),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      if (_creatingPoll) {
        await widget.onCreatePoll(title, [
          _optionOneController.text,
          _optionTwoController.text,
        ]);
      } else {
        await widget.onPropose(title, _locationController.text.trim());
      }
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      _creatingPoll
          ? 'Create activity poll'
          : widget.proposalMode
          ? 'Propose activity'
          : 'Add activity',
    ),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _titleController,
            decoration: InputDecoration(
              labelText: _creatingPoll ? 'Poll question' : 'Activity title',
            ),
          ),
          if (!_creatingPoll)
            TextField(
              controller: _locationController,
              decoration: const InputDecoration(
                labelText: 'Location (optional)',
              ),
            ),
          if (_creatingPoll) ...[
            TextField(
              controller: _optionOneController,
              decoration: const InputDecoration(labelText: 'Option 1'),
            ),
            TextField(
              controller: _optionTwoController,
              decoration: const InputDecoration(labelText: 'Option 2'),
            ),
          ],
          const SizedBox(height: 12),
          if (widget.allowPoll)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _creatingPoll,
              onChanged: _submitting
                  ? null
                  : (value) => setState(() => _creatingPoll = value),
              title: const Text('Create a voting poll instead'),
            ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: _submitting ? null : () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: _submitting ? null : _submit,
        child: Text(
          _submitting
              ? 'Saving...'
              : _creatingPoll
              ? 'Create poll'
              : widget.proposalMode
              ? 'Submit proposal'
              : 'Add activity',
        ),
      ),
    ],
  );
}
