import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';

/// Pure Dart implementation of Agora AccessToken 2.0 Builder
/// Uses `archive` package for universal ZLib compression across both Web and Native platforms.
class AgoraTokenBuilder {
  static String buildTokenWithUid({
    required String appId,
    required String appCertificate,
    required String channelName,
    required int uid,
    int tokenExpireSeconds = 86400,
  }) {
    return buildTokenWithAccount(
      appId: appId,
      appCertificate: appCertificate,
      channelName: channelName,
      account: uid == 0 ? '' : uid.toString(),
      tokenExpireSeconds: tokenExpireSeconds,
    );
  }

  static String buildTokenWithAccount({
    required String appId,
    required String appCertificate,
    required String channelName,
    required String account,
    int tokenExpireSeconds = 86400,
  }) {
    final expireTimestamp = _getExpireTimestamp(tokenExpireSeconds);
    final token = _AgoraAccessToken(appId, appCertificate, expireTimestamp);

    final rtcService = _ServiceRTC(channelName, account);
    rtcService.addPrivilege(_Privileges.joinChannel, expireTimestamp);
    rtcService.addPrivilege(_Privileges.publishAudioStream, expireTimestamp);
    rtcService.addPrivilege(_Privileges.publishVideoStream, expireTimestamp);
    rtcService.addPrivilege(_Privileges.publishDataStream, expireTimestamp);

    token.addService(rtcService);
    return token.build();
  }

  static int _getExpireTimestamp(int seconds) {
    final now = (DateTime.now().millisecondsSinceEpoch / 1000).floor();
    return now + seconds;
  }
}

class _Privileges {
  static const int joinChannel = 1;
  static const int publishAudioStream = 2;
  static const int publishVideoStream = 3;
  static const int publishDataStream = 4;
}

abstract class _ServiceBase {
  int get serviceType;
  final Map<int, int> privileges = {};

  void addPrivilege(int privilege, int expire) {
    privileges[privilege] = expire;
  }

  Uint8List packType() {
    final buffer = _TokenByteBuffer();
    buffer.putUint16(serviceType);
    return buffer.pack();
  }

  Uint8List packPrivileges() {
    final buffer = _TokenByteBuffer();
    buffer.putTreeMapUint32(privileges);
    return buffer.pack();
  }

  Uint8List pack() {
    final typeData = packType();
    final privilegeData = packPrivileges();
    final specificData = packSpecific();

    final result = Uint8List(typeData.length + privilegeData.length + specificData.length);
    var offset = 0;

    result.setRange(offset, offset + typeData.length, typeData);
    offset += typeData.length;

    result.setRange(offset, offset + privilegeData.length, privilegeData);
    offset += privilegeData.length;

    result.setRange(offset, offset + specificData.length, specificData);
    return result;
  }

  Uint8List packSpecific();
}

class _ServiceRTC extends _ServiceBase {
  @override
  int get serviceType => 1; // RTC Service

  final String channelName;
  final String uid;

  _ServiceRTC(this.channelName, this.uid);

  @override
  Uint8List packSpecific() {
    final buffer = _TokenByteBuffer();
    buffer.putString(channelName);
    buffer.putString(uid);
    return buffer.pack();
  }
}

class _AgoraAccessToken {
  static const String version = "007";
  static const int appIdLength = 32;

  final String appId;
  final String appCertificate;
  final int expire;
  late final int issueTs;
  late final int salt;
  final Map<int, _ServiceBase> services = {};

  _AgoraAccessToken(this.appId, this.appCertificate, this.expire) {
    issueTs = (DateTime.now().millisecondsSinceEpoch / 1000).floor();
    final random = Random.secure();
    salt = random.nextInt(99999999) + 1;
  }

  void addService(_ServiceBase service) {
    services[service.serviceType] = service;
  }

  bool _buildCheck() {
    return _isUUID(appId) && _isUUID(appCertificate) && services.isNotEmpty;
  }

  bool _isUUID(String data) {
    if (data.length != appIdLength) return false;
    for (int i = 0; i < data.length; i++) {
      final char = data[i];
      if (!RegExp(r'[0-9a-fA-F]').hasMatch(char)) {
        return false;
      }
    }
    return true;
  }

  Uint8List _signing() {
    final buffer1 = _TokenByteBuffer();
    buffer1.putUint32(issueTs);
    var signing = _encodeHMac(utf8.encode(appCertificate), buffer1.pack());

    final buffer2 = _TokenByteBuffer();
    buffer2.putUint32(salt);
    return _encodeHMac(signing, buffer2.pack());
  }

  String build() {
    if (!_buildCheck()) return '';

    final signing = _signing();

    final signingInfo = _TokenByteBuffer();
    signingInfo.putString(appId);
    signingInfo.putUint32(issueTs);
    signingInfo.putUint32(expire);
    signingInfo.putUint32(salt);
    signingInfo.putUint16(services.length);

    var signingInfoData = signingInfo.pack();

    for (final service in services.values) {
      final serviceData = service.pack();
      final newData = Uint8List(signingInfoData.length + serviceData.length);
      newData.setRange(0, signingInfoData.length, signingInfoData);
      newData.setRange(signingInfoData.length, newData.length, serviceData);
      signingInfoData = newData;
    }

    final signature = _encodeHMac(signingInfoData, signing);

    final contentBuffer = _TokenByteBuffer();
    contentBuffer.putBytes(signature);
    final signatureData = contentBuffer.pack();

    final finalContent = Uint8List(signatureData.length + signingInfoData.length);
    finalContent.setRange(0, signatureData.length, signatureData);
    finalContent.setRange(signatureData.length, finalContent.length, signingInfoData);

    // Universal ZLib compression with archive package (runs on Web, Android, iOS, Windows, macOS)
    final compressed = Uint8List.fromList(ZLibEncoder().encode(finalContent));

    return "$version${base64Encode(compressed)}";
  }

  Uint8List _encodeHMac(List<int> message, List<int> key) {
    final hmac = Hmac(sha256, key);
    final digest = hmac.convert(message);
    return Uint8List.fromList(digest.bytes);
  }
}

class _TokenByteBuffer {
  final List<int> _buffer = [];

  void putUint16(int value) {
    _buffer.add(value & 0xFF);
    _buffer.add((value >> 8) & 0xFF);
  }

  void putUint32(int value) {
    _buffer.add(value & 0xFF);
    _buffer.add((value >> 8) & 0xFF);
    _buffer.add((value >> 16) & 0xFF);
    _buffer.add((value >> 24) & 0xFF);
  }

  void putString(String str) {
    final bytes = utf8.encode(str);
    putUint16(bytes.length);
    _buffer.addAll(bytes);
  }

  void putBytes(Uint8List bytes) {
    putUint16(bytes.length);
    _buffer.addAll(bytes);
  }

  void putTreeMapUint32(Map<int, int> map) {
    putUint16(map.length);
    final sortedKeys = map.keys.toList()..sort();
    for (final key in sortedKeys) {
      putUint16(key);
      putUint32(map[key]!);
    }
  }

  Uint8List pack() => Uint8List.fromList(_buffer);
}
