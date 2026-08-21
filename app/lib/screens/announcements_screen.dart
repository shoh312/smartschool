import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smartschool_app/generated/app_localizations.dart';

import '../core/design_tokens.dart';
import '../models/announcement.dart';
import '../models/app_role.dart';
import '../providers/auth_provider.dart';
import '../services/announcement_service.dart';
import '../widgets/analytics/analytics_widgets.dart';
import '../widgets/app_list_card.dart';
import '../widgets/app_loading_indicator.dart';
import '../widgets/app_shell.dart';
import '../widgets/bottom_nav_inset.dart';
import '../widgets/dashboard/dashboard_widgets.dart';
import '../widgets/empty_state.dart';

/// A reverse-chronological feed of the director's posts (e.g. "Payshanba
/// kuni yig'ilish"). Director gets a "+" to post; teacher (local server) and
/// parent (via [studentId], through the Public Server) are read-only.
class AnnouncementsScreen extends StatefulWidget {
  const AnnouncementsScreen({super.key, this.studentId});

  /// Set only when opened from the parent flow.
  final int? studentId;

  @override
  State<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends State<AnnouncementsScreen> {
  List<Announcement>? _announcements;
  bool _loading = true;
  String? _error;

  bool get _isParent => widget.studentId != null;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final service = context.read<AnnouncementService>();
      final announcements = _isParent
          ? await service.fetchStudentAnnouncements(widget.studentId!)
          : await service.fetchAnnouncements();
      if (mounted) setState(() => _announcements = announcements);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _post() async {
    final result = await showDialog<(String, String)>(
      context: context,
      builder: (context) => const _AnnouncementFormDialog(),
    );
    if (result == null) return;

    final l10n = AppLocalizations.of(context)!;
    try {
      await context.read<AnnouncementService>().createAnnouncement(title: result.$1, body: result.$2);
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.errorPrefix(e.toString()))));
      }
    }
  }

  Future<void> _delete(Announcement announcement) async {
    final l10n = AppLocalizations.of(context)!;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteAnnouncementTitle),
        content: Text(l10n.deleteAnnouncementConfirm),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.cancel)),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.delete, style: TextStyle(color: context.colors.danger)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await context.read<AnnouncementService>().deleteAnnouncement(announcement.id);
      setState(() => _announcements?.removeWhere((a) => a.id == announcement.id));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.errorPrefix(e.toString()))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDirector = !_isParent && context.watch<AuthProvider>().role == AppRole.director;
    final announcements = _announcements;

    return AppShell(
      title: l10n.announcements,
      actions: [
        if (isDirector)
          IconButton(icon: const Icon(Icons.add_rounded), onPressed: _post, tooltip: l10n.postAnnouncement),
      ],
      child: _loading
          ? const AppLoadingIndicator()
          : _error != null
              ? Center(child: Text(l10n.errorPrefix(_error!)))
              : announcements == null || announcements.isEmpty
                  ? EmptyState(icon: Icons.campaign_outlined, title: l10n.noDataTitle, message: l10n.noAnnouncementsYet)
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        padding: (const EdgeInsets.fromLTRB(16, 8, 16, 16)).add(bottomNavPadding(context)),
                        children: [
                          DashboardSectionHeader(title: l10n.announcements),
                          for (var i = 0; i < announcements.length; i++)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: FadeSlideIn(
                                delay: i < 12 ? Duration(milliseconds: 40 * i) : Duration.zero,
                                child: AppCard(
                                  padding: const EdgeInsets.all(14),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const AppListBadge(icon: Icons.campaign_outlined),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  announcements[i].title,
                                                  style: TextStyle(
                                                    color: context.colors.textPrimary,
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 15,
                                                  ),
                                                ),
                                                if (announcements[i].createdAt != null)
                                                  Padding(
                                                    padding: const EdgeInsets.only(top: 2),
                                                    child: Text(
                                                      _formatDate(announcements[i].createdAt!),
                                                      style: TextStyle(
                                                        fontSize: 12.5,
                                                        color: context.colors.textMuted,
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                          if (isDirector)
                                            IconButton(
                                              icon: Icon(Icons.delete_outline, size: 20, color: context.colors.danger),
                                              onPressed: () => _delete(announcements[i]),
                                              padding: EdgeInsets.zero,
                                              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        announcements[i].body,
                                        style: TextStyle(
                                          fontSize: 13.5,
                                          height: 1.35,
                                          color: context.colors.textPrimary,
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
    );
  }

  String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
}

class _AnnouncementFormDialog extends StatefulWidget {
  const _AnnouncementFormDialog();

  @override
  State<_AnnouncementFormDialog> createState() => _AnnouncementFormDialogState();
}

class _AnnouncementFormDialogState extends State<_AnnouncementFormDialog> {
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l10n.postAnnouncement),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _titleController,
              decoration: InputDecoration(labelText: l10n.announcementTitleLabel),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _bodyController,
              maxLines: 4,
              decoration: InputDecoration(labelText: l10n.announcementBodyLabel),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
        ElevatedButton(
          onPressed: () {
            if (_titleController.text.trim().isEmpty || _bodyController.text.trim().isEmpty) return;
            Navigator.pop(context, (_titleController.text.trim(), _bodyController.text.trim()));
          },
          child: Text(l10n.save),
        ),
      ],
    );
  }
}
