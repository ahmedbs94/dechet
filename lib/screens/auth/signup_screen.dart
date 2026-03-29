import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../services/auth_service.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({Key? key}) : super(key: key);

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> with SingleTickerProviderStateMixin {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _dobController = TextEditingController();
  final _authService = AuthService();

  bool _acceptTerms = false;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  String? _errorMessage;
  DateTime? _selectedDate;
  late AnimationController _bgController;

  // Progress tracker
  int get _filledFields {
    int count = 0;
    if (_nameController.text.trim().isNotEmpty) count++;
    if (_emailController.text.trim().isNotEmpty) count++;
    if (_phoneController.text.trim().isNotEmpty) count++;
    if (_dobController.text.trim().isNotEmpty) count++;
    if (_passwordController.text.trim().isNotEmpty) count++;
    if (_confirmPasswordController.text.trim().isNotEmpty) count++;
    return count;
  }

  @override
  void initState() {
    super.initState();
    _bgController = AnimationController(vsync: this, duration: const Duration(seconds: 10))..repeat(reverse: true);
    // Listen for changes to update progress
    for (var c in [_nameController, _emailController, _phoneController, _dobController, _passwordController, _confirmPasswordController]) {
      c.addListener(() { if (mounted) setState(() {}); });
    }
  }

  @override
  void dispose() {
    _bgController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _dobController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppTheme.primaryGreen,
              onPrimary: Colors.white,
              surface: Color(0xFF1a1a2e),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _dobController.text = "${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}";
      });
    }
  }

  Future<void> _handleSignUp() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'Veuillez remplir tous les champs obligatoires');
      return;
    }
    if (password.length < 6) {
      setState(() => _errorMessage = 'Le mot de passe doit contenir au moins 6 caractères');
      return;
    }
    if (password != confirmPassword) {
      setState(() => _errorMessage = 'Les mots de passe ne correspondent pas');
      return;
    }
    if (!_acceptTerms) {
      setState(() => _errorMessage = 'Veuillez accepter les conditions d\'utilisation');
      return;
    }

    setState(() { _isLoading = true; _errorMessage = null; });

    try {
      final result = await _authService.register(email, name, password);

      if (!mounted) return;

      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Compte créé avec succès !', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
            backgroundColor: AppTheme.primaryGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        Navigator.pop(context);
      } else {
        setState(() => _errorMessage = result['message'] ?? 'Erreur lors de l\'inscription');
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'Erreur de connexion. Vérifiez votre réseau.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = _filledFields / 6;
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Stack(
        children: [
          // ── Animated dark background ──
          AnimatedBuilder(
            animation: _bgController,
            builder: (context, child) {
              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                    colors: [
                      Color.lerp(const Color(0xFF0F172A), const Color(0xFF0A3D2E), _bgController.value)!,
                      Color.lerp(const Color(0xFF1a1a2e), const Color(0xFF0F172A), _bgController.value)!,
                    ],
                  ),
                ),
              );
            },
          ),

          // ── Background image ──
          Positioned.fill(
            child: Opacity(
              opacity: 0.08,
              child: Image.network(
                'https://images.unsplash.com/photo-1532996122724-e3c354a0b15b?w=800&q=60',
                fit: BoxFit.cover,
                errorBuilder: (c, e, s) => const SizedBox.shrink(),
              ),
            ),
          ),

          // ── Floating orbs ──
          Positioned(
            top: -100, left: -80,
            child: Animate(
              onPlay: (c) => c.repeat(reverse: true),
              effects: [MoveEffect(end: const Offset(30, 30), duration: 7.seconds)],
              child: Container(width: 280, height: 280, decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [AppTheme.accentTeal.withOpacity(0.12), Colors.transparent]))),
            ),
          ),
          Positioned(
            bottom: -80, right: -60,
            child: Animate(
              onPlay: (c) => c.repeat(reverse: true),
              effects: [MoveEffect(end: const Offset(-20, -20), duration: 9.seconds)],
              child: Container(width: 220, height: 220, decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [AppTheme.primaryGreen.withOpacity(0.1), Colors.transparent]))),
            ),
          ),

          // ── Main content ──
          SafeArea(
            child: Column(
              children: [
                // ── Top bar ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.white.withOpacity(0.1)),
                          ),
                          child: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: Colors.white.withOpacity(0.8)),
                        ),
                      ).animate().fadeIn().slideX(begin: -0.2, end: 0),
                      const Spacer(),
                      // Progress indicator
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withOpacity(0.1)),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          SizedBox(
                            width: 18, height: 18,
                            child: CircularProgressIndicator(
                              value: progress,
                              strokeWidth: 2.5,
                              backgroundColor: Colors.white.withOpacity(0.1),
                              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryGreen),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text('$_filledFields/6', style: GoogleFonts.inter(color: Colors.white.withOpacity(0.6), fontSize: 12, fontWeight: FontWeight.w700)),
                        ]),
                      ).animate().fadeIn(delay: 200.ms),
                    ],
                  ),
                ),

                // ── Scrollable form ──
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Title ──
                        ShaderMask(
                          shaderCallback: (bounds) => const LinearGradient(colors: [Colors.white, Color(0xFF86EFAC)]).createShader(bounds),
                          child: Text('Rejoignez le\nMouvement', style: GoogleFonts.spaceGrotesk(fontSize: 36, fontWeight: FontWeight.w900, color: Colors.white, height: 1.1, letterSpacing: -1)),
                        ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.1, end: 0),

                        const SizedBox(height: 8),
                        Text('Créez votre compte et commencez à changer le monde', style: GoogleFonts.inter(color: Colors.white.withOpacity(0.5), fontSize: 14)).animate().fadeIn(delay: 200.ms),

                        const SizedBox(height: 32),

                        // ── Form card ──
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.07),
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(color: Colors.white.withOpacity(0.1)),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 40, offset: const Offset(0, 20))],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Error
                              if (_errorMessage != null) ...[
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: Colors.red.withOpacity(0.2)),
                                  ),
                                  child: Row(children: [
                                    Icon(Icons.error_outline, color: Colors.red.shade300, size: 18),
                                    const SizedBox(width: 10),
                                    Expanded(child: Text(_errorMessage!, style: GoogleFonts.inter(color: Colors.red.shade300, fontSize: 12))),
                                  ]),
                                ).animate().shakeX(hz: 3, amount: 4, duration: 300.ms),
                                const SizedBox(height: 16),
                              ],

                              _buildField(controller: _nameController, label: 'Nom complet', icon: Icons.person_outline_rounded).animate().fadeIn(delay: 300.ms).slideX(begin: -0.03, end: 0),
                              const SizedBox(height: 14),
                              _buildField(controller: _emailController, label: 'Email', icon: Icons.alternate_email_rounded, keyboardType: TextInputType.emailAddress).animate().fadeIn(delay: 350.ms).slideX(begin: -0.03, end: 0),
                              const SizedBox(height: 14),
                              _buildField(controller: _phoneController, label: 'Téléphone', icon: Icons.phone_iphone_rounded, prefix: '+216 ', keyboardType: TextInputType.phone).animate().fadeIn(delay: 400.ms).slideX(begin: -0.03, end: 0),
                              const SizedBox(height: 14),
                              _buildField(controller: _dobController, label: 'Date de naissance', icon: Icons.calendar_today_rounded, readOnly: true, onTap: () => _selectDate(context)).animate().fadeIn(delay: 450.ms).slideX(begin: -0.03, end: 0),
                              const SizedBox(height: 14),
                              _buildField(
                                controller: _passwordController, label: 'Mot de passe', icon: Icons.lock_outline_rounded, obscure: _obscurePassword,
                                suffixIcon: IconButton(icon: Icon(_obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 18, color: Colors.white.withOpacity(0.4)), onPressed: () => setState(() => _obscurePassword = !_obscurePassword)),
                              ).animate().fadeIn(delay: 500.ms).slideX(begin: -0.03, end: 0),
                              const SizedBox(height: 14),
                              _buildField(
                                controller: _confirmPasswordController, label: 'Confirmer le mot de passe', icon: Icons.lock_reset_rounded, obscure: _obscureConfirm,
                                suffixIcon: IconButton(icon: Icon(_obscureConfirm ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 18, color: Colors.white.withOpacity(0.4)), onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm)),
                              ).animate().fadeIn(delay: 550.ms).slideX(begin: -0.03, end: 0),

                              const SizedBox(height: 24),

                              // Terms
                              GestureDetector(
                                onTap: () => setState(() => _acceptTerms = !_acceptTerms),
                                child: Row(children: [
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    width: 22, height: 22,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(7),
                                      gradient: _acceptTerms ? const LinearGradient(colors: [AppTheme.primaryGreen, AppTheme.accentTeal]) : null,
                                      color: _acceptTerms ? null : Colors.transparent,
                                      border: Border.all(color: _acceptTerms ? Colors.transparent : Colors.white.withOpacity(0.2), width: 2),
                                    ),
                                    child: _acceptTerms ? const Icon(Icons.check_rounded, size: 14, color: Colors.white) : null,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(child: Text('J\'accepte les conditions d\'utilisation de TriDéchet', style: GoogleFonts.inter(fontSize: 12, color: Colors.white.withOpacity(0.5)))),
                                ]),
                              ).animate().fadeIn(delay: 600.ms),

                              const SizedBox(height: 28),

                              // Submit button
                              Animate(
                                onPlay: (c) => c.repeat(reverse: true),
                                effects: [ShimmerEffect(delay: 3.seconds, duration: 2.seconds, color: Colors.white10)],
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(18),
                                    gradient: _acceptTerms ? const LinearGradient(colors: [AppTheme.primaryGreen, AppTheme.accentTeal]) : null,
                                    color: _acceptTerms ? null : Colors.white.withOpacity(0.1),
                                    boxShadow: _acceptTerms ? [BoxShadow(color: AppTheme.primaryGreen.withOpacity(0.35), blurRadius: 20, offset: const Offset(0, 8))] : null,
                                  ),
                                  child: ElevatedButton(
                                    onPressed: (_acceptTerms && !_isLoading) ? _handleSignUp : null,
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 18),
                                      backgroundColor: Colors.transparent,
                                      shadowColor: Colors.transparent,
                                      disabledBackgroundColor: Colors.transparent,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                                    ),
                                    child: _isLoading
                                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
                                        : Text('CRÉER MON COMPTE', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 14, color: _acceptTerms ? Colors.white : Colors.white.withOpacity(0.3))),
                                  ),
                                ),
                              ).animate().fadeIn(delay: 700.ms).slideY(begin: 0.05, end: 0),
                            ],
                          ),
                        ).animate().fadeIn(delay: 250.ms, duration: 600.ms).slideY(begin: 0.04, end: 0),

                        const SizedBox(height: 24),

                        // Login link
                        Center(
                          child: TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: RichText(text: TextSpan(
                              text: 'Déjà un compte ? ',
                              style: GoogleFonts.inter(color: Colors.white.withOpacity(0.5), fontSize: 13),
                              children: [TextSpan(text: 'Se connecter', style: GoogleFonts.outfit(color: AppTheme.primaryGreen, fontWeight: FontWeight.w900))],
                            )),
                          ),
                        ).animate().fadeIn(delay: 800.ms),
                      ],
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

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscure = false,
    bool readOnly = false,
    VoidCallback? onTap,
    String? prefix,
    TextInputType? keyboardType,
    Widget? suffixIcon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        readOnly: readOnly,
        onTap: onTap,
        keyboardType: keyboardType,
        style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 14),
        cursorColor: AppTheme.primaryGreen,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.inter(color: Colors.white.withOpacity(0.4), fontSize: 13),
          prefixIcon: Icon(icon, size: 20, color: AppTheme.primaryGreen.withOpacity(0.7)),
          prefixText: prefix,
          prefixStyle: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600),
          suffixIcon: suffixIcon,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
          floatingLabelStyle: GoogleFonts.inter(color: AppTheme.primaryGreen, fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
