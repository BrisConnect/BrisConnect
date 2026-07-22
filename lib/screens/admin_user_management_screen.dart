import 'package:flutter/material.dart';
import 'package:brisconnect/services/admin_user_management_service.dart';
import 'package:brisconnect/services/local_email_notification_service.dart';
import 'package:brisconnect/services/sms_notification_service.dart';
import 'package:brisconnect/theme/app_palette.dart';

class AdminUserManagementScreen extends StatefulWidget {
  AdminUserManagementScreen({
    super.key,
    AdminUserManagementService? userManagementService,
    LocalEmailNotificationService? localEmailNotificationService,
    SmsNotificationService? smsNotificationService,
    this.enforceRoleGuard = true,
  }) : userManagementService =
           userManagementService ?? AdminUserManagementService(),
       localEmailNotificationService =
           localEmailNotificationService ?? LocalEmailNotificationService(),
       smsNotificationService = smsNotificationService ?? SmsNotificationService();

  final AdminUserManagementService userManagementService;
  final LocalEmailNotificationService localEmailNotificationService;
  final SmsNotificationService smsNotificationService;
  final bool enforceRoleGuard;

  @override
  State<AdminUserManagementScreen> createState() =>
      _AdminUserManagementScreenState();
}

class _AdminUserManagementScreenState extends State<AdminUserManagementScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedRoleFilter = 'all'; // 'all', 'visitor', 'local', 'admin'
  String _selectedStatusFilter = 'all'; // 'all', 'active', 'inactive', 'pending', 'approved', 'rejected'
  String _sortOrder = 'newest'; // 'newest', 'oldest', 'name'
  bool _isLoading = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _confirmAndDeactivateUser(
    AdminUserRecord user,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Deactivate User Account'),
        content: Text(
          'Are you sure you want to deactivate ${user.name} (${user.email})?\n\nDisabled users will not be able to log in.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() => _isLoading = true);
    try {
      await widget.userManagementService.deactivateUser(user.email, user.role);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${user.name} has been deactivated.'),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deactivating user: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
      debugPrint('[AdminUserManagement] Deactivation error: $error');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _reactivateUser(AdminUserRecord user) async {
    setState(() => _isLoading = true);
    try {
      await widget.userManagementService.reactivateUser(user.email, user.role);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${user.name} has been reactivated.'),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error reactivating user: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
      debugPrint('[AdminUserManagement] Reactivation error: $error');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _approveLocalUser(AdminUserRecord user) async {
    setState(() => _isLoading = true);
    try {
      await widget.userManagementService.approveLocalUser(user.email);
      try {
        await widget.localEmailNotificationService.queueAccountReviewEmail(
          recipientEmail: user.email,
          businessName: user.name,
          approved: true,
        );
      } catch (_) {
        // Keep approval successful even when email queueing fails.
      }

      try {
        if (user.phone != null && user.phone!.trim().isNotEmpty) {
          await widget.smsNotificationService.queueLocalAccountReviewSms(
            recipientPhone: user.phone!,
            businessName: user.name,
            approved: true,
          );
        }
      } catch (_) {
        // Keep approval successful even when SMS queueing fails.
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${user.name} approved successfully.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error approving user: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
      debugPrint('[AdminUserManagement] Approval error: $error');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _rejectLocalUser(AdminUserRecord user) async {
    setState(() => _isLoading = true);
    try {
      await widget.userManagementService.rejectLocalUser(user.email);
      try {
        await widget.localEmailNotificationService.queueAccountReviewEmail(
          recipientEmail: user.email,
          businessName: user.name,
          approved: false,
        );
      } catch (_) {
        // Keep rejection successful even when email queueing fails.
      }

      try {
        if (user.phone != null && user.phone!.trim().isNotEmpty) {
          await widget.smsNotificationService.queueLocalAccountReviewSms(
            recipientPhone: user.phone!,
            businessName: user.name,
            approved: false,
          );
        }
      } catch (_) {
        // Keep rejection successful even when SMS queueing fails.
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${user.name} was rejected.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error rejecting user: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
      debugPrint('[AdminUserManagement] Rejection error: $error');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<AdminUserRecord> _filterUsers(List<AdminUserRecord> users) {
    var filtered = users;

    // Filter by role
    if (_selectedRoleFilter != 'all') {
      filtered = filtered
          .where((u) => u.role.toLowerCase() == _selectedRoleFilter)
          .toList();
    }

    // Filter by status
    if (_selectedStatusFilter == 'active') {
      filtered = filtered.where((u) => u.active).toList();
    } else if (_selectedStatusFilter == 'inactive') {
      filtered = filtered.where((u) => !u.active).toList();
    } else if (_selectedStatusFilter == 'pending') {
      filtered = filtered
          .where((u) => u.role == 'local' && (u.approvalStatus ?? 'pending') == 'pending')
          .toList();
    } else if (_selectedStatusFilter == 'approved') {
      filtered = filtered
          .where((u) => u.role == 'local' && (u.approvalStatus ?? 'pending') == 'approved')
          .toList();
    } else if (_selectedStatusFilter == 'rejected') {
      filtered = filtered
          .where((u) => u.role == 'local' && (u.approvalStatus ?? 'pending') == 'rejected')
          .toList();
    }

    // Sort
    if (_sortOrder == 'newest') {
      filtered.sort((a, b) => (b.createdAt ?? DateTime(2000)).compareTo(a.createdAt ?? DateTime(2000)));
    } else if (_sortOrder == 'oldest') {
      filtered.sort((a, b) => (a.createdAt ?? DateTime(2000)).compareTo(b.createdAt ?? DateTime(2000)));
    } else {
      filtered.sort((a, b) => a.name.compareTo(b.name));
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CustomScrollView(
        physics: const ClampingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 16,
                left: 16,
                right: 16,
                bottom: 12,
              ),
              child: Row(
                children: [
                  Image.asset('assets/Brisconnect New.jpg', height: 44),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'User Management',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            shadows: [
                              Shadow(
                                offset: Offset(0, 1),
                                blurRadius: 6,
                                color: Colors.black45,
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Search and manage users',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Colors.white70,
                            shadows: [
                              Shadow(
                                offset: Offset(0, 1),
                                blurRadius: 4,
                                color: Colors.black38,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Search bar
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: AppPalette.surface.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Search by name or email...',
                    hintStyle: TextStyle(
                      color: AppPalette.mutedText,
                      fontWeight: FontWeight.w500,
                    ),
                    prefixIcon: const Icon(Icons.search_rounded,
                        color: AppPalette.mutedText),
                    suffixIcon: const Icon(Icons.mic_rounded,
                        color: AppPalette.mutedText),
                    border: InputBorder.none,
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 16)),

          // Filter by Role label
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: const Text(
                'Filter by Role',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  shadows: [
                    Shadow(
                      offset: Offset(0, 1),
                      blurRadius: 4,
                      color: Colors.black38,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 8)),

          // Role filter chips
          SliverToBoxAdapter(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _FilterChipStyled(
                    icon: Icons.check_circle_rounded,
                    label: 'All Roles',
                    selected: _selectedRoleFilter == 'all',
                    onTap: () => setState(() => _selectedRoleFilter = 'all'),
                  ),
                  const SizedBox(width: 8),
                  _FilterChipStyled(
                    icon: Icons.groups_rounded,
                    label: 'Visitors',
                    selected: _selectedRoleFilter == 'visitor',
                    onTap: () => setState(() => _selectedRoleFilter = 'visitor'),
                  ),
                  const SizedBox(width: 8),
                  _FilterChipStyled(
                    icon: Icons.place_rounded,
                    label: 'Locals',
                    selected: _selectedRoleFilter == 'local',
                    onTap: () => setState(() => _selectedRoleFilter = 'local'),
                  ),
                ],
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 14)),

          // Filter by Status label
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: const Text(
                'Filter by Status',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  shadows: [
                    Shadow(
                      offset: Offset(0, 1),
                      blurRadius: 4,
                      color: Colors.black38,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 8)),

          // Status filter chips
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _FilterChipStyled(
                    icon: Icons.shield_rounded,
                    label: 'Admins',
                    selected: _selectedRoleFilter == 'admin',
                    onTap: () => setState(() => _selectedRoleFilter = _selectedRoleFilter == 'admin' ? 'all' : 'admin'),
                  ),
                  _FilterChipStyled(
                    icon: null,
                    dotColor: Colors.green,
                    label: 'Active',
                    selected: _selectedStatusFilter == 'active',
                    onTap: () => setState(() => _selectedStatusFilter = _selectedStatusFilter == 'active' ? 'all' : 'active'),
                  ),
                  _FilterChipStyled(
                    icon: Icons.radio_button_unchecked,
                    label: 'Inactive',
                    selected: _selectedStatusFilter == 'inactive',
                    onTap: () => setState(() => _selectedStatusFilter = _selectedStatusFilter == 'inactive' ? 'all' : 'inactive'),
                  ),
                  _FilterChipStyled(
                    icon: Icons.schedule_rounded,
                    label: 'Pending Approval',
                    selected: _selectedStatusFilter == 'pending',
                    onTap: () => setState(() => _selectedStatusFilter = _selectedStatusFilter == 'pending' ? 'all' : 'pending'),
                  ),
                  _FilterChipStyled(
                    icon: Icons.check_circle_rounded,
                    iconColor: Colors.green,
                    label: 'Approved Locals',
                    selected: _selectedStatusFilter == 'approved',
                    onTap: () => setState(() => _selectedStatusFilter = _selectedStatusFilter == 'approved' ? 'all' : 'approved'),
                  ),
                  _FilterChipStyled(
                    icon: Icons.close_rounded,
                    iconColor: Colors.red,
                    label: 'Rejected Locals',
                    selected: _selectedStatusFilter == 'rejected',
                    onTap: () => setState(() => _selectedStatusFilter = _selectedStatusFilter == 'rejected' ? 'all' : 'rejected'),
                  ),
                ],
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 14)),

          // User list
          StreamBuilder<List<AdminUserRecord>>(
            stream: widget.userManagementService.watchAllUsers(
              searchQuery: _searchController.text,
            ),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              if (snapshot.hasError) {
                return SliverFillRemaining(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Error loading users: ${snapshot.error}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                );
              }

              final allUsers = snapshot.data ?? [];
              if (allUsers.isEmpty) {
                return const SliverFillRemaining(
                  child: Center(
                    child: Text('No users found',
                        style: TextStyle(color: Colors.white)),
                  ),
                );
              }

              final filteredUsers = _filterUsers(allUsers);

              return SliverMainAxisGroup(
                slivers: [
                  // Count + Sort row
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Text(
                            '${filteredUsers.length}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppPalette.ochre,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Users Found',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                          ),
                          const Spacer(),
                          PopupMenuButton<String>(
                            onSelected: (value) => setState(() => _sortOrder = value),
                            itemBuilder: (ctx) => [
                              const PopupMenuItem(value: 'newest', child: Text('Newest')),
                              const PopupMenuItem(value: 'oldest', child: Text('Oldest')),
                              const PopupMenuItem(value: 'name', child: Text('Name')),
                            ],
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Sort: ',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.white.withValues(alpha: 0.8),
                                  ),
                                ),
                                Text(
                                  _sortOrder == 'newest'
                                      ? 'Newest'
                                      : _sortOrder == 'oldest'
                                          ? 'Oldest'
                                          : 'Name',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    fontStyle: FontStyle.italic,
                                    color: Colors.white.withValues(alpha: 0.9),
                                  ),
                                ),
                                Icon(Icons.arrow_drop_down,
                                    color: Colors.white.withValues(alpha: 0.8),
                                    size: 20),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 10)),

                  if (filteredUsers.isEmpty)
                    const SliverFillRemaining(
                      child: Center(
                        child: Text('No users match your filters',
                            style: TextStyle(color: Colors.white)),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverList.builder(
                        itemCount: filteredUsers.length,
                        itemBuilder: (context, index) {
                          final user = filteredUsers[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _UserCard(
                              user: user,
                              onDeactivate: _isLoading
                                  ? null
                                  : () => _confirmAndDeactivateUser(user),
                              onReactivate: _isLoading
                                  ? null
                                  : () => _reactivateUser(user),
                              onApprove: _isLoading
                                  ? null
                                  : () => _approveLocalUser(user),
                              onReject: _isLoading
                                  ? null
                                  : () => _rejectLocalUser(user),
                            ),
                          );
                        },
                      ),
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: 80)),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

// ── Styled filter chip ──
class _FilterChipStyled extends StatelessWidget {
  final IconData? icon;
  final Color? iconColor;
  final Color? dotColor;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChipStyled({
    this.icon,
    this.iconColor,
    this.dotColor,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? AppPalette.ochre
              : Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? AppPalette.ochre
                : Colors.white.withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (dotColor != null) ...[
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: selected ? Colors.white : dotColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
            ] else if (icon != null) ...[
              Icon(icon, size: 16,
                  color: selected ? Colors.white : (iconColor ?? Colors.white)),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Redesigned user card ──
class _UserCard extends StatelessWidget {
  final AdminUserRecord user;
  final VoidCallback? onDeactivate;
  final VoidCallback? onReactivate;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;

  const _UserCard({
    required this.user,
    this.onDeactivate,
    this.onReactivate,
    this.onApprove,
    this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppPalette.surface.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppPalette.border.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Orange avatar
              CircleAvatar(
                radius: 24,
                backgroundColor: AppPalette.ochre.withValues(alpha: 0.15),
                child: Text(
                  user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppPalette.ochre,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Name + role badge + email + created
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            user.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppPalette.charcoal,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppPalette.charcoal,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            user.role.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (user.role == 'local') ...[
                      const SizedBox(height: 4),
                      Text(
                        'Approval: ${_approvalLabel(user.approvalStatus)}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _approvalColor(user.approvalStatus),
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.mail_outline_rounded,
                            size: 14, color: AppPalette.mutedText),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            user.email,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppPalette.charcoal,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.calendar_today_rounded,
                            size: 14, color: AppPalette.mutedText),
                        const SizedBox(width: 4),
                        Text(
                          'Created: ${_formatDateTime(user.createdAt ?? DateTime.now())}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppPalette.mutedText,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Status badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: user.active
                      ? Colors.green.shade50
                      : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: user.active
                        ? Colors.green.shade300
                        : Colors.red.shade300,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: user.active
                            ? Colors.green.shade600
                            : Colors.red.shade600,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      user.active ? 'Active' : 'Inactive',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: user.active
                            ? Colors.green.shade700
                            : Colors.red.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Action buttons
          const SizedBox(height: 12),

          if (user.role == 'local' &&
              (user.approvalStatus ?? 'pending') == 'pending')
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: onApprove,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('Approve Local'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: onReject,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('Reject Local'),
                  ),
                ),
              ],
            ),

          if (user.role == 'local' &&
              (user.approvalStatus ?? 'pending') == 'pending')
            const SizedBox(height: 8),

          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton(
                onPressed: user.active ? onDeactivate : onReactivate,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppPalette.ochre,
                  side: const BorderSide(color: AppPalette.ochre),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 8),
                ),
                child: Text(user.active ? 'View' : 'Reactivate'),
              ),
              const SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: AppPalette.border),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded,
                      color: AppPalette.charcoal, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                  onSelected: (value) {
                    if (value == 'deactivate') {
                      onDeactivate?.call();
                    } else if (value == 'reactivate') {
                      onReactivate?.call();
                    }
                  },
                  itemBuilder: (ctx) => [
                    if (user.active)
                      const PopupMenuItem(
                        value: 'deactivate',
                        child: Text('Deactivate Account'),
                      )
                    else
                      const PopupMenuItem(
                        value: 'reactivate',
                        child: Text('Reactivate Account'),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _approvalLabel(String? approvalStatus) {
    switch ((approvalStatus ?? 'pending').toLowerCase()) {
      case 'approved':
        return 'Approved';
      case 'rejected':
        return 'Rejected';
      default:
        return 'Pending';
    }
  }

  Color _approvalColor(String? approvalStatus) {
    switch ((approvalStatus ?? 'pending').toLowerCase()) {
      case 'approved':
        return Colors.green.shade700;
      case 'rejected':
        return Colors.red.shade700;
      default:
        return Colors.orange.shade700;
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inDays == 0) {
      if (diff.inHours == 0) {
        return '${diff.inMinutes} minutes ago';
      }
      return '${diff.inHours} hours ago';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} days ago';
    } else {
      return '${dateTime.month}/${dateTime.day}/${dateTime.year}';
    }
  }
}
