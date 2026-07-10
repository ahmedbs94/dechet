import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../constants.dart';

/// Widget simple et réutilisable pour charger des images réseau sans planter
/// sur Flutter Web (gère l'erreur de type ProgressEvent via errorBuilder).
///
/// Améliorations qualité :
///   - cacheWidth/cacheHeight pour un rendu adapté à la densité d'écran
///   - filterQuality HIGH pour un rendu net
///   - gaplessPlayback pour éviter le flash blanc au rechargement
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

    if (url.contains('unsplash.com')) {
      // Évite les SocketException hors-ligne en servant des dégradés premium locaux
      final int hash = url.hashCode.abs();
      final List<List<Color>> gradients = [
        [const Color(0xFF0D5C3A), const Color(0xFF10B981)], // Vert Éco / Émeraude
        [const Color(0xFF1E3A8A), const Color(0xFF0D9488)], // Bleu Profond / Cyan
        [const Color(0xFF311042), const Color(0xFF6C3EB8)], // Violet Royal / Améthyste
        [const Color(0xFF0F172A), const Color(0xFF334155)], // Ardoise / Anthracite
      ];
      final List<Color> colors = gradients[hash % gradients.length];
      return placeholder ?? Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      );
    }

    // Calcul du cacheWidth optimal basé sur la densité d'écran
    // (évite le flou sur les écrans haute densité)
    final double dpr = MediaQuery.of(context).devicePixelRatio;
    final int? cacheW = (width != null && width!.isFinite) ? (width! * dpr).toInt() : null;
    final int? cacheH = (height != null && height!.isFinite) ? (height! * dpr).toInt() : null;

    // Résout les chemins relatifs (/uploads/...) → URL absolue sur mobile
    String finalUrl = ApiConstants.resolveUrl(url);
    // Sur Android : normalise aussi localhost → 127.0.0.1 (ADB reverse)
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      finalUrl = finalUrl.replaceAll('//localhost:', '//127.0.0.1:');
    }

    return Image.network(
      finalUrl,
      width: width,
      height: height,
      fit: fit,
      // Rendu haute qualité (évite le pixelisé / flou sur les redimensionnements)
      filterQuality: FilterQuality.high,
      // Évite le flash blanc quand l'image est rechargée (ex: scroll retour)
      gaplessPlayback: true,
      // Taille cache optimale pour la densité d'écran
      cacheWidth: cacheW,
      cacheHeight: cacheH,
      // Sur web les erreurs réseau lèvent des ProgressEvent; errorBuilder les capture.
      errorBuilder: (context, error, stackTrace) {
        return placeholder ?? Container(color: Colors.grey.shade200);
      },
      // Affiche un placeholder fluide pendant le chargement
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        final double? progress = loadingProgress.expectedTotalBytes != null
            ? loadingProgress.cumulativeBytesLoaded /
                loadingProgress.expectedTotalBytes!
            : null;
        return placeholder ??
            Container(
              color: Colors.grey.shade100,
              child: Center(
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Colors.green.shade400,
                    ),
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
