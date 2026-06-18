import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/premium_widgets.dart';
import '../../widgets/web_back_button.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({Key? key}) : super(key: key);

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _oldPassController    = TextEditingController();
  final _newPassController    = TextEditingController();
  final _confirmPassController = TextEditingController();
  final AuthService _authService = AuthService();

  bool _isLoading      = false;
  bool _showOld        = false;
  bool _showNew        = false;
  bool _showConfirm    = false;

  // ── Indicateur de force ───────────────────────────────────────────
  int _strength = 0; // 0=rien, 1=faible, 2=moyen, 3=fort

  void _evalStrength(String p) {
    int s = 0;
    if (p.length >= 6) s++;
    if (RegExp(r'[A-Z]').hasMatch(p) && RegExp(r'[0-9]').hasMatch(p)) s++;
    if (p.length >= 12 && RegExp(r'[!@#\$&*~]').hasMatch(p)) s++;
    setState(() => _strength = p.isEmpty ? 0 : s + 1 > 3 ? 3 : s + 1);
  }

  String get _strengthLabel {
    switch (_strength) {
      case 1: return 'Faible';
      case 2: return 'Moyen';
      case 3: return 'Fort';
      default: return '';
    }
  }

  Color get _strengthColor {
    switch (_strength) {
      case 1: return Colors.red;
      case 2: return Colors.orange;
      case 3: return AppTheme.primaryGreen;
      default: return Colors.transparent;
    }
  }

  // ── Soumission ────────────────────────────────────────────────────
  void _handleChangePassword() async {
    final oldPass     = _oldPassController.text.trim();
    final newPass     = _newPassController.text.trim();
    final confirmPass = _confirmPassController.text.trim();

    if (oldPass.isEmpty || newPass.isEmpty || confirmPass.isEmpty) {
      _snack('Veuillez remplir tous les champs', isError: true);
      return;
    }
    if (newPass != confirmPass) {
      _snack('Les nouveaux mots de passe ne sont pas identiques', isError: true);
      return;
    }
    if (newPass.length < 6) {
      _snack('Le mot de passe doit contenir au moins 6 caractères', isError: true);
      return;
    }

    setState(() => _isLoading = true);
    final result = await _authService.changePassword(oldPass, newPass);
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result['success'] == true) {
      _snack('Mot de passe mis à jour avec succès ✓', isError: false);
      Navigator.pop(context);
    } else {
      String msg = result['message'] ?? 'Erreur lors de la mise à jour';
      if (msg == 'Ancien mot de passe incorrect') {
        msg = 'Le mot de passe actuel est invalide';
      } else if (msg == 'Could not validate credentials') {
        msg = 'Votre session a expiré. Veuillez vous reconnecter.';
      }
      _snack(msg, isError: true);
    }
  }

  void _snack(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Icon(isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
            color: Colors.white),
        const SizedBox(width: 12),
        Expanded(child: Text(message,
            style: GoogleFonts.inter(fontWeight: FontWeight.w600))),
      ]),
      backgroundColor: isError ? AppTheme.errorRed : AppTheme.primaryGreen,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 3),
    ));
  }

  // ── UI ────────────────────────────────────────────────────────────
  @override
  void dispose() {
    _oldPassController.dispose();
    _newPassController.dispose();
    _confirmPassController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final confirmPass = _confirmPassController.text;
    final newPass     = _newPassController.text;
    final mismatch    = confirmPass.isNotEmpty && confirmPass != newPass;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('Changer le mot de passe',
            style: GoogleFonts.spaceGrotesk(
                color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: webLeading(IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: Theme.of(context).colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        )),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Illustration ──
            Center(
              child: Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.lock_reset_rounded,
                    color: AppTheme.primaryGreen, size: 40),
              ),
            ),
            const SizedBox(height: 28),

            // ── Ancien MDP ──
            _fieldLabel('Mot de passe actuel'),
            const SizedBox(height: 8),
            _buildField(
              controller: _oldPassController,
              hint: '••••••••',
              show: _showOld,
              onToggle: () => setState(() => _showOld = !_showOld),
            ),
            const SizedBox(height: 20),

            // ── Nouveau MDP ──
            _fieldLabel('Nouveau mot de passe'),
            const SizedBox(height: 8),
            _buildField(
              controller: _newPassController,
              hint: 'Min. 6 caractères',
              show: _showNew,
              onToggle: () => setState(() => _showNew = !_showNew),
              onChanged: _evalStrength,
            ),
            // Barre de force
            if (_strength > 0) ...[
              const SizedBox(height: 8),
              _StrengthBar(strength: _strength, label: _strengthLabel, color: _strengthColor),
            ],
            const SizedBox(height: 20),

            // ── Confirmer MDP ──
            _fieldLabel('Confirmer le nouveau mot de passe'),
            const SizedBox(height: 8),
            _buildField(
              controller: _confirmPassController,
              hint: 'Identique au nouveau mot de passe',
              show: _showConfirm,
              onToggle: () => setState(() => _showConfirm = !_showConfirm),
              onChanged: (_) => setState(() {}),
              errorText: mismatch ? 'Les mots de passe ne correspondent pas' : null,
            ),
            const SizedBox(height: 36),

            // ── Bouton ──
            if (_isLoading)
              const Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen))
            else
              PremiumButton(
                text: 'METTRE À JOUR',
                onPressed: _handleChangePassword,
              ),
          ],
        ),
      ),
    );
  }

  Widget _fieldLabel(String label) => Text(label,
      style: GoogleFonts.inter(
          fontSize: 13, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSurface));

  Widget _buildField({
    required TextEditingController controller,
    required String hint,
    required bool show,
    required VoidCallback onToggle,
    ValueChanged<String>? onChanged,
    String? errorText,
  }) {
    return TextField(
      controller: controller,
      obscureText: !show,
      onChanged: onChanged,
      style: GoogleFonts.inter(fontSize: 15, color: Theme.of(context).colorScheme.onSurface),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 13),
        prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppTheme.primaryGreen, size: 20),
        suffixIcon: IconButton(
          icon: Icon(show ? Icons.visibility_off_rounded : Icons.visibility_rounded,
              color: AppTheme.textMuted, size: 20),
          onPressed: onToggle,
        ),
        errorText: errorText,
        errorStyle: GoogleFonts.inter(fontSize: 11, color: Colors.red),
        filled: true,
        fillColor: Theme.of(context).colorScheme.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Theme.of(context).dividerColor)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppTheme.primaryGreen, width: 2)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Colors.red)),
        focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Colors.red, width: 2)),
      ),
    );
  }
}

// ── Barre de force du mot de passe ───────────────────────────────────────────
class _StrengthBar extends StatelessWidget {
  final int strength;
  final String label;
  final Color color;

  const _StrengthBar({
    required this.strength,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ...List.generate(3, (i) => Expanded(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: 4,
            margin: EdgeInsets.only(right: i < 2 ? 4 : 0),
            decoration: BoxDecoration(
              color: i < strength ? color : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        )),
        const SizedBox(width: 10),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Text(
            label,
            key: ValueKey(label),
            style: GoogleFonts.inter(
                fontSize: 11, fontWeight: FontWeight.w700, color: color),
          ),
        ),
      ],
    );
  }
}
