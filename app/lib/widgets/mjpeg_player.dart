import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../services/token_storage.dart';

class MjpegPlayer extends StatefulWidget {
  final String url;
  final double? height;
  final double? width;
  final BoxFit fit;

  const MjpegPlayer({
    super.key,
    required this.url,
    this.height,
    this.width,
    this.fit = BoxFit.contain,
  });

  @override
  State<MjpegPlayer> createState() => _MjpegPlayerState();
}

class _MjpegPlayerState extends State<MjpegPlayer> {
  ui.Image? _image;
  bool _isLoading = true;
  bool _busy = false;
  Timer? _timer;
  final _tokenStorage = TokenStorage();

  @override
  void initState() {
    super.initState();
    _poll();
  }

  void _poll() {
    _timer?.cancel();
    _fetch();
  }

  Future<void> _fetch() async {
    if (_busy) {
      _scheduleNext();
      return;
    }
    _busy = true;
    try {
      final uri = Uri.parse(widget.url);
      final token = await _tokenStorage.readToken();
      final resp = await http
          .get(uri, headers: {if (token != null) 'Authorization': 'Bearer $token'})
          .timeout(const Duration(seconds: 2));
      if (!mounted) return;
      if (resp.statusCode == 200 && resp.bodyBytes.isNotEmpty) {
        _decode(resp.bodyBytes);
      }
    } catch (_) {
      //
    } finally {
      _busy = false;
      if (mounted) _scheduleNext();
    }
  }

  void _scheduleNext() {
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 200), _fetch);
  }

  Future<void> _decode(Uint8List bytes) async {
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      codec.dispose();
      if (!mounted) { frame.image.dispose(); return; }

      _image?.dispose();
      _image = frame.image;
      _isLoading = false;
      if (mounted) setState(() {});
    } catch (_) {}
  }

  @override
  void didUpdateWidget(covariant MjpegPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) { _isLoading = true; _poll(); }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _image?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        color: Colors.black,
        child:
            const Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    if (_image == null) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: Text('No frame', style: TextStyle(color: Colors.white54)),
        ),
      );
    }

    return Container(
      color: Colors.black,
      child: Center(
        child: RawImage(
          image: _image!,
          width: widget.width,
          height: widget.height,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}
