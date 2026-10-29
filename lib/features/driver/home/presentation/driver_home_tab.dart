import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/models/user_model.dart';
import '../../../../core/network/route_service.dart';
import '../../../../core/services/firestore_order_service.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/services/order_repository.dart';
import '../../../../core/services/audio_alert_service.dart';
import '../../../../core/services/call_service.dart';
import '../../../../core/widgets/app_avatar_widget.dart';
import '../../../../core/widgets/in_trip_chat_sheet.dart';
import '../../../../core/widgets/in_app_message_banner.dart';
import '../../../../core/widgets/incoming_call_dialog.dart';
import '../../../auth/data/auth_service.dart';
import '../../../customer/home/presentation/customer_main_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'driver_edit_profile_screen.dart';

class DriverHomeTab extends StatefulWidget {
  final UserModel user;
  final Function(UserModel)? onProfileUpdated;

  const DriverHomeTab({
    super.key,
    required this.user,
    this.onProfileUpdated,
  });

  @override
  State<DriverHomeTab> createState() => _DriverHomeTabState();
}

class _DriverHomeTabState extends State<DriverHomeTab> with SingleTickerProviderStateMixin {
  late UserModel _currentUser;
  bool _isOnline = true;
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;
  late final MapController _mapController;

  // Driver GPS coordinates (Central District 1, HCMC)
  LatLng _driverLocation = const LatLng(10.7750, 106.6980);
  double _driverBearing = 0.0;
  bool _isLoadingGps = false;
  StreamSubscription<Position>? _driverGpsStreamSub;

  // Active Trip State: null = waiting for order, non-null = active trip
  Map<String, dynamic>? _activeTrip;
  int _tripStep = 0; // 0: Moving to pickup, 1: Moving to dropoff, 2: Completed
  int _currentDropoffIndex = 0;
  final List<String> _collectedEpodPhotos = [];
  List<LatLng> _tripRouteCoords = [];

  // Google Maps Style Navigation & Dynamic Rerouting State
  List<RouteStep> _tripRouteSteps = [];
  double _tripRemainingDistanceKm = 0.0;
  int _tripRemainingDurationMinutes = 0;
  bool _isRerouting = false;
  DateTime? _lastRerouteTime;
  bool _isTripDetailsExpanded = false; // false = mini Google Maps HUD; true = expanded customer sheet

  // Real nearby orders from Firestore stream
  final List<Map<String, dynamic>> _nearbyOrders = [];
  bool _isNearbyOrdersCollapsed = false;
  double _selectedRadiusKm = 0.0; // 0.0 = Tất cả, 5.0 = ≤5km, 10.0 = ≤10km, 20.0 = ≤20km
  static const Distance _geoDistance = Distance();

  // Throttling state for Firestore GPS writes
  DateTime? _lastFirestorePushTime;
  LatLng? _lastFirestorePushLocation;

  List<Map<String, dynamic>> get _filteredNearbyOrders {
    if (_selectedRadiusKm <= 0) return _nearbyOrders;
    return _nearbyOrders.where((o) {
      if (o['isDirect'] == true) return true;
      final double dist = (o['distanceToPickupKm'] as num?)?.toDouble() ?? 0.0;
      return dist <= _selectedRadiusKm;
    }).toList();
  }

  void _recomputeNearbyOrderDistances() {
    for (final order in _nearbyOrders) {
      final coord = order['pickupCoord'];
      if (coord is LatLng) {
        order['distanceToPickupKm'] = double.parse(
          (_geoDistance.as(LengthUnit.Meter, _driverLocation, coord) / 1000.0).toStringAsFixed(1),
        );
      }
    }
    _nearbyOrders.sort((a, b) {
      final bool dirA = a['isDirect'] == true;
      final bool dirB = b['isDirect'] == true;
      if (dirA != dirB) return dirA ? -1 : 1;
      final double distA = (a['distanceToPickupKm'] as num?)?.toDouble() ?? 0.0;
      final double distB = (b['distanceToPickupKm'] as num?)?.toDouble() ?? 0.0;
      return distA.compareTo(distB);
    });
  }

  // Daily performance stats
  int _todayEarnings = 0;
  int _todayTripsCount = 0;
  int _todayTripMinutes = 0;
  int _depositBalance = 500000;
  late DateTime _sessionStartTime;

  StreamSubscription<List<Map<String, dynamic>>>? _availableOrdersSub;
  StreamSubscription<List<OrderRecord>>? _driverHistorySub;
  StreamSubscription<Map<String, dynamic>?>? _walletSub;
  StreamSubscription<List<Map<String, dynamic>>>? _driverChatSub;
  int _unreadDriverChatCount = 0;
  bool _isDriverChatOpen = false;
  String? _lastDriverMessageId;
  StreamSubscription<Map<String, dynamic>?>? _driverCallSub;
  Timer? _locationSyncTimer;
  String? _lastNotifiedOrderId;

  String get _onlineHoursLabel {
    final sessionMins = _isOnline ? DateTime.now().difference(_sessionStartTime).inMinutes : 0;
    final totalMins = _todayTripMinutes + sessionMins + (_todayTripsCount > 0 ? 45 : 15);
    final hours = totalMins / 60.0;
    return '${hours.toStringAsFixed(1)}h';
  }

  @override
  void initState() {
    super.initState();
    _currentUser = widget.user;
    _sessionStartTime = DateTime.now();
    _mapController = MapController();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.35).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _initDriverLocation();
    _initDriverOrderStream();
    _startDriverLocationSync();
  }

  @override
  void didUpdateWidget(DriverHomeTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.user != oldWidget.user) {
      _currentUser = widget.user;
    }
  }

  void _initDriverOrderStream() {
    _availableOrdersSub?.cancel();
    _driverHistorySub?.cancel();
    _walletSub?.cancel();
    final driverId = _currentUser.id.isNotEmpty
        ? _currentUser.id
        : (_currentUser.phone.isNotEmpty ? _currentUser.phone : 'drv_02');

    _walletSub = FirestoreOrderService.streamDriverWallet(driverId).listen((data) {
      if (!mounted || data == null) return;
      final cloudDeposit = (data['deposit_balance'] as num?)?.toInt();
      if (cloudDeposit != null) {
        setState(() => _depositBalance = cloudDeposit);
      }
    }, onError: (e) {
      debugPrint('>>> [DriverHomeTab _walletSub error]: $e');
    });

    // 1. Lắng nghe lịch sử đơn để tính thu nhập thực tế hôm nay & khôi phục đơn đang chạy (nếu có)
    _driverHistorySub = FirestoreOrderService.streamDriverOrderHistory(driverId).listen((orders) {
      if (!mounted) return;
      final now = DateTime.now();
      final completedToday = orders.where((o) {
        if (o.status != OrderStatus.completed) return false;
        final t = o.completedAt ?? o.createdAt;
        return t.year == now.year && t.month == now.month && t.day == now.day;
      }).toList();

      final int earnings = completedToday.fold<int>(0, (sum, o) => sum + (o.originalFee ?? o.totalFee));
      final int tripMins = completedToday.fold<int>(0, (sum, o) => sum + (o.durationMinutes > 0 ? o.durationMinutes : 20));
      setState(() {
        _todayEarnings = earnings;
        _todayTripsCount = completedToday.length;
        _todayTripMinutes = tripMins;
      });

      // Tự động khôi phục chuyến xe đang giao (OrderStatus.delivering) nếu tài xế vừa mở lại app hoặc chuyển tab
      if (_activeTrip == null) {
        final activeDelivering = orders.where((o) => o.status == OrderStatus.delivering).toList();
        if (activeDelivering.isNotEmpty) {
          final active = activeDelivering.first;
          final LatLng pCoord = LatLng(active.pickupLat ?? 10.7725, active.pickupLng ?? 106.6980);
          final List<LatLng> dCoords = [];
          if (active.dropoffLats != null && active.dropoffLngs != null) {
            for (int i = 0; i < active.dropoffLats!.length && i < active.dropoffLngs!.length; i++) {
              dCoords.add(LatLng(active.dropoffLats![i], active.dropoffLngs![i]));
            }
          }
          if (dCoords.isEmpty) dCoords.add(const LatLng(10.7850, 106.7450));

          setState(() {
            _activeTrip = {
              'id': active.orderCode,
              'orderCode': active.orderCode,
              'pickup': active.pickupAddress,
              'dropoff': active.dropoffAddresses.join(' -> '),
              'dropoffAddresses': active.dropoffAddresses,
              'pickupCoord': pCoord,
              'dropoffCoord': dCoords.first,
              'dropoffCoords': dCoords,
              'fee': '${active.totalFee.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')} đ',
              'rawFee': active.totalFee,
              'originalFee': active.originalFee ?? active.totalFee,
              'discountAmount': active.discountAmount,
              'paymentMethod': active.paymentMethod,
              'distance': '${active.distanceKm} km',
              'customer': active.senderName.isNotEmpty ? active.senderName : 'Khách hàng GoShip',
              'phone': active.senderPhone,
              'recipientName': active.recipientName,
              'recipientPhone': active.recipientPhone,
              'package': '${active.packageCategory} (${active.weightCategory})',
              'packageCategory': active.packageCategory,
              'weightCategory': active.weightCategory,
              'vehicleName': active.vehicleName,
              'driverNote': active.driverNote,
              'dropoffRecipients': active.dropoffRecipients.map((r) => r.toJson()).toList(),
            };
            _tripRouteCoords = [
              _driverLocation,
              pCoord,
              ...dCoords,
            ];
          });
          _updateTripRoute();
          _initTripChatListener(active.orderCode);
          _initDriverCallListener(active.orderCode);
        }
      }
    }, onError: (e) {
      debugPrint('>>> [DriverHomeTab _driverHistorySub error]: $e');
    });

    // 2. Lắng nghe đơn hàng mới khả dụng quanh tài xế
    _availableOrdersSub = FirestoreOrderService.streamAvailableOrdersForDriver(
      driverId: driverId,
      driverLocation: _driverLocation,
    ).listen((orders) {
      if (!mounted) return;
      debugPrint('>>> [DriverHomeTab]: Driver $driverId stream received ${orders.length} available orders from Firestore');
      setState(() {
        _nearbyOrders.clear();
        _nearbyOrders.addAll(orders);
        _recomputeNearbyOrderDistances();
      });

      // If driver is online and has no active trip, automatically notify for new orders
      final visibleOrders = _filteredNearbyOrders;
      if (_isOnline && _activeTrip == null && visibleOrders.isNotEmpty) {
        // Priority: Direct order specifically to this driver, otherwise first available
        final directOrder = visibleOrders.firstWhere(
          (o) => o['isDirect'] == true,
          orElse: () => {},
        );

        final targetOrder = directOrder.isNotEmpty ? directOrder : visibleOrders.first;

        if (targetOrder['id'] != _lastNotifiedOrderId) {
          _lastNotifiedOrderId = targetOrder['id'];
          if (targetOrder['pickupCoord'] is LatLng) {
            _mapController.move(targetOrder['pickupCoord'] as LatLng, 14.5);
          }
          _showIncomingOrderSheet(targetOrder);
        }
      }
    }, onError: (e) {
      debugPrint('>>> [DriverHomeTab _initDriverOrderStream error]: $e');
    });
  }

  void _startDriverLocationSync() {
    _locationSyncTimer?.cancel();
    _driverGpsStreamSub?.cancel();

    final driverId = _currentUser.id.isNotEmpty
        ? _currentUser.id
        : (_currentUser.phone.isNotEmpty ? _currentUser.phone : 'drv_02');

    void pushLocation([LatLng? loc, double? bearing]) {
      if (!_isOnline) return;
      final targetLoc = loc ?? _driverLocation;
      final targetBearing = bearing ?? _driverBearing;
      _lastFirestorePushTime = DateTime.now();
      _lastFirestorePushLocation = targetLoc;
      FirestoreOrderService.updateDriverLocation(
        driverId: driverId,
        driverName: _currentUser.name,
        phone: _currentUser.phone,
        plateNumber: _currentUser.plateNumber ?? '51D 892.14',
        vehicleType: _currentUser.vehicleType ?? 'Xe Bán tải',
        vehicleName: _currentUser.vehicleType ?? 'Xe Bán tải Ranger',
        location: targetLoc,
        bearing: targetBearing,
        isOnline: _isOnline,
        activeOrderId: _activeTrip != null ? _activeTrip!['id'] : null,
      );
    }

    pushLocation();
    _locationSyncTimer = Timer.periodic(const Duration(seconds: 10), (_) => pushLocation());

    // Luồng GPS thời gian thực từ chip GPS phần cứng (cập nhật UI ngay lập tức, throttle ghi Firestore tối đa 4s/lần hoặc khi di chuyển >= 15m)
    _driverGpsStreamSub = LocationService.getPositionStream(distanceFilterMeters: 5)?.listen((pos) {
      if (!mounted) return;
      final newLoc = LatLng(pos.latitude, pos.longitude);
      final double newBearing = (pos.heading > 0 && pos.heading <= 360) ? pos.heading : _driverBearing;
      setState(() {
        _driverLocation = newLoc;
        _driverBearing = newBearing;
        if (_nearbyOrders.isNotEmpty) {
          _recomputeNearbyOrderDistances();
        }
      });

      final now = DateTime.now();
      final bool timeElapsed = _lastFirestorePushTime == null ||
          now.difference(_lastFirestorePushTime!).inMilliseconds >= 4000;
      final bool movedSignificantly = _lastFirestorePushLocation == null ||
          _geoDistance.as(LengthUnit.Meter, _lastFirestorePushLocation!, newLoc) >= 15.0;

      if (timeElapsed || movedSignificantly) {
        pushLocation(newLoc, newBearing);
      }

      // Khi đang thực hiện chuyến xe, tự động phát hiện lệch đường và tính lại lộ trình (Dynamic Rerouting)
      if (_activeTrip != null && _tripRouteCoords.length >= 2) {
        final double offRouteDist = _distanceToPolyline(newLoc, _tripRouteCoords);
        final bool canReroute = !_isRerouting &&
            (_lastRerouteTime == null || now.difference(_lastRerouteTime!).inSeconds >= 6);

        if (offRouteDist > 40.0 && canReroute) {
          debugPrint('>>> [Dynamic Rerouting]: Lệch khỏi lộ trình ${offRouteDist.toStringAsFixed(1)}m -> Tự động tìm đường mới...');
          _updateTripRoute(isReroute: true);
        } else {
          _updateTripProgress(newLoc);
        }
      }
    }, onError: (err) {
      debugPrint('>>> [_driverGpsStreamSub error]: $err');
    });
  }

  void _toggleOnlineStatus(bool val) {
    if (val && _currentUser.accountStatus == 'locked') {
      _showNotification(
        'Tài khoản đối tác của bạn đang bị tạm khóa bởi Quản trị viên GoShip. Không thể bật Trực tuyến.',
        backgroundColor: AppColors.danger,
      );
      return;
    }
    setState(() {
      _isOnline = val;
      if (val) _sessionStartTime = DateTime.now();
    });
    final driverId = _currentUser.id.isNotEmpty
        ? _currentUser.id
        : (_currentUser.phone.isNotEmpty ? _currentUser.phone : 'drv_02');

    if (!val) {
      _driverGpsStreamSub?.cancel();
      _locationSyncTimer?.cancel();
    } else {
      _startDriverLocationSync();
    }

    FirestoreOrderService.updateDriverLocation(
      driverId: driverId,
      driverName: _currentUser.name,
      phone: _currentUser.phone,
      plateNumber: _currentUser.plateNumber ?? '51D 892.14',
      vehicleType: _currentUser.vehicleType ?? 'Xe Bán tải',
      vehicleName: _currentUser.vehicleType ?? 'Xe Bán tải Ranger',
      location: _driverLocation,
      bearing: _driverBearing,
      isOnline: val,
      activeOrderId: _activeTrip != null ? _activeTrip!['id'] : null,
    );
  }

  Future<void> _initDriverLocation() async {
    setState(() => _isLoadingGps = true);
    final gps = await LocationService.getCurrentLocation();
    if (mounted) {
      setState(() {
        if (gps != null) {
          _driverLocation = gps;
        }
        _isLoadingGps = false;
      });
      _mapController.move(_driverLocation, 14.8);
    }
  }

  @override
  void dispose() {
    _driverGpsStreamSub?.cancel();
    _availableOrdersSub?.cancel();
    _driverHistorySub?.cancel();
    _walletSub?.cancel();
    _clearTripChatListener();
    _locationSyncTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _recenterMap() {
    _mapController.move(_driverLocation, 15.5);
  }

  void _zoomIn() {
    _mapController.move(_mapController.camera.center, _mapController.camera.zoom + 1);
  }

  void _zoomOut() {
    _mapController.move(_mapController.camera.center, _mapController.camera.zoom - 1);
  }

  void _showNotification(
    String message, {
    Color backgroundColor = AppColors.primary,
    Duration duration = const Duration(milliseconds: 2500),
  }) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();

    // Vị trí nổi cách đáy màn hình vừa vặn phía trên thẻ thông tin, không bị lơ lửng giữa màn hình
    final double bottomMargin = _activeTrip != null
        ? (_isTripDetailsExpanded ? 340.0 : 96.0)
        : 90.0;

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.white),
        ),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.only(bottom: bottomMargin, left: 16, right: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: duration,
        elevation: 6,
      ),
    );
  }

  List<LatLng> _getTripDropoffCoords() {
    if (_activeTrip == null) return [];
    if (_activeTrip!['dropoffCoords'] is List<LatLng>) {
      final list = _activeTrip!['dropoffCoords'] as List<LatLng>;
      if (list.isNotEmpty) return list;
    }
    if (_activeTrip!['dropoffCoord'] is LatLng) {
      return [_activeTrip!['dropoffCoord'] as LatLng];
    }
    return [];
  }

  List<String> _getTripDropoffAddresses() {
    if (_activeTrip == null) return [];
    if (_activeTrip!['dropoffAddresses'] is List) {
      final list = List<String>.from(_activeTrip!['dropoffAddresses']);
      if (list.isNotEmpty) return list;
    }
    final d = _activeTrip!['dropoff']?.toString() ?? '';
    if (d.contains(' -> ')) {
      return d.split(' -> ');
    }
    return [d];
  }

  String _getCurrentDropoffAddress() {
    final list = _getTripDropoffAddresses();
    if (_currentDropoffIndex < list.length) {
      return list[_currentDropoffIndex];
    }
    return _activeTrip?['dropoff'] ?? '';
  }

  Map<String, dynamic>? _getCurrentDropoffRecipient() {
    if (_activeTrip == null) return null;
    final recs = _activeTrip!['dropoffRecipients'];
    if (recs is List && _currentDropoffIndex < recs.length && recs[_currentDropoffIndex] is Map) {
      return Map<String, dynamic>.from(recs[_currentDropoffIndex] as Map);
    }
    return null;
  }

  /// Tính khoảng cách ngắn nhất từ điểm [p] đến đoạn thẳng [a -> b]
  double _distanceToSegment(LatLng p, LatLng a, LatLng b) {
    final double x = p.longitude;
    final double y = p.latitude;
    final double x1 = a.longitude;
    final double y1 = a.latitude;
    final double x2 = b.longitude;
    final double y2 = b.latitude;

    final double dx = x2 - x1;
    final double dy = y2 - y1;
    final double lenSq = dx * dx + dy * dy;

    if (lenSq == 0) {
      return _geoDistance.as(LengthUnit.Meter, p, a);
    }

    final double t = (((x - x1) * dx + (y - y1) * dy) / lenSq).clamp(0.0, 1.0);
    final LatLng projection = LatLng(y1 + t * dy, x1 + t * dx);
    return _geoDistance.as(LengthUnit.Meter, p, projection);
  }

  /// Tính khoảng cách ngắn nhất từ vị trí tài xế [p] đến toàn bộ tuyến đường [polyline]
  double _distanceToPolyline(LatLng p, List<LatLng> polyline) {
    if (polyline.isEmpty) return double.infinity;
    if (polyline.length == 1) return _geoDistance.as(LengthUnit.Meter, p, polyline.first);

    double minDist = double.infinity;
    for (int i = 0; i < polyline.length - 1; i++) {
      final d = _distanceToSegment(p, polyline[i], polyline[i + 1]);
      if (d < minDist) {
        minDist = d;
      }
    }
    return minDist;
  }

  /// Tự động tính toán lại lộ trình chỉ đường turn-by-turn khi tài xế rẽ đường khác (Dynamic Rerouting)
  Future<void> _updateTripRoute({bool isReroute = false}) async {
    if (_activeTrip == null) return;
    if (_isRerouting) return;

    _isRerouting = true;
    if (mounted) setState(() {});

    try {
      final LatLng currentLoc = _driverLocation;
      List<LatLng> waypoints = [];

      if (_tripStep == 0) {
        // Đang di chuyển đến điểm lấy hàng
        final pickup = _activeTrip!['pickupCoord'] as LatLng;
        waypoints = [currentLoc, pickup];
      } else {
        // Đang giao hàng: điểm đến là dropoff hiện tại và các dropoff tiếp theo (nếu có)
        final drops = _getTripDropoffCoords();
        if (_currentDropoffIndex < drops.length) {
          final currentDrop = drops[_currentDropoffIndex];
          final remainingDrops = drops.sublist(_currentDropoffIndex + 1);
          waypoints = [currentLoc, currentDrop, ...remainingDrops];
        } else if (drops.isNotEmpty) {
          waypoints = [currentLoc, drops.last];
        } else if (_activeTrip!['dropoffCoord'] is LatLng) {
          waypoints = [currentLoc, _activeTrip!['dropoffCoord'] as LatLng];
        }
      }

      if (waypoints.length >= 2) {
        final routeRes = await RouteService.getDrivingRoute(waypoints);
        if (mounted && routeRes.polylinePoints.isNotEmpty) {
          setState(() {
            _tripRouteCoords = routeRes.polylinePoints;
            _tripRemainingDistanceKm = routeRes.distanceKm;
            _tripRemainingDurationMinutes = routeRes.durationMinutes;
            _tripRouteSteps = List<RouteStep>.from(routeRes.steps);
            _lastRerouteTime = DateTime.now();
          });

          if (isReroute) {
            _showNotification(
              'Đã tự động tính lại lộ trình mới tối ưu cho bạn!',
              backgroundColor: const Color(0xFF0F5132),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('>>> [_updateTripRoute Error]: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isRerouting = false;
        });
      }
    }
  }

  /// Cập nhật tiến độ chuyến đi và loại bỏ các bước chỉ đường đã vượt qua
  void _updateTripProgress(LatLng currentLoc) {
    if (_activeTrip == null) return;
    final LatLng target = _tripStep == 0
        ? (_activeTrip!['pickupCoord'] as LatLng)
        : (_getTripDropoffCoords().isNotEmpty
            ? _getTripDropoffCoords()[_currentDropoffIndex.clamp(0, _getTripDropoffCoords().length - 1)]
            : (_activeTrip!['dropoffCoord'] as LatLng));

    final double distKm = _geoDistance.as(LengthUnit.Meter, currentLoc, target) / 1000.0;
    _tripRemainingDistanceKm = double.parse(distKm.toStringAsFixed(1));
    _tripRemainingDurationMinutes = (_tripRemainingDistanceKm * 3.0).round().clamp(1, 180);

    // Loại bỏ bước rẽ kế tiếp nếu tài xế đã di chuyển qua vị trí rẽ (khoảng cách < 25m)
    if (_tripRouteSteps.length > 1) {
      final double distToFirstStep = _geoDistance.as(LengthUnit.Meter, currentLoc, _tripRouteSteps.first.location);
      if (distToFirstStep < 25.0) {
        _tripRouteSteps.removeAt(0);
      }
    }
    if (mounted) setState(() {});
  }

  /// Mở ứng dụng Google Maps chính thức để điều hướng bằng giọng nói
  // ignore: unused_element
  Future<void> _openExternalGoogleMapsNavigation() async {
    if (_activeTrip == null) return;
    final LatLng target = _tripStep == 0
        ? (_activeTrip!['pickupCoord'] as LatLng)
        : (_getTripDropoffCoords().isNotEmpty
            ? _getTripDropoffCoords()[_currentDropoffIndex.clamp(0, _getTripDropoffCoords().length - 1)]
            : (_activeTrip!['dropoffCoord'] as LatLng));

    final String lat = target.latitude.toString();
    final String lng = target.longitude.toString();

    // 1. Android/iOS native Google Maps navigation intent
    final Uri navUri = Uri.parse('google.navigation:q=$lat,$lng&mode=d');
    // 2. Fallback Google Maps directions URL
    final Uri webUri = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving');

    try {
      if (await canLaunchUrl(navUri)) {
        await launchUrl(navUri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('>>> [_openExternalGoogleMapsNavigation Error]: $e');
      try {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      } catch (_) {}
    }
  }

  /// Google Maps Navigation HUD Banner ở trên cùng
  Widget _buildGoogleMapsNavigationHUD() {
    final totalDrops = _getTripDropoffCoords().length;
    final String destinationAddress = _tripStep == 0
        ? (_activeTrip!['pickup'] ?? 'Điểm lấy hàng')
        : _getCurrentDropoffAddress();

    // Lấy bước hướng dẫn rẽ kế tiếp (Maneuver step)
    final RouteStep? nextStep = _tripRouteSteps.isNotEmpty ? _tripRouteSteps.first : null;
    final String instructionText = nextStep != null && nextStep.instruction.isNotEmpty
        ? nextStep.instruction
        : (_tripStep == 0
            ? 'Sau ${_tripRemainingDistanceKm}km đến điểm lấy hàng'
            : (totalDrops > 1
                ? 'Sau ${_tripRemainingDistanceKm}km đến Điểm ${_currentDropoffIndex + 1}/$totalDrops'
                : 'Sau ${_tripRemainingDistanceKm}km đến điểm giao hàng'));

    final String subText = nextStep != null && nextStep.streetName.isNotEmpty
        ? nextStep.streetName
        : destinationAddress;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0F5132), // Màu xanh biển chỉ đường Google Maps navigation
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Colors.black38, blurRadius: 12, offset: Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          // Icon rẽ kiểu Google Maps
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _getManeuverIcon(nextStep),
              color: Colors.white,
              size: 26,
            ),
          ),
          const SizedBox(width: 12),
          // Hướng dẫn rẽ & Tên đường/Điểm đến
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  instructionText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                    height: 1.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  subText,
                  style: const TextStyle(
                    color: Color(0xFF86EFAC),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Nút bấm tìm lại đường thủ công
          InkWell(
            onTap: () => _updateTripRoute(isReroute: true),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: _isRerouting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh_rounded, color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getManeuverIcon(RouteStep? step) {
    if (step == null) return Icons.navigation_rounded;
    final mod = step.maneuverModifier?.toLowerCase() ?? '';
    final type = step.maneuverType.toLowerCase();

    if (mod.contains('left')) {
      return Icons.turn_left_rounded;
    } else if (mod.contains('right')) {
      return Icons.turn_right_rounded;
    } else if (mod.contains('uturn')) {
      return Icons.u_turn_left_rounded;
    } else if (type == 'arrive') {
      return Icons.location_on_rounded;
    } else if (type == 'depart') {
      return Icons.navigation_rounded;
    }
    return Icons.straight_rounded;
  }

  Future<void> _acceptOrder(Map<String, dynamic> order) async {
    final int grossFee = (order['originalFee'] as num?)?.toInt() ?? (order['rawFee'] as num?)?.toInt() ?? 50000;
    final int requiredDeposit = (grossFee * 0.15).round();
    if (_depositBalance < requiredDeposit && _depositBalance < 20000) {
      _showNotification(
        'Số dư Ví ký quỹ ($_depositBalanceđ) không đủ mức tối thiểu ($requiredDepositđ) để nhận cuốc này. Vui lòng nạp thêm ở tab Ví!',
        backgroundColor: AppColors.danger,
      );
      return;
    }

    final driverId = _currentUser.id.isNotEmpty
        ? _currentUser.id
        : (_currentUser.phone.isNotEmpty ? _currentUser.phone : 'drv_02');

    final bool ok = await FirestoreOrderService.acceptOrder(
      orderCode: order['id'] ?? order['orderCode'],
      driverId: driverId,
      driverName: _currentUser.name.isNotEmpty ? _currentUser.name : 'Driver 01',
      driverPhone: _currentUser.phone.isNotEmpty ? _currentUser.phone : '0917795211',
      plateNumber: _currentUser.plateNumber ?? '59P1-987.65',
      vehicleName: _currentUser.vehicleType ?? 'Xe Bán tải Ranger',
    );

    if (!ok) {
      if (mounted) {
        final orderId = order['id'] ?? order['orderCode'];
        setState(() {
          _nearbyOrders.removeWhere((o) => (o['id'] ?? o['orderCode']) == orderId);
        });
        _showNotification('Đơn hàng này đã có tài xế khác tiếp nhận.', backgroundColor: AppColors.danger);
      }
      return;
    }

    final List<LatLng> dropCoords = [];
    if (order['dropoffCoords'] is List<LatLng>) {
      dropCoords.addAll(order['dropoffCoords'] as List<LatLng>);
    } else if (order['dropoffCoord'] is LatLng) {
      dropCoords.add(order['dropoffCoord'] as LatLng);
    }

    setState(() {
      _activeTrip = order;
      _tripStep = 0; // 0: Moving to pickup
      _currentDropoffIndex = 0;
      _collectedEpodPhotos.clear();
      _isTripDetailsExpanded = false;
      _tripRouteCoords = [
        _driverLocation,
        order['pickupCoord'] as LatLng,
        ...dropCoords,
      ];
    });

    // Tính toán lộ trình thực tế kèm các bước chỉ đường Google Maps navigation
    await _updateTripRoute();

    _mapController.move(order['pickupCoord'] as LatLng, 15.5);

    _initTripChatListener(order['id']?.toString() ?? order['orderCode']?.toString() ?? '');
    _initDriverCallListener(order['id']?.toString() ?? order['orderCode']?.toString() ?? '');

    _showNotification('Bạn đã nhận đơn ${order['id']}. Bắt đầu điều hướng đến điểm lấy hàng.', backgroundColor: AppColors.success);
  }

  void _initTripChatListener(String orderCode) {
    _driverChatSub?.cancel();
    _lastDriverMessageId = null;
    _unreadDriverChatCount = 0;
    bool isFirstSnapshot = true;

    _driverChatSub = FirestoreOrderService.streamOrderChatMessages(orderCode).listen((messages) {
      if (!mounted || messages.isEmpty || _activeTrip == null) {
        isFirstSnapshot = false;
        return;
      }

      final lastMsg = messages.last;
      final String msgId = lastMsg['id']?.toString() ?? '';
      final String senderRole = lastMsg['senderRole']?.toString() ?? '';

      if (isFirstSnapshot) {
        isFirstSnapshot = false;
        _lastDriverMessageId = msgId;
        return;
      }

      // Chỉ thông báo nếu tin nhắn mới là từ phía khách hàng
      if (senderRole != 'driver' && msgId.isNotEmpty && msgId != _lastDriverMessageId) {
        _lastDriverMessageId = msgId;

        if (_isDriverChatOpen) {
          return;
        }

        setState(() {
          _unreadDriverChatCount++;
        });

        final senderName = lastMsg['senderName']?.toString() ?? (_activeTrip!['customer'] ?? 'Khách hàng');
        final text = lastMsg['text']?.toString() ?? '';

        InAppMessageNotification.show(
          context,
          senderName: senderName,
          senderRole: 'Khách hàng',
          messageText: text,
          onTap: _openDriverInTripChat,
        );
      }
    });
  }

  void _initDriverCallListener(String orderCode) {
    _driverCallSub?.cancel();
    _driverCallSub = FirestoreOrderService.streamOrderCallState(orderCode).listen((callState) {
      if (!mounted || callState == null || _activeTrip == null) return;

      final String status = callState['status']?.toString() ?? '';
      final String callerRole = callState['caller_role']?.toString() ?? '';

      // Khi khách hàng gọi đến tài xế và đang đổ chuông
      if (status == 'ringing' && callerRole == 'customer') {
        final callerName = callState['caller_name']?.toString() ?? (_activeTrip!['customer'] ?? 'Khách hàng');
        final callerPhone = _activeTrip!['phone'] ?? '';

        final callId = callState['id']?.toString();

        IncomingCallDialog.show(
          context,
          orderCode: orderCode,
          callerName: callerName,
          callerRole: 'Khách hàng nhận đơn',
          callerPhone: callerPhone,
          callId: callId,
        );
      }
    });
  }

  void _clearTripChatListener() {
    _driverChatSub?.cancel();
    _driverChatSub = null;
    _driverCallSub?.cancel();
    _driverCallSub = null;
    _unreadDriverChatCount = 0;
    _lastDriverMessageId = null;
    InAppMessageNotification.dismiss();
  }

  Future<void> _openDriverInTripChat() async {
    if (_activeTrip == null) return;
    InAppMessageNotification.dismiss();
    setState(() {
      _isDriverChatOpen = true;
      _unreadDriverChatCount = 0;
    });

    await InTripChatSheet.show(
      context,
      orderCode: _activeTrip!['id'].toString(),
      currentUserId: _currentUser.id.isNotEmpty ? _currentUser.id : (_currentUser.phone.isNotEmpty ? _currentUser.phone : 'drv_02'),
      currentUserName: _currentUser.name.isNotEmpty ? _currentUser.name : 'Bác tài GoShip',
      currentUserRole: 'driver',
      otherPartyName: _activeTrip!['customer'] ?? 'Khách hàng',
      otherPartyPhone: _activeTrip!['phone'] ?? '',
      otherPartyRole: 'Khách hàng',
    );

    if (mounted) {
      setState(() {
        _isDriverChatOpen = false;
        _unreadDriverChatCount = 0;
      });
    }
  }

  void _showIncomingOrderSheet(Map<String, dynamic> order) {
    AudioAlertService.playNewOrderAlert();
    final bool isDirect = order['isDirect'] == true;
    final String vehicleName = order['vehicleName'] ?? 'Xe Bán tải';
    final String packageCategory = order['packageCategory'] ?? order['package'] ?? 'Hàng tiêu chuẩn';
    final String weightCategory = order['weightCategory'] ?? '<100kg';
    final String itemsDetail = order['itemsDetail']?.toString().trim() ?? '';
    final String dimensions = order['dimensions']?.toString().trim() ?? '';
    final String driverNote = order['driverNote']?.toString().trim() ?? '';
    final String paymentMethod = order['paymentMethod']?.toString() ?? 'Tiền mặt';
    final bool isCash = paymentMethod.toLowerCase().contains('tiền mặt') ||
        paymentMethod.toLowerCase().contains('cash') ||
        paymentMethod.toLowerCase().contains('cod');
    final int discountAmt = (order['discountAmount'] as num?)?.toInt() ?? 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (isDirect) ...[
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7ED),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.verified_user_rounded, color: AppColors.accent, size: 18),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '⭐ Khách hàng chỉ định riêng bạn cho cuốc này (Ưu tiên 45s)',
                          style: TextStyle(color: Color(0xFF9A3412), fontWeight: FontWeight.w700, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isDirect ? const Color(0xFFFFF7ED) : const Color(0xFFEFF6FF),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isDirect ? Icons.star_rounded : Icons.notifications_active_rounded,
                            color: isDirect ? AppColors.accent : AppColors.primary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isDirect ? 'Cuốc xe chỉ định cho bạn' : 'Đơn hàng mới gần bạn',
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.textPrimary),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                'Khách hàng: ${order['customer'] ?? 'GoShip User'}',
                                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        order['fee'],
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: AppColors.accent),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isCash ? const Color(0xFFFFF7ED) : const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isCash ? AppColors.accent.withValues(alpha: 0.4) : AppColors.success.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Text(
                          isCash ? '💵 Thu tiền mặt' : '💳 Đã trả $paymentMethod',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: isCash ? const Color(0xFFC2410C) : AppColors.success,
                          ),
                        ),
                      ),
                      if (discountAmt > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            'Trợ giá +${discountAmt ~/ 1000}k đ',
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.primary),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              const Divider(height: 24),

              // Route Preview
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 3),
                    child: Icon(Icons.circle, color: AppColors.primary, size: 10),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Lấy hàng: ${order['pickup']}',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Icon(Icons.location_on, color: AppColors.accent, size: 12),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Giao hàng: ${order['dropoff']}',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // CHI TIẾT HÀNG HÓA VÀ PHƯƠNG TIỆN YÊU CẦU
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Hàng huy hiệu thông số: Xe, Tải trọng, Quãng đường, Khoảng cách lấy hàng
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFECFDF5),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFA7F3D0)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.near_me_rounded, size: 13, color: Color(0xFF059669)),
                              const SizedBox(width: 4),
                              Text(
                                'Cách ${order['distanceToPickupKm'] ?? 0.0} km',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF059669)),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.local_shipping_outlined, size: 14, color: AppColors.primary),
                              const SizedBox(width: 4),
                              Text(
                                vehicleName,
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.fitness_center_rounded, size: 13, color: Color(0xFF475569)),
                              const SizedBox(width: 4),
                              Text(
                                weightCategory,
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.straighten_rounded, size: 14, color: AppColors.textSecondary),
                              const SizedBox(width: 4),
                              Text(
                                order['distance'] ?? '',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 16),

                    // Loại hàng & Chi tiết từng món
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.inventory_2_rounded, size: 16, color: Color(0xFF64748B)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                packageCategory,
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                              ),
                              if (itemsDetail.isNotEmpty) ...[
                                const SizedBox(height: 3),
                                Text(
                                  'Mô tả món hàng: $itemsDetail',
                                  style: const TextStyle(fontSize: 12, color: Color(0xFF1E293B), fontWeight: FontWeight.w500),
                                ),
                              ],
                              if (dimensions.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  'Kích thước kiện: $dimensions',
                                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),

                    // Lưu ý của khách hàng cho bác tài
                    if (driverNote.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFBEB),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFFDE68A)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.comment_outlined, size: 14, color: Color(0xFFD97706)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Lưu ý: "$driverNote"',
                                style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Color(0xFF92400E)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Actions: Reject / Accept
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        final orderId = (order['id'] ?? order['orderCode'] ?? '').toString();
                        final driverId = widget.user.id.isNotEmpty
                            ? widget.user.id
                            : (widget.user.phone.isNotEmpty ? widget.user.phone : 'drv_02');
                        if (isDirect && orderId.isNotEmpty) {
                          FirestoreOrderService.cancelOrderByDriver(
                            orderCode: orderId,
                            driverId: driverId,
                            reason: 'Tài xế bỏ qua cuốc chỉ định',
                            returnToMarket: true,
                          );
                        }
                      },
                      child: const Text('Bỏ qua', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _acceptOrder(order);
                      },
                      child: const Text(
                        'Nhận chuyến ngay',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _nextTripStep() {
    if (_activeTrip == null) return;

    if (_tripStep == 0) {
      // Arrived at pickup -> Open Pickup Goods Photo Capture Modal
      _showPickupPhotoCaptureModal();
    } else if (_tripStep == 1) {
      // Arrived at dropoff -> Open e-POD Camera Capture Modal for current dropoff point
      final dropCoords = _getTripDropoffCoords();
      final totalDropoffs = dropCoords.isNotEmpty ? dropCoords.length : 1;
      _showEpodCaptureModal(
        dropoffIndex: _currentDropoffIndex,
        totalDropoffs: totalDropoffs,
      );
    }
  }

  void _showDriverCancelTripDialog() {
    if (_activeTrip == null) return;
    final orderId = _activeTrip!['id'].toString();
    final driverId = widget.user.id.isNotEmpty
        ? widget.user.id
        : (widget.user.phone.isNotEmpty ? widget.user.phone : 'drv_02');

    String selectedReason = 'Khách không nhấc máy sau nhiều lần gọi';
    final List<String> reasons = [
      'Khách không nhấc máy sau nhiều lần gọi',
      'Hàng cồng kềnh vượt tải trọng/kích thước xe',
      'Khách chủ động gọi xin hủy cuốc',
      'Xe gặp sự cố kỹ thuật trên đường',
      'Khu vực điểm lấy hàng bị cấm tải / phong tỏa',
      'Khác...',
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
              child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4.5,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: AppColors.danger, size: 24),
                    SizedBox(width: 8),
                    Text(
                      'Hủy cuốc xe đã nhận',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Lưu ý: Hủy cuốc có thể ảnh hưởng đến tỷ lệ chấp nhận chuyến. Cuốc xe sẽ được tự động hoàn lại hệ thống để tài xế khác nhận.',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4),
                ),
                const SizedBox(height: 14),
                ...reasons.map((r) {
                  final isSelected = selectedReason == r;
                  return InkWell(
                    onTap: () => setModalState(() => selectedReason = r),
                    borderRadius: BorderRadius.circular(10),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                      child: Row(
                        children: [
                          Icon(
                            isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                            color: isSelected ? AppColors.danger : const Color(0xFF94A3B8),
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              r,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                color: isSelected ? AppColors.textPrimary : const Color(0xFF475569),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Tiếp tục cuốc xe', style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.danger,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        onPressed: () async {
                          Navigator.pop(ctx);
                          await FirestoreOrderService.cancelOrderByDriver(
                            orderCode: orderId,
                            driverId: driverId,
                            reason: selectedReason,
                            returnToMarket: true,
                          );

                          setState(() {
                            _activeTrip = null;
                            _tripStep = 0;
                            _tripRouteCoords = [];
                            _tripRouteSteps = [];
                            _tripRemainingDistanceKm = 0.0;
                            _tripRemainingDurationMinutes = 0;
                            _isTripDetailsExpanded = false;
                          });

                          _clearTripChatListener();

                          _showNotification(
                            'Đã hủy cuốc $orderId và hoàn trả về hệ thống đơn chung.',
                            backgroundColor: AppColors.textPrimary,
                          );
                        },
                        child: const Text('Xác nhận hủy', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

  void _showPickupPhotoCaptureModal() {
    if (_activeTrip == null) return;
    final trip = _activeTrip!;
    final ImagePicker picker = ImagePicker();
    final List<dynamic> capturedPhotos = [];
    int selectedPreviewIdx = 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (modalCtx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final int photoCount = capturedPhotos.length;
          final dynamic currentItem = photoCount > 0 ? capturedPhotos[selectedPreviewIdx.clamp(0, photoCount - 1)] : null;

          Future<void> addFromCamera() async {
            if (capturedPhotos.length >= 5) {
              _showNotification('Đã đạt giới hạn tối đa 5 ảnh nhận hàng!', backgroundColor: AppColors.accent);
              return;
            }
            final XFile? picked = await picker.pickImage(
              source: ImageSource.camera,
              maxWidth: 640,
              maxHeight: 640,
              imageQuality: 55,
            );
            if (picked != null) {
              setModalState(() {
                capturedPhotos.add(File(picked.path));
                selectedPreviewIdx = capturedPhotos.length - 1;
              });
            }
          }

          Future<void> addFromGallery() async {
            if (capturedPhotos.length >= 5) {
              _showNotification('Đã đạt giới hạn tối đa 5 ảnh nhận hàng!', backgroundColor: AppColors.accent);
              return;
            }
            try {
              final List<XFile> pickedList = await picker.pickMultiImage(
                maxWidth: 640,
                maxHeight: 640,
                imageQuality: 55,
              );
              if (pickedList.isNotEmpty) {
                setModalState(() {
                  for (final f in pickedList) {
                    if (capturedPhotos.length < 5) {
                      capturedPhotos.add(File(f.path));
                    }
                  }
                  selectedPreviewIdx = capturedPhotos.length - 1;
                });
                return;
              }
            } catch (_) {}
            final XFile? single = await picker.pickImage(
              source: ImageSource.gallery,
              maxWidth: 640,
              maxHeight: 640,
              imageQuality: 55,
            );
            if (single != null) {
              setModalState(() {
                capturedPhotos.add(File(single.path));
                selectedPreviewIdx = capturedPhotos.length - 1;
              });
            }
          }

          return Padding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Row(
                        children: [
                          Icon(Icons.inventory_2_rounded, color: AppColors.primary, size: 20),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Chụp ảnh khi nhận hàng',
                              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.textPrimary),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        photoCount > 0 ? '$photoCount/5 ảnh' : 'Tối đa 5 ảnh',
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.primary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Điểm lấy: ${trip['pickup']}',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 14),

                // Main Photo Preview Box
                Container(
                  height: 200,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Stack(
                      children: [
                        if (currentItem is File)
                          Positioned.fill(
                            child: Image.file(
                              currentItem,
                              fit: BoxFit.cover,
                            ),
                          )
                        else if (currentItem is String)
                          Positioned.fill(
                            child: Container(
                              color: selectedPreviewIdx == 0 ? const Color(0xFF1E293B) : const Color(0xFF0F2B48),
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      selectedPreviewIdx == 0 ? Icons.inventory_2_rounded : Icons.verified_user_rounded,
                                      color: Colors.white70,
                                      size: 44,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      selectedPreviewIdx == 0 ? 'ẢNH KIỆN HÀNG LÚC NHẬN' : 'ẢNH PHIẾU XUẤT / NIÊM PHONG',
                                      style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w700),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          )
                        else
                          Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.add_a_photo_outlined, color: Colors.white70, size: 36),
                                ),
                                const SizedBox(height: 10),
                                const Text(
                                  'Chưa có ảnh nhận hàng',
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Chụp kiện hàng để đối soát trước khi vận chuyển',
                                  style: TextStyle(color: Colors.white60, fontSize: 11),
                                ),
                              ],
                            ),
                          ),

                        // Real-time Watermark Overlay
                        if (photoCount > 0)
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              color: Colors.black.withValues(alpha: 0.8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.verified_rounded, color: AppColors.primary, size: 13),
                                      const SizedBox(width: 4),
                                      const Expanded(
                                        child: Text(
                                          'Xác thực Nhận hàng GoShip',
                                          style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Text(
                                        'Ảnh ${selectedPreviewIdx + 1}/$photoCount',
                                        style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w700),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'GPS: ${_driverLocation.latitude.toStringAsFixed(4)}° N, ${_driverLocation.longitude.toStringAsFixed(4)}° E',
                                    style: const TextStyle(color: Colors.white70, fontSize: 10),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    'Thời gian: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())}',
                                    style: const TextStyle(color: Colors.white70, fontSize: 10),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    'Vận đơn: ${trip['id']} • Người gửi: ${trip['customer']}',
                                    style: const TextStyle(color: Color(0xFF93C5FD), fontSize: 10, fontWeight: FontWeight.w600),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Thumbnails Bar
                if (photoCount > 0) ...[
                  SizedBox(
                    height: 64,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: photoCount + (photoCount < 5 ? 1 : 0),
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (ctx, idx) {
                        if (idx < photoCount) {
                          final item = capturedPhotos[idx];
                          final isSel = idx == selectedPreviewIdx;
                          return GestureDetector(
                            onTap: () => setModalState(() => selectedPreviewIdx = idx),
                            child: Stack(
                              children: [
                                Container(
                                  width: 64,
                                  height: 64,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1E293B),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: isSel ? AppColors.primary : const Color(0xFFCBD5E1),
                                      width: isSel ? 2 : 1,
                                    ),
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: item is File
                                      ? Image.file(item, fit: BoxFit.cover)
                                      : Center(
                                          child: Icon(
                                            idx == 0 ? Icons.inventory_2_rounded : Icons.verified_user_rounded,
                                            color: Colors.white70,
                                            size: 22,
                                          ),
                                        ),
                                ),
                                Positioned(
                                  top: 2,
                                  right: 2,
                                  child: GestureDetector(
                                    onTap: () {
                                      setModalState(() {
                                        capturedPhotos.removeAt(idx);
                                        if (selectedPreviewIdx >= capturedPhotos.length && capturedPhotos.isNotEmpty) {
                                          selectedPreviewIdx = capturedPhotos.length - 1;
                                        }
                                      });
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(2),
                                      decoration: const BoxDecoration(
                                        color: Colors.black87,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.close_rounded, color: Colors.white, size: 12),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        } else {
                          return GestureDetector(
                            onTap: () {
                              showModalBottomSheet(
                                context: context,
                                builder: (bCtx) => SafeArea(
                                  child: Wrap(
                                    children: [
                                      ListTile(
                                        leading: const Icon(Icons.camera_alt_rounded, color: AppColors.primary),
                                        title: const Text('Chụp ảnh từ Camera'),
                                        onTap: () {
                                          Navigator.pop(bCtx);
                                          addFromCamera();
                                        },
                                      ),
                                      ListTile(
                                        leading: const Icon(Icons.photo_library_outlined, color: AppColors.primary),
                                        title: const Text('Chọn ảnh từ Thư viện'),
                                        onTap: () {
                                          Navigator.pop(bCtx);
                                          addFromGallery();
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                            child: Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppColors.primary),
                              ),
                              child: const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_photo_alternate_rounded, color: AppColors.primary, size: 22),
                                  SizedBox(height: 2),
                                  Text('+ Thêm', style: TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.w700)),
                                ],
                              ),
                            ),
                          );
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // Action Buttons
                if (photoCount == 0) ...[
                  SizedBox(
                    height: 48,
                    child: Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                            ),
                            onPressed: addFromCamera,
                            icon: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 18),
                            label: const Text('Chụp ảnh', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: AppColors.primary),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: addFromGallery,
                            icon: const Icon(Icons.photo_library_outlined, color: AppColors.primary, size: 18),
                            label: const Text('Thư viện', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 13)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  SizedBox(
                    height: 48,
                    child: Row(
                      children: [
                        if (photoCount < 5) ...[
                          Expanded(
                            flex: 1,
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: AppColors.primary),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                              ),
                              onPressed: () {
                                showModalBottomSheet(
                                  context: context,
                                  builder: (bCtx) => SafeArea(
                                    child: Wrap(
                                      children: [
                                        ListTile(
                                          leading: const Icon(Icons.camera_alt_rounded, color: AppColors.primary),
                                          title: const Text('Chụp ảnh từ Camera'),
                                          onTap: () {
                                            Navigator.pop(bCtx);
                                            addFromCamera();
                                          },
                                        ),
                                        ListTile(
                                          leading: const Icon(Icons.photo_library_outlined, color: AppColors.primary),
                                          title: const Text('Chọn ảnh từ Thư viện'),
                                          onTap: () {
                                            Navigator.pop(bCtx);
                                            addFromGallery();
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.add_a_photo_outlined, size: 16, color: AppColors.primary),
                              label: const Text(
                                'Thêm ảnh',
                                style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary, fontSize: 12),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Expanded(
                          flex: photoCount < 5 ? 2 : 1,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                            ),
                            onPressed: () async {
                              Navigator.pop(modalCtx);
                              for (final p in capturedPhotos) {
                                if (p is File) {
                                  try {
                                    final bytes = await p.readAsBytes();
                                    final b64 = base64Encode(bytes);
                                    _collectedEpodPhotos.add('data:image/jpeg;base64,$b64');
                                  } catch (e) {
                                    _collectedEpodPhotos.add(p.path);
                                  }
                                } else {
                                  _collectedEpodPhotos.add(p.toString());
                                }
                              }

                              setState(() {
                                _tripStep = 1;
                                _currentDropoffIndex = 0;
                              });

                              FirestoreOrderService.updateOrderStatus(
                                orderCode: trip['id'] ?? trip['orderCode'],
                                newStatus: OrderStatus.delivering,
                                epodPhotos: List<String>.from(_collectedEpodPhotos),
                              );

                              final dropCoords = _getTripDropoffCoords();
                              final LatLng targetDrop = dropCoords.isNotEmpty ? dropCoords.first : (trip['dropoffCoord'] as LatLng);

                              await _updateTripRoute();
                              _mapController.move(targetDrop, 15.5);
                              final totalDrops = dropCoords.length > 1 ? dropCoords.length : 1;
                              _showNotification(
                                totalDrops > 1
                                    ? 'Đã xác nhận lấy hàng! Đang điều hướng đến Điểm giao 1/$totalDrops.'
                                    : 'Đã xác nhận lấy hàng! Đang điều hướng đến điểm giao hàng.',
                                backgroundColor: AppColors.primary,
                              );
                            },
                            icon: const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                            label: Text(
                              'Xác nhận lấy ($photoCount ảnh)',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  void _showEpodCaptureModal({required int dropoffIndex, required int totalDropoffs}) {
    if (_activeTrip == null) return;
    final trip = _activeTrip!;
    final ImagePicker picker = ImagePicker();
    final List<dynamic> capturedPhotos = [];
    int selectedPreviewIdx = 0;

    final String currentDropoffAddress = _getCurrentDropoffAddress();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (modalCtx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final int photoCount = capturedPhotos.length;
          final dynamic currentItem = photoCount > 0 ? capturedPhotos[selectedPreviewIdx.clamp(0, photoCount - 1)] : null;

          Future<void> addFromCamera() async {
            if (capturedPhotos.length >= 5) {
              _showNotification('Đã đạt giới hạn tối đa 5 ảnh/điểm!', backgroundColor: AppColors.accent);
              return;
            }
            final XFile? picked = await picker.pickImage(
              source: ImageSource.camera,
              maxWidth: 640,
              maxHeight: 640,
              imageQuality: 55,
            );
            if (picked != null) {
              setModalState(() {
                capturedPhotos.add(File(picked.path));
                selectedPreviewIdx = capturedPhotos.length - 1;
              });
            }
          }

          Future<void> addFromGallery() async {
            if (capturedPhotos.length >= 5) {
              _showNotification('Đã đạt giới hạn tối đa 5 ảnh/điểm!', backgroundColor: AppColors.accent);
              return;
            }
            try {
              final List<XFile> pickedList = await picker.pickMultiImage(
                maxWidth: 640,
                maxHeight: 640,
                imageQuality: 55,
              );
              if (pickedList.isNotEmpty) {
                setModalState(() {
                  for (final f in pickedList) {
                    if (capturedPhotos.length < 5) {
                      capturedPhotos.add(File(f.path));
                    }
                  }
                  selectedPreviewIdx = capturedPhotos.length - 1;
                });
                return;
              }
            } catch (_) {}
            final XFile? single = await picker.pickImage(
              source: ImageSource.gallery,
              maxWidth: 640,
              maxHeight: 640,
              imageQuality: 55,
            );
            if (single != null) {
              setModalState(() {
                capturedPhotos.add(File(single.path));
                selectedPreviewIdx = capturedPhotos.length - 1;
              });
            }
          }

          final bool isLastDropoff = dropoffIndex >= totalDropoffs - 1;

          return Padding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Icon(
                            isLastDropoff ? Icons.camera_alt_rounded : Icons.add_location_alt_rounded,
                            color: isLastDropoff ? AppColors.success : AppColors.primary,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              totalDropoffs > 1
                                  ? 'Chụp e-POD điểm ${dropoffIndex + 1}/$totalDropoffs'
                                  : 'Chụp chứng từ e-POD',
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.textPrimary),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        photoCount > 0 ? '$photoCount/5 ảnh' : 'Tối đa 5 ảnh',
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.primary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Điểm giao: $currentDropoffAddress',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 14),

                // Main Photo Preview Box
                Container(
                  height: 200,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Stack(
                      children: [
                        if (currentItem is File)
                          Positioned.fill(
                            child: Image.file(
                              currentItem,
                              fit: BoxFit.cover,
                            ),
                          )
                        else if (currentItem is String)
                          Positioned.fill(
                            child: Container(
                              color: selectedPreviewIdx == 0
                                  ? const Color(0xFF1E293B)
                                  : (selectedPreviewIdx == 1 ? const Color(0xFF0F2B48) : const Color(0xFF1E3A2F)),
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      selectedPreviewIdx == 0
                                          ? Icons.inventory_2_rounded
                                          : (selectedPreviewIdx == 1 ? Icons.draw_rounded : Icons.verified_user_rounded),
                                      color: Colors.white70,
                                      size: 44,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      selectedPreviewIdx == 0
                                          ? 'ẢNH BÀN GIAO KIỆN HÀNG'
                                          : (selectedPreviewIdx == 1 ? 'ẢNH CHỮ KÝ XÁC NHẬN' : 'ẢNH TEM NIÊM PHONG / VỊ TRÍ'),
                                      style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w700),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          )
                        else
                          Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.add_a_photo_outlined, color: Colors.white70, size: 36),
                                ),
                                const SizedBox(height: 10),
                                const Text(
                                  'Chưa có ảnh bàn giao',
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  totalDropoffs > 1
                                      ? 'Chụp ảnh xác nhận giao tại Điểm ${dropoffIndex + 1}'
                                      : 'Có thể chụp nhiều ảnh: Kiện hàng, Chữ ký, Vị trí...',
                                  style: const TextStyle(color: Colors.white60, fontSize: 11),
                                ),
                              ],
                            ),
                          ),

                        // Real-time Watermark Overlay
                        if (photoCount > 0)
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              color: Colors.black.withValues(alpha: 0.8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.verified_rounded, color: AppColors.success, size: 13),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          totalDropoffs > 1
                                              ? 'Xác thực GoShip e-POD (Điểm ${dropoffIndex + 1}/$totalDropoffs)'
                                              : 'Xác thực GoShip e-POD',
                                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Text(
                                        'Ảnh ${selectedPreviewIdx + 1}/$photoCount',
                                        style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w700),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'GPS: ${_driverLocation.latitude.toStringAsFixed(4)}° N, ${_driverLocation.longitude.toStringAsFixed(4)}° E',
                                    style: const TextStyle(color: Colors.white70, fontSize: 10),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    'Thời gian: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())}',
                                    style: const TextStyle(color: Colors.white70, fontSize: 10),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    'Vận đơn: ${trip['id']} • Điểm ${dropoffIndex + 1}/$totalDropoffs',
                                    style: const TextStyle(color: Color(0xFF93C5FD), fontSize: 10, fontWeight: FontWeight.w600),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Thumbnails Bar
                if (photoCount > 0) ...[
                  SizedBox(
                    height: 64,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: photoCount + (photoCount < 5 ? 1 : 0),
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (ctx, idx) {
                        if (idx < photoCount) {
                          final item = capturedPhotos[idx];
                          final isSel = idx == selectedPreviewIdx;
                          return GestureDetector(
                            onTap: () => setModalState(() => selectedPreviewIdx = idx),
                            child: Stack(
                              children: [
                                Container(
                                  width: 64,
                                  height: 64,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1E293B),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: isSel ? AppColors.primary : const Color(0xFFCBD5E1),
                                      width: isSel ? 2 : 1,
                                    ),
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: item is File
                                      ? Image.file(item, fit: BoxFit.cover)
                                      : Center(
                                          child: Icon(
                                            idx == 0
                                                ? Icons.inventory_2_rounded
                                                : (idx == 1 ? Icons.draw_rounded : Icons.verified_user_rounded),
                                            color: Colors.white70,
                                            size: 22,
                                          ),
                                        ),
                                ),
                                Positioned(
                                  top: 2,
                                  right: 2,
                                  child: GestureDetector(
                                    onTap: () {
                                      setModalState(() {
                                        capturedPhotos.removeAt(idx);
                                        if (selectedPreviewIdx >= capturedPhotos.length && capturedPhotos.isNotEmpty) {
                                          selectedPreviewIdx = capturedPhotos.length - 1;
                                        }
                                      });
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(2),
                                      decoration: const BoxDecoration(
                                        color: Colors.black87,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.close_rounded, color: Colors.white, size: 12),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        } else {
                          return GestureDetector(
                            onTap: () {
                              showModalBottomSheet(
                                context: context,
                                builder: (bCtx) => SafeArea(
                                  child: Wrap(
                                    children: [
                                      ListTile(
                                        leading: const Icon(Icons.camera_alt_rounded, color: AppColors.primary),
                                        title: const Text('Chụp ảnh từ Camera'),
                                        onTap: () {
                                          Navigator.pop(bCtx);
                                          addFromCamera();
                                        },
                                      ),
                                      ListTile(
                                        leading: const Icon(Icons.photo_library_outlined, color: AppColors.primary),
                                        title: const Text('Chọn ảnh từ Thư viện'),
                                        onTap: () {
                                          Navigator.pop(bCtx);
                                          addFromGallery();
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                            child: Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppColors.primary),
                              ),
                              child: const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_photo_alternate_rounded, color: AppColors.primary, size: 22),
                                  SizedBox(height: 2),
                                  Text('+ Thêm', style: TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.w700)),
                                ],
                              ),
                            ),
                          );
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // Action Buttons
                if (photoCount == 0) ...[
                  SizedBox(
                    height: 48,
                    child: Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                            ),
                            onPressed: addFromCamera,
                            icon: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 18),
                            label: const Text('Chụp ảnh', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: AppColors.primary),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: addFromGallery,
                            icon: const Icon(Icons.photo_library_outlined, color: AppColors.primary, size: 18),
                            label: const Text('Thư viện', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 13)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  SizedBox(
                    height: 48,
                    child: Row(
                      children: [
                        if (photoCount < 5) ...[
                          Expanded(
                            flex: 1,
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: AppColors.primary),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                              ),
                              onPressed: () {
                                showModalBottomSheet(
                                  context: context,
                                  builder: (bCtx) => SafeArea(
                                    child: Wrap(
                                      children: [
                                        ListTile(
                                          leading: const Icon(Icons.camera_alt_rounded, color: AppColors.primary),
                                          title: const Text('Chụp ảnh từ Camera'),
                                          onTap: () {
                                            Navigator.pop(bCtx);
                                            addFromCamera();
                                          },
                                        ),
                                        ListTile(
                                          leading: const Icon(Icons.photo_library_outlined, color: AppColors.primary),
                                          title: const Text('Chọn ảnh từ Thư viện'),
                                          onTap: () {
                                            Navigator.pop(bCtx);
                                            addFromGallery();
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.add_a_photo_outlined, size: 16, color: AppColors.primary),
                              label: const Text(
                                'Thêm ảnh',
                                style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary, fontSize: 12),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Expanded(
                          flex: photoCount < 5 ? 2 : 1,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isLastDropoff ? AppColors.success : const Color(0xFF2563EB),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                            ),
                            onPressed: () async {
                              Navigator.pop(modalCtx);
                              final List<String> pointPhotos = [];
                              for (final p in capturedPhotos) {
                                if (p is File) {
                                  try {
                                    final bytes = await p.readAsBytes();
                                    final b64 = base64Encode(bytes);
                                    pointPhotos.add('data:image/jpeg;base64,$b64');
                                  } catch (e) {
                                    debugPrint('>>> [DriverHomeTab epod convert error]: $e');
                                    pointPhotos.add(p.path);
                                  }
                                } else {
                                  pointPhotos.add(p.toString());
                                }
                              }
                              _collectedEpodPhotos.addAll(pointPhotos);

                              if (dropoffIndex < totalDropoffs - 1) {
                                // Đồng bộ ngay ảnh e-POD của điểm giao trung gian lên Firestore
                                FirestoreOrderService.updateOrderStatus(
                                  orderCode: trip['id'] ?? trip['orderCode'],
                                  newStatus: OrderStatus.delivering,
                                  epodPhotos: List<String>.from(_collectedEpodPhotos),
                                );

                                // Chuyển sang điểm giao hàng kế tiếp
                                final nextIdx = dropoffIndex + 1;
                                setState(() {
                                  _currentDropoffIndex = nextIdx;
                                });

                                final dropCoords = _getTripDropoffCoords();
                                final nextCoord = dropCoords[nextIdx];

                                await _updateTripRoute();
                                _mapController.move(nextCoord, 15.5);
                                _showNotification(
                                  'Đã xác nhận Điểm ${dropoffIndex + 1}/$totalDropoffs! Đang chuyển hướng sang Điểm ${nextIdx + 1}/$totalDropoffs.',
                                  backgroundColor: AppColors.primary,
                                );
                              } else {
                                // Hoàn tất tất cả các điểm giao
                                _showCompletionDialog(trip, epodPhotos: List<String>.from(_collectedEpodPhotos));
                              }
                            },
                            icon: Icon(
                              isLastDropoff ? Icons.check_circle_rounded : Icons.arrow_forward_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                            label: Text(
                              isLastDropoff
                                  ? 'Nộp e-POD ($photoCount ảnh)'
                                  : 'Giao Điểm ${dropoffIndex + 1} ($photoCount)',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  void _showCompletionDialog(Map<String, dynamic> trip, {List<String>? epodPhotos}) {
    final String orderCodeStr = (trip['id'] ?? trip['orderCode'] ?? '').toString();
    final String driverId = _currentUser.id.isNotEmpty
        ? _currentUser.id
        : (_currentUser.phone.isNotEmpty ? _currentUser.phone : 'drv_02');
    final int grossFee = (trip['originalFee'] as num?)?.toInt() ?? (trip['rawFee'] as num?)?.toInt() ?? 85000;
    final int netEarning = (grossFee * 0.85).round();
    final int platformFee = grossFee - netEarning;
    final String paymentMethod = trip['paymentMethod']?.toString() ?? 'Tiền mặt';

    FirestoreOrderService.updateOrderStatus(
      orderCode: orderCodeStr,
      newStatus: OrderStatus.completed,
      epodPhotos: epodPhotos,
    );

    // Tự động cộng thu nhập thực nhận (85%) vào Ví tài xế & khấu trừ 15% phí nền tảng từ Ví ký quỹ
    FirestoreOrderService.creditDriverOrderEarnings(
      driverId: driverId,
      orderCode: orderCodeStr,
      grossFee: grossFee,
    );

    final int photoCount = epodPhotos?.length ?? 1;

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.verified_rounded, color: AppColors.success),
            SizedBox(width: 8),
            Expanded(
              child: Text('Giao hàng thành công', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Chứng từ e-POD ($photoCount ảnh) đã được tải lên GoShip Cloud và gửi thông báo tới khách hàng.'),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.account_balance_wallet_rounded, color: AppColors.success, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Thu nhập ròng (85%): +${netEarning.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')} đ',
                          style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.success, fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Khấu trừ ký quỹ 15%: -${platformFee.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')} đ • Thanh toán: $paymentMethod',
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(dialogCtx);
              setState(() {
                _activeTrip = null;
                _tripStep = 0;
                _tripRouteCoords = [];
                _tripRouteSteps = [];
                _tripRemainingDistanceKm = 0.0;
                _tripRemainingDurationMinutes = 0;
                _isTripDetailsExpanded = false;
              });

              _clearTripChatListener();

              FirestoreOrderService.updateDriverLocation(
                driverId: driverId,
                driverName: _currentUser.name,
                phone: _currentUser.phone,
                plateNumber: _currentUser.plateNumber ?? '51D 892.14',
                vehicleType: _currentUser.vehicleType ?? 'Xe Bán tải',
                vehicleName: _currentUser.vehicleType ?? 'Xe Bán tải Ranger',
                location: _driverLocation,
                bearing: 0.0,
                isOnline: _isOnline,
                activeOrderId: null,
              );

              _mapController.move(_driverLocation, 14.8);
              _showNotification('Cuốc xe đã hoàn thành! Tiền cước ròng (85%) đã cộng vào ví Cloud của bạn.', backgroundColor: AppColors.success);
            },
            child: const Text('Xong', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: Stack(
        children: [
          // 1. REAL INTERACTIVE FLUTTER MAP
          Positioned.fill(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _driverLocation,
                initialZoom: 14.8,
                minZoom: 5.0,
                maxZoom: 18.5,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.drag | InteractiveFlag.pinchZoom | InteractiveFlag.doubleTapZoom,
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  fallbackUrl: 'https://{s}.tile.openstreetmap.fr/hot/{z}/{x}/{y}.png',
                  subdomains: const ['a', 'b'],
                  userAgentPackageName: 'vn.nks.goship.goship_app',
                  maxZoom: 19,
                ),

                // Active Trip Polyline (Curved OSRM Road Route)
                if (_activeTrip != null && _tripRouteCoords.length >= 2)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: _tripRouteCoords,
                        color: const Color(0xFF1D4ED8),
                        strokeWidth: 6.0,
                      ),
                      Polyline(
                        points: _tripRouteCoords,
                        color: const Color(0xFF60A5FA),
                        strokeWidth: 3.8,
                      ),
                    ],
                  ),

                // Markers Layer
                MarkerLayer(
                  markers: [
                    // A. DRIVER VEHICLE MARKER (with animated beacon)
                    Marker(
                      point: _driverLocation,
                      width: 90,
                      height: 90,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          if (_isOnline)
                            AnimatedBuilder(
                              animation: _pulseAnimation,
                              builder: (ctx, child) {
                                return Container(
                                  width: 80 * _pulseAnimation.value,
                                  height: 80 * _pulseAnimation.value,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppColors.primary.withValues(alpha: 0.18 * (1.4 - _pulseAnimation.value)),
                                  ),
                                );
                              },
                            ),
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: _isOnline ? AppColors.primary : const Color(0xFF64748B),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                              boxShadow: [
                                BoxShadow(
                                  color: (_isOnline ? AppColors.primary : Colors.black).withValues(alpha: 0.35),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Center(
                              child: Icon(Icons.local_shipping_rounded, color: Colors.white, size: 22),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // B. NEARBY WAITING ORDERS (When idle & online)
                    if (_isOnline && _activeTrip == null)
                      ..._filteredNearbyOrders.map((order) {
                        final coord = order['pickupCoord'] as LatLng;
                        return Marker(
                          point: coord,
                          width: 86,
                          height: 38,
                          child: GestureDetector(
                            onTap: () => _showIncomingOrderSheet(order),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.accent,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.white, width: 2),
                                  boxShadow: const [
                                    BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2)),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.flash_on_rounded, color: Colors.white, size: 14),
                                    const SizedBox(width: 4),
                                    Text(
                                      order['fee'],
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }),

                    // C. ACTIVE TRIP WAYPOINT MARKERS
                    if (_activeTrip != null) ...[
                      // Pickup Marker
                      Marker(
                        point: _activeTrip!['pickupCoord'] as LatLng,
                        width: 44,
                        height: 44,
                        child: Container(
                          decoration: BoxDecoration(
                            color: _tripStep > 0 ? AppColors.success : AppColors.primary,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2.5),
                            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)],
                          ),
                          child: Center(
                            child: Icon(
                              _tripStep > 0 ? Icons.check_circle_rounded : Icons.outbox_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                      // Dropoff Markers (Multi-Drop Support)
                      ...() {
                        final dropCoords = _getTripDropoffCoords();
                        final int totalDrops = dropCoords.length;
                        return dropCoords.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final coord = entry.value;
                          final bool isDone = _tripStep > 0 && idx < _currentDropoffIndex;
                          final bool isCurrent = _tripStep > 0 && idx == _currentDropoffIndex;

                          final Color pinColor = isDone
                              ? AppColors.success
                              : (isCurrent ? AppColors.accent : const Color(0xFF64748B));

                          return Marker(
                            point: coord,
                            width: 44,
                            height: 44,
                            child: Container(
                              decoration: BoxDecoration(
                                color: pinColor,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2.5),
                                boxShadow: [
                                  BoxShadow(
                                    color: pinColor.withValues(alpha: 0.4),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: isDone
                                    ? const Icon(Icons.check_rounded, color: Colors.white, size: 20)
                                    : (totalDrops > 1
                                        ? Text(
                                            '${idx + 1}',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w900,
                                              fontSize: 14,
                                            ),
                                          )
                                        : const Icon(Icons.location_on_rounded, color: Colors.white, size: 20)),
                              ),
                            ),
                          );
                        });
                      }(),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // 2. TOP FLOATING DRIVER PROFILE & ROLE TOGGLE
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Column(
                children: [
                  if (_activeTrip != null) ...[
                    // GOOGLE MAPS NAVIGATION TURN-BY-TURN HUD (Dark Green)
                    _buildGoogleMapsNavigationHUD(),
                    if (_isRerouting)
                      Container(
                        margin: const EdgeInsets.only(top: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B).withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2))],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 13,
                              height: 13,
                              child: CircularProgressIndicator(color: Color(0xFF4ADE80), strokeWidth: 2),
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Đang tự động tìm lộ trình mới...',
                              style: TextStyle(color: Color(0xFF4ADE80), fontSize: 11, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.95),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: const [
                          BoxShadow(color: Colors.black12, blurRadius: 12, offset: Offset(0, 3)),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                final updated = await Navigator.push<UserModel>(
                                  context,
                                  MaterialPageRoute(builder: (_) => DriverEditProfileScreen(user: _currentUser)),
                                );
                                if (updated != null && mounted) {
                                  setState(() => _currentUser = updated);
                                  widget.onProfileUpdated?.call(updated);
                                }
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Row(
                                children: [
                                  AppAvatarWidget(
                                    avatarUrl: _currentUser.avatarUrl,
                                    name: _currentUser.name,
                                    size: 42,
                                    backgroundColor: AppColors.accent.withValues(alpha: 0.15),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Flexible(
                                              child: Text(
                                                _currentUser.name,
                                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.textPrimary),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            const Icon(Icons.edit_outlined, size: 13, color: AppColors.textSecondary),
                                          ],
                                        ),
                                        Row(
                                          children: [
                                            const Icon(Icons.star_rounded, color: Color(0xFFFFB800), size: 15),
                                            const SizedBox(width: 2),
                                            Text(
                                              '${_currentUser.rating}',
                                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppColors.textPrimary),
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              '($_todayTripsCount cuốc)',
                                              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Row(
                            children: [
                              InkWell(
                                onTap: () {
                                  final customerUser = widget.user.copyWith(
                                    role: UserRole.customer,
                                    avatarUrl: widget.user.avatarUrl ?? 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=150',
                                  );
                                  AuthService.saveSession(customerUser);
                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(builder: (_) => CustomerMainScreen(user: customerUser)),
                                  );
                                },
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryLight,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                                  ),
                                  child: const Row(
                                    children: [
                                      Icon(Icons.person_rounded, size: 14, color: AppColors.primary),
                                      SizedBox(width: 4),
                                      Text(
                                        'Khách hàng',
                                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Online / Offline Switch
                    GestureDetector(
                      onTap: () => _toggleOnlineStatus(!_isOnline),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: _isOnline ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: _isOnline ? AppColors.success.withValues(alpha: 0.5) : AppColors.danger.withValues(alpha: 0.5),
                          ),
                          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2))],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                      color: _isOnline ? AppColors.success : AppColors.danger,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _isOnline ? 'Đang hoạt động' : 'Đang tạm nghỉ',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 13,
                                            color: _isOnline ? const Color(0xFF166534) : AppColors.danger,
                                          ),
                                        ),
                                        const SizedBox(height: 1),
                                        Text(
                                          _isOnline ? 'Sẵn sàng nhận cuốc quanh 3km' : 'Bật công tắc để nhận cuốc',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: _isOnline ? const Color(0xFF4C8C60) : AppColors.textSecondary,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: _isOnline,
                              activeThumbColor: AppColors.success,
                              activeTrackColor: AppColors.success.withValues(alpha: 0.35),
                              inactiveThumbColor: AppColors.danger,
                              onChanged: (val) => _toggleOnlineStatus(val),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // 3. MAP CONTROLS (Right Side Buttons)
          Positioned(
            right: 16,
            bottom: _activeTrip != null ? (_isTripDetailsExpanded ? 340 : 100) : 175,
            child: Column(
              children: [
                FloatingActionButton.small(
                  heroTag: 'driver_gps_btn',
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.primary,
                  elevation: 4,
                  onPressed: _recenterMap,
                  child: _isLoadingGps
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.my_location_rounded),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.small(
                  heroTag: 'driver_zoom_in_btn',
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.textPrimary,
                  elevation: 4,
                  onPressed: _zoomIn,
                  child: const Icon(Icons.add_rounded),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.small(
                  heroTag: 'driver_zoom_out_btn',
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.textPrimary,
                  elevation: 4,
                  onPressed: _zoomOut,
                  child: const Icon(Icons.remove_rounded),
                ),
              ],
            ),
          ),

          // 4. BOTTOM ACTION CARD
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: _activeTrip != null
                // A. Active Navigation Trip Sheet (Collapsible Mini Mode & Expanded Mode)
                ? Builder(
                    builder: (ctx) {
                      final currentRecipient = _getCurrentDropoffRecipient();
                      final String partyName = _tripStep == 0
                          ? (_activeTrip!['customer'] ?? 'Khách gửi GoShip')
                          : (currentRecipient?['name'] ?? currentRecipient?['recipientName'] ?? _activeTrip!['recipientName'] ?? _activeTrip!['customer'] ?? 'Khách nhận');
                      final String partyPhone = _tripStep == 0
                          ? (_activeTrip!['phone'] ?? '')
                          : (currentRecipient?['phone'] ?? currentRecipient?['recipientPhone'] ?? _activeTrip!['recipientPhone'] ?? _activeTrip!['phone'] ?? '');
                      final int totalDrops = _getTripDropoffCoords().length;
                      final String partyRole = _tripStep == 0
                          ? 'Người gửi hàng'
                          : (totalDrops > 1 ? 'Người nhận (Điểm ${_currentDropoffIndex + 1}/$totalDrops)' : 'Người nhận hàng');

                      // 1. MINI NAVIGATION HUD MODE (Gọn gàng tối đa, không che bản đồ, không giãn khoảng cách)
                      if (!_isTripDetailsExpanded) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 16, offset: Offset(0, 4))],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // HÀNG 1: Thời gian & Khoảng cách (Trái) + Gọi, Chat, Mở rộng (Phải)
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  InkWell(
                                    onTap: () => setState(() => _isTripDetailsExpanded = true),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment: CrossAxisAlignment.baseline,
                                      textBaseline: TextBaseline.alphabetic,
                                      children: [
                                        Text(
                                          '${_tripRemainingDurationMinutes > 0 ? _tripRemainingDurationMinutes : 5} phút',
                                          style: const TextStyle(
                                            color: Color(0xFF15803D), // Màu xanh lá đậm Google Maps ETA
                                            fontWeight: FontWeight.w900,
                                            fontSize: 18,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          '• ${_tripRemainingDistanceKm > 0 ? _tripRemainingDistanceKm : 1.2} km',
                                          style: const TextStyle(
                                            color: Color(0xFF475569),
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.phone_rounded, color: AppColors.primary, size: 22),
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                        constraints: const BoxConstraints(),
                                        tooltip: 'Gọi liên hệ',
                                        onPressed: () {
                                          CallService.makePhoneCall(
                                            context,
                                            partyPhone,
                                            calleeName: partyName,
                                            calleeRole: partyRole,
                                            orderCode: _activeTrip!['id']?.toString(),
                                          );
                                        },
                                      ),
                                      const SizedBox(width: 6),
                                      Stack(
                                        clipBehavior: Clip.none,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.chat_bubble_outline_rounded, color: AppColors.accent, size: 22),
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                            constraints: const BoxConstraints(),
                                            tooltip: 'Nhắn tin nhanh',
                                            onPressed: _openDriverInTripChat,
                                          ),
                                          if (_unreadDriverChatCount > 0)
                                            Positioned(
                                              top: -2,
                                              right: -2,
                                              child: Container(
                                                padding: const EdgeInsets.all(3),
                                                decoration: const BoxDecoration(
                                                  color: Color(0xFFEF4444),
                                                  shape: BoxShape.circle,
                                                ),
                                                child: Text(
                                                  '$_unreadDriverChatCount',
                                                  style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(width: 4),
                                      IconButton(
                                        icon: const Icon(Icons.keyboard_arrow_up_rounded, color: AppColors.textSecondary, size: 26),
                                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                                        constraints: const BoxConstraints(),
                                        tooltip: 'Xem thông tin khách hàng',
                                        onPressed: () => setState(() => _isTripDetailsExpanded = true),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              // HÀNG 2: Thông tin điểm đến (Trái) + Nút trạng thái chính (Phải)
                              Row(
                                children: [
                                  Expanded(
                                    child: InkWell(
                                      onTap: () => setState(() => _isTripDetailsExpanded = true),
                                      child: Row(
                                        children: [
                                          Icon(
                                            _tripStep == 0 ? Icons.outbox_rounded : Icons.location_on_rounded,
                                            size: 16,
                                            color: _tripStep == 0 ? AppColors.primary : AppColors.accent,
                                          ),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              _tripStep == 0
                                                  ? 'Lấy: $partyName'
                                                  : (totalDrops > 1
                                                      ? 'Giao (${_currentDropoffIndex + 1}/$totalDrops): $partyName'
                                                      : 'Giao: $partyName'),
                                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _tripStep == 0 ? AppColors.primary : AppColors.success,
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                      minimumSize: Size.zero,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      elevation: 0,
                                    ),
                                    onPressed: _nextTripStep,
                                    child: Text(
                                      _tripStep == 0 ? 'Đã đến lấy' : 'Đã đến giao',
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }

                      // 2. EXPANDED MODE (Xem toàn bộ thông tin hàng hóa, chi tiết khách và nút hủy)
                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 16, offset: Offset(0, 4))],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Header thu nhỏ
                            InkWell(
                              onTap: () => setState(() => _isTripDetailsExpanded = false),
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFEFF6FF),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            'Đơn #${_activeTrip!['id'] ?? _activeTrip!['orderCode']}',
                                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.primary),
                                          ),
                                        ),
                                      ],
                                    ),
                                    Row(
                                      children: [
                                        const Text(
                                          'Thu nhỏ bản đồ',
                                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary),
                                        ),
                                        const SizedBox(width: 4),
                                        const Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: AppColors.primary),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            // Thông tin Người liên hệ
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: _tripStep == 0 ? const Color(0xFFEFF6FF) : const Color(0xFFFFF7ED),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          _tripStep == 0 ? Icons.outbox_rounded : Icons.person_outline_rounded,
                                          color: _tripStep == 0 ? AppColors.primary : AppColors.accent,
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              partyName,
                                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.textPrimary),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            Text(
                                              '$partyPhone • $partyRole',
                                              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.phone_rounded, color: AppColors.primary),
                                      tooltip: 'Gọi liên hệ',
                                      onPressed: () {
                                        CallService.makePhoneCall(
                                          context,
                                          partyPhone,
                                          calleeName: partyName,
                                          calleeRole: partyRole,
                                          orderCode: _activeTrip!['id']?.toString(),
                                        );
                                      },
                                    ),
                                    Stack(
                                      clipBehavior: Clip.none,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.chat_bubble_outline_rounded, color: AppColors.accent),
                                          tooltip: 'Nhắn tin nhanh',
                                          onPressed: _openDriverInTripChat,
                                        ),
                                        if (_unreadDriverChatCount > 0)
                                          Positioned(
                                            top: 4,
                                            right: 4,
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFEF4444),
                                                borderRadius: BorderRadius.circular(10),
                                                border: Border.all(color: Colors.white, width: 1.5),
                                              ),
                                              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                                              child: Center(
                                                child: Text(
                                                  '$_unreadDriverChatCount',
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.w900,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),

                            // Chi tiết thông tin hàng hóa đang vận chuyển
                            Container(
                              margin: const EdgeInsets.only(top: 10),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.inventory_2_outlined, size: 16, color: Color(0xFF64748B)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${_activeTrip!['vehicleName'] ?? 'Xe Bán tải'} • ${_activeTrip!['packageCategory'] ?? _activeTrip!['package'] ?? 'Hàng tiêu chuẩn'} (${_activeTrip!['weightCategory'] ?? '<100kg'})',
                                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        if ((_activeTrip!['itemsDetail']?.toString().trim().isNotEmpty ?? false)) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            'Món: ${_activeTrip!['itemsDetail']}',
                                            style: const TextStyle(fontSize: 11, color: Color(0xFF334155), fontWeight: FontWeight.w500),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                        if ((_activeTrip!['driverNote']?.toString().trim().isNotEmpty ?? false)) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            'Lưu ý: ${_activeTrip!['driverNote']}',
                                            style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Color(0xFFD97706)),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _tripStep == 0 ? AppColors.primary : AppColors.success,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  elevation: 0,
                                ),
                                onPressed: _nextTripStep,
                                child: Builder(
                                  builder: (ctx) {
                                    final int totalDrops = _getTripDropoffCoords().length;
                                    final String buttonLabel = _tripStep == 0
                                        ? 'Đã đến điểm lấy hàng & Chụp ảnh'
                                        : (totalDrops > 1
                                            ? (_currentDropoffIndex < totalDrops - 1
                                                ? 'Đến Điểm ${_currentDropoffIndex + 1}/$totalDrops & Chụp e-POD'
                                                : 'Đến Điểm cuối ($totalDrops/$totalDrops) & Chụp hoàn tất')
                                            : 'Giao thành công & Chụp ảnh e-POD');
                                    return Text(
                                      buttonLabel,
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    );
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextButton.icon(
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.danger,
                                padding: const EdgeInsets.symmetric(vertical: 4),
                              ),
                              icon: const Icon(Icons.cancel_outlined, size: 16),
                              label: const Text('Hủy nhận cuốc xe này', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                              onPressed: _showDriverCancelTripDialog,
                            ),
                          ],
                        ),
                      );
                    },
                  )
                // B. Standby Daily Performance Card
                : Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 16, offset: Offset(0, 4))],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_isOnline && _nearbyOrders.isNotEmpty) ...[
                          if (_isNearbyOrdersCollapsed)
                            InkWell(
                              onTap: () => setState(() => _isNearbyOrdersCollapsed = false),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFFBEB),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFF59E0B)),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(5),
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFF59E0B),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.notifications_active_rounded, color: Colors.white, size: 14),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Có ${_filteredNearbyOrders.length} đơn hàng mới • Chạm để mở xem',
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF92400E)),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF59E0B),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text('Mở xem', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
                                          SizedBox(width: 2),
                                          Icon(Icons.keyboard_arrow_up_rounded, color: Colors.white, size: 14),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          else ...[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: const BoxDecoration(
                                        color: AppColors.accent,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Đơn hàng mới (${_filteredNearbyOrders.length})',
                                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                                    ),
                                  ],
                                ),
                                InkWell(
                                  onTap: () => setState(() => _isNearbyOrdersCollapsed = true),
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: const Color(0xFFE2E8F0)),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          'Thu gọn bản đồ',
                                          style: TextStyle(fontSize: 11, color: Color(0xFF475569), fontWeight: FontWeight.w700),
                                        ),
                                        SizedBox(width: 2),
                                        Icon(Icons.keyboard_arrow_down_rounded, size: 14, color: Color(0xFF475569)),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            // Radius Filter Chips
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  const Icon(Icons.radar_rounded, size: 13, color: AppColors.textSecondary),
                                  const SizedBox(width: 4),
                                  for (final opt in const [
                                    MapEntry(0.0, 'Tất cả'),
                                    MapEntry(5.0, '≤ 5 km'),
                                    MapEntry(10.0, '≤ 10 km'),
                                    MapEntry(20.0, '≤ 20 km'),
                                  ]) ...[
                                    Padding(
                                      padding: const EdgeInsets.only(right: 6),
                                      child: InkWell(
                                        onTap: () => setState(() => _selectedRadiusKm = opt.key),
                                        borderRadius: BorderRadius.circular(8),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: _selectedRadiusKm == opt.key
                                                ? AppColors.primary
                                                : const Color(0xFFF1F5F9),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(
                                              color: _selectedRadiusKm == opt.key
                                                  ? AppColors.primary
                                                  : const Color(0xFFE2E8F0),
                                            ),
                                          ),
                                          child: Text(
                                            opt.value,
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                              color: _selectedRadiusKm == opt.key
                                                  ? Colors.white
                                                  : const Color(0xFF475569),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (_filteredNearbyOrders.isEmpty)
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Không có đơn trong bán kính ${_selectedRadiusKm.toInt()} km',
                                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                    InkWell(
                                      onTap: () => setState(() => _selectedRadiusKm = 0.0),
                                      child: const Text(
                                        'Xem tất cả',
                                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.primary),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else if (_filteredNearbyOrders.length == 1)
                              _buildNearbyOrderItem(_filteredNearbyOrders.first)
                            else
                              ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxHeight: _filteredNearbyOrders.length == 2 ? 170 : 190,
                                ),
                                child: MediaQuery.removePadding(
                                  context: context,
                                  removeTop: true,
                                  removeBottom: true,
                                  child: ListView.separated(
                                    padding: EdgeInsets.zero,
                                    physics: const ClampingScrollPhysics(),
                                    shrinkWrap: true,
                                    itemCount: _filteredNearbyOrders.length,
                                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                                    itemBuilder: (ctx, idx) => _buildNearbyOrderItem(_filteredNearbyOrders[idx]),
                                  ),
                                ),
                              ),
                          ],
                          const Divider(height: 14),
                        ],
                        if (_isOnline && _filteredNearbyOrders.isNotEmpty)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.bolt_rounded, size: 16, color: Color(0xFFD97706)),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Hôm nay: ${_todayEarnings ~/ 1000}k đ • $_todayTripsCount cuốc',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                                  ),
                                ],
                              ),
                              InkWell(
                                onTap: () => _showIncomingOrderSheet(_filteredNearbyOrders[0]),
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEF3C7),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFFF59E0B)),
                                  ),
                                  child: const Row(
                                    children: [
                                      Icon(Icons.bolt_rounded, size: 12, color: Color(0xFFD97706)),
                                      SizedBox(width: 2),
                                      Text(
                                        'Thử đơn mới',
                                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFB45309)),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          )
                        else ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: const [
                              Text(
                                'Hiệu suất hôm nay',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _buildStatBox(
                                  label: 'Thu nhập',
                                  value: '${_todayEarnings ~/ 1000}k đ',
                                  valueColor: AppColors.accent,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _buildStatBox(
                                  label: 'Hoàn thành',
                                  value: '$_todayTripsCount cuốc',
                                  valueColor: AppColors.primary,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _buildStatBox(
                                  label: 'Giờ online',
                                  value: _onlineHoursLabel,
                                  valueColor: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildNearbyOrderItem(Map<String, dynamic> order) {
    final isDirect = order['isDirect'] == true;
    final distKm = (order['distanceToPickupKm'] as num?)?.toDouble() ?? 0.0;
    return InkWell(
      onTap: () => _showIncomingOrderSheet(order),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isDirect ? const Color(0xFFFFF7ED) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDirect ? AppColors.accent : const Color(0xFFE2E8F0),
            width: isDirect ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDirect ? AppColors.accent : AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isDirect ? Icons.star_rounded : Icons.local_shipping_rounded,
                color: Colors.white,
                size: 16,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          order['id'] ?? '',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppColors.textPrimary),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isDirect) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFEDD5),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Chỉ định',
                            style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFFC2410C)),
                          ),
                        ),
                      ],
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Cách ${distKm.toStringAsFixed(1)} km',
                          style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.primary),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Lấy: ${order['pickup']}',
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Giao: ${order['dropoff']}',
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${order['vehicleName'] ?? 'Xe Bán tải'} • ${order['packageCategory'] ?? order['package'] ?? 'Hàng tiêu chuẩn'}${order['itemsDetail']?.toString().isNotEmpty == true ? ' (${order['itemsDetail']})' : ''}',
                    style: const TextStyle(fontSize: 10, color: Color(0xFF2563EB), fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  order['fee'] ?? '',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.accent),
                ),
                const SizedBox(height: 4),
                ElevatedButton(
                  onPressed: () => _acceptOrder(order),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Nhận', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatBox({
    required String label,
    required String value,
    required Color valueColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: valueColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
