import 'package:flutter/foundation.dart';

/// Debug-only logging.
///
/// `print` is **not** stripped from Flutter release builds, so the app used to
/// write GPS coordinates, resolved street addresses, FCM token fragments and
/// full API response bodies to logcat on production devices — readable by any
/// app holding READ_LOGS, or by anyone with the handset plugged in.
///
/// Named `logDebug` rather than `log` because several files import `dart:math`
/// unprefixed, where `log` is the natural logarithm.
void logDebug(Object? message) {
  if (kDebugMode) {
    debugPrint('$message');
  }
}
