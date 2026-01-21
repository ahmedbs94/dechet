import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/signup_screen.dart';
import 'screens/auth/onboarding_screen.dart';
import 'screens/client/client_home.dart';
import 'screens/admin/admin_dashboard.dart';
import 'screens/client/waste_scanner_screen.dart';
import 'screens/client/sorting_guide_screen.dart';

void main() {
  runApp(const TriDechetApp());
}

class TriDechetApp extends StatelessWidget {
  const TriDechetApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TriDéchet',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.seniorTheme,
      initialRoute: '/onboarding',
      routes: {
        '/onboarding': (context) => const OnboardingScreen(),
        '/login': (context) => const LoginScreen(),
        '/signup': (context) => const SignUpScreen(),
        '/home': (context) => const MainNavigationShell(),
        '/admin': (context) => const AdminDashboardScreen(),
        '/scanner': (context) => const WasteScannerScreen(),
        '/guide': (context) => const SortingGuideScreen(),
      },
    );
  }
}
