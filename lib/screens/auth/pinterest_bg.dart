import 'dart:ui';
import 'package:flutter/material.dart';

class PinterestBackground extends StatefulWidget {
  const PinterestBackground({Key? key}) : super(key: key);

  @override
  State<PinterestBackground> createState() => _PinterestBackgroundState();
}

class _PinterestBackgroundState extends State<PinterestBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  // Images illustratives des fonctionnalites — descendent en boucle
  static const List<String> _images = [
    'assets/images/card_impact.png',
    'assets/images/card_rewards.png',
    'assets/images/card_community.png',
    'assets/images/card_map.png',
  ];

  // Couleurs de fallback si l'image ne charge pas
  static const List<Color> _fallbackColors = [
    Color(0xFF064E3B),
    Color(0xFF3B0764),
    Color(0xFF1E3A5F),
    Color(0xFF052E16),
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 40))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _buildColumn(List<String> images, List<Color> colors, bool reverse, double width) {
    // On duplique la liste pour l'effet de défilement infini
    final doubled = [...images, ...images];
    const itemH = 250.0;
    const gap = 12.0;
    final totalH = images.length * (itemH + gap);

    return Expanded(
      child: ClipRect(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final double offset = _controller.value * totalH;
            return OverflowBox(
              maxHeight: double.infinity,
              alignment: Alignment.topCenter,
              child: Transform.translate(
                offset: Offset(0, reverse ? -totalH + offset : -offset),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: doubled.asMap().entries.map((e) {
                    final asset = e.value;
                    final fallback = colors[e.key % colors.length];
                    return Container(
                      margin: const EdgeInsets.only(bottom: gap),
                      height: itemH,
                      width: width,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.asset(
                          asset,
                          fit: BoxFit.cover,
                          errorBuilder: (c, e, s) => Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [fallback, fallback.withOpacity(0.7)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width / 3 - 12;
    return Stack(
      children: [
        Container(color: const Color(0xFF050D18)),
        Positioned.fill(
          child: Opacity(
            opacity: 0.7,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildColumn(_images, _fallbackColors, false, width),
                _buildColumn(_images, _fallbackColors, true,  width),
                _buildColumn(_images, _fallbackColors, false, width),
              ],
            ),
          ),
        ),
        // Glassmorphism overlay
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
            child: Container(color: const Color(0xFF0F172A).withOpacity(0.45)),
          ),
        ),
      ],
    );
  }
}