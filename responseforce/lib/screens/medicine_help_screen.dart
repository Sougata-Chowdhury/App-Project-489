import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/firestore_service.dart';
import '../utils/request_type_mapper.dart';
import '../widgets/primary_button.dart';
import 'assistance_request_sent_screen.dart';

class MedicineHelpScreen extends StatefulWidget {
  const MedicineHelpScreen({super.key});

  @override
  State<MedicineHelpScreen> createState() => _MedicineHelpScreenState();
}

class _MedicineHelpScreenState extends State<MedicineHelpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _medicineName = TextEditingController();
  final _quantity = TextEditingController();
  final _pharmacy = TextEditingController();
  final _notes = TextEditingController();
  String _urgency = 'medium';
  bool _busy = false;

  @override
  void dispose() {
    _medicineName.dispose();
    _quantity.dispose();
    _pharmacy.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;

    setState(() => _busy = true);
    try {
      final service = context.read<FirestoreService>();
      final summary = '${_medicineName.text.trim()} (${_quantity.text.trim()})';

      final ref = await service.createAssistanceRequest(
        'MedicineHelp',
        summary: summary,
        urgency: _urgency,
        details: {
          'medicine_name': _medicineName.text.trim(),
          'quantity': _quantity.text.trim(),
          'pharmacy_or_area': _pharmacy.text.trim(),
          'notes': _notes.text.trim(),
        },
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => AssistanceRequestSentScreen(
            requestRef: ref,
            requestTypeLabel: friendlyRequestType('MedicineHelp'),
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
      appBar: AppBar(title: const Text('Medicine Help')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                _InfoBanner(
                  icon: Icons.medication_outlined,
                  text:
                      'Share exact medicine details so responders can prepare quickly.',
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _medicineName,
                          textInputAction: TextInputAction.next,
                          decoration: field(
                            'Medicine name',
                            hint: 'Paracetamol 500mg',
                            icon: Icons.healing_outlined,
                          ),
                          validator: (v) =>
                              (v ?? '').trim().isEmpty ? 'Required' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _quantity,
                          textInputAction: TextInputAction.next,
                          decoration: field(
                            'Quantity needed',
                            hint: '1 strip / 2 bottles',
                            icon: Icons.numbers,
                          ),
                          validator: (v) =>
                              (v ?? '').trim().isEmpty ? 'Required' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _pharmacy,
                          textInputAction: TextInputAction.next,
                          decoration: field(
                            'Preferred pharmacy / area',
                            hint: 'Optional',
                            icon: Icons.store_mall_directory_outlined,
                          ),
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
                        TextFormField(
                          controller: _notes,
                          maxLines: 3,
                          decoration: field(
                            'Additional notes',
                            hint: 'Allergies, preferred brand, etc.',
                            icon: Icons.notes_outlined,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                PrimaryButton(
                  label: 'Submit Medicine Request',
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
