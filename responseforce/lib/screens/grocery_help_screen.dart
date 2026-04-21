import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/firestore_service.dart';
import '../utils/request_type_mapper.dart';
import '../widgets/primary_button.dart';
import 'assistance_request_sent_screen.dart';

class GroceryHelpScreen extends StatefulWidget {
  const GroceryHelpScreen({super.key});

  @override
  State<GroceryHelpScreen> createState() => _GroceryHelpScreenState();
}

class _GroceryHelpScreenState extends State<GroceryHelpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _items = TextEditingController();
  final _deliveryNotes = TextEditingController();
  final _budget = TextEditingController();
  String _urgency = 'medium';
  bool _busy = false;

  @override
  void dispose() {
    _items.dispose();
    _deliveryNotes.dispose();
    _budget.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;

    setState(() => _busy = true);
    try {
      final items = _items.text.trim();
      final firstLine = items.split('\n').first.trim();
      final summary = firstLine.isEmpty ? 'Grocery request' : firstLine;
      final ref = await context
          .read<FirestoreService>()
          .createAssistanceRequest(
            'GroceryHelp',
            summary: summary,
            urgency: _urgency,
            details: {
              'items': items,
              'delivery_notes': _deliveryNotes.text.trim(),
              'budget': _budget.text.trim(),
            },
          );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => AssistanceRequestSentScreen(
            requestRef: ref,
            requestTypeLabel: friendlyRequestType('GroceryHelp'),
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
      appBar: AppBar(title: const Text('Grocery Help')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                const _InfoBanner(
                  icon: Icons.local_grocery_store_outlined,
                  text:
                      'Add your grocery list clearly so delivery can be arranged without delays.',
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _items,
                          maxLines: 5,
                          textInputAction: TextInputAction.newline,
                          decoration: field(
                            'Grocery items',
                            hint: 'Rice - 2kg\nMilk - 2 packets\nEggs - 12',
                            icon: Icons.list_alt_outlined,
                          ),
                          validator: (v) => (v ?? '').trim().isEmpty
                              ? 'Please add at least one item'
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
                        TextFormField(
                          controller: _budget,
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.next,
                          decoration: field(
                            'Approx budget',
                            hint: 'Optional',
                            icon: Icons.payments_outlined,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _deliveryNotes,
                          maxLines: 3,
                          decoration: field(
                            'Delivery notes',
                            hint: 'Gate code, landmark, preferred time',
                            icon: Icons.directions_outlined,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                PrimaryButton(
                  label: 'Submit Grocery Request',
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
