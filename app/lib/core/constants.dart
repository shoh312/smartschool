class AppConstants {
  static const _fallbackApiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://192.168.43.3:8000',
  );

  /// Set at startup once the backend is auto-discovered on the local network
  /// (see DiscoveryService). Until then, or if discovery fails, the hardcoded
  /// fallback above is used so the app still works if this mechanism breaks.
  static String? _resolvedApiBaseUrl;

  static String get apiBaseUrl => _resolvedApiBaseUrl ?? _fallbackApiBaseUrl;

  static String get websocketUrl =>
      '${apiBaseUrl.replaceFirst('http://', 'ws://').replaceFirst('https://', 'wss://')}/ws/attendance';

  static void setResolvedBaseUrl(String url) {
    _resolvedApiBaseUrl = url;
  }

  static String liveStreamUrl({int cameraId = 0}) =>
      '$apiBaseUrl/stream/frame?camera_id=$cameraId';
}
