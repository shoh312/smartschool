import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../core/constants.dart';
import '../models/attendance.dart';
import '../services/token_storage.dart';

class AttendanceSocketService {
  WebSocketChannel? _channel;
  final _controller = StreamController<List<LiveAttendance>>.broadcast();
  final _tokenStorage = TokenStorage();

  Stream<List<LiveAttendance>> get stream => _controller.stream;

  Future<void> connect() async {
    disconnect();
    final token = await _tokenStorage.readToken();
    final uri = Uri.parse(AppConstants.websocketUrl).replace(
      queryParameters: {if (token != null) 'token': token},
    );
    _channel = WebSocketChannel.connect(uri);
    _channel!.stream.listen(
      (message) {
        final decoded = jsonDecode(message as String) as Map<String, dynamic>;
        final items = decoded['items'];
        if (items is List) {
          _controller.add(
            items
                .map(
                  (item) =>
                      LiveAttendance.fromJson(item as Map<String, dynamic>),
                )
                .toList(),
          );
        }
      },
      onError: _controller.addError,
      onDone: () {},
    );
  }

  void disconnect() {
    _channel?.sink.close();
    _channel = null;
  }

  void dispose() {
    disconnect();
    _controller.close();
  }
}
