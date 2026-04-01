import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../theme/app_theme.dart';
import '../../services/auth_service.dart';
import 'post_detail_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({Key? key}) : super(key: key);

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _authService = AuthService();
  List<dynamic> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    timeago.setLocaleMessages('fr', timeago.FrMessages());
    _loadNotifications();
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
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
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

    if (mounted) Navigator.pop(context); // Close loading

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

  @override
  Widget build(BuildContext context) {
    final unreadCount = _notifications.where((n) => n['is_read'] != true).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: Color(0xFF1E293B)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Notifications', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B))),
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

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: isRead ? Colors.white : color.withOpacity(0.04),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isRead ? Colors.grey.shade100 : color.withOpacity(0.15)),
        boxShadow: isRead ? [] : [BoxShadow(color: color.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: ListTile(
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
            Row(
              children: [
                Text(time, style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8), fontWeight: FontWeight.w500)),
                if (postId != null) ...[
                  const SizedBox(width: 8),
                  Icon(Icons.open_in_new_rounded, size: 12, color: color.withOpacity(0.6)),
                  const SizedBox(width: 2),
                  Text('Voir', style: GoogleFonts.inter(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
                ],
              ],
            ),
          ],
        ),
        trailing: !isRead
            ? Container(
                width: 10, height: 10,
                decoration: BoxDecoration(shape: BoxShape.circle, color: color),
              )
            : postId != null
                ? Icon(Icons.chevron_right_rounded, color: Colors.grey.shade300, size: 22)
                : null,
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
    ).animate().fadeIn(delay: (50 * index).ms).slideX(begin: 0.03, end: 0, duration: 300.ms);
  }
}
