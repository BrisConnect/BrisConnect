import 'package:flutter/material.dart';
import 'package:brisconnect/services/notification_health_service.dart';
import 'package:brisconnect/theme/app_palette.dart';

/// Screen that displays the availability status of business-owner
/// notification services, driven by synthetic health checks.
class NotificationHealthScreen extends StatefulWidget {
  final NotificationHealthService? service;

  const NotificationHealthScreen({super.key, this.service});

  @override
  State<NotificationHealthScreen> createState() => _NotificationHealthScreenState();
}

class _NotificationHealthScreenState extends State<NotificationHealthScreen> {
  late NotificationHealthService _service;
  NotificationHealthResult? _latest;
  List<NotificationHealthResult> _history = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? NotificationHealthService();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final result = await _service.checkHealth();
    try {
      _history = await _service.watchRecentChecks(limit: 100).first;
    } catch (e) {
      _history = [];
    }
    if (!mounted) return;
    setState(() {
      _latest = result;
      _loading = false;
      _error = result.isHealthy ? null : result.message;
    });
  }

  String _formatPercent(double? value) {
    if (value == null) return '—';
    return '${value.toStringAsFixed(2)}%';
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '—';
    final local = date.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day/$month $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final availability = NotificationHealthService.calculateAvailability(_history);

    return Scaffold(
      backgroundColor: AppPalette.background,
      appBar: AppBar(
        title: const Text('Notification Service Health'),
        backgroundColor: AppPalette.ochre,
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppPalette.ochre,
        backgroundColor: AppPalette.surface,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ListView(
            children: [
              _buildStatusCard(),
              const SizedBox(height: 16),
              _buildMetricCard('Availability (last 100 checks)', _formatPercent(availability)),
              const SizedBox(height: 16),
              _buildHistorySection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    final healthy = _latest?.isHealthy ?? false;
    final statusColor = healthy ? Colors.green[400] : Colors.red[400];
    final statusText = _loading
        ? 'Checking...'
        : healthy
            ? 'Healthy'
            : 'Degraded or unavailable';

    return Semantics(
      liveRegion: true,
      child: Card(
        color: AppPalette.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Current status',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppPalette.charcoal,
                    ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    healthy ? Icons.check_circle : Icons.error,
                    color: statusColor,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    statusText,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              if (_latest != null) ...[
                const SizedBox(height: 12),
                Text(
                  'Firestore: ${_latest!.firestoreReachable ? "reachable" : "unreachable"}\n'
                  'FCM: ${_latest!.fcmReachable ? "reachable" : "unreachable"}\n'
                  'Latency: ${_latest!.latencyMs} ms\n'
                  'Checked: ${_formatDate(_latest!.checkedAt)}',
                  style: const TextStyle(color: AppPalette.mutedText),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: const TextStyle(color: Colors.redAccent),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCard(String label, String value) {
    return Card(
      color: AppPalette.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(color: AppPalette.mutedText),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: AppPalette.charcoal,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent checks',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppPalette.charcoal,
              ),
        ),
        const SizedBox(height: 8),
        StreamBuilder<List<NotificationHealthResult>>(
          stream: _service.watchRecentChecks(limit: 20),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting && _history.isEmpty) {
              return const Center(
                child: CircularProgressIndicator(color: AppPalette.ochre),
              );
            }
            final checks = snapshot.data ?? _history;
            _history = checks;

            if (checks.isEmpty) {
              return const Text(
                'No health-check records yet.',
                style: TextStyle(color: AppPalette.mutedText),
              );
            }

            return Column(
              children: checks.map((check) {
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    check.isHealthy ? Icons.check_circle : Icons.error,
                    color: check.isHealthy ? Colors.green[400] : Colors.red[400],
                  ),
                  title: Text(
                    check.status.toUpperCase(),
                    style: TextStyle(
                      color: AppPalette.charcoal,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    'Firestore ${check.firestoreReachable ? "OK" : "FAIL"} · '
                    'FCM ${check.fcmReachable ? "OK" : "FAIL"} · '
                    '${check.latencyMs} ms',
                    style: const TextStyle(color: AppPalette.mutedText),
                  ),
                  trailing: Text(
                    _formatDate(check.checkedAt),
                    style: const TextStyle(color: AppPalette.mutedText),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}
