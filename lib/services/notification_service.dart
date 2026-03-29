import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

/// Simple in-app notification system
/// Stores notifications locally and displays them via overlay
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final ValueNotifier<List<AppNotification>> notifications = ValueNotifier([]);

  int get unreadCount => notifications.value.where((n) => !n.isRead).length;

  void addNotification({
    required String title,
    required String body,
    NotificationType type = NotificationType.info,
  }) {
    final notif = AppNotification(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      body: body,
      type: type,
      createdAt: DateTime.now(),
    );
    notifications.value = [notif, ...notifications.value];
  }

  void markAllRead() {
    notifications.value = notifications.value.map((n) => n.copyWith(isRead: true)).toList();
  }

  void markRead(String id) {
    notifications.value = notifications.value.map((n) => n.id == id ? n.copyWith(isRead: true) : n).toList();
  }

  void clear() {
    notifications.value = [];
  }

  /// Show a quick toast-style notification at the top of the screen
  static void showToast(BuildContext context, {
    required String title,
    required String body,
    NotificationType type = NotificationType.info,
  }) {
    // Add to persistent list
    NotificationService().addNotification(title: title, body: body, type: type);

    // Show overlay
    final overlay = Overlay.of(context);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (context) => _NotificationToast(
        title: title, body: body, type: type,
        onDismiss: () => entry.remove(),
      ),
    );

    overlay.insert(entry);

    // Auto-dismiss after 4 seconds
    Future.delayed(const Duration(seconds: 4), () {
      if (entry.mounted) entry.remove();
    });
  }
}

enum NotificationType { like, comment, save, info }

class AppNotification {
  final String id;
  final String title;
  final String body;
  final NotificationType type;
  final DateTime createdAt;
  final bool isRead;

  AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.createdAt,
    this.isRead = false,
  });

  AppNotification copyWith({bool? isRead}) => AppNotification(
    id: id, title: title, body: body, type: type, createdAt: createdAt,
    isRead: isRead ?? this.isRead,
  );

  IconData get icon {
    switch (type) {
      case NotificationType.like: return Icons.favorite_rounded;
      case NotificationType.comment: return Icons.chat_bubble_rounded;
      case NotificationType.save: return Icons.bookmark_rounded;
      case NotificationType.info: return Icons.notifications_rounded;
    }
  }

  Color get color {
    switch (type) {
      case NotificationType.like: return Colors.pink;
      case NotificationType.comment: return AppTheme.accentTeal;
      case NotificationType.save: return AppTheme.primaryGreen;
      case NotificationType.info: return AppTheme.deepSlate;
    }
  }
}

class _NotificationToast extends StatefulWidget {
  final String title;
  final String body;
  final NotificationType type;
  final VoidCallback onDismiss;

  const _NotificationToast({required this.title, required this.body, required this.type, required this.onDismiss});

  @override
  State<_NotificationToast> createState() => _NotificationToastState();
}

class _NotificationToastState extends State<_NotificationToast> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _slideAnimation = Tween<Offset>(begin: const Offset(0, -1), end: Offset.zero).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  IconData get _icon {
    switch (widget.type) {
      case NotificationType.like: return Icons.favorite_rounded;
      case NotificationType.comment: return Icons.chat_bubble_rounded;
      case NotificationType.save: return Icons.bookmark_rounded;
      case NotificationType.info: return Icons.notifications_rounded;
    }
  }

  Color get _color {
    switch (widget.type) {
      case NotificationType.like: return Colors.pink;
      case NotificationType.comment: return AppTheme.accentTeal;
      case NotificationType.save: return AppTheme.primaryGreen;
      case NotificationType.info: return AppTheme.deepSlate;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 8,
      left: 16, right: 16,
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: GestureDetector(
            onTap: widget.onDismiss,
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 24, offset: const Offset(0, 8))],
                ),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: _color.withOpacity(0.1), shape: BoxShape.circle),
                    child: Icon(_icon, color: _color, size: 20),
                  ),
                  const SizedBox(width: 14),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                    Text(widget.title, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.deepSlate)),
                    Text(widget.body, style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMuted), maxLines: 2, overflow: TextOverflow.ellipsis),
                  ])),
                  const SizedBox(width: 8),
                  Icon(Icons.close_rounded, size: 16, color: AppTheme.textMuted.withOpacity(0.5)),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
