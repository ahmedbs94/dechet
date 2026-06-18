import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../widgets/premium_widgets.dart';
import '../../widgets/web_back_button.dart';

class PersonalInfoScreen extends StatefulWidget {
  const PersonalInfoScreen({Key? key}) : super(key: key);

  @override
  State<PersonalInfoScreen> createState() => _PersonalInfoScreenState();
}

class _PersonalInfoScreenState extends State<PersonalInfoScreen> {
  final AuthService _authService = AuthService();
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: AuthState.currentUser?.name ?? '');
    _emailController = TextEditingController(text: AuthState.currentUser?.email ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final newName = _nameController.text.trim();
    if (newName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Le nom ne peut pas être vide'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isSaving = true);
    final res = await _authService.updateProfile(fullName: newName);
    setState(() => _isSaving = false);

    if (!mounted) return;

    if (res['success'] == true) {
      // Mettre à jour le cache local AuthState
      final u = AuthState.currentUser;
      if (u != null) {
        AuthState.currentUser = User(
          id: u.id,
          name: res['full_name'] ?? newName,
          email: u.email,
          role: u.role,
          points: u.points,
          globalScore: u.globalScore,
          avatarUrl: u.avatarUrl,
          qrCode: u.qrCode,
        );
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Text('Nom mis à jour : ${res['full_name'] ?? newName}',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          ]),
          backgroundColor: AppTheme.primaryGreen,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message'] ?? 'Erreur lors de la mise à jour'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Informations personnelles',
          style: GoogleFonts.spaceGrotesk(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: webLeading(IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: Theme.of(context).colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        )),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            _buildTextField('Nom complet', _nameController, Icons.person_outline, editable: true),
            const SizedBox(height: 16),
            _buildTextField('Email', _emailController, Icons.email_outlined, editable: false,
              hint: 'L\'email ne peut pas être modifié'),
            const SizedBox(height: 32),
            _isSaving
                ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen))
                : PremiumButton(
                    text: 'ENREGISTRER',
                    onPressed: _save,
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, IconData icon,
      {bool editable = true, String? hint}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          enabled: editable,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: editable ? AppTheme.primaryGreen : Colors.grey),
            filled: true,
            fillColor: Theme.of(context).brightness == Brightness.dark
                ? (editable ? Theme.of(context).colorScheme.surface : Theme.of(context).colorScheme.surface.withOpacity(0.5))
                : (editable ? Colors.white : Colors.grey.shade100),
            hintText: hint,
            hintStyle: GoogleFonts.inter(fontSize: 12, color: Theme.of(context).hintColor),
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
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }
}
