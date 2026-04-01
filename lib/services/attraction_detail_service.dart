import 'package:flutter/foundation.dart';
import 'package:brisconnect/services/approved_attraction_service.dart';

class AttractionMediaItem {
  const AttractionMediaItem({
    required this.type,
    required this.label,
    required this.url,
  });

  final String type;
  final String label;
  final String url;
}

class AttractionReviewItem {
  const AttractionReviewItem({
    required this.author,
    required this.rating,
    required this.comment,
    required this.when,
  });

  final String author;
  final double rating;
  final String comment;
  final String when;
}

class AttractionLiveUpdate {
  const AttractionLiveUpdate({
    required this.crowdLevel,
    required this.closureStatus,
    required this.eventNote,
    required this.weatherImpact,
    required this.lastUpdated,
  });

  final String crowdLevel;
  final String closureStatus;
  final String eventNote;
  final String weatherImpact;
  final String lastUpdated;
}

class AttractionDetailData {
  const AttractionDetailData({
    required this.history,
    required this.address,
    required this.openingHours,
    required this.specialSchedule,
    required this.entryRequirements,
    required this.ticketPrice,
    required this.bookingLabel,
    this.bookingUrl,
    required this.media,
    this.virtualTourUrl,
    required this.rating,
    required this.reviewCount,
    required this.ratingBreakdown,
    required this.reviews,
    this.phone,
    this.website,
    this.email,
    required this.facilities,
    required this.amenities,
    required this.accessibility,
    required this.visitDuration,
    required this.bestTimeToVisit,
    required this.liveUpdate,
    required this.nearbyAttractions,
    required this.nearbyServices,
    required this.languages,
    required this.audioFeatures,
    required this.personalisedSuggestions,
  });

  final String history;
  final String address;
  final List<String> openingHours;
  final String specialSchedule;
  final String entryRequirements;
  final String ticketPrice;
  final String bookingLabel;
  final String? bookingUrl;
  final List<AttractionMediaItem> media;
  final String? virtualTourUrl;
  final double rating;
  final int reviewCount;
  final Map<String, int> ratingBreakdown;
  final List<AttractionReviewItem> reviews;
  final String? phone;
  final String? website;
  final String? email;
  final List<String> facilities;
  final List<String> amenities;
  final List<String> accessibility;
  final String visitDuration;
  final String bestTimeToVisit;
  final AttractionLiveUpdate liveUpdate;
  final List<String> nearbyAttractions;
  final List<String> nearbyServices;
  final List<String> languages;
  final List<String> audioFeatures;
  final List<String> personalisedSuggestions;
}

class AttractionDetailService {
  AttractionDetailService._();

  static final ValueNotifier<int> _savedVersion = ValueNotifier<int>(0);
  static final Set<String> _savedAttractionIds = <String>{};
  static final Set<String> _itineraryAttractionIds = <String>{};

  static ValueListenable<int> get savedVersion => _savedVersion;

  static bool isSaved(String attractionId) =>
      _savedAttractionIds.contains(attractionId);

  static bool isInItinerary(String attractionId) =>
      _itineraryAttractionIds.contains(attractionId);

  static void toggleSaved(String attractionId) {
    if (_savedAttractionIds.contains(attractionId)) {
      _savedAttractionIds.remove(attractionId);
    } else {
      _savedAttractionIds.add(attractionId);
    }
    _savedVersion.value++;
  }

  static void toggleItinerary(String attractionId) {
    if (_itineraryAttractionIds.contains(attractionId)) {
      _itineraryAttractionIds.remove(attractionId);
    } else {
      _itineraryAttractionIds.add(attractionId);
    }
    _savedVersion.value++;
  }

  static AttractionDetailData getDetail(
    ApprovedAttraction attraction,
    List<ApprovedAttraction> allAttractions,
  ) {
    final AttractionDetailData? configured = _catalog[attraction.id];
    final List<String> nearbyAttractions = _recommendedNearby(
      attraction,
      allAttractions,
    );
    final List<String> personalisedSuggestions = _personalisedSuggestions(
      attraction,
      allAttractions,
    );

    if (configured != null) {
      return AttractionDetailData(
        history: configured.history,
        address: configured.address,
        openingHours: configured.openingHours,
        specialSchedule: configured.specialSchedule,
        entryRequirements: configured.entryRequirements,
        ticketPrice: configured.ticketPrice,
        bookingLabel: configured.bookingLabel,
        bookingUrl: configured.bookingUrl,
        media: configured.media,
        virtualTourUrl: configured.virtualTourUrl,
        rating: configured.rating,
        reviewCount: configured.reviewCount,
        ratingBreakdown: configured.ratingBreakdown,
        reviews: configured.reviews,
        phone: configured.phone,
        website: configured.website ?? attraction.webLink,
        email: configured.email,
        facilities: configured.facilities,
        amenities: configured.amenities,
        accessibility: configured.accessibility,
        visitDuration: configured.visitDuration,
        bestTimeToVisit: configured.bestTimeToVisit,
        liveUpdate: configured.liveUpdate,
        nearbyAttractions:
            configured.nearbyAttractions.isEmpty ? nearbyAttractions : configured.nearbyAttractions,
        nearbyServices: configured.nearbyServices,
        languages: configured.languages,
        audioFeatures: configured.audioFeatures,
        personalisedSuggestions: personalisedSuggestions,
      );
    }

    final String category = attraction.category ?? 'Attraction';
    return AttractionDetailData(
      history:
          'This $category location is part of Brisbane\'s public attraction network and offers a useful stop for visitors planning a city itinerary.',
      address: attraction.location,
      openingHours: const [
        'Monday to Friday: Hours not published',
        'Saturday to Sunday: Check operator website',
      ],
      specialSchedule: 'Special schedules are posted by the venue when available.',
      entryRequirements: 'Check the official venue page for current access requirements.',
      ticketPrice: 'Pricing varies. See operator website for the latest entry information.',
      bookingLabel: 'Official Website',
      bookingUrl: attraction.webLink,
      media: _fallbackMediaFor(attraction),
      virtualTourUrl: null,
      rating: 4.4,
      reviewCount: 86,
      ratingBreakdown: const {'5': 52, '4': 21, '3': 9, '2': 3, '1': 1},
      reviews: const [
        AttractionReviewItem(
          author: 'Brisbane Visitor',
          rating: 4.5,
          comment: 'Easy to add into a city day-plan and well worth a short visit.',
          when: '2 weeks ago',
        ),
        AttractionReviewItem(
          author: 'Weekend Explorer',
          rating: 4.0,
          comment: 'Useful signage and a convenient location near other attractions.',
          when: '1 month ago',
        ),
      ],
      phone: null,
      website: attraction.webLink,
      email: null,
      facilities: const ['Rest areas', 'Public access areas'],
      amenities: const ['Nearby transport', 'Nearby food options'],
      accessibility: const ['Step-free information not available'],
      visitDuration: '45 to 90 minutes',
      bestTimeToVisit: 'Morning on weekdays or late afternoon for a quieter visit.',
      liveUpdate: const AttractionLiveUpdate(
        crowdLevel: 'Moderate',
        closureStatus: 'No closures reported',
        eventNote: 'Check venue website for event-day variations.',
        weatherImpact: 'Outdoor access may be affected by heavy rain.',
        lastUpdated: 'Updated recently',
      ),
      nearbyAttractions: nearbyAttractions,
      nearbyServices: const ['Bus stop nearby', 'Cafe options nearby'],
      languages: const ['English'],
      audioFeatures: const ['Audio guide not currently available'],
      personalisedSuggestions: personalisedSuggestions,
    );
  }

  static List<String> _recommendedNearby(
    ApprovedAttraction attraction,
    List<ApprovedAttraction> allAttractions,
  ) {
    return allAttractions
        .where((item) => item.id != attraction.id)
        .take(3)
        .map((item) => item.name)
        .toList(growable: false);
  }

  static List<String> _personalisedSuggestions(
    ApprovedAttraction attraction,
    List<ApprovedAttraction> allAttractions,
  ) {
    final String? category = attraction.category?.toLowerCase();
    final Iterable<ApprovedAttraction> sameCategory = allAttractions.where(
      (item) => item.id != attraction.id && item.category?.toLowerCase() == category,
    );
    final List<String> suggestions = sameCategory
        .take(3)
        .map((item) => 'If you like ${attraction.name}, also try ${item.name}.')
        .toList(growable: true);

    if (isSaved(attraction.id)) {
      suggestions.add('This attraction is saved, so plan a nearby meal stop before visiting.');
    }
    if (isInItinerary(attraction.id)) {
      suggestions.add('Add 15 minutes of travel buffer around this itinerary stop.');
    }
    if (suggestions.isEmpty) {
      suggestions.add('This attraction works well as a central stop in a half-day Brisbane itinerary.');
    }
    return suggestions;
  }

  static List<AttractionMediaItem> _fallbackMediaFor(ApprovedAttraction attraction) {
    final String seed = attraction.category?.toLowerCase() ?? 'brisbane';
    return <AttractionMediaItem>[
      AttractionMediaItem(
        type: 'photo',
        label: 'Feature Photo',
        url: 'https://images.unsplash.com/photo-1472653431158-6364773b2a56?auto=format&fit=crop&w=1200&q=80&sig=${seed.hashCode}',
      ),
      AttractionMediaItem(
        type: 'photo',
        label: 'Visitor View',
        url: 'https://images.unsplash.com/photo-1508057198894-247b23fe5ade?auto=format&fit=crop&w=1200&q=80&sig=${attraction.id.hashCode}',
      ),
    ];
  }

  static final Map<String, AttractionDetailData> _catalog =
      <String, AttractionDetailData>{
    'attraction_city_hall': AttractionDetailData(
      history:
          'Brisbane City Hall has served as one of the city\'s most prominent civic landmarks since 1930, hosting ceremonies, events, and public life in the heart of the CBD.',
      address: '64 Adelaide Street, Brisbane City QLD 4000',
      openingHours: const [
        'Monday to Friday: 8:00 AM - 5:00 PM',
        'Saturday: 10:00 AM - 4:00 PM',
        'Sunday: Check event calendar',
      ],
      specialSchedule:
          'Clock tower tours and Museum of Brisbane sessions may run on separate operating times.',
      entryRequirements: 'General public entry is free. Some guided tours may require prior booking.',
      ticketPrice: 'Free general access. Special exhibits or tours may vary.',
      bookingLabel: 'Book Tours / Visit Website',
      bookingUrl: 'https://www.brisbane.qld.gov.au/things-to-see-and-do/council-venues-and-precincts/venues/brisbane-city-hall',
      media: const [
        AttractionMediaItem(
          type: 'photo',
          label: 'City Hall Exterior',
          url: 'https://images.unsplash.com/photo-1480714378408-67cf0d13bc1b?auto=format&fit=crop&w=1200&q=80',
        ),
        AttractionMediaItem(
          type: 'photo',
          label: 'Interior Hall',
          url: 'https://images.unsplash.com/photo-1511818966892-d7d671e672a2?auto=format&fit=crop&w=1200&q=80',
        ),
      ],
      virtualTourUrl: 'https://www.museumofbrisbane.com.au/',
      rating: 4.7,
      reviewCount: 1324,
      ratingBreakdown: const {'5': 920, '4': 275, '3': 92, '2': 22, '1': 15},
      reviews: const [
        AttractionReviewItem(
          author: 'Mina R.',
          rating: 5,
          comment: 'Beautiful heritage building and a very easy stop to include while exploring the CBD.',
          when: '4 days ago',
        ),
        AttractionReviewItem(
          author: 'Dylan W.',
          rating: 4.5,
          comment: 'Great architecture and tour options, especially if you pair it with King George Square.',
          when: '2 weeks ago',
        ),
      ],
      phone: '(07) 3403 8888',
      website: 'https://www.brisbane.qld.gov.au/things-to-see-and-do/council-venues-and-precincts/venues/brisbane-city-hall',
      email: 'cityhall@brisbane.qld.gov.au',
      facilities: const ['Restrooms', 'Visitor information desk', 'Indoor seating'],
      amenities: const ['Cafe nearby', 'Public transport nearby', 'Event spaces'],
      accessibility: const ['Lift access', 'Wheelchair-friendly entry', 'Accessible restrooms'],
      visitDuration: '60 to 120 minutes',
      bestTimeToVisit: 'Weekday mornings for lighter foot traffic and easier tours.',
      liveUpdate: const AttractionLiveUpdate(
        crowdLevel: 'Moderate',
        closureStatus: 'Open',
        eventNote: 'King George Square event setup may affect entry points during major events.',
        weatherImpact: 'Mostly indoor venue; weather impact is minimal.',
        lastUpdated: 'Updated 15 minutes ago',
      ),
      nearbyAttractions: const ['Museum of Brisbane', 'King George Square', 'Queen Street Mall'],
      nearbyServices: const ['Central Station', 'Bus interchange', 'Cafe precinct'],
      languages: const ['English', 'Simplified Chinese', 'Japanese handout'],
      audioFeatures: const ['Self-guided audio highlights available online'],
      personalisedSuggestions: const [],
    ),
    'attraction_story_bridge': AttractionDetailData(
      history:
          'The Story Bridge opened in 1940 and remains one of Brisbane\'s defining steel cantilever structures, linking the CBD with Kangaroo Point and Fortitude Valley.',
      address: 'State Route 15, Brisbane QLD 4169',
      openingHours: const [
        'Bridge access: Open daily',
        'Climb operator: Check official schedule',
      ],
      specialSchedule: 'Special event road closures may affect nearby access during city festivals.',
      entryRequirements: 'Public bridge access is free. Climb experiences require booking and fitness criteria.',
      ticketPrice: 'Bridge access free; guided climb is ticketed.',
      bookingLabel: 'Open Official Info',
      bookingUrl: 'https://www.brisbane.qld.gov.au/traffic-and-transport/bridges-tunnels-and-ferries/bridges/story-bridge',
      media: const [
        AttractionMediaItem(
          type: 'photo',
          label: 'Bridge Skyline View',
          url: 'https://images.unsplash.com/photo-1500530855697-b586d89ba3ee?auto=format&fit=crop&w=1200&q=80',
        ),
        AttractionMediaItem(
          type: 'video',
          label: 'Bridge at Sunset',
          url: 'https://www.brisbane.qld.gov.au/traffic-and-transport/bridges-tunnels-and-ferries/bridges/story-bridge',
        ),
      ],
      virtualTourUrl: null,
      rating: 4.8,
      reviewCount: 2088,
      ratingBreakdown: const {'5': 1630, '4': 330, '3': 86, '2': 21, '1': 21},
      reviews: const [
        AttractionReviewItem(
          author: 'Sophie T.',
          rating: 5,
          comment: 'One of the best skyline landmarks in Brisbane and excellent around dusk.',
          when: '6 days ago',
        ),
        AttractionReviewItem(
          author: 'Marcus H.',
          rating: 4.5,
          comment: 'Very photogenic and easy to pair with Howard Smith Wharves.',
          when: '3 weeks ago',
        ),
      ],
      phone: null,
      website: 'https://www.brisbane.qld.gov.au/traffic-and-transport/bridges-tunnels-and-ferries/bridges/story-bridge',
      email: null,
      facilities: const ['Viewing areas nearby', 'Pedestrian access', 'Cycle paths nearby'],
      amenities: const ['Riverfront dining nearby', 'Public transport access'],
      accessibility: const ['Public approaches vary by side', 'Some steep gradients nearby'],
      visitDuration: '30 to 75 minutes',
      bestTimeToVisit: 'Sunrise or sunset for views and cooler conditions.',
      liveUpdate: const AttractionLiveUpdate(
        crowdLevel: 'Busy in evenings',
        closureStatus: 'Open',
        eventNote: 'Bridge area may be busier during weekend events.',
        weatherImpact: 'Strong wind and storms can reduce comfort for viewpoints.',
        lastUpdated: 'Updated 20 minutes ago',
      ),
      nearbyAttractions: const ['Howard Smith Wharves', 'Kangaroo Point Cliffs', 'Brisbane Riverwalk'],
      nearbyServices: const ['Ferry terminal', 'Riverfront restaurants', 'Ride-share pickup points'],
      languages: const ['English'],
      audioFeatures: const ['Scenic self-guided walk notes'],
      personalisedSuggestions: const [],
    ),
  };
}