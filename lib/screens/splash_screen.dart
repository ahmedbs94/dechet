import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math' as math;
import '../services/auth_service.dart';
import '../models/user_model.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _mainController;
  late AnimationController _particleController;
  late AnimationController _pulseController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    // Main logo animation
    _mainController = AnimationController(
      duration: const Duration(milliseconds: 1800),
      vsync: this,
    );

    _scaleAnimation = CurvedAnimation(
      parent: _mainController,
      curve: Curves.elasticOut,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
    );

    // Particle animations
    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    // Pulse animation for glow
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _mainController.forward();

    _checkSession();
  }

  Future<void> _checkSession() async {
    // Replaced fixed delay with logic that checks for existing session
    final stopwatch = Stopwatch()..start();

    final authService = AuthService();
    final result = await authService.getCurrentUserDetails();

    // Ensure we wait at least 3 seconds for the animation to look good
    final elapsed = stopwatch.elapsedMilliseconds;
    if (elapsed < 3000) {
      await Future.delayed(Duration(milliseconds: 3000 - elapsed));
    }

    if (!mounted) return;

    if (result['success']) {
      final userData = result['user'];
      final userRoleStr = userData['role'] as String;

      UserRole role = UserRole.values.firstWhere(
        (e) => e.toString().split('.').last == userRoleStr,
        orElse: () => UserRole.user,
      );

      AuthState.currentUser = User(
        id: userData['id'].toString(),
        name: userData['full_name'] ?? 'Utilisateur',
        email: userData['email'],
        role: role,
        avatarUrl: userData['avatar_url'] ?? 'https://i.pravatar.cc/300?u=${userData['email']}',
      );

      Navigator.pushReplacementNamed(context, '/home');
    } else {
      // Pour les nouveaux visiteurs, on affiche la page Marketing ultra-attractive
      AuthState.currentUser = null;
      Navigator.pushReplacementNamed(context, '/marketing');
    }
  }

  @override
  void dispose() {
    _mainController.dispose();
    _particleController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF10B981), // Green
              Color(0xFF06B6D4), // Cyan
              Color(0xFF6366F1), // Purple
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            // Animated Wave Background
            ...List.generate(3, (index) {
              return Positioned(
                bottom: -100 - (index * 50),
                left: -50,
                right: -50,
                child: AnimatedBuilder(
                  animation: _particleController,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(
                        math.sin(_particleController.value * 2 * math.pi + index) * 30,
                        0,
                      ),
                      child: Opacity(
                        opacity: 0.1 - (index * 0.03),
                        child: Container(
                          height: 300 + (index * 100),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(300),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              );
            }),

            // Floating Particles
            ...List.generate(20, (index) {
              return AnimatedBuilder(
                animation: _particleController,
                builder: (context, child) {
                  final angle = (index * 18.0) + (_particleController.value * 360);
                  final distance = 100 + (index % 4) * 40;
                  final x = (size.width > 0 ? size.width : 400) / 2 + math.cos(angle * math.pi / 180) * distance;
                  final y = (size.height > 0 ? size.height : 800) / 2 + math.sin(angle * math.pi / 180) * distance;

                  return Positioned(
                    left: x,
                    top: y,
                    child: Container(
                      width: 4 + (index % 3) * 2,
                      height: 4 + (index % 3) * 2,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.4),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.white.withOpacity(0.3),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            }),

            // Main Content
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo with Glow and 3D Effect
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      // Pulsing Glow
                      AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, child) {
                          return Container(
                            width: 220 + (_pulseController.value * 40),
                            height: 220 + (_pulseController.value * 40),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.white.withOpacity(0.3 * (1 - _pulseController.value)),
                                  blurRadius: 80,
                                  spreadRadius: 20,
                                ),
                              ],
                            ),
                          );
                        },
                      ),

                      // Logo Container with Scale Animation
                      ScaleTransition(
                        scale: _scaleAnimation,
                        child: FadeTransition(
                          opacity: _fadeAnimation,
                          child: Container(
                            width: 200,
                            height: 200,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withOpacity(0.15),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.3),
                                width: 2,
                              ),
                            ),
                            padding: const EdgeInsets.all(24),
                            child: Image.asset(
                              'assets/images/splash_logo_3d.png',
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) {
                                return const Icon(
                                  Icons.recycling_rounded,
                                  size: 100,
                                  color: Colors.white,
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 48),

                  // App Name with Shimmer
                  ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [Colors.white, Colors.white70, Colors.white],
                    ).createShader(bounds),
                    child: Text(
                      'TriDéchet',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 56,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -2,
                        height: 1,
                      ),
                    ),
                  )
                      .animate(onPlay: (c) => c.repeat())
                      .shimmer(
                        delay: 800.ms,
                        duration: 2.seconds,
                        color: Colors.white.withOpacity(0.5),
                      )
                      .animate()
                      .fadeIn(delay: 400.ms, duration: 600.ms)
                      .slideY(begin: 0.3, end: 0, curve: Curves.easeOut),

                  const SizedBox(height: 16),

                  // Tagline
                  Text(
                    'L\'avenir du recyclage',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withOpacity(0.95),
                      letterSpacing: 0.5,
                    ),
                  ).animate().fadeIn(delay: 700.ms, duration: 600.ms).slideY(begin: 0.2, end: 0),

                  const SizedBox(height: 20),

                  // Premium Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.3),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 20,
                        ),
                      ],
                    ),
                    child: const SizedBox.shrink(),
                  ).animate().fadeIn(delay: 1000.ms).scale(delay: 1000.ms, duration: 400.ms, curve: Curves.easeOutBack),

                  const SizedBox(height: 80),

                  // Loading Indicator with custom design
                  SizedBox(
                    width: 60,
                    height: 60,
                    child: Stack(
                      children: [
                        // Outer ring
                        SizedBox(
                          width: 60,
                          height: 60,
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white.withOpacity(0.3),
                            ),
                            strokeWidth: 2,
                            strokeCap: StrokeCap.round,
                          ),
                        ),
                        // Inner ring
                        const Center(
                          child: SizedBox(
                            width: 46,
                            height: 46,
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                              strokeWidth: 3,
                              strokeCap: StrokeCap.round,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(delay: 1400.ms, duration: 400.ms),

                  const SizedBox(height: 20),

                  // Loading text
                  Text(
                    'Chargement...',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withOpacity(0.9),
                      letterSpacing: 0.5,
                    ),
                  )
                      .animate(onPlay: (c) => c.repeat())
                      .fadeIn(duration: 1.seconds)
                      .then()
                      .fadeOut(duration: 1.seconds)
                      .animate()
                      .fadeIn(delay: 1600.ms),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
