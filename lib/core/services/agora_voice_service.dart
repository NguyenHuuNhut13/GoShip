import 'dart:async';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import '../constants/agora_config.dart';
import 'agora_token_builder.dart';

class AgoraVoiceService {
  static RtcEngine? _engine;
  static bool _isCallActive = false;
  static bool get isCallActive => _isCallActive;
  static RtcEngine? get engine => _engine;

  static String? _activeChannelId;
  static String? get activeChannelId => _activeChannelId;

  static final ValueNotifier<String> connectionStatus = ValueNotifier<String>('Chưa kết nối');
  static final ValueNotifier<bool> isRemoteUserJoined = ValueNotifier<bool>(false);

  // Trạng thái Video
  static final ValueNotifier<bool> isLocalVideoEnabled = ValueNotifier<bool>(false);
  static final ValueNotifier<bool> isRemoteVideoEnabled = ValueNotifier<bool>(false);
  static final ValueNotifier<int?> remoteUid = ValueNotifier<int?>(null);
  static final ValueNotifier<bool> isFrontCamera = ValueNotifier<bool>(true);

  /// Đảm bảo quyền Microphone
  static Future<bool> ensureMicrophonePermission() async {
    if (kIsWeb) return true;
    try {
      var status = await Permission.microphone.status;
      if (!status.isGranted) {
        status = await Permission.microphone.request();
      }
      return status.isGranted;
    } catch (e) {
      debugPrint('>>> [Agora Permission Check]: $e');
      return true;
    }
  }

  /// Đảm bảo quyền Camera
  static Future<bool> ensureCameraPermission() async {
    if (kIsWeb) return true;
    try {
      var status = await Permission.camera.status;
      if (!status.isGranted) {
        status = await Permission.camera.request();
      }
      return status.isGranted;
    } catch (e) {
      debugPrint('>>> [Agora Camera Permission Check]: $e');
      return true;
    }
  }

  /// Khởi tạo và tham gia kênh cuộc gọi Agora (kênh = orderCode)
  static Future<bool> joinCall({
    required String orderCode,
    int uid = 0,
  }) async {
    if (!AgoraConfig.isConfigured) {
      debugPrint('>>> [AgoraVoiceService]: Agora App ID chưa được cấu hình!');
      connectionStatus.value = 'Chưa cấu hình Agora App ID';
      return false;
    }

    try {
      await leaveCall();
      await ensureMicrophonePermission();

      connectionStatus.value = 'Đang kết nối Agora...';

      _engine = createAgoraRtcEngine();
      await _engine!.initialize(
        RtcEngineContext(
          appId: AgoraConfig.appId.trim(),
          channelProfile: ChannelProfileType.channelProfileCommunication,
        ),
      );

      _engine!.registerEventHandler(
        RtcEngineEventHandler(
          onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
            debugPrint('>>> [Agora]: Đã tham gia kênh: ${connection.channelId}');
            connectionStatus.value = 'Đã kết nối Agora (${connection.channelId})';
            if (!kIsWeb) {
              try {
                _engine?.setEnableSpeakerphone(true);
              } catch (_) {}
            }
          },
          onUserJoined: (RtcConnection connection, int remoteUidVal, int elapsed) {
            debugPrint('>>> [Agora]: Người đối diện đã tham gia: $remoteUidVal');
            remoteUid.value = remoteUidVal;
            isRemoteUserJoined.value = true;
            connectionStatus.value = 'Đang đàm thoại Agora (2 chiều)';
            if (!kIsWeb) {
              try {
                _engine?.setEnableSpeakerphone(true);
              } catch (_) {}
            }
          },
          onUserOffline: (RtcConnection connection, int remoteUidVal, UserOfflineReasonType reason) {
            debugPrint('>>> [Agora]: Người đối diện đã gác máy: $remoteUidVal');
            if (remoteUid.value == remoteUidVal) {
              remoteUid.value = null;
              isRemoteVideoEnabled.value = false;
            }
            isRemoteUserJoined.value = false;
            connectionStatus.value = 'Người đối diện đã gác máy';
          },
          onUserEnableVideo: (RtcConnection connection, int remoteUidVal, bool enabled) {
            debugPrint('>>> [Agora]: onUserEnableVideo $remoteUidVal: $enabled');
            if (remoteUid.value == null || remoteUid.value == remoteUidVal) {
              remoteUid.value = remoteUidVal;
              isRemoteVideoEnabled.value = enabled;
            }
          },
          onUserMuteVideo: (RtcConnection connection, int remoteUidVal, bool muted) {
            debugPrint('>>> [Agora]: onUserMuteVideo $remoteUidVal: muted=$muted');
            if (remoteUid.value == null || remoteUid.value == remoteUidVal) {
              remoteUid.value = remoteUidVal;
              isRemoteVideoEnabled.value = !muted;
            }
          },
          onRemoteVideoStateChanged: (RtcConnection connection, int remoteUidVal,
              RemoteVideoState state, RemoteVideoStateReason reason, int elapsed) {
            debugPrint('>>> [Agora]: onRemoteVideoStateChanged $remoteUidVal: state=$state');
            if (remoteUid.value == null || remoteUid.value == remoteUidVal) {
              remoteUid.value = remoteUidVal;
              if (state == RemoteVideoState.remoteVideoStateDecoding ||
                  state == RemoteVideoState.remoteVideoStateStarting) {
                isRemoteVideoEnabled.value = true;
              } else if (state == RemoteVideoState.remoteVideoStateStopped ||
                  state == RemoteVideoState.remoteVideoStateFailed) {
                isRemoteVideoEnabled.value = false;
              }
            }
          },
          onError: (ErrorCodeType err, String msg) {
            debugPrint('>>> [Agora Error]: $err - $msg');
            connectionStatus.value = 'Lỗi Agora: $err';
          },
        ),
      );

      // Kích hoạt phần cứng âm thanh an toàn trên mọi nền tảng
      try {
        await _engine!.enableAudio();
      } catch (e) {
        debugPrint('>>> [Agora enableAudio Warning]: $e');
      }

      try {
        await _engine!.enableLocalAudio(true);
      } catch (_) {}

      if (!kIsWeb) {
        try {
          await _engine!.setAudioProfile(
            profile: AudioProfileType.audioProfileSpeechStandard,
            scenario: AudioScenarioType.audioScenarioDefault,
          );
        } catch (e) {
          debugPrint('>>> [Agora setAudioProfile Warning]: $e');
        }

        try {
          await _engine!.setDefaultAudioRouteToSpeakerphone(true);
          await _engine!.setEnableSpeakerphone(true);
        } catch (e) {
          debugPrint('>>> [Agora Speakerphone Warning]: $e');
        }
      }

      // Chuẩn hóa tên kênh (chỉ ký tự chữ và số)
      final cleanChannelId = orderCode.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
      _activeChannelId = cleanChannelId;

      // Tự động sinh RTC Token an toàn đa nền tảng (Web + Mobile) với ZLib nén chuẩn
      String activeToken = AgoraConfig.token.trim();
      if (activeToken.isEmpty && AgoraConfig.appCertificate.trim().isNotEmpty) {
        try {
          activeToken = AgoraTokenBuilder.buildTokenWithUid(
            appId: AgoraConfig.appId.trim(),
            appCertificate: AgoraConfig.appCertificate.trim(),
            channelName: cleanChannelId,
            uid: uid,
            tokenExpireSeconds: 86400,
          );
          debugPrint('>>> [Agora Voice]: Tự động sinh RTC Token thành công cho kênh: $cleanChannelId');
        } catch (e) {
          debugPrint('>>> [Agora Token Generator Warning]: $e');
        }
      }

      await _engine!.joinChannel(
        token: activeToken,
        channelId: cleanChannelId,
        uid: uid,
        options: const ChannelMediaOptions(
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
          channelProfile: ChannelProfileType.channelProfileCommunication,
          publishMicrophoneTrack: true,
          publishCameraTrack: false,
          autoSubscribeAudio: true,
          autoSubscribeVideo: true,
          enableAudioRecordingOrPlayout: true,
        ),
      );

      _isCallActive = true;
      debugPrint('>>> [AgoraVoiceService]: Đã gửi lệnh joinChannel ($cleanChannelId)');
      return true;
    } catch (e) {
      debugPrint('>>> [AgoraVoiceService joinCall Error]: $e');
      final errorMsg = e.toString().split('\n').first;
      connectionStatus.value = 'Lỗi kết nối: $errorMsg';
      return false;
    }
  }

  /// Mute/Unmute Mic
  static Future<void> setMicrophoneMute(bool isMuted) async {
    try {
      await _engine?.muteLocalAudioStream(isMuted);
    } catch (_) {}
  }

  /// Bật/Tắt Loa ngoài
  static Future<void> setSpeakerphoneOn(bool isSpeakerOn) async {
    if (kIsWeb) return;
    try {
      await _engine?.setEnableSpeakerphone(isSpeakerOn);
    } catch (_) {}
  }

  /// Bật/Tắt Camera cá nhân trong cuộc gọi
  static Future<bool> toggleLocalVideo() async {
    if (_engine == null) return false;

    if (!isLocalVideoEnabled.value) {
      // Bật camera
      final hasPermission = await ensureCameraPermission();
      if (!hasPermission) {
        debugPrint('>>> [Agora]: Không có quyền Camera');
        return false;
      }

      try {
        await _engine!.enableVideo();
        await _engine!.startPreview();
        await _engine!.enableLocalVideo(true);
        await _engine!.updateChannelMediaOptions(
          const ChannelMediaOptions(
            publishCameraTrack: true,
            publishMicrophoneTrack: true,
          ),
        );
        isLocalVideoEnabled.value = true;
        return true;
      } catch (e) {
        debugPrint('>>> [Agora toggleLocalVideo Enable Error]: $e');
        return false;
      }
    } else {
      // Tắt camera
      try {
        await _engine!.enableLocalVideo(false);
        await _engine!.stopPreview();
        await _engine!.updateChannelMediaOptions(
          const ChannelMediaOptions(
            publishCameraTrack: false,
            publishMicrophoneTrack: true,
          ),
        );
        isLocalVideoEnabled.value = false;
        return true;
      } catch (e) {
        debugPrint('>>> [Agora toggleLocalVideo Disable Error]: $e');
        return false;
      }
    }
  }

  /// Chuyển đổi Camera trước / sau
  static Future<void> switchCamera() async {
    if (kIsWeb || _engine == null) return;
    try {
      await _engine!.switchCamera();
      isFrontCamera.value = !isFrontCamera.value;
    } catch (e) {
      debugPrint('>>> [Agora switchCamera Error]: $e');
    }
  }

  /// Rời kênh & giải phóng tài nguyên Agora
  static Future<void> leaveCall() async {
    _isCallActive = false;
    isRemoteUserJoined.value = false;
    isLocalVideoEnabled.value = false;
    isRemoteVideoEnabled.value = false;
    remoteUid.value = null;
    _activeChannelId = null;
    connectionStatus.value = 'Chưa kết nối';
    try {
      await _engine?.stopPreview();
      await _engine?.disableVideo();
    } catch (_) {}
    try {
      await _engine?.leaveChannel();
      await _engine?.release();
    } catch (_) {}
    _engine = null;
  }
}
