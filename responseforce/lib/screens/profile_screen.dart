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

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      await context.read<FirestoreService>().updateElderProfile(
            fullName: _fullName.text,
            phoneNumber: _phone.text,
            age: _age.text,
            bloodGroup: _blood.text,
            medicalSummary: _medical.text,
            emergencyContactNumber: _emergency.text,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile saved.')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = context.read<FirestoreService>();

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: SafeArea(
        child: StreamBuilder(
          stream: service.elderProfileStream(),
          builder: (context, snapshot) {
            final data = snapshot.data?.data();
            if (data != null && _fullName.text.isEmpty) {
              _fullName.text = (data['fullName'] ?? '').toString();
              _phone.text = (data['phoneNumber'] ?? '').toString();
              _age.text = (data['age'] ?? '').toString();
              _blood.text = (data['bloodGroup'] ?? '').toString();
              _medical.text = (data['medicalSummary'] ?? '').toString();
              _emergency.text = (data['emergencyContactNumber'] ?? '').toString();
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    controller: _fullName,
                    decoration: const InputDecoration(labelText: 'Full name'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'Phone number'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _age,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Age'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _blood,
                    decoration: const InputDecoration(labelText: 'Blood group'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _medical,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'Medical summary'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _emergency,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'Emergency contact number'),
                  ),
                  const SizedBox(height: 16),
                  PrimaryButton(label: 'Save Profile', isBusy: _busy, onPressed: _save),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
