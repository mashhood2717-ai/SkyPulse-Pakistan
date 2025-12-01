import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  // Test reverse geocoding with Islamabad coordinates
  final latitude = 33.6699;
  final longitude = 73.0794;

  final url = Uri.parse(
      'https://geocoding-api.open-meteo.com/v1/search?latitude=$latitude&longitude=$longitude&format=json');

  print('Testing reverse geocoding for: $latitude, $longitude');
  print('URL: $url');

  try {
    final response = await http.get(url);
    print('Status: ${response.statusCode}');
    print('Response: ${response.body}');

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      print('Parsed JSON:');
      print(json.encode(data));

      if (data['results'] != null && data['results'].isNotEmpty) {
        final result = data['results'][0];
        print('\nFirst result:');
        print('  Name: ${result['name']}');
        print('  Country: ${result['country']}');
        print('  Country Code: ${result['country_code']}');
        print('  Admin1: ${result['admin1']}');
      }
    }
  } catch (e) {
    print('Error: $e');
  }
}
