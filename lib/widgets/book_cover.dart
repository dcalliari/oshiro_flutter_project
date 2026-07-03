import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Network book cover with graceful loading/error fallbacks. Shared by the
/// screens so no raw `Image.network` (which throws on error) leaks through.
class BookCover extends StatelessWidget {
  const BookCover({super.key, required this.url, this.width, this.height});

  final String url;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) return _placeholder();
    return CachedNetworkImage(
      imageUrl: url,
      width: width,
      height: height,
      fit: BoxFit.cover,
      placeholder: (_, __) => _box(
        const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      errorWidget: (_, __, ___) => _placeholder(),
    );
  }

  Widget _placeholder() => _box(
        const Icon(Icons.menu_book, color: Colors.grey),
      );

  Widget _box(Widget child) => Container(
        width: width,
        height: height,
        color: Colors.grey.shade200,
        child: child,
      );
}
