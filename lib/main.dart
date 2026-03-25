import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
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
import 'screens/client/waste_scanner_screen.dart';
import 'screens/client/sorting_guide_screen.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'models/post_model.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
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
  runApp(const EcoRewindApp());
}

class EcoRewindApp extends StatelessWidget {
  const EcoRewindApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EcoRewind',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.seniorTheme,
      initialRoute: '/',
      onGenerateRoute: (settings) {
        // Handle /home route with optional initialTab argument
        if (settings.name == '/home') {
          final args = settings.arguments as Map<String, dynamic>?;
          final initialTab = args?['initialTab'] as int? ?? 0;
          return MaterialPageRoute(
            builder: (context) => MainNavigationShell(initialTab: initialTab),
            settings: settings,
          );
        }

        // Static routes
        final routes = <String, WidgetBuilder>{
          '/': (context) => const MarketingLandingScreen(),
          '/marketing': (context) => const MarketingLandingScreen(),
          '/onboarding': (context) => const OnboardingScreen(),
          '/login': (context) => const LoginScreen(),
          '/signup': (context) => const SignUpScreen(),
          '/admin': (context) => const AdminDashboardScreen(),
          '/scanner': (context) => const WasteScannerScreen(),
          '/guide': (context) => const SortingGuideScreen(),
          '/how-it-works': (context) => const SectionHowItWorks(),
          '/impact': (context) => const SectionImpact(),
          '/testimonials': (context) => const SectionTestimonials(),
          '/advantages': (context) => const SectionAdvantages(),
        };

        final builder = routes[settings.name];
        if (builder != null) {
          return MaterialPageRoute(builder: builder, settings: settings);
        }
        return null;
      },
    );
  }
}
