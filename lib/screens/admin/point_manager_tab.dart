import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';
import 'package:google_fonts/google_fonts.dart';

class PointManagerTab extends StatelessWidget {
  const PointManagerTab({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Supervision des Points', style: AppTheme.seniorTheme.textTheme.headlineMedium),
          const Text('Surveillance et maintenance en temps réel.'),
          const SizedBox(height: 32),
          
          _buildMapPreview().animate().fadeIn().scale(),
          
          const SizedBox(height: 48),
          
          const Text('SIGNALEMENTS ET ALERTES (IOT)', 
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: AppTheme.errorRed)),
          const SizedBox(height: 16),
          
          _AlertCard(title: 'Bac saturé : Rue de la Paix', level: 'URGENT', time: '12 min ago'),
          _AlertCard(title: 'Défaut capteur : Parking Nord', level: 'MAINTENANCE', time: '1h ago'),
          _AlertCard(title: 'Signalement Usager : Centre', level: 'VRAC', time: '2h ago'),
          
          const SizedBox(height: 40),
          
          ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.deepSlate, minimumSize: const Size(double.infinity, 60)),
            child: const Text('PLANIFIER UNE INTERVENTION'),
          ).animate().fadeIn(delay: 500.ms),
          
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildMapPreview() {
    return Container(
      height: 240,
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.deepSlate,
        borderRadius: BorderRadius.circular(32),
        boxShadow: AppTheme.premiumShadow,
        image: const DecorationImage(
          image: NetworkImage('https://images.unsplash.com/photo-1524661135-423995f22d0b?w=800&q=80'),
          fit: BoxFit.cover,
          opacity: 0.15,
        ),
      ),
      child: Stack(
        children: [
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                   Animate(
                    onPlay: (c) => c.repeat(),
                    effects: [ScaleEffect(begin: const Offset(1, 1), end: const Offset(1.2, 1.2), duration: 2.seconds, curve: Curves.easeInOut), FadeEffect(begin: 1.0, end: 0.5)],
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(color: AppTheme.primaryGreen.withOpacity(0.2), shape: BoxShape.circle),
                      child: const Icon(Icons.location_searching_rounded, color: AppTheme.primaryGreen, size: 40),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('SCAN TERRITORIAL IOT ACTIF', style: GoogleFonts.outfit(color: AppTheme.primaryGreen, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 2)),
                ],
              ),
            ),
            Positioned(
              bottom: 20,
              left: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(10)),
                child: Row(
                  children: [
                    const CircleAvatar(radius: 4, backgroundColor: Colors.red),
                    const SizedBox(width: 8),
                    Text('3 ALERTES CRITIQUES', style: GoogleFonts.outfit(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AlertCard extends StatelessWidget {
  final String title, level, time;
  const _AlertCard({required this.title, required this.level, required this.time});

  @override
  Widget build(BuildContext context) {
    final isUrgent = level == 'URGENT';
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppTheme.tightShadow,
        border: Border.all(color: isUrgent ? Colors.red.withOpacity(0.1) : Colors.grey.shade50),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isUrgent ? Colors.red.withOpacity(0.1) : Colors.grey.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isUrgent ? Icons.error_outline_rounded : Icons.info_outline_rounded, 
              color: isUrgent ? Colors.red : AppTheme.textMuted,
              size: 24,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.deepSlate)),
                const SizedBox(height: 4),
                Text('$level • $time', style: GoogleFonts.inter(fontSize: 10, color: AppTheme.textMuted, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
              ],
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {},
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('DÉTAILS', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 11, color: AppTheme.primaryGreen)),
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn().slideX(begin: 0.1);
  }
}
