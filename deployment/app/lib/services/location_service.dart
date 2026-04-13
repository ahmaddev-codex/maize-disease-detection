import 'package:geolocator/geolocator.dart';

/// Thin wrapper around geolocator — returns the current position or null
/// if permission is denied or location is unavailable.
class LocationService {
  /// Request permission if needed, then return the current position.
  /// Returns null on any failure (permission denied, timeout, etc.).
  static Future<Position?> currentPosition() async {
    try {
      bool enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) return null;

      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return null;
      }

      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 8),
        ),
      );
    } catch (_) {
      return null;
    }
  }
}
