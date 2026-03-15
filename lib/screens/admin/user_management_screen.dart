import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
  final List<dynamic> _mockUsers = [
    {'id': 1, 'full_name': 'Amine T.', 'email': 'amine@example.com', 'role': 'user'},
    {'id': 2, 'full_name': 'Sarah B.', 'email': 'sarah@example.com', 'role': 'user'},
    {'id': 3, 'full_name': 'Me. Amel', 'email': 'amel@tridechet.tn', 'role': 'educator'},
    {'id': 4, 'full_name': 'Eco-Collect TN', 'email': 'contact@ecocollect.tn', 'role': 'collector'},
    {'id': 5, 'full_name': 'Sami G.', 'email': 'sami@tridechet.tn', 'role': 'pointManager'},
    {'id': 6, 'full_name': 'Admin EcoRewind', 'email': 'admin@tridechet.tn', 'role': 'admin'},
    {'id': 7, 'full_name': 'Grand Tunis', 'email': 'contact@tunis.gov.tn', 'role': 'intercommunality'},
  ];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    try {
      final users = await _authService.getAllUsers();
      setState(() {
        _users = users;
        _isLoading = false;

        // Si le serveur ne renvoie rien (vraiment 0, même pas l'admin courant),
        // alors on utilise les données de test pour ne pas avoir un écran vide
        if (_users.isEmpty) {
          _users = List.from(_mockUsers);
        }
      });
    } catch (e) {
      setState(() {
        _users = List.from(_mockUsers);
        _isLoading = false;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Attention: Erreur de connexion au serveur. Mode Démo activé.'),
        backgroundColor: Colors.orange,
      ));
    }
  }

  void _showUserDialog({Map<String, dynamic>? user}) {
    final isEditing = user != null;
    final emailController = TextEditingController(text: user?['email']);
    final nameController = TextEditingController(text: user?['full_name']);
    final passwordController = TextEditingController(); // Vide par défaut
    String selectedRole = user?['role'] ?? 'user';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEditing ? 'Modifier Utilisateur' : 'Nouvel Utilisateur'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!isEditing) // L'email ne change pas généralement
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Nom complet'),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: selectedRole,
                items: ['user', 'admin', 'educator', 'pointManager', 'collector', 'intercommunality']
                    .map((role) => DropdownMenuItem(
                          value: role,
                          child: Text(_getRoleLabel(role).toUpperCase()),
                        ))
                    .toList(),
                onChanged: (value) => selectedRole = value!,
                decoration: const InputDecoration(labelText: 'Rôle'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: passwordController,
                decoration: InputDecoration(
                  labelText: isEditing ? 'Nouveau mot de passe (laisser vide pour garder)' : 'Mot de passe',
                  helperText: 'L\'admin attribue le mot de passe ici',
                ),
                obscureText: true,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              _processUser(
                isEditing: isEditing,
                userId: user?['id'],
                email: emailController.text,
                name: nameController.text,
                role: selectedRole,
                password: passwordController.text,
              );
            },
            child: Text(isEditing ? 'Sauvegarder' : 'Créer'),
          ),
        ],
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
      backgroundColor: AppTheme.backgroundSoft,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.only(top: 16, bottom: 100),
              itemCount: _users.length,
              itemBuilder: (context, index) {
                final user = _users[index];
                final roleColor = _getRoleColor(user['role']);
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: AppTheme.tightShadow,
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
                            user['role'][0].toUpperCase(),
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
                              user['full_name'] ?? 'Sans nom',
                              style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.bold, color: AppTheme.deepSlate, fontSize: 16),
                            ),
                            Text(user['email'], style: const TextStyle(fontSize: 12)),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: roleColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: roleColor.withOpacity(0.2)),
                              ),
                              child: Text(
                                _getRoleLabel(user['role']).toUpperCase(),
                                style: TextStyle(
                                    fontSize: 10, fontWeight: FontWeight.w900, color: roleColor, letterSpacing: 0.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GestureDetector(
                            onTap: () => _showUserDialog(user: user),
                            child: const Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Icon(Icons.edit_outlined, color: Colors.blue),
                            ),
                          ),
                          GestureDetector(
                            onTap: () => _deleteUser(user['id']),
                            child: const Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Icon(Icons.delete_outline_rounded, color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showUserDialog(),
        backgroundColor: AppTheme.primaryGreen,
        icon: const Icon(Icons.person_add_rounded),
        label: Text("Utilisateur", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
      ),
    );
  }

  String _getRoleLabel(String role) {
    switch (role) {
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
