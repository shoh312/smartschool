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
