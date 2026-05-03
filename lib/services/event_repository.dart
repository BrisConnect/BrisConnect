import 'package:brisconnect/models/event_item.dart';

/// In-memory event cache used only to sync newly-submitted events into the
/// local portal view before the Firestore stream delivers them.
///
/// All persistent event data lives in the Firestore `events` collection;
/// this repository is a transient write-through cache.
class EventRepository {
  static final List<EventItem> _events = [];

  static List<EventItem> getApprovedEvents() {
    return _events.where((event) => event.isApproved).toList();
  }

  static List<EventItem> getPendingEvents() {
    return _events.where((event) => event.isPending).toList();
  }

  static List<EventItem> getReviewedEvents() {
    return _events.where((event) => !event.isPending).toList();
  }

  static List<EventItem> getEventsForLocal(String localEmail) {
    final normalizedEmail = localEmail.trim().toLowerCase();
    return _events
        .where(
          (event) =>
              event.createdByLocalEmail?.toLowerCase() == normalizedEmail,
        )
        .toList();
  }

  static void approveEvent(EventItem event) {
    final index = _events.indexWhere((item) => identical(item, event));
    if (index == -1) {
      return;
    }

    _events[index] = _events[index].copyWith(
      reviewStatus: EventReviewStatus.approved,
    );
  }

  static void rejectEvent(EventItem event) {
    final index = _events.indexWhere((item) => identical(item, event));
    if (index == -1) {
      return;
    }

    _events[index] = _events[index].copyWith(
      reviewStatus: EventReviewStatus.rejected,
    );
  }

  static void addPendingEvent({
    String? id,
    required String title,
    required String date,
    required String location,
    required String description,
    required String createdByLocalEmail,
  }) {
    _events.add(
      EventItem(
        id: id ?? 'local-${DateTime.now().millisecondsSinceEpoch}',
        title: title,
        date: date,
        time: 'Time TBA',
        location: location,
        description: description,
        reviewStatus: EventReviewStatus.pending,
        createdByLocalEmail: createdByLocalEmail,
      ),
    );
  }

  static bool updateEventForLocal({
    required EventItem originalEvent,
    required String localEmail,
    required String title,
    required String date,
    required String location,
    required String description,
  }) {
    final index = _events.indexWhere((item) => identical(item, originalEvent));
    if (index == -1) {
      return false;
    }

    final storedEvent = _events[index];
    final normalizedOwner = storedEvent.createdByLocalEmail?.toLowerCase();
    final normalizedRequester = localEmail.trim().toLowerCase();
    if (normalizedOwner == null || normalizedOwner != normalizedRequester) {
      return false;
    }

    _events[index] = storedEvent.copyWith(
      title: title,
      date: date,
      location: location,
      description: description,
      reviewStatus: EventReviewStatus.pending,
    );

    return true;
  }
}
