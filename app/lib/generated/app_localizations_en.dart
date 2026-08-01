// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get title => 'Smart School';

  @override
  String get login => 'Login';

  @override
  String get signIn => 'Sign In';

  @override
  String get email => 'Email';

  @override
  String get password => 'Password';

  @override
  String get phone => 'Phone Number';

  @override
  String get welcome => 'Welcome';

  @override
  String get login_desc => 'Enter your credentials to sign in.';

  @override
  String get dashboard => 'Dashboard';

  @override
  String get live => 'Live';

  @override
  String get manage => 'Management';

  @override
  String get alerts => 'Alerts';

  @override
  String get students => 'Students';

  @override
  String get classes => 'Classes';

  @override
  String get classSingle => 'Class';

  @override
  String get cameras => 'Cameras';

  @override
  String get settings => 'Settings';

  @override
  String get language => 'Language';

  @override
  String get appearance => 'Appearance';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get themeSystem => 'System';

  @override
  String get logout => 'Logout';

  @override
  String get invalidPhoneError => 'Please enter a valid phone number';

  @override
  String errorPrefix(String error) {
    return 'Error: $error';
  }

  @override
  String get networkErrorMessage =>
      'Could not connect to the server. Check your internet connection or make sure the server is running.';

  @override
  String get serverErrorMessage =>
      'The server returned an error. Please try again.';

  @override
  String get unknownErrorMessage => 'Something went wrong. Please try again.';

  @override
  String get phoneNotRegisteredMessage =>
      'This phone number is not registered at any school yet. Please contact your child\'s school.';

  @override
  String get invalidCredentialsMessage => 'Incorrect email or password.';

  @override
  String get accountInactiveMessage =>
      'Your account is inactive. Please contact your administrator.';

  @override
  String get invalidCurrentPasswordMessage => 'Current password is incorrect.';

  @override
  String get needSupport => 'Need support? ';

  @override
  String get contact => 'Contact';

  @override
  String get roleDirector => 'Director';

  @override
  String get roleParent => 'Parent';

  @override
  String get roleTeacher => 'Teacher';

  @override
  String get createAccount => 'Create Account';

  @override
  String get lastStep => 'Last step!';

  @override
  String tellUsName(String phone) {
    return 'Please enter your name to complete registration for $phone';
  }

  @override
  String get fullName => 'Full Name';

  @override
  String get fullNameHint => 'John Doe';

  @override
  String get completeRegistration => 'Complete Registration';

  @override
  String get termsAndPrivacy =>
      'By continuing, you agree to our Terms of Use and Privacy Policy.';

  @override
  String get present => 'Present';

  @override
  String get late => 'Late';

  @override
  String get absent => 'Absent';

  @override
  String get leftSchool => 'Left School';

  @override
  String get notDetected => 'Not Detected';

  @override
  String get quickActions => 'Quick Actions';

  @override
  String get history => 'History';

  @override
  String get liveStream => 'Live Stream';

  @override
  String get recentActivity => 'Recent Activity';

  @override
  String get attendanceByClass => 'Attendance by Class';

  @override
  String get noAttendanceRecorded => 'No attendance recorded yet today';

  @override
  String cameraLabel(String cameraId) {
    return 'Camera: $cameraId';
  }

  @override
  String get noChildrenLinked => 'No children linked';

  @override
  String get assignedStudentsWillAppear =>
      'Assigned students will appear here.';

  @override
  String get children => 'Children';

  @override
  String get attendanceHistory => 'Attendance History';

  @override
  String get liveStatus => 'Live Status';

  @override
  String get selectClass => 'Please select a class';

  @override
  String get studentPhotoRequired => 'Student photo is required';

  @override
  String get deleteStudentTitle => 'Delete Student';

  @override
  String get deleteStudentConfirm =>
      'Are you sure you want to delete this student?';

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get studentManagement => 'Student Management';

  @override
  String get addNewStudent => 'Add New Student';

  @override
  String get editStudent => 'Edit Student';

  @override
  String get firstName => 'First Name';

  @override
  String get lastName => 'Last Name';

  @override
  String get parentPhoneNumber => 'Parent Phone Number';

  @override
  String get isActive => 'Is Active';

  @override
  String get studentFacePhoto => 'Student Face Photo';

  @override
  String get updatePhotoOptional => 'Update Photo (optional)';

  @override
  String get requiredForFaceRecognition => 'Required for face recognition';

  @override
  String get addStudent => 'Add Student';

  @override
  String get saveChanges => 'Save Changes';

  @override
  String get studentsList => 'Students List';

  @override
  String get noStudents => 'No students';

  @override
  String get studentsAssignedWillAppear =>
      'Students assigned to classes and parents will appear here.';

  @override
  String get deleteClassTitle => 'Delete Class';

  @override
  String get deleteClassConfirm =>
      'Are you sure you want to delete this class? This may affect linked students and cameras.';

  @override
  String get classManagement => 'Class Management';

  @override
  String get createNewClass => 'Create New Class';

  @override
  String get editClass => 'Edit Class';

  @override
  String get classNameLabel => 'Class Name';

  @override
  String get classNameHint => 'e.g., 9A, 10B';

  @override
  String get gradeOptional => 'Grade (optional)';

  @override
  String get gradeHint => 'Auto-detected if empty';

  @override
  String get createClass => 'Create Class';

  @override
  String get existingClasses => 'Existing Classes';

  @override
  String get noClasses => 'No classes';

  @override
  String get createClassesMessage => 'Create classes to monitor attendance.';

  @override
  String gradeLabel(String grade) {
    return 'Grade $grade';
  }

  @override
  String get deleteCameraTitle => 'Delete Camera';

  @override
  String get deleteCameraConfirm =>
      'Are you sure you want to delete this camera?';

  @override
  String get cameraManagement => 'Camera Management';

  @override
  String get addNewCamera => 'Add New Camera';

  @override
  String get editCamera => 'Edit Camera';

  @override
  String get cameraNameLabel => 'Camera Name';

  @override
  String get assignToClass => 'Assign to Class';

  @override
  String get rtspUrl => 'RTSP URL';

  @override
  String get startTime => 'Start Time';

  @override
  String get endTime => 'End Time';

  @override
  String get detectSec => 'Detection (sec)';

  @override
  String get waitMin => 'Wait (min)';

  @override
  String get addCamera => 'Add Camera';

  @override
  String get registeredCameras => 'Registered Cameras';

  @override
  String get noCameras => 'No cameras';

  @override
  String get classroomCamerasWillAppear =>
      'Classroom cameras will appear here.';

  @override
  String cameraListSubtitle(String className, String waitDuration) {
    return 'Class: $className • Wait: ${waitDuration}m';
  }

  @override
  String get unassigned => 'Unassigned';

  @override
  String get noAttendanceRecords => 'No attendance records';

  @override
  String get recordsWillAppear =>
      'Records will appear once face recognition starts.';

  @override
  String inTimeOutTime(String inTime, String outTime) {
    return 'In $inTime  Out $outTime';
  }

  @override
  String get noLiveData => 'No live data';

  @override
  String get realtimeAttendanceMessage =>
      'Real-time attendance will appear during detection.';

  @override
  String lastSeenTime(String time) {
    return 'Last seen at $time';
  }

  @override
  String get directorNotifications => 'Director Notifications';

  @override
  String get schoolWideNotificationView =>
      'School-wide notification view can be enabled later.';

  @override
  String get noNotifications => 'No notifications';

  @override
  String get attendanceAlertsWillAppear =>
      'Attendance alerts will appear here.';

  @override
  String get studentNotFound => 'Student not found';

  @override
  String classLabel(String classId) {
    return 'Class $classId';
  }

  @override
  String parentLabel(String parentId) {
    return 'Parent $parentId';
  }

  @override
  String get viewAttendanceHistoryButton => 'View Attendance History';

  @override
  String get viewLiveStatusButton => 'View Live Status';

  @override
  String get signOutTooltip => 'Sign out';

  @override
  String classTileLabel(String className) {
    return 'Class: $className';
  }

  @override
  String classAttendanceRatio(String className, int arrived, int total) {
    return '$className • $arrived/$total arrived';
  }

  @override
  String get directorDashboard => 'Director Dashboard';

  @override
  String get parentDashboard => 'Parent Dashboard';

  @override
  String get notifications => 'Notifications';

  @override
  String get grades => 'Grades';

  @override
  String get noGrades => 'No grades yet';

  @override
  String get noGradesMessage =>
      'Grades will appear here once a teacher enters them.';

  @override
  String studentFallbackLabel(String id) {
    return 'Student #$id';
  }

  @override
  String get teacherMyClasses => 'My Classes';

  @override
  String get teacherNoClassesTitle => 'You have no classes assigned yet';

  @override
  String get teacherNoClassesMessage =>
      'This will appear once the director assigns you a class.';

  @override
  String classFallbackLabel(String classId) {
    return 'Class #$classId';
  }

  @override
  String get journalStudentColumn => 'Student';

  @override
  String get journalScoreLabel => 'Grade';

  @override
  String get journalCommentOptional => 'Comment (optional)';

  @override
  String get journalTeacherLabel => 'Teacher';

  @override
  String get journalNoComment => 'No comment';

  @override
  String get close => 'Close';

  @override
  String get save => 'Save';

  @override
  String get journalNoStudentsTitle => 'No students found in this class';

  @override
  String get journalNoStudentsMessage =>
      'This will appear once the director assigns students to this class.';

  @override
  String get teachers => 'Teachers';

  @override
  String get addNewTeacher => 'New teacher';

  @override
  String get create => 'Create';

  @override
  String get existingTeachers => 'Existing teachers';

  @override
  String get noTeachers => 'No teachers yet';

  @override
  String get noTeachersMessage => 'Add a new teacher using the form above.';

  @override
  String assignClassToTeacher(String name) {
    return 'Assign a class to $name';
  }

  @override
  String get assignClassNoClasses => 'Create a class first.';

  @override
  String get noClassesAssignedYet => 'Not assigned to any class yet';

  @override
  String get removeAssignment => 'Remove';

  @override
  String get addSubjectTitle => 'Add subject';

  @override
  String get noTeachersForSubject =>
      'No teachers registered for this subject yet';

  @override
  String get noSubjectsInClass => 'No subjects added to this class yet';

  @override
  String get addSubjectToStart => 'Tap \"Add subject\" to assign a teacher.';

  @override
  String get subjectsLabel => 'Subjects';

  @override
  String get subjectsAndTeachers => 'Subjects & teachers';

  @override
  String get viewJournal => 'View journal';

  @override
  String get removeAssignmentConfirm =>
      'Remove this teacher from this subject in the class? Grades they already entered will stay.';

  @override
  String get subjectLabel => 'Subject';

  @override
  String get assign => 'Assign';

  @override
  String get classAssigned => 'Class assigned';

  @override
  String get month1 => 'January';

  @override
  String get month2 => 'February';

  @override
  String get month3 => 'March';

  @override
  String get month4 => 'April';

  @override
  String get month5 => 'May';

  @override
  String get month6 => 'June';

  @override
  String get month7 => 'July';

  @override
  String get month8 => 'August';

  @override
  String get month9 => 'September';

  @override
  String get month10 => 'October';

  @override
  String get month11 => 'November';

  @override
  String get month12 => 'December';

  @override
  String get deleteTeacherTitle => 'Delete Teacher';

  @override
  String get deleteTeacherConfirm =>
      'Are you sure you want to delete this teacher? Their class assignments and entered grades will also be removed.';

  @override
  String get average => 'Average';

  @override
  String get weekday1 => 'Mon';

  @override
  String get weekday2 => 'Tue';

  @override
  String get weekday3 => 'Wed';

  @override
  String get weekday4 => 'Thu';

  @override
  String get weekday5 => 'Fri';

  @override
  String get weekday6 => 'Sat';

  @override
  String get weekday7 => 'Sun';

  @override
  String get attendanceJournal => 'Attendance journal';

  @override
  String get lastSeenLabel => 'Last seen';

  @override
  String get noAttendanceThisMonth => 'No attendance records this month';

  @override
  String get noCameraForClassTitle => 'No camera for this class';

  @override
  String get noCameraForClassMessage =>
      'Assign a camera to this class in Camera Management to see its live status.';

  @override
  String get studentNotAssignedToClass =>
      'This student isn\'t assigned to a class yet';

  @override
  String get cameraNotAvailable =>
      'Camera capture isn\'t available on this device. Use Gallery instead.';

  @override
  String get rooms => 'Rooms';

  @override
  String get roomManagement => 'Room Management';

  @override
  String get addNewRoom => 'Add New Room';

  @override
  String get editRoom => 'Edit Room';

  @override
  String get roomNameLabel => 'Room Name';

  @override
  String get assignToRoom => 'Assign to Room';

  @override
  String get positions => 'Positions';

  @override
  String get addPosition => 'Add Position';

  @override
  String get positionClassLabel => 'Class';

  @override
  String get registeredRooms => 'Registered Rooms';

  @override
  String get noRooms => 'No rooms';

  @override
  String get roomsWillAppear => 'Rooms will appear here.';

  @override
  String get deleteRoomTitle => 'Delete Room';

  @override
  String get deleteRoomConfirm => 'Are you sure you want to delete this room?';

  @override
  String get roomHasCamerasError =>
      'Reassign or remove this room\'s cameras before deleting it.';

  @override
  String cameraListSubtitleRoom(String roomName, String waitDuration) {
    return 'Room: $roomName • Wait: ${waitDuration}m';
  }

  @override
  String roomPositionSubtitle(
    String className,
    String startTime,
    String endTime,
  ) {
    return '$className: $startTime–$endTime';
  }

  @override
  String analyticsScreenTitle(String className) {
    return '$className - Analytics';
  }

  @override
  String get noDataTitle => 'No data';

  @override
  String get noAttendanceDataLast30Days =>
      'No attendance data for last 30 days';

  @override
  String get perStudentDetails => 'Per-Student Details';

  @override
  String get hoursLabel => 'Hours';

  @override
  String get thirtyDayTimeline => '30-Day Timeline';

  @override
  String get noTimetableSubjectsTitle => 'No timetable subjects';

  @override
  String get noTimetableSubjectsMessage =>
      'Add lessons to this class timetable first.';

  @override
  String get tapToAssignTeacher => 'Tap to assign teacher';

  @override
  String get timetableLabel => 'Timetable';

  @override
  String totalHoursPerWeek(String hours) {
    return 'Total: $hours h/week';
  }

  @override
  String get noLessonsForDay => 'No lessons for this day';

  @override
  String get addLesson => 'Add Lesson';

  @override
  String get minutesUnit => 'min';

  @override
  String get cameraOptionTooltip => 'Camera';

  @override
  String get galleryOptionTooltip => 'Gallery';

  @override
  String get noFrame => 'No frame';

  @override
  String get selectMonth => 'Select month';

  @override
  String get generatePdfReport => 'Generate PDF Report';

  @override
  String get pdfReportEyebrow => 'ATTENDANCE REPORT';

  @override
  String get pdfNoDataForMonth => 'No attendance data for the selected month';

  @override
  String get columnPresentDays => 'Present days';

  @override
  String get columnLateDays => 'Late days';

  @override
  String get columnAbsentDays => 'Absent days';

  @override
  String get columnPresentHours => 'Present hours';

  @override
  String get columnAbsentHours => 'Absent hours';

  @override
  String get columnRate => 'Rate';
}
