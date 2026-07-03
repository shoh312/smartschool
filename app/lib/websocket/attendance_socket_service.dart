import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../core/constants.dart';
import '../models/attendance.dart';

class AttendanceSocketService {
  WebSocketChannel? _channel;
  final _controller = StreamController<List<LiveAttendance>>.broadcast();

  Stream<List<LiveAttendance>> get stream => _controller.stream;

  void connect() {
    disconnect();
    _channel = WebSocketChannel.connect(Uri.parse(AppConstants.websocketUrl));
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
