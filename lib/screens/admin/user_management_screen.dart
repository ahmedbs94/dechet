import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({Key? key}) : super(key: key);

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final AuthService _authService = AuthService();
  List<dynamic> _users = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      final users = await _authService.getAllUsers();
      if (mounted) {
        setState(() {
          _users = users;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Erreur de connexion au serveur: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _showUserDialog({Map<String, dynamic>? user}) {
    final isEditing = user != null;
    final emailController = TextEditingController(text: user?['email']);
    final nameController = TextEditingController(text: user?['full_name']);
    final passwordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    String selectedRole = user?['role'] ?? 'user';
    String? errorMessage;

    final currentUserRole = AuthState.currentUser?.role;
    final isSuperAdmin = currentUserRole == UserRole.superadmin;
    final availableRoles = isSuperAdmin
        ? ['user', 'admin', 'superadmin', 'educator', 'pointManager', 'collector', 'intercommunality']
        : ['user', 'educator', 'pointManager', 'collector', 'intercommunality'];

    if (isEditing && !availableRoles.contains(selectedRole)) {
      availableRoles.add(selectedRole);
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final screenH = MediaQuery.of(context).size.height;
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
            contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
            actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            title: Text(
              isEditing ? 'Modifier Utilisateur' : 'Nouvel Utilisateur',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 20),
            ),
            content: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: screenH * 0.62, // jamais plus de 62% de l'écran
                minWidth: double.maxFinite,
              ),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 4),

                    // Erreur
                    if (errorMessage != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Row(children: [
                          Icon(Icons.error_outline_rounded, color: Colors.red.shade400, size: 18),
                          const SizedBox(width: 8),
                          Expanded(child: Text(errorMessage!, style: GoogleFonts.inter(fontSize: 12, color: Colors.red.shade700))),
                        ]),
                      ),

                    // Email
                    if (!isEditing) ...[
                      TextField(
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: 'Email',
                          hintText: 'exemple@gmail.com',
                          prefixIcon: const Icon(Icons.email_outlined, size: 20),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Nom complet
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: 'Nom complet',
                        prefixIcon: const Icon(Icons.person_outline_rounded, size: 20),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Rôle
                    DropdownButtonFormField<String>(
                      value: selectedRole,
                      isExpanded: true,
                      items: availableRoles
                          .map((role) => DropdownMenuItem(
                                value: role,
                                child: Text(
                                  _getRoleLabel(role).toUpperCase(),
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(fontSize: 13),
                                ),
                              ))
                          .toList(),
                      onChanged: (value) => selectedRole = value!,
                      decoration: InputDecoration(
                        labelText: 'Rôle',
                        prefixIcon: const Icon(Icons.badge_outlined, size: 20),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Mot de passe
                    TextField(
                      controller: passwordController,
                      decoration: InputDecoration(
                        labelText: isEditing ? 'Nouveau mot de passe' : 'Mot de passe',
                        helperText: isEditing ? 'Laisser vide pour garder l\'actuel' : null,
                        helperStyle: GoogleFonts.inter(fontSize: 10),
                        prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      ),
                      obscureText: true,
                    ),
                    const SizedBox(height: 12),

                    // Confirmation mot de passe
                    TextField(
                      controller: confirmPasswordController,
                      decoration: InputDecoration(
                        labelText: 'Confirmer le mot de passe',
                        prefixIcon: const Icon(Icons.lock_rounded, size: 20),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      ),
                      obscureText: true,
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Annuler'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryGreen,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                onPressed: () {
                  // Validation de l'email
                  if (!isEditing) {
                    final email = emailController.text.trim();
                    final emailRegex = RegExp(r'^[\w\.\-]+@[\w\.\-]+\.\w{2,}$');
                    if (email.isEmpty || !emailRegex.hasMatch(email)) {
                      setDialogState(() => errorMessage = 'Veuillez entrer un email valide (ex: nom@gmail.com)');
                      return;
                    }
                  }

                  // Validation du nom
                  if (nameController.text.trim().isEmpty) {
                    setDialogState(() => errorMessage = 'Le nom complet est requis');
                    return;
                  }

                  // Validation du mot de passe
                  final pwd = passwordController.text;
                  final confirmPwd = confirmPasswordController.text;

                  if (!isEditing && pwd.isEmpty) {
                    setDialogState(() => errorMessage = 'Le mot de passe est requis');
                    return;
                  }

                  if (pwd.isNotEmpty && pwd.length < 6) {
                    setDialogState(() => errorMessage = 'Le mot de passe doit contenir au moins 6 caractères');
                    return;
                  }

                  if (pwd.isNotEmpty && pwd != confirmPwd) {
                    setDialogState(() => errorMessage = 'Les mots de passe ne correspondent pas');
                    return;
                  }

                  Navigator.pop(context);
                  _processUser(
                    isEditing: isEditing,
                    userId: user?['id'],
                    email: emailController.text.trim(),
                    name: nameController.text.trim(),
                    role: selectedRole,
                    password: pwd,
                  );
                },
                child: Text(
                  isEditing ? 'Sauvegarder' : 'Créer',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _processUser({
    required bool isEditing,
    int? userId,
    required String email,
    required String name,
    required String role,
    required String password,
  }) async {
    if (!isEditing && (email.isEmpty || password.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Email et mot de passe requis')));
      return;
    }

    setState(() => _isLoading = true);
    Map<String, dynamic> result;

    if (isEditing) {
      result = await _authService.updateUserAdmin(
        userId: userId!,
        fullName: name,
        role: role,
        password: password.isNotEmpty ? password : null,
      );
    } else {
      result = await _authService.createUserAdmin(
        email: email,
        fullName: name,
        role: role,
        password: password,
      );
    }

    if (result['success']) {
      await _loadUsers();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Succès ! Utilisateur enregistré sur le serveur.'), backgroundColor: Colors.green),
      );
    } else {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Erreur Serveur'),
          content: Text(
              'L\'utilisateur n\'a pas pu être créé sur le serveur : ${result['message']}\n\nNote : En mode démo, les changements ne sont pas persistés.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Compris')),
          ],
        ),
      );
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteUser(int userId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmer la suppression'),
        content: const Text('Voulez-vous vraiment supprimer cet utilisateur ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Supprimer', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      final success = await _authService.deleteUserAdmin(userId);
      if (success) {
        await _loadUsers();
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Erreur : Impossible de supprimer sur le serveur. Suppression annulée.'),
          backgroundColor: Colors.red,
        ));
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen))
          : _errorMessage != null
              ? Center(child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.cloud_off_rounded, size: 60, color: Colors.grey.shade300),
                    const SizedBox(height: 16),
                    Text(_errorMessage!, style: GoogleFonts.inter(color: AppTheme.textMuted), textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _loadUsers,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Réessayer'),
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGreen),
                    ),
                  ]),
                ))
              : _users.isEmpty
                  ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.people_outline_rounded, size: 60, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      Text('Aucun utilisateur trouvé', style: GoogleFonts.outfit(fontSize: 16, color: AppTheme.textMuted)),
                    ]))
                  : RefreshIndicator(
                      onRefresh: _loadUsers,
                      color: AppTheme.primaryGreen,
                      child: ListView.builder(
                        padding: const EdgeInsets.only(top: 16, bottom: 100),
                        itemCount: _users.length,
                        itemBuilder: (context, index) {
                          final user = _users[index];
                          final roleColor = _getRoleColor(user['role'] ?? 'user');
                          final userName = user['full_name'] ?? 'Sans nom';
                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surface,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: Theme.of(context).brightness == Brightness.dark ? [] : AppTheme.tightShadow,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 52,
                                  height: 52,
                                  decoration: BoxDecoration(
                                    color: roleColor.withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      userName.isNotEmpty ? userName[0].toUpperCase() : '?',
                                      style: TextStyle(color: roleColor, fontWeight: FontWeight.bold, fontSize: 20),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        userName,
                                        style: GoogleFonts.outfit(
                                            fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.titleLarge?.color ?? AppTheme.deepSlate, fontSize: 16),
                                      ),
                                      Text(user['email'] ?? '', style: GoogleFonts.inter(fontSize: 12, color: Theme.of(context).textTheme.bodyMedium?.color ?? AppTheme.textMuted)),
                                      const SizedBox(height: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: roleColor.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: roleColor.withOpacity(0.2)),
                                        ),
                                        child: Text(
                                          _getRoleLabel(user['role'] ?? 'user').toUpperCase(),
                                          style: TextStyle(
                                              fontSize: 10, fontWeight: FontWeight.w900, color: roleColor, letterSpacing: 0.5),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (AuthState.currentUser?.role == UserRole.superadmin ||
                                    (user['role'] != 'admin' && user['role'] != 'superadmin'))
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        onPressed: () => _showUserDialog(user: user),
                                        icon: const Icon(Icons.edit_outlined, color: Colors.blue),
                                        tooltip: 'Modifier',
                                      ),
                                      IconButton(
                                        onPressed: () => _deleteUser(user['id']),
                                        icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                                        tooltip: 'Supprimer',
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_user_management_add',
        onPressed: () => _showUserDialog(),
        backgroundColor: AppTheme.primaryGreen,
        icon: const Icon(Icons.person_add_rounded),
        label: Text("AJOUTER", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
      ),
    );
  }

  String _getRoleLabel(String role) {
    switch (role) {
      case 'superadmin':
        return 'Super Administrateur';
      case 'admin':
        return 'Administrateur';
      case 'educator':
        return 'Éducateur';
      case 'pointManager':
        return 'Gestionnaire';
      case 'collector':
        return 'Collecteur';
      case 'intercommunality':
        return 'Intercommunalité';
      case 'user':
        return 'Citoyen (User)';
      default:
        return role;
    }
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'superadmin':
        return Colors.deepPurple;
      case 'admin':
        return Colors.red;
      case 'educator':
        return Colors.orange;
      case 'pointManager':
        return Colors.purple;
      case 'collector':
        return Colors.brown;
      case 'intercommunality':
        return Colors.blue;
      case 'user':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
}
