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
  String get usernameTakenMessage =>
      'Ин воридшавӣ аллакай банд аст. Дигареро интихоб кунед.';

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
  String get roleStudent => 'Хонанда';

  @override
  String get studentUsernameLabel => 'Логин';

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

  @override
  String get ratingAnalytics => 'Рейтинг';

  @override
  String get overallAverage => 'Баҳои миёна';

  @override
  String get classRank => 'Синф';

  @override
  String get parallelRank => 'Параллел';

  @override
  String get schoolRank => 'Мактаб';

  @override
  String get classRanking => 'Рейтинги синф';

  @override
  String get parallelRanking => 'Рейтинги параллел';

  @override
  String get schoolRanking => 'Рейтинги мактаб';

  @override
  String get strongestSubject => 'Фанни пешрафта';

  @override
  String get weakestSubject => 'Фанни бо диққат';

  @override
  String get subjectBreakdown => 'Фанҳо';

  @override
  String get lessonAttendanceRate => 'Ҳозирии дарсҳо';

  @override
  String get quarter1 => 'Чораки I';

  @override
  String get quarter2 => 'Чораки II';

  @override
  String get quarter3 => 'Чораки III';

  @override
  String get quarter4 => 'Чораки IV';

  @override
  String get noGradesYetMessage => 'Барои ин давра ҳанӯз бахо нест';

  @override
  String get achievementFirstPlace => 'Ҷои 1';

  @override
  String get achievementTopThree => '3-и беҳтарин';

  @override
  String get achievementTopTenPercent => '10%-и беҳтарин';

  @override
  String get exportPdf => 'Содироти PDF';

  @override
  String get classAverage => 'Миёнаи синф';

  @override
  String get parallelAverage => 'Миёнаи параллел';

  @override
  String get schoolAverage => 'Миёнаи мактаб';

  @override
  String get needsAttention => 'Диққат талаб мекунанд';

  @override
  String get biggestDecline => 'Пастравии калонтарин';

  @override
  String get lowestAverage => 'Баҳои пасттарин';

  @override
  String get trendVsPreviousQuarter => 'нисбат ба чораки гузашта';

  @override
  String get pdfRatingEyebrow => 'ҲИСОБОТИ РЕЙТИНГ';

  @override
  String get gradeCountSuffix => 'баҳо';

  @override
  String get rankingScopeAll => 'Ҳама';

  @override
  String get rankingScopeClasses => 'Синфҳо';

  @override
  String get rankingScopeParallel => 'Параллел';

  @override
  String get selectClassPrompt => 'Синфро интихоб кунед';

  @override
  String get selectParallelPrompt => 'Параллелро интихоб кунед';

  @override
  String get topThree => '3-и беҳтарин';

  @override
  String lessonSchedule(String className) {
    return 'Ҷадвал — $className';
  }

  @override
  String get editLesson => 'Дарсро таҳрир кардан';

  @override
  String get deleteLessonTitle => 'Дарсро нест кардан';

  @override
  String get deleteLessonConfirm =>
      'Ин дарс нест карда шавад? Баргардонидан мумкин нест.';

  @override
  String get roomLabel => 'Хона';

  @override
  String get ruznoma => 'Рӯзнома';

  @override
  String get todayLessons => 'Имрӯз';

  @override
  String get tomorrowLessons => 'Пагоҳ';

  @override
  String get homeworkLabel => 'Вазифаи хонагӣ';

  @override
  String get teacherNoteLabel => 'Қайди муаллим';

  @override
  String get addHomeworkPrompt => 'Вазифа ё қайд илова кунед';

  @override
  String get noLessonsToday => 'Барои ин рӯз дарс нест';

  @override
  String get schoolCalendar => 'Тақвими мактаб';

  @override
  String get eventTypeHoliday => 'Иди/Таътил';

  @override
  String get eventTypeExam => 'Имтиҳон';

  @override
  String get eventTypeTest => 'Кори назоратӣ';

  @override
  String get eventTypeEvent => 'Тадбир';

  @override
  String get addEvent => 'Тадбир илова кунед';

  @override
  String get eventTitleLabel => 'Сарлавҳа';

  @override
  String get eventDescriptionLabel => 'Тавсиф (ихтиёрӣ)';

  @override
  String get noUpcomingEvents => 'Тадбири наздик нест';

  @override
  String get deleteEventTitle => 'Тадбирро нест кардан';

  @override
  String get deleteEventConfirm => 'Ин тадбир нест карда шавад?';

  @override
  String get announcements => 'Эълонҳо';

  @override
  String get postAnnouncement => 'Эълон гузоштан';

  @override
  String get announcementTitleLabel => 'Сарлавҳа';

  @override
  String get announcementBodyLabel => 'Матн';

  @override
  String get noAnnouncementsYet => 'Ҳанӯз эълон нест';

  @override
  String get deleteAnnouncementTitle => 'Эълонро нест кардан';

  @override
  String get deleteAnnouncementConfirm => 'Ин эълон нест карда шавад?';

  @override
  String get pickDatePrompt => 'Санаро интихоб кунед';

  @override
  String get lessonWord => 'дарс';

  @override
  String get lessonsCountSuffix => 'дарс';

  @override
  String untilTime(String time) {
    return 'то соати $time';
  }

  @override
  String get teacherWord => 'Муаллим';

  @override
  String lessonOrdinal(int number) {
    return 'Дарси $number';
  }

  @override
  String get retry => 'Такрор кунед';

  @override
  String get logoutConfirmMessage => 'Шумо мутмаин ҳастед, ки мехоҳед бароед?';

  @override
  String get homeworkListTitle => 'Вазифаи хонагӣ';

  @override
  String get noHomeworkMessage => 'Ҳанӯз вазифаи хонагӣ дода нашудааст';

  @override
  String get achievementsTitle => 'Ютуқҳо';

  @override
  String get achievementSchoolFirst => '1-ин дар мактаб';

  @override
  String get achievementTopThreeBadge => '3-и беҳтарин';

  @override
  String get achievementExcellent => 'Хонандаи аълочӣ';

  @override
  String get achievementPerfectAttendance => 'Ҳозирии намунавӣ';

  @override
  String get achievementBigImprovement => 'Беҳтарин пешравӣ';

  @override
  String achievementSubjectMaster(String subject) {
    return 'Устои фанни $subject';
  }

  @override
  String get noAchievementsTitle => 'Ҳанӯз ютуқ нест';

  @override
  String get noAchievementsMessage =>
      'Хондан идома диҳед -- аввалин нишони шумо наздик аст';

  @override
  String get studentHomeTitle => 'Саҳифаи ман';

  @override
  String get studentLoginLabel => 'Логин барои воридшавӣ';

  @override
  String get studentPasswordLabel => 'Парол';

  @override
  String get studentLoginHelperText =>
      'Ихтиёрӣ -- танҳо агар хонанда худаш ворид шавад лозим аст';

  @override
  String get journalScanTitle => 'Сканкунии рӯзнома';

  @override
  String get journalScanPrompt =>
      'Аз саҳифаи рӯзнома сурат гиред ё аз галерея интихоб кунед. Баҳоҳои сутуни имрӯза худкор муайян карда мешаванд.';

  @override
  String get journalScanTakePhoto => 'Сурат гирифтан';

  @override
  String get journalScanPickGallery => 'Аз галерея интихоб кардан';

  @override
  String get journalScanEmptyTitle => 'Ҳеҷ чиз ёфт нашуд';

  @override
  String get journalScanEmptyMessage =>
      'Дар сутуни имрӯзаи ин сурат баҳо ёфт нашуд. Суратро равшантар ва ростатар гиред.';

  @override
  String get journalScanConfirmAll => 'Тасдиқ ва захира';

  @override
  String journalScanSavedCount(int saved, int total) {
    return '$saved аз $total баҳо захира шуд';
  }

  @override
  String journalScanNoMatch(String name) {
    return 'Барои \"$name\" мувофиқат ёфт нашуд -- гузашта шуд';
  }

  @override
  String journalScanRawName(String name) {
    return 'Хонда шуд: $name';
  }

  @override
  String get journalScanAbsent => 'Ҳозир набуд';

  @override
  String get attendanceToday => 'Ҳозирии имрӯза';

  @override
  String get sectionLearning => 'Таълим';

  @override
  String get sectionSchool => 'Мактаб';

  @override
  String arrivedOfTotal(int arrived, int total) {
    return '$arrived аз $total омад';
  }

  @override
  String get materialsTitle => 'Маводҳо';

  @override
  String get materialsSubtitle => 'Дарсу тестҳо барои синфҳои шумо';

  @override
  String get materialLibrary => 'Китобхонаи ман';

  @override
  String get materialHandedOut => 'Додашуда';

  @override
  String get materialNew => 'Маводи нав';

  @override
  String get materialTitleLabel => 'Ном';

  @override
  String get materialDescriptionLabel => 'Тавсифи кӯтоҳ';

  @override
  String get materialEmptyTitle => 'Ҳанӯз мавод нест';

  @override
  String get materialEmptyMessage => 'Дарс ё тест созед ва ба синф диҳед.';

  @override
  String get materialContentEmpty => 'Ақаллан як саҳифа ё савол илова кунед.';

  @override
  String get materialPage => 'Саҳифа';

  @override
  String get materialQuestion => 'Савол';

  @override
  String get materialAddPage => 'Саҳифа';

  @override
  String get materialAddQuestion => 'Савол';

  @override
  String get materialPasteImport => 'Аз матн гузоштан';

  @override
  String get materialPasteTitle => 'Саволҳои худро гузоред';

  @override
  String get materialPasteHelp =>
      '# саҳифаи шарҳро оғоз мекунад, сатри рақамдор — савол, * ҷавоби дурустро нишон медиҳад, - нодурустро, ва = саволи ҷавобнависро месозад.';

  @override
  String get materialPasteAction => 'Матнро хондан';

  @override
  String materialPasteResult(int count) {
    return '$count блок хонда шуд';
  }

  @override
  String get materialQuestionType => 'Навъи савол';

  @override
  String get materialTypeSingle => 'Як ҷавоби дуруст';

  @override
  String get materialTypeTrueFalse => 'Дуруст / Нодуруст';

  @override
  String get materialTypeFill => 'Ҷавобро нависед';

  @override
  String get materialTypeMatch => 'Ҷуфтҳоро пайваст кунед';

  @override
  String get materialTypeOrder => 'Ба тартиб гузоред';

  @override
  String get materialQuestionText => 'Матни савол';

  @override
  String get materialPageText => 'Матни саҳифа';

  @override
  String get materialOption => 'Вариант';

  @override
  String get materialAddOption => 'Илова кардани вариант';

  @override
  String get materialMarkCorrect =>
      'Барои нишон додани ҷавоби дуруст доирачаро пахш кунед';

  @override
  String get materialAcceptedAnswers => 'Ҷавобҳои қабулшаванда';

  @override
  String get materialAcceptedHint =>
      'Дар ҳар сатр як — ҳама шаклҳои навишт қабул мешаванд.';

  @override
  String get materialLeftItem => 'Чап';

  @override
  String get materialRightItem => 'Рост';

  @override
  String get materialOrderHint =>
      'Ҷузъҳоро ба тартиби дуруст нависед — хонанда онҳоро омехта мебинад.';

  @override
  String get materialTrue => 'Дуруст';

  @override
  String get materialFalse => 'Нодуруст';

  @override
  String get materialAssign => 'Додан';

  @override
  String get materialAssignTitle => 'Ба синфҳо додан';

  @override
  String get materialPickClasses => 'Ба кадом синфҳо';

  @override
  String get materialMode => 'Навъи кор';

  @override
  String get materialModeControl => 'Кори назоратӣ';

  @override
  String get materialModeControlHint =>
      'Бо баҳо. Холҳо то мӯҳлат пинҳон мемонанд.';

  @override
  String get materialModePractice => 'Машқ';

  @override
  String get materialModePracticeHint =>
      'Бе баҳо. Хонанда фавран дуруст ё нодурустро мебинад.';

  @override
  String get materialDueAt => 'Мӯҳлат';

  @override
  String get materialPickDue => 'Мӯҳлатро интихоб кунед';

  @override
  String get materialAttempts => 'Кӯшишҳо';

  @override
  String get materialAttemptsUnlimited => 'Бе маҳдудият';

  @override
  String get materialControlNeedsDue => 'Кори назоратӣ мӯҳлат талаб мекунад.';

  @override
  String get materialPickAtLeastOne => 'Ақаллан як синф интихоб кунед.';

  @override
  String get materialResults => 'Натиҷаҳо';

  @override
  String materialSubmittedOf(int done, int total) {
    return '$done аз $total супоридаанд';
  }

  @override
  String get materialResultsHidden =>
      'Холҳо пас аз мӯҳлат ё вақте ки ҳама супоранд, кушода мешаванд.';

  @override
  String get materialNotSubmitted => 'Насупоридааст';

  @override
  String get materialTransfer => 'Ба журнал гузарондан';

  @override
  String get materialTransferDone => 'Баҳоҳо ба журнал гузаронида шуданд';

  @override
  String get materialTransferred => 'Дар журнал';

  @override
  String get materialDuplicate => 'Нусха гирифтан';

  @override
  String get materialLockedEdit =>
      'Ин мавод аллакай дода шудааст. Барои тағйири саволҳо нусха гиред.';

  @override
  String get materialDeleteTitle => 'Ин маводро нест кунем?';

  @override
  String get materialDeleteConfirm =>
      'Он аз китобхона ва аз ҳама синфҳое, ки гирифта буданд, нест мешавад.';

  @override
  String get materialNoQuestions => 'савол нест';

  @override
  String materialQuestionsCount(int count) {
    return '$count савол';
  }

  @override
  String get assignmentsTitle => 'Супоришҳо';

  @override
  String get assignmentsNoneTitle => 'Ҳозир коре нест';

  @override
  String get assignmentsNoneMessage => 'Муаллимон ҳанӯз супориш надодаанд.';

  @override
  String get assignmentStart => 'Оғоз';

  @override
  String get assignmentContinue => 'Давом додан';

  @override
  String get assignmentRetry => 'Боз кӯшиш кунед';

  @override
  String get assignmentNext => 'Оянда';

  @override
  String get assignmentCheck => 'Санҷидан';

  @override
  String get assignmentFinish => 'Анҷом';

  @override
  String get assignmentCorrect => 'Дуруст!';

  @override
  String get assignmentWrong => 'На он қадар дуруст';

  @override
  String get assignmentOverdue => 'Мӯҳлат гузашт';

  @override
  String get assignmentDone => 'Супорида шуд';

  @override
  String assignmentDueLabel(String when) {
    return 'То $when';
  }

  @override
  String assignmentAttemptsLeft(int count) {
    return '$count кӯшиш мондааст';
  }

  @override
  String get assignmentNoAttemptsLeft => 'Кӯшиш намондааст';

  @override
  String get assignmentWaitingMark =>
      'Супорида шуд. Холи шумо пас аз мӯҳлат пайдо мешавад.';

  @override
  String get assignmentYourScore => 'Натиҷаи шумо';

  @override
  String get assignmentTypeAnswer => 'Ҷавобатонро нависед';

  @override
  String get assignmentTapInOrder => 'Калимаҳоро ба тартиб пахш кунед';

  @override
  String get assignmentMatchHint => 'Аз ҳар тараф якто интихоб кунед';

  @override
  String get assignmentLeave => 'Аз супориш бароем?';

  @override
  String get assignmentLeaveMessage =>
      'Ҷавобҳо нигоҳ дошта шуданд — метавонед баргардед ва идома диҳед.';

  @override
  String get materialScopeMine => 'Меники';

  @override
  String get materialScopeSchool => 'Мактаб';

  @override
  String materialByTeacher(String name) {
    return 'муаллиф: $name';
  }

  @override
  String get materialReadOnly =>
      'Ин маводи каси дигар аст. Барои тағйир ё додан нусха гиред.';

  @override
  String get materialSchoolEmpty => 'Дигарон ҳанӯз чизе нанавиштаанд.';

  @override
  String get analysisByQuarter => 'Аз рӯи чоракҳо';

  @override
  String get analysisByMonth => 'Моҳона';

  @override
  String get analysisNoMonthly => 'Дар ин моҳ баҳо нест.';

  @override
  String get analysisBestDay => 'Беҳтарин рӯз';

  @override
  String analysisDaysWithMarks(int count) {
    return '$count рӯз бо баҳо';
  }

  @override
  String get aiTitle => 'Ёрдамчии AI';

  @override
  String get aiSubtitle => 'Дарс ё тест месозад, шумо худатон месанҷед';

  @override
  String get aiStepSource => 'Манбаъ';

  @override
  String get aiStepSettings => 'Танзимот';

  @override
  String get aiStepReview => 'Санҷиш';

  @override
  String get aiSourceTopic => 'Мавзӯъ';

  @override
  String get aiSourceTopicHint =>
      'Мавзӯъро нависед, масалан «Теоремаи Пифагор»';

  @override
  String get aiSourcePhoto => 'Сурати китоб';

  @override
  String get aiSourcePhotoHint => 'Саҳифаро сурат гиред, AI онро мехонад';

  @override
  String get aiSourceText => 'Матн гузоштан';

  @override
  String get aiSourceTextHint => 'Матнро аз китоб ё ҳуҷҷат гузоред';

  @override
  String get aiPickPhoto => 'Сурат интихоб кунед';

  @override
  String get aiPhotoReady => 'Сурат замима шуд';

  @override
  String get aiNeedSource => 'Аввал манбаъро пур кунед.';

  @override
  String get aiQuestionCount => 'Саволҳо';

  @override
  String get aiPageCount => 'Саҳифаҳои шарҳ';

  @override
  String get aiDifficulty => 'Мураккабӣ';

  @override
  String get aiDifficultyEasy => 'Осон';

  @override
  String get aiDifficultyMedium => 'Миёна';

  @override
  String get aiDifficultyHard => 'Душвор';

  @override
  String get aiNeedTypes => 'Ақаллан як навъи саволро интихоб кунед.';

  @override
  String get aiGenerate => 'Сохтан';

  @override
  String get aiWorking => 'Мавод навишта истодаам…';

  @override
  String get aiWorkingHint => 'Одатан 20–30 сония вақт мегирад.';

  @override
  String get aiReviewWarning =>
      'AI метавонад хато кунад. Пеш аз нигоҳ доштан ҳар блокро хонед ва ислоҳ кунед.';

  @override
  String aiDropped(int count) {
    return '$count блоки нодуруст нест карда шуд.';
  }

  @override
  String get aiSaveMaterial => 'Ҳамчун мавод нигоҳ доштан';

  @override
  String get aiRegenerate => 'Аз нав сохтан';

  @override
  String get aiBack => 'Бозгашт';

  @override
  String get aiNext => 'Оянда';

  @override
  String get passwordChangeTitle => 'Паролро иваз кунед';

  @override
  String get passwordChangeWhy =>
      'Ин ҳисоб то ҳол пароли пешфарзро истифода мебарад. Пеш аз идома пароли худро интихоб кунед.';

  @override
  String get passwordCurrent => 'Пароли ҳозира';

  @override
  String get passwordNew => 'Пароли нав';

  @override
  String get passwordRepeat => 'Пароли навро такрор кунед';

  @override
  String get passwordTooShort => 'Ақаллан 8 аломат.';

  @override
  String get passwordMismatch => 'Паролҳо мувофиқат намекунанд.';

  @override
  String get passwordIsDefault => 'Пароли дигар аз пешфарз интихоб кунед.';

  @override
  String get passwordChanged => 'Парол иваз шуд.';

  @override
  String get passwordSave => 'Паролро нигоҳ доштан';

  @override
  String get serverAddress => 'Суроғаи сервер';

  @override
  String get serverAddressHint => 'Барои суроғаи дарунсохт холӣ гузоред';

  @override
  String get serverAddressSaved =>
      'Суроға нигоҳ дошта шуд. Барномаро аз нав кушоед.';

  @override
  String serverAddressCurrent(String url) {
    return 'Ҳозир: $url';
  }

  @override
  String get ratingHighAchievers => 'Аълочиён';

  @override
  String get subjectStrengths => 'Фанҳои қавӣ ва заиф';

  @override
  String subjectCoverage(int students, int grades) {
    return '$students хонанда / $grades баҳо';
  }

  @override
  String get awaitingDetection => 'Ҳанӯз тафтиш нашуд';

  @override
  String get profileTitle => 'Профил';

  @override
  String get streakDaysInARow => 'рӯз пайиҳам';

  @override
  String streakBest(int days) {
    return 'Беҳтарин натиҷа: $days рӯз';
  }

  @override
  String get streakStartToday =>
      'Пагоҳ ба мактаб биё — ҳисоб аз нав сар мешавад';

  @override
  String get identifierLabel => 'Телефон, почта ё логин';

  @override
  String get identifierHint => '98 764 40 02';

  @override
  String get codeTitle => 'Рақамро тасдиқ кунед';

  @override
  String codeSentTo(String phone) {
    return 'Рамз ба $phone фиристода шуд';
  }

  @override
  String get codeNotDelivered =>
      'SMS ҳанӯз пайваст нашудааст. Рамзро аз мактаб пурсед.';

  @override
  String get codeLabel => 'Рамз аз SMS';

  @override
  String get codeResend => 'Аз нав фиристодан';

  @override
  String get codeVerify => 'Давом додан';

  @override
  String get setupTitle => 'Парол гузоред';

  @override
  String get setupSubtitle =>
      'Минбаъд бо рақами телефон ва ҳамин парол ворид мешавед.';

  @override
  String get setupSave => 'Нигоҳ доштан ва ворид шудан';

  @override
  String get parentNoAccountHint =>
      'Ин рақам сабт нашудааст. Ба мактаб муроҷиат кунед.';

  @override
  String get lessonTimeInvalid => 'Ба намуди СС:ДД нависед, масалан 08:30';

  @override
  String get registerTitle => 'Бақайдгирӣ';

  @override
  String get registerSubtitle =>
      'Рақамеро нависед, ки дар мактаб сабт шудааст. Ба он рамз меояд.';

  @override
  String get registerAction => 'Ҳисоб надоред? Ба қайд гиред';

  @override
  String get copyAction => 'Нусхабардорӣ';

  @override
  String get copiedToClipboard => 'Нусха гирифта шуд';

  @override
  String get schoolSettings => 'Танзимоти мактаб';

  @override
  String get liveVideoSetting => 'Видеои жонли';

  @override
  String get liveVideoSettingHint =>
      'Ҳангоми хомӯш будан ҳеҷ кас дар мактаб камераро кушода наметавонад';

  @override
  String get liveVideoOffByDirector =>
      'Видеои жонли аз ҷониби директор хомӯш карда шудааст';

  @override
  String get groupModeSetting => 'Реҷаи гурӯҳҳо';

  @override
  String get groupModeSettingHint =>
      'Барои академияҳо: як синфхона, дар як рӯз якчанд гурӯҳ. Камера ба синфхона вобаста мешавад ва ҷадвал муайян мекунад, ки кадом гурӯҳ дар пеши он аст';

  @override
  String get cameraGroups => 'Гурӯҳҳо';

  @override
  String get cameraGroupsHint => 'Дар пеши ин камера кӣ ва кай меистад';

  @override
  String get addGroupSlot => 'Илова кардани гурӯҳ';

  @override
  String get everyDay => 'Ҳар рӯз';

  @override
  String get noGroupSlots => 'Ҳанӯз гурӯҳ нест';

  @override
  String get slotSaved => 'Илова шуд';

  @override
  String get deleteSlot => 'Нест кардан';
}
