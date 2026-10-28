import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class LocationService {
  static final http.Client _client = http.Client();

  /// Gets the actual real GPS coordinates of the user device/browser
  static Future<LatLng?> getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('>>> [LocationService]: Location services are disabled.');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('>>> [LocationService]: Location permissions are denied');
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('>>> [LocationService]: Location permissions are permanently denied.');
        return null;
      }

      final Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      debugPrint('>>> [LocationService REAL GPS]: lat=${position.latitude}, lon=${position.longitude}');
      return LatLng(position.latitude, position.longitude);
    } catch (e) {
      debugPrint('>>> [LocationService Error]: $e');
      return null;
    }
  }

  /// Stream continuous real-time GPS position updates
  static Stream<Position>? getPositionStream({
    int distanceFilterMeters = 5,
  }) {
    try {
      final LocationSettings locationSettings;
      if (defaultTargetPlatform == TargetPlatform.android) {
        locationSettings = AndroidSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: distanceFilterMeters,
          forceLocationManager: false,
          intervalDuration: const Duration(seconds: 3),
        );
      } else if (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.macOS) {
        locationSettings = AppleSettings(
          accuracy: LocationAccuracy.high,
          activityType: ActivityType.automotiveNavigation,
          distanceFilter: distanceFilterMeters,
          pauseLocationUpdatesAutomatically: false,
        );
      } else {
        locationSettings = LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: distanceFilterMeters,
        );
      }
      return Geolocator.getPositionStream(locationSettings: locationSettings);
    } catch (e) {
      debugPrint('>>> [LocationService getPositionStream Error]: $e');
      return null;
    }
  }

  /// Reverse geocode LatLng to human-readable address in Vietnam
  static Future<String> getAddressFromCoordinates(LatLng latLng) async {
    // 1. First Tier: OpenStreetMap Nominatim with Vietnamese language
    try {
      final nomUri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=${latLng.latitude}&lon=${latLng.longitude}&addressdetails=1&accept-language=vi',
      );

      final response = await _client.get(
        nomUri,
        headers: {'User-Agent': 'GoShip-Delivery-App/1.0 (contact@goship.vn)'},
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
        final addr = data['address'] as Map<String, dynamic>?;

        if (addr != null) {
          final List<String> parts = [];
          final houseNumber = addr['house_number']?.toString();
          final road = addr['road'] ?? addr['pedestrian'] ?? addr['footway'] ?? addr['path'] ?? addr['suburb_road'];
          final neighbourhood = addr['neighbourhood'] ?? addr['quarter'];
          final suburb = addr['suburb'] ?? addr['ward'];
          final district = addr['city_district'] ?? addr['district'] ?? addr['county'];
          final city = addr['city'] ?? addr['province'] ?? addr['state'];

          if (houseNumber != null && road != null) {
            parts.add('$houseNumber $road');
          } else if (road != null) {
            parts.add(road.toString());
          }

          if (neighbourhood != null && neighbourhood != suburb) {
            parts.add(neighbourhood.toString());
          }
          if (suburb != null) {
            parts.add(suburb.toString());
          }
          if (district != null) {
            parts.add(district.toString());
          }
          if (city != null) {
            parts.add(city.toString());
          }

          if (parts.isNotEmpty) {
            return parts.join(', ');
          }

          final displayName = data['display_name']?.toString();
          if (displayName != null && displayName.isNotEmpty) {
            final split = displayName.split(', ');
            if (split.length > 4) {
              return split.take(4).join(', ');
            }
            return displayName;
          }
        }
      }
    } catch (e) {
      debugPrint('>>> [Nominatim Reverse Geocoding Warning]: $e');
    }

    // 2. Second Tier: Photon Komoot reverse geocoding fallback
    try {
      final photonUri = Uri.parse(
        'https://photon.komoot.io/reverse?lon=${latLng.longitude}&lat=${latLng.latitude}',
      );

      final response = await _client.get(
        photonUri,
        headers: {'User-Agent': 'GoShip-Delivery-App/1.0'},
      ).timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
        final List features = data['features'] as List? ?? [];

        if (features.isNotEmpty) {
          final props = features[0]['properties'] as Map<String, dynamic>? ?? {};
          final List<String> parts = [];

          if (props['housenumber'] != null) parts.add(props['housenumber'].toString());
          if (props['street'] != null) parts.add(props['street'].toString());
          if (props['name'] != null && props['name'] != props['street']) parts.add(props['name'].toString());
          if (props['district'] != null) parts.add(props['district'].toString());
          if (props['city'] != null) parts.add(props['city'].toString());
          if (props['state'] != null && props['state'] != props['city']) parts.add(props['state'].toString());

          if (parts.isNotEmpty) {
            return parts.join(', ');
          }
        }
      }
    } catch (e) {
      debugPrint('>>> [Photon Reverse Geocoding Warning]: $e');
    }

    // 3. Third Tier: Approximate Vietnam district/area rather than raw numbers
    return _approximateAreaName(latLng);
  }

  /// Estimates readable street area based on known Vietnamese urban centers
  static String _approximateAreaName(LatLng latLng) {
    final lat = latLng.latitude;
    final lng = latLng.longitude;

    // TP. Hồ Chí Minh bounds
    if (lat >= 10.70 && lat <= 10.90 && lng >= 106.55 && lng <= 106.85) {
      if (lat >= 10.76 && lat <= 10.79 && lng >= 106.68 && lng <= 106.71) {
        return 'Khu vực Trung tâm Quận 1 / Quận 3, TP. Hồ Chí Minh';
      }
      if (lat >= 10.79 && lat <= 10.82 && lng >= 106.70 && lng <= 106.74) {
        return 'Khu vực Điện Biên Phủ, Bình Thạnh, TP. Hồ Chí Minh';
      }
      if (lat >= 10.82 && lat <= 10.87 && lng >= 106.74 && lng <= 106.82) {
        return 'Khu vực TP. Thủ Đức, TP. Hồ Chí Minh';
      }
      if (lat >= 10.74 && lat <= 10.77 && lng >= 106.65 && lng <= 106.68) {
        return 'Khu vực Quận 5 / Quận 10, TP. Hồ Chí Minh';
      }
      if (lat >= 10.71 && lat <= 10.75 && lng >= 106.70 && lng <= 106.75) {
        return 'Khu vực Phú Mỹ Hưng, Quận 7, TP. Hồ Chí Minh';
      }
      return 'Khu vực nội thành TP. Hồ Chí Minh';
    }

    // TP. Hà Nội bounds
    if (lat >= 20.95 && lat <= 21.15 && lng >= 105.75 && lng <= 105.95) {
      return 'Khu vực nội thành TP. Hà Nội';
    }

    // Bình Dương bounds
    if (lat >= 10.90 && lat <= 11.20 && lng >= 106.60 && lng <= 106.80) {
      return 'Khu vực TP. Thủ Dầu Một, Tỉnh Bình Dương';
    }

    // Đồng Nai bounds
    if (lat >= 10.90 && lat <= 11.05 && lng >= 106.80 && lng <= 107.00) {
      return 'Khu vực TP. Biên Hòa, Tỉnh Đồng Nai';
    }

    return 'Điểm định vị trên bản đồ (${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)})';
  }
}
