import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../services/firestore_service.dart';
import '../services/local_reminder_service.dart';
import '../widgets/primary_button.dart';

class MedicationReminderScreen extends StatefulWidget {
  const MedicationReminderScreen({super.key});

  @override
  State<MedicationReminderScreen> createState() =>
      _MedicationReminderScreenState();
}

class _MedicationReminderScreenState extends State<MedicationReminderScreen> {
  final _formKey = GlobalKey<FormState>();
  final _medicineCtrl = TextEditingController();
  final _dosageCtrl = TextEditingController();
  final _instructionsCtrl = TextEditingController();

  final Set<TimeOfDay> _times = <TimeOfDay>{};
  bool _isActive = true;
  bool _isSaving = false;
  bool _isSyncingMissed = false;
  bool _isPermissionLoading = false;
  bool _isRequestingPermission = false;
  ReminderPermissionStatus? _permissionStatus;

  String? _editingRoutineId;
  List<String> _previousReminderTimes = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncOverdueMissed();
      _refreshReminderPermissionStatus();
    });
  }

  @override
  void dispose() {
    _medicineCtrl.dispose();
    _dosageCtrl.dispose();
    _instructionsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final service = context.read<FirestoreService>();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Medication & Reminders'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Routines'),
              Tab(text: "Today's Doses"),
            ],
          ),
        ),
        body: TabBarView(
          children: [_buildRoutinesTab(service), _buildTodayTab(service)],
        ),
      ),
    );
  }

  Widget _buildRoutinesTab(FirestoreService service) {
    final reminderService = context.read<LocalReminderService>();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildPermissionCard(reminderService),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _editingRoutineId == null
                        ? 'Create medication routine'
                        : 'Edit medication routine',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _medicineCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Medicine name',
                      hintText: 'e.g. Amlodipine',
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Medicine name is required';
                      }
                      if (v.trim().length < 2) {
                        return 'Enter a valid medicine name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _dosageCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Dosage (optional)',
                      hintText: 'e.g. 5mg, 1 tablet',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _instructionsCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Instructions (optional)',
                      hintText: 'e.g. After breakfast',
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Reminder times',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _isSaving ? null : _pickTime,
                        icon: const Icon(Icons.add_alarm),
                        label: const Text('Add time'),
                      ),
                    ],
                  ),
                  if (_times.isEmpty)
                    Text(
                      'Add at least one reminder time.',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  if (_times.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _sortedTimes()
                          .map(
                            (t) => InputChip(
                              label: Text(t.format(context)),
                              onDeleted: _isSaving
                                  ? null
                                  : () => setState(() {
                                      _times.remove(t);
                                    }),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                  const SizedBox(height: 10),
                  SwitchListTile.adaptive(
                    value: _isActive,
                    onChanged: _isSaving
                        ? null
                        : (value) => setState(() => _isActive = value),
                    title: const Text('Routine active'),
                    subtitle: const Text(
                      'Active routines trigger reminders every day.',
                    ),
                    contentPadding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 12),
                  PrimaryButton(
                    label: _editingRoutineId == null
                        ? 'Save routine'
                        : 'Update routine',
                    isBusy: _isSaving,
                    onPressed: () => _saveRoutine(service),
                  ),
                  if (_editingRoutineId != null) ...[
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: _isSaving ? null : _resetForm,
                      child: const Text('Cancel editing'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Your routines',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: service.elderMedicationRoutinesStream(),
          builder: (context, snap) {
            final docs = [...(snap.data?.docs ?? const [])]
              ..sort((a, b) {
                final at = (a.data()['createdAt'] as Timestamp?)?.toDate();
                final bt = (b.data()['createdAt'] as Timestamp?)?.toDate();
                return (bt ?? DateTime.fromMillisecondsSinceEpoch(0)).compareTo(
                  at ?? DateTime.fromMillisecondsSinceEpoch(0),
                );
              });

            if (docs.isEmpty) {
              return const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No medication routines yet.'),
                ),
              );
            }

            return Column(
              children: docs.map((d) => _routineCard(d, service)).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildPermissionCard(LocalReminderService reminderService) {
    final status = _permissionStatus;
    final hasIssue = status != null && !status.allGranted;

    if (!hasIssue && !_isPermissionLoading) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.errorContainer.withValues(alpha: 0.42),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enable reminder permissions',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            if (_isPermissionLoading)
              const LinearProgressIndicator(minHeight: 3)
            else
              Text(
                'Reminders need Notification and Alarm permission. Use Enable permissions first, then open app settings if Android still blocks it.',
                style: theme.textTheme.bodyMedium,
              ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: _isRequestingPermission
                      ? null
                      : () => _requestReminderPermissions(reminderService),
                  icon: const Icon(Icons.notifications_active_outlined),
                  label: Text(
                    _isRequestingPermission
                        ? 'Requesting...'
                        : 'Enable permissions',
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _isRequestingPermission
                      ? null
                      : _openAppPermissionSettings,
                  icon: const Icon(Icons.settings_outlined),
                  label: const Text('Open settings'),
                ),
              ],
            ),
            if (status != null) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(
                    label: Text(
                      status.notificationsEnabled
                          ? 'Notifications: On'
                          : 'Notifications: Off',
                    ),
                  ),
                  Chip(
                    label: Text(
                      status.exactAlarmsEnabled ? 'Alarms: On' : 'Alarms: Off',
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _routineCard(
    DocumentSnapshot<Map<String, dynamic>> doc,
    FirestoreService service,
  ) {
    final data = doc.data() ?? <String, dynamic>{};
    final medicineName = (data['medicineName'] ?? '').toString();
    final dosage = (data['dosage'] ?? '').toString();
    final instructions = (data['instructions'] ?? '').toString();
    final times =
        ((data['reminderTimes'] as List?) ?? const [])
            .map((e) => e.toString())
            .where((e) => e.trim().isNotEmpty)
            .toList()
          ..sort();
    final isActive = (data['isActive'] ?? true) == true;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    medicineName.isEmpty ? 'Medicine' : medicineName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Chip(
                  label: Text(isActive ? 'Active' : 'Paused'),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            if (dosage.trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('Dosage: $dosage'),
            ],
            if (instructions.trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('Notes: $instructions'),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: times
                  .map((time) => Chip(label: Text(_displayTime(time))))
                  .toList(),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _startEdit(doc),
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Edit'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _deleteRoutine(service, doc.id, times),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Delete'),
                  ),
                ),
              ],
            ),
            SwitchListTile.adaptive(
              value: isActive,
              onChanged: (value) =>
                  _toggleRoutine(service, doc.id, data, value),
              title: const Text('Enable reminders'),
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTodayTab(FirestoreService service) {
    final startOfDay = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: service.elderMedicationRoutinesStream(),
      builder: (context, routineSnap) {
        final routines =
            routineSnap.data?.docs ??
            const <QueryDocumentSnapshot<Map<String, dynamic>>>[];
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: service.elderMedicationLogsStream(from: startOfDay),
          builder: (context, logSnap) {
            final logs =
                logSnap.data?.docs ??
                const <QueryDocumentSnapshot<Map<String, dynamic>>>[];
            final now = DateTime.now();
            final doses = _buildTodayDoses(routines, logs, now);

            return RefreshIndicator(
              onRefresh: _syncOverdueMissed,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Mark your medicines as Taken or Missed. Overdue doses are auto-marked.',
                            ),
                          ),
                          const SizedBox(width: 8),
                          _isSyncingMissed
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : IconButton(
                                  tooltip: 'Sync overdue',
                                  onPressed: _syncOverdueMissed,
                                  icon: const Icon(Icons.sync),
                                ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (doses.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('No active doses scheduled for today.'),
                      ),
                    ),
                  ...doses.map((dose) => _doseCard(service, dose)),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _doseCard(FirestoreService service, _DoseEntry dose) {
    final statusColor = switch (dose.status) {
      'taken' => Colors.green.shade700,
      'missed' => Colors.red.shade700,
      _ => Colors.blueGrey.shade700,
    };
    final statusLabel = switch (dose.status) {
      'taken' => 'Taken',
      'missed' => 'Missed',
      _ => 'Pending',
    };
    final canMark = dose.status == null;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    dose.medicineName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ),
                Chip(
                  label: Text(statusLabel),
                  backgroundColor: statusColor.withValues(alpha: 0.14),
                  side: BorderSide(color: statusColor.withValues(alpha: 0.24)),
                  labelStyle: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            if (dose.dosage.isNotEmpty) Text('Dosage: ${dose.dosage}'),
            const SizedBox(height: 4),
            Text('Scheduled: ${DateFormat.jm().format(dose.scheduledAt)}'),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: canMark
                        ? () => _markDose(service, dose, 'taken')
                        : null,
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('Taken'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: canMark
                        ? () => _markDose(service, dose, 'missed')
                        : null,
                    icon: const Icon(Icons.cancel_outlined),
                    label: const Text('Missed'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      helpText: 'Select reminder time',
    );
    if (picked == null) return;

    setState(() {
      _times.add(picked);
    });
  }

  Future<void> _saveRoutine(FirestoreService service) async {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) return;
    if (_times.isEmpty) {
      setState(() {});
      return;
    }

    final reminderService = context.read<LocalReminderService>();
    final reminderTimes = _sortedTimes().map(_toTimeKey).toList();
    final medicineName = _medicineCtrl.text.trim();
    final dosage = _dosageCtrl.text.trim();
    final instructions = _instructionsCtrl.text.trim();

    setState(() => _isSaving = true);
    try {
      if (_editingRoutineId == null) {
        final ref = await service.createMedicationRoutine(
          medicineName: medicineName,
          dosage: dosage.isEmpty ? null : dosage,
          instructions: instructions.isEmpty ? null : instructions,
          reminderTimes: reminderTimes,
          isActive: _isActive,
        );
        await reminderService.replaceRoutineReminders(
          routineId: ref.id,
          medicineName: medicineName,
          dosage: dosage,
          reminderTimes: reminderTimes,
          isActive: _isActive,
        );
      } else {
        await service.updateMedicationRoutine(
          routineId: _editingRoutineId!,
          medicineName: medicineName,
          dosage: dosage.isEmpty ? null : dosage,
          instructions: instructions.isEmpty ? null : instructions,
          reminderTimes: reminderTimes,
          isActive: _isActive,
        );
        await reminderService.replaceRoutineReminders(
          routineId: _editingRoutineId!,
          medicineName: medicineName,
          dosage: dosage,
          reminderTimes: reminderTimes,
          oldReminderTimes: _previousReminderTimes,
          isActive: _isActive,
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _editingRoutineId == null ? 'Routine saved.' : 'Routine updated.',
          ),
        ),
      );
      _resetForm();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not save routine: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _startEdit(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    final times = ((data['reminderTimes'] as List?) ?? const [])
        .map((e) => e.toString())
        .where((e) => e.trim().isNotEmpty)
        .toList();

    final parsedTimes = <TimeOfDay>{};
    for (final time in times) {
      final parsed = _timeOfDayFromKey(time);
      if (parsed != null) parsedTimes.add(parsed);
    }

    setState(() {
      _editingRoutineId = doc.id;
      _previousReminderTimes = times;
      _medicineCtrl.text = (data['medicineName'] ?? '').toString();
      _dosageCtrl.text = (data['dosage'] ?? '').toString();
      _instructionsCtrl.text = (data['instructions'] ?? '').toString();
      _isActive = (data['isActive'] ?? true) == true;
      _times
        ..clear()
        ..addAll(parsedTimes);
    });
  }

  Future<void> _toggleRoutine(
    FirestoreService service,
    String routineId,
    Map<String, dynamic> data,
    bool isActive,
  ) async {
    final reminderService = context.read<LocalReminderService>();
    final medicineName = (data['medicineName'] ?? '').toString();
    final dosage = (data['dosage'] ?? '').toString();
    final times = ((data['reminderTimes'] as List?) ?? const [])
        .map((e) => e.toString())
        .toList();

    try {
      await service.updateMedicationRoutine(
        routineId: routineId,
        medicineName: medicineName,
        dosage: dosage,
        instructions: (data['instructions'] ?? '').toString(),
        reminderTimes: times,
        isActive: isActive,
      );
      await reminderService.replaceRoutineReminders(
        routineId: routineId,
        medicineName: medicineName,
        dosage: dosage,
        reminderTimes: times,
        oldReminderTimes: times,
        isActive: isActive,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isActive ? 'Routine activated.' : 'Routine paused.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not update routine: $e')));
    }
  }

  Future<void> _deleteRoutine(
    FirestoreService service,
    String routineId,
    List<String> reminderTimes,
  ) async {
    final reminderService = context.read<LocalReminderService>();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete routine'),
        content: const Text(
          'This routine and future reminders will be removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await reminderService.cancelRoutineReminders(
        routineId: routineId,
        reminderTimes: reminderTimes,
      );
      await service.deleteMedicationRoutine(routineId);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Routine deleted.')));
      if (_editingRoutineId == routineId) {
        _resetForm();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not delete routine: $e')));
    }
  }

  Future<void> _markDose(
    FirestoreService service,
    _DoseEntry dose,
    String status,
  ) async {
    try {
      await service.setMedicationDoseStatus(
        routineId: dose.routineId,
        scheduledAt: dose.scheduledAt,
        status: status,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${dose.medicineName} marked as ${status == 'taken' ? 'Taken' : 'Missed'}',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not update dose: $e')));
    }
  }

  Future<void> _syncOverdueMissed() async {
    if (_isSyncingMissed) return;
    setState(() => _isSyncingMissed = true);
    try {
      await context
          .read<FirestoreService>()
          .markOverdueMedicationLogsAsMissed();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Sync failed: $e')));
    } finally {
      if (mounted) setState(() => _isSyncingMissed = false);
    }
  }

  Future<void> _refreshReminderPermissionStatus() async {
    if (_isPermissionLoading) return;
    setState(() => _isPermissionLoading = true);
    try {
      final status = await context
          .read<LocalReminderService>()
          .getPermissionStatus();
      if (!mounted) return;
      setState(() => _permissionStatus = status);
    } finally {
      if (mounted) setState(() => _isPermissionLoading = false);
    }
  }

  Future<void> _requestReminderPermissions(
    LocalReminderService reminderService,
  ) async {
    if (_isRequestingPermission) return;
    setState(() => _isRequestingPermission = true);
    try {
      final status = await reminderService.requestPermissions();
      if (!mounted) return;
      setState(() => _permissionStatus = status);
      final message = status.allGranted
          ? 'Reminder permissions enabled.'
          : 'Some permissions are still blocked. Open settings to allow them.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not request permission: $e')),
      );
    } finally {
      if (mounted) setState(() => _isRequestingPermission = false);
    }
  }

  Future<void> _openAppPermissionSettings() async {
    await openAppSettings();
    await _refreshReminderPermissionStatus();
  }

  List<_DoseEntry> _buildTodayDoses(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> routines,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> logs,
    DateTime now,
  ) {
    final logMap = <String, String>{};
    for (final log in logs) {
      final data = log.data();
      final routineId = (data['routineId'] ?? '').toString();
      final ts = (data['scheduledAt'] as Timestamp?)?.toDate();
      final status = (data['status'] ?? '').toString();
      if (routineId.isEmpty || ts == null || status.isEmpty) continue;
      logMap['$routineId|${_timeKey(ts)}'] = status;
    }

    final today = DateTime(now.year, now.month, now.day);
    final doses = <_DoseEntry>[];

    for (final routine in routines) {
      final data = routine.data();
      if ((data['isActive'] ?? true) != true) continue;
      final medicineName = (data['medicineName'] ?? '').toString();
      final dosage = (data['dosage'] ?? '').toString();
      final times = ((data['reminderTimes'] as List?) ?? const [])
          .map((e) => e.toString())
          .where((e) => e.trim().isNotEmpty)
          .toList();

      for (final time in times) {
        final parsed = _timeOfDayFromKey(time);
        if (parsed == null) continue;
        final scheduled = DateTime(
          today.year,
          today.month,
          today.day,
          parsed.hour,
          parsed.minute,
        );
        doses.add(
          _DoseEntry(
            routineId: routine.id,
            medicineName: medicineName,
            dosage: dosage,
            scheduledAt: scheduled,
            status: logMap['${routine.id}|${_timeKey(scheduled)}'],
          ),
        );
      }
    }

    doses.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    return doses;
  }

  List<TimeOfDay> _sortedTimes() {
    final out = _times.toList();
    out.sort((a, b) {
      final aMinutes = a.hour * 60 + a.minute;
      final bMinutes = b.hour * 60 + b.minute;
      return aMinutes.compareTo(bMinutes);
    });
    return out;
  }

  void _resetForm() {
    setState(() {
      _editingRoutineId = null;
      _previousReminderTimes = const [];
      _isActive = true;
      _times.clear();
      _medicineCtrl.clear();
      _dosageCtrl.clear();
      _instructionsCtrl.clear();
    });
  }

  String _toTimeKey(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  String _displayTime(String raw) {
    final parsed = _timeOfDayFromKey(raw);
    if (parsed == null) return raw;
    final now = DateTime.now();
    final dt = DateTime(
      now.year,
      now.month,
      now.day,
      parsed.hour,
      parsed.minute,
    );
    return DateFormat.jm().format(dt);
  }

  TimeOfDay? _timeOfDayFromKey(String raw) {
    final parts = raw.split(':');
    if (parts.length != 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
    return TimeOfDay(hour: hour, minute: minute);
  }

  String _timeKey(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _DoseEntry {
  _DoseEntry({
    required this.routineId,
    required this.medicineName,
    required this.dosage,
    required this.scheduledAt,
    required this.status,
  });

  final String routineId;
  final String medicineName;
  final String dosage;
  final DateTime scheduledAt;
  final String? status;
}
