import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../services/firestore_service.dart';
import '../utils/request_type_mapper.dart';
import '../widgets/primary_button.dart';
import 'assistance_request_sent_screen.dart';

class GeneralAssistanceScreen extends StatefulWidget {
  const GeneralAssistanceScreen({super.key});

  @override
  State<GeneralAssistanceScreen> createState() =>
      _GeneralAssistanceScreenState();
}

class _GeneralAssistanceScreenState extends State<GeneralAssistanceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _description = TextEditingController();
  final _extraNotes = TextEditingController();
  String _category = 'Home Care';
  String _urgency = 'medium';
  DateTime? _preferredTime;
  bool _busy = false;

  @override
  void dispose() {
    _description.dispose();
    _extraNotes.dispose();
    super.dispose();
  }

  Future<void> _pickPreferredTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      firstDate: now,
      lastDate: now.add(const Duration(days: 30)),
      initialDate: _preferredTime ?? now,
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_preferredTime ?? now),
    );
    if (time == null) return;

    setState(() {
      _preferredTime = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _submit() async {
    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;

    setState(() => _busy = true);
    try {
      final description = _description.text.trim();
      final summary = '$_category: $description';
      final ref = await context
          .read<FirestoreService>()
          .createAssistanceRequest(
            'GeneralAssistance',
            summary: summary,
            urgency: _urgency,
            preferredTime: _preferredTime,
            details: {
              'category': _category,
              'description': description,
              'preferred_time': _preferredTime == null
                  ? ''
                  : DateFormat.yMMMd().add_jm().format(_preferredTime!),
              'notes': _extraNotes.text.trim(),
            },
          );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => AssistanceRequestSentScreen(
            requestRef: ref,
            requestTypeLabel: friendlyRequestType('GeneralAssistance'),
            requestSummary: summary,
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    InputDecoration field(String label, {String? hint, IconData? icon}) {
      return InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: icon == null ? null : Icon(icon),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('General Assistance')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                const _InfoBanner(
                  icon: Icons.support_agent_outlined,
                  text:
                      'Describe your situation clearly so the right support can be assigned quickly.',
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      children: [
                        DropdownButtonFormField<String>(
                          initialValue: _category,
                          decoration: field(
                            'Category',
                            icon: Icons.category_outlined,
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'Home Care',
                              child: Text('Home Care'),
                            ),
                            DropdownMenuItem(
                              value: 'Mobility Support',
                              child: Text('Mobility Support'),
                            ),
                            DropdownMenuItem(
                              value: 'Companionship',
                              child: Text('Companionship'),
                            ),
                            DropdownMenuItem(
                              value: 'Technical Help',
                              child: Text('Technical Help'),
                            ),
                            DropdownMenuItem(
                              value: 'Other',
                              child: Text('Other'),
                            ),
                          ],
                          onChanged: (v) =>
                              setState(() => _category = v ?? 'Other'),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _description,
                          maxLines: 4,
                          decoration: field(
                            'Description',
                            hint: 'What help do you need?',
                            icon: Icons.description_outlined,
                          ),
                          validator: (v) => (v ?? '').trim().length < 8
                              ? 'Please provide a little more detail'
                              : null,
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: _urgency,
                          decoration: field(
                            'Urgency',
                            icon: Icons.priority_high,
                          ),
                          items: const [
                            DropdownMenuItem(value: 'low', child: Text('Low')),
                            DropdownMenuItem(
                              value: 'medium',
                              child: Text('Medium'),
                            ),
                            DropdownMenuItem(
                              value: 'high',
                              child: Text('High'),
                            ),
                            DropdownMenuItem(
                              value: 'urgent',
                              child: Text('Urgent'),
                            ),
                          ],
                          onChanged: (v) =>
                              setState(() => _urgency = v ?? 'medium'),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: _pickPreferredTime,
                          icon: const Icon(Icons.schedule_outlined),
                          label: Text(
                            _preferredTime == null
                                ? 'Pick preferred time (optional)'
                                : DateFormat.yMMMd().add_jm().format(
                                    _preferredTime!,
                                  ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _extraNotes,
                          maxLines: 3,
                          decoration: field(
                            'Additional notes',
                            hint: 'Any special instruction',
                            icon: Icons.notes_outlined,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                PrimaryButton(
                  label: 'Submit Assistance Request',
                  isBusy: _busy,
                  onPressed: _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: cs.primaryContainer,
            child: Icon(icon, color: cs.onPrimaryContainer),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
