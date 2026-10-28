import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/network/geocoding_service.dart';
import '../../../../../core/services/location_service.dart';
import '../../../../../core/services/saved_address_service.dart';
import 'fullscreen_map_picker.dart';

class LocationPickerResult {
  final String address;
  final LatLng? latLng;

  LocationPickerResult({
    required this.address,
    this.latLng,
  });
}

class LocationPickerSheet extends StatefulWidget {
  final String title;
  final String initialAddress;
  final LatLng? initialLatLng;

  const LocationPickerSheet({
    super.key,
    required this.title,
    this.initialAddress = '',
    this.initialLatLng,
  });

  static Future<LocationPickerResult?> show({
    required BuildContext context,
    required String title,
    String initialAddress = '',
    LatLng? initialLatLng,
  }) {
    return showModalBottomSheet<LocationPickerResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.90,
        child: LocationPickerSheet(
          title: title,
          initialAddress: initialAddress,
          initialLatLng: initialLatLng,
        ),
      ),
    );
  }

  @override
  State<LocationPickerSheet> createState() => _LocationPickerSheetState();
}

class _LocationPickerSheetState extends State<LocationPickerSheet> {
  late final TextEditingController _searchController;
  List<AddressSearchResult> _suggestions = [];
  List<SavedAddressModel> _savedAddresses = [];
  bool _isSearching = false;
  bool _isLocatingGps = false;

  final List<Map<String, dynamic>> _recentAddresses = [
    {
      'title': 'Landmark 81, Bình Thạnh',
      'subtitle': '720A Điện Biên Phủ, Phường 22, Bình Thạnh, TP. HCM',
      'latLng': const LatLng(10.7946, 106.7218),
    },
    {
      'title': '25 Điện Biên Phủ, Quận 3',
      'subtitle': 'Phường Võ Thị Sáu, Quận 3, TP. HCM',
      'latLng': const LatLng(10.7925, 106.7020),
    },
    {
      'title': '123 Lê Duẩn, Quận 1',
      'subtitle': 'Phường Bến Nghé, Quận 1, TP. HCM',
      'latLng': const LatLng(10.7780, 106.6990),
    },
  ];

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.initialAddress);
    _loadSavedAddresses();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedAddresses() async {
    final list = await SavedAddressService.getSavedAddresses();
    if (mounted) {
      setState(() => _savedAddresses = list);
    }
  }

  void _onSearchChanged(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _suggestions = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);
    final results = await GeocodingService.search(query);
    if (!mounted) return;
    setState(() {
      _suggestions = results;
      _isSearching = false;
    });
  }

  Future<void> _openMapPicker() async {
    final result = await Navigator.push<FullscreenMapPickerResult>(
      context,
      MaterialPageRoute(
        builder: (_) => FullscreenMapPickerScreen(
          targetTitle: widget.title,
          initialCenter: widget.initialLatLng ?? const LatLng(10.7946, 106.7150),
          initialAddress: _searchController.text,
        ),
      ),
    );

    if (result != null && mounted) {
      Navigator.pop(
        context,
        LocationPickerResult(
          address: result.addressTitle,
          latLng: result.latLng,
        ),
      );
    }
  }

  Future<void> _pickCurrentGps() async {
    setState(() => _isLocatingGps = true);
    final gps = await LocationService.getCurrentLocation();
    if (!mounted) return;
    setState(() => _isLocatingGps = false);

    if (gps != null) {
      final address = await LocationService.getAddressFromCoordinates(gps);
      if (!mounted) return;
      Navigator.pop(
        context,
        LocationPickerResult(
          address: address,
          latLng: gps,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không thể lấy vị trí GPS. Vui lòng bật định vị.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _confirmSelection(String address, [LatLng? latLng]) {
    Navigator.pop(
      context,
      LocationPickerResult(
        address: address,
        latLng: latLng,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Handle bar
        const SizedBox(height: 12),
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: const Color(0xFFE2E8F0),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 12),

        // Header Title
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Chọn ${widget.title}',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 17,
                  color: AppColors.textPrimary,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),

        // Search Bar Input
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                const Icon(Icons.search_rounded, color: AppColors.primary, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    autofocus: false,
                    onChanged: _onSearchChanged,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Nhập tên đường, số nhà, địa danh...',
                      hintStyle: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.normal,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
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
                if (_isSearching)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
          ),
        ),

        // Quick Actions: Map Picker & GPS Buttons
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: _openMapPicker,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                    decoration: BoxDecoration(
                      color: AppColors.vanBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.map_rounded, color: AppColors.primary, size: 16),
                        SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'Chọn trên bản đồ',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: InkWell(
                  onTap: _isLocatingGps ? null : _pickCurrentGps,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _isLocatingGps
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.my_location_rounded, color: AppColors.primary, size: 16),
                        const SizedBox(width: 6),
                        const Flexible(
                          child: Text(
                            'Vị trí GPS của tôi',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                            overflow: TextOverflow.ellipsis,
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

        const Divider(height: 16),

        // Body: Suggestions OR Saved Addresses + Recent History
        Expanded(
          child: _suggestions.isNotEmpty
              ? ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  itemCount: _suggestions.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, indent: 48),
                  itemBuilder: (ctx, idx) {
                    final sug = _suggestions[idx];
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Color(0xFFEFF6FF),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.location_on_outlined, color: AppColors.primary, size: 18),
                      ),
                      title: Text(sug.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                      subtitle: Text(
                        sug.fullAddress,
                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () => _confirmSelection(sug.fullAddress, sug.latLng),
                    );
                  },
                )
              : ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  children: [
                    // Saved Addresses Section
                    if (_savedAddresses.isNotEmpty) ...[
                      const Text(
                        'Địa chỉ đã lưu',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ..._savedAddresses.map((saved) {
                        IconData iconData = Icons.bookmark_border_rounded;
                        Color iconColor = AppColors.primary;
                        if (saved.iconType == 'home') {
                          iconData = Icons.home_rounded;
                          iconColor = const Color(0xFF2563EB);
                        } else if (saved.iconType == 'work') {
                          iconData = Icons.business_rounded;
                          iconColor = const Color(0xFF0284C7);
                        } else if (saved.iconType == 'warehouse') {
                          iconData = Icons.warehouse_rounded;
                          iconColor = const Color(0xFFD97706);
                        }

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: ListTile(
                            dense: true,
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: iconColor.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(iconData, color: iconColor, size: 18),
                            ),
                            title: Text(
                              saved.label,
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                            ),
                            subtitle: Text(
                              saved.address,
                              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: AppColors.textMuted),
                            onTap: () => _confirmSelection(saved.address, saved.latLng),
                          ),
                        );
                      }),
                      const SizedBox(height: 16),
                    ],

                    // Recent History Section
                    const Text(
                      'Địa chỉ gần đây',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ..._recentAddresses.map((rec) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: ListTile(
                          dense: true,
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.textSecondary.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.history_rounded, color: AppColors.textSecondary, size: 18),
                          ),
                          title: Text(
                            rec['title'] as String,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                          ),
                          subtitle: Text(
                            rec['subtitle'] as String,
                            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: AppColors.textMuted),
                          onTap: () => _confirmSelection(rec['subtitle'] as String, rec['latLng'] as LatLng?),
                        ),
                      );
                    }),
                  ],
                ),
        ),
      ],
    );
  }
}
