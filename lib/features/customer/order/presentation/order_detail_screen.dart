import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/route_service.dart';
import '../../../../core/services/driver_simulation_service.dart';
import '../../../../core/services/firestore_order_service.dart';
import '../../../../core/services/order_repository.dart';
import '../../../../core/services/call_service.dart';
import '../../../../core/widgets/app_avatar_widget.dart';
import '../../../../core/widgets/app_interactive_map.dart';
import '../../../../core/widgets/in_trip_chat_sheet.dart';
import '../../../../core/widgets/in_app_message_banner.dart';
import '../../../../core/widgets/incoming_call_dialog.dart';
import '../models/order_draft_model.dart';
import '../models/simulated_driver_model.dart';

class OrderDetailScreen extends StatefulWidget {
  final OrderDraftModel draft;
  final String orderCode;
  final OrderStatus orderStatus;
  final List<String> epodPhotos;
  final bool enableAutoSimulation;

  const OrderDetailScreen({
    super.key,
    required this.draft,
    required this.orderCode,
    this.orderStatus = OrderStatus.pending,
    this.epodPhotos = const [],
    this.enableAutoSimulation = false,
  });

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> with SingleTickerProviderStateMixin {
  final _currencyFormat = NumberFormat('#,###', 'vi_VN');
  
  // Status: 0 = Finding Driver, 1 = Moving to Pickup, 2 = Delivering, 3 = Completed
  int _orderStatus = 0; 
  late final AnimationController _pulseController;
  Timer? _matchingTimer;
  Timer? _nearbyMotionTimer;

  int _selectedRating = 5;
  bool _hasRated = false;
  String _userComment = '';
  List<LatLng> _routePoints = [];
  List<String> _liveEpodPhotos = [];

  List<String> _getEffectiveEpodPhotos() {
    if (_liveEpodPhotos.isNotEmpty) return _liveEpodPhotos;
    if (widget.epodPhotos.isNotEmpty) return widget.epodPhotos;
    if (widget.draft.epodPhotos.isNotEmpty) return widget.draft.epodPhotos;
    return ['mock_photo_goods', 'mock_photo_signature'];
  }

  // Live Tracking & Simulation State
  List<SimulatedDriver> _nearbyDrivers = [];
  SimulatedDriver? _activeDriver;
  LiveTrackingEngine? _trackingEngine;
  List<LatLng> _traveledRoutePoints = [];
  List<LatLng> _currentRoutePoints = [];
  LatLng? _lastRealGpsRouteCoord;
  bool _isFetchingRealRoute = false;
  double _remainingKm = 0.0;
  int _remainingMins = 0;
  double _progressPercent = 0.0;
  double _simulationSpeed = 2.0;
  bool _isPaused = false;
  StreamSubscription<OrderRecord?>? _orderStreamSub;
  StreamSubscription<Map<String, dynamic>?>? _driverTrackingSub;
  StreamSubscription<List<Map<String, dynamic>>>? _onlineDriversSub;
  StreamSubscription<List<Map<String, dynamic>>>? _chatMessagesSub;
  int _unreadChatCount = 0;
  bool _isChatOpen = false;
  String? _lastMessageId;
  StreamSubscription<Map<String, dynamic>?>? _callStateSub;

  // Driver Details
  final Map<String, dynamic> _driverInfo = {
    'name': 'Bác tài GoShip',
    'phone': '0917 795 211',
    'plate': '59P1-987.65',
    'vehicle': 'Xe Bán tải',
    'rating': 4.9,
    'trips': 120,
    'avatar': 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150',
  };

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _routePoints = List<LatLng>.from(widget.draft.drivingRoutePoints);
    if (_routePoints.isEmpty) {
      _fetchRealRoadRoute();
    }

    _initFirestoreOrderStream();
    _initChatMessagesStream();
    _initCallStateStream();

    if (widget.draft.selectedDriver != null) {
      _driverInfo['name'] = widget.draft.selectedDriver!.name;
      if (widget.draft.selectedDriver!.phone.trim().isNotEmpty) {
        _driverInfo['phone'] = widget.draft.selectedDriver!.phone.trim();
      }
      if (widget.draft.selectedDriver!.plate.trim().isNotEmpty) {
        _driverInfo['plate'] = widget.draft.selectedDriver!.plate.trim();
      }
      _driverInfo['vehicle'] = widget.draft.selectedDriver!.vehicleName;
      _driverInfo['avatar'] = widget.draft.selectedDriver!.avatarUrl;
      _driverInfo['rating'] = widget.draft.selectedDriver!.rating;
      _driverInfo['trips'] = widget.draft.selectedDriver!.tripsCount;
      _activeDriver = widget.draft.selectedDriver;
    }

    if (widget.orderStatus == OrderStatus.completed) {
      _orderStatus = 3; // Already delivered
      _activeDriver = widget.draft.selectedDriver ?? SimulatedDriver(
        id: 'drv_01',
        name: _driverInfo['name'],
        phone: _driverInfo['phone'],
        plate: _driverInfo['plate'],
        vehicleType: 'van',
        vehicleName: _driverInfo['vehicle'],
        rating: _driverInfo['rating'],
        tripsCount: _driverInfo['trips'],
        avatarUrl: _driverInfo['avatar'],
        currentPosition: widget.draft.drivingRoutePoints.isNotEmpty
            ? widget.draft.drivingRoutePoints.last
            : const LatLng(10.7725, 106.6980),
      );
    } else if (widget.orderStatus == OrderStatus.delivering) {
      _orderStatus = 2; // In delivery
      if (widget.draft.selectedDriver != null) {
        _activeDriver = widget.draft.selectedDriver;
      }
      if (widget.enableAutoSimulation) {
        _initFindingAndNearbySimulation();
      }
    } else {
      _initFindingAndNearbySimulation();
    }
  }

  void _initFirestoreOrderStream() {
    _orderStreamSub = FirestoreOrderService.streamOrderDetail(widget.orderCode).listen((order) {
      if (!mounted || order == null) return;

      if (order.epodPhotos.isNotEmpty && order.epodPhotos.length != _liveEpodPhotos.length) {
        setState(() {
          _liveEpodPhotos = List<String>.from(order.epodPhotos);
        });
      }

      if (order.customerRating != null && order.customerRating! > 0) {
        setState(() {
          _hasRated = true;
          _selectedRating = order.customerRating!;
          _userComment = order.customerComment ?? '';
        });
      }

      if (order.status == OrderStatus.cancelled) {
        _matchingTimer?.cancel();
        _nearbyMotionTimer?.cancel();
        _orderStreamSub?.cancel();
        _driverTrackingSub?.cancel();
        _onlineDriversSub?.cancel();
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              title: const Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: AppColors.danger),
                  SizedBox(width: 8),
                  Text('Đơn hàng đã hủy', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                ],
              ),
              content: const Text('Chuyến xe này đã được xác nhận hủy. Nhấn nút bên dưới để trở về màn hình chính.'),
              actions: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                  child: const Text('Về trang chủ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          );
        }
        return;
      }

      if (order.status == OrderStatus.pending && _orderStatus == 2) {
        // Cuốc xe được tài xế trả lại thị trường
        setState(() {
          _orderStatus = 0; // Trở lại tìm kiếm tài xế mới
          _activeDriver = null;
        });
        _initFindingAndNearbySimulation();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Tài xế đã hủy nhận cuốc. Hệ thống đang tiếp tục kết nối tài xế mới cho bạn...'),
              backgroundColor: AppColors.accent,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      // Luôn đồng bộ thông tin tài xế thực từ bản ghi đơn hàng Firestore (kể cả khi đã vào màn hình chi tiết)
      final String? realDriverName = (order.driverName != null && order.driverName!.trim().isNotEmpty)
          ? order.driverName!.trim()
          : ((order.assignedDriverName != null && order.assignedDriverName!.trim().isNotEmpty) ? order.assignedDriverName!.trim() : null);
      final String? realDriverPhone = (order.driverPhone != null && order.driverPhone!.trim().isNotEmpty)
          ? order.driverPhone!.trim()
          : null;
      final String? realDriverPlate = (order.driverPlate != null && order.driverPlate!.trim().isNotEmpty)
          ? order.driverPlate!.trim()
          : null;
      final String? realDriverId = (order.driverId != null && order.driverId!.trim().isNotEmpty)
          ? order.driverId!.trim()
          : ((order.assignedDriverId != null && order.assignedDriverId!.trim().isNotEmpty) ? order.assignedDriverId!.trim() : null);

      if (realDriverName != null || realDriverPhone != null || realDriverPlate != null || order.vehicleName.isNotEmpty) {
        setState(() {
          if (realDriverName != null) _driverInfo['name'] = realDriverName;
          if (realDriverPhone != null && realDriverPhone.isNotEmpty) _driverInfo['phone'] = realDriverPhone;
          if (realDriverPlate != null && realDriverPlate.isNotEmpty) _driverInfo['plate'] = realDriverPlate;
          if (order.vehicleName.isNotEmpty) _driverInfo['vehicle'] = order.vehicleName;
          if (_activeDriver != null) {
            _activeDriver = _activeDriver!.copyWith(
              name: _driverInfo['name'],
              phone: _driverInfo['phone'],
              plate: _driverInfo['plate'],
              vehicleName: _driverInfo['vehicle'],
              avatarUrl: _driverInfo['avatar'],
            );
          }
        });
      }

      if (realDriverId != null) {
        if (_driverTrackingSub == null) {
          _listenToDriverRealGps(realDriverId);
        }
        _fetchDriverProfileFromCloud(realDriverId);
      }

      if (order.status == OrderStatus.delivering) {
        _matchingTimer?.cancel();
        _nearbyMotionTimer?.cancel();
        _onlineDriversSub?.cancel();
        if (_orderStatus < 2) {
          setState(() {
            _orderStatus = 2; // In delivery
            _nearbyDrivers = [];
          });
        }
      } else if (order.status == OrderStatus.completed && _orderStatus < 3) {
        _driverTrackingSub?.cancel();
        _onlineDriversSub?.cancel();
        final wasNotCompleted = _orderStatus < 3;
        setState(() {
          _orderStatus = 3;
        });
        if (wasNotCompleted && !_hasRated) {
          Future.delayed(const Duration(milliseconds: 1200), () {
            if (mounted && !_hasRated && _orderStatus == 3) {
              _showRatingModal();
            }
          });
        }
      }
    });
  }

  void _initChatMessagesStream() {
    bool isFirstSnapshot = true;
    _chatMessagesSub = FirestoreOrderService.streamOrderChatMessages(widget.orderCode).listen((messages) {
      if (!mounted || messages.isEmpty) {
        isFirstSnapshot = false;
        return;
      }

      final lastMsg = messages.last;
      final String msgId = lastMsg['id']?.toString() ?? '';
      final String senderRole = lastMsg['senderRole']?.toString() ?? '';

      if (isFirstSnapshot) {
        isFirstSnapshot = false;
        _lastMessageId = msgId;
        return;
      }

      // Chỉ thông báo nếu tin nhắn mới là từ tài xế gửi đến khách hàng
      if (senderRole != 'customer' && msgId.isNotEmpty && msgId != _lastMessageId) {
        _lastMessageId = msgId;

        if (_isChatOpen) {
          // Khách hàng đang mở cửa sổ chat rồi thì không hiện banner đè lên
          return;
        }

        setState(() {
          _unreadChatCount++;
        });

        final senderName = lastMsg['senderName']?.toString() ?? (_driverInfo['name']?.toString() ?? 'Tài xế GoShip');
        final text = lastMsg['text']?.toString() ?? '';

        InAppMessageNotification.show(
          context,
          senderName: senderName,
          senderRole: 'Tài xế',
          messageText: text,
          onTap: _openInTripChat,
        );
      }
    });
  }

  Future<void> _openInTripChat() async {
    InAppMessageNotification.dismiss();
    setState(() {
      _isChatOpen = true;
      _unreadChatCount = 0;
    });

    await InTripChatSheet.show(
      context,
      orderCode: widget.orderCode,
      currentUserId: widget.draft.senderPhone.isNotEmpty ? widget.draft.senderPhone : 'cust_me',
      currentUserName: widget.draft.senderName.isNotEmpty ? widget.draft.senderName : 'Khách hàng',
      currentUserRole: 'customer',
      otherPartyName: _driverInfo['name']?.toString() ?? 'Tài xế GoShip',
      otherPartyPhone: _driverInfo['phone']?.toString() ?? '',
      otherPartyRole: 'Tài xế',
    );

    if (mounted) {
      setState(() {
        _isChatOpen = false;
        _unreadChatCount = 0;
      });
    }
  }

  void _initCallStateStream() {
    _callStateSub?.cancel();
    _callStateSub = FirestoreOrderService.streamOrderCallState(widget.orderCode).listen((callState) {
      if (!mounted || callState == null) return;

      final String status = callState['status']?.toString() ?? '';
      final String callerRole = callState['caller_role']?.toString() ?? '';

      // Khi tài xế gọi đến khách hàng và đang đổ chuông
      if (status == 'ringing' && callerRole == 'driver') {
        final callerName = callState['caller_name']?.toString() ?? (_driverInfo['name']?.toString() ?? 'Tài xế GoShip');
        final callerPhone = _driverInfo['phone']?.toString() ?? '';

        final callId = callState['id']?.toString();

        IncomingCallDialog.show(
          context,
          orderCode: widget.orderCode,
          callerName: callerName,
          callerRole: 'Tài xế GoShip',
          callerPhone: callerPhone,
          callId: callId,
        );
      }
    });
  }

  void _listenToDriverRealGps(String driverId) {
    _driverTrackingSub?.cancel();
    _driverTrackingSub = FirestoreOrderService.streamDriverLocation(driverId).listen((locData) {
      if (!mounted || locData == null) return;
      final double? lat = (locData['lat'] as num?)?.toDouble();
      final double? lng = (locData['lng'] as num?)?.toDouble();
      final double? bearing = (locData['bearing'] as num?)?.toDouble();
      final String? dName = locData['driver_name']?.toString();
      final String? dPhone = locData['phone']?.toString();
      final String? dPlate = locData['plate']?.toString();
      final String? dAvatar = locData['avatar_url']?.toString();

      if (mounted) {
        setState(() {
          if (dName != null && dName.trim().isNotEmpty) _driverInfo['name'] = dName.trim();
          if (dPhone != null && dPhone.trim().isNotEmpty) _driverInfo['phone'] = dPhone.trim();
          if (dPlate != null && dPlate.trim().isNotEmpty) _driverInfo['plate'] = dPlate.trim();
          if (dAvatar != null && dAvatar.trim().isNotEmpty) _driverInfo['avatar'] = dAvatar.trim();

          if (lat != null && lng != null) {
            final pos = LatLng(lat, lng);
            if (_activeDriver != null) {
              _activeDriver = _activeDriver!.copyWith(
                currentPosition: pos,
                headingDegrees: bearing,
                name: _driverInfo['name'],
                phone: _driverInfo['phone'],
                plate: _driverInfo['plate'],
                vehicleName: _driverInfo['vehicle'],
                avatarUrl: _driverInfo['avatar'],
              );
            } else {
              _activeDriver = SimulatedDriver(
                id: driverId,
                name: _driverInfo['name'],
                phone: _driverInfo['phone'],
                plate: _driverInfo['plate'],
                vehicleType: 'van',
                vehicleName: _driverInfo['vehicle'],
                rating: _driverInfo['rating'] is num ? (_driverInfo['rating'] as num).toDouble() : 4.9,
                tripsCount: 412,
                avatarUrl: _driverInfo['avatar'],
                currentPosition: pos,
                headingDegrees: bearing ?? 0.0,
              );
            }

            // Dynamically calculate remaining distance & minutes to dropoff using real GPS
            final points = _getLocationPoints();
            if (points.isNotEmpty) {
              final targetCoord = points.last.latLng;
              final distKm = const Distance().as(LengthUnit.Kilometer, pos, targetCoord);
              _remainingKm = (distKm * 10).round() / 10;
              _remainingMins = (_remainingKm * 3).clamp(1, 120).round();

              // Refresh live road route if driver moved > 250m or first GPS update
              final shouldRefreshRoute = _lastRealGpsRouteCoord == null ||
                  const Distance().as(LengthUnit.Meter, _lastRealGpsRouteCoord!, pos) > 250;
              if (shouldRefreshRoute && !_isFetchingRealRoute) {
                _isFetchingRealRoute = true;
                _lastRealGpsRouteCoord = pos;
                RouteService.getDrivingRoute([pos, targetCoord]).then((routeRes) {
                  if (mounted && routeRes.polylinePoints.isNotEmpty) {
                    setState(() {
                      _currentRoutePoints = routeRes.polylinePoints;
                    });
                  }
                }).whenComplete(() {
                  _isFetchingRealRoute = false;
                });
              }
            }
          }
        });
      }
    });
  }

  Future<void> _fetchDriverProfileFromCloud(String driverId) async {
    try {
      final fs = FirebaseFirestore.instance;
      // 1. Kiểm tra trên driver_tracking trước
      final trackDoc = await fs.collection('driver_tracking').doc(driverId).get();
      if (trackDoc.exists && trackDoc.data() != null) {
        final d = trackDoc.data()!;
        if (mounted) {
          setState(() {
            if (d['driver_name'] != null && d['driver_name'].toString().trim().isNotEmpty) {
              _driverInfo['name'] = d['driver_name'].toString().trim();
            }
            if (d['phone'] != null && d['phone'].toString().trim().isNotEmpty) {
              _driverInfo['phone'] = d['phone'].toString().trim();
            }
            if (d['plate'] != null && d['plate'].toString().trim().isNotEmpty) {
              _driverInfo['plate'] = d['plate'].toString().trim();
            }
            if (d['avatar_url'] != null && d['avatar_url'].toString().trim().isNotEmpty) {
              _driverInfo['avatar'] = d['avatar_url'].toString().trim();
            }
          });
        }
      }

      // 2. Tra cứu thêm trên users collection nếu thiếu avatar hoặc rating
      final userDoc = await fs.collection('users').doc(driverId.startsWith('usr_') ? driverId : 'usr_$driverId').get();
      final uSnap = userDoc.exists ? userDoc : await fs.collection('users').doc(driverId).get();
      if (uSnap.exists && uSnap.data() != null) {
        final u = uSnap.data()!;
        if (mounted) {
          setState(() {
            if (u['name'] != null && u['name'].toString().trim().isNotEmpty) {
              _driverInfo['name'] = u['name'].toString().trim();
            }
            if (u['phone'] != null && u['phone'].toString().trim().isNotEmpty) {
              _driverInfo['phone'] = u['phone'].toString().trim();
            }
            final plate = u['plate_number'] ?? u['plateNumber'];
            if (plate != null && plate.toString().trim().isNotEmpty) {
              _driverInfo['plate'] = plate.toString().trim();
            }
            final avatar = u['avatar_url'] ?? u['avatarUrl'];
            if (avatar != null && avatar.toString().trim().isNotEmpty) {
              _driverInfo['avatar'] = avatar.toString().trim();
            }
            if (u['rating'] != null) {
              _driverInfo['rating'] = (u['rating'] as num).toDouble();
            }
            final trips = u['trips_count'] ?? u['tripsCount'];
            if (trips != null) {
              _driverInfo['trips'] = trips.toString();
            }
            if (_activeDriver != null) {
              _activeDriver = _activeDriver!.copyWith(
                name: _driverInfo['name'],
                phone: _driverInfo['phone'],
                plate: _driverInfo['plate'],
                avatarUrl: _driverInfo['avatar'],
                rating: _driverInfo['rating'] is num ? (_driverInfo['rating'] as num).toDouble() : 4.9,
                tripsCount: int.tryParse(_driverInfo['trips'].toString()) ?? 100,
              );
            }
          });
        }
      }
    } catch (e) {
      debugPrint('>>> [_fetchDriverProfileFromCloud error]: $e');
    }
  }

  void _initFindingAndNearbySimulation() {
    _orderStatus = 0;

    // Stream real online drivers from Firestore
    _onlineDriversSub?.cancel();
    _onlineDriversSub = FirestoreOrderService.streamOnlineDrivers().listen((driverList) {
      if (!mounted || _orderStatus != 0) return;
      setState(() {
        _nearbyDrivers = driverList.map((d) {
          final lat = (d['lat'] as num?)?.toDouble() ?? 10.7750;
          final lng = (d['lng'] as num?)?.toDouble() ?? 106.6980;
          final bearing = (d['bearing'] as num?)?.toDouble() ?? 0.0;
          return SimulatedDriver(
            id: d['id'] ?? d['driver_id'] ?? '',
            name: d['name'] ?? d['driver_name'] ?? 'Bác tài GoShip',
            phone: d['phone'] ?? '',
            plate: d['plate'] ?? d['plate_number'] ?? '',
            vehicleType: d['vehicleType'] ?? d['vehicle_type'] ?? 'van',
            vehicleName: d['vehicleName'] ?? d['vehicle_name'] ?? 'Xe Bán tải',
            rating: (d['rating'] as num?)?.toDouble() ?? 4.9,
            tripsCount: (d['trips'] as num?)?.toInt() ?? 100,
            avatarUrl: '',
            currentPosition: LatLng(lat, lng),
            headingDegrees: bearing,
          );
        }).toList();

        if (widget.draft.selectedDriver != null) {
          final match = _nearbyDrivers.firstWhere(
            (d) => d.id == widget.draft.selectedDriver!.id,
            orElse: () => widget.draft.selectedDriver!,
          );
          _activeDriver = match;
        }
      });
    });

    if (widget.draft.selectedDriver != null) {
      _activeDriver = widget.draft.selectedDriver;
    }

    // ONLY start automatic timer simulation when explicitly requested (e.g. test environment)
    if (widget.enableAutoSimulation) {
      if (_nearbyDrivers.isEmpty) {
        final pickupCoord = _getLocationPoints().first.latLng;
        _nearbyDrivers = DriverSimulationService.generateNearbyDrivers(pickupCoord, count: 5);
      }
      if (widget.draft.selectedDriver != null) {
        _matchingTimer = Timer(const Duration(milliseconds: 1500), () {
          if (mounted) _startMovingToPickupPhase();
        });
      } else {
        _matchingTimer = Timer(const Duration(milliseconds: 3500), () {
          if (mounted) _startMovingToPickupPhase();
        });
      }
    }
  }

  Future<void> _startMovingToPickupPhase() async {
    _nearbyMotionTimer?.cancel();
    if (widget.draft.selectedDriver != null) {
      _activeDriver = widget.draft.selectedDriver!;
    } else if (_nearbyDrivers.isNotEmpty) {
      _activeDriver = _nearbyDrivers.first;
    } else {
      final pickupCoord = _getLocationPoints().first.latLng;
      _activeDriver = DriverSimulationService.generateNearbyDrivers(pickupCoord, count: 1).first;
    }

    _driverInfo['name'] = _activeDriver!.name;
    _driverInfo['phone'] = _activeDriver!.phone;
    _driverInfo['plate'] = _activeDriver!.plate;
    _driverInfo['vehicle'] = _activeDriver!.vehicleName;
    _driverInfo['rating'] = _activeDriver!.rating;
    _driverInfo['trips'] = _activeDriver!.tripsCount;
    _driverInfo['avatar'] = _activeDriver!.avatarUrl;

    if (!mounted) return;
    setState(() {
      _orderStatus = 1;
      _nearbyDrivers = [];
    });

    final isPreSelected = widget.draft.selectedDriver != null;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isPreSelected
            ? 'Tài xế ưu tiên ${_activeDriver!.name} đã nhận đơn! Đang di chuyển đến điểm lấy.'
            : 'Tài xế ${_activeDriver!.name} đã nhận đơn! Đang di chuyển đến điểm lấy.'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );

    final pickupCoord = _getLocationPoints().first.latLng;
    final routeResult = await RouteService.getDrivingRoute([_activeDriver!.currentPosition, pickupCoord]);
    final driverToPickupRoute = routeResult.polylinePoints;

    if (!mounted) return;
    setState(() {
      _currentRoutePoints = driverToPickupRoute;
      _traveledRoutePoints = [];
    });

    _trackingEngine?.dispose();
    _trackingEngine = LiveTrackingEngine(
      routePoints: driverToPickupRoute,
      onUpdate: (pos, heading, traveled, remaining, remKm, remMins, progress) {
        if (!mounted) return;
        setState(() {
          _activeDriver = _activeDriver!.copyWith(currentPosition: pos, headingDegrees: heading);
          _traveledRoutePoints = traveled;
          _currentRoutePoints = remaining;
          _remainingKm = remKm;
          _remainingMins = remMins;
          _progressPercent = progress;
        });
      },
      onCompleted: () {
        if (!mounted) return;
        _startDeliveringPhase();
      },
    );

    _trackingEngine!.start(speedMultiplier: _simulationSpeed);
  }

  void _startDeliveringPhase() {
    if (!mounted) return;
    setState(() {
      _orderStatus = 2;
      _traveledRoutePoints = [];
      _currentRoutePoints = List.from(_routePoints);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Tài xế đã nhận hàng! Đang di chuyển đến điểm giao.'),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
      ),
    );

    final pointsToFollow = _routePoints.isNotEmpty
        ? _routePoints
        : _getLocationPoints().map((p) => p.latLng).toList();

    _trackingEngine?.dispose();
    _trackingEngine = LiveTrackingEngine(
      routePoints: pointsToFollow,
      onUpdate: (pos, heading, traveled, remaining, remKm, remMins, progress) {
        if (!mounted) return;
        setState(() {
          _activeDriver = _activeDriver!.copyWith(currentPosition: pos, headingDegrees: heading);
          _traveledRoutePoints = traveled;
          _currentRoutePoints = remaining;
          _remainingKm = remKm;
          _remainingMins = remMins;
          _progressPercent = progress;
        });
      },
      onCompleted: () {
        if (!mounted) return;
        _onOrderCompleted();
      },
    );

    _trackingEngine!.start(speedMultiplier: _simulationSpeed);
  }

  void _onOrderCompleted() {
    if (!mounted) return;
    setState(() {
      _orderStatus = 3;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Đơn hàng đã giao thành công tới người nhận!'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _setSpeed(double speed) {
    setState(() => _simulationSpeed = speed);
    _trackingEngine?.setSpeedMultiplier(speed);
  }

  void _togglePause() {
    setState(() => _isPaused = !_isPaused);
    if (_isPaused) {
      _trackingEngine?.pause();
    } else {
      _trackingEngine?.resume();
    }
  }

  void _jumpToEndSimulation() {
    _trackingEngine?.jumpToEnd();
  }

  Future<void> _fetchRealRoadRoute() async {
    final pts = _getLocationPoints();
    final waypoints = pts.map((p) => p.latLng).toList();
    if (waypoints.length >= 2) {
      final result = await RouteService.getDrivingRoute(waypoints);
      if (mounted && result.polylinePoints.isNotEmpty) {
        setState(() {
          _routePoints = result.polylinePoints;
          widget.draft.drivingRoutePoints = result.polylinePoints;
        });
      }
    }
  }

  @override
  void dispose() {
    _matchingTimer?.cancel();
    _nearbyMotionTimer?.cancel();
    _orderStreamSub?.cancel();
    _driverTrackingSub?.cancel();
    _onlineDriversSub?.cancel();
    _chatMessagesSub?.cancel();
    _callStateSub?.cancel();
    InAppMessageNotification.dismiss();
    _trackingEngine?.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  LatLng _resolveAddressCoord(String address, int fallbackIndex) {
    final a = address.toLowerCase();
    if (a.contains('lê lợi') || a.contains('bến thành')) {
      return const LatLng(10.7725, 106.6980);
    }
    if (a.contains('võ văn tần')) {
      return const LatLng(10.7780, 106.6900);
    }
    if (a.contains('bitexco') || a.contains('hải triều')) {
      return const LatLng(10.7716, 106.7044);
    }
    if (a.contains('landmark 81') || a.contains('vinhomes') || a.contains('bình thạnh')) {
      return const LatLng(10.7946, 106.7218);
    }
    if (a.contains('điện biên phủ') || a.contains('quận 3')) {
      return const LatLng(10.7825, 106.6905);
    }
    if (a.contains('tân bình')) {
      return const LatLng(10.8150, 106.6320);
    }
    return LatLng(10.7750 - fallbackIndex * 0.008, 106.6950 + fallbackIndex * 0.008);
  }

  List<LocationPoint> _getLocationPoints() {
    final List<LocationPoint> pts = [];
    final draft = widget.draft;

    final LatLng pickupCoord = draft.pickupLatLng ?? _resolveAddressCoord(draft.pickupAddress, 0);

    pts.add(LocationPoint(
      title: 'Điểm lấy hàng',
      address: draft.pickupAddress.isNotEmpty ? draft.pickupAddress : 'Landmark 81, Bình Thạnh',
      latLng: pickupCoord,
      isPickup: true,
    ));

    for (int i = 0; i < draft.dropoffAddresses.length; i++) {
      final addr = draft.dropoffAddresses[i];
      final coord = (i < draft.dropoffLatLngs.length && draft.dropoffLatLngs[i] != null)
          ? draft.dropoffLatLngs[i]!
          : _resolveAddressCoord(addr, i + 1);
      pts.add(LocationPoint(
        title: 'Điểm giao ${i + 1}',
        address: addr.isNotEmpty ? addr : '25 Điện Biên Phủ, Quận 3',
        latLng: coord,
        isPickup: false,
        index: i + 1,
      ));
    }
    return pts;
  }

  void _showRatingModal() {
    int tempRating = _selectedRating;
    final commentCtrl = TextEditingController(text: _userComment);
    final List<String> feedbackTags = [
      'Giao đúng giờ',
      'Thân thiện lịch sự',
      'Hàng hóa nguyên vẹn',
      'Lái xe cẩn thận',
      'Hỗ trợ bốc dỡ tốt',
    ];
    final Set<String> selectedTags = {};

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          String ratingDesc = 'Rất tuyệt vời!';
          if (tempRating == 1) ratingDesc = 'Rất không hài lòng';
          if (tempRating == 2) ratingDesc = 'Chưa hài lòng';
          if (tempRating == 3) ratingDesc = 'Bình thường';
          if (tempRating == 4) ratingDesc = 'Hài lòng';

          return Padding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
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
                const Text(
                  'Đánh giá dịch vụ & Tài xế',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 6),
                Text(
                  'Chuyến xe ${widget.orderCode} • ${_driverInfo['name']}',
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 20),

                // Stars row
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (idx) {
                    final starIndex = idx + 1;
                    return IconButton(
                      iconSize: 36,
                      icon: Icon(
                        starIndex <= tempRating ? Icons.star_rounded : Icons.star_outline_rounded,
                        color: const Color(0xFFFFB800),
                      ),
                      onPressed: () => setModalState(() => tempRating = starIndex),
                    );
                  }),
                ),
                Text(
                  ratingDesc,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.accent),
                ),

                const SizedBox(height: 18),

                // Quick feedback chips
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: feedbackTags.map((tag) {
                    final isSelected = selectedTags.contains(tag);
                    return FilterChip(
                      selected: isSelected,
                      label: Text(tag, style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500)),
                      selectedColor: AppColors.primaryLight,
                      checkmarkColor: AppColors.primary,
                      onSelected: (val) {
                        setModalState(() {
                          if (val) {
                            selectedTags.add(tag);
                          } else {
                            selectedTags.remove(tag);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),

                const SizedBox(height: 16),

                // Comment text field
                TextField(
                  controller: commentCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'Để lại lời khen hoặc góp ý cho bác tài...',
                    contentPadding: EdgeInsets.all(12),
                  ),
                ),

                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    onPressed: () async {
                      final rating = tempRating;
                      final comment = commentCtrl.text.trim();
                      final tags = selectedTags.toList();
                      Navigator.pop(ctx);
                      setState(() {
                        _selectedRating = rating;
                        _hasRated = true;
                        _userComment = comment;
                      });

                      // Lưu đánh giá vào Firestore & Local Repository
                      await FirestoreOrderService.submitCustomerRatingForDriver(
                        orderCode: widget.orderCode,
                        rating: rating,
                        comment: comment,
                        tags: tags,
                      );
                      await OrderRepository.updateCustomerRating(
                        widget.orderCode,
                        rating: rating,
                        comment: comment,
                        tags: tags,
                      );

                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Cảm ơn bạn đã gửi đánh giá dịch vụ!'),
                            backgroundColor: AppColors.success,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    },
                    child: const Text('Gửi đánh giá ngay', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showCancelOrderDialog() {
    String selectedReason = 'Đổi ý, không muốn gửi hàng nữa';
    final List<String> reasons = [
      'Đổi ý, không muốn gửi hàng nữa',
      'Thời gian chờ tài xế quá lâu',
      'Điền sai thông tin địa chỉ hoặc người nhận',
      'Thay đổi phương thức vận chuyển khác',
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
                const Text(
                  'Xác nhận hủy đơn hàng',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Vui lòng chọn lý do để GoShip cải thiện chất lượng dịch vụ tốt hơn:',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
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
                        child: const Text('Giữ lại đơn', style: TextStyle(fontWeight: FontWeight.w700)),
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
                          _matchingTimer?.cancel();
                          _nearbyMotionTimer?.cancel();
                          _orderStreamSub?.cancel();
                          _driverTrackingSub?.cancel();
                          _onlineDriversSub?.cancel();

                          await FirestoreOrderService.cancelOrderByCustomer(
                            orderCode: widget.orderCode,
                            reason: selectedReason,
                          );

                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Đã hủy đơn hàng #${widget.orderCode} thành công.'),
                                backgroundColor: AppColors.textPrimary,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                            Navigator.of(context).popUntil((route) => route.isFirst);
                          }
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

  Widget _buildEpodImage(String photoPath, {BoxFit fit = BoxFit.cover, Widget? placeholder}) {
    if (photoPath.isEmpty || photoPath.startsWith('mock_')) {
      return placeholder ?? const SizedBox.shrink();
    }

    if (photoPath.startsWith('http://') || photoPath.startsWith('https://')) {
      return Image.network(
        photoPath,
        fit: fit,
        errorBuilder: (_, __, ___) => placeholder ?? const SizedBox.shrink(),
      );
    }

    if (photoPath.startsWith('data:image')) {
      try {
        final base64Str = photoPath.split(',').last;
        final bytes = base64Decode(base64Str);
        return Image.memory(
          bytes,
          fit: fit,
          errorBuilder: (_, __, ___) => placeholder ?? const SizedBox.shrink(),
        );
      } catch (_) {
        return placeholder ?? const SizedBox.shrink();
      }
    }

    if (!kIsWeb) {
      try {
        final file = File(photoPath);
        if (file.existsSync()) {
          return Image.file(
            file,
            fit: fit,
            errorBuilder: (_, __, ___) => placeholder ?? const SizedBox.shrink(),
          );
        }
      } catch (_) {
        return placeholder ?? const SizedBox.shrink();
      }
    }

    return placeholder ?? const SizedBox.shrink();
  }

  Widget _buildSinglePhotoView(String photoPath, int index, int total) {
    final List<Map<String, dynamic>> mockTypes = [
      {
        'icon': Icons.inventory_2_rounded,
        'title': 'ẢNH 1: BÀN GIAO KIỆN HÀNG NGUYÊN VẸN',
        'sub': 'Kiểm đếm đầy đủ số lượng tại điểm giao',
        'color': const Color(0xFF0F172A),
      },
      {
        'icon': Icons.draw_rounded,
        'title': 'ẢNH 2: CHỮ KÝ BIÊN BẢN BÀN GIAO',
        'sub': 'Xác thực ký nhận người nhận hàng',
        'color': const Color(0xFF0F2B48),
      },
      {
        'icon': Icons.verified_user_rounded,
        'title': 'ẢNH 3: TEM NIÊM PHONG & ĐỊA ĐIỂM GIAO',
        'sub': 'Tem vẹn nguyên không rách rời',
        'color': const Color(0xFF1E3A2F),
      },
      {
        'icon': Icons.receipt_long_rounded,
        'title': 'ẢNH 4: CHỨNG TỪ KÈM THEO',
        'sub': 'Biên nhận & phiếu giao nhận',
        'color': const Color(0xFF332042),
      },
    ];
    final info = mockTypes[index % mockTypes.length];
    final fallback = Container(
      color: info['color'] as Color,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(info['icon'] as IconData, size: 50, color: Colors.white70),
            ),
            const SizedBox(height: 10),
            Text(
              info['title'] as String,
              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8),
            ),
            const SizedBox(height: 4),
            Text(
              info['sub'] as String,
              style: const TextStyle(color: Colors.white60, fontSize: 10),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );

    return _buildEpodImage(photoPath, fit: BoxFit.cover, placeholder: fallback);
  }

  void _showEpodPreviewModal({int initialIndex = 0}) {
    final List<String> photos = _getEffectiveEpodPhotos();

    int currentPhotoIndex = initialIndex.clamp(0, photos.isEmpty ? 0 : photos.length - 1);
    final PageController pageCtrl = PageController(initialPage: currentPhotoIndex);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header - safe from RenderFlex overflow
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  color: const Color(0xFF1E293B),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Chứng từ giao hàng điện tử (e-POD)',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                        onPressed: () => Navigator.pop(ctx),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),

                // Image Carousel with Watermark
                Stack(
                  children: [
                    SizedBox(
                      height: 280,
                      width: double.infinity,
                      child: PageView.builder(
                        controller: pageCtrl,
                        itemCount: photos.length,
                        onPageChanged: (idx) {
                          setModalState(() {
                            currentPhotoIndex = idx;
                          });
                        },
                        itemBuilder: (ctx, idx) => _buildSinglePhotoView(photos[idx], idx, photos.length),
                      ),
                    ),

                    // Left arrow
                    if (photos.length > 1 && currentPhotoIndex > 0)
                      Positioned(
                        left: 8,
                        top: 100,
                        child: GestureDetector(
                          onTap: () {
                            pageCtrl.previousPage(
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeInOut,
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.5),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 16),
                          ),
                        ),
                      ),

                    // Right arrow
                    if (photos.length > 1 && currentPhotoIndex < photos.length - 1)
                      Positioned(
                        right: 8,
                        top: 100,
                        child: GestureDetector(
                          onTap: () {
                            pageCtrl.nextPage(
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeInOut,
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.5),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 16),
                          ),
                        ),
                      ),

                    // Watermark overlay box
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        color: Colors.black.withValues(alpha: 0.8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.verified_rounded, color: AppColors.success, size: 14),
                                const SizedBox(width: 6),
                                const Expanded(
                                  child: Text(
                                    'Xác thực GPS & Thời gian thực (e-POD)',
                                    style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '${currentPhotoIndex + 1}/${photos.length}',
                                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Tọa độ GPS: 10.7925° N, 106.7020° E',
                              style: TextStyle(color: Colors.white70, fontSize: 11),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'Thời gian: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())}',
                              style: const TextStyle(color: Colors.white70, fontSize: 11),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'Mã vận đơn: ${widget.orderCode}',
                              style: const TextStyle(color: Colors.white70, fontSize: 11),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'Người nhận: ${widget.draft.recipientName.isNotEmpty ? widget.draft.recipientName : "Khách hàng"} (Đã ký nhận)',
                              style: const TextStyle(color: Color(0xFF60A5FA), fontSize: 11, fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                // Multi-photo Thumbnail Selector Strip
                if (photos.length > 1)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    color: const Color(0xFF0F172A),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(photos.length, (i) {
                          final isSel = i == currentPhotoIndex;
                          return GestureDetector(
                            onTap: () {
                              pageCtrl.animateToPage(
                                i,
                                duration: const Duration(milliseconds: 250),
                                curve: Curves.easeInOut,
                              );
                            },
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: isSel ? AppColors.primary : Colors.white.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: isSel ? Colors.white : Colors.transparent),
                              ),
                              child: Text(
                                'Ảnh ${i + 1}',
                                style: TextStyle(
                                  color: isSel ? Colors.white : Colors.white70,
                                  fontSize: 11,
                                  fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  ),

                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 18),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Chứng từ hợp lệ, được bảo lưu vĩnh viễn trên GoShip Cloud.',
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEpodSection() {
    final List<String> photos = _getEffectiveEpodPhotos();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.verified_outlined, color: AppColors.primary, size: 18),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'Chứng từ điện tử (e-POD)',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textPrimary),
                  overflow: TextOverflow.ellipsis,
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
                  '${photos.length} ảnh chứng từ',
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.primary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Horizontal list of photo thumbnails
          SizedBox(
            height: 76,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: photos.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (ctx, idx) {
                final photo = photos[idx];
                final fallbackIcon = Center(
                  child: Icon(
                    idx == 0
                        ? Icons.inventory_2_rounded
                        : (idx == 1 ? Icons.draw_rounded : Icons.verified_user_rounded),
                    color: Colors.white70,
                    size: 26,
                  ),
                );
                return InkWell(
                  onTap: () => _showEpodPreviewModal(initialIndex: idx),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: 76,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        _buildEpodImage(photo, fit: BoxFit.cover, placeholder: fallbackIcon),
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            color: Colors.black.withValues(alpha: 0.65),
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Text(
                              'Ảnh ${idx + 1}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 10),
          InkWell(
            onTap: () => _showEpodPreviewModal(initialIndex: 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.touch_app_outlined, size: 14, color: AppColors.primary),
                    SizedBox(width: 4),
                    Text(
                      'Chạm để xem chi tiết ảnh có watermark GPS',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary),
                    ),
                  ],
                ),
                const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: AppColors.textMuted),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpeedChip(String label, double speed) {
    final isSelected = (_simulationSpeed - speed).abs() < 0.1;
    return InkWell(
      onTap: () => _setSpeed(speed),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accent : Colors.white12,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final draft = widget.draft;
    final totalFee = draft.finalTotalFee;
    final isCompleted = widget.orderStatus == OrderStatus.completed || _orderStatus == 3;
    final isFinding = !isCompleted && (_orderStatus == 0);
    final isMovingToPickup = !isCompleted && (_orderStatus == 1);
    final isDelivering = !isCompleted && (_orderStatus == 2);
    final formattedTime = DateFormat('HH:mm - dd/MM/yyyy').format(DateTime.now());

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Chi tiết đơn hàng',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: AppColors.textPrimary),
            ),
            Text(
              'Mã: ${widget.orderCode}',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          // 1. Full-screen Interactive Road Map
          Positioned.fill(
            child: AppInteractiveMap(
              points: _getLocationPoints(),
              customRoutePoints: _currentRoutePoints.isNotEmpty
                  ? _currentRoutePoints
                  : (_routePoints.isNotEmpty ? _routePoints : draft.drivingRoutePoints),
              traveledRoutePoints: _traveledRoutePoints,
              nearbyDrivers: isFinding ? _nearbyDrivers : const [],
              activeDriver: _activeDriver,
              selectedDriverId: widget.draft.selectedDriver?.id,
              autoFollowDriver: !isFinding && !isCompleted,
              isRadarSearching: isFinding,
              showRouteLine: true,
            ),
          ),

          // 2. Top Floating Status Chip on Map
          Positioned(
            top: 14,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(14),
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 3))],
              ),
              child: Row(
                children: [
                  if (isCompleted)
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: Color(0xFFDCFCE7),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 18),
                    )
                  else if (isFinding)
                    AnimatedBuilder(
                      animation: _pulseController,
                      builder: (ctx, child) {
                        return Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColors.accent.withValues(alpha: 0.15 + _pulseController.value * 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.radar_rounded, color: AppColors.accent, size: 18),
                        );
                      },
                    )
                  else if (isMovingToPickup)
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: Color(0xFFEFF6FF),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.directions_car_rounded, color: AppColors.primary, size: 18),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: Color(0xFFEFF6FF),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.local_shipping_rounded, color: AppColors.accent, size: 18),
                    ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isCompleted
                              ? 'Giao hàng thành công'
                              : (isFinding
                                  ? (widget.draft.selectedDriver != null
                                      ? 'Đang kết nối tài xế: ${widget.draft.selectedDriver!.name}'
                                      : 'Đang tìm tài xế gần bạn...')
                                  : (isMovingToPickup
                                      ? 'Tài xế đang đến điểm lấy'
                                      : 'Tài xế đang giao hàng')),
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textPrimary),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isCompleted
                              ? 'Đơn hàng đã hoàn thành & bảo lưu e-POD'
                              : (isFinding
                                  ? (widget.draft.selectedDriver != null
                                      ? 'Xe: ${widget.draft.selectedDriver!.vehicleName}'
                                      : 'Hệ thống đang quét các xe tải/van bán kính 1.5km')
                                  : (isMovingToPickup
                                      ? 'Cách ~$_remainingKm km • Dự kiến ~$_remainingMins phút'
                                      : 'Còn ~$_remainingKm km • Dự kiến ~$_remainingMins phút')),
                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        ),
                        if (!isCompleted && !isFinding) ...[
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: _progressPercent,
                              backgroundColor: const Color(0xFFE2E8F0),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                isMovingToPickup ? AppColors.primary : AppColors.accent,
                              ),
                              minHeight: 4,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 3. Floating Simulation Controller Toolbar
          if (widget.enableAutoSimulation && !isCompleted && !isFinding)
            Positioned(
              top: 86,
              left: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 2))],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      onTap: _togglePause,
                      child: Icon(
                        _isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(width: 1, height: 12, color: Colors.white24),
                    const SizedBox(width: 8),
                    _buildSpeedChip('1x', 1.0),
                    const SizedBox(width: 4),
                    _buildSpeedChip('3x', 3.0),
                    const SizedBox(width: 4),
                    _buildSpeedChip('5x', 5.0),
                    const SizedBox(width: 8),
                    Container(width: 1, height: 12, color: Colors.white24),
                    const SizedBox(width: 6),
                    InkWell(
                      onTap: _jumpToEndSimulation,
                      child: const Row(
                        children: [
                          Icon(Icons.fast_forward_rounded, color: Colors.amber, size: 15),
                          SizedBox(width: 2),
                          Text(
                            'Xong',
                            style: TextStyle(
                              color: Colors.amber,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // 4. Draggable Bottom Sheet with Driver Card & Full Order Details
          DraggableScrollableSheet(
            initialChildSize: isCompleted ? 0.55 : 0.30,
            minChildSize: isCompleted ? 0.22 : 0.26,
            maxChildSize: 0.92,
            snap: true,
            snapSizes: const [0.30, 0.55, 0.92],
            builder: (context, scrollController) {
              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 16,
                      offset: const Offset(0, -3),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Drag Handle Pill
                      Center(
                        child: Container(
                          margin: const EdgeInsets.only(top: 10, bottom: 6),
                          width: 44,
                          height: 4.5,
                          decoration: BoxDecoration(
                            color: const Color(0xFFCBD5E1),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),

                      // Driver Card / Finding Radar Card
                      Container(
                        margin: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: isFinding
                  ? Column(
                      children: [
                        Row(
                          children: [
                            SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(color: AppColors.accent, strokeWidth: 2.5),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'Đang kết nối tài xế phù hợp...',
                                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textPrimary),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.radar_rounded, size: 14, color: AppColors.accent),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                widget.draft.selectedDriver != null
                                    ? 'Đang phát tín hiệu điều phối tới bác tài...'
                                    : 'Đang kết nối các xe tải/van gần điểm lấy hàng...',
                                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.danger,
                              side: BorderSide(color: AppColors.danger.withValues(alpha: 0.4)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(vertical: 9),
                            ),
                            icon: const Icon(Icons.close_rounded, size: 16),
                            label: const Text('Hủy tìm kiếm chuyến xe', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                            onPressed: _showCancelOrderDialog,
                          ),
                        ),
                      ],
                    )
                  : Column(
                      children: [
                        Row(
                          children: [
                            AppAvatarWidget(
                              avatarUrl: _driverInfo['avatar'] as String?,
                              name: _driverInfo['name']?.toString() ?? 'Tài xế',
                              size: 48,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _driverInfo['name'],
                                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.textPrimary),
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      Text(
                                        _driverInfo['plate'],
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                                      ),
                                      const Padding(
                                        padding: EdgeInsets.symmetric(horizontal: 6),
                                        child: Text('•', style: TextStyle(color: AppColors.textMuted)),
                                      ),
                                      const Icon(Icons.star_rounded, size: 14, color: Color(0xFFF59E0B)),
                                      const SizedBox(width: 2),
                                      Text(
                                        '${_driverInfo['rating']}',
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // Action Buttons: Chat & Call
                        Row(
                          children: [
                            Expanded(
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        side: const BorderSide(color: AppColors.primary),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                      onPressed: _openInTripChat,
                                      icon: const Icon(Icons.chat_bubble_outline_rounded, color: AppColors.primary, size: 18),
                                      label: const Text('Nhắn tin', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
                                    ),
                                  ),
                                  if (_unreadChatCount > 0)
                                    Positioned(
                                      top: -6,
                                      right: 8,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFEF4444),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: Colors.white, width: 2),
                                        ),
                                        child: Text(
                                          '$_unreadChatCount',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  elevation: 0,
                                ),
                                onPressed: () {
                                  final rawPhone = _driverInfo['phone']?.toString().trim();
                                  final phoneToCall = (rawPhone != null && rawPhone.isNotEmpty)
                                      ? rawPhone
                                      : (_activeDriver?.phone.trim().isNotEmpty == true ? _activeDriver!.phone.trim() : '0917795211');
                                  CallService.makePhoneCall(
                                    context,
                                    phoneToCall,
                                    calleeName: _driverInfo['name']?.toString() ?? 'Tài xế GoShip',
                                    calleeRole: 'Tài xế GoShip',
                                    orderCode: widget.orderCode,
                                  );
                                },
                                icon: const Icon(Icons.phone_rounded, color: Colors.white, size: 18),
                                label: const Text('Gọi tài xế', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                              ),
                            ),
                          ],
                        ),
                        if (_orderStatus == 1) ...[
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: TextButton.icon(
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.danger,
                                padding: const EdgeInsets.symmetric(vertical: 4),
                              ),
                              icon: const Icon(Icons.cancel_outlined, size: 15),
                              label: const Text(
                                'Hủy chuyến xe này',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, decoration: TextDecoration.underline),
                              ),
                              onPressed: _showCancelOrderDialog,
                            ),
                          ),
                        ],
                      ],
                    ),
            ),

            // Swipe Up Hint Pill
            Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.keyboard_arrow_up_rounded, size: 18, color: AppColors.textMuted),
                    const SizedBox(width: 4),
                    const Text(
                      'Vuốt lên để xem chi tiết đơn hàng',
                      style: TextStyle(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ),

            // 3. Scrollable Order Details
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Progress Stepper Card (Figma progress-stepper)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Trạng thái đơn hàng',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.textPrimary),
                        ),
                        const SizedBox(height: 16),

                        _buildStepItem(
                          title: 'Đã tạo đơn hàng',
                          time: formattedTime,
                          isCompleted: true,
                          isLast: false,
                        ),
                        _buildStepItem(
                          title: isCompleted ? 'Tài xế đã nhận đơn' : (isFinding ? 'Đang tìm tài xế' : 'Tài xế đã nhận đơn'),
                          time: isCompleted ? 'Hoàn thành' : (isFinding ? 'Đang kết nối...' : 'Vừa xong'),
                          isCompleted: _orderStatus >= 1,
                          isActive: isFinding,
                          isLast: false,
                        ),
                        _buildStepItem(
                          title: isMovingToPickup ? 'Tài xế đang đến điểm lấy' : 'Đang trên đường giao',
                          time: isCompleted
                              ? 'Đã giao tới nơi'
                              : (isFinding
                                  ? 'Chờ tài xế'
                                  : (isMovingToPickup ? 'Cách ~$_remainingKm km' : 'Còn ~$_remainingKm km')),
                          isCompleted: isCompleted,
                          isActive: isMovingToPickup || isDelivering,
                          isLast: false,
                        ),
                        _buildStepItem(
                          title: 'Giao hàng thành công',
                          time: isCompleted ? 'Đã xác nhận e-POD' : 'Chờ xác nhận',
                          isCompleted: isCompleted,
                          isActive: false,
                          isLast: true,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Route Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Hành trình di chuyển',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.textPrimary),
                        ),
                        const SizedBox(height: 14),

                        // Pickup
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              margin: const EdgeInsets.only(top: 4),
                              width: 10,
                              height: 10,
                              decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Text('Nơi lấy hàng (Người gửi)', style: TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                                      if (draft.senderName.isNotEmpty) ...[
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            '• ${draft.senderName}${draft.senderPhone.isNotEmpty ? " (${draft.senderPhone})" : ""}',
                                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    draft.pickupAddress.isNotEmpty ? draft.pickupAddress : 'Landmark 81, Bình Thạnh, TP. HCM',
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        // Dropoffs
                        ...draft.dropoffAddresses.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final addr = entry.value;
                          final title = draft.dropoffAddresses.length > 1 ? 'Nơi giao hàng ${idx + 1}' : 'Nơi giao hàng';
                          final recipient = (idx < draft.dropoffRecipients.length) ? draft.dropoffRecipients[idx] : null;

                          return Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  margin: const EdgeInsets.only(top: 4),
                                  width: 10,
                                  height: 10,
                                  decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(title, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                                          if (recipient != null && recipient.name.isNotEmpty) ...[
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                '• ${recipient.name}${recipient.phone.isNotEmpty ? " (${recipient.phone})" : ""}',
                                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        addr.isNotEmpty ? addr : '25 Điện Biên Phủ, Quận 3, TP. HCM',
                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                                      ),
                                      if (recipient != null && (recipient.itemsDescription.isNotEmpty || recipient.dimensionSummary.isNotEmpty)) ...[
                                        const SizedBox(height: 4),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF1F5F9),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: const Color(0xFFE2E8F0)),
                                          ),
                                          child: Text(
                                            [
                                              if (recipient.itemsDescription.isNotEmpty) 'Hàng: ${recipient.itemsDescription}',
                                              if (recipient.dimensionSummary.isNotEmpty) recipient.dimensionSummary,
                                            ].join(' • '),
                                            style: const TextStyle(fontSize: 11, color: Color(0xFF475569), fontWeight: FontWeight.w500),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // 4. Electronic Proof of Delivery (e-POD: displayed when order is completed or live e-POD photos have been uploaded)
                  if (isCompleted || _liveEpodPhotos.isNotEmpty) ...[
                    _buildEpodSection(),
                    const SizedBox(height: 20),
                  ],

                  // Package & Payment Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Thông tin & Thanh toán',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.textPrimary),
                        ),
                        const SizedBox(height: 12),

                        _buildInfoRow(Icons.inventory_2_outlined, 'Hàng hóa: ${draft.packageCategory} (${draft.weightCategory})'),
                        const SizedBox(height: 8),
                        _buildInfoRow(Icons.payments_outlined, 'Thanh toán: ${draft.paymentMethod.title}'),

                        const Divider(height: 20, color: Color(0xFFE2E8F0)),

                        _buildSummaryPriceRow('Cước phí vận chuyển', '${_currencyFormat.format(draft.totalFeeBeforeDiscount)} đ'),
                        if (draft.discountAmount > 0) ...[
                          const SizedBox(height: 4),
                          _buildSummaryPriceRow('Khuyến mãi (${draft.promoCode})', '-${_currencyFormat.format(draft.discountAmount.round())} đ', isDiscount: true),
                        ],
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Tổng thanh toán', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                            Text(
                              '${_currencyFormat.format(totalFee)} đ',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFFFF6B00)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  if (_orderStatus == 3) ...[
                    const SizedBox(height: 20),

                    // Rating Action Card / Button (SRS 5.3.1 Rating Pop-up)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _hasRated ? const Color(0xFFF0FDF4) : const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _hasRated ? AppColors.success.withValues(alpha: 0.3) : const Color(0xFFFDE68A)),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _hasRated ? Icons.check_circle_rounded : Icons.stars_rounded,
                            color: _hasRated ? AppColors.success : const Color(0xFFF59E0B),
                            size: 28,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _hasRated ? 'Đã đánh giá: $_selectedRating sao' : 'Đánh giá chuyến đi này',
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textPrimary),
                                ),
                                Text(
                                  _hasRated ? (_userComment.isNotEmpty ? _userComment : 'Cảm ơn phản hồi của bạn!') : 'Chấm điểm tài xế & chất lượng giao hàng',
                                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _hasRated ? AppColors.success : const Color(0xFFF59E0B),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: _showRatingModal,
                            child: Text(
                              _hasRated ? 'Sửa' : 'Đánh giá',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),

                  // Return Home Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.primary, width: 1.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
                      child: const Text(
                        'Về trang chủ',
                        style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 15),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  },
),
],
),
);
}

  Widget _buildStepItem({
    required String title,
    required String time,
    required bool isCompleted,
    bool isActive = false,
    required bool isLast,
  }) {
    final color = isCompleted ? (isActive ? AppColors.accent : AppColors.primary) : const Color(0xFFCBD5E1);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
                child: isCompleted && !isActive
                    ? const Icon(Icons.check, size: 9, color: Colors.white)
                    : null,
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: isCompleted ? AppColors.primary : const Color(0xFFE2E8F0),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 14),
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isCompleted ? AppColors.textPrimary : AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  time,
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF64748B)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 13, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryPriceRow(String label, String value, {bool isDiscount = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: isDiscount ? AppColors.success : AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
