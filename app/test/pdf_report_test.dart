// Exercises buildAttendanceReportPdfBytes directly via `flutter test`, which
// is far faster than rebuilding the whole Windows app to click through the
// UI on every pdf-widgets layout tweak, and surfaces the same layout
// exceptions (e.g. "Widget won't fit into the page...") immediately.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:smartschool_app/generated/app_localizations_tg.dart';
import 'package:smartschool_app/utils/attendance_pdf_report.dart';

void main() {
  test('builds a class attendance report PDF without layout exceptions', () async {
    final regularBytes = await File(
      'assets/fonts/NotoSans-Regular.ttf',
    ).readAsBytes();
    final boldBytes = await File(
      'assets/fonts/NotoSans-Bold.ttf',
    ).readAsBytes();

    final students = [
      const MonthlyStudentSummary(
        studentId: 1,
        firstName: 'Shohjahon',
        lastName: 'Yuldoshev',
        presentDays: 1,
        lateDays: 1,
        absentDays: 12,
        totalPresentHours: 1.1,
        totalAbsentHours: 84.0,
        attendanceRate: 14.3,
      ),
      const MonthlyStudentSummary(
        studentId: 25,
        firstName: 'Hafizullo',
        lastName: 'Achilov',
        presentDays: 0,
        lateDays: 0,
        absentDays: 2,
        totalPresentHours: 0.0,
        totalAbsentHours: 16.0,
        attendanceRate: 0.0,
      ),
      const MonthlyStudentSummary(
        studentId: 99,
        firstName: 'Test',
        lastName: 'Perfect',
        presentDays: 20,
        lateDays: 1,
        absentDays: 0,
        totalPresentHours: 126.0,
        totalAbsentHours: 0.0,
        attendanceRate: 100.0,
      ),
    ];

    final bytes = await buildAttendanceReportPdfBytes(
      l10n: AppLocalizationsTg(),
      className: '9A',
      year: 2026,
      month: 7,
      students: students,
      regularFontBytes: regularBytes,
      boldFontBytes: boldBytes,
    );

    expect(bytes.length, greaterThan(1000));

    final outFile = File(
      r'C:\Users\gameboy\AppData\Local\Temp\claude\C--Users-gameboy\d46c7516-a083-46a5-b5db-3c6e878781a8\scratchpad\test_report.pdf',
    );
    await outFile.writeAsBytes(bytes);
    // ignore: avoid_print
    print('Wrote ${bytes.length} bytes to ${outFile.path}');
  });
}
