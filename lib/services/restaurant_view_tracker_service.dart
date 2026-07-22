import 'package:cloud_firestore/cloud_firestore.dart';

/// Service for tracking and managing restaurant view counts
class RestaurantViewTrackerService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String _collection = 'restaurants';
  static const String _viewsField = 'views';
  static const String _lastViewedField = 'lastViewed';

  /// Increment view count for a restaurant
  Future<void> trackRestaurantView(String restaurantId) async {
    try {
      final docRef = _firestore.collection(_collection).doc(restaurantId);

      // Check if document exists
      final docSnapshot = await docRef.get();

      if (docSnapshot.exists) {
        // Increment existing views
        await docRef.update({
          _viewsField: FieldValue.increment(1),
          _lastViewedField: FieldValue.serverTimestamp(),
        });
      } else {
        // Create new document with initial view count
        await docRef.set({
          _viewsField: 1,
          _lastViewedField: FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print('Error tracking restaurant view: $e');
      // Silently fail to not disrupt user experience
    }
  }

  /// Get current view count for a restaurant
  Future<int> getViewCount(String restaurantId) async {
    try {
      final doc =
          await _firestore.collection(_collection).doc(restaurantId).get();
      if (doc.exists) {
        return (doc.data()?[_viewsField] as num?)?.toInt() ?? 0;
      }
      return 0;
    } catch (e) {
      print('Error getting view count: $e');
      return 0;
    }
  }

  /// Stream view count for real-time updates
  Stream<int> watchViewCount(String restaurantId) {
    return _firestore
        .collection(_collection)
        .doc(restaurantId)
        .snapshots()
        .map((snapshot) {
      if (snapshot.exists) {
        return (snapshot.data()?[_viewsField] as num?)?.toInt() ?? 0;
      }
      return 0;
    });
  }

  /// Get top restaurants by views
  Future<List<Map<String, dynamic>>> getTopRestaurants({int limit = 10}) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .orderBy(_viewsField, descending: true)
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) {
        return {
          'id': doc.id,
          'views': (doc.data()[_viewsField] as num?)?.toInt() ?? 0,
          ...doc.data(),
        };
      }).toList();
    } catch (e) {
      print('Error getting top restaurants: $e');
      return [];
    }
  }

  /// Get restaurants viewed in the last N days
  Future<List<Map<String, dynamic>>> getRecentlyViewedRestaurants(
      {int days = 7, int limit = 20}) async {
    try {
      final cutoffDate = DateTime.now().subtract(Duration(days: days));

      final snapshot = await _firestore
          .collection(_collection)
          .where(_lastViewedField, isGreaterThanOrEqualTo: cutoffDate)
          .orderBy(_lastViewedField, descending: true)
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) {
        return {
          'id': doc.id,
          'views': (doc.data()[_viewsField] as num?)?.toInt() ?? 0,
          'lastViewed': doc.data()[_lastViewedField],
          ...doc.data(),
        };
      }).toList();
    } catch (e) {
      print('Error getting recently viewed restaurants: $e');
      return [];
    }
  }

  /// Get daily view analytics for a restaurant
  Future<List<Map<String, dynamic>>> getDailyViewAnalytics(
      String restaurantId,
      {int days = 30}) async {
    try {
      final doc = await _firestore
          .collection('view_analytics')
          .doc(restaurantId)
          .get();

      if (doc.exists) {
        final dailyData = (doc.data()?['dailyViews'] as List?) ?? [];
        return List<Map<String, dynamic>>.from(dailyData);
      }
      return [];
    } catch (e) {
      print('Error getting daily analytics: $e');
      return [];
    }
  }

  /// Get view statistics
  Future<Map<String, dynamic>> getViewStatistics(String restaurantId) async {
    try {
      final doc =
          await _firestore.collection(_collection).doc(restaurantId).get();

      if (doc.exists) {
        final data = doc.data() ?? {};
        final totalViews = (data[_viewsField] as num?)?.toInt() ?? 0;
        final lastViewed = data[_lastViewedField];

        return {
          'totalViews': totalViews,
          'lastViewed': lastViewed,
          'createdAt': data['createdAt'],
        };
      }
      return {'totalViews': 0};
    } catch (e) {
      print('Error getting view statistics: $e');
      return {'totalViews': 0};
    }
  }

  /// Get trending restaurants (viewed most in last 7 days)
  Future<List<Map<String, dynamic>>> getTrendingRestaurants(
      {int days = 7, int limit = 10}) async {
    try {
      final cutoffDate = DateTime.now().subtract(Duration(days: days));

      final snapshot = await _firestore
          .collection(_collection)
          .where(_lastViewedField, isGreaterThanOrEqualTo: cutoffDate)
          .orderBy(_viewsField, descending: true)
          .orderBy(_lastViewedField, descending: true)
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) {
        return {
          'id': doc.id,
          'views': (doc.data()[_viewsField] as num?)?.toInt() ?? 0,
          'lastViewed': doc.data()[_lastViewedField],
          ...doc.data(),
        };
      }).toList();
    } catch (e) {
      print('Error getting trending restaurants: $e');
      return [];
    }
  }
}
