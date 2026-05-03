/// Builds a tour-guide-style narration script from event metadata fields.
///
/// Used to persist an `aiNarration` field in Firestore so the narration
/// text is visible in the database and doesn't need to be generated
/// client-side every time.
String buildEventNarration({
  required String title,
  String badge = '',
  String dateTime = '',
  String location = '',
  String price = '',
  String description = '',
  String culturalBackground = '',
}) {
  final narrative = <String>[];

  if (title.isNotEmpty) {
    final opening = badge.isNotEmpty
        ? 'G\'day and welcome! You\'re about to experience $title, one of Brisbane\'s standout $badge highlights'
        : 'G\'day and welcome! Let me tell you about $title';
    narrative.add(opening);
  }

  final timeLocation = <String>[];
  if (dateTime.isNotEmpty) timeLocation.add('happening on $dateTime');
  if (location.isNotEmpty) timeLocation.add('over at $location');
  if (timeLocation.isNotEmpty) {
    narrative.add('You can catch this one ${timeLocation.join(', ')}');
  }

  if (description.isNotEmpty) {
    narrative.add('Now, here\'s what makes it really worth your time. $description');
  }

  if (culturalBackground.isNotEmpty) {
    narrative.add('And there\'s a deeper story behind this one. $culturalBackground');
  }

  if (price.isNotEmpty) {
    final priceText = price.toLowerCase().contains('free')
        ? 'The best part? This one\'s completely free'
        : 'Just a heads up, entry is priced at $price, so plan ahead';
    narrative.add(priceText);
  }

  if (narrative.isEmpty) return '';
  return '${narrative.join('. ')}.';
}

/// Builds a tour-guide-style narration script from attraction metadata fields.
///
/// Persisted as `aiNarration` in the `attractions` Firestore collection.
String buildAttractionNarration({
  required String name,
  String category = '',
  String description = '',
  String location = '',
  String webLink = '',
}) {
  final parts = <String>[];

  if (name.isNotEmpty) {
    final opening = category.isNotEmpty
        ? 'G\'day! Welcome to $name, one of Brisbane\'s top $category spots'
        : 'G\'day! Welcome to $name';
    parts.add(opening);
  }

  if (description.isNotEmpty) {
    parts.add('Let me paint the picture for you. $description');
  }

  if (location.isNotEmpty) {
    parts.add('You\'ll find this gem at $location');
  }

  if (webLink.isNotEmpty) {
    parts.add('Want to know more? Check out $webLink');
  }

  if (parts.isEmpty) return '';
  return '${parts.join('. ')}.';
}
