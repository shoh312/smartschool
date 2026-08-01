import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:smartschool_app/generated/app_localizations.dart';

import '../services/api_client.dart';

class MonthlyStudentSummary {
  const MonthlyStudentSummary({
    required this.studentId,
    required this.firstName,
    required this.lastName,
    required this.presentDays,
    required this.lateDays,
    required this.absentDays,
    required this.totalPresentHours,
    required this.totalAbsentHours,
    required this.attendanceRate,
  });

  final int studentId;
  final String firstName;
  final String lastName;
  final int presentDays;
  final int lateDays;
  final int absentDays;
  final double totalPresentHours;
  final double totalAbsentHours;
  final double attendanceRate;

  factory MonthlyStudentSummary.fromJson(Map<String, dynamic> json) {
    return MonthlyStudentSummary(
      studentId: json['student_id'] as int,
      firstName: json['first_name'] as String? ?? '',
      lastName: json['last_name'] as String? ?? '',
      presentDays: json['present_days'] as int? ?? 0,
      lateDays: json['late_days'] as int? ?? 0,
      absentDays: json['absent_days'] as int? ?? 0,
      totalPresentHours: (json['total_present_hours'] as num?)?.toDouble() ?? 0,
      totalAbsentHours: (json['total_absent_hours'] as num?)?.toDouble() ?? 0,
      attendanceRate: (json['attendance_rate'] as num?)?.toDouble() ?? 0,
    );
  }
}

class MonthlyClassReport {
  const MonthlyClassReport({
    required this.classId,
    required this.className,
    required this.students,
  });

  final int classId;
  final String className;
  final List<MonthlyStudentSummary> students;

  factory MonthlyClassReport.fromJson(Map<String, dynamic> json) {
    final raw = json['students'] as List<dynamic>? ?? [];
    return MonthlyClassReport(
      classId: json['class_id'] as int,
      className: json['class_name'] as String? ?? '',
      students: raw
          .map((e) => MonthlyStudentSummary.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class _ReportColors {
  static final primary = PdfColor.fromInt(0xFF4F46E5);
  static final primaryDark = PdfColor.fromInt(0xFF4338CA);
  static final primarySoft = PdfColor.fromInt(0xFFEEF0FF);
  static final info = PdfColor.fromInt(0xFF2563EB);
  static final infoSoft = PdfColor.fromInt(0xFFEFF6FF);
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

  static PdfColor tier(double rate) {
    if (rate >= 80) return success;
    if (rate >= 60) return warning;
    return danger;
  }

  static PdfColor tierSoft(double rate) {
    if (rate >= 80) return successSoft;
    if (rate >= 60) return warningSoft;
    return dangerSoft;
  }
}

/// Fetches the monthly attendance summary for a single class and lays it out
/// as a print/save-ready PDF (via the system print dialog).
Future<void> generateClassMonthlyReportPdf({
  required BuildContext context,
  required int classId,
  required String className,
  required int year,
  required int month,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final api = context.read<ApiClient>();

  final data =
      await api.get(
            '/attendance/monthly-report',
            query: {'year': '$year', 'month': '$month', 'class_id': '$classId'},
          )
          as List<dynamic>;
  final reports = data
      .map((e) => MonthlyClassReport.fromJson(e as Map<String, dynamic>))
      .toList();
  final students = List<MonthlyStudentSummary>.from(
    reports.isEmpty ? <MonthlyStudentSummary>[] : reports.first.students,
  )..sort((a, b) => b.attendanceRate.compareTo(a.attendanceRate));

  final regularData = await rootBundle.load(
    'assets/fonts/NotoSans-Regular.ttf',
  );
  final boldData = await rootBundle.load('assets/fonts/NotoSans-Bold.ttf');

  final bytes = await buildAttendanceReportPdfBytes(
    l10n: l10n,
    className: className,
    year: year,
    month: month,
    students: students,
    regularFontBytes: regularData.buffer.asUint8List(),
    boldFontBytes: boldData.buffer.asUint8List(),
  );
  await Printing.layoutPdf(
    onLayout: (_) async => bytes,
    name: 'attendance-report-$className-$year-$month.pdf',
  );
}

/// Pure PDF-building step (no BuildContext/network/asset-bundle dependency)
/// so it can be exercised from a plain `dart run` script for fast iteration
/// -- rebuilding the whole Windows app to click through the UI on every
/// layout tweak is far slower than catching a pdf-widgets layout exception
/// this way.
Future<Uint8List> buildAttendanceReportPdfBytes({
  required AppLocalizations l10n,
  required String className,
  required int year,
  required int month,
  required List<MonthlyStudentSummary> students,
  required Uint8List regularFontBytes,
  required Uint8List boldFontBytes,
}) async {
  final regular = pw.Font.ttf(regularFontBytes.buffer.asByteData());
  final bold = pw.Font.ttf(boldFontBytes.buffer.asByteData());

  final monthName = monthLabel(l10n, month);
  final generatedOn = DateTime.now();
  final generatedLabel =
      '${generatedOn.day.toString().padLeft(2, '0')}.${generatedOn.month.toString().padLeft(2, '0')}.${generatedOn.year} '
      '${generatedOn.hour.toString().padLeft(2, '0')}:${generatedOn.minute.toString().padLeft(2, '0')}';

  final totalStudents = students.length;
  final avgRate = totalStudents == 0
      ? 0.0
      : students.map((s) => s.attendanceRate).reduce((a, b) => a + b) /
            totalStudents;
  final totalAbsentDays = students.fold<int>(0, (sum, s) => sum + s.absentDays);
  final totalPresentDays = students.fold<int>(
    0,
    (sum, s) => sum + s.presentDays + s.lateDays,
  );

  final doc = pw.Document(
    theme: pw.ThemeData.withFont(base: regular, bold: bold),
  );

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(30, 30, 30, 26),
      footer: (ctx) => pw.Container(
        margin: const pw.EdgeInsets.only(top: 10),
        padding: const pw.EdgeInsets.only(top: 8),
        decoration: pw.BoxDecoration(
          border: pw.Border(
            top: pw.BorderSide(color: _ReportColors.border, width: 0.6),
          ),
        ),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Row(
              children: [
                pw.Container(
                  width: 5,
                  height: 5,
                  decoration: pw.BoxDecoration(
                    color: _ReportColors.primary,
                    shape: pw.BoxShape.circle,
                  ),
                ),
                pw.SizedBox(width: 5),
                pw.Text(
                  'SmartSchool  ·  $generatedLabel',
                  style: pw.TextStyle(
                    font: regular,
                    fontSize: 8,
                    color: _ReportColors.textMuted,
                  ),
                ),
              ],
            ),
            pw.Text(
              '${ctx.pageNumber} / ${ctx.pagesCount}',
              style: pw.TextStyle(
                font: regular,
                fontSize: 8,
                color: _ReportColors.textMuted,
              ),
            ),
          ],
        ),
      ),
      build: (ctx) => [
        // Header band with gradient + brand mark
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
                decoration: pw.BoxDecoration(
                  color: PdfColors.white,
                  borderRadius: pw.BorderRadius.circular(11),
                ),
                child: pw.Text(
                  'S',
                  style: pw.TextStyle(
                    font: bold,
                    fontSize: 21,
                    color: _ReportColors.primary,
                  ),
                ),
              ),
              pw.SizedBox(width: 14),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      l10n.pdfReportEyebrow,
                      style: pw.TextStyle(
                        font: bold,
                        fontSize: 8.5,
                        color: PdfColor.fromInt(0xCCFFFFFF),
                        letterSpacing: 1.4,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      className,
                      style: pw.TextStyle(
                        font: bold,
                        fontSize: 25,
                        color: PdfColors.white,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      '$monthName $year',
                      style: pw.TextStyle(
                        font: regular,
                        fontSize: 11.5,
                        color: PdfColor.fromInt(0xE6FFFFFF),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 18),

        // Summary stat row
        pw.Row(
          children: [
            _statCard(
              l10n.students,
              '$totalStudents',
              _ReportColors.primary,
              _ReportColors.primarySoft,
              bold,
              regular,
            ),
            pw.SizedBox(width: 10),
            _statCard(
              l10n.columnRate,
              '${avgRate.toStringAsFixed(0)}%',
              _ReportColors.success,
              _ReportColors.successSoft,
              bold,
              regular,
            ),
            pw.SizedBox(width: 10),
            _statCard(
              l10n.columnPresentDays,
              '$totalPresentDays',
              _ReportColors.info,
              _ReportColors.infoSoft,
              bold,
              regular,
            ),
            pw.SizedBox(width: 10),
            _statCard(
              l10n.columnAbsentDays,
              '$totalAbsentDays',
              _ReportColors.danger,
              _ReportColors.dangerSoft,
              bold,
              regular,
            ),
          ],
        ),
        pw.SizedBox(height: 22),

        if (students.isEmpty)
          pw.Container(
            padding: const pw.EdgeInsets.all(28),
            alignment: pw.Alignment.center,
            decoration: pw.BoxDecoration(
              color: _ReportColors.surfaceAlt,
              borderRadius: pw.BorderRadius.circular(12),
              border: pw.Border.all(color: _ReportColors.border, width: 0.6),
            ),
            child: pw.Text(
              l10n.pdfNoDataForMonth,
              style: pw.TextStyle(
                font: regular,
                fontSize: 11,
                color: _ReportColors.textSecondary,
              ),
            ),
          )
        else
          pw.Table(
            border: pw.TableBorder.all(color: _ReportColors.border, width: 0.6),
            columnWidths: const {
              0: pw.FlexColumnWidth(2.5),
              1: pw.FlexColumnWidth(1.35),
              2: pw.FlexColumnWidth(1.25),
              3: pw.FlexColumnWidth(1.35),
              4: pw.FlexColumnWidth(1.3),
              5: pw.FlexColumnWidth(1.3),
              6: pw.FlexColumnWidth(1.85),
            },
            children: [
              pw.TableRow(
                decoration: pw.BoxDecoration(color: _ReportColors.primary),
                children:
                    [
                          l10n.journalStudentColumn,
                          l10n.columnPresentDays,
                          l10n.columnLateDays,
                          l10n.columnAbsentDays,
                          l10n.columnPresentHours,
                          l10n.columnAbsentHours,
                          l10n.columnRate,
                        ]
                        .map(
                          (h) => pw.Padding(
                            padding: const pw.EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 10,
                            ),
                            child: pw.Text(
                              h,
                              style: pw.TextStyle(
                                font: bold,
                                fontSize: 8.5,
                                color: PdfColors.white,
                              ),
                            ),
                          ),
                        )
                        .toList(),
              ),
              for (final entry in students.asMap().entries)
                pw.TableRow(
                  decoration: pw.BoxDecoration(
                    color: entry.key.isEven
                        ? _ReportColors.white
                        : _ReportColors.surfaceAlt,
                  ),
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      child: pw.Row(
                        children: [
                          pw.Container(
                            width: 22,
                            height: 22,
                            alignment: pw.Alignment.center,
                            decoration: pw.BoxDecoration(
                              color: _ReportColors.tierSoft(
                                entry.value.attendanceRate,
                              ),
                              shape: pw.BoxShape.circle,
                            ),
                            child: pw.Text(
                              entry.value.firstName.isNotEmpty
                                  ? entry.value.firstName[0].toUpperCase()
                                  : '?',
                              style: pw.TextStyle(
                                font: bold,
                                fontSize: 9,
                                color: _ReportColors.tier(
                                  entry.value.attendanceRate,
                                ),
                              ),
                            ),
                          ),
                          pw.SizedBox(width: 8),
                          pw.Expanded(
                            child: pw.Text(
                              '${entry.value.firstName} ${entry.value.lastName}',
                              style: pw.TextStyle(
                                font: regular,
                                fontSize: 9.5,
                                color: _ReportColors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    _cell(
                      '${entry.value.presentDays}',
                      regular,
                      _ReportColors.success,
                    ),
                    _cell(
                      '${entry.value.lateDays}',
                      regular,
                      _ReportColors.warning,
                    ),
                    _cell(
                      '${entry.value.absentDays}',
                      regular,
                      _ReportColors.danger,
                    ),
                    _cell(
                      entry.value.totalPresentHours.toStringAsFixed(1),
                      regular,
                      _ReportColors.textPrimary,
                    ),
                    _cell(
                      entry.value.totalAbsentHours.toStringAsFixed(1),
                      regular,
                      _ReportColors.textPrimary,
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      child: _rateBar(entry.value.attendanceRate, bold),
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

pw.Widget _cell(String value, pw.Font font, PdfColor color) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    child: pw.Text(
      value,
      style: pw.TextStyle(font: font, fontSize: 9.5, color: color),
    ),
  );
}

pw.Widget _rateBar(double rate, pw.Font bold) {
  final color = _ReportColors.tier(rate);
  final fraction = (rate.clamp(0, 100)) / 100;
  const barWidth = 42.0;
  return pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.center,
    children: [
      pw.Container(
        width: barWidth,
        height: 7,
        decoration: pw.BoxDecoration(
          color: _ReportColors.border,
          borderRadius: pw.BorderRadius.circular(3.5),
        ),
        child: pw.Align(
          alignment: pw.Alignment.centerLeft,
          child: pw.Container(
            width: barWidth * fraction,
            height: 7,
            decoration: pw.BoxDecoration(
              color: color,
              borderRadius: pw.BorderRadius.circular(3.5),
            ),
          ),
        ),
      ),
      pw.SizedBox(width: 8),
      pw.Text(
        '${rate.toStringAsFixed(0)}%',
        style: pw.TextStyle(font: bold, fontSize: 9.5, color: color),
      ),
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
            height: 58,
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
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 11,
                vertical: 12,
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    value,
                    style: pw.TextStyle(
                      font: bold,
                      fontSize: 19,
                      color: accent,
                    ),
                  ),
                  pw.SizedBox(height: 3),
                  pw.Text(
                    label,
                    style: pw.TextStyle(
                      font: regular,
                      fontSize: 8.5,
                      color: _ReportColors.textSecondary,
                    ),
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

String monthLabel(AppLocalizations l, int month) {
  switch (month) {
    case 1:
      return l.month1;
    case 2:
      return l.month2;
    case 3:
      return l.month3;
    case 4:
      return l.month4;
    case 5:
      return l.month5;
    case 6:
      return l.month6;
    case 7:
      return l.month7;
    case 8:
      return l.month8;
    case 9:
      return l.month9;
    case 10:
      return l.month10;
    case 11:
      return l.month11;
    default:
      return l.month12;
  }
}
