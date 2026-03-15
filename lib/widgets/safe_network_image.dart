import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

/// Widget simple et réutilisable pour charger des images réseau sans planter
/// sur Flutter Web (gère l'erreur de type ProgressEvent via errorBuilder).
/// Supporte aussi les blob URLs générées par image_picker sur le web.
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

    // Sur le web, les blob URLs et les URLs réseau peuvent lever des ProgressEvent
    // On utilise un errorBuilder robuste pour les capturer
    return Image.network(
      url,
      width: width,
      height: height,
      fit: fit,
      // Sur web, toutes les erreurs réseau (y compris blob expirés) sont capturées
      errorBuilder: (context, error, stackTrace) {
        return placeholder ??
            Container(
              width: width,
              height: height,
              color: Colors.grey.shade200,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.image_not_supported_outlined, color: Colors.grey.shade400, size: 24),
                    const SizedBox(height: 4),
                    Text(
                      'Image indisponible',
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 10),
                    ),
                  ],
                ),
              ),
            );
      },
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return placeholder ??
            Container(
              width: width,
              height: height,
              color: Colors.grey.shade100,
              child: const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2D9D6F)),
                  ),
                ),
              ),
            );
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
