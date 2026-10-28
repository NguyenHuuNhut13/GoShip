import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class RouteStep {
  final String instruction;
  final String streetName;
  final String maneuverType;
  final String? maneuverModifier;
  final double distanceMeters;
  final LatLng location;

  const RouteStep({
    required this.instruction,
    required this.streetName,
    required this.maneuverType,
    this.maneuverModifier,
    required this.distanceMeters,
    required this.location,
  });
}

class RouteResult {
  final List<LatLng> polylinePoints;
  final double distanceKm;
  final int durationMinutes;
  final bool isSuccess;
  final List<RouteStep> steps;

  RouteResult({
    required this.polylinePoints,
    required this.distanceKm,
    required this.durationMinutes,
    required this.isSuccess,
    this.steps = const [],
  });
}

class RouteService {
  static final http.Client _client = http.Client();

  /// Fetches real driving street-by-street route with turn-by-turn steps from OSRM
  static Future<RouteResult> getDrivingRoute(List<LatLng> waypoints) async {
    if (waypoints.length < 2) {
      return RouteResult(
        polylinePoints: waypoints,
        distanceKm: 0,
        durationMinutes: 0,
        isSuccess: true,
        steps: const [],
      );
    }

    try {
      // OSRM format: lon,lat;lon,lat;lon,lat
      final coordsParam = waypoints.map((w) => '${w.longitude},${w.latitude}').join(';');
      final url = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/$coordsParam?overview=full&geometries=geojson&steps=true',
      );

      final response = await _client.get(
        url,
        headers: {'User-Agent': 'GoShip-Delivery-App/1.0'},
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        if (data['code'] == 'Ok' && data['routes'] != null && (data['routes'] as List).isNotEmpty) {
          final route = data['routes'][0] as Map<String, dynamic>;
          final double distanceMeters = (route['distance'] as num?)?.toDouble() ?? 0.0;
          final double durationSeconds = (route['duration'] as num?)?.toDouble() ?? 0.0;

          final geometry = route['geometry'] as Map<String, dynamic>?;
          final coordsList = geometry?['coordinates'] as List?;

          final List<LatLng> roadPoints = [];
          if (coordsList != null) {
            for (final item in coordsList) {
              if (item is List && item.length >= 2) {
                final double lon = (item[0] as num).toDouble();
                final double lat = (item[1] as num).toDouble();
                roadPoints.add(LatLng(lat, lon));
              }
            }
          }

          // Parse turn-by-turn navigation steps
          final List<RouteStep> navigationSteps = [];
          final legs = route['legs'] as List?;
          if (legs != null && legs.isNotEmpty) {
            for (final leg in legs) {
              final stepsList = (leg as Map<String, dynamic>)['steps'] as List?;
              if (stepsList != null) {
                for (final s in stepsList) {
                  final sMap = s as Map<String, dynamic>;
                  final double stepDist = (sMap['distance'] as num?)?.toDouble() ?? 0.0;
                  final String street = sMap['name']?.toString() ?? '';
                  final maneuver = sMap['maneuver'] as Map<String, dynamic>? ?? {};
                  final String mType = maneuver['type']?.toString() ?? 'turn';
                  final String? mModifier = maneuver['modifier']?.toString();
                  final mLoc = maneuver['location'] as List?;

                  LatLng stepLocation = roadPoints.isNotEmpty ? roadPoints.first : waypoints.first;
                  if (mLoc != null && mLoc.length >= 2) {
                    stepLocation = LatLng((mLoc[1] as num).toDouble(), (mLoc[0] as num).toDouble());
                  }

                  final instruction = _formatVietnameseInstruction(mType, mModifier, street, stepDist);
                  navigationSteps.add(
                    RouteStep(
                      instruction: instruction,
                      streetName: street,
                      maneuverType: mType,
                      maneuverModifier: mModifier,
                      distanceMeters: stepDist,
                      location: stepLocation,
                    ),
                  );
                }
              }
            }
          }

          // If no steps returned by OSRM, synthesize default steps
          if (navigationSteps.isEmpty && roadPoints.isNotEmpty) {
            navigationSteps.add(
              RouteStep(
                instruction: 'Bắt đầu di chuyển theo tuyến đường',
                streetName: '',
                maneuverType: 'depart',
                distanceMeters: distanceMeters,
                location: roadPoints.first,
              ),
            );
            navigationSteps.add(
              RouteStep(
                instruction: 'Đến điểm đích',
                streetName: '',
                maneuverType: 'arrive',
                distanceMeters: 0,
                location: roadPoints.last,
              ),
            );
          }

          final double km = double.parse((distanceMeters / 1000.0).toStringAsFixed(1));
          final int minutes = (durationSeconds / 60.0).round().clamp(1, 1440);

          debugPrint('>>> [OSRM Route Success]: $km km, ~$minutes mins, ${roadPoints.length} road points, ${navigationSteps.length} steps.');

          return RouteResult(
            polylinePoints: roadPoints.isNotEmpty ? roadPoints : waypoints,
            distanceKm: km > 0 ? km : 1.0,
            durationMinutes: minutes > 0 ? minutes : 5,
            isSuccess: true,
            steps: navigationSteps,
          );
        }
      }
    } catch (e) {
      debugPrint('>>> [OSRM Route Error, using fallback]: $e');
    }

    // Fallback: Calculate distance and interpolate road-aligned intermediate points
    double totalDist = 0.0;
    const Distance distanceCalc = Distance();
    for (int i = 0; i < waypoints.length - 1; i++) {
      totalDist += distanceCalc.as(LengthUnit.Kilometer, waypoints[i], waypoints[i + 1]);
    }
    final double distKm = double.parse((totalDist > 0 ? totalDist : 3.5).toStringAsFixed(1));
    final int duration = (distKm * 3.0).round().clamp(5, 120);

    final List<LatLng> interpolatedRoad = [];
    for (int i = 0; i < waypoints.length - 1; i++) {
      final p1 = waypoints[i];
      final p2 = waypoints[i + 1];
      interpolatedRoad.add(p1);
      final corner1 = LatLng(p1.latitude, (p1.longitude * 2 + p2.longitude) / 3);
      final corner2 = LatLng((p1.latitude + p2.latitude * 2) / 3, corner1.longitude);
      interpolatedRoad.add(corner1);
      interpolatedRoad.add(corner2);
    }
    interpolatedRoad.add(waypoints.last);

    final List<RouteStep> fallbackSteps = [
      RouteStep(
        instruction: 'Bắt đầu di chuyển theo lộ trình',
        streetName: '',
        maneuverType: 'depart',
        distanceMeters: distKm * 1000,
        location: waypoints.first,
      ),
      RouteStep(
        instruction: 'Đến điểm đích',
        streetName: '',
        maneuverType: 'arrive',
        distanceMeters: 0,
        location: waypoints.last,
      ),
    ];

    return RouteResult(
      polylinePoints: interpolatedRoad,
      distanceKm: distKm,
      durationMinutes: duration,
      isSuccess: false,
      steps: fallbackSteps,
    );
  }

  static String _formatVietnameseInstruction(String type, String? modifier, String streetName, double distanceMeters) {
    final street = streetName.trim().isNotEmpty ? ' vào $streetName' : '';
    final distText = distanceMeters > 0
        ? (distanceMeters >= 1000
            ? 'Sau ${(distanceMeters / 1000).toStringAsFixed(1)}km '
            : 'Sau ${distanceMeters.round()}m ')
        : '';

    switch (type) {
      case 'depart':
        return 'Bắt đầu khởi hành$street';
      case 'arrive':
        return 'Đến điểm dừng';
      case 'turn':
      case 'end of road':
        if (modifier == 'left' || modifier == 'slight left' || modifier == 'sharp left') {
          return '$distText rẽ trái$street';
        } else if (modifier == 'right' || modifier == 'slight right' || modifier == 'sharp right') {
          return '$distText rẽ phải$street';
        } else if (modifier == 'uturn') {
          return '$distText quay đầu xe';
        }
        return '$distText rẽ$street';
      case 'new name':
      case 'continue':
        return '$distText tiếp tục đi thẳng$street';
      case 'roundabout':
      case 'rotary':
        return '$distText vào bùng binh$street';
      case 'fork':
        if (modifier?.contains('left') == true) return '$distText đi theo nhánh bên trái$street';
        if (modifier?.contains('right') == true) return '$distText đi theo nhánh bên phải$street';
        return '$distText đi theo lối rẽ$street';
      default:
        if (modifier == 'left' || modifier == 'slight left') return '$distText rẽ trái$street';
        if (modifier == 'right' || modifier == 'slight right') return '$distText rẽ phải$street';
        return '$distText tiếp tục di chuyển$street';
    }
  }
}
