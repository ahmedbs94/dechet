import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';

class EducatorTab extends StatelessWidget {
  const EducatorTab({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      body: SingleChildScrollView(
        key: const PageStorageKey('educator_tab'),
        primary: false,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 32),
            _buildQuickStats(context),
            const SizedBox(height: 48),

            _buildSectionHeader('OUTILS PÉDAGOGIQUES', Icons.school_rounded),
            const SizedBox(height: 20),
            _buildPedagogicalTools(context),

            const SizedBox(height: 40),

            _buildSectionHeader('SUIVI & ACCOMPAGNEMENT', Icons.supervisor_account_rounded),
            const SizedBox(height: 20),
            _buildStudentTracking(context),

            const SizedBox(height: 40),

            _buildSectionHeader('SÉANCES DE SENSIBILISATION', Icons.event_available_rounded),
            const SizedBox(height: 20),
            _buildAwarenessSessions(context),

            const SizedBox(height: 100),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Menu d\'actions rapides ouvert...')),
          );
        },
        backgroundColor: AppTheme.primaryGreen,
        icon: const Icon(Icons.add_rounded),
        label: const Text('NOUVEAU CONTENU'),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Espace Éducateur', style: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.bold, color: AppTheme.deepSlate)),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: AppTheme.primaryGreen.withOpacity(0.1), shape: BoxShape.circle),
              child: const Icon(Icons.verified_user_rounded, color: AppTheme.primaryGreen),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text('Gérez vos classes et vos contenus pédagogiques.', style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 16)),
      ],
    ).animate().fadeIn().slideX();
  }

  Widget _buildQuickStats(BuildContext context) {
    return Row(
      children: [
        _buildStatCard(context, 'Étudiants Actifs', '1,204', Icons.groups_rounded, Colors.blue),
        const SizedBox(width: 12),
        _buildStatCard(context, 'Cours Publiés', '28', Icons.library_books_rounded, Colors.orange),
        const SizedBox(width: 12),
        _buildStatCard(context, 'Note Moyenne', '4.8', Icons.star_rounded, Colors.amber),
      ],
    );
  }

  Widget _buildStatCard(BuildContext context, String label, String value, IconData icon, Color color) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          // TODO: BACKEND - Fetch detailed statistics for this category (GET /api/educator/stats/{label})
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Détails : $label')),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: AppTheme.tightShadow,
            border: Border.all(color: color.withOpacity(0.1)),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 8),
              Text(value, style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.deepSlate)),
              Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.textMuted, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    ).animate().scale(delay: 200.ms);
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppTheme.primaryGreen),
        const SizedBox(width: 10),
        Text(title, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: AppTheme.textMuted)),
      ],
    );
  }

  Widget _buildPedagogicalTools(BuildContext context) {
    return Column(
      children: [
        _buildToolItem(
          context,
          'Créateur de Quiz Interactif',
          'Concevez des quiz pour tester les connaissances.',
          Icons.quiz_rounded,
          Colors.purple,
        ),
        const SizedBox(height: 16),
        _buildToolItem(
          context,
          'Éditeur d\'Articles & Vidéos',
          'Publiez des tutoriels et guides de tri.',
          Icons.video_library_rounded,
          Colors.red,
        ),
        const SizedBox(height: 16),
        _buildToolItem(
          context,
          'Analyseur de Performance',
          'Suivez les progrès de vos apprenants.',
          Icons.analytics_rounded,
          Colors.teal,
        ),
      ],
    );
  }

  Widget _buildToolItem(BuildContext context, String title, String subtitle, IconData icon, Color color) {
    return GestureDetector(
      onTap: () {
        // TODO: BACKEND - Navigate to respective tool or trigger API action
        // if title == 'Créateur de Quiz' -> Navigator.push(QuizCreatorScreen)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lancement de : $title')),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: AppTheme.tightShadow,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.deepSlate)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400),
          ],
        ),
      ),
    ).animate().slideX(begin: 0.1);
  }

  Widget _buildStudentTracking(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.deepSlate,
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppTheme.premiumShadow,
        image: const DecorationImage(
          image: NetworkImage('https://images.unsplash.com/photo-1557683316-973673baf926?w=800&q=80'),
          fit: BoxFit.cover,
          opacity: 0.1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Questions en attente', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(10)),
                child: const Text('5 Nouveaux', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildQuestionItem(context, 'Comment recycler les piles ?', 'Amine T.', 'Il y a 30m'),
          const Divider(color: Colors.white24, height: 24),
          _buildQuestionItem(context, 'Où jeter les pots de peinture ?', 'Sarah B.', 'Il y a 2h'),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Ouverture du forum de classe...')),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('VOIR TOUTES LES QUESTIONS'),
            ),
          ),
        ],
      ),
    ).animate().fadeIn();
  }

  Widget _buildQuestionItem(BuildContext context, String question, String author, String time) {
    return GestureDetector(
      onTap: () {
         // TODO: BACKEND - Open reply dialog or navigate to thread (GET /api/forum/thread/{id})
         ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Répondre à $author')),
          );
      },
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: Colors.white24,
            child: Text(author[0], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(question, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                Text('$author • $time', style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 11)),
              ],
            ),
          ),
          Icon(Icons.reply_rounded, color: Colors.white.withOpacity(0.5), size: 18),
        ],
      ),
    );
  }

  Widget _buildAwarenessSessions(BuildContext context) {
    return Column(
      children: [
        _buildSessionCard(
          context,
          'Atelier Compostage',
          'Campus Universitaire, Tunis',
          '24 Mars • 14:00',
          '32 Inscrits',
          true
        ),
        const SizedBox(height: 16),
        _buildSessionCard(
          context,
          'Webinaire Zéro Déchet',
          'En ligne (Zoom)',
          '28 Mars • 18:00',
          '150 Inscrits',
          false
        ),
      ],
    );
  }

  Widget _buildSessionCard(BuildContext context, String title, String location, String date, String attendees, bool isPhysical) {
    return GestureDetector(
      onTap: () {
        // TODO: BACKEND - Fetch full event details and attendee list (GET /api/events/{id})
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Détails de l\'événement : $title')),
          );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: AppTheme.tightShadow,
          border: Border(left: BorderSide(color: isPhysical ? Colors.orange : Colors.blue, width: 4)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: (isPhysical ? Colors.orange : Colors.blue).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Text(date.split('•')[0].split(' ')[0], style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.deepSlate)),
                        Text(date.split('•')[0].split(' ')[1], style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.textMuted)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.deepSlate)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.location_on_rounded, size: 12, color: AppTheme.textMuted),
                            const SizedBox(width: 4),
                            Text(location, style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.people_alt_rounded, size: 14, color: AppTheme.deepSlate),
                      const SizedBox(width: 4),
                      Text(attendees, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.deepSlate)),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isPhysical ? Colors.orange.withOpacity(0.1) : Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(isPhysical ? 'PRÉSENTIEL' : 'EN LIGNE', 
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: isPhysical ? Colors.orange : Colors.blue)),
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn().slideY(begin: 0.1);
  }
}
