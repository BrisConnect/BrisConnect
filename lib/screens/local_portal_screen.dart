import 'package:flutter/material.dart';
import 'package:brisconnect/auth/local_auth.dart';
import 'package:brisconnect/models/event_item.dart';
import 'package:brisconnect/screens/add_event_screen.dart';
import 'package:brisconnect/screens/local_edit_event_screen.dart';
import 'package:brisconnect/screens/local_event_detail_screen.dart';
import 'package:brisconnect/services/event_repository.dart';
import 'package:brisconnect/theme/app_palette.dart';
import 'package:brisconnect/widgets/reusable_management_card.dart';

class LocalPortalScreen extends StatefulWidget {
  const LocalPortalScreen({super.key});

  @override
  State<LocalPortalScreen> createState() => _LocalPortalScreenState();
}

class _LocalPortalScreenState extends State<LocalPortalScreen> {
  final TextEditingController _searchController = TextEditingController();
  int _selectedIndex = 0;
  static const String _defaultImageUrl =
      'https://images.unsplash.com/photo-1472653431158-6364773b2a56?auto=format&fit=crop&w=1400&q=80';

  List<EventItem> get _mySubmittedEvents {
    final localEmail = LocalAuth.currentLocal?.email;
    if (localEmail == null) {
      return const [];
    }
    return EventRepository.getEventsForLocal(localEmail);
  }

  List<EventItem> _searchItems(List<EventItem> items) {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return items;

    return items.where((item) {
      return item.title.toLowerCase().contains(query) ||
          item.location.toLowerCase().contains(query) ||
          _statusText(item.reviewStatus).toLowerCase().contains(query);
    }).toList();
  }

  List<EventItem> get _pendingEvents =>
      _mySubmittedEvents.where((item) => item.isPending).toList();

  List<EventItem> get _approvedEvents =>
      _mySubmittedEvents.where((item) => item.isApproved).toList();

  String _statusText(EventReviewStatus status) {
    switch (status) {
      case EventReviewStatus.approved:
        return 'Approved';
      case EventReviewStatus.pending:
        return 'Pending Approval';
      case EventReviewStatus.rejected:
        return 'Rejected';
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      decoration: BoxDecoration(
        color: AppPalette.surface,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: AppPalette.border),
        boxShadow: const [
          BoxShadow(
            color: AppPalette.cardShadow,
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, color: AppPalette.ochre),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: 'Manage local events in Brisbane',
                hintStyle: TextStyle(color: AppPalette.mutedText),
              ),
            ),
          ),
          Container(
            width: 38,
            height: 38,
            decoration: const BoxDecoration(
              color: AppPalette.surfaceAlt,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Management filters coming soon')),
                );
              },
              icon: const Icon(Icons.tune_rounded, size: 20),
              color: AppPalette.deepBlue,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildManagementCard(EventItem event) {
    return ReusableManagementCard(
      imageUrl: _defaultImageUrl,
      title: event.title,
      dateTime: '${event.date} • ${event.time}',
      location: event.location,
      status: _statusText(event.reviewStatus),
      onEditTap: () async {
        final didEdit = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) => LocalEditEventScreen(event: event),
          ),
        );
        if (didEdit == true && mounted) {
          setState(() {});
        }
      },
      onDeleteTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delete: ${event.title}')),
        );
      },
      onViewDetailsTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => LocalEventDetailScreen(event: event),
          ),
        );
      },
    );
  }

  Widget _buildDashboard() {
    final all = _searchItems(_mySubmittedEvents);
    final pending = _searchItems(_pendingEvents);
    final approved = _searchItems(_approvedEvents);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      children: [
        Text(
          'Welcome, ${LocalAuth.currentLocal?.name ?? 'Local'}',
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: AppPalette.charcoal,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Organize, submit, and track your local events',
          style: TextStyle(
            color: AppPalette.mutedText,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 14),
        _buildSearchBar(),
        const SizedBox(height: 16),
        _QuickActionCard(
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AddEventScreen()),
            );
            if (mounted) {
              setState(() {});
            }
          },
        ),
        const SizedBox(height: 18),
        _SectionTitle(
          title: 'My Submitted Events',
          subtitle: '${all.length} total events',
        ),
        ...all.map(_buildManagementCard),
        const SizedBox(height: 10),
        _SectionTitle(
          title: 'Pending Events',
          subtitle: '${pending.length} waiting for approval',
        ),
        if (pending.isEmpty)
          const _LocalEmptyState('No pending events right now.')
        else
          ...pending.map(_buildManagementCard),
        const SizedBox(height: 10),
        _SectionTitle(
          title: 'Approved Events',
          subtitle: '${approved.length} live events',
        ),
        if (approved.isEmpty)
          const _LocalEmptyState('No approved events yet.')
        else
          ...approved.map(_buildManagementCard),
      ],
    );
  }

  Widget _buildMyEventsTab() {
    final all = _searchItems(_mySubmittedEvents);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      children: [
        const Text(
          'My Events',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: AppPalette.charcoal,
          ),
        ),
        const SizedBox(height: 12),
        _buildSearchBar(),
        const SizedBox(height: 16),
        if (all.isEmpty)
          const _LocalEmptyState('You have not submitted any events yet.')
        else
          ...all.map(_buildManagementCard),
      ],
    );
  }

  Widget _buildProfileTab() {
    final local = LocalAuth.currentLocal;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      children: [
        const Text(
          'Profile',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: AppPalette.charcoal,
          ),
        ),
        const SizedBox(height: 12),
        Card(
          color: AppPalette.surface,
          child: ListTile(
            leading: const CircleAvatar(
              backgroundColor: AppPalette.surfaceAlt,
              child: Icon(Icons.person_rounded, color: AppPalette.deepBlue),
            ),
            title: Text(local?.name ?? 'Local User'),
            subtitle: Text(local?.email ?? 'local@brisconnect.com'),
          ),
        ),
        Card(
          color: AppPalette.surface,
          child: ListTile(
            leading: const Icon(Icons.logout_rounded, color: AppPalette.ochre),
            title: const Text('Logout'),
            subtitle: const Text('Sign out and return to welcome screen'),
            onTap: () {
              LocalAuth.logout();
              Navigator.popUntil(context, (route) => route.isFirst);
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F3EA),
      body: SafeArea(
        child: IndexedStack(
          index: _selectedIndex,
          children: [
            _buildDashboard(),
            _buildMyEventsTab(),
            _buildProfileTab(),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        selectedItemColor: AppPalette.ochre,
        unselectedItemColor: AppPalette.deepBlue,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_rounded),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.event_note_rounded),
            label: 'My Events',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline_rounded),
            activeIcon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final VoidCallback onTap;

  const _QuickActionCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppPalette.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppPalette.border),
        boxShadow: const [
          BoxShadow(
            color: AppPalette.cardShadow,
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppPalette.surfaceAlt,
            ),
            child: const Icon(Icons.add_rounded, color: AppPalette.ochre),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Add New Event',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppPalette.charcoal,
                    fontSize: 16,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Create and submit a new local event for review',
                  style: TextStyle(color: AppPalette.mutedText),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: onTap,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppPalette.deepBlue,
              foregroundColor: Colors.white,
            ),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionTitle({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppPalette.charcoal,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(
              color: AppPalette.mutedText,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _LocalEmptyState extends StatelessWidget {
  final String text;

  const _LocalEmptyState(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppPalette.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppPalette.border),
      ),
      child: Text(
        text,
        style: const TextStyle(color: AppPalette.mutedText),
      ),
    );
  }
}
