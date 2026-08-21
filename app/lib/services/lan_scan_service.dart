import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Finds a SmartSchool server by walking the phone's own subnet.
///
/// [DiscoveryService] asks by UDP broadcast, which is instant and costs one
/// packet -- but plenty of Wi-Fi routers drop broadcast between clients
/// ("AP isolation"), and then nothing answers however healthy the server
/// is. This is the fallback for those networks: try every address on the
/// subnet directly, which no router filters.
///
/// It is a fallback and not the first choice on purpose. Broadcast asks one
/// question; this opens up to 254 connections and is the noisier, slower
/// way to learn the same fact.
class LanScanService {
  /// Long enough for a phone on a busy Wi-Fi to complete a handshake with a
  /// machine that is there, short enough that 254 dead addresses do not add
  /// up to a wait anyone notices. Dead hosts usually fail well before this.
  static const Duration probeTimeout = Duration(milliseconds: 700);

  /// How many probes are allowed in flight. A phone that opens 254 sockets
  /// at once tends to hit the platform's descriptor limits and report
  /// failures that are really its own; batching keeps every result truthful.
  static const int concurrency = 32;

  /// What the school server answers on `/`, and what the Public Server
  /// answers. Matched on so an unrelated service that happens to sit on
  /// port 8000 is not mistaken for ours -- an open port proves nothing.
  static const String backendMarker = 'SmartSchool Backend';
  static const String publicServerMarker = 'SmartSchool Public Server';

  /// The device's own IPv4 addresses, one per connected network.
  Future<List<InternetAddress>> _localAddresses() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
        includeLinkLocal: false,
      );
      return [
        for (final interface in interfaces)
          ...interface.addresses.where((a) => !a.isLoopback),
      ];
    } on Object {
      return const [];
    }
  }

  /// `192.168.0.11` -> `192.168.0.` — the /24 the phone is sitting on.
  ///
  /// Assumes a /24, which is what home and small-office routers hand out.
  /// A wider network would need the netmask, and Dart does not expose it.
  String? _subnetPrefix(InternetAddress address) {
    final parts = address.address.split('.');
    if (parts.length != 4) return null;
    return '${parts[0]}.${parts[1]}.${parts[2]}.';
  }

  /// True if `http://host:port/` is answered by a SmartSchool server.
  Future<bool> _isServer(String host, int port, String marker) async {
    HttpClient? client;
    try {
      client = HttpClient()..connectionTimeout = probeTimeout;
      final request = await client
          .getUrl(Uri.parse('http://$host:$port/'))
          .timeout(probeTimeout);
      final response = await request.close().timeout(probeTimeout);
      if (response.statusCode != 200) {
        await response.drain<void>();
        return false;
      }
      final body = await response
          .transform(utf8.decoder)
          .join()
          .timeout(probeTimeout);
      return body.contains(marker);
    } on Object {
      return false;
    } finally {
      client?.close(force: true);
    }
  }

  /// Scans the phone's subnet for a server answering with [marker].
  ///
  /// Returns a full base URL (`http://host:port`) or null. The phone's own
  /// address is tried first -- on an emulator or a device also running the
  /// stack that is the answer, and it costs one probe to rule out.
  Future<String?> findServer({
    required int port,
    required String marker,
    Duration? overallTimeout,
  }) async {
    final locals = await _localAddresses();
    if (locals.isEmpty) return null;

    final deadline = overallTimeout == null
        ? null
        : DateTime.now().add(overallTimeout);

    for (final local in locals) {
      final prefix = _subnetPrefix(local);
      if (prefix == null) continue;

      // Hosts in the order they are worth trying: the gateway and the low
      // addresses first, because a machine that serves something is usually
      // given a low or reserved address, and a static one at that.
      final hosts = <String>[
        local.address,
        for (var i = 1; i <= 254; i++) '$prefix$i',
      ];
      final seen = <String>{};
      final ordered = [
        for (final host in hosts)
          if (seen.add(host)) host,
      ];

      for (var start = 0; start < ordered.length; start += concurrency) {
        if (deadline != null && DateTime.now().isAfter(deadline)) return null;

        final batch = ordered.skip(start).take(concurrency).toList();
        final results = await Future.wait([
          for (final host in batch) _isServer(host, port, marker),
        ]);

        for (var i = 0; i < batch.length; i++) {
          if (results[i]) return 'http://${batch[i]}:$port';
        }
      }
    }
    return null;
  }
}
