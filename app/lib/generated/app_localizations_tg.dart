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
  String get appearance => 'Намуди зоҳирӣ';

  @override
  String get themeLight => 'Равшан';

  @override
  String get themeDark => 'Торик';

  @override
  String get themeSystem => 'Мувофиқи система';

  @override
  String get logout => 'Баромад';

  @override
  String get invalidPhoneError => 'Лутфан рақами телефони дурустро ворид кунед';

  @override
  String errorPrefix(String error) {
    return 'Хатогӣ: $error';
  }

  @override
  String get networkErrorMessage =>
      'Пайваст ба сервер имконнопазир шуд. Пайвасти интернет ё фаъол буданти серверро санҷед.';

  @override
  String get serverErrorMessage =>
      'Сервер хатогӣ баргардонд. Лутфан дубора кӯшиш кунед.';

  @override
  String get unknownErrorMessage =>
      'Хатогие рӯй дод. Лутфан дубора кӯшиш кунед.';

  @override
  String get phoneNotRegisteredMessage =>
      'Ин рақами телефон ҳанӯз дар ҳеч мактабе сабти ном нашудааст. Лутфан ба мактаби фарзандатон муроҷиат кунед.';

  @override
  String get invalidCredentialsMessage =>
      'Почтаи электронӣ ё парол нодуруст аст.';

  @override
  String get accountInactiveMessage =>
      'Ҳисоби шумо фаъол нест. Лутфан ба администратор муроҷиат кунед.';

  @override
  String get invalidCurrentPasswordMessage => 'Пароли ҷорӣ нодуруст аст.';

  @override
  String get needSupport => 'Кӯмак лозим аст? ';

  @override
  String get contact => 'Тамос';

  @override
  String get roleDirector => 'Директор';

  @override
  String get roleParent => 'Волидайн';

  @override
  String get roleTeacher => 'Муаллим';

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
  String get attendanceByClass => 'Ҳозирӣ аз рӯи синфҳо';

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
  String get unassigned => 'Вобаста нашудааст';

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
  String classAttendanceRatio(String className, int arrived, int total) {
    return '$className • $arrived/$total омаданд';
  }

  @override
  String get directorDashboard => 'Панели директор';

  @override
  String get parentDashboard => 'Панели волидайн';

  @override
  String get notifications => 'Огоҳиҳо';

  @override
  String get grades => 'Баҳоҳо';

  @override
  String get noGrades => 'Ҳанӯз баҳо нест';

  @override
  String get noGradesMessage =>
      'Баҳоҳо пас аз гузоштани муаллим дар ин ҷо пайдо мешаванд.';

  @override
  String studentFallbackLabel(String id) {
    return 'Хонанда #$id';
  }

  @override
  String get teacherMyClasses => 'Синфҳои ман';

  @override
  String get teacherNoClassesTitle =>
      'Ба шумо ҳанӯз ягон синф вобаста карда нашудааст';

  @override
  String get teacherNoClassesMessage =>
      'Ин пас аз он ки директор ба шумо синф вобаста кунад, пайдо мешавад.';

  @override
  String classFallbackLabel(String classId) {
    return 'Синфи #$classId';
  }

  @override
  String get journalStudentColumn => 'Хонанда';

  @override
  String get journalScoreLabel => 'Баҳо';

  @override
  String get journalCommentOptional => 'Шарҳ (ихтиёрӣ)';

  @override
  String get journalTeacherLabel => 'Муаллим';

  @override
  String get journalNoComment => 'Бе шарҳ';

  @override
  String get close => 'Пӯшидан';

  @override
  String get save => 'Захира кардан';

  @override
  String get journalNoStudentsTitle => 'Дар ин синф хонанда ёфт нашуд';

  @override
  String get journalNoStudentsMessage =>
      'Ин пас аз он ки директор хонандагонро ба ин синф вобаста кунад, пайдо мешавад.';

  @override
  String get teachers => 'Муаллимон';

  @override
  String get addNewTeacher => 'Муаллими нав';

  @override
  String get create => 'Эҷод кардан';

  @override
  String get existingTeachers => 'Муаллимони мавҷуда';

  @override
  String get noTeachers => 'Ҳанӯз муаллим нест';

  @override
  String get noTeachersMessage =>
      'Бо истифода аз шакли боло муаллими нав илова кунед.';

  @override
  String assignClassToTeacher(String name) {
    return 'Ба $name синф вобаста кардан';
  }

  @override
  String get assignClassNoClasses => 'Аввал синф эҷод кунед.';

  @override
  String get noClassesAssignedYet =>
      'То ҳол ба ягон синф вобаста карда нашудааст';

  @override
  String get removeAssignment => 'Хориҷ кардан';

  @override
  String get addSubjectTitle => 'Фан илова кардан';

  @override
  String get noTeachersForSubject => 'Барои ин фан ҳанӯз муаллим нест';

  @override
  String get noSubjectsInClass => 'Дар ин синф ҳанӯз фан илова нашудааст';

  @override
  String get addSubjectToStart =>
      'Барои вобаста кардани муаллим \"Фан илова кардан\"-ро пахш кунед.';

  @override
  String get subjectsLabel => 'Фанҳо';

  @override
  String get subjectsAndTeachers => 'Фанҳо ва муаллимон';

  @override
  String get viewJournal => 'Кушодани журнал';

  @override
  String get removeAssignmentConfirm =>
      'Ин муаллимро аз ин фан дар синф хориҷ кунем? Бахои аллакай гузошташуда мемонанд.';

  @override
  String get subjectLabel => 'Фан';

  @override
  String get assign => 'Вобаста кардан';

  @override
  String get classAssigned => 'Синф вобаста карда шуд';

  @override
  String get month1 => 'Январ';

  @override
  String get month2 => 'Феврал';

  @override
  String get month3 => 'Март';

  @override
  String get month4 => 'Апрел';

  @override
  String get month5 => 'Май';

  @override
  String get month6 => 'Июн';

  @override
  String get month7 => 'Июл';

  @override
  String get month8 => 'Август';

  @override
  String get month9 => 'Сентябр';

  @override
  String get month10 => 'Октябр';

  @override
  String get month11 => 'Ноябр';

  @override
  String get month12 => 'Декабр';

  @override
  String get deleteTeacherTitle => 'Ҳазфи муаллим';

  @override
  String get deleteTeacherConfirm =>
      'Шумо мутмаин ҳастед, ки ин муаллимро ҳазф кардан мехоҳед? Вобастагиҳои синф ва баҳоҳои гузоштаи ӯ низ ҳазф мешаванд.';

  @override
  String get average => 'Миёна';

  @override
  String get weekday1 => 'Дш';

  @override
  String get weekday2 => 'Сш';

  @override
  String get weekday3 => 'Чш';

  @override
  String get weekday4 => 'Пш';

  @override
  String get weekday5 => 'Ҷм';

  @override
  String get weekday6 => 'Шб';

  @override
  String get weekday7 => 'Як';

  @override
  String get attendanceJournal => 'Журнали ҳозирот';

  @override
  String get lastSeenLabel => 'Дафъаи охир дида шуд';

  @override
  String get noAttendanceThisMonth => 'Дар ин моҳ ягон қайди ҳозирӣ нест';

  @override
  String get noCameraForClassTitle => 'Барои ин синф камера нест';

  @override
  String get noCameraForClassMessage =>
      'Дар \"Идоракунии камераҳо\" ба ин синф камера вобаста кунед, то ҳолати зиндаи онро бинед.';

  @override
  String get studentNotAssignedToClass =>
      'Ин талаба ҳанӯз ба синф вобаста карда нашудааст';

  @override
  String get cameraNotAvailable =>
      'Дар ин дастгоҳ гирифтани сурат бо камера дастрас нест. \"Галерея\"-ро истифода баред.';

  @override
  String get rooms => 'Синфхонаҳо';

  @override
  String get roomManagement => 'Идоракунии синфхонаҳо';

  @override
  String get addNewRoom => 'Синфхонаи нав';

  @override
  String get editRoom => 'Таҳрири синфхона';

  @override
  String get roomNameLabel => 'Номи синфхона';

  @override
  String get assignToRoom => 'Вобаста кардан ба синфхона';

  @override
  String get positions => 'Сменаҳо';

  @override
  String get addPosition => 'Илова кардани смена';

  @override
  String get positionClassLabel => 'Синф';

  @override
  String get registeredRooms => 'Синфхонаҳои мавҷуда';

  @override
  String get noRooms => 'Ҳанӯз синфхона нест';

  @override
  String get roomsWillAppear => 'Синфхонаҳо дар ин ҷо пайдо мешаванд.';

  @override
  String get deleteRoomTitle => 'Ҳазфи синфхона';

  @override
  String get deleteRoomConfirm =>
      'Шумо мутмаин ҳастед, ки ин синфхонаро ҳазф кардан мехоҳед?';

  @override
  String get roomHasCamerasError =>
      'Аввал камераҳои ин синфхонаро ба ҷои дигар гузаронед ё ҳазф кунед.';

  @override
  String cameraListSubtitleRoom(String roomName, String waitDuration) {
    return 'Синфхона: $roomName • Танаффус: $waitDurationд';
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
    return '$className - Таҳлил';
  }

  @override
  String get noDataTitle => 'Маълумот нест';

  @override
  String get noAttendanceDataLast30Days =>
      'Барои 30 рӯзи охир маълумоти ҳозирот мавҷуд нест';

  @override
  String get perStudentDetails => 'Маълумот аз рӯи ҳар як хонанда';

  @override
  String get hoursLabel => 'Соатҳо';

  @override
  String get thirtyDayTimeline => 'Хронологияи 30 рӯз';

  @override
  String get noTimetableSubjectsTitle => 'Дар ҷадвал фан нест';

  @override
  String get noTimetableSubjectsMessage =>
      'Аввал ба ҷадвали ин синф дарсҳо илова кунед.';

  @override
  String get tapToAssignTeacher => 'Барои таъини муаллим пахш кунед';

  @override
  String get timetableLabel => 'Ҷадвал';

  @override
  String totalHoursPerWeek(String hours) {
    return 'Ҳамагӣ: $hours соат/ҳафта';
  }

  @override
  String get noLessonsForDay => 'Барои ин рӯз дарс нест';

  @override
  String get addLesson => 'Илова кардани дарс';

  @override
  String get minutesUnit => 'дақ';

  @override
  String get cameraOptionTooltip => 'Камера';

  @override
  String get galleryOptionTooltip => 'Галерея';

  @override
  String get noFrame => 'Кадр нест';

  @override
  String get selectMonth => 'Моҳро интихоб кунед';

  @override
  String get generatePdfReport => 'Сохтани ҳисоботи PDF';

  @override
  String get pdfReportEyebrow => 'ҲИСОБОТИ ҲОЗИРӢ';

  @override
  String get pdfNoDataForMonth =>
      'Барои моҳи интихобшуда маълумоти ҳозирӣ нест';

  @override
  String get columnPresentDays => 'Рӯзҳои ҳозирӣ';

  @override
  String get columnLateDays => 'Рӯзҳои дер';

  @override
  String get columnAbsentDays => 'Рӯзҳои ғоиб';

  @override
  String get columnPresentHours => 'Соатҳои ҳозирӣ';

  @override
  String get columnAbsentHours => 'Соатҳои ғоиб';

  @override
  String get columnRate => 'Фоиз';
}
