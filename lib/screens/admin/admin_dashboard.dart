import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';
import '../../models/post_model.dart';
import '../client/profile_tab.dart';
import 'educator_tab.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({Key? key}) : super(key: key);

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            expandedHeight: 200,
            floating: true,
            pinned: true,
            backgroundColor: Colors.white,
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blueGrey.shade900, Colors.blueGrey.shade800],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      right: -30,
                      top: -30,
                      child: Icon(Icons.security_rounded, size: 180, color: Colors.white.withOpacity(0.05)),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 60.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('CENTRE DE COMMANDEMENT', 
                            style: GoogleFonts.outfit(color: AppTheme.primaryGreen, fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 10)),
                          const SizedBox(height: 4),
                          Text('Supervision Globale', 
                            style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 28)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              IconButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Aucune nouvelle notification')),
                  );
                }, 
                icon: const Icon(Icons.notifications_none_rounded, color: Colors.white),
              ),
               IconButton(
                onPressed: () => Navigator.pushReplacementNamed(context, '/login'), 
                icon: const Icon(Icons.power_settings_new_rounded, color: AppTheme.errorRed),
              ),
              const SizedBox(width: 8),
            ],
            bottom: TabBar(
              controller: _tabController,
              isScrollable: true,
              labelColor: AppTheme.primaryGreen,
              unselectedLabelColor: Colors.white60,
              indicatorColor: AppTheme.primaryGreen,
              indicatorWeight: 3,
              labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14),
              tabs: const [
                Tab(text: 'VUE D\'ENSEMBLE'),
                Tab(text: 'CONTENUS'),
                Tab(text: 'POINTS DE TRI'),
                Tab(text: 'UTILISATEURS'),
                Tab(text: 'MON PROFIL'),
              ],
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildOverviewTab(),
            _buildContentValidationTab(),
            _buildPointsManagementTab(),
            _buildUserManagementTab(),
            const ProfileTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      key: const PageStorageKey('admin_overview'),
      primary: false,
      padding: const EdgeInsets.all(24),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('INDICATEURS DE PERFORMANCE', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 11, color: AppTheme.textMuted)),
          const SizedBox(height: 16),
          _buildKpiGrid(),
          const SizedBox(height: 32),
          
          Text('IMPACT ENVIRONNEMENTAL', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 11, color: AppTheme.textMuted)),
          const SizedBox(height: 16),
          _buildImpactSection(),
          
          const SizedBox(height: 32),
          Text('Engagement de la Communauté', style: AppTheme.seniorTheme.textTheme.headlineSmall),
          const SizedBox(height: 16),
          Container(
            height: 250,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: AppTheme.premiumShadow,
            ),
            child: LineChart(
              LineChartData(
                gridData: FlGridData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true, 
                      getTitlesWidget: (val, meta) {
                        const days = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
                        if (val.toInt() >= 0 && val.toInt() < days.length) {
                           return Text(days[val.toInt()], style: const TextStyle(color: Colors.grey, fontSize: 10));
                        }
                        return const Text('');
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: const [
                      FlSpot(0, 3), FlSpot(1, 4), FlSpot(2, 3.5), FlSpot(3, 5), FlSpot(4, 4.5), FlSpot(5, 7), FlSpot(6, 6)
                    ],
                    isCurved: true,
                    color: AppTheme.primaryGreen,
                    barWidth: 4,
                    isStrokeCapRound: true,
                    dotData: FlDotData(show: false),
                    belowBarData: BarAreaData(show: true, color: AppTheme.primaryGreen.withOpacity(0.05)),
                  ),
                ],
              ),
            ),
          ).animate().fadeIn().scale(),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildKpiGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            _buildSummaryCard('Utilisateurs', '13.5k', '+12%', Icons.group_rounded, Colors.blue, constraints.maxWidth),
            _buildSummaryCard('Contenus', '854', '+5%', Icons.library_books_rounded, Colors.purple, constraints.maxWidth),
            _buildSummaryCard('Points de Tri', '120', '+2', Icons.map_rounded, Colors.orange, constraints.maxWidth),
            _buildSummaryCard('Alertes', '3', '-50%', Icons.warning_amber_rounded, Colors.red, constraints.maxWidth),
          ],
        );
      }
    );
  }

  Widget _buildSummaryCard(String title, String value, String trend, IconData icon, Color color, double parentWidth) {
    double width = (parentWidth - 16) / 2;
    return Container(
      width: width,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.tightShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle), child: Icon(icon, color: color, size: 20)),
              Text(trend, style: TextStyle(color: trend.startsWith('+') ? Colors.green : Colors.red, fontWeight: FontWeight.bold, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 16),
          Text(value, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 24, color: AppTheme.deepSlate)),
          Text(title, style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildImpactSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.deepSlate,
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppTheme.premiumShadow,
      ),
      child: Column(
        children: [
          _buildImpactRow('CO2 Évité', '12.4 Tonnes', Icons.cloud_done_rounded, Colors.blueAccent),
          const Divider(color: Colors.white10, height: 32),
          _buildImpactRow('Eau Économisée', '45,000 L', Icons.water_drop_rounded, Colors.cyan),
          const Divider(color: Colors.white10, height: 32),
          _buildImpactRow('Énergie Sauvegardée', '18.2 MWh', Icons.bolt_rounded, Colors.amber),
        ],
      ),
    );
  }

  Widget _buildImpactRow(String label, String value, IconData icon, Color color) {
    return Row(
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
              Text(label, style: GoogleFonts.inter(color: Colors.white70, fontSize: 13)),
              Text(value, style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
        ),
        const Icon(Icons.trending_up_rounded, color: Colors.green, size: 20),
      ],
    );
  }

  Widget _buildContentValidationTab() {
    return SingleChildScrollView(
      key: const PageStorageKey('admin_content'),
      primary: false,
      padding: const EdgeInsets.all(24),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('MODÉRATION DE CONTENUS', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 12, color: AppTheme.textMuted)),
          const SizedBox(height: 24),
          _buildValidationSection('Articles & Vidéos (Éducation)', [
            _ValidationItem(title: 'Tutoriel: Les piles bouton', author: 'Mme. Amel', type: 'Vidéo', date: 'Il y a 2h'),
            _ValidationItem(title: 'Article: Zéro Déchet au bureau', author: 'Karim S.', type: 'Article', date: 'Il y a 5h'),
          ]),
          const SizedBox(height: 32),
          _buildValidationSection('Mises à jour: Points de Tri', [
            _ValidationItem(title: 'Nouveau point: Cité Olympique', author: 'Sami (Gestionnaire)', type: 'Point', date: 'Il y a 1j'),
            _ValidationItem(title: 'Rapport Maintenance: Marsa', author: 'Collecteur TN', type: 'Alerte', date: 'Il y a 3j'),
          ]),
          const SizedBox(height: 32),
          Text('MODÉRATION IA (SIGNALEMENTS)', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 12, color: Colors.orange.shade800)),
          const SizedBox(height: 16),
          _buildValidationSection('Publications à Vérifier', [
            _ValidationItem(title: 'Scan: Canette Aluminium (Confidence 45%)', author: 'Amine T.', type: 'IA', date: 'Il y a 10m'),
            _ValidationItem(title: 'Erreur Tri: Bouteille verre dans Plastique', author: 'Sarah B.', type: 'IA', date: 'Il y a 1h'),
          ]),
          const SizedBox(height: 32),
          Text('ANNONCES BLOQUÉES (IA)', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 12, color: Colors.red.shade800)),
          const SizedBox(height: 16),
          _buildValidationSection('Annonces Suspectes', 
            mockPosts.where((p) => p.status == PostStatus.rejectedByAI).map((p) => 
               _ValidationItem(
                 title: p.description, 
                 author: p.userName, 
                 type: 'Post', 
                 date: p.timeAgo,
                 onApprove: () {
                    p.status = PostStatus.approved;
                    // In real app, update state/API
                 },
                 onDelete: () {
                    mockPosts.remove(p);
                 },
               )
            ).toList(),
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildPointsManagementTab() {
    return SingleChildScrollView(
      key: const PageStorageKey('admin_points'),
      primary: false,
      padding: const EdgeInsets.all(24),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('RÉSEAU DE COLLECTE', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 12, color: AppTheme.textMuted)),
              ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.add_location_alt_rounded, size: 18),
                label: const Text('AJOUTER'),
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGreen, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildPointItem('Tunis Centre - Bornes Vertes', 'Disponible', 0.85, Colors.green),
          _buildPointItem('Ariana Nord - Plastiques', 'Saturé', 0.98, Colors.red),
          _buildPointItem('La Marsa - Complexe Tri', 'Maintenance', 0.0, Colors.orange),
          _buildPointItem('Bardo - Papier/Carton', 'Disponible', 0.45, Colors.green),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildPointItem(String name, String status, double load, Color statusColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: AppTheme.tightShadow),
      child: Column(
        children: [
          Row(
            children: [
              Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Icon(Icons.location_on_rounded, color: statusColor, size: 24)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text(status, style: GoogleFonts.inter(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12)),
                  ],
                ),
              ),
              const Icon(Icons.edit_note_rounded, color: AppTheme.textMuted),
            ],
          ),
          if (load > 0) ...[
            const SizedBox(height: 16),
            LinearProgressIndicator(value: load, backgroundColor: Colors.grey.shade100, color: statusColor, minHeight: 6),
          ],
        ],
      ),
    );
  }

  Widget _buildUserManagementTab() {
    return SingleChildScrollView(
      key: const PageStorageKey('admin_users'),
      primary: false,
      padding: const EdgeInsets.all(24),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('ADMINISTRATION DES UTILISATEURS', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 12, color: AppTheme.textMuted)),
              ElevatedButton.icon(
                onPressed: () => _showAddUserDialog(context),
                icon: const Icon(Icons.person_add_rounded, size: 18),
                label: const Text('AJOUTER'),
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGreen, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildUserListItem('Amine T.', 'User Premium', '768 pts', 'Actif'),
          _buildUserListItem('Sarah B.', 'User', '450 pts', 'Actif'),
          _buildUserListItem('Me. Amel', 'Educateur', 'Moderateur', 'Actif'),
          _buildUserListItem('Eco-Collect TN', 'Collector pro', 'Partenaire', 'Vérifié'),
          _buildUserListItem('Sami G.', 'Point Manager', 'Staff', 'Actif'),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildUserListItem(String name, String role, String detail, String status) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          CircleAvatar(backgroundColor: AppTheme.backgroundLight, child: Text(name[0], style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryGreen))),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                Text('$role • $detail', style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: Text(status, style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 10)),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.edit_rounded, color: AppTheme.primaryGreen, size: 20),
            onPressed: () => _showEditUserDialog(context, name),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
            onPressed: () => _showDeleteUserConfirm(context, name),
          ),
        ],
      ),
    );
  }

  void _showAddUserDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('Ajouter un utilisateur', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(decoration: InputDecoration(labelText: 'Nom Complet', labelStyle: GoogleFonts.inter())),
            const SizedBox(height: 12),
            TextField(decoration: InputDecoration(labelText: 'Email', labelStyle: GoogleFonts.inter())),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'Rôle'),
              items: ['User', 'Educateur', 'Collecteur', 'Admin'].map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
              onChanged: (v) {},
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('ANNULER')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context), 
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGreen),
            child: const Text('CRÉER'),
          ),
        ],
      ),
    );
  }

  void _showEditUserDialog(BuildContext context, String name) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('Modifier $name', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: const Text('Formulaire de modification des données utilisateur.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('FERMER')),
          ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('SAUVEGARDER')),
        ],
      ),
    );
  }

  void _showDeleteUserConfirm(BuildContext context, String name) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Confirmer la suppression'),
        content: Text('Voulez-vous vraiment supprimer l\'utilisateur $name ? Cette action est irréversible.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('ANNULER')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context), 
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('SUPPRIMER'),
          ),
        ],
      ),
    );
  }

  Widget _buildValidationTab() {
    return Container(); // Deprecated, replaced by specialized tabs
  }

  Widget _buildValidationSection(String title, List<Widget> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.deepSlate)),
            TextButton(
              onPressed: () {
                 ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Chargement de la liste complète...')),
                  );
              }, 
              child: const Text('Tout voir')
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...items,
      ],
    );
  }
}

class _ValidationItem extends StatelessWidget {
  final String title, author, type, date;
  final VoidCallback? onApprove;
  final VoidCallback? onDelete;

  const _ValidationItem({
    required this.title, 
    required this.author, 
    required this.type, 
    required this.date,
    this.onApprove,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.tightShadow,
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppTheme.primaryGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              type == 'Vidéo' ? Icons.play_circle_fill_rounded : 
              (type == 'Point' ? Icons.location_on_rounded : 
              (type == 'Article' ? Icons.article_rounded : 
              (type == 'IA' || type == 'Post' ? Icons.psychology_rounded : Icons.warning_amber_rounded))),
              color: (type == 'IA' || type == 'Post') ? Colors.orange : AppTheme.primaryGreen,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.deepSlate), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text('Par $author • $date', style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
              ],
            ),
          ),
          Row(
            children: [
              IconButton(
                onPressed: (){
                  if (onApprove != null) onApprove!();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Approuvé : $title'), backgroundColor: Colors.green),
                  );
                }, 
                icon: const Icon(Icons.check_circle_outline_rounded, color: Colors.green)
              ),
              IconButton(
                onPressed: (){
                   if (onDelete != null) onDelete!();
                   ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Supprimé : $title'), backgroundColor: Colors.red),
                  );
                }, 
                icon: const Icon(Icons.highlight_off_rounded, color: Colors.red)
              ),
            ],
          ),
        ],
      ),
    ).animate().slideX(begin: 0.1);
  }
}
