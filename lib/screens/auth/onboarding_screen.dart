import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../services/l10n_service.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({Key? key}) : super(key: key);

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingData> _data = [
    const OnboardingData(
      title: 'Tri Intelligent',
      description: 'Simplifiez votre gestion des déchets grâce à notre IA de reconnaissance visuelle.',
      assetPath: 'assets/images/onboarding_1_new.png',
      accentColor: Color(0xFF4CAF50),
    ),
    const OnboardingData(
      title: 'Impact Réel',
      description: 'Visualisez vos économies de CO2 et gagnez des points éco-citoyens à chaque geste.',
      assetPath: 'assets/images/onboarding_2_new.png',
      accentColor: Color(0xFF00BCD4),
    ),
    const OnboardingData(
      title: 'Communauté Active',
      description: 'Rejoignez des milliers de Tunisiens engagés pour un environnement plus propre.',
      assetPath: 'assets/images/onboarding_3_new.png',
      accentColor: Color(0xFFFF9800),
    ),
    const OnboardingData(
      title: 'Guide du Tri',
      description: 'Apprenez les gestes simples pour trier vos déchets comme un expert.',
      assetPath: 'assets/images/onboarding_4_new.png',
      accentColor: Color(0xFF43A047),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Elegant Layered Background
          AnimatedContainer(
            duration: 1.seconds,
            curve: Curves.easeInOut,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  _data[_currentPage].accentColor.withOpacity(0.05),
                  Colors.white,
                  _data[_currentPage].accentColor.withOpacity(0.02),
                ],
              ),
            ),
          ),

          Positioned(
            top: -150,
            right: -100,
            child: Animate(
              onPlay: (c) => c.repeat(reverse: true),
              effects: [FadeEffect(duration: 3.seconds), MoveEffect(begin: const Offset(0, 0), end: const Offset(-20, 20), duration: 5.seconds)],
              child: Container(
                width: 400,
                height: 400,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _data[_currentPage].accentColor.withOpacity(0.03),
                ),
              ),
            ),
          ),

          PageView.builder(
            controller: _pageController,
            onPageChanged: (value) => setState(() => _currentPage = value),
            itemCount: _data.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // High-Quality Lottie with Complex Container
                    SizedBox(
                      height: 350,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Background glowing effect
                          Animate(
                            onPlay: (c) => c.repeat(),
                            effects: [
                              ScaleEffect(begin: const Offset(0.8, 0.8), end: const Offset(1.2, 1.2), duration: 2.seconds, curve: Curves.easeInOut),
                              FadeEffect(begin: 0.3, end: 0.1, duration: 2.seconds),
                            ],
                            child: Container(
                              width: 280,
                              height: 280,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _data[index].accentColor.withOpacity(0.1),
                              ),
                            ),
                          ),
                          // The Visual Content
                          Image.asset(
                            _data[index].assetPath,
                            height: 280,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              return Icon(
                                _getIconForIndex(index),
                                size: 180,
                                color: _data[index].accentColor,
                              ).animate(onPlay: (c) => c.repeat(reverse: true)).shimmer(duration: 2.seconds);
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 50),
                    Animate(
                      key: ValueKey('title_$index'),
                      effects: const [FadeEffect(), SlideEffect(begin: Offset(0, 0.2))],
                      child: Text(
                        L10n.tr('onboarding_title_${index + 1}'),
                        style: GoogleFonts.outfit(
                          fontSize: 34,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.deepSlate,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Animate(
                      key: ValueKey('desc_$index'),
                      effects: const [FadeEffect(delay: Duration(milliseconds: 200)), SlideEffect(begin: Offset(0, 0.1))],
                      child: Text(
                        L10n.tr('onboarding_desc_${index + 1}'),
                        style: GoogleFonts.inter(
                          fontSize: 17,
                          height: 1.6,
                          color: AppTheme.textMuted,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          
          // Premium Bottom Controls
          Positioned(
            bottom: 60,
            left: 40,
            right: 40,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Indicators
                Row(
                  children: List.generate(
                    _data.length,
                    (index) => AnimatedContainer(
                      duration: 400.ms,
                      margin: const EdgeInsets.only(right: 10),
                      height: 8,
                      width: _currentPage == index ? 28 : 8,
                      decoration: BoxDecoration(
                        color: _currentPage == index ? _data[_currentPage].accentColor : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: _currentPage == index 
                          ? [BoxShadow(color: _data[_currentPage].accentColor.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))]
                          : [],
                      ),
                    ),
                  ),
                ),
                
                // Primary Action Button
                Animate(
                  effects: [ShimmerEffect(delay: 2.seconds, duration: 2.seconds)],
                  child: ElevatedButton(
                    onPressed: () {
                      if (_currentPage < _data.length - 1) {
                        _pageController.nextPage(
                          duration: 600.ms,
                          curve: Curves.easeOutQuart,
                        );
                      } else {
                        Navigator.pushReplacementNamed(context, '/login');
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      backgroundColor: _data[_currentPage].accentColor,
                      elevation: 12,
                      shadowColor: _data[_currentPage].accentColor.withOpacity(0.5),
                    ),
                    child: Text(
                      _currentPage == _data.length - 1 ? L10n.tr('btn_start') : L10n.tr('btn_next'),
                      style: GoogleFonts.outfit(fontWeight: FontWeight.bold, letterSpacing: 1),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getIconForIndex(int index) {
    switch (index) {
      case 0: return Icons.psychology_rounded;
      case 1: return Icons.eco_rounded;
      case 2: return Icons.groups_rounded;
      case 3: return Icons.auto_stories_rounded;
      default: return Icons.help_outline_rounded;
    }
  }
}

class OnboardingData {
  final String title;
  final String description;
  final String assetPath;
  final Color accentColor;

  const OnboardingData({
    required this.title,
    required this.description,
    required this.assetPath,
    required this.accentColor,
  });
}
