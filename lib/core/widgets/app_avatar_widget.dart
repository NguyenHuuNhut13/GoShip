import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class AppAvatarWidget extends StatefulWidget {
  final String? avatarUrl;
  final String name;
  final double size;
  final Color? backgroundColor;

  const AppAvatarWidget({
    super.key,
    required this.avatarUrl,
    required this.name,
    this.size = 48,
    this.backgroundColor,
  });

  @override
  State<AppAvatarWidget> createState() => _AppAvatarWidgetState();
}

class _AppAvatarWidgetState extends State<AppAvatarWidget> {
  bool _useProxyFallback = false;
  bool _failedCompletely = false;

  String _cleanUrl(String url) {
    var cleaned = url.trim();
    if (cleaned.startsWith('https://')) {
      cleaned = 'https://${cleaned.substring(8).replaceAll(RegExp(r'/+'), '/')}';
    } else if (cleaned.startsWith('http://')) {
      cleaned = 'http://${cleaned.substring(7).replaceAll(RegExp(r'/+'), '/')}';
    } else if (cleaned.startsWith('/storage/')) {
      cleaned = 'https://data.nks.vn${cleaned.replaceAll(RegExp(r'/+'), '/')}';
    } else if (cleaned.startsWith('storage/')) {
      cleaned = 'https://data.nks.vn/${cleaned.replaceAll(RegExp(r'/+'), '/')}';
    } else if (cleaned.startsWith('users/')) {
      cleaned = 'https://data.nks.vn/storage/${cleaned.replaceAll(RegExp(r'/+'), '/')}';
    } else if (cleaned.startsWith('/')) {
      cleaned = 'https://data.nks.vn/storage${cleaned.replaceAll(RegExp(r'/+'), '/')}';
    } else {
      cleaned = 'https://data.nks.vn/storage/${cleaned.replaceAll(RegExp(r'/+'), '/')}';
    }
    return cleaned;
  }

  String _getCorsSafeUrl(String originalUrl) {
    final cleaned = _cleanUrl(originalUrl);
    // On Web, proxy through images.weserv.nl to add CORS headers
    if (kIsWeb || _useProxyFallback) {
      final stripped = cleaned.replaceFirst('https://', '').replaceFirst('http://', '');
      return 'https://images.weserv.nl/?url=$stripped';
    }
    return cleaned;
  }

  @override
  Widget build(BuildContext context) {
    final avatar = widget.avatarUrl?.trim();

    if (_failedCompletely || avatar == null || avatar.isEmpty || avatar == 'null') {
      return _buildFallback();
    }

    // 1. Handle Base64 encoded image
    if (avatar.startsWith('data:image') || (!avatar.startsWith('http') && !avatar.startsWith('/') && avatar.length > 100)) {
      try {
        String cleanBase64 = avatar;
        if (avatar.contains(',')) {
          cleanBase64 = avatar.split(',').last;
        }
        final Uint8List bytes = base64Decode(cleanBase64.replaceAll('\n', '').replaceAll('\r', '').trim());
        return Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.backgroundColor ?? AppColors.primary.withValues(alpha: 0.12),
          ),
          child: ClipOval(
            child: Image.memory(
              bytes,
              width: widget.size,
              height: widget.size,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _buildFallback(),
            ),
          ),
        );
      } catch (_) {}
    }

    // 2. Handle Local File Path
    if (!kIsWeb) {
      try {
        final file = File(avatar);
        if (file.existsSync()) {
          return Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.backgroundColor ?? AppColors.primary.withValues(alpha: 0.12),
            ),
            child: ClipOval(
              child: Image.file(
                file,
                width: widget.size,
                height: widget.size,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _buildFallback(),
              ),
            ),
          );
        }
      } catch (_) {}
    }

    // 3. Handle Network URL (with CORS safety on Web)
    final targetUrl = _getCorsSafeUrl(avatar);

    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: widget.backgroundColor ?? AppColors.primary.withValues(alpha: 0.12),
      ),
      child: ClipOval(
        child: Image.network(
          targetUrl,
          width: widget.size,
          height: widget.size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            debugPrint('>>> [Avatar Load Error on $targetUrl]: $error');
            if (!_useProxyFallback && !kIsWeb) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) setState(() => _useProxyFallback = true);
              });
            } else {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) setState(() => _failedCompletely = true);
              });
            }
            return _buildFallback();
          },
        ),
      ),
    );
  }

  Widget _buildFallback() {
    final initial = widget.name.trim().isNotEmpty ? widget.name.trim()[0].toUpperCase() : 'N';
    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: widget.backgroundColor ?? AppColors.primary.withValues(alpha: 0.15),
      ),
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.w800,
            fontSize: widget.size * 0.42,
          ),
        ),
      ),
    );
  }
}
