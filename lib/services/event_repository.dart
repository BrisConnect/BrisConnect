import 'package:brisconnect/models/event_item.dart';

class EventRepository {
  static final List<EventItem> _events = [
    const EventItem(
      id: 'approved-brisbane-multicultural-festival',
      title: 'Brisbane Multicultural Festival',
      date: '22 Mar 2026',
      time: '10:00 AM - 8:00 PM',
      location: 'South Bank Parklands',
      description:
          'A city-wide celebration of food, music, and performances from diverse cultures.',
      reviewStatus: EventReviewStatus.approved,
      imageAsset: 'assets/logo.png',
      latitude: -27.4810,
      longitude: 153.0234,
    ),
    const EventItem(
      id: 'approved-riverfire-community-concert',
      title: 'Riverfire Community Concert',
      date: '05 Apr 2026',
      time: '6:30 PM - 10:00 PM',
      location: 'Kangaroo Point Cliffs',
      description:
          'Outdoor live concert with local artists and fireworks over the Brisbane River.',
      reviewStatus: EventReviewStatus.approved,
      latitude: -27.4748,
      longitude: 153.0353,
    ),
    const EventItem(
      id: 'pending-lantern-night-market',
      title: 'Lantern Night Market',
      date: '18 Apr 2026',
      time: '4:00 PM - 9:00 PM',
      location: 'Roma Street Parkland',
      description:
          'Night market featuring artisan stalls, cultural dance groups, and local cuisine.',
      reviewStatus: EventReviewStatus.pending,
    ),
    const EventItem(
      id: 'approved-first-nations-storytelling-evening',
      title: 'First Nations Storytelling Evening',
      date: '27 Apr 2026',
      time: '5:30 PM - 7:00 PM',
      location: 'State Library of Queensland',
      description:
          'Guided storytelling and talks showcasing local First Nations heritage and history.',
      reviewStatus: EventReviewStatus.approved,
      latitude: -27.4730,
      longitude: 153.0170,
    ),
  ];

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
