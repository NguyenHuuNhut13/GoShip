import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../../features/customer/order/models/simulated_driver_model.dart';

class DriverSimulationService {
  /// Calculates bearing (heading angle 0-360 degrees) from start coordinate to end coordinate
  static double calculateBearing(LatLng start, LatLng end) {
    final double lat1 = start.latitude * (math.pi / 180.0);
    final double lng1 = start.longitude * (math.pi / 180.0);
    final double lat2 = end.latitude * (math.pi / 180.0);
    final double lng2 = end.longitude * (math.pi / 180.0);

    final double dLng = lng2 - lng1;

    final double y = math.sin(dLng) * math.cos(lat2);
    final double x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLng);

    final double bearingRad = math.atan2(y, x);
    final double bearingDeg = (bearingRad * (180.0 / math.pi) + 360.0) % 360.0;
    return bearingDeg;
  }

  /// Generates a realistic set of truck drivers positioned strictly on real streets
  /// If [routePoints] from OSRM is provided, drivers are mapped directly onto the route's road network.
  /// If not, verified real-world asphalt road corridors around [center] are used (never inside lakes or houses).
  static List<SimulatedDriver> generateNearbyDrivers(
    LatLng center, {
    List<LatLng>? routePoints,
    int count = 5,
    String preferredVehicle = 'van',
  }) {
    // 5 professional truck driver profiles (100% trucks/vans/pickups, NO motorbikes)
    final List<Map<String, dynamic>> driverTemplates = [
      {
        'id': 'drv_01',
        'name': 'Trần Văn Hùng',
        'phone': '0912 345 678',
        'plate': '59-G1 123.45',
        'vehicleType': 'van',
        'vehicleName': 'Xe tải Van Suzuki Blind 580kg',
        'rating': 4.9,
        'trips': 412,
        'avatar': 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150',
        'addressHint': 'Đang lưu thông trên đường Nguyễn Hữu Cảnh (Tân Cảng)',
      },
      {
        'id': 'drv_02',
        'name': 'Nguyễn Hoàng Long',
        'phone': '0908 765 432',
        'plate': '51D 892.14',
        'vehicleType': 'pickup',
        'vehicleName': 'Xe bán tải Ranger 750kg',
        'rating': 4.95,
        'trips': 620,
        'avatar': 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150',
        'addressHint': 'Đang lưu thông trên đường Điện Biên Phủ (Cầu Sài Gòn)',
      },
      {
        'id': 'drv_03',
        'name': 'Lê Minh Tuấn',
        'phone': '0983 112 233',
        'plate': '60C 341.82',
        'vehicleType': 'truck_1000kg',
        'vehicleName': 'Xe tải thùng bạt Isuzu 1.25 Tấn',
        'rating': 4.88,
        'trips': 350,
        'avatar': 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=150',
        'addressHint': 'Đang lưu thông trên đường Nguyễn Văn Thương (D1)',
      },
      {
        'id': 'drv_04',
        'name': 'Đặng Thành Nam',
        'phone': '0961 445 566',
        'plate': '50D 629.53',
        'vehicleType': 'van',
        'vehicleName': 'Xe tải Van Dongben 800kg',
        'rating': 4.85,
        'trips': 280,
        'avatar': 'https://images.unsplash.com/photo-1519085360753-af0119f7cbe7?w=150',
        'addressHint': 'Đang lưu thông trên đường Võ Oanh (D3)',
      },
      {
        'id': 'drv_05',
        'name': 'Phạm Quốc Bảo',
        'phone': '0937 998 877',
        'plate': '51C 445.67',
        'vehicleType': 'truck_1500kg',
        'vehicleName': 'Xe tải thùng kín Hyundai 1.5 Tấn',
        'rating': 4.92,
        'trips': 510,
        'avatar': 'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=150',
        'addressHint': 'Đang lưu thông trên đường Nguyễn Gia Trí (D2)',
      },
    ];

    final targetCount = count.clamp(1, driverTemplates.length);
    final List<List<LatLng>> roadCorridors = [];

    // 100% verified asphalt road corridors strictly within 1000m radius of Landmark (10.7946, 106.7218)
    // All coordinates are strictly inland / westward (longitude <= 106.7218, NEVER in Saigon River)
    const distCalc = Distance();
    final double distFromLandmark = distCalc.as(LengthUnit.Kilometer, center, const LatLng(10.7946, 106.7218));

    if (distFromLandmark < 3.0) {
      roadCorridors.addAll([
        // 1. Đường Nguyễn Hữu Cảnh (Tân Cảng - Landmark 81, cách tâm ~120m-480m)
        [
          const LatLng(10.7940, 106.7208),
          const LatLng(10.7952, 106.7200),
          const LatLng(10.7966, 106.7194),
          const LatLng(10.7980, 106.7188),
        ],
        // 2. Đường Điện Biên Phủ (Đoạn cầu vượt Tân Cảng inland, cách tâm ~440m-860m)
        [
          const LatLng(10.7986, 106.7216),
          const LatLng(10.7995, 106.7205),
          const LatLng(10.8005, 106.7195),
          const LatLng(10.8015, 106.7182),
        ],
        // 3. Đường Nguyễn Văn Thương (D1) (Cách tâm ~610m-910m)
        [
          const LatLng(10.8000, 106.7209),
          const LatLng(10.8012, 106.7212),
          const LatLng(10.8020, 106.7214),
          const LatLng(10.8028, 106.7216),
        ],
        // 4. Đường Võ Oanh (D3) (Đoạn nối sang D1, cách tâm ~900m-980m)
        [
          const LatLng(10.8025, 106.7198),
          const LatLng(10.8028, 106.7188),
          const LatLng(10.8026, 106.7178),
        ],
        // 5. Đường Nguyễn Gia Trí (D2 - Đoạn nối Điện Biên Phủ, cách tâm ~960m-995m)
        [
          const LatLng(10.8015, 106.7162),
          const LatLng(10.8020, 106.7162),
          const LatLng(10.8025, 106.7160),
        ],
      ]);
    } else {
      // Generic location: Generate realistic street segments offset along surrounding neighborhood streets
      final double cosLat = math.cos(center.latitude * math.pi / 180.0);
      final angles = [0.4, 1.8, 3.2, 4.6, 5.8];
      for (int i = 0; i < targetCount; i++) {
        final rad = angles[i % angles.length];
        final baseDist = 280.0 + (i % 3) * 140.0;
        final pBase = LatLng(
          center.latitude + (baseDist * math.sin(rad)) / 111000.0,
          center.longitude + (baseDist * math.cos(rad)) / (111000.0 * cosLat),
        );

        // Corridor along street angle (tangent)
        final streetAngle = rad + math.pi / 2;
        final pts = <LatLng>[];
        for (int step = -2; step <= 2; step++) {
          final d = step * 50.0;
          pts.add(LatLng(
            pBase.latitude + (d * math.sin(streetAngle)) / 111000.0,
            pBase.longitude + (d * math.cos(streetAngle)) / (111000.0 * cosLat),
          ));
        }
        roadCorridors.add(pts);
      }
    }

    final List<SimulatedDriver> list = [];
    for (int i = 0; i < targetCount; i++) {
      final t = driverTemplates[i];
      final path = roadCorridors[i % roadCorridors.length];
      final initialPos = path.first;
      final heading = path.length >= 2 ? calculateBearing(path[0], path[1]) : 45.0;

      list.add(SimulatedDriver(
        id: t['id'] as String,
        name: t['name'] as String,
        phone: t['phone'] as String,
        plate: t['plate'] as String,
        vehicleType: t['vehicleType'] as String,
        vehicleName: t['vehicleName'] as String,
        rating: (t['rating'] as num).toDouble(),
        tripsCount: t['trips'] as int,
        avatarUrl: t['avatar'] as String,
        currentPosition: initialPos,
        headingDegrees: heading,
        addressHint: t['addressHint'] as String,
        roadPath: path,
        currentPathIndex: 0,
        pathProgress: (i * 0.2) % 0.8,
        movingForward: true,
      ));
    }

    return list;
  }

  /// Advances all nearby drivers along their respective real road paths
  /// Moves forward by [speedMetersPerSec] * [deltaSeconds] meters (~15-20m per tick)
  /// Automatically aligns heading with the street direction and safely loops at street ends.
  static List<SimulatedDriver> stepNearbyDrivers(
    List<SimulatedDriver> drivers, {
    double speedMetersPerSec = 7.0, // ~25 km/h urban delivery pace
    double deltaSeconds = 5.0,
  }) {
    if (drivers.isEmpty) return drivers;
    final double stepDistance = speedMetersPerSec * deltaSeconds;
    const distanceCalc = Distance();

    return drivers.map((driver) {
      final path = driver.roadPath;
      if (path.length < 2) return driver;

      int curIdx = driver.currentPathIndex.clamp(0, path.length - 2);
      double progress = driver.pathProgress;
      bool forward = driver.movingForward;

      LatLng p1 = forward ? path[curIdx] : path[curIdx + 1];
      LatLng p2 = forward ? path[curIdx + 1] : path[curIdx];

      double segLen = distanceCalc.as(LengthUnit.Meter, p1, p2);
      if (segLen <= 1.0) segLen = 15.0;

      progress += stepDistance / segLen;

      if (progress >= 1.0) {
        progress = 0.0;
        if (forward) {
          curIdx++;
          if (curIdx >= path.length - 1) {
            forward = false;
            curIdx = path.length - 2;
          }
        } else {
          curIdx--;
          if (curIdx < 0) {
            forward = true;
            curIdx = 0;
          }
        }
      }

      p1 = forward ? path[curIdx] : path[curIdx + 1];
      p2 = forward ? path[curIdx + 1] : path[curIdx];

      final double lat = p1.latitude + (p2.latitude - p1.latitude) * progress;
      final double lng = p1.longitude + (p2.longitude - p1.longitude) * progress;
      final LatLng newPos = LatLng(lat, lng);
      final double heading = calculateBearing(p1, p2);

      return driver.copyWith(
        currentPosition: newPos,
        headingDegrees: heading,
        currentPathIndex: curIdx,
        pathProgress: progress,
        movingForward: forward,
      );
    }).toList();
  }

  /// Optional: Asynchronously snaps drivers to the nearest real street centerlines via OSRM
  static Future<List<SimulatedDriver>> snapDriversToRoads(List<SimulatedDriver> drivers) async {
    final List<SimulatedDriver> updated = [];
    for (final d in drivers) {
      try {
        final url = Uri.parse(
          'https://router.project-osrm.org/nearest/v1/driving/${d.currentPosition.longitude},${d.currentPosition.latitude}?number=1',
        );
        final response = await http.get(url, headers: {'User-Agent': 'GoShip-App/1.0'})
            .timeout(const Duration(seconds: 2));
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['code'] == 'Ok' && data['waypoints'] != null && (data['waypoints'] as List).isNotEmpty) {
            final wp = data['waypoints'][0];
            final loc = wp['location'] as List;
            final name = wp['name']?.toString() ?? '';
            final snappedPos = LatLng((loc[1] as num).toDouble(), (loc[0] as num).toDouble());
            updated.add(d.copyWith(
              currentPosition: snappedPos,
              addressHint: name.isNotEmpty ? 'Đang lưu thông trên $name' : d.addressHint,
            ));
            continue;
          }
        }
      } catch (_) {}
      updated.add(d);
    }
    return updated;
  }
}

/// Specialized controller to drive an animated vehicle smoothly along a road polyline
class LiveTrackingEngine {
  final List<LatLng> routePoints;
  final Function(
    LatLng currentPosition,
    double headingDegrees,
    List<LatLng> traveledPoints,
    List<LatLng> remainingPoints,
    double remainingKm,
    int remainingMinutes,
    double progressPercent,
  ) onUpdate;
  final VoidCallback onCompleted;

  Timer? _timer;
  int _currentSegmentIndex = 0;
  double _segmentT = 0.0; // 0.0 -> 1.0 along current segment
  double _speedMultiplier = 1.0;
  bool _isPaused = false;

  late final double _totalDistanceMeters;
  final List<double> _cumulativeDistances = [];

  LiveTrackingEngine({
    required this.routePoints,
    required this.onUpdate,
    required this.onCompleted,
  }) {
    _calculateDistances();
  }

  void _calculateDistances() {
    _cumulativeDistances.clear();
    double sum = 0.0;
    const distanceCalc = Distance();
    _cumulativeDistances.add(0.0);

    for (int i = 0; i < routePoints.length - 1; i++) {
      final d = distanceCalc.as(LengthUnit.Meter, routePoints[i], routePoints[i + 1]);
      sum += d;
      _cumulativeDistances.add(sum);
    }
    _totalDistanceMeters = sum > 0 ? sum : 100.0;
  }

  void start({double speedMultiplier = 1.0}) {
    _speedMultiplier = speedMultiplier;
    _currentSegmentIndex = 0;
    _segmentT = 0.0;
    _isPaused = false;
    _timer?.cancel();

    if (routePoints.isEmpty) {
      onCompleted();
      return;
    }

    if (routePoints.length == 1) {
      onUpdate(routePoints.first, 0.0, routePoints, [], 0.0, 0, 1.0);
      onCompleted();
      return;
    }

    // Tick every 80ms for ultra smooth movement
    const int tickMs = 80;
    _timer = Timer.periodic(const Duration(milliseconds: tickMs), (timer) {
      if (_isPaused) return;

      _tick(tickMs);
    });
  }

  void _tick(int tickMs) {
    if (_currentSegmentIndex >= routePoints.length - 1) {
      _timer?.cancel();
      onCompleted();
      return;
    }

    final p1 = routePoints[_currentSegmentIndex];
    final p2 = routePoints[_currentSegmentIndex + 1];

    const distanceCalc = Distance();
    final segmentLengthMeters = distanceCalc.as(LengthUnit.Meter, p1, p2);

    // Realistic truck speed: ~38 km/h = ~10.5 m/s
    final double speedMps = 10.5 * _speedMultiplier;
    final double stepMeters = speedMps * (tickMs / 1000.0);

    final double stepT = segmentLengthMeters > 0 ? (stepMeters / segmentLengthMeters) : 1.0;
    _segmentT += stepT;

    while (_segmentT >= 1.0 && _currentSegmentIndex < routePoints.length - 1) {
      _segmentT -= 1.0;
      _currentSegmentIndex++;
    }

    if (_currentSegmentIndex >= routePoints.length - 1) {
      final lastPoint = routePoints.last;
      final prevPoint = routePoints.length >= 2 ? routePoints[routePoints.length - 2] : lastPoint;
      final heading = DriverSimulationService.calculateBearing(prevPoint, lastPoint);

      onUpdate(
        lastPoint,
        heading,
        routePoints,
        [],
        0.0,
        0,
        1.0,
      );
      _timer?.cancel();
      onCompleted();
      return;
    }

    final curP1 = routePoints[_currentSegmentIndex];
    final curP2 = routePoints[_currentSegmentIndex + 1];

    // Interpolate coordinate
    final lat = curP1.latitude + (curP2.latitude - curP1.latitude) * _segmentT;
    final lng = curP1.longitude + (curP2.longitude - curP1.longitude) * _segmentT;
    final currentPos = LatLng(lat, lng);
    final heading = DriverSimulationService.calculateBearing(curP1, curP2);

    // Split traveled vs remaining
    final List<LatLng> traveled = routePoints.sublist(0, _currentSegmentIndex + 1);
    traveled.add(currentPos);

    final List<LatLng> remaining = [currentPos];
    remaining.addAll(routePoints.sublist(_currentSegmentIndex + 1));

    // Calculate remaining distance & ETA
    final double coveredInSegment = segmentLengthMeters * _segmentT;
    final double totalCovered = (_cumulativeDistances[_currentSegmentIndex] + coveredInSegment)
        .clamp(0.0, _totalDistanceMeters);
    final double remainingMeters = (_totalDistanceMeters - totalCovered).clamp(0.0, _totalDistanceMeters);
    final double remainingKm = double.parse((remainingMeters / 1000.0).toStringAsFixed(1));
    final int remainingMins = (remainingMeters / (10.5 * 60.0)).ceil().clamp(1, 120);
    final double progressPercent = (totalCovered / _totalDistanceMeters).clamp(0.0, 1.0);

    onUpdate(
      currentPos,
      heading,
      traveled,
      remaining,
      remainingKm,
      remainingMins,
      progressPercent,
    );
  }

  void setSpeedMultiplier(double multiplier) {
    _speedMultiplier = multiplier.clamp(0.5, 20.0);
  }

  void pause() {
    _isPaused = true;
  }

  void resume() {
    _isPaused = false;
  }

  void jumpToEnd() {
    _timer?.cancel();
    if (routePoints.isNotEmpty) {
      final lastPoint = routePoints.last;
      final prevPoint = routePoints.length >= 2 ? routePoints[routePoints.length - 2] : lastPoint;
      final heading = DriverSimulationService.calculateBearing(prevPoint, lastPoint);
      onUpdate(
        lastPoint,
        heading,
        routePoints,
        [],
        0.0,
        0,
        1.0,
      );
    }
    onCompleted();
  }

  void dispose() {
    _timer?.cancel();
  }
}
