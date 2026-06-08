import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../widgets/safe_network_image.dart';


class CommunityScreen extends StatefulWidget {
  const CommunityScreen({Key? key}) : super(key: key);

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  final AuthService _authService = AuthService();

  List<Map<String, dynamic>> _testimonials = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTestimonials();
  }

  Future<void> _loadTestimonials() async {
    final data = await _authService.fetchTestimonials();
    if (mounted) {
      setState(() {
        _testimonials = data;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // En-tête sans bouton retour — navigation assurée par la barre/sidebar
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 56, 24, 28),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF059669), Color(0xFF0D9488), Color(0xFF0891B2)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Espace Communauté',
                    style: GoogleFonts.spaceGrotesk(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1,
                    ),
                  ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.2, end: 0),
                  const SizedBox(height: 6),
                  Text(
                    'Témoignages et propositions de nos éco-citoyens',
                    style: GoogleFonts.inter(color: Colors.white.withOpacity(0.8), fontSize: 14),
                  ).animate().fadeIn(delay: 150.ms),
                ],
              ),
            ),
            _buildContent(),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.only(top: 120),
        child: Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen)),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Action buttons ──
          if (AuthState.isLoggedIn && AuthState.currentUser?.role == UserRole.user) ...[
            _buildAddTestimonialButton(),
            const SizedBox(height: 12),
            _buildSubmitProposalButton(),
            const SizedBox(height: 28),
          ],

          // ── Section title ──
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFBBF24).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.format_quote_rounded, color: Color(0xFFFBBF24), size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                'Avis de nos citoyens',
                style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w900, color: AppTheme.deepSlate),
              ),
            ],
          ).animate().fadeIn(delay: 200.ms),
          const SizedBox(height: 6),
          Text(
            '${_testimonials.length} témoignage${_testimonials.length > 1 ? 's' : ''}',
            style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textMuted),
          ).animate().fadeIn(delay: 250.ms),
          const SizedBox(height: 20),

          // ── Testimonials list ──
          if (_testimonials.isEmpty)
            _buildEmptyState()
          else
            ..._testimonials.asMap().entries.map((entry) {
              final i = entry.key;
              final t = entry.value;
              final userId = int.tryParse(AuthState.currentUser?.id ?? '');
              return _TestimonialCard(
                testimonial: t,
                isOwn: t['user_id'] == userId,
                onDelete: () => _deleteTestimonial(t['id']),
              ).animate().fadeIn(delay: Duration(milliseconds: 300 + i * 80)).slideY(begin: 0.05, end: 0);
            }),
        ],
      ),
    );
  }

  // ── Add Testimonial Button ──

  Widget _buildAddTestimonialButton() {
    final userId = int.tryParse(AuthState.currentUser?.id ?? '');
    final hasExisting = _testimonials.any((t) => t['user_id'] == userId);
    if (hasExisting) return const SizedBox.shrink();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: _showAddTestimonialDialog,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF059669), Color(0xFF0D9488)]),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: AppTheme.primaryGreen.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 8))],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.rate_review_rounded, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Partager votre avis', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
                    const SizedBox(height: 2),
                    Text('Votre expérience compte !', style: GoogleFonts.inter(color: Colors.white70, fontSize: 12)),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 14),
            ],
          ),
        ),
      ),
    ).animate().fadeIn().slideY(begin: 0.1, end: 0);
  }

  // ── Submit Proposal Button ──

  Widget _buildSubmitProposalButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: _showAddProposalDialog,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)]),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: const Color(0xFF6366F1).withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 8))],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.add_location_alt_rounded, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Proposer un centre de tri', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
                    const SizedBox(height: 2),
                    Text('Suggérez un nouvel emplacement', style: GoogleFonts.inter(color: Colors.white70, fontSize: 12)),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 14),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.1, end: 0);
  }

  // ── Add Testimonial Dialog ──

  void _showAddTestimonialDialog() {
    final contentController = TextEditingController();
    int selectedRating = 5;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 20),
              Text('Votre avis', style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.w900, color: AppTheme.deepSlate)),
              const SizedBox(height: 8),
              Text('Partagez votre expérience avec EcoRewind', style: GoogleFonts.inter(fontSize: 14, color: AppTheme.textMuted)),
              const SizedBox(height: 24),
              Text('Note', style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 14)),
              const SizedBox(height: 8),
              Row(
                children: List.generate(5, (i) => GestureDetector(
                  onTap: () => setModalState(() => selectedRating = i + 1),
                  child: Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Icon(i < selectedRating ? Icons.star_rounded : Icons.star_outline_rounded, color: const Color(0xFFFBBF24), size: 36),
                  ),
                )),
              ),
              const SizedBox(height: 20),
              Text('Votre témoignage', style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 14)),
              const SizedBox(height: 8),
              TextField(
                controller: contentController,
                maxLines: 4,
                maxLength: 500,
                decoration: InputDecoration(
                  hintText: 'Décrivez votre expérience...',
                  hintStyle: GoogleFonts.inter(color: AppTheme.textMuted),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppTheme.primaryGreen, width: 2)),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: () async {
                    final content = contentController.text.trim();
                    if (content.isEmpty) return;
                    Navigator.pop(ctx);
                    final result = await _authService.createTestimonial(content, selectedRating);
                    if (result['success'] == true) {
                      _loadTestimonials();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: const Text('✅ Avis soumis ! Il sera visible après approbation.'),
                          backgroundColor: AppTheme.primaryGreen,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ));
                      }
                    } else if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(result['message'] ?? 'Erreur'),
                        backgroundColor: Colors.red.shade400,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ));
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: Text('Publier mon avis', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Add Proposal Dialog ──

  void _showAddProposalDialog() {
    final nameCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final List<String> selectedTypes = [];
    final wasteOptions = ['Plastique', 'Verre', 'Papier', 'Métal', 'Organique', 'Électronique', 'Textile'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.85),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 20),
                Text('Proposer un centre de tri', style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w900, color: AppTheme.deepSlate)),
                const SizedBox(height: 8),
                Text('Votre proposition sera examinée par l\'administration', style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textMuted)),
                const SizedBox(height: 24),
                _buildField('Nom du centre', nameCtrl, 'Ex: Point Vert Lac 2'),
                const SizedBox(height: 16),
                _buildField('Adresse', addressCtrl, 'Ex: Avenue Habib Bourguiba, Tunis'),
                const SizedBox(height: 16),
                Text('Types de déchets', style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 14)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: wasteOptions.map((type) {
                    final isSelected = selectedTypes.contains(type);
                    return GestureDetector(
                      onTap: () => setModalState(() {
                        isSelected ? selectedTypes.remove(type) : selectedTypes.add(type);
                      }),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? AppTheme.primaryGreen.withOpacity(0.1) : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: isSelected ? AppTheme.primaryGreen : Colors.grey.shade200, width: isSelected ? 2 : 1),
                        ),
                        child: Text(type, style: GoogleFonts.inter(fontSize: 13, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500, color: isSelected ? AppTheme.primaryGreen : AppTheme.textMuted)),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                _buildField('Description (optionnel)', descCtrl, 'Détails supplémentaires...', maxLines: 3),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (nameCtrl.text.trim().isEmpty || addressCtrl.text.trim().isEmpty) {
                        ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Nom et adresse obligatoires')));
                        return;
                      }
                      Navigator.pop(ctx);
                      final result = await _authService.createCenterProposal(
                        name: nameCtrl.text.trim(),
                        address: addressCtrl.text.trim(),
                        wasteTypes: selectedTypes.join(','),
                        description: descCtrl.text.trim(),
                      );
                      if (result['success'] == true && mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: const Text('📍 Proposition envoyée ! Elle sera examinée par l\'admin.'),
                          backgroundColor: const Color(0xFF6366F1),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ));
                      } else if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(result['message'] ?? 'Erreur'),
                          backgroundColor: Colors.red.shade400,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ));
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: Text('Envoyer la proposition', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 16)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField(String label, TextEditingController ctrl, String hint, {int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 14)),
        const SizedBox(height: 8),
        TextField(
          controller: ctrl,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 13),
            filled: true,
            fillColor: Colors.grey.shade50,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppTheme.primaryGreen, width: 2)),
          ),
        ),
      ],
    );
  }

  Future<void> _deleteTestimonial(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Supprimer votre avis ?', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: const Text('Cette action est irréversible.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Supprimer', style: TextStyle(color: Colors.red.shade400))),
        ],
      ),
    );
    if (confirm == true) {
      await _authService.deleteTestimonial(id);
      _loadTestimonials();
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: AppTheme.primaryGreen.withOpacity(0.08), shape: BoxShape.circle),
              child: Icon(Icons.format_quote_rounded, size: 48, color: AppTheme.primaryGreen.withOpacity(0.5)),
            ),
            const SizedBox(height: 20),
            Text('Aucun avis encore', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.deepSlate)),
            const SizedBox(height: 6),
            Text('Soyez le premier à partager\nvotre expérience !', style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textMuted), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

// ============================================
// Testimonial Card Widget
// ============================================

class _TestimonialCard extends StatelessWidget {
  final Map<String, dynamic> testimonial;
  final bool isOwn;
  final VoidCallback onDelete;

  const _TestimonialCard({required this.testimonial, required this.isOwn, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final name = testimonial['user_name'] ?? 'Citoyen';
    final content = testimonial['content'] ?? '';
    final rating = testimonial['rating'] ?? 5;
    final avatarUrl = testimonial['user_avatar_url'] ?? '';
    final createdAt = testimonial['created_at'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ...List.generate(5, (i) => Icon(i < rating ? Icons.star_rounded : Icons.star_outline_rounded, color: const Color(0xFFFBBF24), size: 18)),
              const Spacer(),
              if (isOwn)
                GestureDetector(
                  onTap: onDelete,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
                    child: Icon(Icons.delete_outline_rounded, size: 16, color: Colors.red.shade400),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text('"$content"', style: GoogleFonts.inter(color: AppTheme.deepSlate, fontSize: 14, fontStyle: FontStyle.italic, height: 1.6)),
          const SizedBox(height: 16),
          Row(
            children: [
              SafeNetworkCircleAvatar(url: avatarUrl, radius: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w800, fontSize: 14, color: AppTheme.deepSlate)),
                    if (createdAt.isNotEmpty)
                      Text(_formatDate(createdAt), style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: AppTheme.primaryGreen.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.verified_rounded, color: AppTheme.primaryGreen, size: 16),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(String isoDate) {
    try {
      final dt = DateTime.parse(isoDate);
      final months = ['jan', 'fév', 'mar', 'avr', 'mai', 'jun', 'jul', 'aoû', 'sep', 'oct', 'nov', 'déc'];
      return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
    } catch (_) {
      return '';
    }
  }
}
