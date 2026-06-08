import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'theme/app_theme.dart';
import 'theme/platform_ui.dart';
import 'theme/web_theme.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/signup_screen.dart';
import 'screens/auth/onboarding_screen.dart';
import 'screens/auth/marketing_landing_screen.dart';
import 'screens/auth/section_how_it_works.dart';
import 'screens/auth/section_impact.dart';
import 'screens/auth/section_testimonials.dart';
import 'screens/auth/section_advantages.dart';
import 'screens/client/client_home.dart';
import 'screens/admin/admin_dashboard.dart';

import 'screens/client/sorting_guide_screen.dart';
import 'screens/client/bin_scanner_screen.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'models/post_model.dart';
import 'models/user_model.dart';
import 'services/auth_service.dart';
import 'services/l10n_service.dart';

import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await L10n.init();

  // ── Initialisation Firebase (Score temps réel — QR Poubelle) ──────────────
  // DefaultFirebaseOptions fournit la config correcte selon la plateforme
  // (Web, Android, iOS). Si le Web App ID n'est pas encore configuré,
  // Firebase est ignoré silencieusement (app continue en mode dégradé).
  try {
    final webAppId = DefaultFirebaseOptions.web.appId;
    final webReady = !webAppId.contains('REMPLACER');
    if (!kIsWeb || webReady) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } else {
      debugPrint('[Firebase] Web App ID non configuré → mode dégradé (pas de RTDB temps réel)');
    }
  } catch (e) {
    debugPrint('[Firebase] Initialisation échouée : $e');
  }

  // Initialiser le SDK Facebook pour le web
  if (kIsWeb) {
    await FacebookAuth.i.webAndDesktopInitialize(
      appId: "1420513346522756",
      cookie: true,
      xfbml: true,
      version: "v18.0",
    );
  }
  
  await PostRegistry.loadSavedStates();

  // ── Restauration de session (reload navigateur / cold start) ──────────────
  // Lire le token JWT sauvegardé et reconstruire AuthState.currentUser AVANT
  // que Flutter rende la première route. Sans cela, un reload sur /#/home
  // trouvait AuthState.currentUser == null et affichait le dialog de connexion.
  await _restoreSessionIfAvailable();

  runApp(const EcoRewindApp());
}

/// Restaure la session utilisateur depuis SharedPreferences.
/// Appelé une seule fois au démarrage, avant runApp().
Future<void> _restoreSessionIfAvailable() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    if (token == null) return; // Pas de session sauvegardée

    // Mettre le token en mémoire pour les requêtes HTTP
    AuthState.authToken = token;

    // Vérifier que le token est encore valide côté backend
    final authService = AuthService();
    final result = await authService.getCurrentUserDetails();

    if (result['success'] == true) {
      final userData = result['user'] as Map<String, dynamic>;
      final roleStr = userData['role'] as String? ?? 'user';
      final role = UserRole.values.firstWhere(
        (e) => e.toString().split('.').last == roleStr,
        orElse: () => UserRole.user,
      );
      AuthState.currentUser = User(
        id: userData['id'].toString(),
        name: userData['full_name'] ?? 'Utilisateur',
        email: userData['email'] ?? '',
        role: role,
        globalScore: (userData['global_score'] as num?)?.toDouble() ?? 0.0,
        avatarUrl: userData['avatar_url'] ?? '',
        qrCode: userData['qr_code'] ?? '',
      );
      debugPrint('[Session] Restaurée : ${AuthState.currentUser?.name}');
    } else {
      if (result['message']?.toString().contains('Erreur réseau') == true || result['message']?.toString().contains('Erreur serveur') == true) {
        debugPrint('[Session] Erreur réseau ignorée. Décodage local du token en fallback.');
        try {
          final parts = token.split('.');
          if (parts.length == 3) {
            final payload = parts[1];
            final normalized = base64Url.normalize(payload);
            final resp = utf8.decode(base64Url.decode(normalized));
            final payloadData = json.decode(resp);
            
            final roleStr = payloadData['role'] as String? ?? 'user';
            final role = UserRole.values.firstWhere(
              (e) => e.toString().split('.').last == roleStr,
              orElse: () => UserRole.user,
            );
            
            AuthState.currentUser = User(
              id: payloadData['id']?.toString() ?? '0',
              name: payloadData['full_name'] ?? payloadData['sub'] ?? 'Utilisateur (Hors ligne)',
              email: payloadData['sub'] ?? '',
              role: role,
            );
            debugPrint('[Session] Fallback local réussi pour : ${AuthState.currentUser?.email}');
          }
        } catch (e) {
          debugPrint('[Session] Échec du fallback local : $e');
        }
      } else {
        // Token expiré ou invalide → nettoyer
        AuthState.authToken = null;
        AuthState.currentUser = null;
        await prefs.remove('jwt_token');
        await prefs.remove('refresh_token');
        debugPrint('[Session] Token invalide, session effacée');
      }
    }
  } catch (e) {
    debugPrint('[Session] Erreur restauration : $e');
  }
}

class EcoRewindApp extends StatelessWidget {
  const EcoRewindApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EcoRewind',
      debugShowCheckedModeBanner: false,
      theme: PlatformUI.isWeb ? WebTheme.theme : AppTheme.seniorTheme,
      initialRoute: '/',
      onGenerateRoute: (settings) {
        // ─── Sur Web : pas d'historique Flutter — Chrome gère Retour/Avancer ───
        // Sur Mobile : MaterialPageRoute classique avec animation
        Route<T> buildRoute<T>(WidgetBuilder builder, {bool fullscreen = false}) {
          if (kIsWeb) {
            return PageRouteBuilder<T>(
              settings: settings,
              pageBuilder: (context, _, __) => builder(context),
              transitionDuration: Duration.zero,
              reverseTransitionDuration: Duration.zero,
            );
          }
          return MaterialPageRoute<T>(
            settings: settings,
            builder: builder,
            fullscreenDialog: fullscreen,
          );
        }

        // ─── Routes d'onglets : chaque onglet = sa propre route ──────────────
        Route<dynamic> tabRoute(int tabIndex) => PageRouteBuilder(
              settings: settings,
              pageBuilder: (context, _, __) =>
                  MainNavigationShell(initialTab: tabIndex),
              transitionDuration: Duration.zero,
              reverseTransitionDuration: Duration.zero,
            );

        switch (settings.name) {
          case '/home':
          case '/feed':
            final args = settings.arguments as Map<String, dynamic>?;
            final initialTab = args?['initialTab'] as int? ?? 0;
            return tabRoute(initialTab);
          case '/multimedia':
            return tabRoute(1);
          case '/rewards':
            return tabRoute(2);
          case '/map':
            return tabRoute(3);
          case '/community':
            return tabRoute(4);
          case '/profile':
            final role = AuthState.currentUser?.role ?? UserRole.user;
            final profileIdx = role == UserRole.educator ? 2 : (role == UserRole.user ? 5 : 4);
            return tabRoute(profileIdx);

          // ─── Routes statiques ─────────────────────────────────────────────
          case '/':
          case '/marketing':
            return buildRoute((_) => const MarketingLandingScreen());
          case '/onboarding':
            return buildRoute((_) => const OnboardingScreen());
          case '/login':
            return buildRoute((_) => const LoginScreen());
          case '/signup':
            return buildRoute((_) => const SignUpScreen());
          case '/admin':
            return buildRoute((_) => const AdminDashboardScreen());

          case '/guide':
            return buildRoute((_) => const SortingGuideScreen());
          case '/how-it-works':
            return buildRoute((_) => const SectionHowItWorks());
          case '/impact':
            return buildRoute((_) => const SectionImpact());
          case '/testimonials':
            return buildRoute((_) => const SectionTestimonials());
          case '/advantages':
            return buildRoute((_) => const SectionAdvantages());
          case '/bin-scanner':
            return buildRoute((_) => const BinScannerScreen(), fullscreen: true);
        }

        return null;
      },
    );
  }
}
