import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../model/location_data.dart';

final locationServiceProvider = Provider<LocationService>(
  (ref) => const GeolocatorLocationService(),
);

abstract interface class LocationService {
  Future<void> requestPermission();
  Stream<LocationData> watchLocation();
}

class LocationServiceException implements Exception {
  const LocationServiceException(this.message, {this.openSettings = false});
  final String message;
  final bool openSettings;

  @override
  String toString() => message;
}

class GeolocatorLocationService implements LocationService {
  const GeolocatorLocationService();

  @override
  Future<void> requestPermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const LocationServiceException(
        'Turn on your device location service and try again.',
        openSettings: true,
      );
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw const LocationServiceException(
        'Location permission is required to share your live location.',
      );
    }
    if (permission == LocationPermission.deniedForever) {
      throw const LocationServiceException(
        'Location permission is disabled. Allow it in app settings.',
        openSettings: true,
      );
    }
  }

  @override
  Stream<LocationData> watchLocation() => Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      ).map(
        (position) => LocationData(
          latitude: position.latitude,
          longitude: position.longitude,
          accuracy: position.accuracy,
          timestamp: position.timestamp,
        ),
      );
}
