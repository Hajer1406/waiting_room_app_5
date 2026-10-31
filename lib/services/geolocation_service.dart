// lib/services/geolocation_service.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// Handles device GPS location requests with proper permission management.
/// Returns null if permission is denied, timed out, or unavailable
/// (the app continues to work without location — it's optional context).
class GeolocationService {
  Future<Position?> getCurrentPosition() async {
    try {
      // Step 1: Check current permission status
      var permission = await Geolocator.checkPermission();

      // Step 2: Request permission if not yet granted
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      // Step 3: If still denied (or permanently denied), return null gracefully
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        debugPrint('GeolocationService: permission denied ($permission)');
        return null;
      }

      // Step 4: Verify that device location services are enabled
      final isServiceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!isServiceEnabled) {
        debugPrint('GeolocationService: location services are disabled');
        return null;
      }

      // Step 5: Try last known position on mobile/desktop (not supported on Web)
      if (!kIsWeb) {
        try {
          final lastKnown = await Geolocator.getLastKnownPosition();
          if (lastKnown != null) {
            return lastKnown;
          }
        } catch (_) {}
      }

      // Step 6: Fetch fresh position (12-second timeout to allow Chrome Wi-Fi lookup)
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low, // Low accuracy = faster + saves battery
        timeLimit: const Duration(seconds: 12),
      );
    } catch (e) {
      debugPrint('GeolocationService error: $e');
      return null; // Never crash or freeze the app over optional location data
    }
  }
}
