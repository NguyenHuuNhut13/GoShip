import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../../../../core/constants/app_colors.dart';

class AvatarCropScreen extends StatefulWidget {
  final String imagePath;
  const AvatarCropScreen({super.key, required this.imagePath});

  @override
  State<AvatarCropScreen> createState() => _AvatarCropScreenState();
}

class _AvatarCropScreenState extends State<AvatarCropScreen> {
  final GlobalKey _cropKey = GlobalKey();
  final TransformationController _transformationController = TransformationController();
  int _rotationQuarter = 0;
  double _zoomLevel = 1.0;
  bool _isProcessing = false;

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  void _rotateClockwise() {
    setState(() {
      _rotationQuarter = (_rotationQuarter + 1) % 4;
    });
  }

  void _resetTransform() {
    setState(() {
      _rotationQuarter = 0;
      _zoomLevel = 1.0;
      _transformationController.value = Matrix4.identity();
    });
  }

  Future<void> _handleCropAndSave() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      final boundary = _cropKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        throw Exception('Không tìm thấy khung cắt ảnh');
      }

      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        throw Exception('Lỗi chuyển đổi dữ liệu ảnh');
      }

      final bytes = byteData.buffer.asUint8List();
      final tempFile = File('${Directory.systemTemp.path}/avatar_cropped_${DateTime.now().millisecondsSinceEpoch}.png');
      await tempFile.writeAsBytes(bytes);

      if (!mounted) return;
      Navigator.pop(context, tempFile.path);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi cắt ảnh: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final cropSize = screenSize.width * 0.78;

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Cắt & Chỉnh sửa ảnh',
          style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700),
        ),
        actions: [
          TextButton(
            onPressed: _isProcessing ? null : _handleCropAndSave,
            child: _isProcessing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(color: AppColors.accent, strokeWidth: 2),
                  )
                : const Text(
                    'Xong',
                    style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.w700, fontSize: 16),
                  ),
          ),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 16),
          const Text(
            'Kéo hoặc dùng 2 ngón tay thu phóng để căn chỉnh ảnh',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const Spacer(),

          // Center Crop Area with Circular Mask
          Center(
            child: SizedBox(
              width: cropSize,
              height: cropSize,
              child: RepaintBoundary(
                key: _cropKey,
                child: ClipOval(
                  child: Container(
                    color: Colors.black,
                    child: RotatedBox(
                      quarterTurns: _rotationQuarter,
                      child: InteractiveViewer(
                        transformationController: _transformationController,
                        minScale: 0.8,
                        maxScale: 4.0,
                        boundaryMargin: const EdgeInsets.all(200),
                        onInteractionUpdate: (details) {
                          setState(() {
                            _zoomLevel = _transformationController.value.getMaxScaleOnAxis();
                          });
                        },
                        child: Center(
                          child: Image.file(
                            File(widget.imagePath),
                            fit: BoxFit.cover,
                            width: cropSize * 1.5,
                            height: cropSize * 1.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          const Spacer(),

          // Controls panel
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
            decoration: const BoxDecoration(
              color: Color(0xFF1E1E1E),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Zoom Slider
                Row(
                  children: [
                    const Icon(Icons.zoom_out_rounded, color: Colors.white60, size: 20),
                    Expanded(
                      child: Slider(
                        value: _zoomLevel.clamp(0.8, 3.5),
                        min: 0.8,
                        max: 3.5,
                        activeColor: AppColors.accent,
                        inactiveColor: Colors.white24,
                        onChanged: (val) {
                          setState(() {
                            _zoomLevel = val;
                            final current = _transformationController.value;
                            final scale = val / current.getMaxScaleOnAxis();
                            _transformationController.value = current..scaleByDouble(scale, scale, 1.0, 1.0);
                          });
                        },
                      ),
                    ),
                    const Icon(Icons.zoom_in_rounded, color: Colors.white60, size: 20),
                  ],
                ),
                const SizedBox(height: 10),

                // Rotate and Reset Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton.icon(
                      style: TextButton.styleFrom(foregroundColor: Colors.white),
                      onPressed: _rotateClockwise,
                      icon: const Icon(Icons.rotate_90_degrees_cw_rounded, size: 20),
                      label: const Text('Xoay 90°'),
                    ),
                    TextButton.icon(
                      style: TextButton.styleFrom(foregroundColor: Colors.white70),
                      onPressed: _resetTransform,
                      icon: const Icon(Icons.restart_alt_rounded, size: 20),
                      label: const Text('Đặt lại'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
