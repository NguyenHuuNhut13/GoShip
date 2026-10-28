class AgoraConfig {
  /// Điền Agora App ID lấy từ Agora Console (console.agora.io)
  /// Hỗ trợ truyền qua `--dart-define=AGORA_APP_ID=...` khi build Production
  static String appId = const String.fromEnvironment(
    'AGORA_APP_ID',
    defaultValue: '9ade929166c04e40a3bdbf4339073f2c',
  );

  /// App Certificate từ Agora Console (dùng để tự sinh Token bảo mật)
  /// Hỗ trợ truyền qua `--dart-define=AGORA_APP_CERTIFICATE=...`
  static String appCertificate = const String.fromEnvironment(
    'AGORA_APP_CERTIFICATE',
    defaultValue: '',
  );

  /// Token tĩnh (để trống nếu dùng chế độ tự sinh Token qua appCertificate hoặc Testing Mode)
  static String token = const String.fromEnvironment(
    'AGORA_TOKEN',
    defaultValue: '',
  );

  /// Kiểm tra Agora đã được cấu hình App ID hay chưa
  static bool get isConfigured => appId.trim().isNotEmpty;
}
