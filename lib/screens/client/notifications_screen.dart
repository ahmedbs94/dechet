import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../theme/app_theme.dart';
import '../../services/auth_service.dart';
import '../../models/user_model.dart';
import 'post_detail_screen.dart';
import '../../widgets/web_back_button.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({Key? key}) : super(key: key);

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _authService = AuthService();
  List<dynamic> _notifications = [];
  bool _isLoading = true;
  // Track which notification has an open reply field
  int? _replyingToNotifId;
  final TextEditingController _replyController = TextEditingController();
  bool _isSendingReply = false;

  @override
  void initState() {
    super.initState();
    timeago.setLocaleMessages('fr', timeago.FrMessages());
    _loadNotifications();
  }

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  Future<void> _loadNotifications() async {
    setState(() => _isLoading = true);
    final notifs = await _authService.fetchNotifications();
    if (mounted) setState(() { _notifications = notifs; _isLoading = false; });
  }

  Future<void> _markAllRead() async {
    await _authService.markAllNotificationsRead();
    setState(() {
      for (var n in _notifications) { n['is_read'] = true; }
    });
  }

  IconData _getIcon(String type) {
    switch (type) {
      case 'like': return Icons.favorite_rounded;
      case 'comment': return Icons.chat_bubble_rounded;
      case 'save': return Icons.bookmark_rounded;
      default: return Icons.notifications_rounded;
    }
  }

  Color _getColor(String type) {
    switch (type) {
      case 'like': return const Color(0xFFFF6B8A);
      case 'comment': return const Color(0xFF5B8DEF);
      case 'save': return AppTheme.primaryGreen;
      default: return const Color(0xFF94A3B8);
    }
  }

  String _formatTime(String? dateStr) {
    if (dateStr == null) return '';
    try {
      return timeago.format(DateTime.parse(dateStr), locale: 'fr');
    } catch (_) { return ''; }
  }

  Future<void> _navigateToPost(int postId) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Theme.of(ctx).colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20)],
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const CircularProgressIndicator(color: AppTheme.primaryGreen),
            const SizedBox(height: 16),
            Text('Chargement...', style: GoogleFonts.inter(fontSize: 14, color: AppTheme.textMuted)),
          ]),
        ),
      ),
    );

    final post = await _authService.fetchSinglePost(postId);

    if (mounted) Navigator.pop(context);

    if (post != null && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => PostDetailScreen(post: post)),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Publication introuvable ou supprimée', style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
        backgroundColor: Colors.red.shade400,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    }
  }

  Future<void> _sendReply(Map<String, dynamic> notif) async {
    if (_replyController.text.trim().isEmpty) return;
    if (!AuthState.isLoggedIn) return;

    final postId = notif['post_id'];
    final commentId = notif['comment_id']; // The comment we're replying to
    if (postId == null) return;

    setState(() => _isSendingReply = true);

    final user = AuthState.currentUser;
    final result = await _authService.addComment(
      postId.toString(),
      user?.name ?? 'Anonyme',
      user?.avatarUrl,
      _replyController.text.trim(),
      parentId: commentId is int ? commentId : (commentId != null ? int.tryParse(commentId.toString()) : null),
    );

    if (mounted) {
      setState(() => _isSendingReply = false);

      if (result['success'] == true) {
        _replyController.clear();
        setState(() => _replyingToNotifId = null);

        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Row(children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Text('Réponse envoyée !', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          ]),
          backgroundColor: AppTheme.primaryGreen,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 2),
        ));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erreur lors de l\'envoi de la réponse', style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
          backgroundColor: Colors.red.shade400,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = _notifications.where((n) => n['is_read'] != true).length;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        leading: webLeading(IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: Theme.of(context).colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        )),
        title: Text('Notifications', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
        actions: [
          if (unreadCount > 0)
            TextButton(
              onPressed: _markAllRead,
              child: Text('Tout lire', style: GoogleFonts.inter(color: AppTheme.primaryGreen, fontWeight: FontWeight.w600, fontSize: 13)),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen))
          : _notifications.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  color: AppTheme.primaryGreen,
                  onRefresh: _loadNotifications,
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    itemCount: _notifications.length,
                    itemBuilder: (context, index) {
                      final notif = _notifications[index];
                      return _buildNotifCard(notif, index);
                    },
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 80, height: 80,
          decoration: BoxDecoration(
            color: AppTheme.primaryGreen.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.notifications_none_rounded, size: 40, color: AppTheme.primaryGreen.withOpacity(0.5)),
        ),
        const SizedBox(height: 20),
        Text('Aucune notification', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF64748B))),
        const SizedBox(height: 8),
        Text('Vos interactions apparaîtront ici', style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF94A3B8))),
      ]),
    ).animate().fadeIn(delay: 100.ms);
  }

  Widget _buildNotifCard(Map<String, dynamic> notif, int index) {
    final type = notif['type'] ?? '';
    final isRead = notif['is_read'] == true;
    final color = _getColor(type);
    final icon = _getIcon(type);
    final time = _formatTime(notif['created_at']);
    final postId = notif['post_id'];
    final notifId = notif['id'];
    final isComment = type == 'comment';
    final isReplying = _replyingToNotifId == notifId;
    final fromUser = notif['from_user_name'] ?? '';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: isRead ? Theme.of(context).colorScheme.surface : color.withOpacity(0.04),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isRead
              ? (Theme.of(context).brightness == Brightness.dark
                  ? Theme.of(context).dividerColor
                  : Colors.grey.shade100)
              : color.withOpacity(0.15),
        ),
        boxShadow: isRead ? [] : [BoxShadow(color: color.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [color.withOpacity(0.15), color.withOpacity(0.08)]),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            title: Text(
              notif['title'] ?? 'Notification',
              style: GoogleFonts.outfit(
                fontWeight: isRead ? FontWeight.w500 : FontWeight.bold,
                fontSize: 15,
                color: const Color(0xFF1E293B),
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(notif['body'] ?? '', style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B))),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 12,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(time, style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8), fontWeight: FontWeight.w500)),
                    if (postId != null)
                      GestureDetector(
                        onTap: () {
                          final pid = postId is int ? postId : int.parse(postId.toString());
                          _navigateToPost(pid);
                        },
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.open_in_new_rounded, size: 12, color: color.withOpacity(0.6)),
                            const SizedBox(width: 2),
                            Text('Voir', style: GoogleFonts.inter(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    // Reply button for comment notifications
                    if (isComment && postId != null && AuthState.isLoggedIn)
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            if (isReplying) {
                              _replyingToNotifId = null;
                              _replyController.clear();
                            } else {
                              _replyingToNotifId = notifId;
                              _replyController.clear();
                            }
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: isReplying ? color.withOpacity(0.15) : color.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(
                              isReplying ? Icons.close_rounded : Icons.reply_rounded,
                              size: 13,
                              color: color,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isReplying ? 'Annuler' : 'Répondre',
                              style: GoogleFonts.inter(fontSize: 11, color: color, fontWeight: FontWeight.w600),
                            ),
                          ]),
                        ),
                      ),
                  ],
                ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!isRead)
                  Container(
                    width: 10, height: 10,
                    margin: const EdgeInsets.only(right: 4),
                    decoration: BoxDecoration(shape: BoxShape.circle, color: color),
                  ),
                if (isRead)
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () async {
                        final id = notif['id'];
                        if (id != null) {
                          final nid = id is int ? id : int.parse(id.toString());
                          final success = await _authService.markNotificationUnread(nid);
                          if (success && mounted) {
                            setState(() => notif['is_read'] = false);
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text('Notification marquée comme non lue', style: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 13)),
                              backgroundColor: color,
                              behavior: SnackBarBehavior.floating,
                              duration: const Duration(seconds: 2),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ));
                          }
                        }
                      },
                      child: Tooltip(
                        message: 'Marquer comme non lue',
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.mark_email_unread_outlined, size: 18, color: color),
                        ),
                      ),
                    ),
                  ),
                if (postId != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Icon(Icons.chevron_right_rounded, color: Colors.grey.shade300, size: 22),
                  ),
              ],
            ),
            onTap: () async {
              // Mark as read
              if (!isRead) {
                final id = notif['id'];
                if (id != null) {
                  await _authService.markNotificationRead(id is int ? id : int.parse(id.toString()));
                  setState(() => notif['is_read'] = true);
                }
              }

              // Navigate to the post if post_id is available
              if (postId != null) {
                final pid = postId is int ? postId : int.parse(postId.toString());
                _navigateToPost(pid);
              }
            },
          ),

          // Inline reply field
          if (isReplying)
            _buildReplyField(notif, color, fromUser),
        ],
      ),
    ).animate().fadeIn(delay: (50 * index).ms).slideX(begin: 0.03, end: 0, duration: 300.ms);
  }

  Widget _buildReplyField(Map<String, dynamic> notif, Color color, String fromUser) {
    return Animate(
      effects: [FadeEffect(duration: 200.ms), SlideEffect(begin: const Offset(0, -0.1), end: Offset.zero, duration: 200.ms)],
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Divider
            Container(
              height: 1,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color.withOpacity(0.2), color.withOpacity(0.05), Colors.transparent],
                ),
              ),
            ),
            // Label
            Padding(
              padding: const EdgeInsets.only(bottom: 8, left: 4),
              child: Row(children: [
                Icon(Icons.reply_rounded, size: 14, color: color.withOpacity(0.7)),
                const SizedBox(width: 6),
                Text(
                  'Répondre à $fromUser',
                  style: GoogleFonts.inter(fontSize: 12, color: color.withOpacity(0.8), fontWeight: FontWeight.w600),
                ),
              ]),
            ),
            // Input + send button
            Row(children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: color.withOpacity(0.2)),
                  ),
                  child: TextField(
                    controller: _replyController,
                    autofocus: true,
                    maxLines: 3,
                    minLines: 1,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendReply(notif),
                    style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF1E293B)),
                    decoration: InputDecoration(
                      hintText: 'Écrire votre réponse...',
                      hintStyle: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF94A3B8)),
                      border: InputBorder.none,
                      filled: false,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      isDense: true,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _isSendingReply ? null : () => _sendReply(notif),
                  borderRadius: BorderRadius.circular(50),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 42, height: 42,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [color, color.withOpacity(0.8)],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3))],
                    ),
                    child: Center(
                      child: _isSendingReply
                          ? const SizedBox(
                              width: 18, height: 18,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                    ),
                  ),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}
