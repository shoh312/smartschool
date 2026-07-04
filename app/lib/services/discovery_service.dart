import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Finds the SmartSchool backend automatically on the current local network by
/// UDP broadcast, so the app doesn't need a hardcoded server IP that breaks
/// every time the device joins a different Wi-Fi.
class DiscoveryService {
  static const _discoveryPort = 8734;
  static const _magicRequest = 'SMARTSCHOOL_DISCOVER_V1';
  static const _magicResponsePrefix = 'SMARTSCHOOL_HERE:';

  /// Broadcasts a discovery request and returns the first reply as a full
  /// `http://host:port` base URL, or null if nothing replied within [timeout].
  Future<String?> discoverBaseUrl({
    Duration timeout = const Duration(seconds: 2),
  }) async {
    RawDatagramSocket? socket;
    try {
      socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      socket.broadcastEnabled = true;

      final completer = Completer<String?>();

      socket.listen((event) {
        if (event != RawSocketEvent.read) return;
        final datagram = socket!.receive();
        if (datagram == null) return;

        final message = utf8.decode(datagram.data, allowMalformed: true);
        if (!message.startsWith(_magicResponsePrefix)) return;

        final port = message.substring(_magicResponsePrefix.length).trim();
        final host = datagram.address.address;
        if (!completer.isCompleted) {
          completer.complete('http://$host:$port');
        }
      });

      socket.send(
        utf8.encode(_magicRequest),
        InternetAddress('255.255.255.255'),
        _discoveryPort,
      );

      return await completer.future.timeout(timeout, onTimeout: () => null);
    } catch (_) {
      return null;
    } finally {
      socket?.close();
    }
  }

  /// Quick reachability check for a previously cached base URL, so a working
  /// connection on the same network doesn't need to re-broadcast every launch.
  Future<bool> isReachable(
    String baseUrl, {
    Duration timeout = const Duration(seconds: 2),
  }) async {
    try {
      final client = HttpClient()..connectionTimeout = timeout;
      final request = await client
          .getUrl(Uri.parse(baseUrl))
          .timeout(timeout);
      final response = await request.close().timeout(timeout);
      await response.drain();
      client.close();
      return response.statusCode < 500;
    } catch (_) {
      return false;
    }
  }
}
