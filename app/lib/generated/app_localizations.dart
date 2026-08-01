import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ru.dart';
import 'app_localizations_tg.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ru'),
    Locale('tg'),
  ];

  /// No description provided for @title.
  ///
  /// In en, this message translates to:
  /// **'Smart School'**
  String get title;

  /// No description provided for @login.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get login;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get signIn;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @phone.
  ///
  /// In en, this message translates to:
  /// **'Phone Number'**
  String get phone;

  /// No description provided for @welcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome'**
  String get welcome;

  /// No description provided for @login_desc.
  ///
  /// In en, this message translates to:
  /// **'Enter your credentials to sign in.'**
  String get login_desc;

  /// No description provided for @dashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get dashboard;

  /// No description provided for @live.
  ///
  /// In en, this message translates to:
  /// **'Live'**
  String get live;

  /// No description provided for @manage.
  ///
  /// In en, this message translates to:
  /// **'Management'**
  String get manage;

  /// No description provided for @alerts.
  ///
  /// In en, this message translates to:
  /// **'Alerts'**
  String get alerts;

  /// No description provided for @students.
  ///
  /// In en, this message translates to:
  /// **'Students'**
  String get students;

  /// No description provided for @classes.
  ///
  /// In en, this message translates to:
  /// **'Classes'**
  String get classes;

  /// No description provided for @classSingle.
  ///
  /// In en, this message translates to:
  /// **'Class'**
  String get classSingle;

  /// No description provided for @cameras.
  ///
  /// In en, this message translates to:
  /// **'Cameras'**
  String get cameras;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get themeSystem;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout;

  /// No description provided for @invalidPhoneError.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid phone number'**
  String get invalidPhoneError;

  /// No description provided for @errorPrefix.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String errorPrefix(String error);

  /// No description provided for @networkErrorMessage.
  ///
  /// In en, this message translates to:
  /// **'Could not connect to the server. Check your internet connection or make sure the server is running.'**
  String get networkErrorMessage;

  /// No description provided for @serverErrorMessage.
  ///
  /// In en, this message translates to:
  /// **'The server returned an error. Please try again.'**
  String get serverErrorMessage;

  /// No description provided for @unknownErrorMessage.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get unknownErrorMessage;

  /// No description provided for @phoneNotRegisteredMessage.
  ///
  /// In en, this message translates to:
  /// **'This phone number is not registered at any school yet. Please contact your child\'s school.'**
  String get phoneNotRegisteredMessage;

  /// No description provided for @invalidCredentialsMessage.
  ///
  /// In en, this message translates to:
  /// **'Incorrect email or password.'**
  String get invalidCredentialsMessage;

  /// No description provided for @accountInactiveMessage.
  ///
  /// In en, this message translates to:
  /// **'Your account is inactive. Please contact your administrator.'**
  String get accountInactiveMessage;

  /// No description provided for @invalidCurrentPasswordMessage.
  ///
  /// In en, this message translates to:
  /// **'Current password is incorrect.'**
  String get invalidCurrentPasswordMessage;

  /// No description provided for @needSupport.
  ///
  /// In en, this message translates to:
  /// **'Need support? '**
  String get needSupport;

  /// No description provided for @contact.
  ///
  /// In en, this message translates to:
  /// **'Contact'**
  String get contact;

  /// No description provided for @roleDirector.
  ///
  /// In en, this message translates to:
  /// **'Director'**
  String get roleDirector;

  /// No description provided for @roleParent.
  ///
  /// In en, this message translates to:
  /// **'Parent'**
  String get roleParent;

  /// No description provided for @roleTeacher.
  ///
  /// In en, this message translates to:
  /// **'Teacher'**
  String get roleTeacher;

  /// No description provided for @createAccount.
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get createAccount;

  /// No description provided for @lastStep.
  ///
  /// In en, this message translates to:
  /// **'Last step!'**
  String get lastStep;

  /// No description provided for @tellUsName.
  ///
  /// In en, this message translates to:
  /// **'Please enter your name to complete registration for {phone}'**
  String tellUsName(String phone);

  /// No description provided for @fullName.
  ///
  /// In en, this message translates to:
  /// **'Full Name'**
  String get fullName;

  /// No description provided for @fullNameHint.
  ///
  /// In en, this message translates to:
  /// **'John Doe'**
  String get fullNameHint;

  /// No description provided for @completeRegistration.
  ///
  /// In en, this message translates to:
  /// **'Complete Registration'**
  String get completeRegistration;

  /// No description provided for @termsAndPrivacy.
  ///
  /// In en, this message translates to:
  /// **'By continuing, you agree to our Terms of Use and Privacy Policy.'**
  String get termsAndPrivacy;

  /// No description provided for @present.
  ///
  /// In en, this message translates to:
  /// **'Present'**
  String get present;

  /// No description provided for @late.
  ///
  /// In en, this message translates to:
  /// **'Late'**
  String get late;

  /// No description provided for @absent.
  ///
  /// In en, this message translates to:
  /// **'Absent'**
  String get absent;

  /// No description provided for @leftSchool.
  ///
  /// In en, this message translates to:
  /// **'Left School'**
  String get leftSchool;

  /// No description provided for @notDetected.
  ///
  /// In en, this message translates to:
  /// **'Not Detected'**
  String get notDetected;

  /// No description provided for @quickActions.
  ///
  /// In en, this message translates to:
  /// **'Quick Actions'**
  String get quickActions;

  /// No description provided for @history.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get history;

  /// No description provided for @liveStream.
  ///
  /// In en, this message translates to:
  /// **'Live Stream'**
  String get liveStream;

  /// No description provided for @recentActivity.
  ///
  /// In en, this message translates to:
  /// **'Recent Activity'**
  String get recentActivity;

  /// No description provided for @attendanceByClass.
  ///
  /// In en, this message translates to:
  /// **'Attendance by Class'**
  String get attendanceByClass;

  /// No description provided for @noAttendanceRecorded.
  ///
  /// In en, this message translates to:
  /// **'No attendance recorded yet today'**
  String get noAttendanceRecorded;

  /// No description provided for @cameraLabel.
  ///
  /// In en, this message translates to:
  /// **'Camera: {cameraId}'**
  String cameraLabel(String cameraId);

  /// No description provided for @noChildrenLinked.
  ///
  /// In en, this message translates to:
  /// **'No children linked'**
  String get noChildrenLinked;

  /// No description provided for @assignedStudentsWillAppear.
  ///
  /// In en, this message translates to:
  /// **'Assigned students will appear here.'**
  String get assignedStudentsWillAppear;

  /// No description provided for @children.
  ///
  /// In en, this message translates to:
  /// **'Children'**
  String get children;

  /// No description provided for @attendanceHistory.
  ///
  /// In en, this message translates to:
  /// **'Attendance History'**
  String get attendanceHistory;

  /// No description provided for @liveStatus.
  ///
  /// In en, this message translates to:
  /// **'Live Status'**
  String get liveStatus;

  /// No description provided for @selectClass.
  ///
  /// In en, this message translates to:
  /// **'Please select a class'**
  String get selectClass;

  /// No description provided for @studentPhotoRequired.
  ///
  /// In en, this message translates to:
  /// **'Student photo is required'**
  String get studentPhotoRequired;

  /// No description provided for @deleteStudentTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Student'**
  String get deleteStudentTitle;

  /// No description provided for @deleteStudentConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this student?'**
  String get deleteStudentConfirm;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @studentManagement.
  ///
  /// In en, this message translates to:
  /// **'Student Management'**
  String get studentManagement;

  /// No description provided for @addNewStudent.
  ///
  /// In en, this message translates to:
  /// **'Add New Student'**
  String get addNewStudent;

  /// No description provided for @editStudent.
  ///
  /// In en, this message translates to:
  /// **'Edit Student'**
  String get editStudent;

  /// No description provided for @firstName.
  ///
  /// In en, this message translates to:
  /// **'First Name'**
  String get firstName;

  /// No description provided for @lastName.
  ///
  /// In en, this message translates to:
  /// **'Last Name'**
  String get lastName;

  /// No description provided for @parentPhoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Parent Phone Number'**
  String get parentPhoneNumber;

  /// No description provided for @isActive.
  ///
  /// In en, this message translates to:
  /// **'Is Active'**
  String get isActive;

  /// No description provided for @studentFacePhoto.
  ///
  /// In en, this message translates to:
  /// **'Student Face Photo'**
  String get studentFacePhoto;

  /// No description provided for @updatePhotoOptional.
  ///
  /// In en, this message translates to:
  /// **'Update Photo (optional)'**
  String get updatePhotoOptional;

  /// No description provided for @requiredForFaceRecognition.
  ///
  /// In en, this message translates to:
  /// **'Required for face recognition'**
  String get requiredForFaceRecognition;

  /// No description provided for @addStudent.
  ///
  /// In en, this message translates to:
  /// **'Add Student'**
  String get addStudent;

  /// No description provided for @saveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get saveChanges;

  /// No description provided for @studentsList.
  ///
  /// In en, this message translates to:
  /// **'Students List'**
  String get studentsList;

  /// No description provided for @noStudents.
  ///
  /// In en, this message translates to:
  /// **'No students'**
  String get noStudents;

  /// No description provided for @studentsAssignedWillAppear.
  ///
  /// In en, this message translates to:
  /// **'Students assigned to classes and parents will appear here.'**
  String get studentsAssignedWillAppear;

  /// No description provided for @deleteClassTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Class'**
  String get deleteClassTitle;

  /// No description provided for @deleteClassConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this class? This may affect linked students and cameras.'**
  String get deleteClassConfirm;

  /// No description provided for @classManagement.
  ///
  /// In en, this message translates to:
  /// **'Class Management'**
  String get classManagement;

  /// No description provided for @createNewClass.
  ///
  /// In en, this message translates to:
  /// **'Create New Class'**
  String get createNewClass;

  /// No description provided for @editClass.
  ///
  /// In en, this message translates to:
  /// **'Edit Class'**
  String get editClass;

  /// No description provided for @classNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Class Name'**
  String get classNameLabel;

  /// No description provided for @classNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g., 9A, 10B'**
  String get classNameHint;

  /// No description provided for @gradeOptional.
  ///
  /// In en, this message translates to:
  /// **'Grade (optional)'**
  String get gradeOptional;

  /// No description provided for @gradeHint.
  ///
  /// In en, this message translates to:
  /// **'Auto-detected if empty'**
  String get gradeHint;

  /// No description provided for @createClass.
  ///
  /// In en, this message translates to:
  /// **'Create Class'**
  String get createClass;

  /// No description provided for @existingClasses.
  ///
  /// In en, this message translates to:
  /// **'Existing Classes'**
  String get existingClasses;

  /// No description provided for @noClasses.
  ///
  /// In en, this message translates to:
  /// **'No classes'**
  String get noClasses;

  /// No description provided for @createClassesMessage.
  ///
  /// In en, this message translates to:
  /// **'Create classes to monitor attendance.'**
  String get createClassesMessage;

  /// No description provided for @gradeLabel.
  ///
  /// In en, this message translates to:
  /// **'Grade {grade}'**
  String gradeLabel(String grade);

  /// No description provided for @deleteCameraTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Camera'**
  String get deleteCameraTitle;

  /// No description provided for @deleteCameraConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this camera?'**
  String get deleteCameraConfirm;

  /// No description provided for @cameraManagement.
  ///
  /// In en, this message translates to:
  /// **'Camera Management'**
  String get cameraManagement;

  /// No description provided for @addNewCamera.
  ///
  /// In en, this message translates to:
  /// **'Add New Camera'**
  String get addNewCamera;

  /// No description provided for @editCamera.
  ///
  /// In en, this message translates to:
  /// **'Edit Camera'**
  String get editCamera;

  /// No description provided for @cameraNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Camera Name'**
  String get cameraNameLabel;

  /// No description provided for @assignToClass.
  ///
  /// In en, this message translates to:
  /// **'Assign to Class'**
  String get assignToClass;

  /// No description provided for @rtspUrl.
  ///
  /// In en, this message translates to:
  /// **'RTSP URL'**
  String get rtspUrl;

  /// No description provided for @startTime.
  ///
  /// In en, this message translates to:
  /// **'Start Time'**
  String get startTime;

  /// No description provided for @endTime.
  ///
  /// In en, this message translates to:
  /// **'End Time'**
  String get endTime;

  /// No description provided for @detectSec.
  ///
  /// In en, this message translates to:
  /// **'Detection (sec)'**
  String get detectSec;

  /// No description provided for @waitMin.
  ///
  /// In en, this message translates to:
  /// **'Wait (min)'**
  String get waitMin;

  /// No description provided for @addCamera.
  ///
  /// In en, this message translates to:
  /// **'Add Camera'**
  String get addCamera;

  /// No description provided for @registeredCameras.
  ///
  /// In en, this message translates to:
  /// **'Registered Cameras'**
  String get registeredCameras;

  /// No description provided for @noCameras.
  ///
  /// In en, this message translates to:
  /// **'No cameras'**
  String get noCameras;

  /// No description provided for @classroomCamerasWillAppear.
  ///
  /// In en, this message translates to:
  /// **'Classroom cameras will appear here.'**
  String get classroomCamerasWillAppear;

  /// No description provided for @cameraListSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Class: {className} • Wait: {waitDuration}m'**
  String cameraListSubtitle(String className, String waitDuration);

  /// No description provided for @unassigned.
  ///
  /// In en, this message translates to:
  /// **'Unassigned'**
  String get unassigned;

  /// No description provided for @noAttendanceRecords.
  ///
  /// In en, this message translates to:
  /// **'No attendance records'**
  String get noAttendanceRecords;

  /// No description provided for @recordsWillAppear.
  ///
  /// In en, this message translates to:
  /// **'Records will appear once face recognition starts.'**
  String get recordsWillAppear;

  /// No description provided for @inTimeOutTime.
  ///
  /// In en, this message translates to:
  /// **'In {inTime}  Out {outTime}'**
  String inTimeOutTime(String inTime, String outTime);

  /// No description provided for @noLiveData.
  ///
  /// In en, this message translates to:
  /// **'No live data'**
  String get noLiveData;

  /// No description provided for @realtimeAttendanceMessage.
  ///
  /// In en, this message translates to:
  /// **'Real-time attendance will appear during detection.'**
  String get realtimeAttendanceMessage;

  /// No description provided for @lastSeenTime.
  ///
  /// In en, this message translates to:
  /// **'Last seen at {time}'**
  String lastSeenTime(String time);

  /// No description provided for @directorNotifications.
  ///
  /// In en, this message translates to:
  /// **'Director Notifications'**
  String get directorNotifications;

  /// No description provided for @schoolWideNotificationView.
  ///
  /// In en, this message translates to:
  /// **'School-wide notification view can be enabled later.'**
  String get schoolWideNotificationView;

  /// No description provided for @noNotifications.
  ///
  /// In en, this message translates to:
  /// **'No notifications'**
  String get noNotifications;

  /// No description provided for @attendanceAlertsWillAppear.
  ///
  /// In en, this message translates to:
  /// **'Attendance alerts will appear here.'**
  String get attendanceAlertsWillAppear;

  /// No description provided for @studentNotFound.
  ///
  /// In en, this message translates to:
  /// **'Student not found'**
  String get studentNotFound;

  /// No description provided for @classLabel.
  ///
  /// In en, this message translates to:
  /// **'Class {classId}'**
  String classLabel(String classId);

  /// No description provided for @parentLabel.
  ///
  /// In en, this message translates to:
  /// **'Parent {parentId}'**
  String parentLabel(String parentId);

  /// No description provided for @viewAttendanceHistoryButton.
  ///
  /// In en, this message translates to:
  /// **'View Attendance History'**
  String get viewAttendanceHistoryButton;

  /// No description provided for @viewLiveStatusButton.
  ///
  /// In en, this message translates to:
  /// **'View Live Status'**
  String get viewLiveStatusButton;

  /// No description provided for @signOutTooltip.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOutTooltip;

  /// No description provided for @classTileLabel.
  ///
  /// In en, this message translates to:
  /// **'Class: {className}'**
  String classTileLabel(String className);

  /// No description provided for @classAttendanceRatio.
  ///
  /// In en, this message translates to:
  /// **'{className} • {arrived}/{total} arrived'**
  String classAttendanceRatio(String className, int arrived, int total);

  /// No description provided for @directorDashboard.
  ///
  /// In en, this message translates to:
  /// **'Director Dashboard'**
  String get directorDashboard;

  /// No description provided for @parentDashboard.
  ///
  /// In en, this message translates to:
  /// **'Parent Dashboard'**
  String get parentDashboard;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @grades.
  ///
  /// In en, this message translates to:
  /// **'Grades'**
  String get grades;

  /// No description provided for @noGrades.
  ///
  /// In en, this message translates to:
  /// **'No grades yet'**
  String get noGrades;

  /// No description provided for @noGradesMessage.
  ///
  /// In en, this message translates to:
  /// **'Grades will appear here once a teacher enters them.'**
  String get noGradesMessage;

  /// No description provided for @studentFallbackLabel.
  ///
  /// In en, this message translates to:
  /// **'Student #{id}'**
  String studentFallbackLabel(String id);

  /// No description provided for @teacherMyClasses.
  ///
  /// In en, this message translates to:
  /// **'My Classes'**
  String get teacherMyClasses;

  /// No description provided for @teacherNoClassesTitle.
  ///
  /// In en, this message translates to:
  /// **'You have no classes assigned yet'**
  String get teacherNoClassesTitle;

  /// No description provided for @teacherNoClassesMessage.
  ///
  /// In en, this message translates to:
  /// **'This will appear once the director assigns you a class.'**
  String get teacherNoClassesMessage;

  /// No description provided for @classFallbackLabel.
  ///
  /// In en, this message translates to:
  /// **'Class #{classId}'**
  String classFallbackLabel(String classId);

  /// No description provided for @journalStudentColumn.
  ///
  /// In en, this message translates to:
  /// **'Student'**
  String get journalStudentColumn;

  /// No description provided for @journalScoreLabel.
  ///
  /// In en, this message translates to:
  /// **'Grade'**
  String get journalScoreLabel;

  /// No description provided for @journalCommentOptional.
  ///
  /// In en, this message translates to:
  /// **'Comment (optional)'**
  String get journalCommentOptional;

  /// No description provided for @journalTeacherLabel.
  ///
  /// In en, this message translates to:
  /// **'Teacher'**
  String get journalTeacherLabel;

  /// No description provided for @journalNoComment.
  ///
  /// In en, this message translates to:
  /// **'No comment'**
  String get journalNoComment;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @journalNoStudentsTitle.
  ///
  /// In en, this message translates to:
  /// **'No students found in this class'**
  String get journalNoStudentsTitle;

  /// No description provided for @journalNoStudentsMessage.
  ///
  /// In en, this message translates to:
  /// **'This will appear once the director assigns students to this class.'**
  String get journalNoStudentsMessage;

  /// No description provided for @teachers.
  ///
  /// In en, this message translates to:
  /// **'Teachers'**
  String get teachers;

  /// No description provided for @addNewTeacher.
  ///
  /// In en, this message translates to:
  /// **'New teacher'**
  String get addNewTeacher;

  /// No description provided for @create.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// No description provided for @existingTeachers.
  ///
  /// In en, this message translates to:
  /// **'Existing teachers'**
  String get existingTeachers;

  /// No description provided for @noTeachers.
  ///
  /// In en, this message translates to:
  /// **'No teachers yet'**
  String get noTeachers;

  /// No description provided for @noTeachersMessage.
  ///
  /// In en, this message translates to:
  /// **'Add a new teacher using the form above.'**
  String get noTeachersMessage;

  /// No description provided for @assignClassToTeacher.
  ///
  /// In en, this message translates to:
  /// **'Assign a class to {name}'**
  String assignClassToTeacher(String name);

  /// No description provided for @assignClassNoClasses.
  ///
  /// In en, this message translates to:
  /// **'Create a class first.'**
  String get assignClassNoClasses;

  /// No description provided for @noClassesAssignedYet.
  ///
  /// In en, this message translates to:
  /// **'Not assigned to any class yet'**
  String get noClassesAssignedYet;

  /// No description provided for @removeAssignment.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get removeAssignment;

  /// No description provided for @addSubjectTitle.
  ///
  /// In en, this message translates to:
  /// **'Add subject'**
  String get addSubjectTitle;

  /// No description provided for @noTeachersForSubject.
  ///
  /// In en, this message translates to:
  /// **'No teachers registered for this subject yet'**
  String get noTeachersForSubject;

  /// No description provided for @noSubjectsInClass.
  ///
  /// In en, this message translates to:
  /// **'No subjects added to this class yet'**
  String get noSubjectsInClass;

  /// No description provided for @addSubjectToStart.
  ///
  /// In en, this message translates to:
  /// **'Tap \"Add subject\" to assign a teacher.'**
  String get addSubjectToStart;

  /// No description provided for @subjectsLabel.
  ///
  /// In en, this message translates to:
  /// **'Subjects'**
  String get subjectsLabel;

  /// No description provided for @subjectsAndTeachers.
  ///
  /// In en, this message translates to:
  /// **'Subjects & teachers'**
  String get subjectsAndTeachers;

  /// No description provided for @viewJournal.
  ///
  /// In en, this message translates to:
  /// **'View journal'**
  String get viewJournal;

  /// No description provided for @removeAssignmentConfirm.
  ///
  /// In en, this message translates to:
  /// **'Remove this teacher from this subject in the class? Grades they already entered will stay.'**
  String get removeAssignmentConfirm;

  /// No description provided for @subjectLabel.
  ///
  /// In en, this message translates to:
  /// **'Subject'**
  String get subjectLabel;

  /// No description provided for @assign.
  ///
  /// In en, this message translates to:
  /// **'Assign'**
  String get assign;

  /// No description provided for @classAssigned.
  ///
  /// In en, this message translates to:
  /// **'Class assigned'**
  String get classAssigned;

  /// No description provided for @month1.
  ///
  /// In en, this message translates to:
  /// **'January'**
  String get month1;

  /// No description provided for @month2.
  ///
  /// In en, this message translates to:
  /// **'February'**
  String get month2;

  /// No description provided for @month3.
  ///
  /// In en, this message translates to:
  /// **'March'**
  String get month3;

  /// No description provided for @month4.
  ///
  /// In en, this message translates to:
  /// **'April'**
  String get month4;

  /// No description provided for @month5.
  ///
  /// In en, this message translates to:
  /// **'May'**
  String get month5;

  /// No description provided for @month6.
  ///
  /// In en, this message translates to:
  /// **'June'**
  String get month6;

  /// No description provided for @month7.
  ///
  /// In en, this message translates to:
  /// **'July'**
  String get month7;

  /// No description provided for @month8.
  ///
  /// In en, this message translates to:
  /// **'August'**
  String get month8;

  /// No description provided for @month9.
  ///
  /// In en, this message translates to:
  /// **'September'**
  String get month9;

  /// No description provided for @month10.
  ///
  /// In en, this message translates to:
  /// **'October'**
  String get month10;

  /// No description provided for @month11.
  ///
  /// In en, this message translates to:
  /// **'November'**
  String get month11;

  /// No description provided for @month12.
  ///
  /// In en, this message translates to:
  /// **'December'**
  String get month12;

  /// No description provided for @deleteTeacherTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Teacher'**
  String get deleteTeacherTitle;

  /// No description provided for @deleteTeacherConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this teacher? Their class assignments and entered grades will also be removed.'**
  String get deleteTeacherConfirm;

  /// No description provided for @average.
  ///
  /// In en, this message translates to:
  /// **'Average'**
  String get average;

  /// No description provided for @weekday1.
  ///
  /// In en, this message translates to:
  /// **'Mon'**
  String get weekday1;

  /// No description provided for @weekday2.
  ///
  /// In en, this message translates to:
  /// **'Tue'**
  String get weekday2;

  /// No description provided for @weekday3.
  ///
  /// In en, this message translates to:
  /// **'Wed'**
  String get weekday3;

  /// No description provided for @weekday4.
  ///
  /// In en, this message translates to:
  /// **'Thu'**
  String get weekday4;

  /// No description provided for @weekday5.
  ///
  /// In en, this message translates to:
  /// **'Fri'**
  String get weekday5;

  /// No description provided for @weekday6.
  ///
  /// In en, this message translates to:
  /// **'Sat'**
  String get weekday6;

  /// No description provided for @weekday7.
  ///
  /// In en, this message translates to:
  /// **'Sun'**
  String get weekday7;

  /// No description provided for @attendanceJournal.
  ///
  /// In en, this message translates to:
  /// **'Attendance journal'**
  String get attendanceJournal;

  /// No description provided for @lastSeenLabel.
  ///
  /// In en, this message translates to:
  /// **'Last seen'**
  String get lastSeenLabel;

  /// No description provided for @noAttendanceThisMonth.
  ///
  /// In en, this message translates to:
  /// **'No attendance records this month'**
  String get noAttendanceThisMonth;

  /// No description provided for @noCameraForClassTitle.
  ///
  /// In en, this message translates to:
  /// **'No camera for this class'**
  String get noCameraForClassTitle;

  /// No description provided for @noCameraForClassMessage.
  ///
  /// In en, this message translates to:
  /// **'Assign a camera to this class in Camera Management to see its live status.'**
  String get noCameraForClassMessage;

  /// No description provided for @studentNotAssignedToClass.
  ///
  /// In en, this message translates to:
  /// **'This student isn\'t assigned to a class yet'**
  String get studentNotAssignedToClass;

  /// No description provided for @cameraNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'Camera capture isn\'t available on this device. Use Gallery instead.'**
  String get cameraNotAvailable;

  /// No description provided for @rooms.
  ///
  /// In en, this message translates to:
  /// **'Rooms'**
  String get rooms;

  /// No description provided for @roomManagement.
  ///
  /// In en, this message translates to:
  /// **'Room Management'**
  String get roomManagement;

  /// No description provided for @addNewRoom.
  ///
  /// In en, this message translates to:
  /// **'Add New Room'**
  String get addNewRoom;

  /// No description provided for @editRoom.
  ///
  /// In en, this message translates to:
  /// **'Edit Room'**
  String get editRoom;

  /// No description provided for @roomNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Room Name'**
  String get roomNameLabel;

  /// No description provided for @assignToRoom.
  ///
  /// In en, this message translates to:
  /// **'Assign to Room'**
  String get assignToRoom;

  /// No description provided for @positions.
  ///
  /// In en, this message translates to:
  /// **'Positions'**
  String get positions;

  /// No description provided for @addPosition.
  ///
  /// In en, this message translates to:
  /// **'Add Position'**
  String get addPosition;

  /// No description provided for @positionClassLabel.
  ///
  /// In en, this message translates to:
  /// **'Class'**
  String get positionClassLabel;

  /// No description provided for @registeredRooms.
  ///
  /// In en, this message translates to:
  /// **'Registered Rooms'**
  String get registeredRooms;

  /// No description provided for @noRooms.
  ///
  /// In en, this message translates to:
  /// **'No rooms'**
  String get noRooms;

  /// No description provided for @roomsWillAppear.
  ///
  /// In en, this message translates to:
  /// **'Rooms will appear here.'**
  String get roomsWillAppear;

  /// No description provided for @deleteRoomTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Room'**
  String get deleteRoomTitle;

  /// No description provided for @deleteRoomConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this room?'**
  String get deleteRoomConfirm;

  /// No description provided for @roomHasCamerasError.
  ///
  /// In en, this message translates to:
  /// **'Reassign or remove this room\'s cameras before deleting it.'**
  String get roomHasCamerasError;

  /// No description provided for @cameraListSubtitleRoom.
  ///
  /// In en, this message translates to:
  /// **'Room: {roomName} • Wait: {waitDuration}m'**
  String cameraListSubtitleRoom(String roomName, String waitDuration);

  /// No description provided for @roomPositionSubtitle.
  ///
  /// In en, this message translates to:
  /// **'{className}: {startTime}–{endTime}'**
  String roomPositionSubtitle(
    String className,
    String startTime,
    String endTime,
  );

  /// No description provided for @analyticsScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'{className} - Analytics'**
  String analyticsScreenTitle(String className);

  /// No description provided for @noDataTitle.
  ///
  /// In en, this message translates to:
  /// **'No data'**
  String get noDataTitle;

  /// No description provided for @noAttendanceDataLast30Days.
  ///
  /// In en, this message translates to:
  /// **'No attendance data for last 30 days'**
  String get noAttendanceDataLast30Days;

  /// No description provided for @perStudentDetails.
  ///
  /// In en, this message translates to:
  /// **'Per-Student Details'**
  String get perStudentDetails;

  /// No description provided for @hoursLabel.
  ///
  /// In en, this message translates to:
  /// **'Hours'**
  String get hoursLabel;

  /// No description provided for @thirtyDayTimeline.
  ///
  /// In en, this message translates to:
  /// **'30-Day Timeline'**
  String get thirtyDayTimeline;

  /// No description provided for @noTimetableSubjectsTitle.
  ///
  /// In en, this message translates to:
  /// **'No timetable subjects'**
  String get noTimetableSubjectsTitle;

  /// No description provided for @noTimetableSubjectsMessage.
  ///
  /// In en, this message translates to:
  /// **'Add lessons to this class timetable first.'**
  String get noTimetableSubjectsMessage;

  /// No description provided for @tapToAssignTeacher.
  ///
  /// In en, this message translates to:
  /// **'Tap to assign teacher'**
  String get tapToAssignTeacher;

  /// No description provided for @timetableLabel.
  ///
  /// In en, this message translates to:
  /// **'Timetable'**
  String get timetableLabel;

  /// No description provided for @totalHoursPerWeek.
  ///
  /// In en, this message translates to:
  /// **'Total: {hours} h/week'**
  String totalHoursPerWeek(String hours);

  /// No description provided for @noLessonsForDay.
  ///
  /// In en, this message translates to:
  /// **'No lessons for this day'**
  String get noLessonsForDay;

  /// No description provided for @addLesson.
  ///
  /// In en, this message translates to:
  /// **'Add Lesson'**
  String get addLesson;

  /// No description provided for @minutesUnit.
  ///
  /// In en, this message translates to:
  /// **'min'**
  String get minutesUnit;

  /// No description provided for @cameraOptionTooltip.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get cameraOptionTooltip;

  /// No description provided for @galleryOptionTooltip.
  ///
  /// In en, this message translates to:
  /// **'Gallery'**
  String get galleryOptionTooltip;

  /// No description provided for @noFrame.
  ///
  /// In en, this message translates to:
  /// **'No frame'**
  String get noFrame;

  /// No description provided for @selectMonth.
  ///
  /// In en, this message translates to:
  /// **'Select month'**
  String get selectMonth;

  /// No description provided for @generatePdfReport.
  ///
  /// In en, this message translates to:
  /// **'Generate PDF Report'**
  String get generatePdfReport;

  /// No description provided for @pdfReportEyebrow.
  ///
  /// In en, this message translates to:
  /// **'ATTENDANCE REPORT'**
  String get pdfReportEyebrow;

  /// No description provided for @pdfNoDataForMonth.
  ///
  /// In en, this message translates to:
  /// **'No attendance data for the selected month'**
  String get pdfNoDataForMonth;

  /// No description provided for @columnPresentDays.
  ///
  /// In en, this message translates to:
  /// **'Present days'**
  String get columnPresentDays;

  /// No description provided for @columnLateDays.
  ///
  /// In en, this message translates to:
  /// **'Late days'**
  String get columnLateDays;

  /// No description provided for @columnAbsentDays.
  ///
  /// In en, this message translates to:
  /// **'Absent days'**
  String get columnAbsentDays;

  /// No description provided for @columnPresentHours.
  ///
  /// In en, this message translates to:
  /// **'Present hours'**
  String get columnPresentHours;

  /// No description provided for @columnAbsentHours.
  ///
  /// In en, this message translates to:
  /// **'Absent hours'**
  String get columnAbsentHours;

  /// No description provided for @columnRate.
  ///
  /// In en, this message translates to:
  /// **'Rate'**
  String get columnRate;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ru', 'tg'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ru':
      return AppLocalizationsRu();
    case 'tg':
      return AppLocalizationsTg();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
