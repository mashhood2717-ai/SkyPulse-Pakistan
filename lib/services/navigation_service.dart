import 'package:url_launcher/url_launcher_string.dart';

class NavigationService {
  /// Opens Google Maps directions to the provided coordinates.
  /// Returns true if the launcher reports success.
  static Future<bool> openGoogleMapsNavigation(double lat, double lon, {String? label}) async {
    final dest = '$lat,$lon';
    final url = Uri.encodeFull('https://www.google.com/maps/dir/?api=1&destination=$dest&travelmode=driving');
    try {
      return await launchUrlString(url, mode: LaunchMode.externalApplication);
    } catch (e) {
      return false;
    }
  }
}
