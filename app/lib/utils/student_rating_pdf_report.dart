import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:smartschool_app/generated/app_localizations.dart';

import '../models/analytics.dart';

/// Same palette as attendance_pdf_report.dart -- kept as a separate copy
/// (not shared) so each report file stays a single self-contained unit that
/// can be handed to a fresh `dart run` script for fast layout iteration,
/// matching the existing pattern in this codebase.
class _ReportColors {
  static final primary = PdfColor.fromInt(0xFF4F46E5);
  static final primaryDark = PdfColor.fromInt(0xFF4338CA);
  static final primarySoft = PdfColor.fromInt(0xFFEEF0FF);
  static final gold = PdfColor.fromInt(0xFFB8860B);
  static final goldSoft = PdfColor.fromInt(0xFFFFFBEB);
  static final success = PdfColor.fromInt(0xFF059669);
  static final successSoft = PdfColor.fromInt(0xFFECFDF5);
  static final warning = PdfColor.fromInt(0xFFB45309);
  static final warningSoft = PdfColor.fromInt(0xFFFFFBEB);
  static final danger = PdfColor.fromInt(0xFFB91C1C);
  static final dangerSoft = PdfColor.fromInt(0xFFFEF2F2);
  static final textPrimary = PdfColor.fromInt(0xFF0F172A);
  static final textSecondary = PdfColor.fromInt(0xFF64748B);
  static final textMuted = PdfColor.fromInt(0xFF94A3B8);
  static final border = PdfColor.fromInt(0xFFE2E5F0);
  static final surfaceAlt = PdfColor.fromInt(0xFFF7F8FC);
  static const white = PdfColors.white;

  static PdfColor tier(double value) {
    if (value >= 8) return success;
    if (value >= 6) return warning;
    return danger;
  }

  static PdfColor tierSoft(double value) {
    if (value >= 8) return successSoft;
    if (value >= 6) return warningSoft;
    return dangerSoft;
  }
}

String quarterLabel(AppLocalizations l, int quarter) {
  switch (quarter) {
    case 1:
      return l.quarter1;
    case 2:
      return l.quarter2;
    case 3:
      return l.quarter3;
    default:
      return l.quarter4;
  }
}

/// Loads fonts and hands the finished PDF to the system print/save dialog --
/// the data is already loaded on screen (StudentAnalyticsOverview), so
/// unlike the attendance report this needs no extra network call.
Future<void> generateStudentRatingPdf({
  required BuildContext context,
  required StudentAnalyticsOverview overview,
}) async {
  final l10n = AppLocalizations.of(context)!;

  final regularData = await rootBundle.load('assets/fonts/NotoSans-Regular.ttf');
  final boldData = await rootBundle.load('assets/fonts/NotoSans-Bold.ttf');

  final bytes = await buildStudentRatingPdfBytes(
    l10n: l10n,
    overview: overview,
    regularFontBytes: regularData.buffer.asUint8List(),
    boldFontBytes: boldData.buffer.asUint8List(),
  );
  await Printing.layoutPdf(
    onLayout: (_) async => bytes,
    name: 'rating-${overview.firstName}-${overview.lastName}-q${overview.quarter}.pdf',
  );
}

/// Pure PDF-building step (no BuildContext/network/asset-bundle dependency).
Future<Uint8List> buildStudentRatingPdfBytes({
  required AppLocalizations l10n,
  required StudentAnalyticsOverview overview,
  required Uint8List regularFontBytes,
  required Uint8List boldFontBytes,
}) async {
  final regular = pw.Font.ttf(regularFontBytes.buffer.asByteData());
  final bold = pw.Font.ttf(boldFontBytes.buffer.asByteData());

  final generatedOn = DateTime.now();
  final generatedLabel =
      '${generatedOn.day.toString().padLeft(2, '0')}.${generatedOn.month.toString().padLeft(2, '0')}.${generatedOn.year} '
      '${generatedOn.hour.toString().padLeft(2, '0')}:${generatedOn.minute.toString().padLeft(2, '0')}';

  final doc = pw.Document(theme: pw.ThemeData.withFont(base: regular, bold: bold));

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(30, 30, 30, 26),
      footer: (ctx) => pw.Container(
        margin: const pw.EdgeInsets.only(top: 10),
        padding: const pw.EdgeInsets.only(top: 8),
        decoration: pw.BoxDecoration(
          border: pw.Border(top: pw.BorderSide(color: _ReportColors.border, width: 0.6)),
        ),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Row(
              children: [
                pw.Container(
                  width: 5,
                  height: 5,
                  decoration: pw.BoxDecoration(color: _ReportColors.primary, shape: pw.BoxShape.circle),
                ),
                pw.SizedBox(width: 5),
                pw.Text(
                  'SmartSchool  ·  $generatedLabel',
                  style: pw.TextStyle(font: regular, fontSize: 8, color: _ReportColors.textMuted),
                ),
              ],
            ),
            pw.Text(
              '${ctx.pageNumber} / ${ctx.pagesCount}',
              style: pw.TextStyle(font: regular, fontSize: 8, color: _ReportColors.textMuted),
            ),
          ],
        ),
      ),
      build: (ctx) => [
        // Header band
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.fromLTRB(22, 20, 22, 20),
          decoration: pw.BoxDecoration(
            gradient: pw.LinearGradient(
              begin: pw.Alignment.topLeft,
              end: pw.Alignment.bottomRight,
              colors: [_ReportColors.primary, _ReportColors.primaryDark],
            ),
            borderRadius: pw.BorderRadius.circular(14),
          ),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Container(
                width: 42,
                height: 42,
                alignment: pw.Alignment.center,
                decoration: pw.BoxDecoration(color: PdfColors.white, borderRadius: pw.BorderRadius.circular(11)),
                child: pw.Text('S', style: pw.TextStyle(font: bold, fontSize: 21, color: _ReportColors.primary)),
              ),
              pw.SizedBox(width: 14),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      l10n.pdfRatingEyebrow,
                      style: pw.TextStyle(font: bold, fontSize: 8.5, color: PdfColor.fromInt(0xCCFFFFFF), letterSpacing: 1.4),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      '${overview.firstName} ${overview.lastName}',
                      style: pw.TextStyle(font: bold, fontSize: 23, color: PdfColors.white),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      quarterLabel(l10n, overview.quarter),
                      style: pw.TextStyle(font: regular, fontSize: 11.5, color: PdfColor.fromInt(0xE6FFFFFF)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 18),

        // Stat row: overall average + 3 ranks
        pw.Row(
          children: [
            _statCard(
              l10n.overallAverage,
              overview.overallAverage == null ? '—' : overview.overallAverage!.toStringAsFixed(2),
              _ReportColors.primary,
              _ReportColors.primarySoft,
              bold,
              regular,
            ),
            pw.SizedBox(width: 10),
            _statCard(
              l10n.classRank,
              _rankText(overview.classRank),
              _rankTierColor(overview.classRank),
              _rankTierSoftColor(overview.classRank),
              bold,
              regular,
            ),
            pw.SizedBox(width: 10),
            _statCard(
              l10n.parallelRank,
              _rankText(overview.parallelRank),
              _rankTierColor(overview.parallelRank),
              _rankTierSoftColor(overview.parallelRank),
              bold,
              regular,
            ),
            pw.SizedBox(width: 10),
            _statCard(
              l10n.schoolRank,
              _rankText(overview.schoolRank),
              _rankTierColor(overview.schoolRank),
              _rankTierSoftColor(overview.schoolRank),
              bold,
              regular,
            ),
          ],
        ),
        pw.SizedBox(height: 10),

        if (overview.lessonAttendanceRate != null)
          pw.Row(
            children: [
              _statCard(
                l10n.lessonAttendanceRate,
                '${overview.lessonAttendanceRate!.toStringAsFixed(0)}%',
                _ReportColors.tier(overview.lessonAttendanceRate! / 10),
                _ReportColors.tierSoft(overview.lessonAttendanceRate! / 10),
                bold,
                regular,
              ),
            ],
          ),
        pw.SizedBox(height: 18),

        if (_hasComparisons(overview))
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(14),
            decoration: pw.BoxDecoration(
              color: _ReportColors.surfaceAlt,
              borderRadius: pw.BorderRadius.circular(12),
              border: pw.Border.all(color: _ReportColors.border, width: 0.6),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                if (overview.classAverage != null)
                  _comparisonLine(l10n.classAverage, overview.overallAverage!, overview.classAverage!, bold, regular),
                if (overview.parallelAverage != null)
                  _comparisonLine(l10n.parallelAverage, overview.overallAverage!, overview.parallelAverage!, bold, regular),
                if (overview.schoolAverage != null)
                  _comparisonLine(l10n.schoolAverage, overview.overallAverage!, overview.schoolAverage!, bold, regular),
              ],
            ),
          ),
        pw.SizedBox(height: 18),

        if (overview.strongestSubject != null || overview.weakestSubject != null)
          pw.Row(
            children: [
              if (overview.strongestSubject != null)
                _highlightCard(l10n.strongestSubject, overview.strongestSubject!, _ReportColors.success, _ReportColors.successSoft, bold, regular),
              if (overview.strongestSubject != null && overview.weakestSubject != null) pw.SizedBox(width: 10),
              if (overview.weakestSubject != null)
                _highlightCard(l10n.weakestSubject, overview.weakestSubject!, _ReportColors.danger, _ReportColors.dangerSoft, bold, regular),
            ],
          ),
        pw.SizedBox(height: 22),

        pw.Text(
          l10n.subjectBreakdown,
          style: pw.TextStyle(font: bold, fontSize: 13, color: _ReportColors.textPrimary),
        ),
        pw.SizedBox(height: 10),

        if (overview.subjectBreakdown.isEmpty)
          pw.Container(
            padding: const pw.EdgeInsets.all(28),
            alignment: pw.Alignment.center,
            decoration: pw.BoxDecoration(
              color: _ReportColors.surfaceAlt,
              borderRadius: pw.BorderRadius.circular(12),
              border: pw.Border.all(color: _ReportColors.border, width: 0.6),
            ),
            child: pw.Text(
              l10n.noGradesYetMessage,
              style: pw.TextStyle(font: regular, fontSize: 11, color: _ReportColors.textSecondary),
            ),
          )
        else
          pw.Table(
            border: pw.TableBorder.all(color: _ReportColors.border, width: 0.6),
            columnWidths: const {0: pw.FlexColumnWidth(3), 1: pw.FlexColumnWidth(1.4), 2: pw.FlexColumnWidth(2.2)},
            children: [
              pw.TableRow(
                decoration: pw.BoxDecoration(color: _ReportColors.primary),
                children: [l10n.subjectBreakdown, l10n.overallAverage, l10n.gradeCountSuffix]
                    .map(
                      (h) => pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                        child: pw.Text(h, style: pw.TextStyle(font: bold, fontSize: 8.5, color: PdfColors.white)),
                      ),
                    )
                    .toList(),
              ),
              for (final entry in overview.subjectBreakdown.asMap().entries)
                pw.TableRow(
                  decoration: pw.BoxDecoration(
                    color: entry.key.isEven ? _ReportColors.white : _ReportColors.surfaceAlt,
                  ),
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      child: pw.Text(
                        entry.value.subject,
                        style: pw.TextStyle(font: regular, fontSize: 9.5, color: _ReportColors.textPrimary),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      child: _subjectAverageBar(entry.value.average, bold),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      child: pw.Text(
                        '${entry.value.gradeCount}',
                        style: pw.TextStyle(font: regular, fontSize: 9.5, color: _ReportColors.textSecondary),
                      ),
                    ),
                  ],
                ),
            ],
          ),
      ],
    ),
  );

  return doc.save();
}

String _rankText(RankInfo rank) => rank.position == null ? '—' : '${rank.position}/${rank.outOf}';

/// Rank quality by percentile rather than always gold -- a student ranked
/// near the bottom of a small class shouldn't get the same celebratory
/// gold card as the actual top performer.
PdfColor _rankTierColor(RankInfo rank) {
  if (rank.position == null || rank.outOf == 0) return _ReportColors.textMuted;
  final fraction = rank.position! / rank.outOf;
  if (fraction <= 0.1) return _ReportColors.gold;
  if (fraction <= 0.5) return _ReportColors.success;
  if (fraction <= 0.8) return _ReportColors.warning;
  return _ReportColors.danger;
}

PdfColor _rankTierSoftColor(RankInfo rank) {
  if (rank.position == null || rank.outOf == 0) return _ReportColors.surfaceAlt;
  final fraction = rank.position! / rank.outOf;
  if (fraction <= 0.1) return _ReportColors.goldSoft;
  if (fraction <= 0.5) return _ReportColors.successSoft;
  if (fraction <= 0.8) return _ReportColors.warningSoft;
  return _ReportColors.dangerSoft;
}

bool _hasComparisons(StudentAnalyticsOverview overview) =>
    overview.overallAverage != null &&
    (overview.classAverage != null || overview.parallelAverage != null || overview.schoolAverage != null);

pw.Widget _comparisonLine(String label, double own, double group, pw.Font bold, pw.Font regular) {
  final delta = own - group;
  final deltaColor = delta >= 0 ? _ReportColors.success : _ReportColors.danger;
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 3),
    child: pw.Row(
      children: [
        pw.Expanded(
          child: pw.Text(label, style: pw.TextStyle(font: regular, fontSize: 9.5, color: _ReportColors.textSecondary)),
        ),
        pw.Text(group.toStringAsFixed(2), style: pw.TextStyle(font: bold, fontSize: 9.5, color: _ReportColors.textPrimary)),
        pw.SizedBox(width: 8),
        pw.Text(
          '${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(2)}',
          style: pw.TextStyle(font: bold, fontSize: 9.5, color: deltaColor),
        ),
      ],
    ),
  );
}

pw.Widget _highlightCard(String label, String subject, PdfColor accent, PdfColor soft, pw.Font bold, pw.Font regular) {
  return pw.Expanded(
    child: pw.Container(
      padding: const pw.EdgeInsets.all(11),
      decoration: pw.BoxDecoration(
        color: soft,
        borderRadius: pw.BorderRadius.circular(11),
        border: pw.Border.all(color: _ReportColors.border, width: 0.5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label, style: pw.TextStyle(font: regular, fontSize: 8, color: _ReportColors.textSecondary)),
          pw.SizedBox(height: 3),
          pw.Text(subject, style: pw.TextStyle(font: bold, fontSize: 12, color: accent)),
        ],
      ),
    ),
  );
}

pw.Widget _subjectAverageBar(double average, pw.Font bold) {
  final color = _ReportColors.tier(average);
  final fraction = (average / 10).clamp(0.0, 1.0);
  const barWidth = 42.0;
  return pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.center,
    children: [
      pw.Container(
        width: barWidth,
        height: 7,
        decoration: pw.BoxDecoration(color: _ReportColors.border, borderRadius: pw.BorderRadius.circular(3.5)),
        child: pw.Align(
          alignment: pw.Alignment.centerLeft,
          child: pw.Container(
            width: barWidth * fraction,
            height: 7,
            decoration: pw.BoxDecoration(color: color, borderRadius: pw.BorderRadius.circular(3.5)),
          ),
        ),
      ),
      pw.SizedBox(width: 8),
      pw.Text(average.toStringAsFixed(1), style: pw.TextStyle(font: bold, fontSize: 9.5, color: color)),
    ],
  );
}

pw.Widget _statCard(
  String label,
  String value,
  PdfColor accent,
  PdfColor soft,
  pw.Font bold,
  pw.Font regular,
) {
  return pw.Expanded(
    child: pw.Container(
      decoration: pw.BoxDecoration(
        color: soft,
        borderRadius: pw.BorderRadius.circular(11),
        border: pw.Border.all(color: _ReportColors.border, width: 0.5),
      ),
      child: pw.Row(
        children: [
          pw.Container(
            width: 3,
            height: 54,
            decoration: pw.BoxDecoration(
              color: accent,
              borderRadius: const pw.BorderRadius.only(
                topLeft: pw.Radius.circular(11),
                bottomLeft: pw.Radius.circular(11),
              ),
            ),
          ),
          pw.Expanded(
            child: pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 11),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(value, style: pw.TextStyle(font: bold, fontSize: 16, color: accent)),
                  pw.SizedBox(height: 3),
                  pw.Text(
                    label,
                    style: pw.TextStyle(font: regular, fontSize: 8, color: _ReportColors.textSecondary),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
