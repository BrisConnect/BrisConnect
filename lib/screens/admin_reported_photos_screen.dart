import 'package:flutter/material.dart';
import 'package:brisconnect/auth/app_user_role.dart';
import 'package:brisconnect/models/moderation_action.dart';
import 'package:brisconnect/models/visitor_photo.dart';
import 'package:brisconnect/services/admin_moderation_service.dart';
import 'package:brisconnect/services/admin_user_management_service.dart';
import 'package:brisconnect/services/photo_report_service.dart';
import 'package:brisconnect/services/visitor_photo_service.dart';
import 'package:brisconnect/theme/app_palette.dart';
import 'package:brisconnect/utils/admin_utils.dart';
import 'package:brisconnect/widgets/logo_app_bar_title.dart';
import 'package:brisconnect/widgets/role_guard.dart';

/// Admin screen for reviewing and moderating reported visitor photos.
class AdminReportedPhotosScreen extends StatefulWidget {
  final AdminModerationService? moderationService;
  final VisitorPhotoService? photoService;
  final AdminUserManagementService? userManagementService;
  final bool enforceRoleGuard;

  const AdminReportedPhotosScreen({
    super.key,
    this.moderationService,
    this.photoService,
    this.userManagementService,
    this.enforceRoleGuard = true,
  });

  @override
  State<AdminReportedPhotosScreen> createState() =>
      _AdminReportedPhotosScreenState();
}

class _AdminReportedPhotosScreenState
    extends State<AdminReportedPhotosScreen> {
  String _selectedStatusFilter = 'pending';
  String _selectedReasonFilter = 'all';
  String _selectedSeverityFilter = 'all';
  DateTime? _selectedDateFrom;
  DateTime? _selectedDateTo;
  late final AdminModerationService _moderationService;
  late final VisitorPhotoService _photoService;
  late final AdminUserManagementService _userManagementService;

  @override
  void initState() {
    super.initState();
    _moderationService = widget.moderationService ?? AdminModerationService();
    _photoService = widget.photoService ?? VisitorPhotoService();
    _userManagementService =
        widget.userManagementService ?? AdminUserManagementService();
  }

  List<PhotoReport> _applyLocalFilters(List<PhotoReport> reports) {
    return reports.where((report) {
      if (_selectedReasonFilter != 'all' && report.reason != _selectedReasonFilter) {
        return false;
      }
      if (_selectedSeverityFilter != 'all' &&
          report.severity != _selectedSeverityFilter) {
        return false;
      }
      final from = _selectedDateFrom;
      final to = _selectedDateTo;
      if (from != null && report.createdAt.isBefore(from)) return false;
      if (to != null && report.createdAt.isAfter(to.add(const Duration(days: 1)))) {
        return false;
      }
      return true;
    }).toList();
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final initial = isFrom ? _selectedDateFrom : _selectedDateTo;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial ?? DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
    );
    if (picked != null && mounted) {
      setState(() {
        if (isFrom) {
          _selectedDateFrom = picked;
        } else {
          _selectedDateTo = picked;
        }
      });
    }
  }

  void _clearDateFilters() {
    setState(() {
      _selectedDateFrom = null;
      _selectedDateTo = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final screen = Scaffold(
      backgroundColor: AppPalette.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const LogoAppBarTitle('Reported Photos'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Filter Reports',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppPalette.charcoal,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final status in const [
                      'pending',
                      'reviewing',
                      'resolved',
                      'dismissed',
                    ])
                      FilterChip(
                        label: Text(status[0].toUpperCase() + status.substring(1)),
                        selected: _selectedStatusFilter == status,
                        onSelected: (_) =>
                            setState(() => _selectedStatusFilter = status),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    DropdownButton<String>(
                      value: _selectedReasonFilter,
                      hint: const Text('Reason'),
                      items: [
                        const DropdownMenuItem(value: 'all', child: Text('All reasons')),
                        ...PhotoReportService.reportReasons.map(
                          (reason) => DropdownMenuItem(
                            value: reason,
                            child: Text(PhotoReportService.getReasonLabel(reason)),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) setState(() => _selectedReasonFilter = value);
                      },
                    ),
                    DropdownButton<String>(
                      value: _selectedSeverityFilter,
                      hint: const Text('Severity'),
                      items: [
                        const DropdownMenuItem(value: 'all', child: Text('All severities')),
                        ...PhotoReportService.reportSeverities.map(
                          (severity) => DropdownMenuItem(
                            value: severity,
                            child: Text(PhotoReportService.getSeverityLabel(severity)),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) setState(() => _selectedSeverityFilter = value);
                      },
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.calendar_today, size: 16),
                      label: Text(_selectedDateFrom == null
                          ? 'From date'
                          : 'From ${_formatDate(_selectedDateFrom!)}'),
                      onPressed: () => _pickDate(isFrom: true),
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.calendar_today, size: 16),
                      label: Text(_selectedDateTo == null
                          ? 'To date'
                          : 'To ${_formatDate(_selectedDateTo!)}'),
                      onPressed: () => _pickDate(isFrom: false),
                    ),
                    if (_selectedDateFrom != null || _selectedDateTo != null)
                      TextButton.icon(
                        onPressed: _clearDateFilters,
                        icon: const Icon(Icons.clear, size: 16),
                        label: const Text('Clear dates'),
                      ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<PhotoReport>>(
              stream: _moderationService.watchPhotoReportsByStatus(_selectedStatusFilter),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text('Error loading reports: ${snapshot.error}'),
                    ),
                  );
                }

                final reports = _applyLocalFilters(snapshot.data ?? []);
                if (reports.isEmpty) {
                  return Center(
                    child: Text(
                      'No $_selectedStatusFilter photo reports',
                      style: const TextStyle(color: AppPalette.charcoal),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: reports.length,
                  itemBuilder: (context, index) => _PhotoReportCard(
                    report: reports[index],
                    moderationService: _moderationService,
                    photoService: _photoService,
                    userManagementService: _userManagementService,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );

    if (widget.enforceRoleGuard) {
      return RoleGuard(
        allowedRoles: const {AppUserRole.admin},
        child: screen,
      );
    }
    return screen;
  }
}

String _formatDate(DateTime date) {
  return '${date.month}/${date.day}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
}

Color _statusColor(String status) {
  switch (status) {
    case 'resolved':
      return Colors.red;
    case 'dismissed':
      return Colors.grey;
    case 'reviewing':
      return Colors.orange;
    default:
      return AppPalette.ochre;
  }
}

class _PhotoReportCard extends StatefulWidget {
  final PhotoReport report;
  final AdminModerationService moderationService;
  final VisitorPhotoService photoService;
  final AdminUserManagementService userManagementService;

  const _PhotoReportCard({
    required this.report,
    required this.moderationService,
    required this.photoService,
    required this.userManagementService,
  });

  @override
  State<_PhotoReportCard> createState() => _PhotoReportCardState();
}

class _PhotoReportCardState extends State<_PhotoReportCard>
    with AdminScreenMixin<_PhotoReportCard> {
  VisitorPhoto? _photo;
  bool _loadingPhoto = true;

  @override
  void initState() {
    super.initState();
    widget.photoService.getPhoto(widget.report.photoId).then((photo) {
      if (mounted) {
        setState(() {
          _photo = photo;
          _loadingPhoto = false;
        });
      }
    });
  }

  Future<void> _moderate(ModerationDecision decision) async {
    if (isLoading) return;
    final adminEmail = requireAdminEmail();
    if (adminEmail == null) return;

    final reason = await AdminUtils.showReasonDialog(
      context,
      title: decision == ModerationDecision.dismiss
          ? 'Dismiss report'
          : 'Remove photo',
      hintText: decision == ModerationDecision.dismiss
          ? 'Reason for dismissing the report'
          : 'Reason for removing this photo',
      barrierDismissible: false,
    );
    if (reason == null || reason.trim().isEmpty) return;

    await runAdminAction(
      () => widget.moderationService.moderatePhotoReport(
        reportId: widget.report.id,
        decision: decision,
        adminEmail: adminEmail,
        reason: reason.trim(),
      ),
      success: decision == ModerationDecision.dismiss
          ? 'Report dismissed'
          : 'Photo removed (recoverable for 30 days)',
    );
  }

  Future<void> _warnUser() async {
    final adminEmail = requireAdminEmail();
    if (adminEmail == null) return;

    final reason = await AdminUtils.showReasonDialog(
      context,
      title: 'Warn reporter',
      hintText: 'Warning message to send the reporter',
      barrierDismissible: false,
    );
    if (reason == null || reason.trim().isEmpty) return;

    await runAdminAction(
      () => widget.moderationService.moderatePhotoReport(
        reportId: widget.report.id,
        decision: ModerationDecision.flag,
        adminEmail: adminEmail,
        reason: 'Warning issued: ${reason.trim()}',
      ),
      success: 'Warning recorded.',
    );
  }

  Future<void> _suspendReporter() async {
    final adminEmail = AdminUtils.currentAdminEmail;
    final confirmed = await AdminUtils.showConfirmDialog(
      context,
      title: 'Suspend reporter',
      content: 'Deactivate the account for ${widget.report.visitorEmail}?',
      confirmText: 'Suspend',
      confirmColor: Colors.red,
    );

    if (confirmed != true || !mounted) return;

    await runAdminAction(
      () async {
        await widget.userManagementService.deactivateUser(
          widget.report.visitorEmail,
          'visitor',
        );
        if (adminEmail != null && adminEmail.isNotEmpty) {
          await widget.moderationService.logUserSuspension(
            userEmail: widget.report.visitorEmail,
            adminEmail: adminEmail,
            reason: 'Suspended after reviewing photo report ${widget.report.id}',
            relatedContentType: ModeratedContentType.photo,
            relatedContentId: widget.report.photoId,
          );
        }
      },
      success: '${widget.report.visitorEmail} suspended.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppPalette.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppPalette.border),
      ),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: _loadingPhoto
                      ? const SizedBox(
                          width: 64,
                          height: 64,
                          child: Center(
                              child: CircularProgressIndicator(strokeWidth: 2)),
                        )
                      : (_photo == null
                          ? Container(
                              width: 64,
                              height: 64,
                              color: AppPalette.background,
                              child: const Icon(Icons.broken_image_outlined),
                            )
                          : Image.network(
                              _photo!.imageUrl,
                              width: 64,
                              height: 64,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                width: 64,
                                height: 64,
                                color: AppPalette.background,
                                child: const Icon(Icons.broken_image_outlined),
                              ),
                            )),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Photo ID: ${widget.report.photoId}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Reported by: ${widget.report.visitorEmail}',
                        style: const TextStyle(fontSize: 12, color: AppPalette.charcoal),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (_photo?.isDeleted == true) ...[
                        const SizedBox(height: 4),
                        const Text(
                          'Already removed (recoverable for 30 days)',
                          style: TextStyle(fontSize: 12, color: Colors.red),
                        ),
                      ],
                    ],
                  ),
                ),
                Chip(
                  label: Text(
                    widget.report.status.toUpperCase(),
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  backgroundColor: _statusColor(widget.report.status).withValues(alpha: 0.2),
                  side: BorderSide(color: _statusColor(widget.report.status)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Reason: ${PhotoReportService.getReasonLabel(widget.report.reason)}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              'Severity: ${PhotoReportService.getSeverityLabel(widget.report.severity)}',
              style: const TextStyle(fontSize: 12, color: AppPalette.charcoal),
            ),
            if (widget.report.comments != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppPalette.background,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  widget.report.comments!,
                  style: const TextStyle(fontSize: 13, color: AppPalette.charcoal),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              'Reported: ${_formatDate(widget.report.createdAt)}',
              style: const TextStyle(fontSize: 11, color: AppPalette.charcoal),
            ),
            if (widget.report.reviewedAt != null)
              Text(
                'Reviewed: ${_formatDate(widget.report.reviewedAt!)}',
                style: const TextStyle(fontSize: 11, color: AppPalette.charcoal),
              ),
            const SizedBox(height: 12),
            if (widget.report.status == 'pending') ...[
              Wrap(
                spacing: 8,
                alignment: WrapAlignment.end,
                children: [
                  TextButton(
                    onPressed: isLoading ? null : () => _moderate(ModerationDecision.dismiss),
                    child: const Text('Dismiss'),
                  ),
                  TextButton(
                    onPressed: isLoading ? null : _warnUser,
                    child: const Text('Warn'),
                  ),
                  OutlinedButton(
                    onPressed: isLoading ? null : _suspendReporter,
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.red.shade700),
                    child: const Text('Suspend'),
                  ),
                  ElevatedButton(
                    onPressed: isLoading ? null : () => _moderate(ModerationDecision.delete),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade700,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Remove Photo'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
