// What the streak on the attendance page is actually counting.
//
// A streak is a promise to the pupil: it says "you kept this up". So the
// rules have to match what a child would count themselves. Coming in late is
// still coming in. Sunday is not a day you failed to attend. And two rows
// for one Tuesday is one Tuesday.

import 'package:flutter_test/flutter_test.dart';
import 'package:smartschool_app/models/attendance.dart';
import 'package:smartschool_app/widgets/attendance/attendance_streak.dart';

AttendanceRecord _day(int day, AttendanceStatus status) => AttendanceRecord(
      id: day,
      studentId: 1,
      status: status,
      attendanceDate: DateTime(2026, 8, day),
    );

void main() {
  test('an empty history has nothing to show', () {
    final streak = computeAttendanceStreak([]);
    expect(streak.isEmpty, isTrue);
    expect(streak.current, 0);
  });

  test('counts the run ending at the most recent day', () {
    final streak = computeAttendanceStreak([
      _day(17, AttendanceStatus.present),
      _day(18, AttendanceStatus.present),
      _day(19, AttendanceStatus.present),
    ]);
    expect(streak.current, 3);
    expect(streak.daysCounted, 3);
  });

  test('arriving late is still arriving', () {
    final streak = computeAttendanceStreak([
      _day(17, AttendanceStatus.present),
      _day(18, AttendanceStatus.late),
      _day(19, AttendanceStatus.present),
    ]);
    expect(streak.current, 3);
  });

  test('leaving early is still having come', () {
    final streak = computeAttendanceStreak([
      _day(17, AttendanceStatus.present),
      _day(18, AttendanceStatus.leftSchool),
    ]);
    expect(streak.current, 2);
  });

  test('an absence breaks the run but the best is remembered', () {
    final streak = computeAttendanceStreak([
      _day(10, AttendanceStatus.present),
      _day(11, AttendanceStatus.present),
      _day(12, AttendanceStatus.present),
      _day(13, AttendanceStatus.present),
      _day(14, AttendanceStatus.absent),
      _day(17, AttendanceStatus.present),
    ]);
    expect(streak.current, 1);
    expect(streak.best, 4);
  });

  test('a gap with no record does not break the run', () {
    // 15 and 16 August 2026 are a Saturday and a Sunday with no lessons, so
    // the school wrote no rows for them -- and the pupil did not fail to
    // attend anything.
    final streak = computeAttendanceStreak([
      _day(14, AttendanceStatus.present),
      _day(17, AttendanceStatus.present),
    ]);
    expect(streak.current, 2);
  });

  test('order of the input does not matter', () {
    final streak = computeAttendanceStreak([
      _day(19, AttendanceStatus.present),
      _day(17, AttendanceStatus.present),
      _day(18, AttendanceStatus.present),
    ]);
    expect(streak.current, 3);
  });

  test('one day with two rows is one day', () {
    // A pupil detected, marked left_school, then seen again writes more than
    // one row for the same date.
    final streak = computeAttendanceStreak([
      _day(17, AttendanceStatus.present),
      AttendanceRecord(
        id: 99,
        studentId: 1,
        status: AttendanceStatus.leftSchool,
        attendanceDate: DateTime(2026, 8, 17),
      ),
      _day(18, AttendanceStatus.present),
    ]);
    expect(streak.current, 2);
    expect(streak.daysCounted, 2);
  });

  test('a stray absent row does not cancel a day the pupil was seen', () {
    final streak = computeAttendanceStreak([
      AttendanceRecord(
        id: 98,
        studentId: 1,
        status: AttendanceStatus.absent,
        attendanceDate: DateTime(2026, 8, 18),
      ),
      _day(18, AttendanceStatus.present),
      _day(17, AttendanceStatus.present),
    ]);
    expect(streak.current, 2);
  });
}
