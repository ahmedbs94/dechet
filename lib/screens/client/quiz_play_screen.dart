import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../services/auth_service.dart';
import '../../models/user_model.dart';


/// Écran interactif pour répondre à un quiz (Citoyen)
/// Le citoyen répond question par question, puis Gemini corrige et donne une note /10
class QuizPlayScreen extends StatefulWidget {
  final Map<String, dynamic> quiz;
  const QuizPlayScreen({Key? key, required this.quiz}) : super(key: key);

  @override
  State<QuizPlayScreen> createState() => _QuizPlayScreenState();
}

class _QuizPlayScreenState extends State<QuizPlayScreen> {
  final AuthService _authService = AuthService();
  int _currentQuestion = 0;
  final Map<String, String> _answers = {};
  bool _isSubmitting = false;
  Map<String, dynamic>? _result;

  List<dynamic> get _questions => (widget.quiz['questions'] as List?) ?? [];
  int get _total => _questions.length;

  void _selectAnswer(String answer) {
    setState(() {
      _answers['${_currentQuestion + 1}'] = answer;
    });
  }

  void _nextQuestion() {
    if (_currentQuestion < _total - 1) {
      setState(() => _currentQuestion++);
    }
  }

  void _prevQuestion() {
    if (_currentQuestion > 0) {
      setState(() => _currentQuestion--);
    }
  }

  Future<void> _submitQuiz() async {
    setState(() => _isSubmitting = true);

    final quizId = widget.quiz['id'];
    final res = await _authService.submitQuizAnswers(quizId, _answers);

    if (mounted) {
      setState(() {
        _isSubmitting = false;
        if (res['success'] == true) {
          _result = res['grading'] ?? res;
          // Mettre à jour le score global local
          final newGlobalScore = (res['global_score'] as num?)?.toDouble();
          if (newGlobalScore != null && AuthState.currentUser != null) {
            final u = AuthState.currentUser!;
            AuthState.currentUser = User(
              id: u.id,
              name: u.name,
              email: u.email,
              role: u.role,
              points: u.points,
              globalScore: newGlobalScore,
              avatarUrl: u.avatarUrl,
              qrCode: u.qrCode,
            );
          }
        }
      });

      if (res['success'] != true) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(res['message'] ?? 'Erreur lors de la correction'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_result != null) return _buildResultScreen();
    if (_questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Quiz')),
        body: const Center(child: Text('Aucune question dans ce quiz')),
      );
    }
    
    return Stack(
      children: [
        _buildQuizScreen(),
        if (_isSubmitting) _buildLoadingOverlay(),
      ],
    );
  }

  Widget _buildLoadingOverlay() {
    return Positioned.fill(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutCubic,
        builder: (context, value, child) {
          return BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20 * value, sigmaY: 20 * value),
            child: Container(
              color: const Color(0xFF0B1120).withOpacity(0.85 * value),
              child: Opacity(
                opacity: value,
                child: child,
              ),
            ),
          );
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animated AI Brain / Sparkle
            Container(
              width: 120, height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.deepPurpleAccent.withOpacity(0.15),
                border: Border.all(color: Colors.deepPurpleAccent.withOpacity(0.3), width: 2),
                boxShadow: [
                  BoxShadow(color: Colors.deepPurpleAccent.withOpacity(0.6), blurRadius: 60, spreadRadius: 10),
                  BoxShadow(color: const Color(0xFF00E676).withOpacity(0.2), blurRadius: 40, spreadRadius: -5), // subtle green mix
                ],
              ),
              child: const Center(
                child: Icon(Icons.auto_awesome, color: Colors.white, size: 50),
              ),
            ).animate(onPlay: (controller) => controller.repeat(reverse: true))
             .scale(begin: const Offset(0.9, 0.9), end: const Offset(1.1, 1.1), duration: 1.5.seconds, curve: Curves.easeInOutQuart)
             .shimmer(color: Colors.white.withOpacity(0.8), duration: 2.seconds),
             
            const SizedBox(height: 50),
            
            Text('Analyse en cours', 
              style: GoogleFonts.outfit(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w900, letterSpacing: -1))
              .animate().fadeIn(duration: 800.ms).slideY(begin: 0.2),
              
            const SizedBox(height: 16),
            
            Text('Veuillez patienter...',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: Colors.white.withOpacity(0.7), fontSize: 18, height: 1.6, fontWeight: FontWeight.w500))
              .animate().fadeIn(delay: 300.ms),
              
            const SizedBox(height: 50),
            
            // Custom pulsing line
            Container(
              width: 200, height: 4,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: Colors.white.withOpacity(0.1),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: const LinearProgressIndicator(
                  backgroundColor: Colors.transparent,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.deepPurpleAccent),
                ),
              ),
            ).animate().fadeIn(delay: 600.ms),
          ],
        ),
      ),
    );
  }

  Widget _buildQuizScreen() {
    final q = _questions[_currentQuestion];
    final qText = q['question'] ?? '';
    final qType = q['type'] ?? 'mcq';
    final options = (q['options'] as List?)?.cast<String>() ?? [];
    final currentAnswer = _answers['${_currentQuestion + 1}'];
    final progress = (_currentQuestion + 1) / _total;

    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      body: Stack(
        children: [
          // Background floating elements for WOW effect
          Positioned(
            top: -50,
            left: -50,
            child: Container(
              width: 200, height: 200,
              decoration: BoxDecoration(shape: BoxShape.circle, color: AppTheme.primaryGreen.withOpacity(0.15)),
            ),
          ),
          Positioned(
            bottom: 100,
            right: -80,
            child: Container(
              width: 250, height: 250,
              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.purple.withOpacity(0.1)),
            ),
          ),
          Positioned.fill(child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50), child: Container(color: Colors.transparent))),

          SafeArea(
            child: Column(
              children: [
                // Custom App Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.arrow_back_ios_new_rounded, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : AppTheme.deepSlate),
                        onPressed: () => _showExitDialog(),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E293B).withOpacity(0.8) : Colors.white.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
                          border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF334155) : Colors.white, width: 2),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.psychology_alt_rounded, size: 18, color: AppTheme.primaryGreen),
                            const SizedBox(width: 8),
                            Text('Question ${_currentQuestion + 1} sur $_total',
                              style: GoogleFonts.outfit(color: AppTheme.primaryGreen, fontWeight: FontWeight.w800, fontSize: 14)),
                          ],
                        ),
                      ),
                      const Spacer(),
                      const SizedBox(width: 48), // Balance for back button
                    ],
                  ),
                ),

                // Progress line
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E293B) : Colors.grey.shade200,
                      valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryGreen),
                      minHeight: 6,
                    ),
                  ),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Question Card (Glassmorphism)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(32),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(32),
                              decoration: BoxDecoration(
                                color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E293B).withOpacity(0.7) : Colors.white.withOpacity(0.7),
                                borderRadius: BorderRadius.circular(32),
                                border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF334155).withOpacity(0.5) : Colors.white.withOpacity(0.5), width: 2),
                                boxShadow: AppTheme.premiumShadow,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(qText,
                                    style: GoogleFonts.outfit(fontSize: 26, fontWeight: FontWeight.w800, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : AppTheme.deepSlate, height: 1.3, letterSpacing: -0.5)),
                                ],
                              ),
                            ),
                          ),
                        ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.1),
                        
                        const SizedBox(height: 40),

                        // Options
                        if (qType == 'mcq' || qType == 'true_false')
                          ...options.asMap().entries.map((entry) {
                            final idx = entry.key;
                            final option = entry.value;
                            final letter = option.length > 1 ? option.split('.')[0].trim() : String.fromCharCode(65 + idx);
                            final isSelected = currentAnswer == letter;

                            return GestureDetector(
                              onTap: () => _selectAnswer(letter),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 400),
                                curve: Curves.easeOutQuart,
                                margin: const EdgeInsets.only(bottom: 16),
                                padding: EdgeInsets.all(isSelected ? 24 : 20),
                                decoration: BoxDecoration(
                                  gradient: isSelected 
                                      ? const LinearGradient(colors: [AppTheme.primaryGreen, Color(0xFF00D2A8)]) 
                                      : LinearGradient(colors: [Theme.of(context).colorScheme.surface, Theme.of(context).colorScheme.surface]),
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(
                                    color: isSelected ? Colors.transparent : (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF334155) : Colors.grey.shade200),
                                    width: 2,
                                  ),
                                  boxShadow: isSelected
                                      ? [BoxShadow(color: AppTheme.primaryGreen.withOpacity(0.4), blurRadius: 24, offset: const Offset(0, 10))]
                                      : [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 4))],
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 48, height: 48,
                                      decoration: BoxDecoration(
                                        color: isSelected ? Colors.white.withOpacity(0.25) : Colors.white.withOpacity(0.12),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Center(
                                        child: Text(letter,
                                          style: GoogleFonts.outfit(
                                            color: isSelected ? Colors.white : AppTheme.textMuted,
                                            fontWeight: FontWeight.w900, fontSize: 18)),
                                      ),
                                    ),
                                    const SizedBox(width: 20),
                                    Expanded(
                                      child: Text(option,
                                        style: GoogleFonts.inter(
                                          fontSize: 16, 
                                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                          color: isSelected ? Colors.white : (Theme.of(context).brightness == Brightness.dark ? Colors.white : AppTheme.deepSlate),
                                          height: 1.4)),
                                    ),
                                    if (isSelected)
                                      const Icon(Icons.check_circle_rounded, color: Colors.white, size: 32)
                                        .animate().scale(duration: 400.ms, curve: Curves.elasticOut),
                                  ],
                                ),
                              ),
                            ).animate().fadeIn(delay: Duration(milliseconds: 100 + (100 * idx))).slideX(begin: 0.1);
                          }),

                        // Open question
                        if (qType == 'open')
                          TextField(
                            onChanged: (val) => _answers['${_currentQuestion + 1}'] = val,
                            maxLines: 5,
                            style: GoogleFonts.inter(fontSize: 16, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : AppTheme.deepSlate),
                            decoration: InputDecoration(
                              hintText: 'Rédigez votre réponse détaillée ici...',
                              hintStyle: GoogleFonts.inter(color: AppTheme.textMuted),
                              filled: true,
                              fillColor: Theme.of(context).colorScheme.surface,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide(color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF334155) : Colors.grey.shade200, width: 2)),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide(color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF334155) : Colors.grey.shade200, width: 2)),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: AppTheme.primaryGreen, width: 2)),
                              contentPadding: const EdgeInsets.all(24),
                            ),
                          ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1),
                          
                        const SizedBox(height: 60), // Extra space
                      ],
                    ),
                  ),
                ),

                // Bottom Navigation Area
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
                      decoration: BoxDecoration(
                        color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E293B).withOpacity(0.85) : Colors.white.withOpacity(0.85),
                        border: Border(top: BorderSide(color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF334155).withOpacity(0.5) : Colors.white.withOpacity(0.5), width: 2)),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 30, offset: const Offset(0, -10))],
                      ),
                      child: Row(
                        children: [
                          if (_currentQuestion > 0)
                            Expanded(
                              flex: 1,
                              child: OutlinedButton(
                                onPressed: _prevQuestion,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.white60 : AppTheme.textMuted,
                                  padding: const EdgeInsets.symmetric(vertical: 22),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                                  side: BorderSide(color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF334155) : Colors.grey.shade300, width: 2),
                                ),
                                child: const Icon(Icons.arrow_back_rounded, size: 28),
                              ),
                            ),
                          if (_currentQuestion > 0) const SizedBox(width: 16),
                          Expanded(
                            flex: 3,
                            child: _currentQuestion < _total - 1
                                ? ElevatedButton(
                                    onPressed: currentAnswer != null ? _nextQuestion : null,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.primaryGreen,
                                      foregroundColor: Colors.white,
                                      disabledBackgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E293B) : Colors.grey.shade200,
                                      disabledForegroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.white30 : Colors.grey.shade400,
                                      padding: const EdgeInsets.symmetric(vertical: 22),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                                      elevation: currentAnswer != null ? 10 : 0,
                                      shadowColor: AppTheme.primaryGreen.withOpacity(0.5),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text('Étape Suivante', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w800)),
                                        const SizedBox(width: 8),
                                        const Icon(Icons.arrow_forward_rounded, size: 24),
                                      ],
                                    ),
                                  )
                                : ElevatedButton(
                                    onPressed: (_isSubmitting || currentAnswer == null) ? null : _submitQuiz,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.deepPurple,
                                      foregroundColor: Colors.white,
                                      disabledBackgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E293B) : Colors.grey.shade200,
                                      disabledForegroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.white30 : Colors.grey.shade400,
                                      padding: const EdgeInsets.symmetric(vertical: 22),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                                      elevation: currentAnswer != null ? 15 : 0,
                                      shadowColor: Colors.deepPurple.withOpacity(0.6),
                                    ),
                                    child: _isSubmitting
                                        ? const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white))
                                        : Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              const Icon(Icons.auto_awesome, size: 24),
                                              const SizedBox(width: 12),
                                              Text('Valider mes réponses', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w800)),
                                            ],
                                          ),
                                  ),
                          ),
                        ],
                      ),
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

  Widget _buildResultScreen() {
    final score = (_result!['score'] as num?)?.toDouble() ?? 0;
    final maxScore = (_result!['max_score'] as num?)?.toDouble() ?? 10;
    final totalCorrect = (_result!['total_correct'] as num?)?.toInt() ?? 0;
    final details = (_result!['details'] as List?) ?? [];
    final feedback = _result!['general_feedback'] ?? '';
    final percentage = (score / maxScore * 100).toInt();

    Color scoreColor;
    String emoji;
    String label;
    if (percentage >= 80) {
      scoreColor = const Color(0xFF00E676); // Bright neon green
      emoji = '🏆';
      label = 'Incroyable !';
    } else if (percentage >= 60) {
      scoreColor = const Color(0xFFFF9100); // Bright orange
      emoji = '👍';
      label = 'Bon travail !';
    } else if (percentage >= 40) {
      scoreColor = const Color(0xFFFF3D00); // Deep orange/red
      emoji = '💪';
      label = 'Sur la bonne voie';
    } else {
      scoreColor = const Color(0xFFFF1744); // Bright red
      emoji = '📚';
      label = 'Ne lâchez rien !';
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0B1120), // Ultra dark slate
      body: Stack(
        children: [
          // Dark mode glowing background
          Positioned(
            top: -100, left: -50,
            child: Container(
              width: 300, height: 300,
              decoration: BoxDecoration(shape: BoxShape.circle, color: scoreColor.withOpacity(0.15)),
            ),
          ),
          Positioned.fill(child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80), child: Container(color: Colors.transparent))),

          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 100, 24, 40),
                  child: Column(
                    children: [
                      // Animated glowing emoji
                      Container(
                        width: 120, height: 120,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white.withOpacity(0.1), width: 2),
                          boxShadow: [BoxShadow(color: scoreColor.withOpacity(0.3), blurRadius: 40, spreadRadius: 10)],
                        ),
                        child: Center(child: Text(emoji, style: const TextStyle(fontSize: 60))),
                      ).animate().scale(delay: 200.ms, curve: Curves.elasticOut),
                      
                      const SizedBox(height: 32),
                      
                      Text(label, style: GoogleFonts.outfit(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w900, letterSpacing: -1))
                          .animate().fadeIn(delay: 300.ms).slideY(begin: 0.2),
                          
                      const SizedBox(height: 32),
                      
                      // Score display
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.03),
                          borderRadius: BorderRadius.circular(32),
                          border: Border.all(color: scoreColor.withOpacity(0.5), width: 2),
                          boxShadow: [BoxShadow(color: scoreColor.withOpacity(0.1), blurRadius: 30)],
                        ),
                        child: Column(
                          children: [
                            Text('NOTE FINALE', style: GoogleFonts.outfit(color: Colors.white.withOpacity(0.5), fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 2)),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text(score.toStringAsFixed(1), style: GoogleFonts.outfit(color: Colors.white, fontSize: 64, fontWeight: FontWeight.w900, letterSpacing: -2)),
                                Text(' / ${maxScore.toStringAsFixed(0)}', style: GoogleFonts.outfit(color: Colors.white.withOpacity(0.5), fontSize: 28, fontWeight: FontWeight.w700)),
                              ],
                            ),
                          ],
                        ),
                      ).animate().fadeIn(delay: 500.ms).scale(begin: const Offset(0.9, 0.9)),
                      
                      const SizedBox(height: 24),
                      
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(20)),
                        child: Text('$totalCorrect sur $_total réponses exactes',
                          style: GoogleFonts.inter(color: Colors.white.withOpacity(0.9), fontSize: 16, fontWeight: FontWeight.w600)),
                      ).animate().fadeIn(delay: 600.ms),
                      
                      const SizedBox(height: 24),
                      
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: Colors.amber.withOpacity(0.2), shape: BoxShape.circle),
                            child: const Icon(Icons.star_rounded, color: Colors.amber, size: 28),
                          ),
                          const SizedBox(width: 12),
                          Text('+${score.toStringAsFixed(1)} points éco',
                            style: GoogleFonts.outfit(color: Colors.amber, fontSize: 22, fontWeight: FontWeight.w800)),
                        ],
                      ).animate().fadeIn(delay: 700.ms).slideY(begin: 0.2),
                    ],
                  ),
                ),
              ),

              if (feedback.isNotEmpty)
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.03),
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(color: Colors.purpleAccent.withOpacity(0.3), width: 1.5),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(color: Colors.purpleAccent.withOpacity(0.2), borderRadius: BorderRadius.circular(14)),
                              child: const Icon(Icons.auto_awesome, color: Colors.purpleAccent, size: 24),
                            ),
                            const SizedBox(width: 16),
                            Text('Explications de l\'IA', style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Text(feedback, style: GoogleFonts.inter(fontSize: 16, color: Colors.white.withOpacity(0.8), height: 1.6)),
                      ],
                    ),
                  ).animate().fadeIn(delay: 800.ms).slideY(begin: 0.1),
                ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(32, 60, 32, 24),
                  child: Row(
                    children: [
                      Expanded(child: Divider(color: Colors.white.withOpacity(0.1))),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text('ANALYSE DÉTAILLÉE', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 2, color: Colors.white.withOpacity(0.4))),
                      ),
                      Expanded(child: Divider(color: Colors.white.withOpacity(0.1))),
                    ],
                  ),
                ),
              ),

              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((_, i) {
                    final d = details[i];
                    final isCorrect = d['is_correct'] == true;
                    final answerColor = isCorrect ? const Color(0xFF00E676) : const Color(0xFFFF1744);
                    
                    return Container(
                      margin: const EdgeInsets.only(bottom: 24),
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.02),
                        borderRadius: BorderRadius.circular(32),
                        border: Border.all(color: answerColor.withOpacity(0.3), width: 2),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(color: answerColor.withOpacity(0.15), shape: BoxShape.circle),
                                child: Icon(isCorrect ? Icons.check_rounded : Icons.close_rounded, color: answerColor, size: 24),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Question ${d['number'] ?? i + 1}',
                                      style: GoogleFonts.outfit(color: Colors.white.withOpacity(0.5), fontWeight: FontWeight.w800, fontSize: 14)),
                                    const SizedBox(height: 8),
                                    if (d['question'] != null)
                                      Text(d['question'], style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white, height: 1.4)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Divider(color: Colors.white10)),
                          
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(color: Colors.white.withOpacity(0.03), borderRadius: BorderRadius.circular(20)),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SizedBox(width: 110, child: Text('Votre choix', style: GoogleFonts.inter(fontSize: 14, color: Colors.white.withOpacity(0.5), fontWeight: FontWeight.w600))),
                                    Expanded(child: Text('${d['student_answer'] ?? '-'}',
                                      style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: answerColor))),
                                  ],
                                ),
                                if (!isCorrect && d['correct_answer'] != null) ...[
                                  const SizedBox(height: 16),
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      SizedBox(width: 110, child: Text('La bonne réponse', style: GoogleFonts.inter(fontSize: 14, color: Colors.white.withOpacity(0.5), fontWeight: FontWeight.w600))),
                                      Expanded(child: Text('${d['correct_answer']}',
                                        style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: const Color(0xFF00E676)))),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                          
                          if (d['feedback'] != null && d['feedback'].toString().isNotEmpty) ...[
                            const SizedBox(height: 20),
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(color: Colors.blueAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.tips_and_updates_rounded, color: Colors.blueAccent, size: 22),
                                  const SizedBox(width: 16),
                                  Expanded(child: Text(d['feedback'], style: GoogleFonts.inter(fontSize: 15, color: Colors.white.withOpacity(0.9), height: 1.5))),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ).animate().fadeIn(delay: Duration(milliseconds: 900 + i * 150)).slideY(begin: 0.1);
                  }, childCount: details.length),
                ),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 40, 24, 80),
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF0B1120),
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      elevation: 20,
                      shadowColor: Colors.white.withOpacity(0.2),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.check_circle_rounded, size: 28),
                        const SizedBox(width: 16),
                        Text('Terminer et quitter', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w900)),
                      ],
                    ),
                  ).animate().fadeIn(delay: 1.seconds).slideY(begin: 0.2),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showExitDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Quitter le quiz ?', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: Text('Votre progression sera perdue.', style: GoogleFonts.inter(color: AppTheme.textMuted)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Continuer')),
          ElevatedButton(
            onPressed: () { Navigator.pop(ctx); Navigator.pop(context); },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('Quitter', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
