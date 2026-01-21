import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';

class MapTab extends StatelessWidget {
  const MapTab({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Implémentation réelle de la carte via Flutter Map
          FlutterMap(
            options: MapOptions(
              initialCenter: const LatLng(36.8065, 10.1815), // Centre de Tunis
              initialZoom: 11.5,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.tridechet.app',
              ),
              MarkerLayer(
                markers: [
                  _buildMapMarker(context, const LatLng(36.8665, 10.1647), 'Ariana Nord', true),
                  _buildMapMarker(context, const LatLng(36.8065, 10.1815), 'Tunis Centre', false),
                  _buildMapMarker(context, const LatLng(36.8782, 10.3247), 'La Marsa', true),
                  // Points de tri simulés supplémentaires
                   _buildMapMarker(context, const LatLng(36.8189, 10.1658), 'Bardo', false),
                   _buildMapMarker(context, const LatLng(36.7256, 10.2164), 'Ben Arous', true),
                ],
              ),
            ],
          ),
          
          // Superposition de dégradé pour la lisibilité de l'interface (haut/bas)
          IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withOpacity(0.9),
                    Colors.transparent, 
                    Colors.transparent,
                    Colors.white.withOpacity(0.8)
                  ],
                  stops: const [0.0, 0.15, 0.85, 1.0],
                ),
              ),
            ),
          ),

          // Zone de la barre de recherche
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  GlassCard(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.search, color: AppTheme.primaryGreen),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextField(
                            decoration: InputDecoration(
                              hintText: 'Rechercher un point de tri à Tunis...',
                              hintStyle: TextStyle(color: AppTheme.textMuted),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              fillColor: Colors.transparent,
                            ),
                          ),
                        ),
                        const Icon(Icons.tune_rounded, color: AppTheme.textMuted, size: 20),
                      ],
                    ),
                  ).animate().fadeIn().slideY(begin: -0.2),
                  const SizedBox(height: 16),
                  _buildCategories().animate().fadeIn(delay: 400.ms),
                ],
              ),
            ),
          ),

          // Bouton de localisation de l'utilisateur
          Positioned(
            bottom: 120,
            right: 24,
            child: FloatingActionButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Localisation en cours...')),
                );
              },
              backgroundColor: Colors.white,
              child: const Icon(Icons.my_location, color: AppTheme.primaryGreen),
            ).animate().scale(delay: 1.seconds),
          ),
        ],
      ),
    );
  }

  Widget _buildCategories() {
    final filters = ['Proximité', 'Plastique', 'Verre', 'Batteries'];
    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        itemBuilder: (context, index) => GestureDetector(
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Filtre appliqué : ${filters[index]}')),
            );
          },
          child: Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(
              color: index == 0 ? AppTheme.primaryGreen : Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: AppTheme.premiumShadow,
            ),
            child: Center(
              child: Text(
                filters[index],
                style: TextStyle(color: index == 0 ? Colors.white : AppTheme.textMuted, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Marker _buildMapMarker(BuildContext context, LatLng point, String name, bool isVerified) {
    return Marker(
      point: point,
      width: 100,
      height: 100,
      child: GestureDetector(
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Point de Tri : $name\nDéchets acceptés : Plastique, Verre'),
              action: SnackBarAction(label: 'ITINÉRAIRE', onPressed: (){}),
            ),
          );
        },
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primaryGreen,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: AppTheme.primaryGreen.withOpacity(0.4), blurRadius: 15, spreadRadius: 5)],
                border: Border.all(color: Colors.white, width: 3),
              ),
              child: const Icon(Icons.recycling, color: Colors.white, size: 20),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                   BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))
                ]
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(name, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.deepSlate)),
                  if (isVerified) const SizedBox(width: 4),
                  if (isVerified) const Icon(Icons.verified, color: AppTheme.primaryGreen, size: 10),
                ],
              ),
            ),
          ],
        ),
      ).animate(onPlay: (c) => c.repeat(reverse: true)).slideY(begin: 0, end: -0.1, duration: 2.seconds),
    );
  }
}
