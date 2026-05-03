import 'package:flutter/material.dart';
import 'package:brisconnect/auth/local_auth.dart';
import 'package:brisconnect/auth/visitor_auth.dart';
import 'package:brisconnect/theme/app_palette.dart';
import 'package:brisconnect/widgets/logo_app_bar_title.dart';

class InterestCategoriesScreen extends StatefulWidget {
  const InterestCategoriesScreen.visitor({super.key}) : isLocalUser = false;

  const InterestCategoriesScreen.local({super.key}) : isLocalUser = true;

  final bool isLocalUser;

  @override
  State<InterestCategoriesScreen> createState() =>
      _InterestCategoriesScreenState();
}

class _InterestCategoriesScreenState extends State<InterestCategoriesScreen> {
  static const List<_InterestCategory> _categories = [
    _InterestCategory('Cultural', Icons.theater_comedy_outlined),
    _InterestCategory('Music & Entertainment', Icons.music_note_outlined),
    _InterestCategory('Sports', Icons.sports_soccer_outlined),
    _InterestCategory('Food & Dining', Icons.restaurant_outlined),
    _InterestCategory('Nature & Outdoors', Icons.park_outlined),
    _InterestCategory(
        'Historical & Attractions', Icons.account_balance_outlined),
    _InterestCategory('Markets & Shopping', Icons.storefront_outlined),
    _InterestCategory('Workshops & Community', Icons.groups_outlined),
  ];

  final Set<String> _selected = <String>{};
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadInitialSelection();
  }

  Future<void> _loadInitialSelection() async {
    final values = widget.isLocalUser
        ? await LocalAuth.getInterestCategories()
        : await VisitorAuth.getInterestCategories();

    if (!mounted) return;
    setState(() {
      _selected
        ..clear()
        ..addAll(values);
      _isLoading = false;
    });
  }

  Future<void> _saveSelection() async {
    if (_isSaving) return;

    setState(() => _isSaving = true);
    final sorted = _selected.toList()..sort();
    final success = widget.isLocalUser
        ? await LocalAuth.setInterestCategories(sorted)
        : await VisitorAuth.setInterestCategories(sorted);

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Interest categories saved.'),
          duration: Duration(seconds: 2),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save categories. Please try again.'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _toggleCategory(String label, bool selected) {
    setState(() {
      if (selected) {
        _selected.add(label);
      } else {
        _selected.remove(label);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.background,
      appBar: AppBar(
        title: const LogoAppBarTitle('Interest Categories'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Interest Categories',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: AppPalette.charcoal,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Choose your interests so we can personalise events and attractions for you.',
                      style: TextStyle(
                        color: AppPalette.mutedText,
                        fontSize: 14,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: _categories.map((category) {
                        final selected = _selected.contains(category.label);
                        return FilterChip(
                          showCheckmark: false,
                          avatar: Icon(
                            category.icon,
                            size: 18,
                            color:
                                selected ? Colors.white : AppPalette.deepBlue,
                          ),
                          label: Text(category.label),
                          selected: selected,
                          onSelected: (value) =>
                              _toggleCategory(category.label, value),
                          selectedColor: AppPalette.deepBlue,
                          backgroundColor: AppPalette.surface,
                          side: const BorderSide(color: AppPalette.border),
                          labelStyle: TextStyle(
                            color:
                                selected ? Colors.white : AppPalette.charcoal,
                            fontWeight: FontWeight.w600,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                        );
                      }).toList(growable: false),
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isSaving ? null : _saveSelection,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppPalette.deepBlue,
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: _isSaving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.save_outlined),
                        label: Text(_isSaving ? 'Saving...' : 'Save'),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: _isSaving
                            ? null
                            : () {
                                Navigator.of(context).maybePop();
                              },
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(46),
                          side: const BorderSide(color: AppPalette.border),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Skip for now'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _InterestCategory {
  const _InterestCategory(this.label, this.icon);

  final String label;
  final IconData icon;
}
