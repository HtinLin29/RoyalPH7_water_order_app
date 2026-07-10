import 'dart:convert';

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import 'supabase_error_handler.dart';

class LocationService {
  Future<String> getCurrentAddress() async {
    try {
      await _ensurePermission();

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );

      if (_supportsNativeGeocoding) {
        try {
          return await _reverseGeocodeNative(
            position.latitude,
            position.longitude,
          );
        } catch (_) {
          // Fall through to HTTP reverse geocoding on desktop/web.
        }
      }

      return await _reverseGeocodeHttp(position.latitude, position.longitude);
    } on Exception {
      rethrow;
    } catch (e) {
      throw Exception(SupabaseErrorHandler.getMessage(e));
    }
  }

  bool get _supportsNativeGeocoding {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
  }

  Future<String> _reverseGeocodeNative(double latitude, double longitude) async {
    final placemarks = await placemarkFromCoordinates(latitude, longitude);

    if (placemarks.isEmpty) {
      throw Exception('Could not determine address from your location');
    }

    final address = _formatPlacemark(placemarks.first);
    if (address.trim().isEmpty) {
      throw Exception('Could not determine address from your location');
    }

    return address;
  }

  Future<String> _reverseGeocodeHttp(double latitude, double longitude) async {
    final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
      'format': 'json',
      'lat': latitude.toString(),
      'lon': longitude.toString(),
    });

    final response = await http.get(
      uri,
      headers: const {'User-Agent': 'RoyalPh7App/1.0'},
    );

    if (response.statusCode != 200) {
      throw Exception('Could not determine address from your location');
    }

    final data = json.decode(response.body) as Map<String, dynamic>;
    final displayName = data['display_name'] as String?;
    if (displayName != null && displayName.trim().isNotEmpty) {
      return displayName.trim();
    }

    throw Exception('Could not determine address from your location');
  }

  String _formatPlacemark(Placemark placemark) {
    final parts = <String>[
      if (placemark.street != null && placemark.street!.trim().isNotEmpty)
        placemark.street!.trim(),
      if (placemark.subLocality != null &&
          placemark.subLocality!.trim().isNotEmpty)
        placemark.subLocality!.trim(),
      if (placemark.locality != null && placemark.locality!.trim().isNotEmpty)
        placemark.locality!.trim(),
      if (placemark.administrativeArea != null &&
          placemark.administrativeArea!.trim().isNotEmpty)
        placemark.administrativeArea!.trim(),
      if (placemark.postalCode != null &&
          placemark.postalCode!.trim().isNotEmpty)
        placemark.postalCode!.trim(),
      if (placemark.country != null && placemark.country!.trim().isNotEmpty)
        placemark.country!.trim(),
    ];

    return parts.join(', ');
  }

  Future<void> _ensurePermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Please enable location services on your device');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      throw Exception('Location permission is required to use GPS');
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception(
        'Location permission denied. Please enable it in app settings',
      );
    }
  }
}
