import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../core/constants.dart';
import 'lan_scan_service.dart';
import 'token_storage.dart';

/// Points [AppConstants.baseUrl] at the school server on this network: the
/// last known-good address first (fast, no broadcast if it still answers),
/// falling back to a broadcast search, and leaving the compiled-in address in
/// place if neither works.
///
/// Called from two places, because there are two ways to arrive at a staff
/// session: cold start with a saved one (SplashScreen), and signing in after
/// somebody else signed out (LoginScreen) -- logout jumps straight to the
/// login screen without passing through the splash again.
Future<void> resolveSchoolServerUrl(TokenStorage tokenStorage) async {
  final discovery = DiscoveryService();
  final cachedUrl = await tokenStorage.readServerUrl();

  if (cachedUrl != null && await discovery.isReachable(cachedUrl)) {
    AppConstants.setResolvedBaseUrl(cachedUrl);
    return;
  }

  final discoveredUrl = await discovery.discoverBaseUrl();
  if (discoveredUrl != null) {
    AppConstants.setResolvedBaseUrl(discoveredUrl);
    await tokenStorage.saveServerUrl(discoveredUrl);
    return;
  }

  // Broadcast went unanswered. That does not mean the server is down --
  // many routers refuse to pass broadcast between wireless clients, and on
  // those networks the question never reaches it. Walk the subnet instead.
  final scanned = await LanScanService().findServer(
    port: AppConstants.schoolServerPort,
    marker: LanScanService.backendMarker,
    overallTimeout: const Duration(seconds: 20),
  );
  if (scanned != null) {
    AppConstants.setResolvedBaseUrl(scanned);
    await tokenStorage.saveServerUrl(scanned);
  }
}

/// Points the Public Server at whatever is serving it on this network.
///
/// Only for the on-site setup this project is being tested with, where the
/// Public Server happens to run on the same machine as the school's. In a
/// real deployment it lives on the internet at a fixed address and none of
/// this applies -- which is why the saved address always wins here, and a
/// scan is only attempted when nothing has been configured.
Future<void> resolvePublicServerUrl(TokenStorage tokenStorage) async {
  final discovery = DiscoveryService();
  final saved = await tokenStorage.readPublicServerUrl();

  // A saved address is preferred but never simply believed. On a real
  // deployment this is the domain a director typed in Settings and it keeps
  // working; on this test setup it is a LAN address a previous scan found,
  // and the moment the machine moves to another network it is a dead end.
  //
  // Trusting it blindly is what broke parent sign-in: the school server is
  // rediscovered every launch and kept working, while the Public Server
  // stayed pinned to an address that had stopped existing.
  if (saved != null && saved.isNotEmpty) {
    AppConstants.setPublicServerBaseUrl(saved);
    if (await discovery.isReachable(saved)) return;
  }

  if (await discovery.isReachable(AppConstants.defaultPublicServerBaseUrl)) {
    AppConstants.setPublicServerBaseUrl(null);
    return;
  }

  final scanned = await LanScanService().findServer(
    port: AppConstants.publicServerPort,
    marker: LanScanService.publicServerMarker,
    overallTimeout: const Duration(seconds: 20),
  );
  if (scanned != null) {
    AppConstants.setPublicServerBaseUrl(scanned);
    await tokenStorage.savePublicServerUrl(scanned);
  }
}

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
