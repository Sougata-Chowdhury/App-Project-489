import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/firestore_service.dart';

class AdminAnalyticsScreen extends StatefulWidget {
  const AdminAnalyticsScreen({super.key, required this.service});

  final FirestoreService service;

  @override
  State<AdminAnalyticsScreen> createState() => _AdminAnalyticsScreenState();
}

class _AdminAnalyticsScreenState extends State<AdminAnalyticsScreen> {
  late Future<AdminSosAnalytics> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.service.getAdminSosAnalytics();
  }

  Future<void> _reload() async {
    setState(() {
      _future = widget.service.getAdminSosAnalytics();
    });
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AdminSosAnalytics>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Could not load analytics right now.',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text('${snap.error}'),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _reload,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }

        final analytics = snap.data;
        if (analytics == null) {
          return const Center(child: Text('No analytics data available.'));
        }

        final openCases = analytics.pendingCount + analytics.inProgressCount;
        final totalRatioBase = analytics.resolvedCount + openCases;
        final resolvedRatio = totalRatioBase == 0
            ? 0.0
            : analytics.resolvedCount / totalRatioBase;
        final pendingRatio = totalRatioBase == 0
            ? 0.0
            : openCases / totalRatioBase;

        return RefreshIndicator(
          onRefresh: _reload,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(12),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      const CircleAvatar(child: Icon(Icons.analytics_outlined)),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'SOS Analytics Dashboard',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                            Text('Weekly and monthly emergency intelligence'),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Refresh',
                        onPressed: _reload,
                        icon: const Icon(Icons.refresh),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              LayoutBuilder(
                builder: (context, constraints) {
                  final twoCols = constraints.maxWidth >= 560;
                  final cardWidth = twoCols
                      ? (constraints.maxWidth - 8) / 2
                      : constraints.maxWidth;
                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      SizedBox(
                        width: cardWidth,
                        child: _KpiCard(
                          title: 'SOS This Week',
                          value: '${analytics.weekTotal}',
                          icon: Icons.calendar_view_week_outlined,
                          tint: Colors.red,
                        ),
                      ),
                      SizedBox(
                        width: cardWidth,
                        child: _KpiCard(
                          title: 'SOS This Month',
                          value: '${analytics.monthTotal}',
                          icon: Icons.calendar_month_outlined,
                          tint: Colors.deepOrange,
                        ),
                      ),
                      SizedBox(
                        width: cardWidth,
                        child: _KpiCard(
                          title: 'Avg Response Time',
                          value: analytics.avgResponseMinutes == null
                              ? '—'
                              : '${analytics.avgResponseMinutes!.toStringAsFixed(1)} min',
                          icon: Icons.timer_outlined,
                          tint: Colors.blue,
                        ),
                      ),
                      SizedBox(
                        width: cardWidth,
                        child: _KpiCard(
                          title: 'Repeat Emergency Users',
                          value: '${analytics.repeatEmergencyUsers}',
                          icon: Icons.warning_amber_outlined,
                          tint: Colors.purple,
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 10),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Resolved vs Pending Ratio (This Month)',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: LinearProgressIndicator(
                                value: resolvedRatio,
                                minHeight: 10,
                                backgroundColor: Colors.red.withValues(
                                  alpha: 0.15,
                                ),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.green.shade700,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            '${(resolvedRatio * 100).toStringAsFixed(0)}% resolved',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _RatioChip(
                            label: 'Resolved: ${analytics.resolvedCount}',
                            color: Colors.green.shade700,
                          ),
                          _RatioChip(
                            label: 'Open: $openCases',
                            color: Colors.red.shade700,
                          ),
                          _RatioChip(
                            label:
                                '${(pendingRatio * 100).toStringAsFixed(0)}% pending/open',
                            color: Colors.orange.shade700,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'High-Risk & Repeat Emergency Insights (Last 30 Days)',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 10),
                      if (analytics.highRiskUsers.isEmpty)
                        const Text(
                          'No high-risk users detected in the last 30 days.',
                        ),
                      ...analytics.highRiskUsers.map(
                        (user) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Theme.of(
                                  context,
                                ).colorScheme.outlineVariant,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        user.elderName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ),
                                    Chip(
                                      visualDensity: VisualDensity.compact,
                                      label: Text('Risk ${user.riskScore}'),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    _RatioChip(
                                      label: 'SOS: ${user.totalSos}',
                                      color: Colors.red.shade700,
                                    ),
                                    _RatioChip(
                                      label:
                                          'Unresolved: ${user.unresolvedSos}',
                                      color: Colors.orange.shade700,
                                    ),
                                    if (user.lastIncidentAt != null)
                                      _RatioChip(
                                        label:
                                            'Last: ${DateFormat.yMMMd().add_jm().format(user.lastIncidentAt!)}',
                                        color: Colors.blueGrey.shade700,
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.tint,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: tint.withValues(alpha: 0.12),
              child: Icon(icon, color: tint),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 20,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RatioChip extends StatelessWidget {
  const _RatioChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Chip(
      visualDensity: VisualDensity.compact,
      label: Text(label),
      backgroundColor: color.withValues(alpha: 0.12),
      side: BorderSide(color: color.withValues(alpha: 0.24)),
      labelStyle: TextStyle(color: color, fontWeight: FontWeight.w700),
    );
  }
}
