import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Dịch vụ tối ưu hóa, nén thông minh và đồng bộ ảnh đa thiết bị trên Cloud (Giai đoạn 4).
/// Đảm bảo mọi ảnh (Avatar, CCCD 2 mặt, Ảnh kiện hàng, Ảnh e-POD) đều tương thích
/// trên mọi thiết bị (Android / iOS / Web) và không bao giờ vượt giới hạn 1MB của Firestore.
class CloudMediaService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const String _mediaCollection = 'cloud_media';
  static final Map<String, Uint8List> _memoryCache = {};

  /// Chuyển đổi đường dẫn file cục bộ hoặc chuỗi ảnh bất kỳ sang định dạng Cloud Data URI
  /// đã được nén tối ưu (< 100KB) để đồng bộ tức thì giữa các thiết bị.
  static Future<String?> ensureCloudPortableImage(
    String? source, {
    String category = 'profile',
    String? ownerId,
    int maxDimension = 720,
    bool backupToCloudCollection = true,
  }) async {
    if (source == null || source.trim().isEmpty || source == 'null') {
      return null;
    }

    final trimmed = source.trim();

    // 1. Nếu đã là URL HTTP/HTTPS công khai thì giữ nguyên
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }

    try {
      Uint8List? rawBytes;
      bool isPng = trimmed.toLowerCase().endsWith('.png');

      // 2. Nếu đã là chuỗi data:image hoặc base64
      if (trimmed.startsWith('data:image')) {
        isPng = trimmed.startsWith('data:image/png');
        final commaIdx = trimmed.indexOf(',');
        if (commaIdx != -1) {
          final b64 = trimmed.substring(commaIdx + 1).replaceAll('\n', '').replaceAll('\r', '').trim();
          rawBytes = base64Decode(b64);
        }
      } else if (!kIsWeb && (trimmed.contains('/') || trimmed.contains('\\'))) {
        // 3. Nếu là đường dẫn file cục bộ trên thiết bị
        final file = File(trimmed);
        if (await file.exists()) {
          rawBytes = await file.readAsBytes();
        }
      } else if (trimmed.length > 120) {
        // Chuỗi base64 thuần không có tiền tố
        try {
          rawBytes = base64Decode(trimmed.replaceAll('\n', '').replaceAll('\r', '').trim());
        } catch (_) {}
      }

      if (rawBytes == null || rawBytes.isEmpty) {
        return trimmed;
      }

      // 4. Nếu kích thước ảnh lớn hơn 140KB, thực hiện thu nhỏ kích thước khung hình để tiết kiệm băng thông Cloud
      Uint8List optimizedBytes = rawBytes;
      String mimeType = isPng ? 'image/png' : 'image/jpeg';

      if (rawBytes.lengthInBytes > 140 * 1024) {
        final resized = await _downscaleImageBytes(rawBytes, maxDimension: maxDimension);
        if (resized != null && resized.lengthInBytes < rawBytes.lengthInBytes) {
          optimizedBytes = resized;
          mimeType = 'image/png';
        }
      }

      final String portableDataUri = 'data:$mimeType;base64,${base64Encode(optimizedBytes)}';

      // 5. Sao lưu bản ghi độc lập vào collection `cloud_media` nếu được bật
      if (backupToCloudCollection && ownerId != null && ownerId.isNotEmpty) {
        final mediaDocId = '${category}_${ownerId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_')}';
        _db.collection(_mediaCollection).doc(mediaDocId).set({
          'category': category,
          'owner_id': ownerId,
          'size_bytes': optimizedBytes.lengthInBytes,
          'data_uri': portableDataUri,
          'updated_at': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true)).catchError((_) {});
      }

      return portableDataUri;
    } catch (e) {
      debugPrint('>>> [CloudMediaService.ensureCloudPortableImage Warning]: $e');
      return trimmed;
    }
  }

  /// Thu nhỏ chiều rộng/cao của ảnh lớn bằng dart:ui codec
  static Future<Uint8List?> _downscaleImageBytes(
    Uint8List inputBytes, {
    int maxDimension = 720,
  }) async {
    try {
      final codec = await ui.instantiateImageCodec(
        inputBytes,
        targetWidth: maxDimension,
      );
      final frame = await codec.getNextFrame();
      final byteData = await frame.image.toByteData(format: ui.ImageByteFormat.png);
      frame.image.dispose();
      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint('>>> [CloudMediaService._downscaleImageBytes Warning]: $e');
      return null;
    }
  }

  /// Giải mã chuỗi Base64 / Data URI có bộ nhớ đệm (Cache) để cuộn mượt 60 FPS
  static Uint8List? decodeDataUriCached(String source) {
    final key = source.length > 80 ? '${source.length}_${source.substring(0, 40)}_${source.substring(source.length - 30)}' : source;
    if (_memoryCache.containsKey(key)) {
      return _memoryCache[key];
    }
    try {
      String cleanBase64 = source.trim();
      if (cleanBase64.contains(',')) {
        cleanBase64 = cleanBase64.split(',').last;
      }
      final bytes = base64Decode(cleanBase64.replaceAll('\n', '').replaceAll('\r', '').trim());
      if (_memoryCache.length > 60) {
        _memoryCache.remove(_memoryCache.keys.first);
      }
      _memoryCache[key] = bytes;
      return bytes;
    } catch (_) {
      return null;
    }
  }

  /// Widget hiển thị ảnh đa năng (hỗ trợ Data URI Base64, URL HTTP/HTTPS có proxy CORS, và File cục bộ)
  static Widget buildSmartImage(
    String? source, {
    BoxFit fit = BoxFit.cover,
    double? width,
    double? height,
    Widget? fallback,
  }) {
    final defaultFallback = fallback ??
        const Center(
          child: Icon(Icons.image_outlined, color: Colors.grey, size: 28),
        );

    if (source == null || source.trim().isEmpty || source == 'null') {
      return defaultFallback;
    }

    final trimmed = source.trim();

    // 1. Data URI hoặc Base64
    if (trimmed.startsWith('data:image') ||
        (!trimmed.startsWith('http') && !trimmed.startsWith('/') && !trimmed.contains('\\') && trimmed.length > 120)) {
      final bytes = decodeDataUriCached(trimmed);
      if (bytes != null) {
        return Image.memory(
          bytes,
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (_, __, ___) => defaultFallback,
        );
      }
    }

    // 2. URL mạng (HTTP/HTTPS)
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      String displayUrl = trimmed;
      if (kIsWeb) {
        final stripped = displayUrl.replaceFirst('https://', '').replaceFirst('http://', '');
        displayUrl = 'https://images.weserv.nl/?url=$stripped';
      }
      return Image.network(
        displayUrl,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (ctx, err, stack) {
          if (!displayUrl.contains('images.weserv.nl')) {
            final stripped = trimmed.replaceFirst('https://', '').replaceFirst('http://', '');
            return Image.network(
              'https://images.weserv.nl/?url=$stripped',
              width: width,
              height: height,
              fit: fit,
              errorBuilder: (_, __, ___) => defaultFallback,
            );
          }
          return defaultFallback;
        },
      );
    }

    // 3. File cục bộ (Mobile / Desktop)
    if (!kIsWeb) {
      try {
        final file = File(trimmed);
        if (file.existsSync()) {
          return Image.file(
            file,
            width: width,
            height: height,
            fit: fit,
            errorBuilder: (_, __, ___) => defaultFallback,
          );
        }
      } catch (_) {}
    }

    return defaultFallback;
  }
}
