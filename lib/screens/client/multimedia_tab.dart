import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

// Écran principal gérant l'affichage des contenus éducatifs (Vidéos, Articles, Quiz)
class MultimediaTab extends StatefulWidget {
  const MultimediaTab({Key? key}) : super(key: key);

  @override
  State<MultimediaTab> createState() => _MultimediaTabState();
}

class _MultimediaTabState extends State<MultimediaTab> {
  // État local pour gérer les filtres et les catégories
  String _selectedCategory = 'Tout';
  final List<String> _categories = ['Tout', 'Vidéos', 'Quiz', 'Articles', 'Impact'];

  // Base de données simulée contenant tous les items multimédias
  final List<Map<String, String>> _allContent = [
    {
      'title': 'Le Guide du Tri Pratique',
      'meta': 'Vidéo • 4min',
      'type': 'Vidéos',
      'url': 'https://youtu.be/yUwUEWtVAvU',
      'image': 'https://img.youtube.com/vi/yUwUEWtVAvU/maxresdefault.jpg',
      'description': 'Maîtrisez les fondamentaux du tri en quelques minutes. Cette vidéo vous explique comment séparer vos déchets ménagers pour faciliter le recyclage en Tunisie.',
    },
    {
      'title': 'Quiz : Maître du Tri',
      'meta': 'Quiz • 100pts',
      'type': 'Quiz',
      'image': 'https://images.unsplash.com/photo-1595278069441-2cf29f8005a4?w=400&q=80',
      'description': 'Êtes-vous vraiment un expert du tri ? Testez vos connaissances sur les différents types de plastiques et gagnez des points éco !',
    },
    {
      'title': 'L\'Essentiel du Tri',
      'meta': 'Article • 3min',
      'type': 'Articles',
      'image': 'https://images.unsplash.com/photo-1532996122724-e3c354a0b15b?w=400&q=80',
      'description': 'Découvrez les règles d\'or pour un tri sélectif efficace. Un guide complet pour devenir un citoyen éco-responsable exemplaire.',
    },
    {
      'title': 'Le Plastique en Tunisie',
      'meta': 'Vidéo • 5min',
      'type': 'Vidéos',
      'image': 'https://images.unsplash.com/photo-1595278069441-2cf29f8005a4?w=400&q=80',
      'description': 'Quels sont les enjeux de la pollution plastique dans nos villes ? Explorez les solutions locales pour réduire notre empreinte écologique.',
    },
    {
      'title': 'Quiz : Zéro Déchet',
      'meta': 'Quiz • 80pts',
      'type': 'Quiz',
      'image': 'https://images.unsplash.com/photo-1532996122724-e3c354a0b15b?w=400&q=80',
      'description': 'Comment réduire vos déchets au quotidien ? Relevez le défi de ce quiz et découvrez des astuces pour une vie sans plastique.',
    },
    {
      'title': 'Compostage Maison',
      'meta': 'Vidéo • 8min',
      'type': 'Vidéos',
      'image': 'https://images.unsplash.com/photo-1581578017093-cd30fce4eeb7?w=400&q=80',
      'description': 'Le guide ultime pour débuter votre composteur, même en appartement. Transformez vos restes en ressources pour vos plantes.',
    },
    {
      'title': 'Mission Recyclage',
      'meta': 'Vidéo • Short',
      'type': 'Vidéos',
      'url': 'https://youtube.com/shorts/e_4aS_472zw',
      'image': 'https://images.unsplash.com/photo-1595278069441-2cf29f8005a4?w=400&q=80',
      'description': 'Suivez le parcours incroyable d\'un déchet plastique, de votre poubelle jusqu\'à sa transformation finale en un nouvel objet utile.',
    },
    {
      'title': 'Quiz : Océans Propres',
      'meta': 'Quiz • 120pts',
      'type': 'Quiz',
      'image': 'https://images.unsplash.com/photo-1484417894907-623942c8ee29?w=400&q=80',
      'description': 'Testez vos connaissances sur la protection de la vie marine et l\'impact des micro-plastiques dans nos mers.',
    },
    {
      'title': 'Bénévolat & Environnement',
      'meta': 'Article • 6min',
      'type': 'Articles',
      'image': 'https://media.istockphoto.com/id/1156692026/fr/vectoriel/b%C3%A9n%C3%A9voles-ramassant-les-ordures-en-plastique-%C3%A0-lext%C3%A9rieur-concept-de-volontariat.jpg?s=612x612&w=0&k=20&c=yRbJL49HMH_KYLDcRq7ehn5DWNMRiP87sms-WYpGBDU=',
      'description': 'Rejoignez notre réseau de volontaires passionnés. Ensemble, nous organisons des journées de nettoyage sur les plages et dans les parcs.',
    },
    {
      'title': 'Impact de la Pollution',
      'meta': 'Impact • Galeries',
      'type': 'Impact',
      'image': 'https://images.unsplash.com/photo-1621451537084-482c73073a0f?w=400&q=80',
      'description': 'Des images frappantes de l\'impact de nos déchets sur la biodiversité marine. Une raison de plus pour agir dès aujourd\'hui.',
    },
    {
      'title': 'Avant/Après : Nettoyage',
      'meta': 'Impact • Photos',
      'type': 'Impact',
      'image': 'https://images.unsplash.com/photo-1621451537084-482c73073a0f?w=400&q=80',
      'description': 'Visualisez les résultats spectaculaires de nos dernières actions de nettoyage communautaire à travers la Tunisie.',
    },
    {
      'title': 'Économie Circulaire',
      'meta': 'Article • 10min',
      'type': 'Articles',
      'image': 'https://images.unsplash.com/photo-1595278069441-2cf29f8005a4?w=400&q=80',
      'description': 'Pourquoi jeter quand on peut réutiliser ? Apprenez comment le modèle circulaire peut sauver notre planète et créer de nouveaux emplois.',
    },
    {
      'title': 'Quiz Énergie Propre',
      'meta': 'Quiz • 50pts',
      'type': 'Quiz',
      'image': 'https://images.unsplash.com/photo-1466611653911-95081537e5b7?w=400&q=80',
      'description': 'Mettez vos connaissances au défi sur les énergies solaires et éoliennes. Relevez le challenge et gagnez des récompenses !',
    },
  ];

  // Ouvre une URL externe (ex: YouTube) en utilisant url_launcher
  Future<void> _launchURL(String? url) async {
    if (url == null) return;
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossible d\'ouvrir le lien : $url')),
      );
    }
  }

  // Affiche les détails d'un contenu dans une feuille modale (Bottom Sheet)
  void _openContent(Map<String, String> content) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          children: [
            Stack(
              children: [
                Container(
                  height: 250,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                    image: DecorationImage(image: NetworkImage(content['image']!), fit: BoxFit.cover),
                  ),
                ),
                Positioned(
                  top: 20,
                  right: 20,
                  child: CircleAvatar(
                    backgroundColor: Colors.black26,
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ),
                if (content['type'] == 'Vidéos')
                  const Positioned.fill(
                    child: Center(
                      child: Icon(Icons.play_circle_fill_rounded, size: 80, color: Colors.white70),
                    ),
                  ),
              ],
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(color: AppTheme.primaryGreen.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                          child: Text(content['type']!.toUpperCase(), style: const TextStyle(color: AppTheme.primaryGreen, fontWeight: FontWeight.bold, fontSize: 10)),
                        ),
                        const SizedBox(width: 12),
                        Text(content['meta']!, style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(content['title']!, style: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 24),
                    Text(
                      content['description'] ?? 'Aucune description disponible pour ce contenu.',
                      style: const TextStyle(fontSize: 16, height: 1.6, color: AppTheme.textMain),
                    ),
                    const SizedBox(height: 40),
                    if (content['type'] == 'Quiz')
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Début du Quiz !')));
                        },
                        style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 56)),
                        child: const Text('COMMENCER LE QUIZ'),
                      )
                    else if (content['type'] == 'Vidéos')
                      ElevatedButton.icon(
                        onPressed: () {
                          if (content.containsKey('url')) {
                            _launchURL(content['url']);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lecture de la vidéo...')));
                          }
                        },
                        icon: const Icon(Icons.play_circle_outline_rounded),
                        label: const Text('REGARDER LA VIDÉO'),
                        style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 56)),
                      )
                    else
                      ElevatedButton.icon(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Contenu téléchargé pour une lecture hors-ligne.')));
                        },
                        icon: const Icon(Icons.download_rounded),
                        label: const Text('TÉLÉCHARGER POUR HORS-LIGNE'),
                        style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 56)),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  // Construction de l'interface utilisateur principale
  Widget build(BuildContext context) {
    // Filtrage du contenu basé sur la catégorie sélectionnée
    final filteredContent = _selectedCategory == 'Tout' 
        ? _allContent 
        : _allContent.where((c) => c['type'] == _selectedCategory).toList();

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Animate(
                    effects: [FadeEffect(), SlideEffect(begin: const Offset(-0.2, 0))],
                    child: Text('Formation Éco', style: AppTheme.seniorTheme.textTheme.headlineMedium),
                  ),
                  const Text('Apprendre. Agir. Transformer.'),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Animate(
              effects: [FadeEffect(), SlideEffect(begin: const Offset(0, 0.1))],
              child: _buildFeaturedSection(context),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 16)),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _buildSortingGuideCard(context),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 40)),

          SliverToBoxAdapter(
            child: _buildCategoryList(),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 32)),

          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 20,
                crossAxisSpacing: 20,
                childAspectRatio: 0.8,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final item = filteredContent[index];
                  return Animate(
                    key: ValueKey(item['title']),
                    effects: [FadeEffect(), ScaleEffect(begin: const Offset(0.9, 0.9))],
                    child: GestureDetector(
                      onTap: () => _openContent(item),
                      child: _buildCourseCard(item['title']!, item['meta']!, item['image']!, item['type']!),
                    ),
                  );
                },
                childCount: filteredContent.length,
              ),
            ),
          ),
          
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  // Section "À la une" mettant en avant un contenu spécial
  Widget _buildFeaturedSection(BuildContext context) {
    return GestureDetector(
      onTap: () => _openContent({
        'title': 'Le Futur de nos Villes',
        'meta': 'Spécial • 15min',
        'type': 'Vidéos',
        'image': 'https://images.unsplash.com/photo-1532094349884-543bc11b234d?w=800&q=80',
      }),
      child: Container(
        height: 420,
        margin: const EdgeInsets.symmetric(horizontal: 24),
        child: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(32),
                image: const DecorationImage(
                  image: NetworkImage('https://images.unsplash.com/photo-1532094349884-543bc11b234d?w=800&q=80'),
                  fit: BoxFit.cover,
                ),
                boxShadow: AppTheme.premiumShadow,
              ),
            ),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(32),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withOpacity(0.85)],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryGreen,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text('SÉRIE ORIGINALE', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1.5)),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Le Futur de nos Villes',
                    style: GoogleFonts.outfit(fontSize: 34, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: -1),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Découvrez comment le tri transforme l\'urbanisme moderne en Tunisie.',
                    style: GoogleFonts.inter(color: Colors.white70, fontSize: 14, height: 1.4),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Widget de liste horizontale pour les catégories
  Widget _buildCategoryList() {
    return SizedBox(
      height: 45,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final category = _categories[index];
          final isSelected = _selectedCategory == category;
          return GestureDetector(
            onTap: () => setState(() => _selectedCategory = category),
            child: AnimatedContainer(
              duration: 200.ms,
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 24),
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.primaryGreen : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: isSelected ? Colors.transparent : Colors.grey.shade200),
                boxShadow: isSelected ? [BoxShadow(color: AppTheme.primaryGreen.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))] : [],
              ),
              child: Center(
                child: Text(
                  category,
                  style: TextStyle(
                    color: isSelected ? Colors.white : AppTheme.textMuted,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // Carte individuelle représentant un cours ou un média
  Widget _buildCourseCard(String title, String meta, String imageUrl, String type) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppTheme.tightShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  child: Image.network(
                    imageUrl,
                    width: double.infinity,
                    height: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Colors.grey.shade200,
                        child: Center(
                          child: Icon(
                            Icons.image_not_supported_rounded,
                            color: Colors.grey.shade400,
                            size: 40,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black.withOpacity(0.4)],
                    ),
                  ),
                ),
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      type == 'Quiz' ? Icons.help_outline_rounded : Icons.play_arrow_rounded,
                      color: Colors.white, 
                      size: 28
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.deepSlate), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(meta, style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 10, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSortingGuideCard(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/guide'),
      child: Container(
        height: 140,
        decoration: BoxDecoration(
          color: AppTheme.primaryGreen.withOpacity(0.1),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppTheme.primaryGreen.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: AppTheme.primaryGreen, borderRadius: BorderRadius.circular(10)),
                      child: const Text('NOUVEAU', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 10),
                    Text('Guide Illutré du Tri', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold)),
                    const Text('Apprenez les bases en 1 min.', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                  ],
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: ClipRRect(
                borderRadius: const BorderRadius.only(topRight: Radius.circular(24), bottomRight: Radius.circular(24)),
                child: Image.network(
                  'https://images.unsplash.com/photo-1595278069441-2cf29f8005a4?w=400&q=80',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => const Center(child: Icon(Icons.auto_stories_rounded, color: AppTheme.primaryGreen, size: 40)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
