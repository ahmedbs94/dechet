import 'dart:ui';
import 'package:flutter/material.dart';
import '../../widgets/safe_network_image.dart';

class PinterestBackground extends StatefulWidget {
  const PinterestBackground({Key? key}) : super(key: key);

  @override
  State<PinterestBackground> createState() => _PinterestBackgroundState();
}

class _PinterestBackgroundState extends State<PinterestBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  final List<String> col1 = [
    'https://images.unsplash.com/photo-1542601906990-b4d3fb778b09?w=500&q=80',
    'https://images.unsplash.com/photo-1518173946687-a4c8892bbd9f?w=500&q=80',
    'https://images.unsplash.com/photo-1497436072909-60f360e1d4b1?w=500&q=80',
    'https://images.unsplash.com/photo-1542601906990-b4d3fb778b09?w=500&q=80',
  ];
  final List<String> col2 = [
    'https://images.unsplash.com/photo-1473448912268-2022ce9509d8?w=500&q=80',
    'https://images.unsplash.com/photo-1464822759023-fed622ff2c3b?w=500&q=80',
    'https://images.unsplash.com/photo-1501504905252-473c47e087f8?w=500&q=80',
    'https://images.unsplash.com/photo-1473448912268-2022ce9509d8?w=500&q=80',
  ];
  final List<String> col3 = [
    'https://images.unsplash.com/photo-1441974231531-c6227db76b6e?w=500&q=80',
    'https://images.unsplash.com/photo-1532996122724-e3c354a0b15b?w=500&q=80',
    'https://images.unsplash.com/photo-1472214103451-9374bd1c798e?w=500&q=80',
    'https://images.unsplash.com/photo-1441974231531-c6227db76b6e?w=500&q=80',
  ];

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(vsync: this, duration: const Duration(seconds: 40))
          ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Colonne d'images animée en défilement vertical.
  /// ClipRect + OverflowBox empêchent le débordement de layout tout en
  /// laissant la translation dépasser les limites logiques du parent.
  Widget _buildColumn(List<String> images, bool reverse, double width) {
    return Expanded(
      child: ClipRect(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final double offset = _controller.value * 786;
            return OverflowBox(
              maxHeight: double.infinity,
              alignment: Alignment.topCenter,
              child: Transform.translate(
                offset: Offset(0, reverse ? -786 + offset : -offset),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: images.map((url) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      height: 250,
                      width: width,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        color: Colors.grey.shade100,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: SafeNetworkImage(
                          url,
                          fit: BoxFit.cover,
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
        Container(color: Colors.black),
        Positioned.fill(
          child: Opacity(
            opacity: 0.6,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildColumn(col1, false, width),
                _buildColumn(col2, true, width),
                _buildColumn(col3, false, width),
              ],
            ),
          ),
        ),
        // Glassmorphism overlay
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
            child: Container(
              color: const Color(0xFF0F172A).withOpacity(0.4),
            ),
          ),
        ),
      ],
    );
  }
}
