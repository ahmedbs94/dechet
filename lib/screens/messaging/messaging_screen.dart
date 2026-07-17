// lib/screens/messaging/messaging_screen.dart
// Écran de messagerie inter-rôles — EcoRewind
// Design premium dark avec bulles de chat, groupes, broadcasts

import 'dart:async';
import 'dart:convert';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/messaging_service.dart';
import '../../theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Point d'entrée : MessagingScreen
// ─────────────────────────────────────────────────────────────────────────────

class MessagingScreen extends StatefulWidget {
  const MessagingScreen({Key? key}) : super(key: key);

  @override
  State<MessagingScreen> createState() => _MessagingScreenState();
}

class _MessagingScreenState extends State<MessagingScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  List<Map<String, dynamic>> _conversations = [];
  bool _loading = true;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _load();
    _pollTimer = Timer.periodic(
      const Duration(seconds: 8),
      (_) => _load(silent: true),
    );
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    final convs = await MessagingService.getConversations();
    if (mounted) {
      setState(() {
        _conversations = convs;
        _loading = false;
      });
    }
  }

  // ── Ouvrir une nouvelle conversation ─────────────────────────────────────

  Future<void> _openNewMessage() async {
    final recipients = await MessagingService.getEligibleRecipients();
    final groups = await MessagingService.getAccessibleGroups();

    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _NewMessageSheet(
        recipients: recipients,
        groups: groups,
        onMessageSent: _load,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: const Color(0xFF0A0F1A),
      appBar: _buildAppBar(),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen))
          : _conversations.isEmpty
              ? _buildEmpty()
              : _buildConversationList(),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_messaging_new',
        onPressed: _openNewMessage,
        backgroundColor: AppTheme.primaryGreen,
        icon: const Icon(Icons.edit_rounded, color: Colors.white),
        label: Text(
          'Nouveau message',
          style: GoogleFonts.outfit(
              color: Colors.white, fontWeight: FontWeight.w700),
        ),
      ).animate().slideY(begin: 1, duration: 400.ms, curve: Curves.easeOut),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF0D1B2A),
      elevation: 0,
      title: Row(children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppTheme.primaryGreen, AppTheme.accentTeal],
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.forum_rounded, color: Colors.white, size: 18),
        ),
        const SizedBox(width: 10),
        Text('Messagerie',
            style: GoogleFonts.outfit(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 18)),
      ]),
      actions: [
        IconButton(
          icon: const Icon(Icons.add_comment_rounded, color: AppTheme.primaryGreen),
          tooltip: 'Nouveau message',
          onPressed: _openNewMessage,
        ),
        IconButton(
          icon: const Icon(Icons.refresh_rounded, color: Colors.white54),
          onPressed: _load,
        ),
      ],
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.primaryGreen.withOpacity(0.2),
                  AppTheme.accentTeal.withOpacity(0.1)
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.forum_outlined,
                color: AppTheme.primaryGreen, size: 40),
          ),
          const SizedBox(height: 20),
          Text('Aucune conversation',
              style: GoogleFonts.outfit(
                  color: Colors.white70,
                  fontSize: 18,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text('Appuyez sur le bouton ci-dessous pour commencer',
              style: GoogleFonts.inter(
                  color: Colors.white38, fontSize: 13)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _openNewMessage,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 4,
            ),
            icon: const Icon(Icons.edit_rounded, size: 18),
            label: Text(
              'Nouveau message',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 60),
        ],
      ),
    ).animate().fadeIn(duration: 500.ms);
  }


  Widget _buildConversationList() {
    return RefreshIndicator(
      color: AppTheme.primaryGreen,
      backgroundColor: const Color(0xFF0D1B2A),
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
        itemCount: _conversations.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) {
          final c = _conversations[i];
          return _ConversationTile(
            conversation: c,
            onTap: () => _openConversation(c),
          );
        },
      ),
    );
  }

  void _openConversation(Map<String, dynamic> conv) async {
    final type = conv['type'] as String;

    if (type == 'direct') {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => _ChatScreen(
            partnerId: conv['partner_id'] as int,
            partnerName: conv['partner_name'] as String,
            partnerRole: conv['partner_role'] as String,
            partnerAvatar: conv['partner_avatar'] as String?,
          ),
        ),
      );
    } else if (type == 'citizen_group') {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => _GroupChatScreen(
            groupId: conv['group_id'] as int,
            groupName: conv['group_name'] as String,
            groupColor: conv['group_color'] as String? ?? '#00C896',
            memberCount: conv['member_count'] as int? ?? 0,
          ),
        ),
      );
    } else if (type == 'broadcast') {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => _ChatScreen(
            partnerId: conv['partner_id'] as int,
            partnerName: conv['partner_name'] as String,
            partnerRole: conv['partner_role'] as String,
            partnerAvatar: conv['partner_avatar'] as String?,
            isBroadcast: true,
          ),
        ),
      );
    }
    _load();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tile de conversation
// ─────────────────────────────────────────────────────────────────────────────

class _ConversationTile extends StatelessWidget {
  final Map<String, dynamic> conversation;
  final VoidCallback onTap;

  const _ConversationTile({required this.conversation, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final type = conversation['type'] as String;
    final unread = (conversation['unread_count'] as int? ?? 0);
    final hasUnread = unread > 0;
    final lastMsg = conversation['last_message'] as String? ?? '';
    final lastAt = conversation['last_message_at'] as String?;
    final ismine = conversation['last_is_mine'] as bool? ?? false;

    String title;
    String subtitle;
    IconData typeIcon;
    Color iconColor;

    if (type == 'citizen_group') {
      title = conversation['group_name'] as String? ?? 'Groupe';
      final count = conversation['member_count'] as int? ?? 0;
      subtitle = '👥 $count membres · $lastMsg';
      typeIcon = Icons.groups_rounded;
      iconColor = Color(int.parse(
          (conversation['group_color'] as String? ?? '#00C896')
              .replaceFirst('#', '0xFF')));
    } else if (type == 'broadcast') {
      title = '${conversation['partner_name']} (broadcast)';
      final label = conversation['collector_group_label'] as String?;
      subtitle = label != null ? '📢 $label · $lastMsg' : '📢 $lastMsg';
      typeIcon = Icons.campaign_rounded;
      iconColor = Colors.orange;
    } else {
      title = conversation['partner_name'] as String? ?? '?';
      subtitle = ismine ? '✓ $lastMsg' : lastMsg;
      typeIcon = _roleIcon(conversation['partner_role'] as String? ?? 'user');
      iconColor = AppTheme.primaryGreen;
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: hasUnread
              ? const Color(0xFF0D2A1A)
              : const Color(0xFF111827),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: hasUnread
                ? AppTheme.primaryGreen.withOpacity(0.4)
                : Colors.white.withOpacity(0.05),
            width: hasUnread ? 1.5 : 1,
          ),
        ),
        child: Row(children: [
          // Avatar
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  iconColor.withOpacity(0.3),
                  iconColor.withOpacity(0.1)
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(typeIcon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 12),
          // Texte
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                    child: Text(
                      title,
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontWeight: hasUnread
                            ? FontWeight.w800
                            : FontWeight.w600,
                        fontSize: 15,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (lastAt != null)
                    Text(
                      _formatTime(lastAt),
                      style: GoogleFonts.inter(
                        color: hasUnread
                            ? AppTheme.primaryGreen
                            : Colors.white38,
                        fontSize: 11,
                        fontWeight: hasUnread
                            ? FontWeight.w700
                            : FontWeight.w400,
                      ),
                    ),
                ]),
                const SizedBox(height: 4),
                Row(children: [
                  Expanded(
                    child: Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        color: hasUnread ? Colors.white60 : Colors.white38,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (hasUnread)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryGreen,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$unread',
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                ]),
              ],
            ),
          ),
        ]),
      ),
    ).animate().fadeIn(duration: 300.ms).slideX(begin: -0.05);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Écran de conversation 1-à-1
// ─────────────────────────────────────────────────────────────────────────────

class _ChatScreen extends StatefulWidget {
  final int partnerId;
  final String partnerName;
  final String partnerRole;
  final String? partnerAvatar;
  final bool isBroadcast;

  const _ChatScreen({
    required this.partnerId,
    required this.partnerName,
    required this.partnerRole,
    this.partnerAvatar,
    this.isBroadcast = false,
  });

  @override
  State<_ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<_ChatScreen> {
  final TextEditingController _ctrl = TextEditingController();
  final ScrollController _scroll = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  bool _loading = true;
  bool _sending = false;
  Timer? _pollTimer;
  Timer? _typingTimer;          // délai avant de stopper l'indicateur "en écriture"
  int? _replyToId;
  String? _replyToContent;
  String? _replyToSender;
  bool _partnerTyping = false;  // vrai quand le partenaire est en train d'écrire
  int? _myUserId;               // id de l'utilisateur courant (lu depuis SharedPreferences)

  StreamSubscription<RemoteMessage>? _fcmSub;
  StreamSubscription<DatabaseEvent>? _typingSub; // écoute RTDB typing du partenaire

  // ── Références RTDB (/typing/{userId}/{partnerId}) ─────────────────────────
  DatabaseReference get _myTypingRef =>
      FirebaseDatabase.instance.ref('typing/$_myUserId/${widget.partnerId}');
  DatabaseReference get _partnerTypingRef =>
      FirebaseDatabase.instance.ref('typing/${widget.partnerId}/$_myUserId');

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    // Récupérer l'ID de l'utilisateur courant depuis SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final jwt = prefs.getString('jwt_token');
    if (jwt != null) {
      try {
        final parts = jwt.split('.');
        if (parts.length == 3) {
          final payload = parts[1];
          final normalized = base64Url.normalize(payload);
          final resp = utf8.decode(base64Url.decode(normalized));
          final data = jsonDecode(resp) as Map<String, dynamic>;
          _myUserId = int.tryParse(data['id']?.toString() ?? '');
        }
      } catch (_) {}
    }

    _load();
    // Marquer tous les messages comme lus dès l'ouverture (coches bleues)
    MessagingService.markConversationAsRead(widget.partnerId).ignore();

    // Polling 2s pour les messages récents
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) => _load(silent: true));

    // Wakeup instantané si une push FCM de type 'message' arrive en foreground
    _fcmSub = FirebaseMessaging.onMessage.listen((msg) {
      final type = msg.data['type'] ?? '';
      final partnerId = int.tryParse(msg.data['partner_id'] ?? msg.data['sender_id'] ?? '');
      if (type == 'message' && partnerId == widget.partnerId) {
        _load(silent: true);
        // Marquer immédiatement comme lu
        MessagingService.markConversationAsRead(widget.partnerId).ignore();
      }
    });

    // Écouter l'indicateur de frappe du partenaire (RTDB)
    if (_myUserId != null) {
      _typingSub = _partnerTypingRef.onValue.listen((event) {
        final val = event.snapshot.value;
        final isTyping = val == true || val == 1;
        if (mounted && _partnerTyping != isTyping) {
          setState(() => _partnerTyping = isTyping);
          if (isTyping) _scrollToBottom();
        }
      });
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _typingTimer?.cancel();
    _fcmSub?.cancel();
    _typingSub?.cancel();
    // Effacer l'indicateur de frappe quand on quitte
    if (_myUserId != null) {
      _myTypingRef.remove().ignore();
    }
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  // ── Publier l'indicateur de frappe dans RTDB ──────────────────────────────
  void _onTypingChanged(String value) {
    if (_myUserId == null) return;
    if (value.isNotEmpty) {
      _myTypingRef.set(true).ignore();
      // Réinitialiser le timer : stoppe l'indicateur après 3s sans frappe
      _typingTimer?.cancel();
      _typingTimer = Timer(const Duration(seconds: 3), () {
        _myTypingRef.remove().ignore();
      });
    } else {
      _typingTimer?.cancel();
      _myTypingRef.remove().ignore();
    }
  }


  Future<void> _load({bool silent = false}) async {
    if (!silent && mounted) setState(() => _loading = true);
    final data = await MessagingService.getConversation(widget.partnerId);
    if (mounted && data != null) {
      final msgs = (data['messages'] as List? ?? [])
          .cast<Map<String, dynamic>>();
      setState(() {
        _messages = msgs;
        _loading = false;
      });
      if (!silent) _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    _ctrl.clear();

    Map<String, dynamic>? result;
    if (_replyToId != null) {
      result = await MessagingService.replyToMessage(
        messageId: _replyToId!,
        content: text,
      );
    } else {
      result = await MessagingService.sendMessage(
        receiverId: widget.partnerId,
        content: text,
      );
    }

    setState(() {
      _sending = false;
      _replyToId = null;
      _replyToContent = null;
      _replyToSender = null;
    });

    if (result != null) {
      await _load(silent: true);
      _scrollToBottom();
    }
  }

  void _setReply(Map<String, dynamic> msg) {
    HapticFeedback.lightImpact();
    setState(() {
      _replyToId = msg['id'] as int;
      _replyToContent = msg['content'] as String?;
      _replyToSender = msg['sender_name'] as String?;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0F1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1B2A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                AppTheme.primaryGreen.withOpacity(0.3),
                AppTheme.accentTeal.withOpacity(0.2),
              ]),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _roleIcon(widget.partnerRole),
              color: AppTheme.primaryGreen,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.partnerName,
                style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15)),
            Text(_roleLabel(widget.partnerRole),
                style: GoogleFonts.inter(
                    color: AppTheme.primaryGreen,
                    fontSize: 11,
                    fontWeight: FontWeight.w500)),
          ]),
        ]),
      ),
      body: Column(children: [
        // Messages
        Expanded(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(
                      color: AppTheme.primaryGreen))
              : _messages.isEmpty
                  ? _buildNoChatYet()
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                      itemCount: _messages.length,
                      itemBuilder: (_, i) => _MessageBubble(
                        message: _messages[i],
                        onReply: () => _setReply(_messages[i]),
                      ),
                    ),
        ),
        // Indicateur "en cours d'écriture"
        if (_partnerTyping) _buildTypingIndicator(),
        // Bandeau reply
        if (_replyToId != null) _buildReplyBanner(),
        // Zone de saisie
        _buildInputBar(),
      ]),
    );
  }

  /// Bulle "en cours d'écriture" style WhatsApp
  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 4, top: 2),
      child: Row(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: AppTheme.primaryGreen.withOpacity(0.2),
            child: Text(
              widget.partnerName.isNotEmpty ? widget.partnerName[0].toUpperCase() : '?',
              style: GoogleFonts.outfit(color: AppTheme.primaryGreen, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFF1E2D3D),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomRight: Radius.circular(18),
                bottomLeft: Radius.circular(4),
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _TypingDot(delay: 0),
                SizedBox(width: 4),
                _TypingDot(delay: 150),
                SizedBox(width: 4),
                _TypingDot(delay: 300),
              ],
            ),
          ),
        ],
      ).animate().fadeIn(duration: 200.ms),
    );
  }

  Widget _buildNoChatYet() {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.chat_bubble_outline_rounded,
            color: Colors.white24, size: 60),
        const SizedBox(height: 16),
        Text('Commencez la conversation',
            style: GoogleFonts.outfit(
                color: Colors.white38, fontSize: 16)),
      ]),
    );
  }

  Widget _buildReplyBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: const Color(0xFF0D2A1A),
      child: Row(children: [
        Container(
          width: 3,
          height: 36,
          decoration: BoxDecoration(
            color: AppTheme.primaryGreen,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _replyToSender ?? '',
                style: GoogleFonts.outfit(
                    color: AppTheme.primaryGreen,
                    fontSize: 12,
                    fontWeight: FontWeight.w700),
              ),
              Text(
                _replyToContent ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                    color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white38, size: 18),
          onPressed: () => setState(() {
            _replyToId = null;
            _replyToContent = null;
            _replyToSender = null;
          }),
        ),
      ]),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
      decoration: const BoxDecoration(
        color: Color(0xFF0D1B2A),
        border:
            Border(top: BorderSide(color: Color(0xFF1E2D3D), width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: Row(children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF111827),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                    color: const Color(0xFF1E2D3D), width: 1),
              ),
              child: TextField(
                controller: _ctrl,
                style: GoogleFonts.inter(
                    color: Colors.white, fontSize: 14),
                maxLines: null,
                textInputAction: TextInputAction.newline,
                onChanged: _onTypingChanged,
                decoration: InputDecoration(
                  hintText: 'Écrire un message…',
                  hintStyle: GoogleFonts.inter(
                      color: Colors.white30, fontSize: 14),
                  filled: false,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _sending ? null : _send,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.primaryGreen, AppTheme.accentTeal],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryGreen.withOpacity(0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: _sending
                  ? const Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      ),
                    )
                  : const Icon(Icons.send_rounded,
                      color: Colors.white, size: 22),
            ),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bulle de message
// ─────────────────────────────────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  final Map<String, dynamic> message;
  final VoidCallback onReply;

  const _MessageBubble({required this.message, required this.onReply});

  @override
  Widget build(BuildContext context) {
    final ismine = message['is_mine'] as bool? ?? false;
    final content = message['content'] as String? ?? '';
    final senderName = message['sender_name'] as String? ?? '';
    final createdAt = message['created_at'] as String?;
    final parentPreview = message['parent_preview'] as Map<String, dynamic>?;

    return GestureDetector(
      onLongPress: onReply,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment:
              ismine ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!ismine) ...[
              CircleAvatar(
                radius: 16,
                backgroundColor: AppTheme.primaryGreen.withOpacity(0.2),
                child: Icon(
                  _roleIcon(message['sender_role'] as String? ?? 'user'),
                  color: AppTheme.primaryGreen,
                  size: 16,
                ),
              ),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Column(
                crossAxisAlignment: ismine
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  if (!ismine)
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 2),
                      child: Text(
                        senderName,
                        style: GoogleFonts.outfit(
                          color: AppTheme.primaryGreen,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  Container(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.72,
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      gradient: ismine
                          ? const LinearGradient(
                              colors: [
                                AppTheme.primaryGreen,
                                AppTheme.accentTeal
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : null,
                      color: ismine ? null : const Color(0xFF1E2D3D),
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(18),
                        topRight: const Radius.circular(18),
                        bottomLeft: Radius.circular(ismine ? 18 : 4),
                        bottomRight: Radius.circular(ismine ? 4 : 18),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: ismine
                              ? AppTheme.primaryGreen.withOpacity(0.25)
                              : Colors.black.withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Reply preview
                        if (parentPreview != null)
                          Container(
                            padding: const EdgeInsets.all(8),
                            margin: const EdgeInsets.only(bottom: 6),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: const Border(
                                left: BorderSide(
                                    color: Colors.white54, width: 2),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  parentPreview['sender_name'] as String? ??
                                      '',
                                  style: GoogleFonts.outfit(
                                    color: Colors.white70,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  parentPreview['content'] as String? ?? '',
                                  style: GoogleFonts.inter(
                                    color: Colors.white54,
                                    fontSize: 11,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        // Contenu
                        Text(
                          content,
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 14,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              createdAt != null ? _formatTime(createdAt) : '',
                              style: GoogleFonts.inter(
                                color: Colors.white54,
                                fontSize: 10,
                              ),
                            ),
                            if (ismine) ...[
                              const SizedBox(width: 4),
                              Icon(
                                (message['is_read'] as bool? ?? false)
                                    ? Icons.done_all_rounded
                                    : Icons.done_rounded,
                                // Bleu = lu, gris = envoyé mais non lu
                                color: (message['is_read'] as bool? ?? false)
                                    ? const Color(0xFF4FC3F7)   // bleu WhatsApp
                                    : Colors.white54,
                                size: 14,
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ).animate().fadeIn(duration: 250.ms).slideY(begin: 0.1),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Écran conversation de groupe (citoyens ou collecteurs)
// ─────────────────────────────────────────────────────────────────────────────

class _GroupChatScreen extends StatefulWidget {
  final int groupId;
  final String groupName;
  final String groupColor;
  final int memberCount;

  const _GroupChatScreen({
    required this.groupId,
    required this.groupName,
    required this.groupColor,
    required this.memberCount,
  });

  @override
  State<_GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<_GroupChatScreen> {
  final TextEditingController _ctrl = TextEditingController();
  final ScrollController _scroll = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  bool _loading = true;
  bool _sending = false;
  Timer? _pollTimer;

  StreamSubscription<RemoteMessage>? _fcmSub;

  @override
  void initState() {
    super.initState();
    _load();
    // Polling 2s pour les messages récents
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) => _load(silent: true));
    // Wakeup instantané si une push FCM de type 'group_message' arrive en foreground
    _fcmSub = FirebaseMessaging.onMessage.listen((msg) {
      final type = msg.data['type'] ?? '';
      final groupId = int.tryParse(msg.data['group_id'] ?? '');
      if (type == 'group_message' && groupId == widget.groupId) {
        _load(silent: true);
      }
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _fcmSub?.cancel();
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    final data =
        await MessagingService.getGroupConversation(widget.groupId);
    if (mounted && data != null) {
      final msgs = (data['messages'] as List? ?? [])
          .cast<Map<String, dynamic>>();
      setState(() {
        _messages = msgs;
        _loading = false;
      });
      if (!silent) _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut);
      }
    });
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    _ctrl.clear();
    final result = await MessagingService.sendGroupMessage(
        groupId: widget.groupId, content: text);
    setState(() => _sending = false);
    if (result != null) {
      await _load(silent: true);
      _scrollToBottom();
    }
  }

  Color get _groupColor {
    try {
      return Color(int.parse(widget.groupColor.replaceFirst('#', '0xFF')));
    } catch (_) {
      return AppTheme.primaryGreen;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0F1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1B2A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: _groupColor.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.groups_rounded, color: _groupColor, size: 22),
          ),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.groupName,
                style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15)),
            Text('${widget.memberCount} membres',
                style: GoogleFonts.inter(
                    color: _groupColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w500)),
          ]),
        ]),
      ),
      body: Column(children: [
        Expanded(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(
                      color: AppTheme.primaryGreen))
              : _messages.isEmpty
                  ? Center(
                      child: Text('Aucun message dans ce groupe',
                          style: GoogleFonts.inter(
                              color: Colors.white38, fontSize: 14)),
                    )
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.all(16),
                      itemCount: _messages.length,
                      itemBuilder: (_, i) => _MessageBubble(
                        message: _messages[i],
                        onReply: () {},
                      ),
                    ),
        ),
        // Input
        Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
          decoration: const BoxDecoration(
            color: Color(0xFF0D1B2A),
            border:
                Border(top: BorderSide(color: Color(0xFF1E2D3D), width: 1)),
          ),
          child: SafeArea(
            top: false,
            child: Row(children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF111827),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                        color: const Color(0xFF1E2D3D), width: 1),
                  ),
                  child: TextField(
                    controller: _ctrl,
                    style: GoogleFonts.inter(
                        color: Colors.white, fontSize: 14),
                    maxLines: null,
                    decoration: InputDecoration(
                      hintText: 'Message au groupe…',
                      hintStyle: GoogleFonts.inter(
                          color: Colors.white30, fontSize: 14),
                      filled: false,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: _sending ? null : _send,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [_groupColor, _groupColor.withOpacity(0.7)],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: _groupColor.withOpacity(0.35),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: _sending
                      ? const Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2),
                          ),
                        )
                      : const Icon(Icons.send_rounded,
                          color: Colors.white, size: 22),
                ),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sheet : Nouveau message
// ─────────────────────────────────────────────────────────────────────────────

class _NewMessageSheet extends StatefulWidget {
  final List<Map<String, dynamic>> recipients;
  final List<Map<String, dynamic>> groups;
  final VoidCallback onMessageSent;

  const _NewMessageSheet({
    required this.recipients,
    required this.groups,
    required this.onMessageSent,
  });

  @override
  State<_NewMessageSheet> createState() => _NewMessageSheetState();
}

class _NewMessageSheetState extends State<_NewMessageSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  Map<String, dynamic>? _selectedRecipient;
  Map<String, dynamic>? _selectedGroup;
  final TextEditingController _contentCtrl = TextEditingController();
  String _groupLabel = '';
  final List<Map<String, dynamic>> _selectedCollectors = [];
  bool _sending = false;

  int get _tabCount {
    int n = 1; // toujours l'onglet Individuel
    if (_hasGroups) n++;
    if (_hasCollectors) n++;
    return n;
  }

  @override
  void initState() {
    super.initState();
    _tab = TabController(
      length: _tabCount,
      vsync: this,
    );
  }

  bool get _hasGroups => widget.groups.isNotEmpty;

  bool get _hasCollectors => widget.recipients
      .any((r) => r['role'] == 'collector');

  @override
  void dispose() {
    _tab.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendDirect() async {
    if (_selectedRecipient == null || _contentCtrl.text.trim().isEmpty) return;
    setState(() => _sending = true);
    await MessagingService.sendMessage(
      receiverId: _selectedRecipient!['id'] as int,
      content: _contentCtrl.text.trim(),
    );
    setState(() => _sending = false);
    widget.onMessageSent();
    if (mounted) Navigator.pop(context);
  }

  Future<void> _sendGroup() async {
    if (_selectedGroup == null || _contentCtrl.text.trim().isEmpty) return;
    setState(() => _sending = true);
    await MessagingService.sendGroupMessage(
      groupId: _selectedGroup!['id'] as int,
      content: _contentCtrl.text.trim(),
    );
    setState(() => _sending = false);
    widget.onMessageSent();
    if (mounted) Navigator.pop(context);
  }

  Future<void> _sendBroadcast() async {
    if (_selectedCollectors.isEmpty || _contentCtrl.text.trim().isEmpty) return;
    setState(() => _sending = true);
    await MessagingService.broadcastToCollectors(
      receiverIds:
          _selectedCollectors.map((c) => c['id'] as int).toList(),
      content: _contentCtrl.text.trim(),
      collectorGroupLabel: _groupLabel.isNotEmpty ? _groupLabel : null,
    );
    setState(() => _sending = false);
    widget.onMessageSent();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [
      const Tab(text: 'Individuel'),
      if (_hasGroups) const Tab(text: 'Groupe'),
      if (_hasCollectors) const Tab(text: 'Broadcast'),
    ];

    // Si la liste est vide, on affiche un état explicatif
    final hasNoRecipients = widget.recipients.isEmpty && widget.groups.isEmpty;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      builder: (_, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF0D1B2A),
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Text('Nouveau message',
              style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          // Cas : aucun destinataire disponible
          if (hasNoRecipients)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.person_off_rounded,
                        color: Colors.white24, size: 56),
                    const SizedBox(height: 16),
                    Text('Aucun destinataire disponible',
                        style: GoogleFonts.outfit(
                            color: Colors.white54,
                            fontSize: 16,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Text(
                      'Votre rôle ne permet pas encore\nd\'envoyer des messages à d\'autres utilisateurs.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                          color: Colors.white30, fontSize: 13),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            // Tabs (si plusieurs)
            if (tabs.length > 1)
              TabBar(
                controller: _tab,
                tabs: tabs,
                labelColor: AppTheme.primaryGreen,
                unselectedLabelColor: Colors.white38,
                indicatorColor: AppTheme.primaryGreen,
                indicatorSize: TabBarIndicatorSize.label,
              ),
            const SizedBox(height: 12),
            // Contenu
            Expanded(
              child: TabBarView(
                controller: _tab,
                children: [
                  _DirectTab(
                    recipients: widget.recipients,
                    selected: _selectedRecipient,
                    onSelect: (r) => setState(() => _selectedRecipient = r),
                    contentCtrl: _contentCtrl,
                    sending: _sending,
                  onSend: _sendDirect,
                ),
                if (_hasGroups)
                  _GroupTab(
                    groups: widget.groups,
                    selected: _selectedGroup,
                    onSelect: (g) => setState(() => _selectedGroup = g),
                    contentCtrl: _contentCtrl,
                    sending: _sending,
                    onSend: _sendGroup,
                  ),
                if (_hasCollectors)
                  _BroadcastTab(
                    collectors: widget.recipients
                        .where((r) => r['role'] == 'collector')
                        .toList(),
                    selected: _selectedCollectors,
                    onToggle: (c) {
                      setState(() {
                        if (_selectedCollectors
                            .any((x) => x['id'] == c['id'])) {
                          _selectedCollectors.removeWhere(
                              (x) => x['id'] == c['id']);
                        } else {
                          _selectedCollectors.add(c);
                        }
                      });
                    },
                    groupLabel: _groupLabel,
                    onLabelChange: (v) =>
                        setState(() => _groupLabel = v),
                    contentCtrl: _contentCtrl,
                    sending: _sending,
                    onSend: _sendBroadcast,
                  ),
              ],
            ),
          ),          // Expanded (TabBarView)
          ],          // fin du bloc else
        ]),           // Column children
      ),              // Container
    );               // DraggableScrollableSheet
  }
}

// ── Tab Individuel ────────────────────────────────────────────────────────────

// ── Tab Individuel ────────────────────────────────────────────────────────────

class _DirectTab extends StatefulWidget {
  final List<Map<String, dynamic>> recipients;
  final Map<String, dynamic>? selected;
  final void Function(Map<String, dynamic>) onSelect;
  final TextEditingController contentCtrl;
  final bool sending;
  final VoidCallback onSend;

  const _DirectTab({
    required this.recipients,
    required this.selected,
    required this.onSelect,
    required this.contentCtrl,
    required this.sending,
    required this.onSend,
  });

  @override
  State<_DirectTab> createState() => _DirectTabState();
}

class _DirectTabState extends State<_DirectTab> {
  final TextEditingController _searchCtrl = TextEditingController();
  bool _isExpanded = false;
  String _query = '';

  @override
  void initState() {
    super.initState();
    if (widget.selected != null) {
      _searchCtrl.text = widget.selected!['full_name'] as String;
    }
  }

  @override
  void didUpdateWidget(covariant _DirectTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selected != oldWidget.selected) {
      if (widget.selected != null) {
        _searchCtrl.text = widget.selected!['full_name'] as String;
      } else {
        _searchCtrl.clear();
      }
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Filter recipients based on search query
    final filtered = widget.recipients.where((r) {
      final name = (r['full_name'] as String? ?? '').toLowerCase();
      final email = (r['email'] as String? ?? '').toLowerCase();
      final role = (r['role'] as String? ?? '').toLowerCase();
      final q = _query.toLowerCase();
      return name.contains(q) || email.contains(q) || role.contains(q);
    }).toList();

    // Group filtered by role
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final r in filtered) {
      final role = r['role'] as String;
      grouped.putIfAbsent(role, () => []).add(r);
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Sélectionner un destinataire',
            style: GoogleFonts.outfit(
                color: Colors.white60,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8)),
        const SizedBox(height: 10),

        // Search Dropdown field
        FocusScope(
          child: Focus(
            onFocusChange: (hasFocus) {
              setState(() {
                _isExpanded = hasFocus;
              });
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _searchCtrl,
                  onChanged: (val) {
                    setState(() {
                      _query = val;
                      _isExpanded = true;
                    });
                  },
                  style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.primaryGreen),
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close_rounded, color: Colors.white54, size: 20),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() {
                                _query = '';
                                _isExpanded = true;
                              });
                            },
                          )
                        : const Icon(Icons.arrow_drop_down_rounded, color: Colors.white54),
                    hintText: 'Écrivez le début du nom...',
                    hintStyle: GoogleFonts.inter(color: Colors.white30, fontSize: 14),
                    filled: true,
                    fillColor: const Color(0xFF111827),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF1E2D3D)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF1E2D3D)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppTheme.primaryGreen),
                    ),
                    contentPadding: const EdgeInsets.all(14),
                  ),
                ),
                
                // Dropdown container
                if (_isExpanded && filtered.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    constraints: const BoxConstraints(maxHeight: 250),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1F2937),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: ListView(
                        shrinkWrap: true,
                        padding: const EdgeInsets.all(8),
                        children: grouped.entries.map((entry) => Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                              child: Row(children: [
                                Icon(_roleIcon(entry.key), color: AppTheme.primaryGreen, size: 12),
                                const SizedBox(width: 6),
                                Text(_roleLabel(entry.key),
                                    style: GoogleFonts.outfit(
                                        color: AppTheme.primaryGreen,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700)),
                              ]),
                            ),
                            ...entry.value.map((r) {
                              final isSelected = widget.selected?['id'] == r['id'];
                              return InkWell(
                                onTap: () {
                                  widget.onSelect(r);
                                  _searchCtrl.text = r['full_name'] as String;
                                  FocusScope.of(context).unfocus();
                                  setState(() {
                                    _isExpanded = false;
                                    _query = '';
                                  });
                                },
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.all(10),
                                  margin: const EdgeInsets.symmetric(vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isSelected ? AppTheme.primaryGreen.withOpacity(0.1) : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(children: [
                                    CircleAvatar(
                                      radius: 12,
                                      backgroundColor: AppTheme.primaryGreen.withOpacity(0.2),
                                      child: Icon(_roleIcon(r['role'] as String), color: AppTheme.primaryGreen, size: 12),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        r['full_name'] as String,
                                        style: GoogleFonts.outfit(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                    if (isSelected)
                                      const Icon(Icons.check_circle_rounded, color: AppTheme.primaryGreen, size: 16),
                                  ]),
                                ),
                              );
                            }),
                            const Divider(color: Colors.white10),
                          ],
                        )).toList(),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // If a recipient is selected, show details card and message input
        if (widget.selected != null) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.primaryGreen.withOpacity(0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.primaryGreen.withOpacity(0.3)),
            ),
            child: Row(children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppTheme.primaryGreen.withOpacity(0.2),
                child: Icon(_roleIcon(widget.selected!['role'] as String), color: AppTheme.primaryGreen, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.selected!['full_name'] as String,
                      style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                    Text(
                      _roleLabel(widget.selected!['role'] as String),
                      style: GoogleFonts.inter(color: Colors.white54, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ]),
          ),
          const SizedBox(height: 16),
          _MessageInput(ctrl: widget.contentCtrl, sending: widget.sending, onSend: widget.onSend),
        ],
      ],
    );
  }
}

// ── Tab Groupe ────────────────────────────────────────────────────────────────

class _GroupTab extends StatefulWidget {
  final List<Map<String, dynamic>> groups;
  final Map<String, dynamic>? selected;
  final void Function(Map<String, dynamic>) onSelect;
  final TextEditingController contentCtrl;
  final bool sending;
  final VoidCallback onSend;

  const _GroupTab({
    required this.groups,
    required this.selected,
    required this.onSelect,
    required this.contentCtrl,
    required this.sending,
    required this.onSend,
  });

  @override
  State<_GroupTab> createState() => _GroupTabState();
}

class _GroupTabState extends State<_GroupTab> {
  final TextEditingController _searchCtrl = TextEditingController();
  bool _isExpanded = false;
  String _query = '';

  @override
  void initState() {
    super.initState();
    if (widget.selected != null) {
      _searchCtrl.text = widget.selected!['name'] as String;
    }
  }

  @override
  void didUpdateWidget(covariant _GroupTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selected != oldWidget.selected) {
      if (widget.selected != null) {
        _searchCtrl.text = widget.selected!['name'] as String;
      } else {
        _searchCtrl.clear();
      }
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Filter groups based on search query
    final filtered = widget.groups.where((g) {
      final name = (g['name'] as String? ?? '').toLowerCase();
      final desc = (g['description'] as String? ?? '').toLowerCase();
      final q = _query.toLowerCase();
      return name.contains(q) || desc.contains(q);
    }).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Choisir un groupe',
            style: GoogleFonts.outfit(
                color: Colors.white60, fontSize: 12,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),

        // Search Dropdown field
        FocusScope(
          child: Focus(
            onFocusChange: (hasFocus) {
              setState(() {
                _isExpanded = hasFocus;
              });
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _searchCtrl,
                  onChanged: (val) {
                    setState(() {
                      _query = val;
                      _isExpanded = true;
                    });
                  },
                  style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.primaryGreen),
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close_rounded, color: Colors.white54, size: 20),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() {
                                _query = '';
                                _isExpanded = true;
                              });
                            },
                          )
                        : const Icon(Icons.arrow_drop_down_rounded, color: Colors.white54),
                    hintText: 'Écrivez le début du nom du groupe...',
                    hintStyle: GoogleFonts.inter(color: Colors.white30, fontSize: 14),
                    filled: true,
                    fillColor: const Color(0xFF111827),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF1E2D3D)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF1E2D3D)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppTheme.primaryGreen),
                    ),
                    contentPadding: const EdgeInsets.all(14),
                  ),
                ),
                
                // Dropdown container
                if (_isExpanded && filtered.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    constraints: const BoxConstraints(maxHeight: 250),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1F2937),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: ListView(
                        shrinkWrap: true,
                        padding: const EdgeInsets.all(8),
                        children: filtered.map((g) {
                          final isSelected = widget.selected?['id'] == g['id'];
                          final color = g['color'] != null
                              ? Color(int.parse(
                                  (g['color'] as String).replaceFirst('#', '0xFF')))
                              : AppTheme.primaryGreen;
                          return InkWell(
                            onTap: () {
                              widget.onSelect(g);
                              _searchCtrl.text = g['name'] as String;
                              FocusScope.of(context).unfocus();
                              setState(() {
                                _isExpanded = false;
                                _query = '';
                              });
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              margin: const EdgeInsets.symmetric(vertical: 2),
                              decoration: BoxDecoration(
                                color: isSelected ? color.withOpacity(0.12) : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(children: [
                                Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                      color: color.withOpacity(0.2),
                                      shape: BoxShape.circle),
                                  child: Icon(Icons.groups_rounded,
                                      color: color, size: 16),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(g['name'] as String,
                                          style: GoogleFonts.outfit(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 13)),
                                      Text('${g['member_count']} membres',
                                          style: GoogleFonts.inter(
                                              color: color, fontSize: 11)),
                                    ],
                                  ),
                                ),
                                if (isSelected)
                                  Icon(Icons.check_circle_rounded,
                                      color: color, size: 18),
                              ]),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // If a group is selected, show details card and message input
        if (widget.selected != null) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.primaryGreen.withOpacity(0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.primaryGreen.withOpacity(0.3)),
            ),
            child: Row(children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                    color: AppTheme.primaryGreen.withOpacity(0.2),
                    shape: BoxShape.circle),
                child: const Icon(Icons.groups_rounded,
                    color: AppTheme.primaryGreen, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.selected!['name'] as String,
                      style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                    Text(
                      '${widget.selected!['member_count']} membres',
                      style: GoogleFonts.inter(color: Colors.white54, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ]),
          ),
          const SizedBox(height: 16),
          _MessageInput(ctrl: widget.contentCtrl, sending: widget.sending, onSend: widget.onSend),
        ],
      ],
    );
  }
}

// ── Tab Broadcast ─────────────────────────────────────────────────────────────

class _BroadcastTab extends StatefulWidget {
  final List<Map<String, dynamic>> collectors;
  final List<Map<String, dynamic>> selected;
  final void Function(Map<String, dynamic>) onToggle;
  final String groupLabel;
  final void Function(String) onLabelChange;
  final TextEditingController contentCtrl;
  final bool sending;
  final VoidCallback onSend;

  const _BroadcastTab({
    required this.collectors,
    required this.selected,
    required this.onToggle,
    required this.groupLabel,
    required this.onLabelChange,
    required this.contentCtrl,
    required this.sending,
    required this.onSend,
  });

  @override
  State<_BroadcastTab> createState() => _BroadcastTabState();
}

class _BroadcastTabState extends State<_BroadcastTab> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    // Filter collectors based on query
    final filtered = widget.collectors.where((c) {
      final name = (c['full_name'] as String? ?? '').toLowerCase();
      final email = (c['email'] as String? ?? '').toLowerCase();
      final q = _query.toLowerCase();
      return name.contains(q) || email.contains(q);
    }).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Libellé optionnel
        TextField(
          onChanged: widget.onLabelChange,
          style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
          decoration: InputDecoration(
            hintText: 'Libellé du groupe (ex: Zone Nord)',
            hintStyle: GoogleFonts.inter(color: Colors.white30, fontSize: 13),
            filled: true,
            fillColor: const Color(0xFF111827),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF1E2D3D)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF1E2D3D)),
            ),
            contentPadding: const EdgeInsets.all(14),
          ),
        ),
        const SizedBox(height: 14),

        // Search Bar for collectors
        TextField(
          onChanged: (val) {
            setState(() {
              _query = val;
            });
          },
          style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search_rounded, color: Colors.white30, size: 18),
            hintText: 'Rechercher un collecteur...',
            hintStyle: GoogleFonts.inter(color: Colors.white30, fontSize: 13),
            filled: true,
            fillColor: const Color(0xFF111827),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF1E2D3D)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF1E2D3D)),
            ),
            contentPadding: const EdgeInsets.all(12),
          ),
        ),
        const SizedBox(height: 14),

        Text('Sélectionner les collecteurs (${widget.selected.length}/${widget.collectors.length})',
            style: GoogleFonts.outfit(
                color: Colors.white60, fontSize: 12,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        ...filtered.map((c) {
          final isSelected =
              widget.selected.any((x) => x['id'] == c['id']);
          return GestureDetector(
            onTap: () => widget.onToggle(c),
            child: Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.orange.withOpacity(0.12)
                    : const Color(0xFF111827),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: isSelected
                        ? Colors.orange
                        : Colors.white10),
              ),
              child: Row(children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.orange.withOpacity(0.2),
                  child: const Icon(Icons.recycling_rounded,
                      color: Colors.orange, size: 16),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    c['full_name'] as String,
                    style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13),
                  ),
                ),
                if (isSelected)
                  const Icon(Icons.check_box_rounded,
                      color: Colors.orange, size: 20)
                else
                  const Icon(Icons.check_box_outline_blank_rounded,
                      color: Colors.white24, size: 20),
              ]),
            ),
          );
        }),
        if (widget.selected.isNotEmpty) ...[
          const SizedBox(height: 16),
          _MessageInput(
            ctrl: widget.contentCtrl,
            sending: widget.sending,
            onSend: widget.onSend,
            hint: 'Message à tous les collecteurs…',
          ),
        ],
      ],
    );
  }
}


// ── Input de message ──────────────────────────────────────────────────────────

class _MessageInput extends StatelessWidget {
  final TextEditingController ctrl;
  final bool sending;
  final VoidCallback onSend;
  final String hint;

  const _MessageInput({
    required this.ctrl,
    required this.sending,
    required this.onSend,
    this.hint = 'Écrire votre message…',
  });

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      TextField(
        controller: ctrl,
        style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
        maxLines: 4,
        minLines: 2,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.inter(color: Colors.white30, fontSize: 14),
          filled: true,
          fillColor: const Color(0xFF111827),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFF1E2D3D)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFF1E2D3D)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(
                color: AppTheme.primaryGreen, width: 1.5),
          ),
          contentPadding: const EdgeInsets.all(14),
        ),
      ),
      const SizedBox(height: 12),
      SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton.icon(
          onPressed: sending ? null : onSend,
          icon: sending
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2),
                )
              : const Icon(Icons.send_rounded, size: 18),
          label: Text(sending ? 'Envoi…' : 'Envoyer',
              style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w800, fontSize: 15)),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryGreen,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers globaux
// ─────────────────────────────────────────────────────────────────────────────

IconData _roleIcon(String role) {
  switch (role) {
    case 'admin':
    case 'superadmin':
      return Icons.shield_rounded;
    case 'intercommunality':
      return Icons.account_balance_rounded;
    case 'collector':
      return Icons.recycling_rounded;
    case 'pointManager':
      return Icons.location_on_rounded;
    case 'educator':
      return Icons.school_rounded;
    case 'user':
      return Icons.person_rounded;
    default:
      return Icons.person_rounded;
  }
}

String _roleLabel(String role) {
  switch (role) {
    case 'admin':      return 'Administrateur';
    case 'superadmin': return 'Super Admin';
    case 'intercommunality': return 'Intercommunalité';
    case 'collector':  return 'Collecteur';
    case 'pointManager': return 'Gestionnaire';
    case 'educator':   return 'Éducateur';
    case 'user':       return 'Citoyen';
    default:           return role;
  }
}

String _formatTime(String isoString) {
  try {
    final dt = DateTime.parse(isoString).toLocal();
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) {
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } else if (diff.inDays == 1) {
      return 'Hier';
    } else if (diff.inDays < 7) {
      const days = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
      return days[dt.weekday - 1];
    } else {
      return '${dt.day}/${dt.month}';
    }
  } catch (_) {
    return '';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Routes d'accès direct depuis une notification push
// Utilisées par FcmService._navigateFromPayload() pour naviguer directement
// vers la bonne conversation sans passer par la liste.
// ─────────────────────────────────────────────────────────────────────────────

/// Ouvre directement la conversation 1-à-1 avec [partnerId].
/// Utilisé lors d'un tap sur une notification push de type 'message'.
class DirectChatRoute extends StatelessWidget {
  final int    partnerId;
  final String partnerName;

  const DirectChatRoute({
    Key? key,
    required this.partnerId,
    required this.partnerName,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return _ChatScreen(
      partnerId:   partnerId,
      partnerName: partnerName,
      partnerRole: '',   // inconnu au moment du tap — chargé à l'affichage
    );
  }
}

/// Ouvre directement la conversation de groupe [groupId].
/// Utilisé lors d'un tap sur une notification push de type 'group_message'.
class GroupChatRoute extends StatelessWidget {
  final int    groupId;
  final String groupName;

  const GroupChatRoute({
    Key? key,
    required this.groupId,
    required this.groupName,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return _GroupChatScreen(
      groupId:     groupId,
      groupName:   groupName,
      groupColor:  '#2E7D32',
      memberCount: 0,   // rechargé depuis l'API
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Point animé pour l'indicateur "en cours d'écriture" (style WhatsApp)
// ─────────────────────────────────────────────────────────────────────────────

class _TypingDot extends StatefulWidget {
  final int delay;
  const _TypingDot({required this.delay});
  @override
  State<_TypingDot> createState() => _TypingDotState();
}

class _TypingDotState extends State<_TypingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _anim = Tween<double>(begin: 0, end: -5).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _ctrl.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Transform.translate(
        offset: Offset(0, _anim.value),
        child: Container(
          width: 7,
          height: 7,
          decoration: const BoxDecoration(
            color: Colors.white54,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}
