import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

class SimulatedDriver {
  final String id;
  final String name;
  final String phone;
  final String plate;
  final String vehicleType; // 'van', 'pickup', 'truck_1000kg', 'truck_1500kg'
  final String vehicleName;
  final double rating;
  final int tripsCount;
  final String avatarUrl;
  final LatLng currentPosition;
  final double headingDegrees;
  final String addressHint;
  final List<LatLng> roadPath;
  final int currentPathIndex;
  final double pathProgress;
  final bool movingForward;

  const SimulatedDriver({
    required this.id,
    required this.name,
    required this.phone,
    required this.plate,
    required this.vehicleType,
    required this.vehicleName,
    required this.rating,
    required this.tripsCount,
    required this.avatarUrl,
    required this.currentPosition,
    this.headingDegrees = 0.0,
    this.addressHint = 'Đậu trên tuyến đường lân cận',
    this.roadPath = const [],
    this.currentPathIndex = 0,
    this.pathProgress = 0.0,
    this.movingForward = true,
  });

  IconData get vehicleIcon {
    switch (vehicleType) {
      case 'van':
        return Icons.airport_shuttle_rounded;
      case 'pickup':
        return Icons.local_shipping_rounded;
      case 'truck_1000kg':
      case 'truck_1500kg':
      default:
        return Icons.local_shipping_rounded;
    }
  }

  SimulatedDriver copyWith({
    String? id,
    String? name,
    String? phone,
    String? plate,
    String? vehicleType,
    String? vehicleName,
    double? rating,
    int? tripsCount,
    String? avatarUrl,
    LatLng? currentPosition,
    double? headingDegrees,
    String? addressHint,
    List<LatLng>? roadPath,
    int? currentPathIndex,
    double? pathProgress,
    bool? movingForward,
  }) {
    return SimulatedDriver(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      plate: plate ?? this.plate,
      vehicleType: vehicleType ?? this.vehicleType,
      vehicleName: vehicleName ?? this.vehicleName,
      rating: rating ?? this.rating,
      tripsCount: tripsCount ?? this.tripsCount,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      currentPosition: currentPosition ?? this.currentPosition,
      headingDegrees: headingDegrees ?? this.headingDegrees,
      addressHint: addressHint ?? this.addressHint,
      roadPath: roadPath ?? this.roadPath,
      currentPathIndex: currentPathIndex ?? this.currentPathIndex,
      pathProgress: pathProgress ?? this.pathProgress,
      movingForward: movingForward ?? this.movingForward,
    );
  }
}
