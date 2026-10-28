import 'dart:async';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/agora_config.dart';
import '../constants/app_colors.dart';
import '../services/agora_voice_service.dart';
import '../services/audio_alert_service.dart';
import '../services/firestore_order_service.dart';

class InAppCallScreen extends StatefulWidget {
  final String calleeName;
  final String calleePhone;
  final String calleeRole; // 'Tài xế GoShip', 'Khách hàng', etc.
  final String? calleeAvatar;
  final String? orderCode;
  final String? callId;
  final bool isIncomingAccepted;

  const InAppCallScreen({
    super.key,
    required this.calleeName,
    required this.calleePhone,
    this.calleeRole = 'Tài xế GoShip',
    this.calleeAvatar,
    this.orderCode,
    this.callId,
    this.isIncomingAccepted = false,
  });

  static Future<void> show(
    BuildContext context, {
    required String calleeName,
    required String calleePhone,
    String calleeRole = 'Tài xế GoShip',
    String? calleeAvatar,
    String? orderCode,
    String? callId,
    bool isIncomingAccepted = false,
  }) {
    return Navigator.of(context).push(
      PageRouteBuilder(
        opaque: true,
        pageBuilder: (_, __, ___) => InAppCallScreen(
          calleeName: calleeName,
          calleePhone: calleePhone,
          calleeRole: calleeRole,
          calleeAvatar: calleeAvatar,
          orderCode: orderCode,
          callId: callId,
          isIncomingAccepted: isIncomingAccepted,
        ),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  State<InAppCallScreen> createState() => _InAppCallScreenState();
}

class _InAppCallScreenState extends State<InAppCallScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  Timer? _connectTimer;
  Timer? _durationTimer;
  StreamSubscription<Map<String, dynamic>?>? _callStateSub;

  bool _isConnecting = true;
  bool _isConnected = false;
  bool _isCallEnded = false;
  String _statusText = 'Đang đổ chuông...';
  int _durationSeconds = 0;

  bool _isMuted = false;
  bool _isSpeakerOn = true;
  bool _isCameraOn = false;
  late bool _useAgora;

  VideoViewController? _localVideoController;
  VideoViewController? _remoteVideoController;
  int? _activeRemoteUid;

  @override
  void initState() {
    super.initState();
    _useAgora = AgoraConfig.isConfigured;
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();

    AgoraVoiceService.isLocalVideoEnabled.addListener(_onLocalVideoChanged);
    AgoraVoiceService.isRemoteVideoEnabled.addListener(_onRemoteVideoChanged);
    AgoraVoiceService.remoteUid.addListener(_onRemoteVideoChanged);

    if (widget.isIncomingAccepted) {
      // Trường hợp nhận cuộc gọi đến: Kết nối ngay lập tức
      _isConnecting = false;
      _isConnected = true;
      _statusText = 'Đã kết nối';
      _startTimer();
      AudioAlertService.playCallConnected();
      if (widget.orderCode != null && widget.orderCode!.isNotEmpty) {
        if (_useAgora) {
          AgoraVoiceService.joinCall(orderCode: widget.orderCode!).then((success) {
            if (!success && mounted) {
              debugPrint('>>> [InAppCallScreen]: Không thể kết nối Agora: ${AgoraVoiceService.connectionStatus.value}');
            }
          });
        }
      }
      Future.delayed(const Duration(milliseconds: 600), () {
        if (_useAgora) {
          AgoraVoiceService.setSpeakerphoneOn(true);
        }
      });
    } else {
      // Bắt đầu phát âm thanh tút tút cuộc gọi đi
      AudioAlertService.playDialTone();

      // Trường hợp khởi tạo cuộc gọi đi:
      if (widget.orderCode != null && widget.orderCode!.isNotEmpty) {
        final activeCallId = widget.callId ?? 'call_${DateTime.now().millisecondsSinceEpoch}';
        // Khởi tạo luồng âm thanh đàm thoại (Agora)
        if (_useAgora) {
          AgoraVoiceService.joinCall(orderCode: widget.orderCode!).then((success) {
            if (!success && mounted) {
              debugPrint('>>> [InAppCallScreen]: Không thể kết nối Agora: ${AgoraVoiceService.connectionStatus.value}');
            }
          });
        }

        // Gửi tín hiệu gọi đến Firestore để đổ chuông thiết bị đối phương
        // Nếu người nhận cuộc gọi KHÔNG phải là 'tài xế', tức là Tài xế đang gọi cho Khách hàng / Người gửi / Người nhận
        final isDriver = !widget.calleeRole.toLowerCase().contains('tài xế');
        FirestoreOrderService.startInAppCall(
          orderCode: widget.orderCode!,
          callerId: isDriver ? 'drv_me' : 'cust_me',
          callerName: isDriver ? 'Tài xế GoShip' : 'Khách hàng',
          callerRole: isDriver ? 'driver' : 'customer',
          calleePhone: widget.calleePhone,
          callId: activeCallId,
        );
      }
    }

    // Lắng nghe trạng thái 2 chiều từ Firestore cho cả 2 phía Caller và Callee
    if (widget.orderCode != null && widget.orderCode!.isNotEmpty) {
      _callStateSub = FirestoreOrderService.streamOrderCallState(widget.orderCode!).listen((callState) {
        if (!mounted || _isCallEnded) return;
        if (callState == null) return;

        final status = callState['status']?.toString();
        if (status == 'connected' && !_isConnected) {
          AudioAlertService.stopDialTone();
          AudioAlertService.playCallConnected();
          setState(() {
            _isConnecting = false;
            _isConnected = true;
            _statusText = 'Đã kết nối';
          });
          _connectTimer?.cancel();
          _startTimer();
          if (_useAgora) {
            AgoraVoiceService.setSpeakerphoneOn(true);
          }
          Future.delayed(const Duration(milliseconds: 600), () {
            if (_useAgora) {
              AgoraVoiceService.setSpeakerphoneOn(true);
            }
          });
        } else if (status == 'rejected') {
          AudioAlertService.stopDialTone();
          AudioAlertService.playCallEnded();
          setState(() {
            _isConnecting = false;
            _isConnected = false;
            _statusText = 'Đối phương bận hoặc từ chối';
          });
          _connectTimer?.cancel();
          Future.delayed(const Duration(milliseconds: 1500), () {
            if (mounted) _endCall();
          });
        } else if (status == 'ended' && (_isConnected || _isConnecting)) {
          _endCall(syncFirestore: false);
        }
      });

      if (!widget.isIncomingAccepted) {
        // Hẹn giờ chờ tối đa 45s nếu đối phương không trả lời
        _connectTimer = Timer(const Duration(seconds: 45), () {
          if (!mounted || _isConnected || _isCallEnded) return;
          AudioAlertService.stopDialTone();
          AudioAlertService.playCallEnded();
          setState(() {
            _isConnecting = false;
            _statusText = 'Người nhận không nhấc máy';
          });
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) _endCall();
          });
        });
      }
    } else {
      // Mô phỏng kết nối tự động sau 2.5s nếu đang test giao diện không có orderCode
      _connectTimer = Timer(const Duration(milliseconds: 2500), () {
        if (!mounted || _isConnected || _isCallEnded) return;
        AudioAlertService.stopDialTone();
        AudioAlertService.playCallConnected();
        setState(() {
          _isConnecting = false;
          _isConnected = true;
          _statusText = 'Đã kết nối';
        });
        _startTimer();
      });
    }
  }

  void _startTimer() {
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _durationSeconds++);
    });
  }

  String get _formattedDuration {
    final mins = (_durationSeconds ~/ 60).toString().padLeft(2, '0');
    final secs = (_durationSeconds % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  void _onLocalVideoChanged() {
    if (!mounted) return;
    final isLocalOn = AgoraVoiceService.isLocalVideoEnabled.value;
    setState(() {
      _isCameraOn = isLocalOn;
      if (isLocalOn && AgoraVoiceService.engine != null) {
        _localVideoController?.dispose();
        _localVideoController = VideoViewController(
          rtcEngine: AgoraVoiceService.engine!,
          canvas: const VideoCanvas(uid: 0),
        );
      } else {
        _localVideoController?.dispose();
        _localVideoController = null;
      }
    });
  }

  void _onRemoteVideoChanged() {
    if (!mounted) return;
    final isRemoteOn = AgoraVoiceService.isRemoteVideoEnabled.value;
    final rUid = AgoraVoiceService.remoteUid.value;
    setState(() {
      if (isRemoteOn && rUid != null && AgoraVoiceService.engine != null && AgoraVoiceService.activeChannelId != null) {
        if (_activeRemoteUid != rUid || _remoteVideoController == null) {
          _remoteVideoController?.dispose();
          _remoteVideoController = VideoViewController.remote(
            rtcEngine: AgoraVoiceService.engine!,
            canvas: VideoCanvas(uid: rUid),
            connection: RtcConnection(channelId: AgoraVoiceService.activeChannelId!),
          );
          _activeRemoteUid = rUid;
        }
      } else {
        _remoteVideoController?.dispose();
        _remoteVideoController = null;
        _activeRemoteUid = null;
      }
    });
  }

  void _endCall({bool syncFirestore = true}) {
    if (_isCallEnded) return;
    if (_useAgora) {
      AgoraVoiceService.leaveCall();
    }
    _localVideoController?.dispose();
    _localVideoController = null;
    _remoteVideoController?.dispose();
    _remoteVideoController = null;
    _activeRemoteUid = null;

    AudioAlertService.stopDialTone();
    AudioAlertService.playCallEnded();
    setState(() {
      _isCallEnded = true;
      _isConnected = false;
      _isConnecting = false;
      _statusText = 'Cuộc gọi đã kết thúc';
    });
    _durationTimer?.cancel();
    _connectTimer?.cancel();
    _callStateSub?.cancel();

    if (syncFirestore && widget.orderCode != null && widget.orderCode!.isNotEmpty) {
      FirestoreOrderService.endInAppCall(widget.orderCode!);
    }

    Future.delayed(const Duration(milliseconds: 650), () {
      if (mounted) {
        Navigator.of(context).pop();
      }
    });
  }

  @override
  void dispose() {
    AgoraVoiceService.isLocalVideoEnabled.removeListener(_onLocalVideoChanged);
    AgoraVoiceService.isRemoteVideoEnabled.removeListener(_onRemoteVideoChanged);
    AgoraVoiceService.remoteUid.removeListener(_onRemoteVideoChanged);

    _localVideoController?.dispose();
    _localVideoController = null;
    _remoteVideoController?.dispose();
    _remoteVideoController = null;
    _activeRemoteUid = null;

    if (_useAgora) {
      AgoraVoiceService.leaveCall();
    }
    AudioAlertService.stopDialTone();
    _pulseController.dispose();
    _connectTimer?.cancel();
    _durationTimer?.cancel();
    _callStateSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final calleeInitial = widget.calleeName.trim().isNotEmpty
        ? widget.calleeName.trim().substring(0, 1).toUpperCase()
        : 'G';

    final hasRemoteVideo = _remoteVideoController != null;
    final hasLocalVideo = _localVideoController != null;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Stack(
          children: [
            // 1. Background Layer (Gradient or Fullscreen Remote Video)
            if (hasRemoteVideo) ...[
              Positioned.fill(
                child: AgoraVideoView(controller: _remoteVideoController!),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.65),
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.75),
                      ],
                      stops: const [0.0, 0.45, 1.0],
                    ),
                  ),
                ),
              ),
            ] else
              Positioned.fill(
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0xFF0B132B),
                        Color(0xFF1E293B),
                        Color(0xFF0F172A),
                      ],
                    ),
                  ),
                ),
              ),

            // 2. Main Content
            SafeArea(
              child: Column(
                children: [
                  // Top Header Bar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white70, size: 30),
                          tooltip: 'Thu nhỏ',
                          onPressed: _endCall,
                        ),
                        Expanded(
                          child: Column(
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Icon(Icons.shield_outlined, color: Color(0xFF34D399), size: 14),
                                  SizedBox(width: 6),
                                  Text(
                                    'Cuộc gọi nội bộ bảo mật GoShip',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              if (widget.orderCode != null && widget.orderCode!.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    'Mã chuyến: ${widget.orderCode}',
                                    style: const TextStyle(
                                      color: Colors.white38,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (_isCameraOn && !kIsWeb)
                          IconButton(
                            icon: const Icon(Icons.flip_camera_ios_rounded, color: Colors.white, size: 24),
                            tooltip: 'Đổi camera',
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              AgoraVoiceService.switchCamera();
                            },
                          )
                        else
                          const SizedBox(width: 48),
                      ],
                    ),
                  ),

                  const Spacer(flex: 2),

                  // Center Callee / Video Section
                  if (hasLocalVideo && !hasRemoteVideo)
                    // Local Camera Preview while waiting for remote peer
                    Container(
                      width: 250,
                      height: 330,
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: const Color(0xFF60A5FA).withValues(alpha: 0.8),
                          width: 2.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.45),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          AgoraVideoView(controller: _localVideoController!),
                          Positioned(
                            bottom: 12,
                            left: 12,
                            right: 12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.65),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.videocam_rounded, color: Color(0xFF34D399), size: 14),
                                  SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      'Camera của bạn đang bật',
                                      style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  else if (!hasRemoteVideo)
                    // Standard Voice Call Avatar with Radar Rings
                    Column(
                      children: [
                        SizedBox(
                          width: 170,
                          height: 170,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              if (_isConnecting && !_isCallEnded)
                                AnimatedBuilder(
                                  animation: _pulseController,
                                  builder: (context, child) {
                                    return Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        Container(
                                          width: 130 + (_pulseController.value * 40),
                                          height: 130 + (_pulseController.value * 40),
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: AppColors.primary.withValues(alpha: (1 - _pulseController.value) * 0.5),
                                              width: 2,
                                            ),
                                          ),
                                        ),
                                        Container(
                                          width: 110 + (_pulseController.value * 25),
                                          height: 110 + (_pulseController.value * 25),
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: const Color(0xFF60A5FA).withValues(alpha: (1 - _pulseController.value) * 0.7),
                                              width: 2,
                                            ),
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),

                              // Avatar Circle
                              Container(
                                width: 104,
                                height: 104,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.35),
                                      blurRadius: 18,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                  border: Border.all(
                                    color: _isConnected ? const Color(0xFF34D399) : Colors.white24,
                                    width: 3,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    calleeInitial,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 42,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Callee Name
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Text(
                            widget.calleeName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.3,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),

                        const SizedBox(height: 8),

                        // Role pill & phone
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                          ),
                          child: Text(
                            '${widget.calleeRole} • ${widget.calleePhone}',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    )
                  else
                    // Remote video is active: Compact top pill
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.calleeName,
                            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '•  ${widget.calleeRole}',
                            style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 16),

                  // Call status or timer
                  if (_isCallEnded)
                    Text(
                      _statusText,
                      style: const TextStyle(
                        color: Color(0xFFF87171),
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    )
                  else if (_isConnected)
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(0xFF34D399),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _formattedDuration,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ValueListenableBuilder<String>(
                          valueListenable: AgoraVoiceService.connectionStatus,
                          builder: (context, p2pStatus, _) {
                            final isP2pConnected = p2pStatus.contains('Đã kết nối') || p2pStatus.contains('Đang đàm thoại');
                            final isP2pFailed = p2pStatus.contains('Lỗi');
                            return Container(
                              constraints: const BoxConstraints(maxWidth: 340),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: isP2pConnected
                                    ? const Color(0xFF059669).withValues(alpha: 0.2)
                                    : isP2pFailed
                                        ? const Color(0xFFDC2626).withValues(alpha: 0.2)
                                        : Colors.white.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isP2pConnected
                                      ? const Color(0xFF34D399).withValues(alpha: 0.5)
                                      : isP2pFailed
                                          ? const Color(0xFFF87171).withValues(alpha: 0.5)
                                          : Colors.white12,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isP2pConnected
                                        ? Icons.lock_outline_rounded
                                        : isP2pFailed
                                            ? Icons.error_outline_rounded
                                            : Icons.sync_rounded,
                                    size: 13,
                                    color: isP2pConnected
                                        ? const Color(0xFF34D399)
                                        : isP2pFailed
                                            ? const Color(0xFFF87171)
                                            : Colors.white70,
                                  ),
                                  const SizedBox(width: 5),
                                  Flexible(
                                    child: Text(
                                      p2pStatus,
                                      style: TextStyle(
                                        color: isP2pConnected
                                            ? const Color(0xFF34D399)
                                            : isP2pFailed
                                                ? const Color(0xFFF87171)
                                                : Colors.white70,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    )
                  else
                    Text(
                      _statusText,
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),

                  const Spacer(flex: 3),

                  // Bottom Call Controls Row (Mic, Camera, End Call, Speaker)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // 1. Mute Button
                        _buildControlButton(
                          icon: _isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                          label: _isMuted ? 'Đã tắt mic' : 'Tắt mic',
                          isActive: _isMuted,
                          activeColor: const Color(0xFFF59E0B),
                          onTap: () {
                            HapticFeedback.lightImpact();
                            setState(() {
                              _isMuted = !_isMuted;
                              if (_useAgora) {
                                AgoraVoiceService.setMicrophoneMute(_isMuted);
                              }
                            });
                          },
                        ),

                        // 2. Camera Toggle Button
                        _buildControlButton(
                          icon: _isCameraOn ? Icons.videocam_rounded : Icons.videocam_off_rounded,
                          label: _isCameraOn ? 'Tắt camera' : 'Mở camera',
                          isActive: _isCameraOn,
                          activeColor: const Color(0xFF3B82F6),
                          onTap: () async {
                            HapticFeedback.lightImpact();
                            if (_useAgora) {
                              final messenger = ScaffoldMessenger.of(context);
                              final success = await AgoraVoiceService.toggleLocalVideo();
                              if (!mounted) return;
                              if (!success && !_isCameraOn) {
                                messenger.showSnackBar(
                                  const SnackBar(
                                    content: Text('Không thể mở camera hoặc chưa cấp quyền camera.'),
                                    backgroundColor: AppColors.danger,
                                    behavior: SnackBarBehavior.floating,
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              }
                            }
                          },
                        ),

                        // 3. End Call Button
                        GestureDetector(
                          onTap: _endCall,
                          child: Container(
                            width: 68,
                            height: 68,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFEF4444).withValues(alpha: 0.4),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.call_end_rounded,
                                color: Colors.white,
                                size: 32,
                              ),
                            ),
                          ),
                        ),

                        // 4. Speaker Button
                        _buildControlButton(
                          icon: _isSpeakerOn ? Icons.volume_up_rounded : Icons.volume_down_rounded,
                          label: _isSpeakerOn ? 'Loa trong' : 'Loa ngoài',
                          isActive: _isSpeakerOn,
                          activeColor: const Color(0xFF3B82F6),
                          onTap: () {
                            HapticFeedback.lightImpact();
                            setState(() {
                              _isSpeakerOn = !_isSpeakerOn;
                              if (_useAgora) {
                                AgoraVoiceService.setSpeakerphoneOn(_isSpeakerOn);
                              }
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // 3. Picture-in-Picture Floating Local Video (when both remote & local video are active)
            if (hasRemoteVideo && hasLocalVideo)
              Positioned(
                top: 76,
                right: 16,
                child: GestureDetector(
                  onTap: () {
                    if (!kIsWeb) AgoraVoiceService.switchCamera();
                  },
                  child: Container(
                    width: 104,
                    height: 154,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white70, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.5),
                          blurRadius: 14,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: AgoraVideoView(controller: _localVideoController!),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required bool isActive,
    required Color activeColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isActive ? activeColor : Colors.white.withValues(alpha: 0.12),
                border: Border.all(
                  color: isActive ? activeColor : Colors.white.withValues(alpha: 0.18),
                  width: 1.5,
                ),
              ),
              child: Center(
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.white : Colors.white60,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
