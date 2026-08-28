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

  /// No description provided for @usernameTakenMessage.
  ///
  /// In en, this message translates to:
  /// **'This login is already taken. Please choose another one.'**
  String get usernameTakenMessage;

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

  /// No description provided for @roleStudent.
  ///
  /// In en, this message translates to:
  /// **'Student'**
  String get roleStudent;

  /// No description provided for @studentUsernameLabel.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get studentUsernameLabel;

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

  /// No description provided for @ratingAnalytics.
  ///
  /// In en, this message translates to:
  /// **'Rating'**
  String get ratingAnalytics;

  /// No description provided for @overallAverage.
  ///
  /// In en, this message translates to:
  /// **'Overall average'**
  String get overallAverage;

  /// No description provided for @classRank.
  ///
  /// In en, this message translates to:
  /// **'Class'**
  String get classRank;

  /// No description provided for @parallelRank.
  ///
  /// In en, this message translates to:
  /// **'Parallel'**
  String get parallelRank;

  /// No description provided for @schoolRank.
  ///
  /// In en, this message translates to:
  /// **'School'**
  String get schoolRank;

  /// No description provided for @classRanking.
  ///
  /// In en, this message translates to:
  /// **'Class ranking'**
  String get classRanking;

  /// No description provided for @parallelRanking.
  ///
  /// In en, this message translates to:
  /// **'Parallel ranking'**
  String get parallelRanking;

  /// No description provided for @schoolRanking.
  ///
  /// In en, this message translates to:
  /// **'School ranking'**
  String get schoolRanking;

  /// No description provided for @strongestSubject.
  ///
  /// In en, this message translates to:
  /// **'Strongest subject'**
  String get strongestSubject;

  /// No description provided for @weakestSubject.
  ///
  /// In en, this message translates to:
  /// **'Needs attention'**
  String get weakestSubject;

  /// No description provided for @subjectBreakdown.
  ///
  /// In en, this message translates to:
  /// **'Subjects'**
  String get subjectBreakdown;

  /// No description provided for @lessonAttendanceRate.
  ///
  /// In en, this message translates to:
  /// **'Lesson attendance'**
  String get lessonAttendanceRate;

  /// No description provided for @quarter1.
  ///
  /// In en, this message translates to:
  /// **'Quarter 1'**
  String get quarter1;

  /// No description provided for @quarter2.
  ///
  /// In en, this message translates to:
  /// **'Quarter 2'**
  String get quarter2;

  /// No description provided for @quarter3.
  ///
  /// In en, this message translates to:
  /// **'Quarter 3'**
  String get quarter3;

  /// No description provided for @quarter4.
  ///
  /// In en, this message translates to:
  /// **'Quarter 4'**
  String get quarter4;

  /// No description provided for @noGradesYetMessage.
  ///
  /// In en, this message translates to:
  /// **'No grades recorded yet for this period'**
  String get noGradesYetMessage;

  /// No description provided for @achievementFirstPlace.
  ///
  /// In en, this message translates to:
  /// **'1st place'**
  String get achievementFirstPlace;

  /// No description provided for @achievementTopThree.
  ///
  /// In en, this message translates to:
  /// **'Top 3'**
  String get achievementTopThree;

  /// No description provided for @achievementTopTenPercent.
  ///
  /// In en, this message translates to:
  /// **'Top 10%'**
  String get achievementTopTenPercent;

  /// No description provided for @exportPdf.
  ///
  /// In en, this message translates to:
  /// **'Export PDF'**
  String get exportPdf;

  /// No description provided for @classAverage.
  ///
  /// In en, this message translates to:
  /// **'Class avg'**
  String get classAverage;

  /// No description provided for @parallelAverage.
  ///
  /// In en, this message translates to:
  /// **'Parallel avg'**
  String get parallelAverage;

  /// No description provided for @schoolAverage.
  ///
  /// In en, this message translates to:
  /// **'School avg'**
  String get schoolAverage;

  /// No description provided for @needsAttention.
  ///
  /// In en, this message translates to:
  /// **'Needs attention'**
  String get needsAttention;

  /// No description provided for @biggestDecline.
  ///
  /// In en, this message translates to:
  /// **'Biggest decline'**
  String get biggestDecline;

  /// No description provided for @lowestAverage.
  ///
  /// In en, this message translates to:
  /// **'Lowest average'**
  String get lowestAverage;

  /// No description provided for @trendVsPreviousQuarter.
  ///
  /// In en, this message translates to:
  /// **'vs previous quarter'**
  String get trendVsPreviousQuarter;

  /// No description provided for @pdfRatingEyebrow.
  ///
  /// In en, this message translates to:
  /// **'RATING REPORT'**
  String get pdfRatingEyebrow;

  /// No description provided for @gradeCountSuffix.
  ///
  /// In en, this message translates to:
  /// **'grades'**
  String get gradeCountSuffix;

  /// No description provided for @rankingScopeAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get rankingScopeAll;

  /// No description provided for @rankingScopeClasses.
  ///
  /// In en, this message translates to:
  /// **'Classes'**
  String get rankingScopeClasses;

  /// No description provided for @rankingScopeParallel.
  ///
  /// In en, this message translates to:
  /// **'Parallel'**
  String get rankingScopeParallel;

  /// No description provided for @selectClassPrompt.
  ///
  /// In en, this message translates to:
  /// **'Select a class'**
  String get selectClassPrompt;

  /// No description provided for @selectParallelPrompt.
  ///
  /// In en, this message translates to:
  /// **'Select a parallel'**
  String get selectParallelPrompt;

  /// No description provided for @topThree.
  ///
  /// In en, this message translates to:
  /// **'Top 3'**
  String get topThree;

  /// No description provided for @lessonSchedule.
  ///
  /// In en, this message translates to:
  /// **'Schedule — {className}'**
  String lessonSchedule(String className);

  /// No description provided for @editLesson.
  ///
  /// In en, this message translates to:
  /// **'Edit lesson'**
  String get editLesson;

  /// No description provided for @deleteLessonTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete lesson'**
  String get deleteLessonTitle;

  /// No description provided for @deleteLessonConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete this lesson? This cannot be undone.'**
  String get deleteLessonConfirm;

  /// No description provided for @roomLabel.
  ///
  /// In en, this message translates to:
  /// **'Room'**
  String get roomLabel;

  /// No description provided for @ruznoma.
  ///
  /// In en, this message translates to:
  /// **'Diary'**
  String get ruznoma;

  /// No description provided for @todayLessons.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get todayLessons;

  /// No description provided for @tomorrowLessons.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow'**
  String get tomorrowLessons;

  /// No description provided for @homeworkLabel.
  ///
  /// In en, this message translates to:
  /// **'Homework'**
  String get homeworkLabel;

  /// No description provided for @teacherNoteLabel.
  ///
  /// In en, this message translates to:
  /// **'Teacher\'s note'**
  String get teacherNoteLabel;

  /// No description provided for @addHomeworkPrompt.
  ///
  /// In en, this message translates to:
  /// **'Add homework or a note'**
  String get addHomeworkPrompt;

  /// No description provided for @noLessonsToday.
  ///
  /// In en, this message translates to:
  /// **'No lessons for this day'**
  String get noLessonsToday;

  /// No description provided for @schoolCalendar.
  ///
  /// In en, this message translates to:
  /// **'School calendar'**
  String get schoolCalendar;

  /// No description provided for @eventTypeHoliday.
  ///
  /// In en, this message translates to:
  /// **'Holiday'**
  String get eventTypeHoliday;

  /// No description provided for @eventTypeExam.
  ///
  /// In en, this message translates to:
  /// **'Exam'**
  String get eventTypeExam;

  /// No description provided for @eventTypeTest.
  ///
  /// In en, this message translates to:
  /// **'Control work'**
  String get eventTypeTest;

  /// No description provided for @eventTypeEvent.
  ///
  /// In en, this message translates to:
  /// **'Event'**
  String get eventTypeEvent;

  /// No description provided for @addEvent.
  ///
  /// In en, this message translates to:
  /// **'Add event'**
  String get addEvent;

  /// No description provided for @eventTitleLabel.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get eventTitleLabel;

  /// No description provided for @eventDescriptionLabel.
  ///
  /// In en, this message translates to:
  /// **'Description (optional)'**
  String get eventDescriptionLabel;

  /// No description provided for @noUpcomingEvents.
  ///
  /// In en, this message translates to:
  /// **'No upcoming events'**
  String get noUpcomingEvents;

  /// No description provided for @deleteEventTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete event'**
  String get deleteEventTitle;

  /// No description provided for @deleteEventConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete this event?'**
  String get deleteEventConfirm;

  /// No description provided for @announcements.
  ///
  /// In en, this message translates to:
  /// **'Announcements'**
  String get announcements;

  /// No description provided for @postAnnouncement.
  ///
  /// In en, this message translates to:
  /// **'Post announcement'**
  String get postAnnouncement;

  /// No description provided for @announcementTitleLabel.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get announcementTitleLabel;

  /// No description provided for @announcementBodyLabel.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get announcementBodyLabel;

  /// No description provided for @noAnnouncementsYet.
  ///
  /// In en, this message translates to:
  /// **'No announcements yet'**
  String get noAnnouncementsYet;

  /// No description provided for @deleteAnnouncementTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete announcement'**
  String get deleteAnnouncementTitle;

  /// No description provided for @deleteAnnouncementConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete this announcement?'**
  String get deleteAnnouncementConfirm;

  /// No description provided for @pickDatePrompt.
  ///
  /// In en, this message translates to:
  /// **'Select a date'**
  String get pickDatePrompt;

  /// No description provided for @lessonWord.
  ///
  /// In en, this message translates to:
  /// **'lesson'**
  String get lessonWord;

  /// No description provided for @lessonsCountSuffix.
  ///
  /// In en, this message translates to:
  /// **'lessons'**
  String get lessonsCountSuffix;

  /// No description provided for @untilTime.
  ///
  /// In en, this message translates to:
  /// **'until {time}'**
  String untilTime(String time);

  /// No description provided for @teacherWord.
  ///
  /// In en, this message translates to:
  /// **'Teacher'**
  String get teacherWord;

  /// No description provided for @lessonOrdinal.
  ///
  /// In en, this message translates to:
  /// **'Lesson {number}'**
  String lessonOrdinal(int number);

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @logoutConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to sign out?'**
  String get logoutConfirmMessage;

  /// No description provided for @homeworkListTitle.
  ///
  /// In en, this message translates to:
  /// **'Homework'**
  String get homeworkListTitle;

  /// No description provided for @noHomeworkMessage.
  ///
  /// In en, this message translates to:
  /// **'No homework assigned yet'**
  String get noHomeworkMessage;

  /// No description provided for @achievementsTitle.
  ///
  /// In en, this message translates to:
  /// **'Achievements'**
  String get achievementsTitle;

  /// No description provided for @achievementSchoolFirst.
  ///
  /// In en, this message translates to:
  /// **'#1 in school'**
  String get achievementSchoolFirst;

  /// No description provided for @achievementTopThreeBadge.
  ///
  /// In en, this message translates to:
  /// **'Top 3'**
  String get achievementTopThreeBadge;

  /// No description provided for @achievementExcellent.
  ///
  /// In en, this message translates to:
  /// **'Excellent student'**
  String get achievementExcellent;

  /// No description provided for @achievementPerfectAttendance.
  ///
  /// In en, this message translates to:
  /// **'Perfect attendance'**
  String get achievementPerfectAttendance;

  /// No description provided for @achievementBigImprovement.
  ///
  /// In en, this message translates to:
  /// **'Most improved'**
  String get achievementBigImprovement;

  /// No description provided for @achievementSubjectMaster.
  ///
  /// In en, this message translates to:
  /// **'{subject} master'**
  String achievementSubjectMaster(String subject);

  /// No description provided for @noAchievementsTitle.
  ///
  /// In en, this message translates to:
  /// **'No achievements yet'**
  String get noAchievementsTitle;

  /// No description provided for @noAchievementsMessage.
  ///
  /// In en, this message translates to:
  /// **'Keep studying -- your first badge is just around the corner'**
  String get noAchievementsMessage;

  /// No description provided for @studentHomeTitle.
  ///
  /// In en, this message translates to:
  /// **'My page'**
  String get studentHomeTitle;

  /// No description provided for @studentLoginLabel.
  ///
  /// In en, this message translates to:
  /// **'Login username'**
  String get studentLoginLabel;

  /// No description provided for @studentPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get studentPasswordLabel;

  /// No description provided for @studentLoginHelperText.
  ///
  /// In en, this message translates to:
  /// **'Optional -- only needed if this student should log in on their own'**
  String get studentLoginHelperText;

  /// No description provided for @journalScanTitle.
  ///
  /// In en, this message translates to:
  /// **'Scan journal'**
  String get journalScanTitle;

  /// No description provided for @journalScanPrompt.
  ///
  /// In en, this message translates to:
  /// **'Take a photo of the journal page, or pick one from your gallery. Grades in today\'s column will be read automatically.'**
  String get journalScanPrompt;

  /// No description provided for @journalScanTakePhoto.
  ///
  /// In en, this message translates to:
  /// **'Take photo'**
  String get journalScanTakePhoto;

  /// No description provided for @journalScanPickGallery.
  ///
  /// In en, this message translates to:
  /// **'Choose from gallery'**
  String get journalScanPickGallery;

  /// No description provided for @journalScanEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing detected'**
  String get journalScanEmptyTitle;

  /// No description provided for @journalScanEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'No grades were found in today\'s column of this photo. Try a clearer, straighter photo.'**
  String get journalScanEmptyMessage;

  /// No description provided for @journalScanConfirmAll.
  ///
  /// In en, this message translates to:
  /// **'Confirm and save'**
  String get journalScanConfirmAll;

  /// No description provided for @journalScanSavedCount.
  ///
  /// In en, this message translates to:
  /// **'{saved} of {total} grades saved'**
  String journalScanSavedCount(int saved, int total);

  /// No description provided for @journalScanNoMatch.
  ///
  /// In en, this message translates to:
  /// **'No matching student for \"{name}\" -- skipped'**
  String journalScanNoMatch(String name);

  /// No description provided for @journalScanRawName.
  ///
  /// In en, this message translates to:
  /// **'Read as: {name}'**
  String journalScanRawName(String name);

  /// No description provided for @journalScanAbsent.
  ///
  /// In en, this message translates to:
  /// **'Absent'**
  String get journalScanAbsent;

  /// No description provided for @attendanceToday.
  ///
  /// In en, this message translates to:
  /// **'Today\'s attendance'**
  String get attendanceToday;

  /// No description provided for @sectionLearning.
  ///
  /// In en, this message translates to:
  /// **'Learning'**
  String get sectionLearning;

  /// No description provided for @sectionSchool.
  ///
  /// In en, this message translates to:
  /// **'School'**
  String get sectionSchool;

  /// No description provided for @arrivedOfTotal.
  ///
  /// In en, this message translates to:
  /// **'{arrived} of {total} arrived'**
  String arrivedOfTotal(int arrived, int total);

  /// No description provided for @materialsTitle.
  ///
  /// In en, this message translates to:
  /// **'Materials'**
  String get materialsTitle;

  /// No description provided for @materialsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Lessons and tests for your classes'**
  String get materialsSubtitle;

  /// No description provided for @materialLibrary.
  ///
  /// In en, this message translates to:
  /// **'My library'**
  String get materialLibrary;

  /// No description provided for @materialHandedOut.
  ///
  /// In en, this message translates to:
  /// **'Handed out'**
  String get materialHandedOut;

  /// No description provided for @materialNew.
  ///
  /// In en, this message translates to:
  /// **'New material'**
  String get materialNew;

  /// No description provided for @materialTitleLabel.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get materialTitleLabel;

  /// No description provided for @materialDescriptionLabel.
  ///
  /// In en, this message translates to:
  /// **'Short description'**
  String get materialDescriptionLabel;

  /// No description provided for @materialEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No materials yet'**
  String get materialEmptyTitle;

  /// No description provided for @materialEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'Create a lesson or a test and hand it to your class.'**
  String get materialEmptyMessage;

  /// No description provided for @materialContentEmpty.
  ///
  /// In en, this message translates to:
  /// **'Add at least one page or question.'**
  String get materialContentEmpty;

  /// No description provided for @materialPage.
  ///
  /// In en, this message translates to:
  /// **'Page'**
  String get materialPage;

  /// No description provided for @materialQuestion.
  ///
  /// In en, this message translates to:
  /// **'Question'**
  String get materialQuestion;

  /// No description provided for @materialAddPage.
  ///
  /// In en, this message translates to:
  /// **'Page'**
  String get materialAddPage;

  /// No description provided for @materialAddQuestion.
  ///
  /// In en, this message translates to:
  /// **'Question'**
  String get materialAddQuestion;

  /// No description provided for @materialPasteImport.
  ///
  /// In en, this message translates to:
  /// **'Paste from text'**
  String get materialPasteImport;

  /// No description provided for @materialPasteTitle.
  ///
  /// In en, this message translates to:
  /// **'Paste your questions'**
  String get materialPasteTitle;

  /// No description provided for @materialPasteHelp.
  ///
  /// In en, this message translates to:
  /// **'# starts an explanation page, a numbered line starts a question, * marks the correct option, - a wrong one, and = makes it a type-the-answer question.'**
  String get materialPasteHelp;

  /// No description provided for @materialPasteAction.
  ///
  /// In en, this message translates to:
  /// **'Read the text'**
  String get materialPasteAction;

  /// No description provided for @materialPasteResult.
  ///
  /// In en, this message translates to:
  /// **'{count} blocks read'**
  String materialPasteResult(int count);

  /// No description provided for @materialQuestionType.
  ///
  /// In en, this message translates to:
  /// **'Question type'**
  String get materialQuestionType;

  /// No description provided for @materialTypeSingle.
  ///
  /// In en, this message translates to:
  /// **'One correct answer'**
  String get materialTypeSingle;

  /// No description provided for @materialTypeTrueFalse.
  ///
  /// In en, this message translates to:
  /// **'True / False'**
  String get materialTypeTrueFalse;

  /// No description provided for @materialTypeFill.
  ///
  /// In en, this message translates to:
  /// **'Type the answer'**
  String get materialTypeFill;

  /// No description provided for @materialTypeMatch.
  ///
  /// In en, this message translates to:
  /// **'Match pairs'**
  String get materialTypeMatch;

  /// No description provided for @materialTypeOrder.
  ///
  /// In en, this message translates to:
  /// **'Put in order'**
  String get materialTypeOrder;

  /// No description provided for @materialQuestionText.
  ///
  /// In en, this message translates to:
  /// **'Question text'**
  String get materialQuestionText;

  /// No description provided for @materialPageText.
  ///
  /// In en, this message translates to:
  /// **'Page text'**
  String get materialPageText;

  /// No description provided for @materialOption.
  ///
  /// In en, this message translates to:
  /// **'Option'**
  String get materialOption;

  /// No description provided for @materialAddOption.
  ///
  /// In en, this message translates to:
  /// **'Add option'**
  String get materialAddOption;

  /// No description provided for @materialMarkCorrect.
  ///
  /// In en, this message translates to:
  /// **'Tap the circle to mark the correct answer'**
  String get materialMarkCorrect;

  /// No description provided for @materialAcceptedAnswers.
  ///
  /// In en, this message translates to:
  /// **'Accepted answers'**
  String get materialAcceptedAnswers;

  /// No description provided for @materialAcceptedHint.
  ///
  /// In en, this message translates to:
  /// **'One per line -- spelling variants all count.'**
  String get materialAcceptedHint;

  /// No description provided for @materialLeftItem.
  ///
  /// In en, this message translates to:
  /// **'Left'**
  String get materialLeftItem;

  /// No description provided for @materialRightItem.
  ///
  /// In en, this message translates to:
  /// **'Right'**
  String get materialRightItem;

  /// No description provided for @materialOrderHint.
  ///
  /// In en, this message translates to:
  /// **'Write the items in the correct order -- the pupil sees them shuffled.'**
  String get materialOrderHint;

  /// No description provided for @materialTrue.
  ///
  /// In en, this message translates to:
  /// **'True'**
  String get materialTrue;

  /// No description provided for @materialFalse.
  ///
  /// In en, this message translates to:
  /// **'False'**
  String get materialFalse;

  /// No description provided for @materialAssign.
  ///
  /// In en, this message translates to:
  /// **'Hand out'**
  String get materialAssign;

  /// No description provided for @materialAssignTitle.
  ///
  /// In en, this message translates to:
  /// **'Hand out to classes'**
  String get materialAssignTitle;

  /// No description provided for @materialPickClasses.
  ///
  /// In en, this message translates to:
  /// **'Which classes'**
  String get materialPickClasses;

  /// No description provided for @materialMode.
  ///
  /// In en, this message translates to:
  /// **'Type of work'**
  String get materialMode;

  /// No description provided for @materialModeControl.
  ///
  /// In en, this message translates to:
  /// **'Control test'**
  String get materialModeControl;

  /// No description provided for @materialModeControlHint.
  ///
  /// In en, this message translates to:
  /// **'Graded. Marks stay hidden until the deadline.'**
  String get materialModeControlHint;

  /// No description provided for @materialModePractice.
  ///
  /// In en, this message translates to:
  /// **'Practice'**
  String get materialModePractice;

  /// No description provided for @materialModePracticeHint.
  ///
  /// In en, this message translates to:
  /// **'No grade. The pupil is told right or wrong at once.'**
  String get materialModePracticeHint;

  /// No description provided for @materialDueAt.
  ///
  /// In en, this message translates to:
  /// **'Deadline'**
  String get materialDueAt;

  /// No description provided for @materialPickDue.
  ///
  /// In en, this message translates to:
  /// **'Choose a deadline'**
  String get materialPickDue;

  /// No description provided for @materialAttempts.
  ///
  /// In en, this message translates to:
  /// **'Attempts'**
  String get materialAttempts;

  /// No description provided for @materialAttemptsUnlimited.
  ///
  /// In en, this message translates to:
  /// **'Unlimited'**
  String get materialAttemptsUnlimited;

  /// No description provided for @materialControlNeedsDue.
  ///
  /// In en, this message translates to:
  /// **'A control test needs a deadline.'**
  String get materialControlNeedsDue;

  /// No description provided for @materialPickAtLeastOne.
  ///
  /// In en, this message translates to:
  /// **'Choose at least one class.'**
  String get materialPickAtLeastOne;

  /// No description provided for @materialResults.
  ///
  /// In en, this message translates to:
  /// **'Results'**
  String get materialResults;

  /// No description provided for @materialSubmittedOf.
  ///
  /// In en, this message translates to:
  /// **'{done} of {total} submitted'**
  String materialSubmittedOf(int done, int total);

  /// No description provided for @materialResultsHidden.
  ///
  /// In en, this message translates to:
  /// **'Marks open when the deadline passes, or once everybody has submitted.'**
  String get materialResultsHidden;

  /// No description provided for @materialNotSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Not submitted'**
  String get materialNotSubmitted;

  /// No description provided for @materialTransfer.
  ///
  /// In en, this message translates to:
  /// **'Send to journal'**
  String get materialTransfer;

  /// No description provided for @materialTransferDone.
  ///
  /// In en, this message translates to:
  /// **'Grades sent to the journal'**
  String get materialTransferDone;

  /// No description provided for @materialTransferred.
  ///
  /// In en, this message translates to:
  /// **'In the journal'**
  String get materialTransferred;

  /// No description provided for @materialDuplicate.
  ///
  /// In en, this message translates to:
  /// **'Make a copy'**
  String get materialDuplicate;

  /// No description provided for @materialLockedEdit.
  ///
  /// In en, this message translates to:
  /// **'This material has been handed out. Make a copy to change the questions.'**
  String get materialLockedEdit;

  /// No description provided for @materialDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this material?'**
  String get materialDeleteTitle;

  /// No description provided for @materialDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'It will disappear from your library and from every class it was handed to.'**
  String get materialDeleteConfirm;

  /// No description provided for @materialNoQuestions.
  ///
  /// In en, this message translates to:
  /// **'no questions'**
  String get materialNoQuestions;

  /// No description provided for @materialQuestionsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} questions'**
  String materialQuestionsCount(int count);

  /// No description provided for @assignmentsTitle.
  ///
  /// In en, this message translates to:
  /// **'Assignments'**
  String get assignmentsTitle;

  /// No description provided for @assignmentsNoneTitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing to do right now'**
  String get assignmentsNoneTitle;

  /// No description provided for @assignmentsNoneMessage.
  ///
  /// In en, this message translates to:
  /// **'Your teachers have not handed out any work yet.'**
  String get assignmentsNoneMessage;

  /// No description provided for @assignmentStart.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get assignmentStart;

  /// No description provided for @assignmentContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get assignmentContinue;

  /// No description provided for @assignmentRetry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get assignmentRetry;

  /// No description provided for @assignmentNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get assignmentNext;

  /// No description provided for @assignmentCheck.
  ///
  /// In en, this message translates to:
  /// **'Check'**
  String get assignmentCheck;

  /// No description provided for @assignmentFinish.
  ///
  /// In en, this message translates to:
  /// **'Finish'**
  String get assignmentFinish;

  /// No description provided for @assignmentCorrect.
  ///
  /// In en, this message translates to:
  /// **'Correct!'**
  String get assignmentCorrect;

  /// No description provided for @assignmentWrong.
  ///
  /// In en, this message translates to:
  /// **'Not quite'**
  String get assignmentWrong;

  /// No description provided for @assignmentOverdue.
  ///
  /// In en, this message translates to:
  /// **'Deadline passed'**
  String get assignmentOverdue;

  /// No description provided for @assignmentDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get assignmentDone;

  /// No description provided for @assignmentDueLabel.
  ///
  /// In en, this message translates to:
  /// **'Due {when}'**
  String assignmentDueLabel(String when);

  /// No description provided for @assignmentAttemptsLeft.
  ///
  /// In en, this message translates to:
  /// **'{count} attempts left'**
  String assignmentAttemptsLeft(int count);

  /// No description provided for @assignmentNoAttemptsLeft.
  ///
  /// In en, this message translates to:
  /// **'No attempts left'**
  String get assignmentNoAttemptsLeft;

  /// No description provided for @assignmentWaitingMark.
  ///
  /// In en, this message translates to:
  /// **'Submitted. Your mark appears after the deadline.'**
  String get assignmentWaitingMark;

  /// No description provided for @assignmentYourScore.
  ///
  /// In en, this message translates to:
  /// **'Your score'**
  String get assignmentYourScore;

  /// No description provided for @assignmentTypeAnswer.
  ///
  /// In en, this message translates to:
  /// **'Type your answer'**
  String get assignmentTypeAnswer;

  /// No description provided for @assignmentTapInOrder.
  ///
  /// In en, this message translates to:
  /// **'Tap the words in the right order'**
  String get assignmentTapInOrder;

  /// No description provided for @assignmentMatchHint.
  ///
  /// In en, this message translates to:
  /// **'Pick one from each side to join them'**
  String get assignmentMatchHint;

  /// No description provided for @assignmentLeave.
  ///
  /// In en, this message translates to:
  /// **'Leave this task?'**
  String get assignmentLeave;

  /// No description provided for @assignmentLeaveMessage.
  ///
  /// In en, this message translates to:
  /// **'Your answers are saved -- you can come back and carry on.'**
  String get assignmentLeaveMessage;

  /// No description provided for @materialScopeMine.
  ///
  /// In en, this message translates to:
  /// **'Mine'**
  String get materialScopeMine;

  /// No description provided for @materialScopeSchool.
  ///
  /// In en, this message translates to:
  /// **'School'**
  String get materialScopeSchool;

  /// No description provided for @materialByTeacher.
  ///
  /// In en, this message translates to:
  /// **'by {name}'**
  String materialByTeacher(String name);

  /// No description provided for @materialReadOnly.
  ///
  /// In en, this message translates to:
  /// **'Someone else wrote this. Make a copy to change it or hand it out.'**
  String get materialReadOnly;

  /// No description provided for @materialSchoolEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nobody else has written anything yet.'**
  String get materialSchoolEmpty;

  /// No description provided for @analysisByQuarter.
  ///
  /// In en, this message translates to:
  /// **'By quarter'**
  String get analysisByQuarter;

  /// No description provided for @analysisByMonth.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get analysisByMonth;

  /// No description provided for @analysisNoMonthly.
  ///
  /// In en, this message translates to:
  /// **'No marks in this month.'**
  String get analysisNoMonthly;

  /// No description provided for @analysisBestDay.
  ///
  /// In en, this message translates to:
  /// **'Best day'**
  String get analysisBestDay;

  /// No description provided for @analysisDaysWithMarks.
  ///
  /// In en, this message translates to:
  /// **'{count} days with marks'**
  String analysisDaysWithMarks(int count);

  /// No description provided for @aiTitle.
  ///
  /// In en, this message translates to:
  /// **'AI assistant'**
  String get aiTitle;

  /// No description provided for @aiSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Draft a lesson or a test, then check it yourself'**
  String get aiSubtitle;

  /// No description provided for @aiStepSource.
  ///
  /// In en, this message translates to:
  /// **'Source'**
  String get aiStepSource;

  /// No description provided for @aiStepSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get aiStepSettings;

  /// No description provided for @aiStepReview.
  ///
  /// In en, this message translates to:
  /// **'Check'**
  String get aiStepReview;

  /// No description provided for @aiSourceTopic.
  ///
  /// In en, this message translates to:
  /// **'Topic'**
  String get aiSourceTopic;

  /// No description provided for @aiSourceTopicHint.
  ///
  /// In en, this message translates to:
  /// **'Write the topic, e.g. \"Pythagoras theorem\"'**
  String get aiSourceTopicHint;

  /// No description provided for @aiSourcePhoto.
  ///
  /// In en, this message translates to:
  /// **'Textbook photo'**
  String get aiSourcePhoto;

  /// No description provided for @aiSourcePhotoHint.
  ///
  /// In en, this message translates to:
  /// **'Photograph a page and the AI will read it'**
  String get aiSourcePhotoHint;

  /// No description provided for @aiSourceText.
  ///
  /// In en, this message translates to:
  /// **'Paste text'**
  String get aiSourceText;

  /// No description provided for @aiSourceTextHint.
  ///
  /// In en, this message translates to:
  /// **'Paste text from a book or a document'**
  String get aiSourceTextHint;

  /// No description provided for @aiPickPhoto.
  ///
  /// In en, this message translates to:
  /// **'Choose a photo'**
  String get aiPickPhoto;

  /// No description provided for @aiPhotoReady.
  ///
  /// In en, this message translates to:
  /// **'Photo attached'**
  String get aiPhotoReady;

  /// No description provided for @aiNeedSource.
  ///
  /// In en, this message translates to:
  /// **'Fill in the source first.'**
  String get aiNeedSource;

  /// No description provided for @aiQuestionCount.
  ///
  /// In en, this message translates to:
  /// **'Questions'**
  String get aiQuestionCount;

  /// No description provided for @aiPageCount.
  ///
  /// In en, this message translates to:
  /// **'Explanation pages'**
  String get aiPageCount;

  /// No description provided for @aiDifficulty.
  ///
  /// In en, this message translates to:
  /// **'Difficulty'**
  String get aiDifficulty;

  /// No description provided for @aiDifficultyEasy.
  ///
  /// In en, this message translates to:
  /// **'Easy'**
  String get aiDifficultyEasy;

  /// No description provided for @aiDifficultyMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get aiDifficultyMedium;

  /// No description provided for @aiDifficultyHard.
  ///
  /// In en, this message translates to:
  /// **'Hard'**
  String get aiDifficultyHard;

  /// No description provided for @aiNeedTypes.
  ///
  /// In en, this message translates to:
  /// **'Choose at least one question type.'**
  String get aiNeedTypes;

  /// No description provided for @aiGenerate.
  ///
  /// In en, this message translates to:
  /// **'Generate'**
  String get aiGenerate;

  /// No description provided for @aiWorking.
  ///
  /// In en, this message translates to:
  /// **'Writing the material…'**
  String get aiWorking;

  /// No description provided for @aiWorkingHint.
  ///
  /// In en, this message translates to:
  /// **'This usually takes 20–30 seconds.'**
  String get aiWorkingHint;

  /// No description provided for @aiReviewWarning.
  ///
  /// In en, this message translates to:
  /// **'AI can be wrong. Read every block and fix what needs fixing before saving.'**
  String get aiReviewWarning;

  /// No description provided for @aiDropped.
  ///
  /// In en, this message translates to:
  /// **'{count} blocks were unusable and removed.'**
  String aiDropped(int count);

  /// No description provided for @aiSaveMaterial.
  ///
  /// In en, this message translates to:
  /// **'Save as material'**
  String get aiSaveMaterial;

  /// No description provided for @aiRegenerate.
  ///
  /// In en, this message translates to:
  /// **'Generate again'**
  String get aiRegenerate;

  /// No description provided for @aiBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get aiBack;

  /// No description provided for @aiNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get aiNext;

  /// No description provided for @passwordChangeTitle.
  ///
  /// In en, this message translates to:
  /// **'Change your password'**
  String get passwordChangeTitle;

  /// No description provided for @passwordChangeWhy.
  ///
  /// In en, this message translates to:
  /// **'This account still uses the password it shipped with. Choose your own before going any further.'**
  String get passwordChangeWhy;

  /// No description provided for @passwordCurrent.
  ///
  /// In en, this message translates to:
  /// **'Current password'**
  String get passwordCurrent;

  /// No description provided for @passwordNew.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get passwordNew;

  /// No description provided for @passwordRepeat.
  ///
  /// In en, this message translates to:
  /// **'Repeat new password'**
  String get passwordRepeat;

  /// No description provided for @passwordTooShort.
  ///
  /// In en, this message translates to:
  /// **'At least 8 characters.'**
  String get passwordTooShort;

  /// No description provided for @passwordMismatch.
  ///
  /// In en, this message translates to:
  /// **'The two passwords do not match.'**
  String get passwordMismatch;

  /// No description provided for @passwordIsDefault.
  ///
  /// In en, this message translates to:
  /// **'Choose a different password from the default one.'**
  String get passwordIsDefault;

  /// No description provided for @passwordChanged.
  ///
  /// In en, this message translates to:
  /// **'Password changed.'**
  String get passwordChanged;

  /// No description provided for @passwordSave.
  ///
  /// In en, this message translates to:
  /// **'Save password'**
  String get passwordSave;

  /// No description provided for @serverAddress.
  ///
  /// In en, this message translates to:
  /// **'Server address'**
  String get serverAddress;

  /// No description provided for @serverAddressHint.
  ///
  /// In en, this message translates to:
  /// **'Leave empty to use the built-in address'**
  String get serverAddressHint;

  /// No description provided for @serverAddressSaved.
  ///
  /// In en, this message translates to:
  /// **'Server address saved. Restart the app.'**
  String get serverAddressSaved;

  /// No description provided for @serverAddressCurrent.
  ///
  /// In en, this message translates to:
  /// **'Now: {url}'**
  String serverAddressCurrent(String url);

  /// Label for the count of students averaging 8 or above
  ///
  /// In en, this message translates to:
  /// **'High achievers'**
  String get ratingHighAchievers;

  /// Section title for the per-subject class breakdown
  ///
  /// In en, this message translates to:
  /// **'Strong and weak subjects'**
  String get subjectStrengths;

  /// How many pupils and grades a subject average covers
  ///
  /// In en, this message translates to:
  /// **'{students} pupils / {grades} grades'**
  String subjectCoverage(int students, int grades);

  /// Shown when the cameras have not yet decided a student is present or absent today
  ///
  /// In en, this message translates to:
  /// **'Not checked yet'**
  String get awaitingDetection;

  /// Title of the profile screen, which replaced Settings in the bottom bar
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profileTitle;

  /// Follows the streak number on the attendance page
  ///
  /// In en, this message translates to:
  /// **'days in a row'**
  String get streakDaysInARow;

  /// The longest run of school days attended in the loaded history
  ///
  /// In en, this message translates to:
  /// **'Best run: {days} days'**
  String streakBest(int days);

  /// Shown instead of the best run when the streak is zero
  ///
  /// In en, this message translates to:
  /// **'Come to school tomorrow and the count starts again'**
  String get streakStartToday;

  /// No description provided for @identifierLabel.
  ///
  /// In en, this message translates to:
  /// **'Phone, email or login'**
  String get identifierLabel;

  /// No description provided for @identifierHint.
  ///
  /// In en, this message translates to:
  /// **'98 764 40 02'**
  String get identifierHint;

  /// No description provided for @codeTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm your number'**
  String get codeTitle;

  /// No description provided for @codeSentTo.
  ///
  /// In en, this message translates to:
  /// **'We sent a code to {phone}'**
  String codeSentTo(String phone);

  /// No description provided for @codeNotDelivered.
  ///
  /// In en, this message translates to:
  /// **'SMS is not set up yet. Ask the school for the code.'**
  String get codeNotDelivered;

  /// No description provided for @codeLabel.
  ///
  /// In en, this message translates to:
  /// **'Code from the SMS'**
  String get codeLabel;

  /// No description provided for @codeResend.
  ///
  /// In en, this message translates to:
  /// **'Send again'**
  String get codeResend;

  /// No description provided for @codeVerify.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get codeVerify;

  /// No description provided for @setupTitle.
  ///
  /// In en, this message translates to:
  /// **'Set your password'**
  String get setupTitle;

  /// No description provided for @setupSubtitle.
  ///
  /// In en, this message translates to:
  /// **'You will sign in with your phone number and this password.'**
  String get setupSubtitle;

  /// No description provided for @setupSave.
  ///
  /// In en, this message translates to:
  /// **'Save and sign in'**
  String get setupSave;

  /// No description provided for @parentNoAccountHint.
  ///
  /// In en, this message translates to:
  /// **'This number is not registered. Ask the school to add it.'**
  String get parentNoAccountHint;

  /// No description provided for @lessonTimeInvalid.
  ///
  /// In en, this message translates to:
  /// **'Use HH:MM, for example 08:30'**
  String get lessonTimeInvalid;

  /// No description provided for @registerTitle.
  ///
  /// In en, this message translates to:
  /// **'Register'**
  String get registerTitle;

  /// No description provided for @registerSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter the number the school has on file. We will send a code to it.'**
  String get registerSubtitle;

  /// No description provided for @registerAction.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account? Register'**
  String get registerAction;

  /// No description provided for @copyAction.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copyAction;

  /// No description provided for @copiedToClipboard.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get copiedToClipboard;

  /// No description provided for @schoolSettings.
  ///
  /// In en, this message translates to:
  /// **'School settings'**
  String get schoolSettings;

  /// No description provided for @liveVideoSetting.
  ///
  /// In en, this message translates to:
  /// **'Live video'**
  String get liveVideoSetting;

  /// No description provided for @liveVideoSettingHint.
  ///
  /// In en, this message translates to:
  /// **'When off, nobody in the school can open a camera'**
  String get liveVideoSettingHint;

  /// No description provided for @liveVideoOffByDirector.
  ///
  /// In en, this message translates to:
  /// **'Live video is turned off by the director'**
  String get liveVideoOffByDirector;

  /// No description provided for @groupModeSetting.
  ///
  /// In en, this message translates to:
  /// **'Group mode'**
  String get groupModeSetting;

  /// No description provided for @groupModeSettingHint.
  ///
  /// In en, this message translates to:
  /// **'For academies: one room, several groups a day. A camera is tied to the room and the schedule decides whose lesson is in front of it'**
  String get groupModeSettingHint;

  /// No description provided for @cameraGroups.
  ///
  /// In en, this message translates to:
  /// **'Groups'**
  String get cameraGroups;

  /// No description provided for @cameraGroupsHint.
  ///
  /// In en, this message translates to:
  /// **'Who is in front of this camera, and when'**
  String get cameraGroupsHint;

  /// No description provided for @addGroupSlot.
  ///
  /// In en, this message translates to:
  /// **'Add group'**
  String get addGroupSlot;

  /// No description provided for @everyDay.
  ///
  /// In en, this message translates to:
  /// **'Every day'**
  String get everyDay;

  /// No description provided for @noGroupSlots.
  ///
  /// In en, this message translates to:
  /// **'No groups yet'**
  String get noGroupSlots;

  /// No description provided for @slotSaved.
  ///
  /// In en, this message translates to:
  /// **'Added'**
  String get slotSaved;

  /// No description provided for @deleteSlot.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get deleteSlot;
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
