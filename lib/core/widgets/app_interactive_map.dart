import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../constants/app_colors.dart';
import '../services/location_service.dart';
import '../../features/customer/order/models/simulated_driver_model.dart';
import 'top_down_truck_widget.dart';

class LocationPoint {
  final String title;
  final String address;
  final LatLng latLng;
  final bool isPickup;
  final int? index;

  LocationPoint({
    required this.title,
    required this.address,
    required this.latLng,
    this.isPickup = false,
    this.index,
  });
}

class AppInteractiveMap extends StatefulWidget {
  final LatLng initialCenter;
  final double initialZoom;
  final List<LocationPoint> points;
  final List<LatLng> customRoutePoints;
  final List<LatLng> traveledRoutePoints;
  final List<SimulatedDriver> nearbyDrivers;
  final SimulatedDriver? activeDriver;
  final bool autoFollowDriver;
  final bool isRadarSearching;
  final Function(LatLng point)? onPointSelected;
  final Function(SimulatedDriver driver)? onDriverSelected;
  final String? selectedDriverId;
  final bool showRouteLine;
  final bool isMiniMap;
  final double? bottomControlsPadding;
  final LatLng? nearbySearchCenter;
  final double nearbySearchRadiusMeters;
  final bool showNearbyRadiusCircle;

  const AppInteractiveMap({
    super.key,
    this.initialCenter = const LatLng(10.7946, 106.7150),
    this.initialZoom = 14.0,
    this.points = const [],
    this.customRoutePoints = const [],
    this.traveledRoutePoints = const [],
    this.nearbyDrivers = const [],
    this.activeDriver,
    this.autoFollowDriver = false,
    this.isRadarSearching = false,
    this.onPointSelected,
    this.onDriverSelected,
    this.selectedDriverId,
    this.showRouteLine = true,
    this.isMiniMap = false,
    this.bottomControlsPadding,
    this.nearbySearchCenter,
    this.nearbySearchRadiusMeters = 1000.0,
    this.showNearbyRadiusCircle = false,
  });

  @override
  State<AppInteractiveMap> createState() => _AppInteractiveMapState();
}

class _AppInteractiveMapState extends State<AppInteractiveMap>
    with SingleTickerProviderStateMixin {
  late final MapController _mapController;
  late final AnimationController _pulseController;
  bool _userFollowingDriver = true;
  late double _currentZoom;

  double get _zoomScale {
    final z = _currentZoom.clamp(10.0, 18.0);
    return (0.35 + (z - 10.0) / 6.0 * 0.65).clamp(0.35, 1.15);
  }

  LatLng? get _effectiveSearchCenter {
    if (widget.nearbySearchCenter != null) {
      return widget.nearbySearchCenter;
    }
    // Ưu tiên điểm lấy / nhận hàng (isPickup == true)
    for (final pt in widget.points) {
      if (pt.isPickup) return pt.latLng;
    }
    if (widget.points.isNotEmpty) return widget.points.first.latLng;
    return widget.initialCenter;
  }

  double get _effectiveSearchRadius => widget.nearbySearchRadiusMeters;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _userFollowingDriver = widget.autoFollowDriver;
    _currentZoom = widget.initialZoom;
  }

  @override
  void didUpdateWidget(AppInteractiveMap oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.activeDriver != null && _userFollowingDriver) {
      final oldPos = oldWidget.activeDriver?.currentPosition;
      final newPos = widget.activeDriver!.currentPosition;
      if (oldPos == null || oldPos.latitude != newPos.latitude || oldPos.longitude != newPos.longitude) {
        _mapController.move(newPos, _mapController.camera.zoom);
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _moveToCurrentLocation() async {
    final gps = await LocationService.getCurrentLocation();
    if (gps != null) {
      _mapController.move(gps, 15.5);
    } else if (widget.points.isNotEmpty) {
      _mapController.move(widget.points.first.latLng, 14.5);
    } else {
      _mapController.move(widget.initialCenter, 14.5);
    }
  }

  void _moveToActiveDriver() {
    if (widget.activeDriver != null) {
      setState(() {
        _userFollowingDriver = true;
      });
      _mapController.move(widget.activeDriver!.currentPosition, 16.0);
    }
  }

  void _zoomIn() {
    _mapController.move(_mapController.camera.center, _mapController.camera.zoom + 1);
  }

  void _zoomOut() {
    _mapController.move(_mapController.camera.center, _mapController.camera.zoom - 1);
  }

  @override
  Widget build(BuildContext context) {
    // Prefer detailed OSRM turn-by-turn road curves
    final List<LatLng> remainingRouteCoords = widget.customRoutePoints.isNotEmpty
        ? widget.customRoutePoints
        : widget.points.map((p) => p.latLng).toList();

    final LatLng center = widget.activeDriver != null
        ? widget.activeDriver!.currentPosition
        : (widget.points.isNotEmpty ? widget.points.first.latLng : widget.initialCenter);

    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. FlutterMap OpenStreetMap Layer
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: center,
            initialZoom: widget.initialZoom,
            minZoom: 5.0,
            maxZoom: 18.5,
            interactionOptions: InteractionOptions(
              flags: widget.isMiniMap
                  ? (InteractiveFlag.drag | InteractiveFlag.pinchZoom)
                  : (InteractiveFlag.drag | InteractiveFlag.pinchZoom | InteractiveFlag.doubleTapZoom),
            ),
            onPositionChanged: (camera, hasGesture) {
              if (camera.zoom != _currentZoom) {
                setState(() => _currentZoom = camera.zoom);
              }
              if (hasGesture && _userFollowingDriver) {
                // User interacted with map, pause auto-follow until recenter pressed
                setState(() => _userFollowingDriver = false);
              }
            },
            onTap: (tapPosition, latLng) {
              if (widget.onPointSelected != null) {
                widget.onPointSelected!(latLng);
              }
            },
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              fallbackUrl: 'https://{s}.tile.openstreetmap.fr/hot/{z}/{x}/{y}.png',
              subdomains: const ['a', 'b'],
              userAgentPackageName: 'vn.nks.goship.goship_app',
              maxZoom: 19,
            ),

            // Traveled Polyline (Muted gray line showing distance already covered)
            if (widget.showRouteLine && widget.traveledRoutePoints.length >= 2)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: widget.traveledRoutePoints,
                    color: const Color(0xFF94A3B8),
                    strokeWidth: 4.5,
                  ),
                ],
              ),

            // Remaining Route Polyline (Turn-by-turn curved street path)
            if (widget.showRouteLine && remainingRouteCoords.length >= 2)
              PolylineLayer(
                polylines: [
                  // Shadow outline for polyline
                  Polyline(
                    points: remainingRouteCoords,
                    color: const Color(0xFF1D4ED8),
                    strokeWidth: 5.5,
                  ),
                  // Inner bright route line
                  Polyline(
                    points: remainingRouteCoords,
                    color: const Color(0xFF3B82F6),
                    strokeWidth: 3.8,
                  ),
                ],
              ),

            // Vòng tròn bán kính tìm kiếm quanh điểm nhận / lấy hàng (Search Radius Circle)
            if (widget.showNearbyRadiusCircle &&
                _effectiveSearchCenter != null &&
                (widget.nearbyDrivers.isNotEmpty || widget.isRadarSearching))
              CircleLayer(
                circles: [
                  // Lớp phủ màu mờ nhẹ nhàng bên trong vòng tròn
                  CircleMarker(
                    point: _effectiveSearchCenter!,
                    radius: _effectiveSearchRadius,
                    useRadiusInMeter: true,
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderColor: AppColors.primary.withValues(alpha: 0.55),
                    borderStrokeWidth: 2.0,
                  ),
                  // Hiệu ứng sóng radar nhẹ nhàng quanh chu vi vòng tròn
                  CircleMarker(
                    point: _effectiveSearchCenter!,
                    radius: _effectiveSearchRadius * (0.98 + 0.02 * _pulseController.value),
                    useRadiusInMeter: true,
                    color: Colors.transparent,
                    borderColor: AppColors.accent.withValues(alpha: 0.35 * (1.0 - _pulseController.value)),
                    borderStrokeWidth: 1.5,
                  ),
                ],
              ),

            // Tag hiển thị bán kính ở đỉnh chu vi vòng tròn (chỉ hiện khi showNearbyRadiusCircle == true)
            if (widget.showNearbyRadiusCircle && widget.nearbyDrivers.isNotEmpty && _effectiveSearchCenter != null && _currentZoom >= 13.0)
              MarkerLayer(
                markers: [
                  Marker(
                    point: LatLng(
                      _effectiveSearchCenter!.latitude + (_effectiveSearchRadius / 111000.0),
                      _effectiveSearchCenter!.longitude,
                    ),
                    width: 140,
                    height: 24,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: const [
                            BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 1)),
                          ],
                        ),
                        child: Text(
                          'Bán kính ${(_effectiveSearchRadius / 1000).toStringAsFixed(1)} km',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

            // Nearby Drivers Markers (Hiển thị các xe tài xế đang lưu thông quanh khu vực)
            if (widget.nearbyDrivers.isNotEmpty)
              Builder(
                builder: (context) {
                  final center = _effectiveSearchCenter;
                  const distCalc = Distance();
                  final visibleDrivers = widget.showNearbyRadiusCircle
                      ? widget.nearbyDrivers.where((driver) {
                          if (center == null) return true;
                          final dist = distCalc.as(LengthUnit.Meter, driver.currentPosition, center);
                          return dist <= _effectiveSearchRadius;
                        }).toList()
                      : widget.nearbyDrivers;

                  final driversToRender = visibleDrivers.isNotEmpty ? visibleDrivers : widget.nearbyDrivers;
                  if (driversToRender.isEmpty) return const SizedBox.shrink();

                  return MarkerLayer(
                    markers: driversToRender.map((driver) {
                      final bool isSelected = widget.selectedDriverId == driver.id;
                      final double truckW = (20.0 * _zoomScale).clamp(10.0, 24.0);
                      final double truckH = (38.0 * _zoomScale).clamp(18.0, 44.0);
                      final double markerW = (54.0 * _zoomScale).clamp(26.0, 64.0);
                      final double markerH = (66.0 * _zoomScale).clamp(30.0, 76.0);

                      return Marker(
                        point: driver.currentPosition,
                        width: markerW,
                        height: markerH,
                        child: GestureDetector(
                          onTap: () {
                            if (widget.onDriverSelected != null) {
                              widget.onDriverSelected!(driver);
                            }
                          },
                          child: TopDownTruckWidget(
                            headingDegrees: driver.headingDegrees,
                            isSelected: isSelected,
                            cabinColor: isSelected ? AppColors.accent : AppColors.primary,
                            cargoColor: const Color(0xFFE2E8F0),
                            width: truckW,
                            height: truckH,
                            label: (isSelected && _currentZoom >= 13.5) ? 'Đã chọn' : null,
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),

            // Radar Pulse Effect at Pickup when searching
            if (widget.isRadarSearching && widget.points.isNotEmpty)
              MarkerLayer(
                markers: [
                  Marker(
                    point: widget.points.first.latLng,
                    width: 140,
                    height: 140,
                    child: AnimatedBuilder(
                      animation: _pulseController,
                      builder: (ctx, child) {
                        return Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.accent.withValues(
                              alpha: 0.22 * (1.2 - _pulseController.value),
                            ),
                            border: Border.all(
                              color: AppColors.accent.withValues(
                                alpha: 0.6 * (1.1 - _pulseController.value),
                              ),
                              width: 2.0,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),

            // Active Tracking Driver Marker (Top-down truck with headlights, scaled with zoom, no overlapping label)
            if (widget.activeDriver != null)
              MarkerLayer(
                markers: [
                  Marker(
                    point: widget.activeDriver!.currentPosition,
                    width: (58.0 * _zoomScale).clamp(28.0, 68.0),
                    height: (70.0 * _zoomScale).clamp(34.0, 80.0),
                    child: TopDownTruckWidget(
                      headingDegrees: widget.activeDriver!.headingDegrees,
                      isSelected: false,
                      isLiveTracking: true,
                      cabinColor: AppColors.accent,
                      cargoColor: const Color(0xFFF1F5F9),
                      width: (22.0 * _zoomScale).clamp(11.0, 26.0),
                      height: (40.0 * _zoomScale).clamp(20.0, 48.0),
                      label: null,
                    ),
                  ),
                ],
              ),

            // Location Points (Pickup & Dropoffs)
            MarkerLayer(
              markers: widget.points.map((pt) {
                final isPickup = pt.isPickup;
                final color = isPickup ? AppColors.primary : AppColors.accent;

                return Marker(
                  point: pt.latLng,
                  width: 42,
                  height: 42,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2.2),
                          boxShadow: [
                            BoxShadow(
                              color: color.withValues(alpha: 0.4),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Icon(
                          isPickup ? Icons.my_location_rounded : Icons.location_on_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),

        // 2. Nearby Driver Count Indicator (Bottom-left status chip)
        if (!widget.isMiniMap && widget.nearbyDrivers.isNotEmpty && _effectiveSearchCenter != null)
          Positioned(
            left: 14,
            bottom: widget.bottomControlsPadding ?? 14,
            child: Builder(
              builder: (context) {
                final center = _effectiveSearchCenter!;
                final radius = _effectiveSearchRadius;
                const distCalc = Distance();
                final count = widget.nearbyDrivers.where((d) {
                  return distCalc.as(LengthUnit.Meter, d.currentPosition, center) <= radius;
                }).length;

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.94),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
                    boxShadow: const [
                      BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2)),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: AppColors.success,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        widget.showNearbyRadiusCircle
                            ? 'Bán kính ${(radius / 1000).toStringAsFixed(1)}km: $count xe sẵn sàng'
                            : '${widget.nearbyDrivers.length} xe quanh khu vực',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

        // 3. Control Buttons (Zoom in, Zoom out, My Location, Follow Driver)
        if (!widget.isMiniMap)
          Positioned(
            right: 12,
            bottom: widget.bottomControlsPadding ?? 14,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.activeDriver != null) ...[
                  _buildMapButton(
                    Icons.navigation_rounded,
                    _moveToActiveDriver,
                    isHighlight: _userFollowingDriver,
                    tooltip: 'Bám theo tài xế',
                  ),
                  const SizedBox(height: 8),
                ],
                _buildMapButton(Icons.add_rounded, _zoomIn),
                const SizedBox(height: 6),
                _buildMapButton(Icons.remove_rounded, _zoomOut),
                const SizedBox(height: 8),
                _buildMapButton(Icons.my_location_rounded, _moveToCurrentLocation, isPrimary: true),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildMapButton(
    IconData icon,
    VoidCallback onTap, {
    bool isPrimary = false,
    bool isHighlight = false,
    String? tooltip,
  }) {
    Color bg = Colors.white;
    Color iconColor = AppColors.textPrimary;

    if (isHighlight) {
      bg = AppColors.accent;
      iconColor = Colors.white;
    } else if (isPrimary) {
      bg = AppColors.primary;
      iconColor = Colors.white;
    }

    return Tooltip(
      message: tooltip ?? '',
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: bg,
          shape: BoxShape.circle,
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2))],
        ),
        child: IconButton(
          padding: EdgeInsets.zero,
          icon: Icon(icon, color: iconColor, size: 18),
          onPressed: onTap,
        ),
      ),
    );
  }
}
