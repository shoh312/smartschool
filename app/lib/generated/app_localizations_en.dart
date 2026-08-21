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
  String get roleStudent => 'Student';

  @override
  String get studentUsernameLabel => 'Username';

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

  @override
  String get ratingAnalytics => 'Rating';

  @override
  String get overallAverage => 'Overall average';

  @override
  String get classRank => 'Class';

  @override
  String get parallelRank => 'Parallel';

  @override
  String get schoolRank => 'School';

  @override
  String get classRanking => 'Class ranking';

  @override
  String get parallelRanking => 'Parallel ranking';

  @override
  String get schoolRanking => 'School ranking';

  @override
  String get strongestSubject => 'Strongest subject';

  @override
  String get weakestSubject => 'Needs attention';

  @override
  String get subjectBreakdown => 'Subjects';

  @override
  String get lessonAttendanceRate => 'Lesson attendance';

  @override
  String get quarter1 => 'Quarter 1';

  @override
  String get quarter2 => 'Quarter 2';

  @override
  String get quarter3 => 'Quarter 3';

  @override
  String get quarter4 => 'Quarter 4';

  @override
  String get noGradesYetMessage => 'No grades recorded yet for this period';

  @override
  String get achievementFirstPlace => '1st place';

  @override
  String get achievementTopThree => 'Top 3';

  @override
  String get achievementTopTenPercent => 'Top 10%';

  @override
  String get exportPdf => 'Export PDF';

  @override
  String get classAverage => 'Class avg';

  @override
  String get parallelAverage => 'Parallel avg';

  @override
  String get schoolAverage => 'School avg';

  @override
  String get needsAttention => 'Needs attention';

  @override
  String get biggestDecline => 'Biggest decline';

  @override
  String get lowestAverage => 'Lowest average';

  @override
  String get trendVsPreviousQuarter => 'vs previous quarter';

  @override
  String get pdfRatingEyebrow => 'RATING REPORT';

  @override
  String get gradeCountSuffix => 'grades';

  @override
  String get rankingScopeAll => 'All';

  @override
  String get rankingScopeClasses => 'Classes';

  @override
  String get rankingScopeParallel => 'Parallel';

  @override
  String get selectClassPrompt => 'Select a class';

  @override
  String get selectParallelPrompt => 'Select a parallel';

  @override
  String get topThree => 'Top 3';

  @override
  String lessonSchedule(String className) {
    return 'Schedule — $className';
  }

  @override
  String get editLesson => 'Edit lesson';

  @override
  String get deleteLessonTitle => 'Delete lesson';

  @override
  String get deleteLessonConfirm =>
      'Delete this lesson? This cannot be undone.';

  @override
  String get roomLabel => 'Room';

  @override
  String get ruznoma => 'Diary';

  @override
  String get todayLessons => 'Today';

  @override
  String get tomorrowLessons => 'Tomorrow';

  @override
  String get homeworkLabel => 'Homework';

  @override
  String get teacherNoteLabel => 'Teacher\'s note';

  @override
  String get addHomeworkPrompt => 'Add homework or a note';

  @override
  String get noLessonsToday => 'No lessons for this day';

  @override
  String get schoolCalendar => 'School calendar';

  @override
  String get eventTypeHoliday => 'Holiday';

  @override
  String get eventTypeExam => 'Exam';

  @override
  String get eventTypeTest => 'Control work';

  @override
  String get eventTypeEvent => 'Event';

  @override
  String get addEvent => 'Add event';

  @override
  String get eventTitleLabel => 'Title';

  @override
  String get eventDescriptionLabel => 'Description (optional)';

  @override
  String get noUpcomingEvents => 'No upcoming events';

  @override
  String get deleteEventTitle => 'Delete event';

  @override
  String get deleteEventConfirm => 'Delete this event?';

  @override
  String get announcements => 'Announcements';

  @override
  String get postAnnouncement => 'Post announcement';

  @override
  String get announcementTitleLabel => 'Title';

  @override
  String get announcementBodyLabel => 'Message';

  @override
  String get noAnnouncementsYet => 'No announcements yet';

  @override
  String get deleteAnnouncementTitle => 'Delete announcement';

  @override
  String get deleteAnnouncementConfirm => 'Delete this announcement?';

  @override
  String get pickDatePrompt => 'Select a date';

  @override
  String get lessonWord => 'lesson';

  @override
  String get lessonsCountSuffix => 'lessons';

  @override
  String untilTime(String time) {
    return 'until $time';
  }

  @override
  String get teacherWord => 'Teacher';

  @override
  String lessonOrdinal(int number) {
    return 'Lesson $number';
  }

  @override
  String get retry => 'Retry';

  @override
  String get logoutConfirmMessage => 'Are you sure you want to sign out?';

  @override
  String get homeworkListTitle => 'Homework';

  @override
  String get noHomeworkMessage => 'No homework assigned yet';

  @override
  String get achievementsTitle => 'Achievements';

  @override
  String get achievementSchoolFirst => '#1 in school';

  @override
  String get achievementTopThreeBadge => 'Top 3';

  @override
  String get achievementExcellent => 'Excellent student';

  @override
  String get achievementPerfectAttendance => 'Perfect attendance';

  @override
  String get achievementBigImprovement => 'Most improved';

  @override
  String achievementSubjectMaster(String subject) {
    return '$subject master';
  }

  @override
  String get noAchievementsTitle => 'No achievements yet';

  @override
  String get noAchievementsMessage =>
      'Keep studying -- your first badge is just around the corner';

  @override
  String get studentHomeTitle => 'My page';

  @override
  String get studentLoginLabel => 'Login username';

  @override
  String get studentPasswordLabel => 'Password';

  @override
  String get studentLoginHelperText =>
      'Optional -- only needed if this student should log in on their own';

  @override
  String get journalScanTitle => 'Scan journal';

  @override
  String get journalScanPrompt =>
      'Take a photo of the journal page, or pick one from your gallery. Grades in today\'s column will be read automatically.';

  @override
  String get journalScanTakePhoto => 'Take photo';

  @override
  String get journalScanPickGallery => 'Choose from gallery';

  @override
  String get journalScanEmptyTitle => 'Nothing detected';

  @override
  String get journalScanEmptyMessage =>
      'No grades were found in today\'s column of this photo. Try a clearer, straighter photo.';

  @override
  String get journalScanConfirmAll => 'Confirm and save';

  @override
  String journalScanSavedCount(int saved, int total) {
    return '$saved of $total grades saved';
  }

  @override
  String journalScanNoMatch(String name) {
    return 'No matching student for \"$name\" -- skipped';
  }

  @override
  String journalScanRawName(String name) {
    return 'Read as: $name';
  }

  @override
  String get journalScanAbsent => 'Absent';

  @override
  String get attendanceToday => 'Today\'s attendance';

  @override
  String get sectionLearning => 'Learning';

  @override
  String get sectionSchool => 'School';

  @override
  String arrivedOfTotal(int arrived, int total) {
    return '$arrived of $total arrived';
  }

  @override
  String get materialsTitle => 'Materials';

  @override
  String get materialsSubtitle => 'Lessons and tests for your classes';

  @override
  String get materialLibrary => 'My library';

  @override
  String get materialHandedOut => 'Handed out';

  @override
  String get materialNew => 'New material';

  @override
  String get materialTitleLabel => 'Title';

  @override
  String get materialDescriptionLabel => 'Short description';

  @override
  String get materialEmptyTitle => 'No materials yet';

  @override
  String get materialEmptyMessage =>
      'Create a lesson or a test and hand it to your class.';

  @override
  String get materialContentEmpty => 'Add at least one page or question.';

  @override
  String get materialPage => 'Page';

  @override
  String get materialQuestion => 'Question';

  @override
  String get materialAddPage => 'Page';

  @override
  String get materialAddQuestion => 'Question';

  @override
  String get materialPasteImport => 'Paste from text';

  @override
  String get materialPasteTitle => 'Paste your questions';

  @override
  String get materialPasteHelp =>
      '# starts an explanation page, a numbered line starts a question, * marks the correct option, - a wrong one, and = makes it a type-the-answer question.';

  @override
  String get materialPasteAction => 'Read the text';

  @override
  String materialPasteResult(int count) {
    return '$count blocks read';
  }

  @override
  String get materialQuestionType => 'Question type';

  @override
  String get materialTypeSingle => 'One correct answer';

  @override
  String get materialTypeTrueFalse => 'True / False';

  @override
  String get materialTypeFill => 'Type the answer';

  @override
  String get materialTypeMatch => 'Match pairs';

  @override
  String get materialTypeOrder => 'Put in order';

  @override
  String get materialQuestionText => 'Question text';

  @override
  String get materialPageText => 'Page text';

  @override
  String get materialOption => 'Option';

  @override
  String get materialAddOption => 'Add option';

  @override
  String get materialMarkCorrect => 'Tap the circle to mark the correct answer';

  @override
  String get materialAcceptedAnswers => 'Accepted answers';

  @override
  String get materialAcceptedHint =>
      'One per line -- spelling variants all count.';

  @override
  String get materialLeftItem => 'Left';

  @override
  String get materialRightItem => 'Right';

  @override
  String get materialOrderHint =>
      'Write the items in the correct order -- the pupil sees them shuffled.';

  @override
  String get materialTrue => 'True';

  @override
  String get materialFalse => 'False';

  @override
  String get materialAssign => 'Hand out';

  @override
  String get materialAssignTitle => 'Hand out to classes';

  @override
  String get materialPickClasses => 'Which classes';

  @override
  String get materialMode => 'Type of work';

  @override
  String get materialModeControl => 'Control test';

  @override
  String get materialModeControlHint =>
      'Graded. Marks stay hidden until the deadline.';

  @override
  String get materialModePractice => 'Practice';

  @override
  String get materialModePracticeHint =>
      'No grade. The pupil is told right or wrong at once.';

  @override
  String get materialDueAt => 'Deadline';

  @override
  String get materialPickDue => 'Choose a deadline';

  @override
  String get materialAttempts => 'Attempts';

  @override
  String get materialAttemptsUnlimited => 'Unlimited';

  @override
  String get materialControlNeedsDue => 'A control test needs a deadline.';

  @override
  String get materialPickAtLeastOne => 'Choose at least one class.';

  @override
  String get materialResults => 'Results';

  @override
  String materialSubmittedOf(int done, int total) {
    return '$done of $total submitted';
  }

  @override
  String get materialResultsHidden =>
      'Marks open when the deadline passes, or once everybody has submitted.';

  @override
  String get materialNotSubmitted => 'Not submitted';

  @override
  String get materialTransfer => 'Send to journal';

  @override
  String get materialTransferDone => 'Grades sent to the journal';

  @override
  String get materialTransferred => 'In the journal';

  @override
  String get materialDuplicate => 'Make a copy';

  @override
  String get materialLockedEdit =>
      'This material has been handed out. Make a copy to change the questions.';

  @override
  String get materialDeleteTitle => 'Delete this material?';

  @override
  String get materialDeleteConfirm =>
      'It will disappear from your library and from every class it was handed to.';

  @override
  String get materialNoQuestions => 'no questions';

  @override
  String materialQuestionsCount(int count) {
    return '$count questions';
  }

  @override
  String get assignmentsTitle => 'Assignments';

  @override
  String get assignmentsNoneTitle => 'Nothing to do right now';

  @override
  String get assignmentsNoneMessage =>
      'Your teachers have not handed out any work yet.';

  @override
  String get assignmentStart => 'Start';

  @override
  String get assignmentContinue => 'Continue';

  @override
  String get assignmentRetry => 'Try again';

  @override
  String get assignmentNext => 'Next';

  @override
  String get assignmentCheck => 'Check';

  @override
  String get assignmentFinish => 'Finish';

  @override
  String get assignmentCorrect => 'Correct!';

  @override
  String get assignmentWrong => 'Not quite';

  @override
  String get assignmentOverdue => 'Deadline passed';

  @override
  String get assignmentDone => 'Done';

  @override
  String assignmentDueLabel(String when) {
    return 'Due $when';
  }

  @override
  String assignmentAttemptsLeft(int count) {
    return '$count attempts left';
  }

  @override
  String get assignmentNoAttemptsLeft => 'No attempts left';

  @override
  String get assignmentWaitingMark =>
      'Submitted. Your mark appears after the deadline.';

  @override
  String get assignmentYourScore => 'Your score';

  @override
  String get assignmentTypeAnswer => 'Type your answer';

  @override
  String get assignmentTapInOrder => 'Tap the words in the right order';

  @override
  String get assignmentMatchHint => 'Pick one from each side to join them';

  @override
  String get assignmentLeave => 'Leave this task?';

  @override
  String get assignmentLeaveMessage =>
      'Your answers are saved -- you can come back and carry on.';

  @override
  String get materialScopeMine => 'Mine';

  @override
  String get materialScopeSchool => 'School';

  @override
  String materialByTeacher(String name) {
    return 'by $name';
  }

  @override
  String get materialReadOnly =>
      'Someone else wrote this. Make a copy to change it or hand it out.';

  @override
  String get materialSchoolEmpty => 'Nobody else has written anything yet.';

  @override
  String get analysisByQuarter => 'By quarter';

  @override
  String get analysisByMonth => 'Monthly';

  @override
  String get analysisNoMonthly => 'No marks in this month.';

  @override
  String get analysisBestDay => 'Best day';

  @override
  String analysisDaysWithMarks(int count) {
    return '$count days with marks';
  }

  @override
  String get aiTitle => 'AI assistant';

  @override
  String get aiSubtitle => 'Draft a lesson or a test, then check it yourself';

  @override
  String get aiStepSource => 'Source';

  @override
  String get aiStepSettings => 'Settings';

  @override
  String get aiStepReview => 'Check';

  @override
  String get aiSourceTopic => 'Topic';

  @override
  String get aiSourceTopicHint =>
      'Write the topic, e.g. \"Pythagoras theorem\"';

  @override
  String get aiSourcePhoto => 'Textbook photo';

  @override
  String get aiSourcePhotoHint => 'Photograph a page and the AI will read it';

  @override
  String get aiSourceText => 'Paste text';

  @override
  String get aiSourceTextHint => 'Paste text from a book or a document';

  @override
  String get aiPickPhoto => 'Choose a photo';

  @override
  String get aiPhotoReady => 'Photo attached';

  @override
  String get aiNeedSource => 'Fill in the source first.';

  @override
  String get aiQuestionCount => 'Questions';

  @override
  String get aiPageCount => 'Explanation pages';

  @override
  String get aiDifficulty => 'Difficulty';

  @override
  String get aiDifficultyEasy => 'Easy';

  @override
  String get aiDifficultyMedium => 'Medium';

  @override
  String get aiDifficultyHard => 'Hard';

  @override
  String get aiNeedTypes => 'Choose at least one question type.';

  @override
  String get aiGenerate => 'Generate';

  @override
  String get aiWorking => 'Writing the material…';

  @override
  String get aiWorkingHint => 'This usually takes 20–30 seconds.';

  @override
  String get aiReviewWarning =>
      'AI can be wrong. Read every block and fix what needs fixing before saving.';

  @override
  String aiDropped(int count) {
    return '$count blocks were unusable and removed.';
  }

  @override
  String get aiSaveMaterial => 'Save as material';

  @override
  String get aiRegenerate => 'Generate again';

  @override
  String get aiBack => 'Back';

  @override
  String get aiNext => 'Next';

  @override
  String get passwordChangeTitle => 'Change your password';

  @override
  String get passwordChangeWhy =>
      'This account still uses the password it shipped with. Choose your own before going any further.';

  @override
  String get passwordCurrent => 'Current password';

  @override
  String get passwordNew => 'New password';

  @override
  String get passwordRepeat => 'Repeat new password';

  @override
  String get passwordTooShort => 'At least 8 characters.';

  @override
  String get passwordMismatch => 'The two passwords do not match.';

  @override
  String get passwordIsDefault =>
      'Choose a different password from the default one.';

  @override
  String get passwordChanged => 'Password changed.';

  @override
  String get passwordSave => 'Save password';

  @override
  String get serverAddress => 'Server address';

  @override
  String get serverAddressHint => 'Leave empty to use the built-in address';

  @override
  String get serverAddressSaved => 'Server address saved. Restart the app.';

  @override
  String serverAddressCurrent(String url) {
    return 'Now: $url';
  }

  @override
  String get ratingHighAchievers => 'High achievers';

  @override
  String get subjectStrengths => 'Strong and weak subjects';

  @override
  String subjectCoverage(int students, int grades) {
    return '$students pupils / $grades grades';
  }

  @override
  String get awaitingDetection => 'Not checked yet';
}
