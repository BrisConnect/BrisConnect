import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:brisconnect/theme/app_palette.dart';

class DashboardSearchBar extends StatefulWidget {
  const DashboardSearchBar({super.key});

  @override
  State<DashboardSearchBar> createState() => _DashboardSearchBarState();
}

class _DashboardSearchBarState extends State<DashboardSearchBar> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _isLoading = false;
  List<_SearchSuggestion> _suggestions = [];

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    if (query.trim().length < 2) {
      setState(() => _suggestions = []);
      return;
    }
    setState(() => _isLoading = true);

    final lower = query.trim().toLowerCase();
    final firestore = FirebaseFirestore.instance;
    final suggestions = <_SearchSuggestion>[];

    try {
      final users = await firestore
          .collection('local_users')
          .orderBy('name')
          .startAt([lower]).endAt(['$lower\uf8ff'])
          .limit(3)
          .get();
      for (final doc in users.docs) {
        final data = doc.data();
        final name = (data['name'] as String? ?? '').trim();
        if (name.toLowerCase().contains(lower)) {
          suggestions.add(
            _SearchSuggestion(
              title: name.isNotEmpty ? name : doc.id,
              subtitle: 'User',
              icon: Icons.person_rounded,
              onTap: () {},
            ),
          );
        }
      }

      final businesses = await firestore
          .collection('businesses')
          .orderBy('businessName')
          .startAt([lower]).endAt(['$lower\uf8ff'])
          .limit(3)
          .get();
      for (final doc in businesses.docs) {
        final data = doc.data();
        final name = (data['businessName'] as String? ?? '').trim();
        if (name.toLowerCase().contains(lower)) {
          suggestions.add(
            _SearchSuggestion(
              title: name.isNotEmpty ? name : doc.id,
              subtitle: 'Business',
              icon: Icons.business_rounded,
              onTap: () {},
            ),
          );
        }
      }

      final events = await firestore
          .collection('events')
          .orderBy('title')
          .startAt([lower]).endAt(['$lower\uf8ff'])
          .limit(3)
          .get();
      for (final doc in events.docs) {
        final data = doc.data();
        final title = (data['title'] as String? ?? '').trim();
        if (title.toLowerCase().contains(lower)) {
          suggestions.add(
            _SearchSuggestion(
              title: title.isNotEmpty ? title : doc.id,
              subtitle: 'Event',
              icon: Icons.event_rounded,
              onTap: () {},
            ),
          );
        }
      }
    } catch (_) {
      // Silently fail search.
    }

    if (mounted) {
      setState(() {
        _suggestions = suggestions;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: AppPalette.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: TextField(
            controller: _controller,
            focusNode: _focusNode,
            onChanged: _search,
            decoration: InputDecoration(
              hintText:
                  'Search users, businesses, events, reviews or reports…',
              hintStyle: TextStyle(
                color: AppPalette.mutedText.withValues(alpha: 0.8),
                fontWeight: FontWeight.w500,
              ),
              prefixIcon:
                  const Icon(Icons.search_rounded, color: AppPalette.mutedText),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_controller.text.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.clear_rounded,
                          color: AppPalette.mutedText),
                      onPressed: () {
                        _controller.clear();
                        _search('');
                      },
                    ),
                  IconButton(
                    icon: const Icon(Icons.mic_rounded,
                        color: AppPalette.mutedText),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Voice search coming soon')),
                      );
                    },
                  ),
                ],
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
        if (_isLoading || _suggestions.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppPalette.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: _isLoading
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(
                      child: CircularProgressIndicator(color: AppPalette.ochre),
                    ),
                  )
                : _suggestions.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'No results found',
                          style: TextStyle(color: AppPalette.mutedText),
                        ),
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: _suggestions
                            .map(
                              (s) => ListTile(
                                leading: Icon(s.icon, color: AppPalette.ochre),
                                title: Text(
                                  s.title,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700),
                                ),
                                subtitle: Text(s.subtitle),
                                trailing: const Icon(
                                  Icons.chevron_right_rounded,
                                  color: AppPalette.mutedText,
                                ),
                                onTap: s.onTap,
                              ),
                            )
                            .toList(),
                      ),
          ),
      ],
    );
  }
}

class _SearchSuggestion {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  _SearchSuggestion({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });
}
