import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../services/auth_service.dart';

/// Écran admin de gestion des propositions de centres de tri.
/// Affiche toutes les propositions soumises par les citoyens
/// avec possibilité d'approuver, refuser ou supprimer.
class AdminProposalsScreen extends StatefulWidget {
  const AdminProposalsScreen({Key? key}) : super(key: key);

  @override
  State<AdminProposalsScreen> createState() => _AdminProposalsScreenState();
}

class _AdminProposalsScreenState extends State<AdminProposalsScreen> {
  final AuthService _authService = AuthService();

  List<Map<String, dynamic>> _proposals = [];
  bool _isLoading = true;
  String _filterStatus = 'all'; // all, pending, approved, rejected

  @override
  void initState() {
    super.initState();
    _loadProposals();
  }

  Future<void> _loadProposals() async {
    setState(() => _isLoading = true);
    final data = await _authService.fetchCenterProposals(
      status: _filterStatus == 'all' ? null : _filterStatus,
    );
    if (mounted) {
      setState(() {
        _proposals = data;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: AppTheme.primaryGreen,
      onRefresh: _loadProposals,
      child: SingleChildScrollView(
        key: const PageStorageKey('admin_proposals'),
        primary: false,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 20),
            _buildFilterChips(),
            const SizedBox(height: 20),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.only(top: 80),
                child: Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen)),
              )
            else if (_proposals.isEmpty)
              _buildEmptyState()
            else
              ..._proposals.asMap().entries.map((entry) {
                final i = entry.key;
                return _buildProposalCard(entry.value)
                    .animate()
                    .fadeIn(delay: Duration(milliseconds: 100 + i * 60))
                    .slideY(begin: 0.04, end: 0);
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final pendingCount = _proposals.where((p) => p['status'] == 'pending').length;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Propositions de centres',
                  style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w900, color: AppTheme.deepSlate)),
              const SizedBox(height: 4),
              Text(
                '${_proposals.length} proposition${_proposals.length > 1 ? 's' : ''}${pendingCount > 0 ? ' · $pendingCount en attente' : ''}',
                style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textMuted),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF6366F1).withOpacity(0.08),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.location_city_rounded, color: Color(0xFF6366F1), size: 24),
        ),
      ],
    ).animate().fadeIn();
  }

  Widget _buildFilterChips() {
    final filters = [
      {'key': 'all', 'label': 'Toutes', 'icon': Icons.list_rounded},
      {'key': 'pending', 'label': 'En attente', 'icon': Icons.hourglass_top_rounded},
      {'key': 'approved', 'label': 'Approuvées', 'icon': Icons.check_circle_rounded},
      {'key': 'rejected', 'label': 'Refusées', 'icon': Icons.cancel_rounded},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((f) {
          final isActive = _filterStatus == f['key'];
          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: GestureDetector(
              onTap: () {
                setState(() => _filterStatus = f['key'] as String);
                _loadProposals();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isActive ? AppTheme.primaryGreen : Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: isActive ? AppTheme.primaryGreen : (Theme.of(context).brightness == Brightness.dark ? Theme.of(context).dividerColor : Colors.grey.shade200)),
                  boxShadow: isActive
                      ? [BoxShadow(color: AppTheme.primaryGreen.withOpacity(0.2), blurRadius: 12, offset: const Offset(0, 4))]
                      : [],
                ),
                child: Row(
                  children: [
                    Icon(f['icon'] as IconData, size: 16, color: isActive ? Colors.white : AppTheme.textMuted),
                    const SizedBox(width: 6),
                    Text(
                      f['label'] as String,
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: isActive ? FontWeight.w800 : FontWeight.w500,
                        color: isActive ? Colors.white : AppTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    ).animate().fadeIn(delay: 100.ms);
  }

  Widget _buildProposalCard(Map<String, dynamic> proposal) {
    final name = proposal['name'] ?? '';
    final address = proposal['address'] ?? '';
    final status = proposal['status'] ?? 'pending';
    final wasteTypes = (proposal['waste_types'] ?? '').toString();
    final description = proposal['description'] ?? '';
    final userName = proposal['user_name'] ?? 'Citoyen';
    final proposalId = proposal['id'] as int;
    final createdAt = proposal['created_at'] ?? '';

    final statusConfig = {
      'pending': {'color': const Color(0xFFF59E0B), 'label': 'En attente', 'icon': Icons.hourglass_top_rounded},
      'approved': {'color': AppTheme.primaryGreen, 'label': 'Approuvé', 'icon': Icons.check_circle_rounded},
      'rejected': {'color': Colors.red.shade400, 'label': 'Refusé', 'icon': Icons.cancel_rounded},
    };
    final cfg = statusConfig[status] ?? statusConfig['pending']!;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: status == 'pending' ? const Color(0xFFF59E0B).withOpacity(0.3) : (Theme.of(context).brightness == Brightness.dark ? Theme.of(context).dividerColor : Colors.grey.shade100), width: status == 'pending' ? 2 : 1),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: const Color(0xFF6366F1).withOpacity(0.08), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.location_on_rounded, color: Color(0xFF6366F1), size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 16, color: AppTheme.deepSlate)),
                    Text(address, style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMuted), maxLines: 2, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: (cfg['color'] as Color).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(cfg['icon'] as IconData, size: 12, color: cfg['color'] as Color),
                    const SizedBox(width: 3),
                    Text(cfg['label'] as String, style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w800, color: cfg['color'] as Color)),
                  ],
                ),
              ),
            ],
          ),

          // Waste types
          if (wasteTypes.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: wasteTypes.split(',').where((t) => t.trim().isNotEmpty).map((type) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(type.trim(), style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.primaryGreen)),
              )).toList(),
            ),
          ],

          // Description
          if (description.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(description, style: GoogleFonts.inter(fontSize: 13, color: AppTheme.deepSlate, height: 1.5)),
          ],

          // Meta info
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(Icons.person_outline_rounded, size: 14, color: AppTheme.textMuted),
              const SizedBox(width: 4),
              Text(userName, style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted, fontWeight: FontWeight.w600)),
              if (createdAt.isNotEmpty) ...[
                const SizedBox(width: 10),
                const Icon(Icons.access_time_rounded, size: 14, color: AppTheme.textMuted),
                const SizedBox(width: 4),
                Text(_formatDate(createdAt), style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted)),
              ],
            ],
          ),

          // Admin action buttons
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 14),
          Row(
            children: [
              if (status != 'approved')
                Expanded(
                  child: _buildActionBtn(
                    label: 'Approuver',
                    icon: Icons.check_rounded,
                    color: AppTheme.primaryGreen,
                    onTap: () => _updateStatus(proposalId, 'approved'),
                  ),
                ),
              if (status != 'approved' && status != 'rejected') const SizedBox(width: 10),
              if (status != 'rejected')
                Expanded(
                  child: _buildActionBtn(
                    label: 'Refuser',
                    icon: Icons.close_rounded,
                    color: Colors.orange.shade600,
                    onTap: () => _updateStatus(proposalId, 'rejected'),
                  ),
                ),
              const SizedBox(width: 10),
              _buildActionBtn(
                label: '',
                icon: Icons.delete_outline_rounded,
                color: Colors.red.shade400,
                onTap: () => _deleteProposal(proposalId),
                isCompact: true,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionBtn({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    bool isCompact = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: isCompact ? 8 : 10, vertical: 9),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: isCompact ? MainAxisSize.min : MainAxisSize.max,
            children: [
              Icon(icon, size: 15, color: color),
              if (label.isNotEmpty) ...[
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    label,
                    style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w700, color: color),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _updateStatus(int id, String status) async {
    final result = await _authService.updateCenterProposalStatus(id, status);
    if (result && mounted) {
      _loadProposals();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(status == 'approved' ? '✅ Proposition approuvée' : '⛔ Proposition refusée'),
        backgroundColor: status == 'approved' ? AppTheme.primaryGreen : Colors.orange.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    }
  }

  Future<void> _deleteProposal(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Supprimer cette proposition ?', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: const Text('Cette action est irréversible.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Supprimer', style: TextStyle(color: Colors.red.shade400))),
        ],
      ),
    );
    if (confirm == true) {
      await _authService.deleteCenterProposal(id);
      _loadProposals();
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 80),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: const Color(0xFF6366F1).withOpacity(0.08), shape: BoxShape.circle),
              child: Icon(Icons.add_location_alt_rounded, size: 48, color: const Color(0xFF6366F1).withOpacity(0.4)),
            ),
            const SizedBox(height: 20),
            Text('Aucune proposition', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.deepSlate)),
            const SizedBox(height: 6),
            Text('Les propositions des citoyens\napparaîtront ici.', style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textMuted), textAlign: TextAlign.center),
          ],
        ),
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
