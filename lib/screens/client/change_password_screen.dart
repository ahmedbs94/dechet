import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/premium_widgets.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({Key? key}) : super(key: key);

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _oldPassController = TextEditingController();
  final _newPassController = TextEditingController();
  final _confirmPassController = TextEditingController();
  final AuthService _authService = AuthService();
  bool _isLoading = false;

  void _handleChangePassword() async {
    final oldPass = _oldPassController.text.trim();
    final newPass = _newPassController.text.trim();
    final confirmPass = _confirmPassController.text.trim();

    if (oldPass.isEmpty || newPass.isEmpty || confirmPass.isEmpty) {
      _showCustomSnackBar('Veuillez remplir tous les champs', isError: true);
      return;
    }

    if (newPass != confirmPass) {
      _showCustomSnackBar('Les nouveaux mots de passe ne sont pas identiques', isError: true);
      return;
    }

    if (newPass.length < 6) {
      _showCustomSnackBar('Le nouveau mot de passe doit contenir au moins 6 caractères', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    final result = await _authService.changePassword(oldPass, newPass);

    setState(() => _isLoading = false);

    if (result['success']) {
      if (!mounted) return;
      _showCustomSnackBar('Mot de passe mis à jour avec succès', isError: false);
      Navigator.pop(context);
    } else {
      if (!mounted) return;
      String errorMessage = result['message'] ?? 'Erreur lors de la mise à jour';

      // Traduction des erreurs techniques du backend
      if (errorMessage == "Ancien mot de passe incorrect") {
        errorMessage = "Le mot de passe actuel est invalide";
      } else if (errorMessage == "Could not validate credentials") {
        errorMessage = "Votre session a expiré. Veuillez vous reconnecter.";
      }

      _showCustomSnackBar(errorMessage, isError: true);
    }
  }

  void _showCustomSnackBar(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.manrope(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: isError ? AppTheme.errorRed : AppTheme.primaryGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Changer le mot de passe',
          style: GoogleFonts.spaceGrotesk(
            color: AppTheme.deepNavy,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.deepNavy),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            _buildTextField('Ancien mot de passe', _oldPassController, true),
            const SizedBox(height: 16),
            _buildTextField('Nouveau mot de passe', _newPassController, true),
            const SizedBox(height: 16),
            _buildTextField('Confirmer le mot de passe', _confirmPassController, true),
            const SizedBox(height: 32),
            if (_isLoading)
              const CircularProgressIndicator()
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

  Widget _buildTextField(String label, TextEditingController controller, bool isPassword) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppTheme.deepNavy,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: isPassword,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.lock_outline, color: AppTheme.primaryGreen),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.primaryGreen, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}
