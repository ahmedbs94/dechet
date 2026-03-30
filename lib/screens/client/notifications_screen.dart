import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../theme/app_theme.dart';
import '../../services/auth_service.dart';

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
      final dt = DateTime.parse(dateStr);
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return 'maintenant';
      if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes}min';
      if (diff.inHours < 24) return 'il y a ${diff.inHours}h';
      if (diff.inDays < 7) return 'il y a ${diff.inDays}j';
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) { return ''; }
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
            Text(time, style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8), fontWeight: FontWeight.w500)),
          ],
        ),
        trailing: !isRead
            ? Container(
                width: 10, height: 10,
                decoration: BoxDecoration(shape: BoxShape.circle, color: color),
              )
            : null,
        onTap: () async {
          if (!isRead) {
            final id = notif['id'];
            if (id != null) {
              await _authService.markNotificationRead(id is int ? id : int.parse(id.toString()));
              setState(() => notif['is_read'] = true);
            }
          }
        },
      ),
    ).animate().fadeIn(delay: (50 * index).ms).slideX(begin: 0.03, end: 0, duration: 300.ms);
  }
}
