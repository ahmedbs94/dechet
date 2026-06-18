// lib/widgets/meetings_section.dart
// ─────────────────────────────────────────────────────────────────────────────
// Widget "Mes Séances" intégré dans l'onglet Formation du citoyen.
// Affiche les séances à venir avec leur lien Google Meet.
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/meetings_service.dart';
import '../theme/app_theme.dart';

class MeetingsSection extends StatefulWidget {
  const MeetingsSection({Key? key}) : super(key: key);

  @override
  State<MeetingsSection> createState() => _MeetingsSectionState();
}

class _MeetingsSectionState extends State<MeetingsSection> {
  List<dynamic> _meetings = [];
  bool _loading = true;

  static const _kGreen  = Color(0xFF00C896);

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('fr', null).then((_) => _load());
  }

  Future<void> _load() async {
    final data = await MeetingsService.getUpcomingMeetings();
    if (mounted) setState(() { _meetings = data; _loading = false; });
  }

  Future<void> _respond(int meetingId, String status) async {
    final ok = await MeetingsService.respondToMeeting(meetingId, status);
    if (ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(status == 'confirmed' ? 'Participation confirmée !' : 'Invitation déclinée'),
        backgroundColor: status == 'confirmed' ? _kGreen : Colors.orange,
      ));
      _load();
    }
  }

  Future<void> _openMeet(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── En-tête de section ────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 14),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _kGreen.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.video_camera_front_rounded,
                  color: _kGreen, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Mes Séances', style: GoogleFonts.outfit(
                  color: Theme.of(context).brightness == Brightness.dark ? Colors.white : AppTheme.deepSlate, fontSize: 18, fontWeight: FontWeight.bold)),
              Text('Google Meet avec votre éducateur', style: GoogleFonts.inter(
                  color: Theme.of(context).brightness == Brightness.dark ? Colors.white54 : AppTheme.textMuted, fontSize: 12)),
            ])),
            IconButton(
              icon: Icon(Icons.refresh_rounded, color: Theme.of(context).brightness == Brightness.dark ? Colors.white54 : AppTheme.textMuted),
              onPressed: () { setState(() => _loading = true); _load(); },
            ),
          ]),
        ),

        // ── Contenu ───────────────────────────────────────────────────────
        if (_loading)
          const Center(child: Padding(
            padding: EdgeInsets.all(40),
            child: CircularProgressIndicator(color: _kGreen, strokeWidth: 2),
          ))
        else if (_meetings.isEmpty)
          _EmptyState()
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: _meetings.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) => _MeetingCard(
              meeting: _meetings[i],
              onRespond: _respond,
              onJoin: _openMeet,
            ),
          ),
        const SizedBox(height: 24),
      ],
    );
  }
}

// ── Carte d'une séance ────────────────────────────────────────────────────────

class _MeetingCard extends StatelessWidget {
  final Map<String, dynamic> meeting;
  final Future<void> Function(int id, String status) onRespond;
  final void Function(String url) onJoin;

  static const _kGreen = Color(0xFF00C896);
  static const _kCard  = Color(0xFF1E2D3D);

  const _MeetingCard({
    required this.meeting,
    required this.onRespond,
    required this.onJoin,
  });

  Color _statusColor(String s) {
    switch (s) {
      case 'confirmed': return _kGreen;
      case 'declined':  return Colors.orange;
      default:          return Colors.blue;
    }
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'confirmed': return 'Confirmée';
      case 'declined':  return 'Déclinée';
      default:          return 'En attente';
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheduledAt  = DateTime.tryParse(meeting['scheduled_at'] ?? '') ?? DateTime.now();
    final duration     = meeting['duration_minutes'] ?? 60;
    final myStatus     = meeting['my_status'] ?? 'invited';
    final isNow = DateTime.now().isAfter(scheduledAt.subtract(const Duration(minutes: 15)))
               && DateTime.now().isBefore(scheduledAt.add(Duration(minutes: duration)));

    return Container(
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(16),
        border: isNow
          ? Border.all(color: _kGreen, width: 1.5)
          : Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Header ──────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
          decoration: BoxDecoration(
            color: _kGreen.withOpacity(0.06),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Row(children: [
            Expanded(child: Text(
              meeting['title'] ?? '',
              style: GoogleFonts.outfit(
                color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            )),
            if (isNow)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _kGreen,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('EN COURS', style: GoogleFonts.outfit(
                    color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold)),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _statusColor(myStatus).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_statusLabel(myStatus), style: GoogleFonts.outfit(
                    color: _statusColor(myStatus), fontSize: 11, fontWeight: FontWeight.w600)),
              ),
          ]),
        ),

        // ── Body ────────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Éducateur
            _InfoRow(Icons.person_rounded,
              meeting['educator_name'] ?? 'Éducateur'),
            const SizedBox(height: 8),
            // Date & heure
            _InfoRow(Icons.calendar_today_rounded,
              DateFormat('EEEE dd MMMM yyyy à HH:mm', 'fr').format(scheduledAt)),
            const SizedBox(height: 8),
            // Durée
            _InfoRow(Icons.timer_rounded, '$duration minutes'),
            if ((meeting['group_name'] as String? ?? '').isNotEmpty) ...[
              const SizedBox(height: 8),
              _InfoRow(Icons.group_rounded, meeting['group_name']),
            ],
            if ((meeting['description'] as String? ?? '').isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(meeting['description'], style: GoogleFonts.inter(
                  color: Colors.white60, fontSize: 13, height: 1.5)),
            ],
            const SizedBox(height: 14),

            // ── Actions ──────────────────────────────────────────────────
            Row(children: [
              // Bouton rejoindre
              Expanded(child: ElevatedButton.icon(
                onPressed: () => onJoin(meeting['meet_link'] ?? ''),
                icon: const Icon(Icons.video_camera_front_rounded, size: 18),
                label: Text('Rejoindre', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kGreen,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              )),
              if (myStatus == 'invited') ...[
                const SizedBox(width: 8),
                // Confirmer
                IconButton(
                  onPressed: () => onRespond(meeting['id'], 'confirmed'),
                  icon: const Icon(Icons.check_circle_rounded, color: _kGreen),
                  tooltip: 'Confirmer',
                ),
                // Décliner
                IconButton(
                  onPressed: () => onRespond(meeting['id'], 'declined'),
                  icon: const Icon(Icons.cancel_rounded, color: Colors.orange),
                  tooltip: 'Décliner',
                ),
              ],
            ]),
          ]),
        ),
      ]),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoRow(this.icon, this.text);

  @override
  Widget build(BuildContext context) => Row(children: [
    Icon(icon, color: const Color(0xFF00C896), size: 16),
    const SizedBox(width: 8),
    Expanded(child: Text(text, style: GoogleFonts.inter(color: Colors.white70, fontSize: 13))),
  ]);
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 30),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF00C896).withOpacity(0.08),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.event_available_rounded,
              color: Color(0xFF00C896), size: 44),
        ),
        const SizedBox(height: 16),
        Text('Aucune séance à venir',
          style: GoogleFonts.outfit(color: Theme.of(context).brightness == Brightness.dark ? Colors.white : AppTheme.deepSlate, fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Text("Votre éducateur planifiera prochainement\nune séance Google Meet avec vous.",
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(color: Theme.of(context).brightness == Brightness.dark ? Colors.white54 : AppTheme.textMuted, fontSize: 13, height: 1.5)),
      ]),
    ),
  );
}
