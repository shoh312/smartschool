class AppConstants {
  /// The ports the two servers listen on. Named here because the LAN scan
  /// needs them as numbers, not buried inside a URL string it would have to
  /// parse back out.
  static const int schoolServerPort = 8000;
  static const int publicServerPort = 8200;

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

  /// Pushed frames instead of HTTP polling -- the server sends a new frame
  /// the instant one is available (checked every 50ms) rather than the
  /// client asking every 200ms and often getting the same bytes back.
  static String liveStreamWebsocketUrl({int cameraId = 0}) =>
      '${apiBaseUrl.replaceFirst('http://', 'ws://').replaceFirst('https://', 'wss://')}/ws/stream?camera_id=$cameraId';

  /// The Public Server: a fixed, non-LAN-discovered address (unlike
  /// [apiBaseUrl]) that only the parent role talks to, so student photos and
  /// video -- which only ever live on the school's local network -- are
  /// never exposed to it. Android emulators need `10.0.2.2` instead of
  /// `localhost` to reach the host machine.
  static const String _compiledPublicServerBaseUrl = String.fromEnvironment(
    'PUBLIC_SERVER_BASE_URL',
    defaultValue: 'http://localhost:8200',
  );

  /// Overridden from Settings and remembered on the device.
  ///
  /// The school server is found by discovery; this one can't be -- it lives
  /// on the internet, not the LAN -- so its address used to be fixed at
  /// build time. Every time the network or the host changed, the only fix
  /// was to rebuild and reinstall the app on every phone. Making it a
  /// setting means one APK keeps working when the address changes, which is
  /// also what lets an APK be handed out before the server is hosted.
  static String? _overriddenPublicServerBaseUrl;

  static String get publicServerBaseUrl =>
      _overriddenPublicServerBaseUrl ?? _compiledPublicServerBaseUrl;

  /// The address baked in at build time -- shown in Settings as the value
  /// an empty override falls back to.
  static String get defaultPublicServerBaseUrl => _compiledPublicServerBaseUrl;

  static void setPublicServerBaseUrl(String? url) {
    final trimmed = url?.trim();
    _overriddenPublicServerBaseUrl =
        (trimmed == null || trimmed.isEmpty) ? null : trimmed.replaceAll(RegExp(r'/+$'), '');
  }

  /// Subjects taught in the standard Tajikistan general-education (umumta'lim)
  /// curriculum, used to populate the subject picker when a director assigns
  /// a teacher to a class -- keeps subject names consistent across teachers
  /// instead of relying on free text.
  static const List<String> schoolSubjects = [
    'Забони тоҷикӣ',
    'Адабиёти тоҷик',
    'Забони русӣ',
    'Забони англисӣ',
    'Математика',
    'Алгебра',
    'Геометрия',
    'Физика',
    'Химия',
    'Биология',
    'Ҷуғрофия',
    'Таърих',
    'Ҳуқуқ',
    'Информатика',
    'Санъат',
    'Мусиқӣ',
    'Тарбияи ҷисмонӣ',
    'Технология',
  ];
}
