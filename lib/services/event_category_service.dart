import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class EventCategoryService {
  EventCategoryService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static const List<String> defaultCategories = <String>[
    'Culture',
    'Music',
    'Food',
    'Sports',
    'Community',
    'Education',
    'Family',
    'General',
  ];

  static const String _collection = 'config';
  static const String _document = 'event_categories';

  DocumentReference<Map<String, dynamic>> get _docRef =>
      _firestore.collection(_collection).doc(_document);

  Future<List<String>> fetchCategories() async {
    try {
      final snapshot = await _docRef.get();
      if (!snapshot.exists) {
        await _seedDefaults();
        return List<String>.from(defaultCategories);
      }
      final data = snapshot.data() ?? const <String, dynamic>{};
      final items = data['items'];
      if (items is List && items.isNotEmpty) {
        return items.cast<String>();
      }
      return List<String>.from(defaultCategories);
    } catch (error) {
      debugPrint('[EventCategoryService] fetchCategories failed: $error');
      return List<String>.from(defaultCategories);
    }
  }

  Stream<List<String>> watchCategories() {
    return _docRef.snapshots().map((snapshot) {
      if (!snapshot.exists) return List<String>.from(defaultCategories);
      final data = snapshot.data() ?? const <String, dynamic>{};
      final items = data['items'];
      if (items is List && items.isNotEmpty) {
        return items.cast<String>();
      }
      return List<String>.from(defaultCategories);
    }).handleError((error) {
      debugPrint('[EventCategoryService] watchCategories error: $error');
      return List<String>.from(defaultCategories);
    });
  }

  Future<void> saveCategories(List<String> categories) async {
    final cleaned = categories
        .map((c) => c.trim())
        .where((c) => c.isNotEmpty)
        .toSet()
        .toList();
    await _docRef.set({
      'items': cleaned,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> addCategory(String category) async {
    final current = await fetchCategories();
    final trimmed = category.trim();
    if (trimmed.isEmpty || current.contains(trimmed)) return;
    current.add(trimmed);
    await saveCategories(current);
  }

  Future<void> removeCategory(String category) async {
    final current = await fetchCategories();
    current.remove(category.trim());
    await saveCategories(current);
  }

  Future<void> _seedDefaults() async {
    try {
      await _docRef.set({
        'items': defaultCategories,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (error) {
      debugPrint('[EventCategoryService] _seedDefaults failed: $error');
    }
  }
}
