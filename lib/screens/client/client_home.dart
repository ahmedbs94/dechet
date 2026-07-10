import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../widgets/auth_prompt_dialog.dart';
import '../../services/l10n_service.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../models/user_model.dart';
import 'feed_tab.dart';
import 'map_tab.dart';
import 'rewards_tab.dart';
import 'profile_tab.dart';
import 'multimedia_tab.dart';
import 'community_screen.dart';

import '../admin/collector_tab.dart';
import '../admin/intercommunality_tab.dart';
import '../admin/point_manager_tab.dart';
import '../admin/educator_tab.dart';
import '../messaging/messaging_screen.dart';
import '../../theme/app_theme.dart';
import '../../theme/platform_ui.dart';
import '../../layouts/web_shell.dart';
import 'package:google_fonts/google_fonts.dart';

class MainNavigationShell extends StatefulWidget {
  final int initialTab;
  const MainNavigationShell({Key? key, this.initialTab = 0}) : super(key: key);

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  late int _currentIndex;
  late final bool _isLoggedIn;
  List<Widget> get _pages => _initializePages(AuthState.currentUser?.role ?? UserRole.user);


  // GlobalKeys pour accéder aux states des tabs et appeler refresh()
  final GlobalKey<ProfileTabState> _profileKey = GlobalKey<ProfileTabState>();

  @override
  void initState() {
    super.initState();
    L10n.addListener(_onLocaleChange);
    _isLoggedIn = AuthState.currentUser != null;
    _currentIndex = widget.initialTab.clamp(0, _pages.length - 1);

    if (!_isLoggedIn) {
      Future.delayed(const Duration(milliseconds: 700), () {
        if (mounted) AuthPromptDialog.show(context: context);
      });
    }
  }

  @override
  void dispose() {
    L10n.removeListener(_onLocaleChange);
    super.dispose();
  }

  void _onLocaleChange() {
    if (mounted) setState(() {});
  }


  /// Appelé quand on change d'onglet — simple setState pour conserver l'état des tabs
  void _onTabSelected(int index) {
    if (_currentIndex == index) return;
    final role = AuthState.currentUser?.role ?? UserRole.user;
    // Index de l'onglet Profil selon le rôle
    int profileIndex;
    if (role == UserRole.educator) {
      profileIndex = 2; // [Educateur, Messages, Profil]
    } else if (role == UserRole.user) {
      profileIndex = 6; // [Feed, Multimedia, Rewards, Map, Community, Messages, Profil]
    } else if (role == UserRole.intercommunality ||
               role == UserRole.pointManager ||
               role == UserRole.collector) {
      profileIndex = 3; // [EspaceMetier, Messages, Carte, Profil]
    } else {
      profileIndex = 4;
    }
    if (index == profileIndex) _profileKey.currentState?.refreshScore();
    setState(() => _currentIndex = index);
  }

  List<Widget> _initializePages(UserRole role) {
    if (!_isLoggedIn) {
      return [
        const FeedTab(key: ValueKey('feed')),
        const MultimediaTab(key: ValueKey('multimedia')),
        const RewardsTab(key: ValueKey('rewards')),
        const MapTab(key: ValueKey('map')),
      ];
    }

    switch (role) {
      // ── Rôle Éducateur : 3 onglets (Espace Éducateur + Messages + Profil) ──
      case UserRole.educator:
        return [
          const EducatorTab(key: ValueKey('educator')),
          const MessagingScreen(key: ValueKey('messaging')),
          ProfileTab(key: _profileKey),
        ];

      // ── Rôle Collecteur : Espace Métier + Messages + Carte + Profil ──
      case UserRole.collector:
        return [
          const CollectorTab(key: ValueKey('collector')),
          const MessagingScreen(key: ValueKey('messaging')),
          const MapTab(key: ValueKey('map')),
          ProfileTab(key: _profileKey),
        ];

      // ── Rôle Intercommunalité : Espace Métier + Messages + Carte + Profil ──
      case UserRole.intercommunality:
        return [
          const IntercommunalityTab(key: ValueKey('intercommunality')),
          const MessagingScreen(key: ValueKey('messaging')),
          const MapTab(key: ValueKey('map')),
          ProfileTab(key: _profileKey),
        ];

      // ── Rôle Gestionnaire : Signalements + Messages + Carte + Profil ──
      case UserRole.pointManager:
        return [
          const PointManagerTab(key: ValueKey('pointmanager')),
          const MessagingScreen(key: ValueKey('messaging')),
          const MapTab(key: ValueKey('map')),
          ProfileTab(key: _profileKey),
        ];

      // ── Rôle Citoyen (user) : 6 onglets avec Communauté + Messages ──
      case UserRole.user:
        return [
          const FeedTab(key: ValueKey('feed')),
          const MultimediaTab(key: ValueKey('multimedia')),
          const RewardsTab(key: ValueKey('rewards')),
          const MapTab(key: ValueKey('map')),
          const CommunityScreen(key: ValueKey('community')),
          const MessagingScreen(key: ValueKey('messaging')),
          ProfileTab(key: _profileKey),
        ];

      default:
        return [
          const FeedTab(key: ValueKey('feed')),
          const MultimediaTab(key: ValueKey('multimedia')),
          const RewardsTab(key: ValueKey('rewards')),
          const MapTab(key: ValueKey('map')),
          const CommunityScreen(key: ValueKey('community')),
          const MessagingScreen(key: ValueKey('messaging')),
          ProfileTab(key: _profileKey),
        ];
    }
  }

  /// Renvoie le label de l'onglet "Formation" selon le rôle
  String _proTabLabel(UserRole role) {
    switch (role) {
      case UserRole.educator:     return L10n.tr('tab_educator');
      case UserRole.collector:    return L10n.tr('tab_collector');
      case UserRole.intercommunality: return L10n.tr('tab_intercommunality');
      case UserRole.pointManager: return L10n.tr('tab_pointManager');
      default:                    return L10n.tr('tab_multimedia');
    }
  }

  /// Renvoie l'icône de l'onglet "Formation" selon le rôle
  Widget _proTabIcon(UserRole role) {
    switch (role) {
      case UserRole.educator:
        return const FaIcon(FontAwesomeIcons.chalkboardUser, size: 20);
      case UserRole.collector:
        return const Icon(Icons.recycling_rounded, size: 22);
      case UserRole.intercommunality:
        return const Icon(Icons.account_balance_rounded, size: 22);
      case UserRole.pointManager:
        return const Icon(Icons.location_on_rounded, size: 22);
      default:
        return const FaIcon(FontAwesomeIcons.graduationCap, size: 20);
    }
  }

  List<NavigationDestination> _getDestinations(UserRole role) {
    // Visiteur non connecté — pas d'onglet Profil
    if (!_isLoggedIn) {
      return [
        NavigationDestination(icon: const FaIcon(FontAwesomeIcons.house, size: 20), label: L10n.tr('tab_feed')),
        NavigationDestination(icon: const FaIcon(FontAwesomeIcons.graduationCap, size: 20), label: _proTabLabel(role)),
        NavigationDestination(icon: const FaIcon(FontAwesomeIcons.chartLine, size: 20), label: L10n.tr('tab_rewards')),
        NavigationDestination(icon: const FaIcon(FontAwesomeIcons.mapLocationDot, size: 20), label: L10n.tr('tab_map')),
      ];
    }

    // ── Éducateur : 3 onglets (Espace Métier + Messages + Profil) ──
    if (role == UserRole.educator) {
      return [
        NavigationDestination(icon: _proTabIcon(role), label: _proTabLabel(role)),
        const NavigationDestination(icon: Icon(Icons.forum_rounded, size: 22), label: 'Messages'),
        NavigationDestination(icon: const FaIcon(FontAwesomeIcons.user, size: 20), label: L10n.tr('tab_profile')),
      ];
    }

    // ── Intercommunalité / Gestionnaire / Collecteur : 4 onglets avec Messages ──
    if (role == UserRole.intercommunality ||
        role == UserRole.pointManager ||
        role == UserRole.collector) {
      return [
        NavigationDestination(icon: _proTabIcon(role), label: _proTabLabel(role)),
        const NavigationDestination(icon: Icon(Icons.forum_rounded, size: 22), label: 'Messages'),
        NavigationDestination(icon: const FaIcon(FontAwesomeIcons.mapLocationDot, size: 20), label: L10n.tr('tab_map')),
        NavigationDestination(icon: const FaIcon(FontAwesomeIcons.user, size: 20), label: L10n.tr('tab_profile')),
      ];
    }

    // ── Citoyen : 7 onglets avec Communauté + Messages ──
    if (role == UserRole.user) {
      return [
        NavigationDestination(icon: const FaIcon(FontAwesomeIcons.house, size: 20), label: L10n.tr('tab_feed')),
        NavigationDestination(icon: _proTabIcon(role), label: _proTabLabel(role)),
        NavigationDestination(icon: const FaIcon(FontAwesomeIcons.chartLine, size: 20), label: L10n.tr('tab_rewards')),
        NavigationDestination(icon: const FaIcon(FontAwesomeIcons.mapLocationDot, size: 20), label: L10n.tr('tab_map')),
        NavigationDestination(icon: const FaIcon(FontAwesomeIcons.comments, size: 20), label: L10n.tr('tab_community')),
        const NavigationDestination(icon: Icon(Icons.forum_rounded, size: 22), label: 'Messages'),
        NavigationDestination(icon: const FaIcon(FontAwesomeIcons.user, size: 20), label: L10n.tr('tab_profile')),
      ];
    }

    // Admin et autres : 5 onglets standard + Messages
    return [
      NavigationDestination(icon: const FaIcon(FontAwesomeIcons.house, size: 20), label: L10n.tr('tab_feed')),
      NavigationDestination(icon: _proTabIcon(role), label: _proTabLabel(role)),
      NavigationDestination(icon: const FaIcon(FontAwesomeIcons.chartLine, size: 20), label: L10n.tr('tab_rewards')),
      NavigationDestination(icon: const FaIcon(FontAwesomeIcons.mapLocationDot, size: 20), label: L10n.tr('tab_map')),
      const NavigationDestination(icon: Icon(Icons.forum_rounded, size: 22), label: 'Messages'),
      NavigationDestination(icon: const FaIcon(FontAwesomeIcons.user, size: 20), label: L10n.tr('tab_profile')),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final role = AuthState.currentUser?.role ?? UserRole.user;

    // ── Web : sidebar + contenu (professionnel) ──────────────────────
    if (PlatformUI.shouldUseWebLayout(context)) {
      return WebShell(
        currentIndex: _currentIndex,
        onTabSelected: _onTabSelected,
        pages: _pages,
        isLoggedIn: _isLoggedIn,
      );
    }

    // ── Mobile : bottom navigation premium floating ───────────────────
    final destinations = _getDestinations(role);
    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: _PremiumBottomNav(
        currentIndex: _currentIndex,
        destinations: destinations,
        onTap: (index) {
          _onTabSelected(index);
          if (!_isLoggedIn && mounted) {
            final ctx = context; // capture before async gap
            Future.delayed(const Duration(milliseconds: 300), () {
              // ignore: use_build_context_synchronously
              if (mounted) AuthPromptDialog.show(context: ctx);
            });
          }
        },
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// PREMIUM FLOATING BOTTOM NAV
// ════════════════════════════════════════════════════════════════════════════
class _PremiumBottomNav extends StatelessWidget {
  final int currentIndex;
  final List<NavigationDestination> destinations;
  final ValueChanged<int> onTap;

  const _PremiumBottomNav({
    required this.currentIndex,
    required this.destinations,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final count = destinations.length;
    final sw = MediaQuery.of(context).size.width - 32; // largeur nette (marges 16*2)
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        height: 68,
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.22), blurRadius: 20, offset: const Offset(0, 8)),
            BoxShadow(color: AppTheme.primaryGreen.withOpacity(0.07), blurRadius: 36, offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          children: List.generate(count, (i) {
            final dest = destinations[i];
            final active = i == currentIndex;
            final itemW = sw / count;
            return SizedBox(
              width: itemW,
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  onTap(i);
                },
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 7),
                  decoration: BoxDecoration(
                    color: active ? AppTheme.primaryGreen.withOpacity(0.13) : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AnimatedScale(
                            scale: active ? 1.12 : 1.0,
                            duration: const Duration(milliseconds: 200),
                            child: active
                              ? ShaderMask(
                                  shaderCallback: (b) => const LinearGradient(colors: [AppTheme.primaryGreen, AppTheme.accentTeal]).createShader(b),
                                  child: IconTheme(data: const IconThemeData(color: Colors.white, size: 20), child: dest.icon),
                                )
                              : IconTheme(data: const IconThemeData(color: Color(0xFF64748B), size: 18), child: dest.icon),
                          ),
                          const SizedBox(height: 3),
                          AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 200),
                            style: active
                              ? GoogleFonts.outfit(fontSize: count > 4 ? 10.0 : 11.0, fontWeight: FontWeight.w800, color: AppTheme.primaryGreen)
                              : GoogleFonts.inter(fontSize: count > 4 ? 9.5 : 10.5, fontWeight: FontWeight.w500, color: const Color(0xFF64748B)),
                            child: Text(dest.label, overflow: TextOverflow.ellipsis, maxLines: 1),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
