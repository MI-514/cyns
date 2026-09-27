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

  @override
  Widget build(BuildContext context) {
    final cleanUrl = imageUrl.trim();
    if (cleanUrl.isEmpty) {
      return _buildPlaceholder();
    }

    if (cleanUrl.startsWith('data:image')) {
      try {
        final base64Data = cleanUrl.split(',').last;
        final Uint8List bytes = base64Decode(base64Data);
        return Image.memory(
          bytes,
          width: width,
          height: height,
          fit: fit,
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
