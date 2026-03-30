import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../services/auth_service.dart';
import '../../models/user_model.dart';

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
  final _otpController = TextEditingController();
  final _authService = AuthService();

  bool _acceptTerms = false;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  String? _errorMessage;
  late AnimationController _bgController;

  // OTP Flow
  int _currentStep = 0; // 0=form, 1=otp, 2=success
  String _otpMethod = 'email'; // 'email' or 'sms'
  String _otpIdentifier = '';
  int _resendCountdown = 0;
  Timer? _resendTimer;

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
    _bgController = AnimationController(vsync: this, duration: const Duration(seconds: 20))..repeat(reverse: true);
    for (var c in [_nameController, _emailController, _phoneController, _passwordController, _confirmPasswordController, _dobController]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    _bgController.dispose();
    _resendTimer?.cancel();
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _dobController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(data: Theme.of(context).copyWith(colorScheme: const ColorScheme.light(primary: AppTheme.primaryGreen)), child: child!),
    );
    if (picked != null) setState(() => _dobController.text = '${picked.day}/${picked.month}/${picked.year}');
  }

  Future<void> _handleSignUp() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (name.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'Veuillez remplir le nom et le mot de passe');
      return;
    }
    if (email.isEmpty && phone.isEmpty) {
      setState(() => _errorMessage = 'Veuillez saisir un email ou un numéro de téléphone');
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
      final identifier = email.isNotEmpty ? email : '+216$phone';
      final result = await _authService.register(identifier, name, password);

      if (!mounted) return;

      if (result['success'] == true) {
        // Registration successful → send OTP
        _otpIdentifier = identifier;
        _otpMethod = email.isNotEmpty ? 'email' : 'sms';
        await _sendOTP();
        if (mounted) setState(() { _currentStep = 1; _isLoading = false; });
      } else {
        setState(() { _errorMessage = result['message']; _isLoading = false; });
      }
    } catch (e) {
      if (mounted) setState(() { _errorMessage = 'Erreur inattendue'; _isLoading = false; });
    }
  }

  Future<void> _sendOTP() async {
    final result = await _authService.sendOTP(_otpIdentifier, method: _otpMethod);
    if (result['success'] != true && mounted) {
      setState(() => _errorMessage = result['message']);
    }
    _startResendCountdown();
  }

  void _startResendCountdown() {
    _resendTimer?.cancel();
    setState(() => _resendCountdown = 60);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) { timer.cancel(); return; }
      setState(() {
        _resendCountdown--;
        if (_resendCountdown <= 0) timer.cancel();
      });
    });
  }

  Future<void> _verifyOTP() async {
    final code = _otpController.text.trim();
    if (code.isEmpty || code.length != 6) {
      setState(() => _errorMessage = 'Veuillez entrer le code à 6 chiffres');
      return;
    }

    setState(() { _isLoading = true; _errorMessage = null; });

    try {
      final result = await _authService.verifyOTP(_otpIdentifier, code);
      if (!mounted) return;

      if (result['success'] == true) {
        // Auto-login with the token from verification
        if (result['access_token'] != null) {
          await _authService.saveToken(result['access_token']);
          AuthState.loginFromBackend(result);
        }
        setState(() { _currentStep = 2; _isLoading = false; });

        // Navigate to home after 2 seconds
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
        });
      } else {
        setState(() { _errorMessage = result['message']; _isLoading = false; });
      }
    } catch (e) {
      if (mounted) setState(() { _errorMessage = 'Erreur de vérification'; _isLoading = false; });
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
                    begin: Alignment(-1 + _bgController.value * 0.5, -1), end: Alignment(1, 1 - _bgController.value * 0.3),
                    colors: const [Color(0xFF0F172A), Color(0xFF1B2838), Color(0xFF0F3D3E)],
                  ),
                ),
              );
            },
          ),

          // ── Floating orbs ──
          ..._buildOrbs(),

          // ── Main content ──
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),

                  // Back button
                  GestureDetector(
                    onTap: () {
                      if (_currentStep > 0 && _currentStep < 2) {
                        setState(() { _currentStep = 0; _errorMessage = null; });
                      } else {
                        Navigator.pop(context);
                      }
                    },
                    child: Row(children: [
                      Container(
                        padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.white.withOpacity(0.06), borderRadius: BorderRadius.circular(14)),
                        child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 16),
                      ),
                      const SizedBox(width: 12),
                      Text(_currentStep == 0 ? 'Retour' : 'Étape précédente', style: GoogleFonts.inter(color: Colors.white.withOpacity(0.5), fontSize: 13)),
                    ]),
                  ).animate().fadeIn(delay: 50.ms),

                  const SizedBox(height: 28),

                  // Step indicator
                  _buildStepIndicator().animate().fadeIn(delay: 80.ms),

                  const SizedBox(height: 24),

                  // ── Step content ──
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: SlideTransition(position: Tween<Offset>(begin: const Offset(0.05, 0), end: Offset.zero).animate(animation), child: child)),
                    child: _currentStep == 0
                        ? _buildFormStep(progress)
                        : _currentStep == 1
                            ? _buildOTPStep()
                            : _buildSuccessStep(),
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Step Indicator ──
  Widget _buildStepIndicator() {
    return Row(
      children: List.generate(3, (i) {
        final isActive = i == _currentStep;
        final isDone = i < _currentStep;
        final labels = ['Inscription', 'Vérification', 'Terminé'];
        return Expanded(
          child: Row(children: [
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: (isActive || isDone) ? const LinearGradient(colors: [AppTheme.primaryGreen, AppTheme.accentTeal]) : null,
                color: (isActive || isDone) ? null : Colors.white.withOpacity(0.08),
                border: Border.all(color: (isActive || isDone) ? Colors.transparent : Colors.white.withOpacity(0.1)),
              ),
              child: Center(child: isDone
                  ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
                  : Text('${i + 1}', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: (isActive || isDone) ? Colors.white : Colors.white.withOpacity(0.3)))),
            ),
            const SizedBox(width: 6),
            if (i < 2) Expanded(
              child: Container(height: 2, color: isDone ? AppTheme.primaryGreen : Colors.white.withOpacity(0.06)),
            ),
            if (i < 2) const SizedBox(width: 6),
            if (i == 2) Expanded(child: Text(labels[i], style: GoogleFonts.inter(fontSize: 10, color: isActive ? AppTheme.primaryGreen : Colors.white.withOpacity(0.3)))),
          ]),
        );
      }),
    );
  }

  // ── Step 0: Registration Form ──
  Widget _buildFormStep(double progress) {
    return Column(
      key: const ValueKey('form_step'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ShaderMask(
          shaderCallback: (r) => const LinearGradient(colors: [Colors.white, AppTheme.primaryGreen]).createShader(r),
          child: Text('Rejoignez le\nMouvement', style: GoogleFonts.spaceGrotesk(fontSize: 36, fontWeight: FontWeight.w900, color: Colors.white, height: 1.1, letterSpacing: -1)),
        ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.1, end: 0),

        const SizedBox(height: 8),
        Text('Créez votre compte et commencez à changer le monde', style: GoogleFonts.inter(color: Colors.white.withOpacity(0.5), fontSize: 14)).animate().fadeIn(delay: 200.ms),

        const SizedBox(height: 12),
        // Progress
        Row(children: [
          Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(10), child: LinearProgressIndicator(value: progress, minHeight: 4, backgroundColor: Colors.white.withOpacity(0.06), valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryGreen)))),
          const SizedBox(width: 12),
          Text('$_filledFields/6', style: GoogleFonts.outfit(color: AppTheme.primaryGreen, fontSize: 13, fontWeight: FontWeight.bold)),
        ]).animate().fadeIn(delay: 250.ms),

        const SizedBox(height: 24),

        // Form card
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.07),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 40, offset: const Offset(0, 20))],
          ),
          child: Column(
            children: [
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.red.withOpacity(0.2))),
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
              const SizedBox(height: 6),
              Center(child: Text('ou', style: GoogleFonts.inter(color: Colors.white.withOpacity(0.4), fontSize: 12))),
              const SizedBox(height: 6),
              _buildField(controller: _phoneController, label: 'Téléphone', icon: Icons.phone_iphone_rounded, prefix: '+216 ', keyboardType: TextInputType.phone).animate().fadeIn(delay: 400.ms).slideX(begin: -0.03, end: 0),
              const SizedBox(height: 14),
              _buildField(controller: _dobController, label: 'Date de naissance', icon: Icons.calendar_today_rounded, readOnly: true, onTap: () => _selectDate(context)).animate().fadeIn(delay: 450.ms).slideX(begin: -0.03, end: 0),
              const SizedBox(height: 14),
              _buildField(
                controller: _passwordController, label: 'Mot de passe', icon: Icons.lock_outline_rounded, obscure: _obscurePassword,
                suffixIcon: IconButton(icon: Icon(_obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 18, color: const Color(0xFF94A3B8)), onPressed: () => setState(() => _obscurePassword = !_obscurePassword)),
              ).animate().fadeIn(delay: 500.ms).slideX(begin: -0.03, end: 0),
              const SizedBox(height: 14),
              _buildField(
                controller: _confirmPasswordController, label: 'Confirmer le mot de passe', icon: Icons.lock_reset_rounded, obscure: _obscureConfirm,
                suffixIcon: IconButton(icon: Icon(_obscureConfirm ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 18, color: const Color(0xFF94A3B8)), onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm)),
              ).animate().fadeIn(delay: 550.ms).slideX(begin: -0.03, end: 0),

              const SizedBox(height: 24),

              // Terms
              GestureDetector(
                onTap: () => setState(() => _acceptTerms = !_acceptTerms),
                child: Row(children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200), width: 22, height: 22,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(7),
                      gradient: _acceptTerms ? const LinearGradient(colors: [AppTheme.primaryGreen, AppTheme.accentTeal]) : null,
                      color: _acceptTerms ? null : Colors.transparent,
                      border: Border.all(color: _acceptTerms ? Colors.transparent : Colors.white.withOpacity(0.2), width: 2),
                    ),
                    child: _acceptTerms ? const Icon(Icons.check_rounded, size: 14, color: Colors.white) : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text('J\'accepte les conditions d\'utilisation', style: GoogleFonts.inter(color: Colors.white.withOpacity(0.6), fontSize: 12))),
                ]),
              ).animate().fadeIn(delay: 600.ms),

              const SizedBox(height: 28),

              // Submit button
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: const LinearGradient(colors: [AppTheme.primaryGreen, AppTheme.accentTeal]),
                  boxShadow: [BoxShadow(color: AppTheme.primaryGreen.withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 6))],
                ),
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleSignUp,
                  style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 56), backgroundColor: Colors.transparent, shadowColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
                  child: _isLoading
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                      : Text('CONTINUER', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 14, color: Colors.white)),
                ),
              ).animate().fadeIn(delay: 650.ms).slideY(begin: 0.1, end: 0),

              const SizedBox(height: 20),
              Center(
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: RichText(text: TextSpan(children: [
                    TextSpan(text: 'Déjà un compte ? ', style: GoogleFonts.inter(color: Colors.white.withOpacity(0.4), fontSize: 13)),
                    TextSpan(text: 'Se connecter', style: GoogleFonts.inter(color: AppTheme.primaryGreen, fontWeight: FontWeight.w700, fontSize: 13)),
                  ])),
                ),
              ).animate().fadeIn(delay: 700.ms),
            ],
          ),
        ),
      ],
    );
  }

  // ── Step 1: OTP Verification ──
  Widget _buildOTPStep() {
    final isEmail = _otpMethod == 'email';
    return Column(
      key: const ValueKey('otp_step'),
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 20),
        // Icon
        Container(
          width: 80, height: 80,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [AppTheme.primaryGreen, AppTheme.accentTeal]),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [BoxShadow(color: AppTheme.primaryGreen.withOpacity(0.3), blurRadius: 24, offset: const Offset(0, 8))],
          ),
          child: Icon(isEmail ? Icons.mark_email_unread_rounded : Icons.sms_rounded, size: 36, color: Colors.white),
        ).animate().scale(delay: 100.ms, curve: Curves.elasticOut),

        const SizedBox(height: 28),
        Text('Vérifiez votre ${isEmail ? "email" : "téléphone"}', style: GoogleFonts.spaceGrotesk(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white)).animate().fadeIn(delay: 150.ms),

        const SizedBox(height: 12),
        Text(
          'Un code à 6 chiffres a été envoyé à',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(color: Colors.white.withOpacity(0.5), fontSize: 14),
        ).animate().fadeIn(delay: 200.ms),
        const SizedBox(height: 4),
        Text(_otpIdentifier, style: GoogleFonts.inter(color: AppTheme.primaryGreen, fontWeight: FontWeight.w700, fontSize: 15)).animate().fadeIn(delay: 250.ms),

        const SizedBox(height: 32),

        // OTP Input
        Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.07),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Column(
            children: [
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.red.withOpacity(0.2))),
                  child: Row(children: [
                    Icon(Icons.error_outline, color: Colors.red.shade300, size: 18),
                    const SizedBox(width: 10),
                    Expanded(child: Text(_errorMessage!, style: GoogleFonts.inter(color: Colors.red.shade300, fontSize: 12))),
                  ]),
                ).animate().shakeX(hz: 3, amount: 4, duration: 300.ms),
                const SizedBox(height: 16),
              ],

              // Code input field
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: TextField(
                  controller: _otpController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  maxLength: 6,
                  style: GoogleFonts.spaceGrotesk(fontSize: 32, fontWeight: FontWeight.w900, color: const Color(0xFF1E293B), letterSpacing: 12),
                  cursorColor: AppTheme.primaryGreen,
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: '• • • • • •',
                    hintStyle: GoogleFonts.inter(color: const Color(0xFFCBD5E1), fontSize: 24, letterSpacing: 8),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
                  ),
                ),
              ).animate().fadeIn(delay: 300.ms).scale(begin: const Offset(0.95, 0.95)),

              const SizedBox(height: 8),
              Text('Le code expire dans 5 minutes', style: GoogleFonts.inter(color: Colors.white.withOpacity(0.3), fontSize: 11)),

              const SizedBox(height: 28),

              // Verify button
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: const LinearGradient(colors: [AppTheme.primaryGreen, AppTheme.accentTeal]),
                  boxShadow: [BoxShadow(color: AppTheme.primaryGreen.withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 6))],
                ),
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _verifyOTP,
                  style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 56), backgroundColor: Colors.transparent, shadowColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
                  child: _isLoading
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                      : Text('VÉRIFIER LE CODE', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 14, color: Colors.white)),
                ),
              ).animate().fadeIn(delay: 350.ms),

              const SizedBox(height: 20),

              // Resend
              GestureDetector(
                onTap: _resendCountdown > 0 ? null : () async {
                  setState(() => _errorMessage = null);
                  await _sendOTP();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('Nouveau code envoyé !', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                      backgroundColor: AppTheme.primaryGreen,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ));
                  }
                },
                child: Text(
                  _resendCountdown > 0 ? 'Renvoyer dans ${_resendCountdown}s' : 'Renvoyer le code',
                  style: GoogleFonts.inter(
                    color: _resendCountdown > 0 ? Colors.white.withOpacity(0.3) : AppTheme.primaryGreen,
                    fontWeight: FontWeight.w600, fontSize: 13,
                  ),
                ),
              ).animate().fadeIn(delay: 400.ms),
            ],
          ),
        ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.05),
      ],
    );
  }

  // ── Step 2: Success ──
  Widget _buildSuccessStep() {
    return Column(
      key: const ValueKey('success_step'),
      children: [
        const SizedBox(height: 60),
        Container(
          width: 100, height: 100,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [AppTheme.primaryGreen, AppTheme.accentTeal]),
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: AppTheme.primaryGreen.withOpacity(0.4), blurRadius: 32, offset: const Offset(0, 12))],
          ),
          child: const Icon(Icons.check_rounded, size: 48, color: Colors.white),
        ).animate().scale(delay: 100.ms, duration: 600.ms, curve: Curves.elasticOut),

        const SizedBox(height: 32),
        Text('Bienvenue !', style: GoogleFonts.spaceGrotesk(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.white)).animate().fadeIn(delay: 300.ms),

        const SizedBox(height: 12),
        Text('Votre compte a été vérifié avec succès.\nRedirection en cours...', textAlign: TextAlign.center, style: GoogleFonts.inter(color: Colors.white.withOpacity(0.5), fontSize: 15, height: 1.6)).animate().fadeIn(delay: 400.ms),

        const SizedBox(height: 40),
        const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2.5, color: AppTheme.primaryGreen)).animate().fadeIn(delay: 600.ms),
      ],
    );
  }

  // ── Orbs ──
  List<Widget> _buildOrbs() {
    return [
      Positioned(top: -80, right: -60, child: Container(width: 200, height: 200, decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [AppTheme.primaryGreen.withOpacity(0.08), Colors.transparent])))),
      Positioned(bottom: 100, left: -80, child: Container(width: 250, height: 250, decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [AppTheme.accentTeal.withOpacity(0.06), Colors.transparent])))),
    ];
  }

  // ── Reusable field ──
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.15)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        readOnly: readOnly,
        onTap: onTap,
        keyboardType: keyboardType,
        style: GoogleFonts.inter(color: const Color(0xFF1E293B), fontWeight: FontWeight.w500, fontSize: 14),
        cursorColor: AppTheme.primaryGreen,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 13),
          prefixIcon: Icon(icon, size: 20, color: AppTheme.primaryGreen),
          prefixText: prefix,
          prefixStyle: GoogleFonts.inter(color: const Color(0xFF1E293B), fontWeight: FontWeight.w600),
          suffixIcon: suffixIcon,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
          floatingLabelStyle: GoogleFonts.inter(color: AppTheme.primaryGreen, fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
