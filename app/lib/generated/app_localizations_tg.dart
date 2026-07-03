// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Tajik (`tg`).
class AppLocalizationsTg extends AppLocalizations {
  AppLocalizationsTg([String locale = 'tg']) : super(locale);

  @override
  String get title => 'Мактаби интеллектуалӣ';

  @override
  String get login => 'Ворид шудан';

  @override
  String get signIn => 'Ворид шудан';

  @override
  String get email => 'Почтаи электронӣ';

  @override
  String get password => 'Парол';

  @override
  String get phone => 'Рақами телефон';

  @override
  String get welcome => 'Хуш омадед';

  @override
  String get login_desc => 'Барои ворид шудан маълумоти худро ворид кунед.';

  @override
  String get dashboard => 'Асосӣ';

  @override
  String get live => 'Видео';

  @override
  String get manage => 'Идоракунӣ';

  @override
  String get alerts => 'Огоҳӣ';

  @override
  String get students => 'Талабагон';

  @override
  String get classes => 'Синфҳо';

  @override
  String get classSingle => 'Синф';

  @override
  String get cameras => 'Камераҳо';

  @override
  String get settings => 'Танзимот';

  @override
  String get language => 'Забон';

  @override
  String get logout => 'Баромад';

  @override
  String get invalidPhoneError => 'Лутфан рақами телефони дурустро ворид кунед';

  @override
  String errorPrefix(String error) {
    return 'Хатогӣ: $error';
  }

  @override
  String get needSupport => 'Кӯмак лозим аст? ';

  @override
  String get contact => 'Тамос';

  @override
  String get roleDirector => 'Директор';

  @override
  String get roleParent => 'Волидайн';

  @override
  String get createAccount => 'Эҷоди ҳисоб';

  @override
  String get lastStep => 'Қадами охирин!';

  @override
  String tellUsName(String phone) {
    return 'Лутфан номи худро ворид кунед, то сабти номро барои $phone анҷом диҳед';
  }

  @override
  String get fullName => 'Номи пурра';

  @override
  String get fullNameHint => 'Иван Иванов';

  @override
  String get completeRegistration => 'Анҷоми сабти ном';

  @override
  String get termsAndPrivacy =>
      'Бо идомаи кор, шумо ба Шартҳои истифода ва Сиёсати махфияти мо розӣ мешавед.';

  @override
  String get present => 'Ҳозир';

  @override
  String get late => 'Дермонда';

  @override
  String get absent => 'Ғоиб';

  @override
  String get leftSchool => 'Мактабро тарк кард';

  @override
  String get notDetected => 'Муайян нашудааст';

  @override
  String get quickActions => 'Амалҳои фаврӣ';

  @override
  String get history => 'Таърих';

  @override
  String get liveStream => 'Пахши зинда';

  @override
  String get recentActivity => 'Фаъолияти охирин';

  @override
  String get noAttendanceRecorded => 'Имрӯз то ҳол ҳозирот сабт нашудааст';

  @override
  String cameraLabel(String cameraId) {
    return 'Камера: $cameraId';
  }

  @override
  String get noChildrenLinked => 'Кӯдакони вобасташуда нестанд';

  @override
  String get assignedStudentsWillAppear =>
      'Дар ин ҷо хонандагони вобасташуда пайдо мешаванд.';

  @override
  String get children => 'Кӯдакон';

  @override
  String get attendanceHistory => 'Таърихи ҳозирот';

  @override
  String get liveStatus => 'Статуси ҷорӣ';

  @override
  String get selectClass => 'Синфро интихоб кунед';

  @override
  String get studentPhotoRequired => 'Акси хонанда талаб карда мешавад';

  @override
  String get deleteStudentTitle => 'Ҳазфи хонанда';

  @override
  String get deleteStudentConfirm =>
      'Шумо мутмаин ҳастед, ки ин хонандаро ҳазф кардан мехоҳед?';

  @override
  String get cancel => 'Интихобро рад кардан';

  @override
  String get delete => 'Ҳазф кардан';

  @override
  String get studentManagement => 'Идоракунии хонандагон';

  @override
  String get addNewStudent => 'Иловаи хонандаи нав';

  @override
  String get editStudent => 'Таҳрири хонанда';

  @override
  String get firstName => 'Ном';

  @override
  String get lastName => 'Насаб';

  @override
  String get parentPhoneNumber => 'Рақами телефони волидайн';

  @override
  String get isActive => 'Фаъол аст';

  @override
  String get studentFacePhoto => 'Акси чеҳраи хонанда';

  @override
  String get updatePhotoOptional => 'Навсозии акс (ихтиёрӣ)';

  @override
  String get requiredForFaceRecognition => 'Барои шинохти чеҳра лозим аст';

  @override
  String get addStudent => 'Иловаи хонанда';

  @override
  String get saveChanges => 'Захираи тағйирот';

  @override
  String get studentsList => 'Рӯйхати хонандагон';

  @override
  String get noStudents => 'Хонандагон нестанд';

  @override
  String get studentsAssignedWillAppear =>
      'Дар ин ҷо хонандагони ба синфҳо ва волидайн вобасташуда пайдо мешаванд.';

  @override
  String get deleteClassTitle => 'Ҳазфи синф';

  @override
  String get deleteClassConfirm =>
      'Шумо мутмаин ҳастед, ки ин синфро ҳазф кардан мехоҳед? Ин метавонад ба хонандагон ва камераҳои вобасташуда таъсир расонад.';

  @override
  String get classManagement => 'Идоракунии синфҳо';

  @override
  String get createNewClass => 'Эҷоди синфи нав';

  @override
  String get editClass => 'Таҳрири синф';

  @override
  String get classNameLabel => 'Номи синф';

  @override
  String get classNameHint => 'масалан, 9А, 10Б';

  @override
  String get gradeOptional => 'Синф (ихтиёрӣ)';

  @override
  String get gradeHint =>
      'Агар холӣ бошад, ба таври худкор муайян карда мешавад';

  @override
  String get createClass => 'Эҷоди синф';

  @override
  String get existingClasses => 'Синфҳои мавҷуда';

  @override
  String get noClasses => 'Синфҳо нестанд';

  @override
  String get createClassesMessage => 'Барои назорати ҳозирот синфҳо созед.';

  @override
  String gradeLabel(String grade) {
    return 'Синфи $grade';
  }

  @override
  String get deleteCameraTitle => 'Ҳазфи камера';

  @override
  String get deleteCameraConfirm =>
      'Шумо мутмаин ҳастед, ки ин камераро ҳазф кардан мехоҳед?';

  @override
  String get cameraManagement => 'Идоракунии камераҳо';

  @override
  String get addNewCamera => 'Иловаи камераи нав';

  @override
  String get editCamera => 'Таҳрири камера';

  @override
  String get cameraNameLabel => 'Номи камера';

  @override
  String get assignToClass => 'Вобаста кардан ба синф';

  @override
  String get rtspUrl => 'RTSP URL';

  @override
  String get startTime => 'Вақти оғоз';

  @override
  String get endTime => 'Вақти анҷом';

  @override
  String get detectSec => 'Детексия (сония)';

  @override
  String get waitMin => 'Интизорӣ (дақиқа)';

  @override
  String get addCamera => 'Иловаи камера';

  @override
  String get registeredCameras => 'Камераҳои сабтшуда';

  @override
  String get noCameras => 'Камераҳо нестанд';

  @override
  String get classroomCamerasWillAppear =>
      'Дар ин ҷо камераҳои синфхонаҳо пайдо мешаванд.';

  @override
  String cameraListSubtitle(String className, String waitDuration) {
    return 'Синф: $className • Интизорӣ: $waitDurationд';
  }

  @override
  String get unassigned => 'Вобаста نشدهаст';

  @override
  String get noAttendanceRecords => 'Сабтҳои ҳозирот мавҷуд нест';

  @override
  String get recordsWillAppear =>
      'Сабтҳо пас аз оғози шинохти чеҳра пайдо мешаванд.';

  @override
  String inTimeOutTime(String inTime, String outTime) {
    return 'Даромад $inTime  Баромад $outTime';
  }

  @override
  String get noLiveData => 'Маълумоти ҷорӣ мавҷуд нест';

  @override
  String get realtimeAttendanceMessage =>
      'Ҳозироти ҷорӣ ҳангоми детексия пайдо мешавад.';

  @override
  String lastSeenTime(String time) {
    return 'Бори охир дида шуд дар $time';
  }

  @override
  String get directorNotifications => 'Огоҳиҳои директор';

  @override
  String get schoolWideNotificationView =>
      'Намоиши огоҳиҳои умумимактабиро метавон дертар фаъол кард.';

  @override
  String get noNotifications => 'Огоҳиҳо нестанд';

  @override
  String get attendanceAlertsWillAppear =>
      'Огоҳиҳои ҳозирот дар ин ҷо пайдо мешаванд.';

  @override
  String get studentNotFound => 'Хонанда ёфт нашуд';

  @override
  String classLabel(String classId) {
    return 'Синфи $classId';
  }

  @override
  String parentLabel(String parentId) {
    return 'Волидайн $parentId';
  }

  @override
  String get viewAttendanceHistoryButton => 'Таърихи ҳозиротро дидан';

  @override
  String get viewLiveStatusButton => 'Статуси ҷориро дидан';

  @override
  String get signOutTooltip => 'Баромад аз система';

  @override
  String classTileLabel(String className) {
    return 'Синф: $className';
  }

  @override
  String get directorDashboard => 'Панели директор';

  @override
  String get parentDashboard => 'Панели волидайн';

  @override
  String get notifications => 'Огоҳиҳо';
}
