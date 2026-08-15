/// Metro-area knowledge for Pakistani cities.
///
/// Geocoders return whatever administrative unit contains a point, so the same
/// place can come back as "Model Town", "Lahore District" or "Lahore". This
/// table maps neighbourhoods and sub-districts onto the city people would name,
/// and is used for three things:
///
///   * deciding whether a late background response still belongs to the screen
///     the user is looking at (AQI, METAR),
///   * matching a swiped favourite card against the loaded location,
///   * choosing the alert topic to subscribe to.
///
/// This lived as two divergent private copies in WeatherProvider and
/// HomeScreen before.
class CityAreas {
  static const Map<String, List<String>> areas = {
    'lahore': [
      'samanabad',
      'model town',
      'gulberg',
      'dha',
      'johar town',
      'iqbal town',
      'allama iqbal town',
      'garden town',
      'faisal town',
      'township',
      'cantt',
      'cantonment',
      'bahria',
      'wapda town',
      'valencia',
      'raiwind',
    ],
    'karachi': [
      'dha',
      'clifton',
      'gulshan',
      'nazimabad',
      'north nazimabad',
      'korangi',
      'malir',
      'saddar',
      'bahria',
      'pechs',
      'tariq road',
    ],
    'islamabad': [
      'f-6',
      'f-7',
      'f-8',
      'f-10',
      'f-11',
      'g-6',
      'g-7',
      'g-8',
      'g-9',
      'g-10',
      'g-11',
      'i-8',
      'i-9',
      'i-10',
      'e-7',
      'e-11',
      'dha',
      'bahria',
      'blue area',
    ],
    'rawalpindi': [
      'saddar',
      'cantt',
      'cantonment',
      'chaklala',
      'satellite town',
      'bahria',
      'commercial market',
    ],
    'faisalabad': [
      'dha',
      'peoples colony',
      'madina town',
      'ghulam muhammad abad',
    ],
    'multan': ['dha', 'cantt', 'cantonment', 'bosan road'],
    'peshawar': ['hayatabad', 'university town', 'cantt', 'cantonment'],
  };

  /// The major city a place name belongs to, or null when it isn't one we know.
  ///
  /// A match on the city's own name always beats a match on a neighbourhood,
  /// because several neighbourhood names ("dha", "cantt", "bahria") appear
  /// under more than one city.
  static String? majorCityFor(String placeName) {
    final name = placeName.toLowerCase().trim();
    if (name.isEmpty) return null;

    for (final city in areas.keys) {
      if (name.contains(city)) return city;
    }
    for (final entry in areas.entries) {
      if (entry.value.any((area) => name.contains(area))) return entry.key;
    }
    return null;
  }

  /// True when two names describe the same metro area.
  ///
  /// Unlike the old implementations this does not treat any substring overlap
  /// as a match, which used to make short names collide.
  static bool isSameArea(String a, String b) {
    final first = a.toLowerCase().trim();
    final second = b.toLowerCase().trim();
    if (first.isEmpty || second.isEmpty) return false;
    if (first == second) return true;

    final cityA = majorCityFor(first);
    final cityB = majorCityFor(second);
    if (cityA != null && cityB != null) return cityA == cityB;

    // Neither is a city we know: fall back to containment, which still catches
    // "Mailsi" vs "Mailsi City".
    return first.contains(second) || second.contains(first);
  }

  /// The name to build an alert topic from.
  ///
  /// Collapses "Model Town" to "lahore" and "Peshawar City" to "peshawar" so
  /// devices land on the topics alerts are actually published to. Unknown
  /// places pass through untouched, which keeps smaller towns such as
  /// "Mailsi City" on their own topic.
  static String alertCityFor(String placeName) {
    return majorCityFor(placeName) ?? placeName.toLowerCase().trim();
  }
}
