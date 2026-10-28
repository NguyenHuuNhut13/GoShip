import 'dart:async';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/network/route_service.dart';
import '../../../../../core/services/firestore_order_service.dart';
import '../../../../../core/services/location_service.dart';
import '../../../../../core/widgets/app_interactive_map.dart';
import '../../models/order_draft_model.dart';
import '../../models/simulated_driver_model.dart';
import '../widgets/location_picker_sheet.dart';

class Step1AddressScreen extends StatefulWidget {
  final OrderDraftModel draft;
  final VoidCallback onNext;

  const Step1AddressScreen({
    super.key,
    required this.draft,
    required this.onNext,
  });

  @override
  State<Step1AddressScreen> createState() => _Step1AddressScreenState();
}

class _Step1AddressScreenState extends State<Step1AddressScreen> {
  bool _isLoadingRoute = false;
  bool _isMapFullscreen = false;
  late List<String> _dropoffIds;
  List<SimulatedDriver> _nearbyDrivers = [];
  StreamSubscription<List<Map<String, dynamic>>>? _onlineDriversSub;

  @override
  void initState() {
    super.initState();
    if (widget.draft.dropoffAddresses.isEmpty) {
      widget.draft.dropoffAddresses.add('');
    }
    while (widget.draft.dropoffLatLngs.length < widget.draft.dropoffAddresses.length) {
      widget.draft.dropoffLatLngs.add(null);
    }
    while (widget.draft.dropoffRecipients.length < widget.draft.dropoffAddresses.length) {
      widget.draft.dropoffRecipients.add(DropoffRecipient());
    }
    _dropoffIds = List.generate(
      widget.draft.dropoffAddresses.length,
      (i) => 'dropoff_id_${DateTime.now().microsecondsSinceEpoch}_$i',
    );
    _initNearbyDrivers();
    if (widget.draft.pickupAddress.isNotEmpty && widget.draft.dropoffAddresses.any((a) => a.isNotEmpty)) {
      _fetchRealRoute();
    }
  }

  @override
  void dispose() {
    _onlineDriversSub?.cancel();
    super.dispose();
  }

  void _initNearbyDrivers() {
    _onlineDriversSub?.cancel();
    _onlineDriversSub = FirestoreOrderService.streamOnlineDrivers().listen((driverList) {
      if (!mounted) return;
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
          widget.draft.selectedDriver = match;
        }
      });
    });
  }

  void _showDriverSelectionSheet(SimulatedDriver driver) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final isCurrentlySelected = widget.draft.selectedDriver?.id == driver.id;

            return SafeArea(
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
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 26,
                          backgroundColor: AppColors.primaryLight,
                          child: const Icon(Icons.person_rounded, size: 28, color: AppColors.primary),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                driver.name,
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: AppColors.textPrimary),
                              ),
                              const SizedBox(height: 3),
                              Row(
                                children: [
                                  const Icon(Icons.star_rounded, size: 16, color: Color(0xFFF59E0B)),
                                  const SizedBox(width: 3),
                                  Text(
                                    '${driver.rating}',
                                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textPrimary),
                                  ),
                                  Text(
                                    ' (${driver.tripsCount} chuyến thành công)',
                                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(height: 1, color: AppColors.border),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.local_shipping_rounded, size: 18, color: AppColors.primary),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  driver.vehicleName,
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textPrimary),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: Text(
                                  driver.plate,
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppColors.textPrimary),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              const Icon(Icons.place_rounded, size: 18, color: AppColors.accent),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  driver.addressHint,
                                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (isCurrentlySelected)
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                side: const BorderSide(color: AppColors.danger),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: () {
                                setState(() {
                                  widget.draft.selectedDriver = null;
                                });
                                Navigator.pop(ctx);
                              },
                              child: const Text(
                                'Bỏ chọn',
                                style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.danger),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.success,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: () => Navigator.pop(ctx),
                              icon: const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                              label: const Text(
                                'Đang ưu tiên tài xế này',
                                style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      )
                    else
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () {
                            setState(() {
                              widget.draft.selectedDriver = driver;
                            });
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Đã chọn tài xế ưu tiên: ${driver.name} (${driver.vehicleName})'),
                                backgroundColor: AppColors.success,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                          icon: const Icon(Icons.how_to_reg_rounded, color: Colors.white, size: 18),
                          label: const Text(
                            'Chọn tài xế này làm tài xế ưu tiên',
                            style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white, fontSize: 14),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _addDropoffField() {
    if (widget.draft.dropoffAddresses.length >= 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tối đa 4 điểm giao hàng cho một chuyến xe')),
      );
      return;
    }
    setState(() {
      widget.draft.dropoffAddresses.add('');
      widget.draft.dropoffLatLngs.add(null);
      widget.draft.dropoffRecipients.add(DropoffRecipient());
      _dropoffIds.add('dropoff_id_${DateTime.now().microsecondsSinceEpoch}_${_dropoffIds.length}');
      widget.draft.syncRecipientsWithDropoffs();
      _updateDraftMetrics();
    });
  }

  void _removeDropoffField(int index) {
    if (widget.draft.dropoffAddresses.length <= 1) return;
    setState(() {
      widget.draft.dropoffAddresses.removeAt(index);
      if (index < widget.draft.dropoffLatLngs.length) {
        widget.draft.dropoffLatLngs.removeAt(index);
      }
      if (index < widget.draft.dropoffRecipients.length) {
        widget.draft.dropoffRecipients.removeAt(index);
      }
      if (index < _dropoffIds.length) {
        _dropoffIds.removeAt(index);
      }
      widget.draft.syncRecipientsWithDropoffs();
      _updateDraftMetrics();
      _fetchRealRoute();
    });
  }

  void _swapDropoffs(int indexA, int indexB) {
    if (indexA < 0 ||
        indexB < 0 ||
        indexA >= widget.draft.dropoffAddresses.length ||
        indexB >= widget.draft.dropoffAddresses.length) {
      return;
    }
    setState(() {
      final tempAddr = widget.draft.dropoffAddresses[indexA];
      widget.draft.dropoffAddresses[indexA] = widget.draft.dropoffAddresses[indexB];
      widget.draft.dropoffAddresses[indexB] = tempAddr;

      while (widget.draft.dropoffLatLngs.length <= (indexA > indexB ? indexA : indexB)) {
        widget.draft.dropoffLatLngs.add(null);
      }
      final tempLatLng = widget.draft.dropoffLatLngs[indexA];
      widget.draft.dropoffLatLngs[indexA] = widget.draft.dropoffLatLngs[indexB];
      widget.draft.dropoffLatLngs[indexB] = tempLatLng;

      while (widget.draft.dropoffRecipients.length <= (indexA > indexB ? indexA : indexB)) {
        widget.draft.dropoffRecipients.add(DropoffRecipient());
      }
      final tempRecip = widget.draft.dropoffRecipients[indexA];
      widget.draft.dropoffRecipients[indexA] = widget.draft.dropoffRecipients[indexB];
      widget.draft.dropoffRecipients[indexB] = tempRecip;

      if (indexA < _dropoffIds.length && indexB < _dropoffIds.length) {
        final tempId = _dropoffIds[indexA];
        _dropoffIds[indexA] = _dropoffIds[indexB];
        _dropoffIds[indexB] = tempId;
      }

      widget.draft.syncRecipientsWithDropoffs();
      _fetchRealRoute();
    });
  }

  void _onReorderDropoffs(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final addr = widget.draft.dropoffAddresses.removeAt(oldIndex);
      widget.draft.dropoffAddresses.insert(newIndex, addr);

      if (oldIndex < widget.draft.dropoffLatLngs.length) {
        final coord = widget.draft.dropoffLatLngs.removeAt(oldIndex);
        widget.draft.dropoffLatLngs.insert(newIndex, coord);
      }

      if (oldIndex < widget.draft.dropoffRecipients.length) {
        final recip = widget.draft.dropoffRecipients.removeAt(oldIndex);
        widget.draft.dropoffRecipients.insert(newIndex, recip);
      }

      if (oldIndex < _dropoffIds.length) {
        final id = _dropoffIds.removeAt(oldIndex);
        _dropoffIds.insert(newIndex, id);
      }

      widget.draft.syncRecipientsWithDropoffs();
      _fetchRealRoute();
    });
  }

  void _swapPickupAndFirstDropoff() {
    if (widget.draft.dropoffAddresses.isEmpty) return;
    setState(() {
      final tempText = widget.draft.pickupAddress;
      widget.draft.pickupAddress = widget.draft.dropoffAddresses[0];
      widget.draft.dropoffAddresses[0] = tempText;

      final tempLatLng = widget.draft.pickupLatLng;
      widget.draft.pickupLatLng = widget.draft.dropoffLatLngs.isNotEmpty ? widget.draft.dropoffLatLngs[0] : null;
      if (widget.draft.dropoffLatLngs.isNotEmpty) {
        widget.draft.dropoffLatLngs[0] = tempLatLng;
      }
      _fetchRealRoute();
    });
  }

  Future<void> _pickPickupLocation() async {
    final result = await LocationPickerSheet.show(
      context: context,
      title: 'Điểm lấy hàng',
      initialAddress: widget.draft.pickupAddress,
      initialLatLng: widget.draft.pickupLatLng,
    );

    if (result != null) {
      setState(() {
        widget.draft.pickupAddress = result.address;
        widget.draft.pickupLatLng = result.latLng;
        _updateDraftMetrics();
      });
      if (result.latLng != null && (result.address.startsWith('Vị trí') || result.address.startsWith('Tọa độ') || result.address.startsWith('Điểm định vị'))) {
        LocationService.getAddressFromCoordinates(result.latLng!).then((cleanAddr) {
          if (mounted && cleanAddr.isNotEmpty && !cleanAddr.startsWith('Điểm định vị')) {
            setState(() {
              widget.draft.pickupAddress = cleanAddr;
            });
          }
        });
      }
      _initNearbyDrivers();
      _fetchRealRoute();
    }
  }

  Future<void> _pickDropoffLocation(int index) async {
    final label = widget.draft.dropoffAddresses.length > 1 ? 'Điểm giao hàng ${index + 1}' : 'Điểm giao hàng';
    final result = await LocationPickerSheet.show(
      context: context,
      title: label,
      initialAddress: widget.draft.dropoffAddresses[index],
      initialLatLng: index < widget.draft.dropoffLatLngs.length ? widget.draft.dropoffLatLngs[index] : null,
    );

    if (result != null) {
      setState(() {
        widget.draft.dropoffAddresses[index] = result.address;
        while (widget.draft.dropoffLatLngs.length <= index) {
          widget.draft.dropoffLatLngs.add(null);
        }
        widget.draft.dropoffLatLngs[index] = result.latLng;
        _updateDraftMetrics();
      });
      if (result.latLng != null && (result.address.startsWith('Vị trí') || result.address.startsWith('Tọa độ') || result.address.startsWith('Điểm định vị'))) {
        LocationService.getAddressFromCoordinates(result.latLng!).then((cleanAddr) {
          if (mounted && cleanAddr.isNotEmpty && !cleanAddr.startsWith('Điểm định vị') && index < widget.draft.dropoffAddresses.length) {
            setState(() {
              widget.draft.dropoffAddresses[index] = cleanAddr;
            });
          }
        });
      }
      _fetchRealRoute();
    }
  }

  Future<void> _fetchRealRoute() async {
    final List<LatLng> waypoints = [];
    if (widget.draft.pickupLatLng != null) {
      waypoints.add(widget.draft.pickupLatLng!);
    } else if (widget.draft.pickupAddress.isNotEmpty) {
      waypoints.add(const LatLng(10.7946, 106.7218));
    }

    for (int i = 0; i < widget.draft.dropoffAddresses.length; i++) {
      if (i < widget.draft.dropoffLatLngs.length && widget.draft.dropoffLatLngs[i] != null) {
        waypoints.add(widget.draft.dropoffLatLngs[i]!);
      } else if (widget.draft.dropoffAddresses[i].isNotEmpty) {
        final sampleCoords = [
          const LatLng(10.7925, 106.7020),
          const LatLng(10.7716, 106.7044),
          const LatLng(10.7725, 106.6980),
          const LatLng(10.8185, 106.6588),
        ];
        waypoints.add(i < sampleCoords.length ? sampleCoords[i] : LatLng(10.78 + i * 0.01, 106.70 + i * 0.01));
      }
    }

    if (waypoints.length >= 2) {
      setState(() => _isLoadingRoute = true);
      final result = await RouteService.getDrivingRoute(waypoints);
      if (!mounted) return;
      setState(() {
        _isLoadingRoute = false;
        widget.draft.drivingRoutePoints = result.polylinePoints;
        widget.draft.distanceKm = result.distanceKm;
        widget.draft.durationMinutes = result.durationMinutes;
      });
    }
  }

  void _updateDraftMetrics() {
    if (widget.draft.distanceKm == 0.0) {
      widget.draft.distanceKm = double.parse((4.2 + (widget.draft.dropoffAddresses.length - 1) * 3.0).toStringAsFixed(1));
      widget.draft.durationMinutes = 15 + (widget.draft.dropoffAddresses.length - 1) * 10;
    }
  }

  List<LocationPoint> _getLocationPoints() {
    final List<LocationPoint> pts = [];
    if (widget.draft.pickupAddress.isNotEmpty || widget.draft.pickupLatLng != null) {
      pts.add(LocationPoint(
        title: 'Điểm lấy hàng',
        address: widget.draft.pickupAddress,
        latLng: widget.draft.pickupLatLng ?? const LatLng(10.7946, 106.7218),
        isPickup: true,
      ));
    }

    for (int i = 0; i < widget.draft.dropoffAddresses.length; i++) {
      final addr = widget.draft.dropoffAddresses[i];
      if (addr.isNotEmpty || (i < widget.draft.dropoffLatLngs.length && widget.draft.dropoffLatLngs[i] != null)) {
        final coord = (i < widget.draft.dropoffLatLngs.length && widget.draft.dropoffLatLngs[i] != null)
            ? widget.draft.dropoffLatLngs[i]!
            : LatLng(10.7925 - i * 0.01, 106.7020 + i * 0.01);
        pts.add(LocationPoint(
          title: 'Điểm giao ${i + 1}',
          address: addr,
          latLng: coord,
          isPickup: false,
          index: i + 1,
        ));
      }
    }
    return pts;
  }

  @override
  Widget build(BuildContext context) {
    final bool hasRoutePreview = widget.draft.pickupAddress.isNotEmpty &&
        widget.draft.dropoffAddresses.any((a) => a.isNotEmpty);

    if (_isMapFullscreen && hasRoutePreview) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) {
            setState(() => _isMapFullscreen = false);
          }
        },
        child: Scaffold(
          body: SizedBox.expand(
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Fullscreen interactive map
                AppInteractiveMap(
                  points: _getLocationPoints(),
                  customRoutePoints: widget.draft.drivingRoutePoints,
                  nearbyDrivers: _nearbyDrivers,
                  selectedDriverId: widget.draft.selectedDriver?.id,
                  onDriverSelected: (driver) => _showDriverSelectionSheet(driver),
                  showRouteLine: true,
                  isMiniMap: false,
                  bottomControlsPadding: widget.draft.selectedDriver != null ? 85 : 20,
                ),

                // Floating Top Bar with unified back button and route summary (DUY NHẤT 1 NÚT THU NHỎ / QUAY LẠI)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.95),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: const [
                            BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2)),
                          ],
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary, size: 18),
                              tooltip: 'Thu nhỏ bản đồ',
                              onPressed: () => setState(() => _isMapFullscreen = false),
                            ),
                            const Expanded(
                              child: Text(
                                'Bản đồ lộ trình & Tài xế',
                                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textPrimary),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (widget.draft.distanceKm > 0)
                              Padding(
                                padding: const EdgeInsets.only(right: 10),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppColors.vanBg,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '${widget.draft.distanceKm} km',
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // Floating Selected Driver Card (chỉ hiển thị khi đã chọn tài xế, không còn nút thu nhỏ đè ở dưới)
                if (widget.draft.selectedDriver != null)
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 24,
                    child: SafeArea(
                      top: false,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFBBF7D0)),
                          boxShadow: const [
                            BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 3)),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(
                                color: Color(0xFFDCFCE7),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.check_rounded, color: AppColors.success, size: 18),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'ĐÃ CHỌN ƯU TIÊN TÀI XẾ',
                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.success, letterSpacing: 0.5),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${widget.draft.selectedDriver!.name} • ${widget.draft.selectedDriver!.vehicleName}',
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            InkWell(
                              onTap: () => setState(() => widget.draft.selectedDriver = null),
                              child: const Padding(
                                padding: EdgeInsets.all(4),
                                child: Icon(Icons.close_rounded, size: 18, color: AppColors.textSecondary),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Địa chỉ giao hàng',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18, color: AppColors.textPrimary),
        ),
        actions: [
          Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.only(right: 16),
            child: const Text(
              'Bước 1/3',
              style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Clean Route Inputs Card (Giao diện địa điểm giao và nhận tinh gọn)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Pickup Location Row (🔵)
                        _buildClickableAddressRow(
                          value: widget.draft.pickupAddress,
                          color: AppColors.primary,
                          placeholder: 'Chạm để chọn điểm lấy hàng...',
                          onTap: _pickPickupLocation,
                        ),

                        // Route line & Swap button
                        Row(
                          children: [
                            const SizedBox(width: 9),
                            Container(width: 2, height: 16, color: AppColors.border),
                            const Expanded(child: Divider(indent: 12, height: 16)),
                            IconButton(
                              icon: const Icon(Icons.swap_vert_rounded, color: AppColors.primary, size: 20),
                              onPressed: _swapPickupAndFirstDropoff,
                              tooltip: 'Hoán đổi điểm lấy/giao',
                              constraints: const BoxConstraints(minWidth: 30, minHeight: 26),
                              padding: EdgeInsets.zero,
                            ),
                          ],
                        ),

                        // Dropoff Locations with Drag-and-Drop & Quick Swap Button
                        Theme(
                          data: Theme.of(context).copyWith(
                            canvasColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                          ),
                          child: ReorderableListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            buildDefaultDragHandles: false,
                            itemCount: widget.draft.dropoffAddresses.length,
                            onReorder: _onReorderDropoffs,
                            itemBuilder: (context, index) {
                              final isLast = index == widget.draft.dropoffAddresses.length - 1;
                              final placeholder = widget.draft.dropoffAddresses.length > 1
                                  ? 'Chạm để chọn điểm giao ${index + 1}...'
                                  : 'Chạm để chọn điểm giao hàng...';

                              return Container(
                                key: ValueKey(_dropoffIds[index]),
                                child: Column(
                                  children: [
                                    _buildClickableAddressRow(
                                      index: index,
                                      value: widget.draft.dropoffAddresses[index],
                                      color: AppColors.accent,
                                      placeholder: placeholder,
                                      onTap: () => _pickDropoffLocation(index),
                                      canRemove: widget.draft.dropoffAddresses.length > 1,
                                      onRemove: () => _removeDropoffField(index),
                                      canDrag: widget.draft.dropoffAddresses.length > 1,
                                      isDropoff: true,
                                    ),
                                    if (!isLast)
                                      Row(
                                        children: [
                                          const SizedBox(width: 9),
                                          Container(width: 2, height: 14, color: AppColors.border),
                                          const Expanded(child: Divider(indent: 12, height: 14)),
                                          IconButton(
                                            icon: const Icon(Icons.swap_vert_rounded, color: AppColors.accent, size: 18),
                                            onPressed: () => _swapDropoffs(index, index + 1),
                                            tooltip: 'Hoán đổi điểm giao ${index + 1} và ${index + 2}',
                                            constraints: const BoxConstraints(minWidth: 28, minHeight: 24),
                                            padding: EdgeInsets.zero,
                                          ),
                                        ],
                                      ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),

                        const SizedBox(height: 10),

                        // Add Delivery Location Button (Thêm địa điểm giao hàng)
                        InkWell(
                          onTap: _addDropoffField,
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(Icons.add_circle_outline_rounded, color: AppColors.primary, size: 18),
                                SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    'Thêm điểm giao hàng (Đa điểm)',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Route Preview Card (Real Turn-by-Turn Map)
                  if (hasRoutePreview) ...[
                    const SizedBox(height: 18),
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppColors.border),
                        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 3))],
                      ),
                      child: Column(
                        children: [
                          // Header route info
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                            child: Row(
                              children: [
                                const Icon(Icons.route_rounded, color: AppColors.primary, size: 18),
                                const SizedBox(width: 6),
                                const Expanded(
                                  child: Text(
                                    'Lộ trình thực tế',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textPrimary),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                if (_isLoadingRoute)
                                  const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                else
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: AppColors.vanBg,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      '${widget.draft.distanceKm} km • ~${widget.draft.durationMinutes} phút',
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary),
                                    ),
                                  ),
                              ],
                            ),
                          ),

                          // Selected Driver Indicator Banner (if any selected)
                          if (widget.draft.selectedDriver != null)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF0FDF4),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFFBBF7D0)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 16),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Đã chọn ưu tiên: ${widget.draft.selectedDriver!.name} (${widget.draft.selectedDriver!.vehicleName})',
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.success),
                                      ),
                                    ),
                                    InkWell(
                                      onTap: () => setState(() => widget.draft.selectedDriver = null),
                                      child: const Icon(Icons.close_rounded, size: 16, color: AppColors.textSecondary),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                          // Mini Map Preview with turn-by-turn road curves and fullscreen button
                          SizedBox(
                            height: 230,
                            child: ClipRRect(
                              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(17)),
                              child: Stack(
                                children: [
                                  Positioned.fill(
                                    child: AppInteractiveMap(
                                      points: _getLocationPoints(),
                                      customRoutePoints: widget.draft.drivingRoutePoints,
                                      nearbyDrivers: _nearbyDrivers,
                                      selectedDriverId: widget.draft.selectedDriver?.id,
                                      onDriverSelected: (driver) => _showDriverSelectionSheet(driver),
                                      showRouteLine: true,
                                      isMiniMap: true,
                                    ),
                                  ),
                                  Positioned(
                                    top: 10,
                                    right: 10,
                                    child: Material(
                                      color: Colors.white.withValues(alpha: 0.94),
                                      borderRadius: BorderRadius.circular(20),
                                      elevation: 3,
                                      shadowColor: Colors.black26,
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(20),
                                        onTap: () => setState(() => _isMapFullscreen = true),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: const [
                                              Icon(Icons.open_in_full_rounded, size: 13, color: AppColors.primary),
                                              SizedBox(width: 4),
                                              Text(
                                                'Toàn màn hình',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w700,
                                                  color: AppColors.primary,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline_rounded, color: AppColors.primary, size: 20),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Chạm vào Điểm lấy và Điểm giao hàng ở trên để tìm kiếm địa chỉ hoặc chọn trực tiếp từ bản đồ.',
                              style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Bottom Action Bar
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: AppColors.border)),
              boxShadow: [
                BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -2)),
              ],
            ),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () {
                  if (_isLoadingRoute) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Hệ thống đang tính toán lộ trình và khoảng cách di chuyển, vui lòng chờ trong giây lát...'),
                        backgroundColor: AppColors.accent,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                    return;
                  }
                  if (widget.draft.pickupAddress.trim().isEmpty || widget.draft.pickupLatLng == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Vui lòng chọn điểm lấy hàng và tọa độ GPS hợp lệ'),
                        backgroundColor: AppColors.danger,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                    return;
                  }
                  for (int i = 0; i < widget.draft.dropoffAddresses.length; i++) {
                    if (widget.draft.dropoffAddresses[i].trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Vui lòng chọn đầy đủ điểm giao hàng ${i + 1}'),
                          backgroundColor: AppColors.danger,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                      return;
                    }
                    if (i >= widget.draft.dropoffLatLngs.length || widget.draft.dropoffLatLngs[i] == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Vui lòng chọn tọa độ GPS hợp lệ cho điểm giao ${i + 1}'),
                          backgroundColor: AppColors.danger,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                      return;
                    }
                  }
                  widget.onNext();
                },
                child: Text(
                  'Tiếp tục sang bước 2 (${widget.draft.dropoffAddresses.length} điểm giao)',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClickableAddressRow({
    required String value,
    required Color color,
    required String placeholder,
    required VoidCallback onTap,
    int? index,
    bool isDropoff = false,
    bool canRemove = false,
    VoidCallback? onRemove,
    bool canDrag = false,
  }) {
    final bool hasValue = value.trim().isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
      child: Row(
        children: [
          // Nút tròn màu cam / xanh ở đầu thẻ - kiêm chức năng chạm giữ để kéo thả đổi vị trí
          if (canDrag && index != null) ...[
            ReorderableDragStartListener(
              index: index,
              child: Tooltip(
                message: 'Chạm giữ để kéo thả đổi thứ tự',
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.35),
                        blurRadius: 3,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(Icons.unfold_more_rounded, size: 12, color: Colors.white),
                  ),
                ),
              ),
            ),
          ] else ...[
            SizedBox(
              width: 20,
              height: 20,
              child: Center(
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
              ),
            ),
          ],
          const SizedBox(width: 10),
          Expanded(
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                child: Text(
                  hasValue ? value : placeholder,
                  style: TextStyle(
                    fontWeight: hasValue ? FontWeight.w600 : FontWeight.normal,
                    fontSize: 14,
                    color: hasValue ? AppColors.textPrimary : AppColors.textMuted,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
          if (canRemove)
            IconButton(
              icon: const Icon(Icons.close_rounded, color: Colors.redAccent, size: 18),
              onPressed: onRemove,
              constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
              padding: EdgeInsets.zero,
              tooltip: 'Xóa điểm này',
            ),
        ],
      ),
    );
  }
}
