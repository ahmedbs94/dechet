import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';
import 'package:google_fonts/google_fonts.dart';

class CollectorTab extends StatelessWidget {
  const CollectorTab({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverAppBar(
          expandedHeight: 200,
          floating: true,
          pinned: true,
          backgroundColor: Colors.white,
          flexibleSpace: FlexibleSpaceBar(
            title: Text('Logistique Temps Réel', style: GoogleFonts.outfit(color: AppTheme.deepSlate, fontWeight: FontWeight.bold, fontSize: 18)),
            background: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.primaryGreen.withOpacity(0.1), Colors.white],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: const Center(child: Opacity(opacity: 0.1, child: FaIcon(FontAwesomeIcons.truckFast, size: 120))),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.all(24),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _buildActiveTourCard().animate().fadeIn().slideX(),
              const SizedBox(height: 32),
              
              Text('OPTIMISATION DES ROUTES', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: AppTheme.textMuted)),
              const SizedBox(height: 16),
              _buildRouteOptimizationCard(),
              
              const SizedBox(height: 32),
              Text('ORIENTATION DES FLUX (TONNAGE)', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: AppTheme.textMuted)),
              const SizedBox(height: 16),
              _buildFlowItem('Centre de Tri Tunis', 'Matières : Plastique/Papier', '1.8 Tons', AppTheme.primaryGreen),
              _buildFlowItem('Unité Valorisation Nord', 'Matières : Organique', '2.4 Tons', Colors.amber),
              _buildFlowItem('Déchetterie Industrielle', 'Matières : Verre/Métal', '0.9 Tons', Colors.blue),
              
              const SizedBox(height: 60),
              
              Animate(
                onPlay: (c) => c.repeat(),
                effects: [ShimmerEffect(duration: 3.seconds)],
                child: ElevatedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.file_present_rounded),
                  label: const Text('GÉNÉRER LE MANIFESTE DE TRANSPORT'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.deepSlate,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                  ),
                ),
              ),
              const SizedBox(height: 120),
            ]),
          ),
        )
      ],
    );
  }

  Widget _buildActiveTourCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.deepSlate,
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
        boxShadow: AppTheme.premiumShadow,
        gradient: AppTheme.darkGradient,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), shape: BoxShape.circle),
                child: const FaIcon(FontAwesomeIcons.truckFront, color: AppTheme.primaryGreen, size: 24),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('TOUR RÉEL #TC-202', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Colors.white, letterSpacing: 1)),
                    Text('Chauffeur : Ahmed B. • ACTIF', style: TextStyle(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: AppTheme.primaryGreen, borderRadius: BorderRadius.circular(30)),
                child: Text('85%', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: Colors.white, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _TourStat(label: 'Vitesse', value: '45 km/h'),
              _TourStat(label: 'Arrêts', value: '18/24'),
              _TourStat(label: 'ETA', value: '14:45'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRouteOptimizationCard() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge), 
        boxShadow: AppTheme.premiumShadow
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Efficacité Carburant', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: AppTheme.primaryGreen.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                child: Text('OPTIMAL', style: TextStyle(color: AppTheme.primaryGreen, fontWeight: FontWeight.w900, fontSize: 9)),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10), 
                child: LinearProgressIndicator(value: 0.92, minHeight: 12, color: AppTheme.primaryGreen, backgroundColor: Colors.grey.shade50)
              ),
              Animate(
                onPlay: (c) => c.repeat(),
                effects: [ShimmerEffect(duration: 2.seconds, color: Colors.white30)],
                child: Container(height: 12, width: double.infinity, color: Colors.transparent),
              ),
            ],
          ),
          const SizedBox(height: 32),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _MiniStat(label: 'Consommation', value: '8.4L/100'),
              _MiniStat(label: 'CO2 Réduit', value: '1.2 Tons'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFlowItem(String title, String sub, String val, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(24), 
        border: Border.all(color: Colors.grey.shade50),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))]
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12), 
            decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle), 
            child: Icon(Icons.token_rounded, color: color, size: 24)
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.deepSlate)),
                Text(sub, style: TextStyle(fontSize: 11, color: AppTheme.textMuted, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          Text(val, style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 18, color: AppTheme.deepSlate)),
        ],
      ),
    );
  }
}

class _TourStat extends StatelessWidget {
  final String label, value;
  const _TourStat({required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label, value;
  const _MiniStat({required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 16, color: AppTheme.deepSlate)),
        Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textMuted, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
