import 'dart:math' as math;
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

class AudioAlertService {
  static final AudioPlayer _callPlayer = AudioPlayer();
  static final AudioPlayer _alertPlayer = AudioPlayer();
  static bool _isInitialized = false;

  // Cached fallback sound wave bytes in memory (100% offline, zero network lag)
  static Uint8List? _newOrderBytes;
  static Uint8List? _chatMsgBytes;
  static Uint8List? _ringtoneBytes;
  static Uint8List? _dialToneBytes;
  static Uint8List? _connectedBytes;
  static Uint8List? _endCallBytes;

  static Future<void> init() async {
    if (_isInitialized) return;
    try {
      await _callPlayer.setReleaseMode(ReleaseMode.stop);
      await _alertPlayer.setReleaseMode(ReleaseMode.stop);
      try {
        final audioContext = AudioContext(
          android: const AudioContextAndroid(
            isSpeakerphoneOn: true,
            stayAwake: false,
            contentType: AndroidContentType.music,
            usageType: AndroidUsageType.media,
            audioFocus: AndroidAudioFocus.none,
          ),
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.ambient,
            options: const {
              AVAudioSessionOptions.mixWithOthers,
            },
          ),
        );
        await _callPlayer.setAudioContext(audioContext);
        await _alertPlayer.setAudioContext(audioContext);
      } catch (_) {}

      _newOrderBytes = _generateOrderAlertWav();
      _chatMsgBytes = _generateTingTingWav();
      _ringtoneBytes = _generateRingtoneWav();
      _dialToneBytes = _generateDialToneWav();
      _connectedBytes = _generateConnectedWav();
      _endCallBytes = _generateEndCallWav();
      _isInitialized = true;
    } catch (_) {}
  }

  /// Phát âm thanh chuông 'Ting Ting' & rung điện thoại báo cuốc xe mới đến
  static Future<void> playNewOrderAlert() async {
    try {
      await HapticFeedback.heavyImpact();
      await _alertPlayer.stop();
      await _alertPlayer.setReleaseMode(ReleaseMode.stop);
      await _alertPlayer.setVolume(1.0);
      try {
        await _alertPlayer.play(AssetSource('sounds/new_order.wav'));
      } catch (_) {
        _newOrderBytes ??= _generateOrderAlertWav();
        await _alertPlayer.play(BytesSource(_newOrderBytes!));
      }
    } catch (_) {
      try {
        await SystemSound.play(SystemSoundType.alert);
      } catch (_) {}
    }
  }

  /// Phát âm thanh chuông báo tin nhắn mới & rung nhẹ
  static Future<void> playChatMessageAlert() async {
    try {
      await HapticFeedback.mediumImpact();
      await _alertPlayer.stop();
      await _alertPlayer.setReleaseMode(ReleaseMode.stop);
      await _alertPlayer.setVolume(0.9);
      try {
        await _alertPlayer.play(AssetSource('sounds/chat_message.wav'));
      } catch (_) {
        _chatMsgBytes ??= _generateTingTingWav();
        await _alertPlayer.play(BytesSource(_chatMsgBytes!));
      }
    } catch (_) {
      try {
        await SystemSound.play(SystemSoundType.click);
      } catch (_) {}
    }
  }

  /// Phát nhạc chuông đổ chuông cuộc gọi đến (đổ chuông lặp lại)
  static Future<void> playIncomingCallRingtone() async {
    try {
      await HapticFeedback.heavyImpact();
      await _callPlayer.stop();
      await _callPlayer.setReleaseMode(ReleaseMode.loop);
      await _callPlayer.setVolume(1.0);
      try {
        await _callPlayer.play(AssetSource('sounds/ringtone.wav'));
      } catch (_) {
        _ringtoneBytes ??= _generateRingtoneWav();
        await _callPlayer.play(BytesSource(_ringtoneBytes!));
      }
    } catch (_) {
      try {
        await SystemSound.play(SystemSoundType.alert);
      } catch (_) {}
    }
  }

  /// Dừng chuông cuộc gọi đến
  static Future<void> stopIncomingCallRingtone() async {
    try {
      await _callPlayer.stop();
      await _callPlayer.setReleaseMode(ReleaseMode.stop);
    } catch (_) {}
  }

  /// Phát âm thanh tút tút cuộc gọi đi (đang chờ bên kia nhấc máy)
  static Future<void> playDialTone() async {
    try {
      await _callPlayer.stop();
      await _callPlayer.setReleaseMode(ReleaseMode.loop);
      await _callPlayer.setVolume(0.85);
      try {
        await _callPlayer.play(AssetSource('sounds/dial_tone.wav'));
      } catch (_) {
        _dialToneBytes ??= _generateDialToneWav();
        await _callPlayer.play(BytesSource(_dialToneBytes!));
      }
    } catch (_) {}
  }

  /// Dừng âm thanh tút tút cuộc gọi đi
  static Future<void> stopDialTone() async {
    try {
      await _callPlayer.stop();
      await _callPlayer.setReleaseMode(ReleaseMode.stop);
    } catch (_) {}
  }

  /// Phát âm thanh báo khi cuộc gọi đã kết nối thành công
  static Future<void> playCallConnected() async {
    try {
      await HapticFeedback.lightImpact();
      await _alertPlayer.stop();
      await _alertPlayer.setReleaseMode(ReleaseMode.stop);
      await _alertPlayer.setVolume(0.9);
      try {
        await _alertPlayer.play(AssetSource('sounds/connected.wav'));
      } catch (_) {
        _connectedBytes ??= _generateConnectedWav();
        await _alertPlayer.play(BytesSource(_connectedBytes!));
      }
    } catch (_) {}
  }

  /// Phát âm thanh bíp bíp khi kết thúc cuộc gọi
  static Future<void> playCallEnded() async {
    try {
      await HapticFeedback.heavyImpact();
      await stopDialTone();
      await stopIncomingCallRingtone();
      await _alertPlayer.stop();
      await _alertPlayer.setReleaseMode(ReleaseMode.stop);
      await _alertPlayer.setVolume(0.85);
      try {
        await _alertPlayer.play(AssetSource('sounds/end_call.wav'));
      } catch (_) {
        _endCallBytes ??= _generateEndCallWav();
        await _alertPlayer.play(BytesSource(_endCallBytes!));
      }
    } catch (_) {}
  }

  static void dispose() {
    try {
      _callPlayer.dispose();
      _alertPlayer.dispose();
    } catch (_) {}
  }

  // ==================== TẠO ÂM THANH OFFLINE DỰ PHÒNG (PCM WAV 44.1kHz) ====================

  static Uint8List _generateOrderAlertWav() {
    const sampleRate = 44100;
    const durationMs = 600;
    final numSamples = (sampleRate * durationMs / 1000).round();
    final byteLength = 44 + numSamples * 2;
    final bytes = Uint8List(byteLength);
    final bdata = ByteData.view(bytes.buffer);

    _writeWavHeader(bdata, byteLength, numSamples, sampleRate);

    for (int i = 0; i < numSamples; i++) {
      final t = i / sampleRate;
      double freq = 523.25;
      double amp = 0.8;
      if (t > 0.18 && t <= 0.36) {
        freq = 659.25;
      } else if (t > 0.36) {
        freq = 783.99;
        amp *= math.exp(-5 * (t - 0.36));
      }
      final val = (amp * math.sin(2 * math.pi * freq * t)) * 32767;
      bdata.setInt16(44 + i * 2, val.clamp(-32768, 32767).toInt(), Endian.little);
    }
    return bytes;
  }

  static Uint8List _generateTingTingWav() {
    const sampleRate = 44100;
    const durationMs = 300;
    final numSamples = (sampleRate * durationMs / 1000).round();
    final byteLength = 44 + numSamples * 2;
    final bytes = Uint8List(byteLength);
    final bdata = ByteData.view(bytes.buffer);

    _writeWavHeader(bdata, byteLength, numSamples, sampleRate);

    for (int i = 0; i < numSamples; i++) {
      final t = i / sampleRate;
      final decay = math.exp(-10 * t);
      final val = (0.6 * math.sin(2 * math.pi * 880 * t) + 0.3 * math.sin(2 * math.pi * 1760 * t)) * decay * 32767;
      bdata.setInt16(44 + i * 2, val.clamp(-32768, 32767).toInt(), Endian.little);
    }
    return bytes;
  }

  static Uint8List _generateRingtoneWav() {
    const sampleRate = 44100;
    const durationMs = 2000;
    final numSamples = (sampleRate * durationMs / 1000).round();
    final byteLength = 44 + numSamples * 2;
    final bytes = Uint8List(byteLength);
    final bdata = ByteData.view(bytes.buffer);

    _writeWavHeader(bdata, byteLength, numSamples, sampleRate);

    for (int i = 0; i < numSamples; i++) {
      final t = i / sampleRate;
      final isRinging = (t < 0.45) || (t >= 0.65 && t < 1.10);
      final val = isRinging
          ? (0.45 * math.sin(2 * math.pi * 440 * t) + 0.45 * math.sin(2 * math.pi * 480 * t)) * 32767
          : 0.0;
      bdata.setInt16(44 + i * 2, val.clamp(-32768, 32767).toInt(), Endian.little);
    }
    return bytes;
  }

  static Uint8List _generateDialToneWav() {
    const sampleRate = 44100;
    const durationMs = 2000;
    final numSamples = (sampleRate * durationMs / 1000).round();
    final byteLength = 44 + numSamples * 2;
    final bytes = Uint8List(byteLength);
    final bdata = ByteData.view(bytes.buffer);

    _writeWavHeader(bdata, byteLength, numSamples, sampleRate);

    for (int i = 0; i < numSamples; i++) {
      final t = i / sampleRate;
      final isTone = t < 0.8;
      final val = isTone
          ? (0.35 * math.sin(2 * math.pi * 440 * t) + 0.35 * math.sin(2 * math.pi * 480 * t)) * 32767
          : 0.0;
      bdata.setInt16(44 + i * 2, val.clamp(-32768, 32767).toInt(), Endian.little);
    }
    return bytes;
  }

  static Uint8List _generateConnectedWav() {
    const sampleRate = 44100;
    const durationMs = 400;
    final numSamples = (sampleRate * durationMs / 1000).round();
    final byteLength = 44 + numSamples * 2;
    final bytes = Uint8List(byteLength);
    final bdata = ByteData.view(bytes.buffer);

    _writeWavHeader(bdata, byteLength, numSamples, sampleRate);

    for (int i = 0; i < numSamples; i++) {
      final t = i / sampleRate;
      final freq = t < 0.2 ? 587.33 : 880.00;
      final decay = math.exp(-4 * t);
      final val = (0.7 * math.sin(2 * math.pi * freq * t)) * decay * 32767;
      bdata.setInt16(44 + i * 2, val.clamp(-32768, 32767).toInt(), Endian.little);
    }
    return bytes;
  }

  static Uint8List _generateEndCallWav() {
    const sampleRate = 44100;
    const durationMs = 750;
    final numSamples = (sampleRate * durationMs / 1000).round();
    final byteLength = 44 + numSamples * 2;
    final bytes = Uint8List(byteLength);
    final bdata = ByteData.view(bytes.buffer);

    _writeWavHeader(bdata, byteLength, numSamples, sampleRate);

    for (int i = 0; i < numSamples; i++) {
      final t = i / sampleRate;
      final isBeep = (t < 0.15) || (t >= 0.25 && t < 0.40) || (t >= 0.50 && t < 0.65);
      final val = isBeep
          ? (0.4 * math.sin(2 * math.pi * 480 * t) + 0.4 * math.sin(2 * math.pi * 620 * t)) * 32767
          : 0.0;
      bdata.setInt16(44 + i * 2, val.clamp(-32768, 32767).toInt(), Endian.little);
    }
    return bytes;
  }

  static void _writeWavHeader(ByteData bdata, int byteLength, int numSamples, int sampleRate) {
    // RIFF
    bdata.setUint8(0, 0x52); bdata.setUint8(1, 0x49); bdata.setUint8(2, 0x46); bdata.setUint8(3, 0x46);
    bdata.setUint32(4, byteLength - 8, Endian.little);
    // WAVE
    bdata.setUint8(8, 0x57); bdata.setUint8(9, 0x41); bdata.setUint8(10, 0x56); bdata.setUint8(11, 0x45);
    // fmt
    bdata.setUint8(12, 0x66); bdata.setUint8(13, 0x6D); bdata.setUint8(14, 0x74); bdata.setUint8(15, 0x20);
    bdata.setUint32(16, 16, Endian.little); // chunk size
    bdata.setUint16(20, 1, Endian.little);  // PCM
    bdata.setUint16(22, 1, Endian.little);  // mono
    bdata.setUint32(24, sampleRate, Endian.little);
    bdata.setUint32(28, sampleRate * 2, Endian.little); // byte rate
    bdata.setUint16(32, 2, Endian.little);  // block align
    bdata.setUint16(34, 16, Endian.little); // bits per sample
    // data
    bdata.setUint8(36, 0x64); bdata.setUint8(37, 0x61); bdata.setUint8(38, 0x74); bdata.setUint8(39, 0x61);
    bdata.setUint32(40, numSamples * 2, Endian.little);
  }
}
