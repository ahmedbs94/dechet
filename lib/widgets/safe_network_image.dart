import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

/// Widget simple et réutilisable pour charger des images réseau sans planter
/// sur Flutter Web (gère l'erreur de type ProgressEvent via errorBuilder).
class SafeNetworkImage extends StatelessWidget {
  final String url;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Widget? placeholder;

  const SafeNetworkImage(
    this.url, {
    Key? key,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.placeholder,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) return placeholder ?? const SizedBox.shrink();

    return Image.network(
      url,
      width: width,
      height: height,
      fit: fit,
      // Sur web les erreurs réseau lèvent des ProgressEvent; errorBuilder les capture.
      errorBuilder: (context, error, stackTrace) {
        return placeholder ?? Container(color: Colors.grey.shade200);
      },
      // optional: show nothing until data is ready on web to avoid intermittent errors
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return placeholder ?? Container(color: Colors.grey.shade200);
      },
    );
  }
}

class SafeNetworkCircleAvatar extends StatelessWidget {
  final String url;
  final double radius;
  final Widget? placeholder;

  const SafeNetworkCircleAvatar({Key? key, required this.url, this.radius = 20, this.placeholder}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.grey.shade200,
      child: ClipOval(
        child: SizedBox(
          width: radius * 2,
          height: radius * 2,
          child: SafeNetworkImage(url, placeholder: placeholder ?? const SizedBox.shrink()),
        ),
      ),
    );
  }
}
