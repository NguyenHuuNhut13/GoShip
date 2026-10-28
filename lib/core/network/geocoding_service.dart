import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class AddressSearchResult {
  final String title;
  final String fullAddress;
  final LatLng latLng;

  AddressSearchResult({
    required this.title,
    required this.fullAddress,
    required this.latLng,
  });
}

class GeocodingService {
  static final http.Client _client = http.Client();

  // Local fast database for instant auto-complete in Vietnam
  static final List<AddressSearchResult> _presetLocations = [
    AddressSearchResult(
      title: 'Landmark 81, Vinhomes Central Park',
      fullAddress: '720A Điện Biên Phủ, Phường 22, Bình Thạnh, TP. Hồ Chí Minh',
      latLng: const LatLng(10.7946, 106.7218),
    ),
    AddressSearchResult(
      title: '252 Điện Biên Phủ',
      fullAddress: '252 Điện Biên Phủ, Phường Võ Thị Sáu, Quận 3, TP. Hồ Chí Minh',
      latLng: const LatLng(10.7925, 106.7020),
    ),
    AddressSearchResult(
      title: '250 Điện Biên Phủ',
      fullAddress: '250 Điện Biên Phủ, Phường 17, Bình Thạnh, TP. Hồ Chí Minh',
      latLng: const LatLng(10.7950, 106.7050),
    ),
    AddressSearchResult(
      title: 'Tòa nhà Bitexco Financial Tower',
      fullAddress: '02 Hải Triều, Bến Nghé, Quận 1, TP. Hồ Chí Minh',
      latLng: const LatLng(10.7716, 106.7044),
    ),
    AddressSearchResult(
      title: 'Chợ Bến Thành',
      fullAddress: 'Đường Lê Lợi, Phường Bến Thành, Quận 1, TP. Hồ Chí Minh',
      latLng: const LatLng(10.7725, 106.6980),
    ),
    AddressSearchResult(
      title: 'Sân bay Quốc tế Tân Sơn Nhất',
      fullAddress: 'Đường Trường Sơn, Phường 2, Tân Bình, TP. Hồ Chí Minh',
      latLng: const LatLng(10.8185, 106.6588),
    ),
    AddressSearchResult(
      title: '123 Lê Lợi',
      fullAddress: '123 Lê Lợi, Phường Bến Thành, Quận 1, TP. Hồ Chí Minh',
      latLng: const LatLng(10.7724, 106.6996),
    ),
    AddressSearchResult(
      title: '123 Đồng Khởi',
      fullAddress: '123 Đồng Khởi, Phường Bến Nghé, Quận 1, TP. Hồ Chí Minh',
      latLng: const LatLng(10.7765, 106.7038),
    ),
    AddressSearchResult(
      title: 'Đồng Nai (Biên Hòa)',
      fullAddress: 'Thành phố Biên Hòa, Tỉnh Đồng Nai',
      latLng: const LatLng(10.9574, 106.8427),
    ),
    AddressSearchResult(
      title: 'Bình Dương (Thủ Dầu Một)',
      fullAddress: 'Thành phố Thủ Dầu Một, Tỉnh Bình Dương',
      latLng: const LatLng(10.9805, 106.6519),
    ),
    AddressSearchResult(
      title: 'Long An (Tân An)',
      fullAddress: 'Thành phố Tân An, Tỉnh Long An',
      latLng: const LatLng(10.5364, 106.4137),
    ),
    AddressSearchResult(
      title: 'Bà Rịa - Vũng Tàu',
      fullAddress: 'Thành phố Vũng Tàu, Tỉnh Bà Rịa - Vũng Tàu',
      latLng: const LatLng(10.3460, 107.0843),
    ),
    AddressSearchResult(
      title: '123 Nguyễn Thị Minh Khai',
      fullAddress: '123 Nguyễn Thị Minh Khai, Phường Bến Thành, Quận 1, TP. Hồ Chí Minh',
      latLng: const LatLng(10.7735, 106.6912),
    ),
    AddressSearchResult(
      title: '123 Cách Mạng Tháng 8',
      fullAddress: '123 Cách Mạng Tháng 8, Phường 5, Quận 3, TP. Hồ Chí Minh',
      latLng: const LatLng(10.7785, 106.6830),
    ),
  ];

  static Future<List<AddressSearchResult>> search(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return [];

    final qLower = cleanQuery.toLowerCase();
    
    // 1. Local instant matches
    final localMatches = _presetLocations.where((loc) {
      return loc.title.toLowerCase().contains(qLower) ||
          loc.fullAddress.toLowerCase().contains(qLower);
    }).toList();

    // 2. Query Photon Komoot OpenStreetMap Geocoding API (Open CORS & Worldwide)
    try {
      final photonUri = Uri.parse(
        'https://photon.komoot.io/api/?q=${Uri.encodeComponent(cleanQuery)}&limit=6',
      );

      final response = await _client.get(
        photonUri,
        headers: {'User-Agent': 'GoShip-Delivery-App/1.0'},
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
        final List features = data['features'] as List? ?? [];
        final List<AddressSearchResult> onlineResults = [];

        for (final feat in features) {
          final props = feat['properties'] as Map<String, dynamic>? ?? {};
          final geom = feat['geometry'] as Map<String, dynamic>? ?? {};
          final coords = geom['coordinates'] as List? ?? [];

          if (coords.length >= 2) {
            final double lon = (coords[0] as num).toDouble();
            final double lat = (coords[1] as num).toDouble();

            final name = props['name']?.toString() ??
                props['street']?.toString() ??
                props['housenumber']?.toString() ??
                cleanQuery;

            final List<String> addressParts = [];
            if (props['housenumber'] != null) addressParts.add(props['housenumber'].toString());
            if (props['street'] != null) addressParts.add(props['street'].toString());
            if (props['district'] != null) addressParts.add(props['district'].toString());
            if (props['city'] != null) addressParts.add(props['city'].toString());
            if (props['state'] != null && props['state'] != props['city']) addressParts.add(props['state'].toString());
            if (props['country'] != null) addressParts.add(props['country'].toString());

            String fullAddr = addressParts.isNotEmpty ? addressParts.join(', ') : name;
            if (fullAddr == name && props['country'] != null) {
              fullAddr = '$name, ${props['country']}';
            }

            if (!localMatches.any((m) => m.title == name && m.fullAddress == fullAddr)) {
              onlineResults.add(
                AddressSearchResult(
                  title: name,
                  fullAddress: fullAddr,
                  latLng: LatLng(lat, lon),
                ),
              );
            }
          }
        }

        if (onlineResults.isNotEmpty) {
          return [...localMatches, ...onlineResults];
        }
      }
    } catch (e) {
      debugPrint('>>> [Photon Geocoding Error]: $e');
    }

    // 3. Fallback: Query Nominatim via CORS-friendly proxy on Web
    try {
      final rawUrl = 'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(cleanQuery)}&format=json&addressdetails=1&limit=5&countrycodes=vn';
      final nominatimUri = kIsWeb
          ? Uri.parse('https://corsproxy.io/?url=${Uri.encodeComponent(rawUrl)}')
          : Uri.parse(rawUrl);

      final response = await _client.get(
        nominatimUri,
        headers: {'User-Agent': 'GoShip-Delivery-App/1.0 (nhut@goship.vn)'},
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final List list = jsonDecode(utf8.decode(response.bodyBytes));
        final List<AddressSearchResult> onlineResults = [];

        for (final item in list) {
          final lat = double.tryParse(item['lat']?.toString() ?? '');
          final lon = double.tryParse(item['lon']?.toString() ?? '');
          final displayName = item['display_name']?.toString() ?? '';

          if (lat != null && lon != null && displayName.isNotEmpty) {
            final parts = displayName.split(',');
            final shortTitle = parts.isNotEmpty ? parts[0].trim() : cleanQuery;

            onlineResults.add(
              AddressSearchResult(
                title: shortTitle,
                fullAddress: displayName,
                latLng: LatLng(lat, lon),
              ),
            );
          }
        }

        return [...localMatches, ...onlineResults];
      }
    } catch (e) {
      debugPrint('>>> [Nominatim Geocoding Error]: $e');
    }

    return localMatches;
  }
}
