void main() {
  // Test the IMPROVED topic sanitization logic with accent transliteration
  List<String> testCities = [
    'Siālkot',
    'Murree',
    'Lahore',
    'Chakri',
    'Mailsi',
    'Faisalābād',
    'Multān',
    'Îslāmābād',
    'Simple City',
    'City-With-Dash',
    'City_With_Underscore'
  ];

  print('🧪 Testing IMPROVED Topic Sanitization Logic:\n');

  for (String cityName in testCities) {
    String sanitized = _sanitizeTopicName(cityName);
    final fullTopic = '${sanitized}_alerts';
    print('📝 "$cityName" → "$sanitized" → "$fullTopic"');
    print('   ✅ Valid Firebase topic: ${_isValidTopic(fullTopic)}\n');
  }
}

/// Sanitize city name for Firebase topics: transliterate accents to ASCII
String _sanitizeTopicName(String cityName) {
  // Map of accented characters to ASCII equivalents
  const accentMap = {
    'á': 'a',
    'à': 'a',
    'ā': 'a',
    'ä': 'a',
    'â': 'a',
    'é': 'e',
    'è': 'e',
    'ē': 'e',
    'ë': 'e',
    'ê': 'e',
    'í': 'i',
    'ì': 'i',
    'ī': 'i',
    'ï': 'i',
    'î': 'i',
    'ó': 'o',
    'ò': 'o',
    'ō': 'o',
    'ö': 'o',
    'ô': 'o',
    'ú': 'u',
    'ù': 'u',
    'ū': 'u',
    'ü': 'u',
    'û': 'u',
    'ç': 'c',
    'ć': 'c',
    'ñ': 'n',
    'ń': 'n',
    'ý': 'y',
    'ỹ': 'y',
    'š': 's',
    'ś': 's',
    'ž': 'z',
    'ź': 'z',
    'ł': 'l',
    'đ': 'd',
    'ð': 'd',
    'þ': 'th',
    'ø': 'o',
    'æ': 'ae',
  };

  String result = cityName.toLowerCase().replaceAll(' ', '_');

  // Replace accented characters
  accentMap.forEach((accented, ascii) {
    result = result.replaceAll(accented, ascii);
  });

  // Keep only valid Firebase topic chars: a-z, 0-9, _, -
  result = result
      .split('')
      .map((char) => (char.codeUnitAt(0) >= 97 &&
                  char.codeUnitAt(0) <= 122) || // a-z
              (char.codeUnitAt(0) >= 48 && char.codeUnitAt(0) <= 57) || // 0-9
              char == '_' ||
              char == '-'
          ? char
          : '')
      .join('');

  return result;
}

/// Firebase topic validation: alphanumeric, underscore, hyphen only
bool _isValidTopic(String topic) {
  final regex = RegExp(r'^[a-zA-Z0-9_-]+$');
  return regex.hasMatch(topic);
}
