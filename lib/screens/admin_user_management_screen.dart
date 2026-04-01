import 'package:flutter/material.dart';
import 'package:brisconnect/services/admin_user_management_service.dart';
import 'package:brisconnect/theme/app_palette.dart';
import 'package:brisconnect/widgets/logo_app_bar_title.dart';

class AdminUserManagementScreen extends StatefulWidget {
  AdminUserManagementScreen({
    super.key,
    AdminUserManagementService? userManagementService,
    this.enforceRoleGuard = true,
  }) : userManagementService =
           userManagementService ?? AdminUserManagementService();

  final AdminUserManagementService userManagementService;
  final bool enforceRoleGuard;

  @override
  State<AdminUserManagementScreen> createState() =>
      _AdminUserManagementScreenState();
}

class _AdminUserManagementScreenState extends State<AdminUserManagementScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedRoleFilter = 'all'; // 'all', 'visitor', 'local', 'admin'
  String _selectedStatusFilter = 'all'; // 'all', 'active', 'inactive'
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
    }

    // Sort by name
    filtered.sort((a, b) => a.name.compareTo(b.name));

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.background,
      appBar: AppBar(
        title: const LogoAppBarTitle('User Management'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Search and Manage Users',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppPalette.charcoal,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Search by name or email',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    FilterChip(
                      label: const Text('All Roles'),
                      selected: _selectedRoleFilter == 'all',
                      onSelected: (selected) {
                        setState(() {
                          _selectedRoleFilter = selected ? 'all' : 'all';
                        });
                      },
                    ),
                    FilterChip(
                      label: const Text('Visitors'),
                      selected: _selectedRoleFilter == 'visitor',
                      onSelected: (selected) {
                        setState(() {
                          _selectedRoleFilter =
                              selected ? 'visitor' : 'all';
                        });
                      },
                    ),
                    FilterChip(
                      label: const Text('Locals'),
                      selected: _selectedRoleFilter == 'local',
                      onSelected: (selected) {
                        setState(() {
                          _selectedRoleFilter = selected ? 'local' : 'all';
                        });
                      },
                    ),
                    FilterChip(
                      label: const Text('Admins'),
                      selected: _selectedRoleFilter == 'admin',
                      onSelected: (selected) {
                        setState(() {
                          _selectedRoleFilter = selected ? 'admin' : 'all';
                        });
                      },
                    ),
                    FilterChip(
                      label: const Text('Active'),
                      selected: _selectedStatusFilter == 'active',
                      onSelected: (selected) {
                        setState(() {
                          _selectedStatusFilter =
                              selected ? 'active' : 'all';
                        });
                      },
                    ),
                    FilterChip(
                      label: const Text('Inactive'),
                      selected: _selectedStatusFilter == 'inactive',
                      onSelected: (selected) {
                        setState(() {
                          _selectedStatusFilter =
                              selected ? 'inactive' : 'all';
                        });
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<AdminUserRecord>>(
              stream: widget.userManagementService.watchAllUsers(
                searchQuery: _searchController.text,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Error loading users: ${snapshot.error}',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                final allUsers = snapshot.data ?? [];
                if (allUsers.isEmpty) {
                  return const Center(
                    child: Text('No users found'),
                  );
                }

                final filteredUsers =
                    _filterUsers(allUsers);

                if (filteredUsers.isEmpty) {
                  return const Center(
                    child: Text('No users match your filters'),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredUsers.length,
                  itemBuilder: (context, index) {
                    final user = filteredUsers[index];
                    return _UserCard(
                      user: user,
                      onDeactivate: _isLoading
                          ? null
                          : () => _confirmAndDeactivateUser(user),
                      onReactivate: _isLoading
                          ? null
                          : () => _reactivateUser(user),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  final AdminUserRecord user;
  final VoidCallback? onDeactivate;
  final VoidCallback? onReactivate;

  const _UserCard({
    required this.user,
    this.onDeactivate,
    this.onReactivate,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppPalette.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppPalette.border),
      ),
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
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
                                fontWeight: FontWeight.bold,
                                color: AppPalette.charcoal,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Chip(
                            label: Text(
                              user.role.toUpperCase(),
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            backgroundColor:
                                _roleColor(user.role).withValues(alpha: 0.2),
                            side: BorderSide(
                              color: _roleColor(user.role),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        user.email,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppPalette.mutedText,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: user.active
                        ? Colors.green.withValues(alpha: 0.1)
                        : Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    user.active ? 'Active' : 'Inactive',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: user.active ? Colors.green.shade700 : Colors.red.shade700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (user.lastLoginAt != null) ...[
                  Icon(
                    Icons.access_time,
                    size: 16,
                    color: AppPalette.mutedText,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Last login: ${_formatDateTime(user.lastLoginAt!)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppPalette.mutedText,
                    ),
                  ),
                ] else ...[
                  Icon(
                    Icons.person_add_alt_1,
                    size: 16,
                    color: AppPalette.mutedText,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Created: ${_formatDateTime(user.createdAt ?? DateTime.now())}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppPalette.mutedText,
                    ),
                  ),
                ]
              ],
            ),
            const SizedBox(height: 12),
            if (user.active && onDeactivate != null)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: onDeactivate,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                  ),
                  child: const Text('Deactivate Account'),
                ),
              )
            else if (!user.active && onReactivate != null)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onReactivate,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Reactivate Account'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _roleColor(String role) {
    switch (role.toLowerCase()) {
      case 'visitor':
        return Colors.blue;
      case 'local':
        return Colors.orange;
      case 'admin':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inDays == 0) {
      if (diff.inHours == 0) {
        return '${diff.inMinutes}m ago';
      }
      return '${diff.inHours}h ago';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      return '${dateTime.month}/${dateTime.day}/${dateTime.year}';
    }
  }
}
