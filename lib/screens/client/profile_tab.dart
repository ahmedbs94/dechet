import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../models/user_model.dart';
import '../../models/post_model.dart'; // Added import for post_model.dart
import '../../widgets/glass_card.dart';

class ProfileTab extends StatefulWidget {
  const ProfileTab({Key? key}) : super(key: key);

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  // Mise à jour pour une image plus professionnelle type "Directeur"
  String _profileImage = 'https://images.unsplash.com/photo-1560250097-0b93528c311a?w=400&q=80';
  bool _pushNotifications = true;
  bool _mfaEnabled = false;

  void _changeProfileImage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sélecteur d\'image ouvert...')),
    );
     // Simulation de cycle vers une autre image professionnelle
    setState(() {
      _profileImage = 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=400&q=80';
    });
  }

  void _showMfaDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('Authentification Forte', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.security_rounded, size: 60, color: AppTheme.primaryGreen),
            const SizedBox(height: 20),
            const Text('Activez la validation en deux étapes pour sécuriser votre compte éco-responsable.'),
            const SizedBox(height: 20),
            ListTile(
              title: const Text('Utiliser l\'application'),
              subtitle: const Text('Google Authenticator / Authy'),
              trailing: Switch(value: _mfaEnabled, onChanged: (v) {
                setState(() => _mfaEnabled = v);
                Navigator.pop(context);
              }, activeColor: AppTheme.primaryGreen),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('FERMER')),
        ],
      ),
    );
  }

  void _showPasswordDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('Changer le mot de passe', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const TextField(obscureText: true, decoration: InputDecoration(labelText: 'Mot de passe actuel')),
            const SizedBox(height: 12),
            const TextField(obscureText: true, decoration: InputDecoration(labelText: 'Nouveau mot de passe')),
            const SizedBox(height: 12),
            const TextField(obscureText: true, decoration: InputDecoration(labelText: 'Confirmer')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('ANNULER')),
          ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('METTRE À JOUR')),
        ],
      ),
    );
  }

  void _viewSavedPosts(BuildContext context) {
    final savedPosts = mockPosts.where((post) => post.isSaved).toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return GlassCard(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          child: Container(
            height: MediaQuery.of(context).size.height * 0.75,
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40, height: 5,
                    decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 20),
                Text('Publications enregistrées', style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.deepSlate)),
                const SizedBox(height: 16),
                Expanded(
                  child: savedPosts.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(FontAwesomeIcons.bookmark, size: 60, color: AppTheme.textMuted.withOpacity(0.5)),
                              const SizedBox(height: 20),
                              Text('Aucune publication enregistrée pour le moment.', textAlign: TextAlign.center, style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 16)),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: savedPosts.length,
                          itemBuilder: (context, index) {
                            final post = savedPosts[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 8),
                              elevation: 2,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              child: ListTile(
                                leading: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(post.imageUrl, width: 48, height: 48, fit: BoxFit.cover),
                                ),
                                title: Text(post.userName, style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                                subtitle: Text(post.description, maxLines: 2, overflow: TextOverflow.ellipsis),
                                trailing: const Icon(FontAwesomeIcons.solidBookmark, color: AppTheme.primaryGreen, size: 16),
                                onTap: () => Navigator.pop(context),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthState.currentUser;
    // Masquer les statistiques de gamification pour les rôles Admin/Directeur
    final showStats = user?.role == UserRole.user; 

    return Scaffold(
      backgroundColor: Colors.transparent, // Fond géré par le parent ou par défaut
      body: SingleChildScrollView(
        primary: false,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: [
            const SizedBox(height: 40),
            
            Animate(
              effects: const [FadeEffect(), ScaleEffect()],
              child: _buildProfileHeader(user),
            ),
            
            const SizedBox(height: 32),

            // Afficher les statistiques de gamification uniquement pour un utilisateur standard
            if (showStats)
              Animate(
                effects: [FadeEffect(delay: 300.ms), SlideEffect(begin: const Offset(0, 0.1))],
                child: _buildStatsGrid(),
              ),

             if (!showStats) ...[
               _buildProfessionalBadge(),
               const SizedBox(height: 32),
             ],

            const SizedBox(height: 40),

            _buildMenuSection('SÉCURITÉ ET DONNÉES', [
              _MenuAction(
                icon: FontAwesomeIcons.userShield, 
                title: 'Authentification forte', 
                subtitle: _mfaEnabled ? 'Activée' : 'Désactivée',
                onTap: _showMfaDialog,
              ),
              _MenuAction(
                icon: FontAwesomeIcons.key, 
                title: 'Changer le mot de passe', 
                subtitle: 'Mis à jour il y a 3 mois',
                onTap: _showPasswordDialog,
              ),
              _MenuAction( // New menu item for saved posts
                icon: FontAwesomeIcons.bookmark, 
                title: 'Publications enregistrées', 
                subtitle: 'Accédez à votre bibliothèque éco',
                onTap: () => _viewSavedPosts(context),
              ),
              _MenuAction(
                icon: FontAwesomeIcons.fileExport, // Changed icon from fileContract to fileExport
                title: 'Exporter mes données', // Changed title from 'Export des données'
                subtitle: 'Format PDF ou JSON', // Changed subtitle from 'Format JSON/PDF'
                onTap: () {
                   ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Export en cours... Veuillez patienter.')),
                  );
                },
              ),
            ]),

            const SizedBox(height: 32),

            _buildMenuSection('PRÉFÉRENCES', [
              _MenuAction(
                icon: FontAwesomeIcons.bell, 
                title: 'Notifications push', 
                trailing: Switch(
                  value: _pushNotifications, 
                  onChanged: (v) => setState(() => _pushNotifications = v), 
                  activeColor: AppTheme.primaryGreen
                ),
              ),
              _MenuAction(
                icon: FontAwesomeIcons.moon, 
                title: 'Mode Sombre', 
                subtitle: 'Système par défaut',
                onTap: () {
                   ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Thème : Basculement en cours...')),
                  );
                },
              ),
            ]),

            const SizedBox(height: 60),

            Animate(
              effects: [FadeEffect(delay: 1.seconds)],
              child: ElevatedButton(
                onPressed: () => Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade50,
                  foregroundColor: Colors.red,
                  elevation: 0,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  minimumSize: const Size(double.infinity, 60),
                ),
                child: const Text('DÉCONNEXION'),
              ),
            ),
            
            const SizedBox(height: 120),
          ],
        ),
      ),
    );
  }

  Widget _buildProfessionalBadge() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.deepSlate, Colors.blueGrey.shade800],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.premiumShadow,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), shape: BoxShape.circle),
            child: const Icon(Icons.business_center_rounded, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Espace Professionnel', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 4),
                const Text('Vous avez accès aux outils d\'administration avancés.', style: TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.1);
  }

  Widget _buildProfileHeader(User? user) {
    return Column(
      children: [
        GestureDetector(
          onTap: _changeProfileImage,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Lueur professionnelle propre au lieu des particules de jeu
              Container(
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: AppTheme.primaryGreen.withOpacity(0.2), blurRadius: 40, spreadRadius: 10),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  boxShadow: AppTheme.tightShadow,
                ),
                child: CircleAvatar(
                  radius: 60,
                  backgroundImage: NetworkImage(_profileImage),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.deepSlate, 
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 14),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text(user?.name ?? 'Admin', style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.bold, color: AppTheme.deepSlate)),
        Text(user?.email ?? 'admin@tridechet.com', style: GoogleFonts.inter(color: AppTheme.textMuted, fontWeight: FontWeight.w500)),
        const SizedBox(height: 20),
        
        // Suppression du badge de rang générique pour l'admin, conservé uniquement pour les utilisateurs si nécessaire ou remplacé par un tag professionnel
         Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: AppTheme.primaryGreen.withOpacity(0.1),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: AppTheme.primaryGreen.withOpacity(0.2)),
          ),
          child: Text(
             user?.role == UserRole.admin ? 'DIRECTEUR TECHNIQUE' : 'USER ENGAGÉ',
             style: GoogleFonts.outfit(color: AppTheme.primaryGreen, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1.5)
          ),
        ),
      ],
    );
  }

  Widget _buildStatsGrid() {
    final userId = AuthState.currentUser?.id ?? '1';
    final totalPoints = WasteRecordService.getTotalPoints(userId);
    final totalCO2 = WasteRecordService.getTotalCO2Saved(userId);
    final totalActions = WasteRecordService.getUserRecords(userId).length;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
        boxShadow: AppTheme.premiumShadow,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('POINTS', '$totalPoints', Icons.stars_rounded),
          _buildDivider(),
          _buildStatItem('CO2', '${totalCO2.toStringAsFixed(1)}kg', Icons.eco_rounded),
          _buildDivider(),
          _buildStatItem('ACTES', '$totalActions', Icons.check_circle_rounded),
        ],
      ),
    );
  }

  Widget _buildDivider() => Container(height: 40, width: 1, color: Colors.grey.shade100);

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: AppTheme.primaryGreen.withOpacity(0.5), size: 20),
        const SizedBox(height: 8),
        Text(value, style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.deepSlate)),
        Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppTheme.textMuted, letterSpacing: 1)),
      ],
    );
  }

  Widget _buildMenuSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8.0),
          child: Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: AppTheme.textMuted, letterSpacing: 1.5)),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: Colors.white, 
            borderRadius: BorderRadius.circular(24), 
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 8))]
          ),
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _MenuAction extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _MenuAction({required this.icon, required this.title, this.subtitle, this.trailing, this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: AppTheme.primaryGreen.withOpacity(0.05), shape: BoxShape.circle),
        child: FaIcon(icon, size: 16, color: AppTheme.primaryGreen),
      ),
      title: Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 15)),
      subtitle: subtitle != null ? Text(subtitle!, style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)) : null,
      trailing: trailing ?? const Icon(Icons.chevron_right, size: 16, color: AppTheme.textMuted),
    );
  }
}
