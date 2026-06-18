import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/l10n_service.dart';

class IntercommunalityTab extends StatefulWidget {
  const IntercommunalityTab({Key? key}) : super(key: key);

  @override
  State<IntercommunalityTab> createState() => _IntercommunalityTabState();
}

class _IntercommunalityTabState extends State<IntercommunalityTab> {
  @override
  void initState() {
    super.initState();
    L10n.addListener(_onLocaleChange);
  }

  void _onLocaleChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    L10n.removeListener(_onLocaleChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(L10n.tr('Coordination Territoriale'), style: AppTheme.seniorTheme.textTheme.headlineMedium),
          Text(L10n.tr('Gérez les politiques de tri et les acteurs locaux.')),
          const SizedBox(height: 40),
          
          _buildActionCard(
            L10n.tr('Consignes de tri locales'),
            L10n.tr('Mise à jour des règles 2026'),
            Icons.balance_rounded,
            Colors.purple,
          ).animate().fadeIn().slideX(begin: 0.1),
          
          const SizedBox(height: 16),
          _buildActionCard(
            L10n.tr('Points de collecte'),
            L10n.tr('Centralisation (342 points)'),
            Icons.location_city_rounded,
            Colors.blue,
          ).animate().fadeIn(delay: 100.ms).slideX(begin: 0.1),
          
          const SizedBox(height: 16),
          _buildActionCard(
            L10n.tr('Acteurs locaux'),
            L10n.tr('Coordination : 12 prestataires'),
            Icons.groups_rounded,
            Colors.orange,
          ).animate().fadeIn(delay: 200.ms).slideX(begin: 0.1),
          
          const SizedBox(height: 48),
          
          Text(L10n.tr('RAPPORTS DE PERFORMANCE INTERCOMMUNALE'), 
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: AppTheme.textMuted)),
          const SizedBox(height: 16),
          _buildRegionalChart(),
        ],
      ),
    );
  }

  Widget _buildRegionalChart() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
        boxShadow: AppTheme.premiumShadow,
      ),
      child: Column(
        children: [
          _bar('Tunis Capital', 0.9, AppTheme.primaryGreen),
          const SizedBox(height: 16),
          _bar('Ariana', 0.7, Colors.blue),
          const SizedBox(height: 16),
          _bar('Ben Arous', 0.4, Colors.amber),
        ],
      ),
    );
  }

  Widget _bar(String label, double val, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14)),
            Text('${(val*100).toInt()}%', style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w900, color: color)),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(10), 
          child: LinearProgressIndicator(value: val, minHeight: 10, color: color, backgroundColor: color.withOpacity(0.05))
        ),
      ],
    );
  }

  Widget _buildActionCard(String title, String sub, IconData icon, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(24), 
        boxShadow: AppTheme.tightShadow
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        leading: Container(
          padding: const EdgeInsets.all(12), 
          decoration: BoxDecoration(color: color.withOpacity(0.08), shape: BoxShape.circle), 
          child: Icon(icon, color: color, size: 24)
        ),
        title: Text(title, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.deepSlate)),
        subtitle: Text(sub, style: const TextStyle(fontSize: 12, color: AppTheme.textMuted, fontWeight: FontWeight.w500)),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppTheme.textMuted),
      ),
    );
  }
}
