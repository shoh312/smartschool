import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:smartschool_app/generated/app_localizations.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../services/token_storage.dart';

/// Live camera view fed by the server pushing frames over a websocket
/// (see /ws/stream) instead of the client polling over HTTP -- a new frame
/// arrives the instant one is available rather than up to 200ms of polling
/// delay, and no request is wasted re-fetching a frame that hasn't changed.
class WsStreamPlayer extends StatefulWidget {
  final String url;
  final double? height;
  final double? width;

  const WsStreamPlayer({super.key, required this.url, this.height, this.width});

  @override
  State<WsStreamPlayer> createState() => _WsStreamPlayerState();
}

class _WsStreamPlayerState extends State<WsStreamPlayer> {
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  ui.Image? _image;
  bool _isLoading = true;
  bool _decoding = false;
  final _tokenStorage = TokenStorage();

  @override
  void initState() {
    super.initState();
    _connect();
  }

  Future<void> _connect() async {
    final token = await _tokenStorage.readToken();
    final uri = Uri.parse(widget.url).replace(
      queryParameters: {
        ...Uri.parse(widget.url).queryParameters,
        if (token != null) 'token': token,
      },
    );
    _channel = WebSocketChannel.connect(uri);
    _subscription = _channel!.stream.listen(
      (message) {
        // Cast when the socket already hands over a Uint8List, which it
        // does on every platform this ships to -- copying each frame was
        // ~80 KB of pointless allocation fifteen times a second, on the
        // thread that then has to decode it.
        if (message is Uint8List) {
          _decode(message);
        } else if (message is List<int>) {
          _decode(Uint8List.fromList(message));
        }
      },
      onError: (_) {},
    );
  }

  Future<void> _decode(Uint8List bytes) async {
    // The socket can push faster than a single-threaded decode keeps up;
    // drop a frame rather than queue decodes and fall behind in a growing
    // backlog.
    if (_decoding) return;
    _decoding = true;
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      codec.dispose();
      if (!mounted) {
        frame.image.dispose();
        return;
      }
      _image?.dispose();
      _image = frame.image;
      _isLoading = false;
      setState(() {});
    } catch (_) {
      // A partial/corrupt frame every so often is expected -- just skip it.
    } finally {
      _decoding = false;
    }
  }

  @override
  void didUpdateWidget(covariant WsStreamPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _subscription?.cancel();
      _channel?.sink.close();
      _isLoading = true;
      _connect();
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _channel?.sink.close();
    _image?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        color: Colors.black,
        child: const Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    if (_image == null) {
      return Container(
        color: Colors.black,
        child: Center(
          child: Text(
            AppLocalizations.of(context)!.noFrame,
            style: const TextStyle(color: Colors.white54),
          ),
        ),
      );
    }

    // RawImage only respects `fit` when it's given a definite size, and it
    // won't pick one up from a loose parent on its own -- so size it to the
    // frame's native resolution first, then let FittedBox scale that box up
    // to fill whatever space is available (full screen here) without
    // distorting the aspect ratio.
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: Container(
        color: Colors.black,
        child: FittedBox(
          fit: BoxFit.contain,
          child: SizedBox(
            width: _image!.width.toDouble(),
            height: _image!.height.toDouble(),
            child: RawImage(image: _image!),
          ),
        ),
      ),
    );
  }
}
