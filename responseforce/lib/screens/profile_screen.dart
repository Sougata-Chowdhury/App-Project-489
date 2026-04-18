import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/firestore_service.dart';
import '../widgets/primary_button.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  final _fullName = TextEditingController();
  final _phone = TextEditingController();
  final _age = TextEditingController();
  final _blood = TextEditingController();
  final _medical = TextEditingController();
  final _emergency = TextEditingController();

  bool _busy = false;

  @override
  void dispose() {
    _fullName.dispose();
    _phone.dispose();
    _age.dispose();
    _blood.dispose();
    _medical.dispose();
    _emergency.dispose();
    super.dispose();
  }

  String? _requiredName(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'Full name is required';
    if (s.length < 3) return 'Enter at least 3 characters';
    return null;
  }

  String? _requiredPhone(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'Phone number is required';
    if (!RegExp(r'^\+?[0-9]{10,15}$').hasMatch(s)) {
      return 'Use 10-15 digits (optional +)';
    }
    return null;
  }

  String? _optionalPhone(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return null;
    if (!RegExp(r'^\+?[0-9]{10,15}$').hasMatch(s)) {
      return 'Use 10-15 digits (optional +)';
    }
    return null;
  }

  String? _optionalAge(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return null;
    final n = int.tryParse(s);
    if (n == null) return 'Age must be a number';
    if (n < 1 || n > 120) return 'Age should be between 1 and 120';
    return null;
  }

  Future<void> _save() async {
    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;

    setState(() => _busy = true);
    try {
      await context.read<FirestoreService>().updateElderProfile(
        fullName: _fullName.text.trim(),
        phoneNumber: _phone.text.trim(),
        age: _age.text.trim(),
        bloodGroup: _blood.text.trim(),
        medicalSummary: _medical.text.trim(),
        emergencyContactNumber: _emergency.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully.')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = context.read<FirestoreService>();
    final cs = Theme.of(context).colorScheme;

    InputDecoration decorate(String label, {String? hint, IconData? icon}) {
      return InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: icon == null ? null : Icon(icon),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: SafeArea(
        child: StreamBuilder(
          stream: service.elderProfileStream(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                _fullName.text.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }

            final data = snapshot.data?.data();
            if (data != null && _fullName.text.isEmpty) {
              _fullName.text = (data['fullName'] ?? data['full_name'] ?? '')
                  .toString();
              _phone.text = (data['phoneNumber'] ?? '').toString();
              _age.text = (data['age'] ?? data['age_int'] ?? '').toString();
              _blood.text = (data['bloodGroup'] ?? data['blood_group'] ?? '')
                  .toString();
              _medical.text =
                  (data['medicalSummary'] ?? data['medical_conditions'] ?? '')
                      .toString();
              _emergency.text =
                  (data['emergencyContactNumber'] ??
                          data['emergency_contact_number'] ??
                          '')
                      .toString();
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest.withValues(
                          alpha: 0.35,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 26,
                            backgroundColor: cs.primaryContainer,
                            child: Icon(
                              Icons.person,
                              color: cs.onPrimaryContainer,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Keep your profile complete so Admin can respond faster in emergencies.',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _fullName,
                              textInputAction: TextInputAction.next,
                              decoration: decorate(
                                'Full name',
                                icon: Icons.badge_outlined,
                              ),
                              validator: _requiredName,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _phone,
                              keyboardType: TextInputType.phone,
                              textInputAction: TextInputAction.next,
                              decoration: decorate(
                                'Phone number',
                                hint: '+8801XXXXXXXXX',
                                icon: Icons.phone_outlined,
                              ),
                              validator: _requiredPhone,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _emergency,
                              keyboardType: TextInputType.phone,
                              textInputAction: TextInputAction.next,
                              decoration: decorate(
                                'Emergency contact number',
                                hint: 'Optional but recommended',
                                icon: Icons.contact_phone_outlined,
                              ),
                              validator: _optionalPhone,
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _age,
                                    keyboardType: TextInputType.number,
                                    textInputAction: TextInputAction.next,
                                    decoration: decorate(
                                      'Age',
                                      icon: Icons.cake_outlined,
                                    ),
                                    validator: _optionalAge,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextFormField(
                                    controller: _blood,
                                    textInputAction: TextInputAction.next,
                                    decoration: decorate(
                                      'Blood group',
                                      hint: 'A+, O-, etc',
                                      icon: Icons.bloodtype_outlined,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _medical,
                              maxLines: 4,
                              textInputAction: TextInputAction.newline,
                              decoration: decorate(
                                'Medical summary',
                                hint: 'Allergies, conditions, medications',
                                icon: Icons.medical_information_outlined,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    PrimaryButton(
                      label: 'Save Profile',
                      isBusy: _busy,
                      onPressed: _save,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
