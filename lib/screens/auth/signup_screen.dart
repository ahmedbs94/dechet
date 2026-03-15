import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({Key? key}) : super(key: key);

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _dobController = TextEditingController();
  
  bool _acceptTerms = false;
  DateTime? _selectedDate;

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: AppTheme.seniorTheme.copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppTheme.primaryGreen,
              onPrimary: Colors.white,
              onSurface: AppTheme.textMain,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _dobController.text = "${picked.day}/${picked.month}/${picked.year}";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      body: Stack(
        children: [
          // Premium Background Accents
          Positioned(
            top: -100,
            left: -100,
            child: Animate(
              onPlay: (c) => c.repeat(reverse: true),
              effects: [FadeEffect(duration: 2.seconds), ScaleEffect(end: const Offset(1.1, 1.1), duration: 5.seconds)],
              child: Container(
                width: 350,
                height: 350,
                decoration: BoxDecoration(shape: BoxShape.circle, color: AppTheme.primaryGreen.withOpacity(0.04)),
              ),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Animate(
                    effects: [FadeEffect(), SlideEffect(begin: const Offset(-0.5, 0))],
                    child: Container(
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
                      child: IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  Animate(
                    effects: [FadeEffect(delay: 200.ms), SlideEffect(begin: const Offset(0, 0.1))],
                    child: Text(
                      'Rejoindre l\'Élite',
                      style: GoogleFonts.outfit(fontSize: 36, fontWeight: FontWeight.bold, color: AppTheme.deepSlate),
                    ),
                  ),
                  Animate(
                    effects: [FadeEffect(delay: 300.ms)],
                    child: Text('Créez votre profil éco-responsable pour la Tunisie.', style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 16)),
                  ),
                  
                  const SizedBox(height: 48),
                  
                  Animate(
                    effects: [FadeEffect(delay: 400.ms), SlideEffect(begin: const Offset(0, 0.1))],
                    child: GlassCard(
                      opacity: 0.9,
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildField('NOM COMPLET', _nameController, Icons.person_outline_rounded),
                          const SizedBox(height: 20),
                          _buildField('EMAIL', _emailController, Icons.alternate_email_rounded),
                          const SizedBox(height: 20),
                          _buildField('TÉLÉPHONE', _phoneController, Icons.phone_iphone_rounded, prefix: '+216 '),
                          const SizedBox(height: 20),
                          _buildField('DATE DE NAISSANCE', _dobController, Icons.calendar_today_rounded, readOnly: true, onTap: () => _selectDate(context)),
                          const SizedBox(height: 20),
                          _buildField('MOT DE PASSE', _passwordController, Icons.lock_outline_rounded, obscure: true),
                          const SizedBox(height: 20),
                          _buildField('CONFIRMATION', _confirmPasswordController, Icons.lock_reset_rounded, obscure: true),
                          
                          const SizedBox(height: 32),
                          Row(
                            children: [
                              Checkbox(
                                value: _acceptTerms,
                                activeColor: AppTheme.primaryGreen,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                onChanged: (v) => setState(() => _acceptTerms = v!),
                              ),
                              Expanded(
                                child: Text('J\'accepte les conditions de EcoRewind Tunisie.', style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMuted)),
                              ),
                            ],
                          ),
                          
                          const SizedBox(height: 40),
                          Animate(
                            onPlay: (c) => c.repeat(),
                            effects: [ShimmerEffect(delay: 3.seconds, duration: 2.seconds, color: Colors.white24)],
                            child: ElevatedButton(
                              onPressed: _acceptTerms ? () => Navigator.pop(context) : null,
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 20),
                                backgroundColor: AppTheme.primaryGreen,
                                shadowColor: AppTheme.primaryGreen.withOpacity(0.3),
                                elevation: 8,
                              ),
                              child: Text('CRÉER MON COMPTE', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 60),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildField(String label, TextEditingController controller, IconData icon, {bool obscure = false, bool readOnly = false, VoidCallback? onTap, String? prefix}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w900, color: AppTheme.primaryGreen, letterSpacing: 1.2)),
        const SizedBox(height: 10),
        TextField(
          controller: controller,
          obscureText: obscure,
          readOnly: readOnly,
          onTap: onTap,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, size: 20, color: AppTheme.primaryGreen),
            prefixText: prefix,
            prefixStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: AppTheme.deepSlate),
            contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
          ),
        ),
      ],
    );
  }
}
