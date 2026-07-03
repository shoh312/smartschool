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
  String get logout => 'Logout';

  @override
  String get invalidPhoneError => 'Please enter a valid phone number';

  @override
  String errorPrefix(String error) {
    return 'Error: $error';
  }

  @override
  String get needSupport => 'Need support? ';

  @override
  String get contact => 'Contact';

  @override
  String get roleDirector => 'Director';

  @override
  String get roleParent => 'Parent';

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
  String get directorDashboard => 'Director Dashboard';

  @override
  String get parentDashboard => 'Parent Dashboard';

  @override
  String get notifications => 'Notifications';
}
