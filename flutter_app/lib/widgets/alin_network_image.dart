import 'package:flutter/material.dart';
import '../core/app_scope.dart';

class AlinNetworkImage extends StatelessWidget {
  final String path;
  final BoxFit fit;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  const AlinNetworkImage({
    super.key,
    required this.path,
    this.fit = BoxFit.contain,
    this.width,
    this.height,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final url = AppScope.of(context).mediaUrl(path);
    final child = url.isEmpty
        ? Container(
            color: const Color(0xFFF0F4F8),
            alignment: Alignment.center,
            child: Image.asset('assets/images/alin_icon.png', width: 72, fit: BoxFit.contain),
          )
        : Image.network(
            url,
            width: width,
            height: height,
            fit: fit,
            errorBuilder: (_, __, ___) => Container(
              color: const Color(0xFFF0F4F8),
              alignment: Alignment.center,
              child: Image.asset('assets/images/alin_icon.png', width: 72, fit: BoxFit.contain),
            ),
            loadingBuilder: (context, child, progress) => progress == null
                ? child
                : const Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
    return ClipRRect(borderRadius: borderRadius ?? BorderRadius.zero, child: child);
  }
}
