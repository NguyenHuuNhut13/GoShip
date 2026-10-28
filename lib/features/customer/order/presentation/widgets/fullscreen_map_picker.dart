import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/network/geocoding_service.dart';
import '../../../../../core/services/location_service.dart';

class FullscreenMapPickerResult {
  final LatLng latLng;
  final String addressTitle;

  FullscreenMapPickerResult({
    required this.latLng,
    required this.addressTitle,
  });
}

class FullscreenMapPickerScreen extends StatefulWidget {
  final String targetTitle;
  final LatLng initialCenter;
  final String? initialAddress;

  const FullscreenMapPickerScreen({
    super.key,
    required this.targetTitle,
    this.initialCenter = const LatLng(10.7946, 106.7150),
    this.initialAddress,
  });

  @override
  State<FullscreenMapPickerScreen> createState() => _FullscreenMapPickerScreenState();
}

class _FullscreenMapPickerScreenState extends State<FullscreenMapPickerScreen> {
  late final MapController _mapController;
  late LatLng _selectedLocation;
  String _locationName = '';
  bool _isMoving = false;
  bool _isLocatingGps = false;

  final TextEditingController _searchController = TextEditingController();
  List<AddressSearchResult> _searchResults = [];
  bool _isSearching = false;
  bool _isResolvingAddress = false;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _selectedLocation = widget.initialCenter;
    final initial = widget.initialAddress?.trim();
    if (initial != null && initial.isNotEmpty && !initial.startsWith('Tọa độ') && !initial.startsWith('Vị trí')) {
      _locationName = initial;
    } else {
      _locationName = 'Đang xác định tên đường...';
      _isResolvingAddress = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _resolveAddressFor(_selectedLocation);
      });
    }

    // Auto-locate GPS if no address specified
    if (widget.initialAddress == null || widget.initialAddress!.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _moveToRealCurrentLocation(silent: true);
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _moveToRealCurrentLocation({bool silent = false}) async {
    setState(() => _isLocatingGps = true);
    final gpsPoint = await LocationService.getCurrentLocation();
    if (!mounted) return;
    setState(() => _isLocatingGps = false);

    if (gpsPoint != null) {
      _mapController.move(gpsPoint, 16.5);
      final address = await LocationService.getAddressFromCoordinates(gpsPoint);
      if (!mounted) return;
      setState(() {
        _selectedLocation = gpsPoint;
        _locationName = address;
      });
      if (!silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã định vị vị trí hiện tại: $address'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } else if (!silent) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không thể lấy vị trí GPS. Vui lòng cho phép quyền truy cập vị trí trên trình duyệt / thiết bị.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _onSearchChanged(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);
    final results = await GeocodingService.search(query);
    if (!mounted) return;
    setState(() {
      _searchResults = results;
      _isSearching = false;
    });
  }

  void _selectSearchResult(AddressSearchResult res) {
    _mapController.move(res.latLng, 16.5);
    setState(() {
      _selectedLocation = res.latLng;
      _locationName = res.fullAddress;
      _searchResults = [];
      _searchController.clear();
      FocusScope.of(context).unfocus();
    });
  }

  Future<void> _resolveAddressFor(LatLng target) async {
    setState(() => _isResolvingAddress = true);
    final addr = await LocationService.getAddressFromCoordinates(target);
    if (!mounted || _selectedLocation != target) return;
    setState(() {
      _locationName = addr;
      _isResolvingAddress = false;
    });
  }

  void _onMapPositionChanged(MapCamera camera, bool hasGesture) {
    if (hasGesture) {
      setState(() {
        _isMoving = true;
        _isResolvingAddress = true;
        _selectedLocation = camera.center;
        _locationName = 'Đang xác định tên đường...';
      });
    }
  }

  Future<void> _onMapMoveEnd() async {
    setState(() => _isMoving = false);
    await _resolveAddressFor(_selectedLocation);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // 1. High Performance Fullscreen Map
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: widget.initialCenter,
              initialZoom: 15.0,
              minZoom: 5.0,
              maxZoom: 18.5,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.drag | InteractiveFlag.pinchZoom | InteractiveFlag.doubleTapZoom,
              ),
              onPositionChanged: _onMapPositionChanged,
              onMapEvent: (event) {
                if (event is MapEventMoveEnd) {
                  _onMapMoveEnd();
                }
              },
              onTap: (tapPosition, latLng) async {
                _mapController.move(latLng, _mapController.camera.zoom);
                setState(() {
                  _selectedLocation = latLng;
                  _locationName = 'Đang xác định tên đường...';
                  _searchResults = [];
                  FocusScope.of(context).unfocus();
                });
                await _resolveAddressFor(latLng);
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
            ],
          ),

          // 2. Fixed Center Pin with Bounce Effect
          Center(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 38), // Center needle point
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    transform: Matrix4.translationValues(0, _isMoving ? -10 : 0, 0),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.accent.withValues(alpha: 0.4),
                          blurRadius: 14,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.location_on_rounded, color: Colors.white, size: 28),
                  ),
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.3),
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 3. Top Floating Search Bar & Suggestions
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Search Input Container
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 3))],
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                          onPressed: () => Navigator.pop(context),
                        ),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            onChanged: _onSearchChanged,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                            decoration: InputDecoration(
                              hintText: 'Tìm địa chỉ (VD: 123 Lê Lợi, Landmark...)',
                              hintStyle: const TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.normal),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(vertical: 12),
                              suffixIcon: _searchController.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear_rounded, size: 18),
                                      onPressed: () {
                                        _searchController.clear();
                                        _onSearchChanged('');
                                      },
                                    )
                                  : null,
                            ),
                          ),
                        ),
                        if (_isSearching || _isLocatingGps)
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                          )
                        else
                          IconButton(
                            icon: const Icon(Icons.my_location_rounded, color: AppColors.primary),
                            onPressed: () => _moveToRealCurrentLocation(),
                            tooltip: 'Định vị vị trí GPS thật của tôi',
                          ),
                      ],
                    ),
                  ),

                  // Search Dropdown List
                  if (_searchResults.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      constraints: const BoxConstraints(maxHeight: 250),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 12, offset: Offset(0, 4))],
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        itemCount: _searchResults.length,
                        separatorBuilder: (_, __) => const Divider(height: 1, indent: 48),
                        itemBuilder: (ctx, idx) {
                          final res = _searchResults[idx];
                          return ListTile(
                            dense: true,
                            leading: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(
                                color: Color(0xFFEAF4FF),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.location_on_outlined, color: AppColors.primary, size: 18),
                            ),
                            title: Text(res.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                            subtitle: Text(
                              res.fullAddress,
                              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            onTap: () => _selectSearchResult(res),
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // 4. Bottom Confirmation Sheet
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 16, offset: Offset(0, -4))],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.place_rounded, color: AppColors.accent, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Ghim vị trí cho ${widget.targetTitle}',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                if (_isResolvingAddress) ...[
                                  const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                Expanded(
                                  child: Text(
                                    _locationName,
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () async {
                        String finalAddress = _locationName;
                        if (_isResolvingAddress || 
                            finalAddress.startsWith('Đang') || 
                            finalAddress.startsWith('Tọa độ') || 
                            finalAddress.startsWith('Vị trí') ||
                            finalAddress.startsWith('Điểm định vị')) {
                          setState(() => _isResolvingAddress = true);
                          finalAddress = await LocationService.getAddressFromCoordinates(_selectedLocation);
                          if (!mounted) return;
                          setState(() {
                            _locationName = finalAddress;
                            _isResolvingAddress = false;
                          });
                        }

                        if (!context.mounted) return;
                        Navigator.pop(
                          context,
                          FullscreenMapPickerResult(
                            latLng: _selectedLocation,
                            addressTitle: finalAddress,
                          ),
                        );
                      },
                      child: _isResolvingAddress
                          ? const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                ),
                                SizedBox(width: 10),
                                Text(
                                  'Đang xác định địa chỉ...',
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
                                ),
                              ],
                            )
                          : const Text(
                              'Xác nhận vị trí này',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
