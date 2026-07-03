class AppConstants {
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://192.168.0.7:8000',
  );

  static const websocketUrl = String.fromEnvironment(
    'WS_BASE_URL',
    defaultValue: 'ws://192.168.0.7:8000/ws/attendance',
  );
  
  static String liveStreamUrl({int cameraId = 0}) => '$apiBaseUrl/stream/frame?camera_id=$cameraId';
}
