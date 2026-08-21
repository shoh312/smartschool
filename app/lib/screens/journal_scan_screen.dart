import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:smartschool_app/generated/app_localizations.dart';

import '../core/design_tokens.dart';
import '../models/journal_scan_result.dart';
import '../providers/teacher_provider.dart';
import '../services/journal_service.dart';
import '../utils/error_formatter.dart';
import '../widgets/app_loading_indicator.dart';
import '../widgets/app_shell.dart';
import '../widgets/bottom_nav_inset.dart';
import '../widgets/empty_state.dart';

/// Teacher-only: photographs a page of the paper journal, sends it to the
/// backend (which reads it via Gemini vision and fuzzy-matches names against
/// the class roster), then lets the teacher review/fix every row before any
/// grade is actually written -- confirming re-uses the same POST /grades
/// path manual entry already goes through, one call per row.
class JournalScanScreen extends StatefulWidget {
  const JournalScanScreen({
    super.key,
    required this.classId,
    required this.className,
    required this.subject,
  });

  final int classId;
  final String className;
  final String subject;

  @override
  State<JournalScanScreen> createState() => _JournalScanScreenState();
}

class _JournalScanScreenState extends State<JournalScanScreen> {
  final _picker = ImagePicker();
  List<JournalScanResult>? _results;
  bool _scanning = false;
  bool _saving = false;
  String? _error;

  Future<void> _pickAndScan(ImageSource source) async {
    final l10n = AppLocalizations.of(context)!;
    XFile? image;
    try {
      image = await _picker.pickImage(source: source, imageQuality: 90, maxWidth: 2000);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.cameraNotAvailable)));
      }
      return;
    }
    if (image == null) return;

    setState(() {
      _scanning = true;
      _error = null;
      _results = null;
    });
    try {
      final results = await context.read<JournalService>().scanJournalPhoto(
            classId: widget.classId,
            subject: widget.subject,
            imagePath: image.path,
          );
      if (mounted) setState(() => _results = results);
    } catch (e) {
      if (mounted) setState(() => _error = humanReadableError(classifyError(e), l10n));
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  Future<void> _confirmAll() async {
    final l10n = AppLocalizations.of(context)!;
    final results = _results;
    if (results == null) return;

    final rowsToSave = results.where((r) => r.studentId != null && !r.absent && r.grade != null).toList();
    if (rowsToSave.isEmpty) return;

    setState(() => _saving = true);
    final teacherProvider = context.read<TeacherProvider>();
    var successCount = 0;
    for (final row in rowsToSave) {
      final ok = await teacherProvider.submitGrade(
        studentId: row.studentId!,
        classId: widget.classId,
        subject: widget.subject,
        value: row.grade!,
      );
      if (ok) successCount++;
    }
    if (!mounted) return;
    setState(() => _saving = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.journalScanSavedCount(successCount, rowsToSave.length))),
    );
    if (successCount == rowsToSave.length) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final results = _results;

    return AppShell(
      title: '${l10n.journalScanTitle} · ${widget.className}',
      child: _scanning
          ? const AppLoadingIndicator()
          : results == null
              ? _PickPrompt(error: _error, onPick: _pickAndScan)
              : results.isEmpty
                  ? EmptyState(icon: Icons.search_off_rounded, title: l10n.journalScanEmptyTitle, message: l10n.journalScanEmptyMessage)
                  : Column(
                      children: [
                        Expanded(
                          child: ListView.separated(
                            padding: (const EdgeInsets.all(16)).add(bottomNavPadding(context)),
                            itemCount: results.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (context, index) => _ScanResultCard(
                              result: results[index],
                              onChanged: () => setState(() {}),
                            ),
                          ),
                        ),
                        SafeArea(
                          top: false,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            child: FilledButton.icon(
                              onPressed: _saving ? null : _confirmAll,
                              icon: _saving
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : const Icon(Icons.check_rounded),
                              label: Text(l10n.journalScanConfirmAll),
                              style: FilledButton.styleFrom(
                                minimumSize: const Size.fromHeight(52),
                                shape: RoundedRectangleBorder(borderRadius: AppRadius.mdRadius),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
    );
  }
}

class _PickPrompt extends StatelessWidget {
  const _PickPrompt({required this.error, required this.onPick});

  final String? error;
  final ValueChanged<ImageSource> onPick;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.document_scanner_outlined, size: 64, color: context.colors.textMuted),
            const SizedBox(height: 16),
            Text(
              l10n.journalScanPrompt,
              textAlign: TextAlign.center,
              style: TextStyle(color: context.colors.textSecondary, fontSize: 14),
            ),
            if (error != null) ...[
              const SizedBox(height: 12),
              Text(l10n.errorPrefix(error!), style: TextStyle(color: context.colors.danger, fontSize: 13)),
            ],
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => onPick(ImageSource.camera),
              icon: const Icon(Icons.camera_alt_outlined),
              label: Text(l10n.journalScanTakePhoto),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(borderRadius: AppRadius.mdRadius),
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => onPick(ImageSource.gallery),
              icon: const Icon(Icons.photo_library_outlined),
              label: Text(l10n.journalScanPickGallery),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(borderRadius: AppRadius.mdRadius),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Color _gradeColor(BuildContext context, int value) {
  if (value >= 9) return context.colors.success;
  if (value >= 7) return context.colors.info;
  if (value >= 5) return context.colors.warning;
  return context.colors.danger;
}

class _ScanResultCard extends StatelessWidget {
  const _ScanResultCard({required this.result, required this.onChanged});

  final JournalScanResult result;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final matched = result.studentId != null;
    final uncertain = matched && result.confidence < 0.6;
    final flagged = !matched || uncertain;
    final displayName = matched ? result.matchedName! : result.rawName;
    final gradeColor = _gradeColor(context, result.grade ?? 5);
    final flagColor = !matched ? context.colors.danger : context.colors.warning;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: AppRadius.lgRadius,
        border: Border.all(color: flagged ? flagColor.withOpacity(0.5) : context.colors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              gradient: flagged ? null : AppGradients.tint(context.colors.primary),
              color: flagged ? flagColor.withOpacity(0.12) : null,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: !matched
                ? Icon(Icons.person_off_outlined, size: 18, color: flagColor)
                : uncertain
                    ? Icon(Icons.help_outline_rounded, size: 18, color: flagColor)
                    : Text(
                        displayName.isEmpty ? '?' : displayName[0].toUpperCase(),
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: context.colors.primary),
                      ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5, color: context.colors.textPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  !matched
                      ? l10n.journalScanNoMatch(result.rawName)
                      : result.confidence < 0.85
                          ? l10n.journalScanRawName(result.rawName)
                          : '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: flagged ? flagColor : context.colors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (result.absent)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: context.colors.textMuted.withOpacity(0.12),
                borderRadius: AppRadius.mdRadius,
              ),
              child: Text(
                l10n.journalScanAbsent,
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: context.colors.textSecondary),
              ),
            )
          else
            _GradeStepper(
              value: result.grade ?? 5,
              color: gradeColor,
              onChanged: (v) {
                result.grade = v;
                onChanged();
              },
            ),
        ],
      ),
    );
  }
}

class _GradeStepper extends StatelessWidget {
  const _GradeStepper({required this.value, required this.color, required this.onChanged});

  final int value;
  final Color color;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: AppRadius.mdRadius,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.remove_rounded, size: 18),
            color: color,
            visualDensity: VisualDensity.compact,
            onPressed: value > 1 ? () => onChanged(value - 1) : null,
          ),
          SizedBox(
            width: 22,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: color),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add_rounded, size: 18),
            color: color,
            visualDensity: VisualDensity.compact,
            onPressed: value < 10 ? () => onChanged(value + 1) : null,
          ),
        ],
      ),
    );
  }
}
