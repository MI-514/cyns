import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';

class AppNetworkImage extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;

  const AppNetworkImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
  });

  // In-memory cache for decoded base64 image bytes to prevent repeated decoding lag
  static final Map<String, Uint8List> _base64Cache = {};
  static const int _maxCacheEntries = 100;

  @override
  Widget build(BuildContext context) {
    final cleanUrl = imageUrl.trim();
    if (cleanUrl.isEmpty) {
      return _buildPlaceholder();
    }

    if (cleanUrl.startsWith('data:image')) {
      try {
        Uint8List? bytes = _base64Cache[cleanUrl];
        if (bytes == null) {
          final base64Data = cleanUrl.split(',').last;
          bytes = base64Decode(base64Data);
          if (_base64Cache.length >= _maxCacheEntries) {
            _base64Cache.remove(_base64Cache.keys.first);
          }
          _base64Cache[cleanUrl] = bytes;
        }
        return Image.memory(
          bytes,
          width: width,
          height: height,
          fit: fit,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) => _buildPlaceholder(),
        );
      } catch (_) {
        return _buildPlaceholder();
      }
    }

    if (!cleanUrl.startsWith('http://') && !cleanUrl.startsWith('https://')) {
      return _buildPlaceholder();
    }

    return Image.network(
      cleanUrl,
      width: width,
      height: height,
      fit: fit,
      gaplessPlayback: true,
      errorBuilder: (_, __, ___) => _buildPlaceholder(),
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Container(
          width: width,
          height: height,
          color: Colors.black12,
          child: const Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      width: width,
      height: height,
      color: Colors.black12,
      child: const Icon(Icons.image_not_supported_outlined, color: Colors.grey),
    );
  }
}
