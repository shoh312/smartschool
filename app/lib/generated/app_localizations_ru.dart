// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get title => 'Умная школа';

  @override
  String get login => 'Вход';

  @override
  String get signIn => 'Войти';

  @override
  String get email => 'Электронная почта';

  @override
  String get password => 'Пароль';

  @override
  String get phone => 'Номер телефона';

  @override
  String get welcome => 'Добро пожаловать';

  @override
  String get login_desc => 'Введите свои учетные данные для входа.';

  @override
  String get dashboard => 'Главная';

  @override
  String get live => 'Видео';

  @override
  String get manage => 'Управление';

  @override
  String get alerts => 'Оповещения';

  @override
  String get students => 'Ученики';

  @override
  String get classes => 'Классы';

  @override
  String get classSingle => 'Класс';

  @override
  String get cameras => 'Камеры';

  @override
  String get settings => 'Настройки';

  @override
  String get language => 'Язык';

  @override
  String get appearance => 'Внешний вид';

  @override
  String get themeLight => 'Светлая';

  @override
  String get themeDark => 'Тёмная';

  @override
  String get themeSystem => 'Как в системе';

  @override
  String get logout => 'Выйти';

  @override
  String get invalidPhoneError => 'Введите корректный номер телефона';

  @override
  String errorPrefix(String error) {
    return 'Ошибка: $error';
  }

  @override
  String get networkErrorMessage =>
      'Не удалось подключиться к серверу. Проверьте подключение к интернету или убедитесь, что сервер запущен.';

  @override
  String get serverErrorMessage => 'Сервер вернул ошибку. Попробуйте снова.';

  @override
  String get unknownErrorMessage => 'Что-то пошло не так. Попробуйте снова.';

  @override
  String get phoneNotRegisteredMessage =>
      'Этот номер телефона еще не зарегистрирован ни в одной школе. Обратитесь в школу вашего ребенка.';

  @override
  String get invalidCredentialsMessage => 'Неверный email или пароль.';

  @override
  String get accountInactiveMessage =>
      'Ваша учетная запись неактивна. Обратитесь к администратору.';

  @override
  String get invalidCurrentPasswordMessage => 'Текущий пароль неверен.';

  @override
  String get usernameTakenMessage => 'Этот логин уже занят. Выберите другой.';

  @override
  String get needSupport => 'Нужна помощь? ';

  @override
  String get contact => 'Контакты';

  @override
  String get roleDirector => 'Директор';

  @override
  String get roleParent => 'Родитель';

  @override
  String get roleTeacher => 'Учитель';

  @override
  String get roleStudent => 'Ученик';

  @override
  String get studentUsernameLabel => 'Логин';

  @override
  String get createAccount => 'Создать аккаунт';

  @override
  String get lastStep => 'Последний шаг!';

  @override
  String tellUsName(String phone) {
    return 'Введите ваше имя, чтобы завершить регистрацию для $phone';
  }

  @override
  String get fullName => 'Полное имя';

  @override
  String get fullNameHint => 'Иван Иванов';

  @override
  String get completeRegistration => 'Завершить регистрацию';

  @override
  String get termsAndPrivacy =>
      'Продолжая, вы соглашаетесь с Условиями использования и Политикой конфиденциальности.';

  @override
  String get present => 'Присутствует';

  @override
  String get late => 'Опоздал';

  @override
  String get absent => 'Отсутствует';

  @override
  String get leftSchool => 'Ушел из школы';

  @override
  String get notDetected => 'Не обнаружен';

  @override
  String get quickActions => 'Быстрые действия';

  @override
  String get history => 'История';

  @override
  String get liveStream => 'Прямой эфир';

  @override
  String get recentActivity => 'Последние действия';

  @override
  String get attendanceByClass => 'Посещаемость по классам';

  @override
  String get noAttendanceRecorded =>
      'Сегодня посещаемость еще не фиксировалась';

  @override
  String cameraLabel(String cameraId) {
    return 'Камера: $cameraId';
  }

  @override
  String get noChildrenLinked => 'Нет привязанных детей';

  @override
  String get assignedStudentsWillAppear =>
      'Здесь появятся назначенные ученики.';

  @override
  String get children => 'Дети';

  @override
  String get attendanceHistory => 'История посещаемости';

  @override
  String get liveStatus => 'Текущий статус';

  @override
  String get selectClass => 'Пожалуйста, выберите класс';

  @override
  String get studentPhotoRequired => 'Требуется фото ученика';

  @override
  String get deleteStudentTitle => 'Удалить ученика';

  @override
  String get deleteStudentConfirm =>
      'Вы уверены, что хотите удалить этого ученика?';

  @override
  String get cancel => 'Отмена';

  @override
  String get delete => 'Удалить';

  @override
  String get studentManagement => 'Управление учениками';

  @override
  String get addNewStudent => 'Добавить ученика';

  @override
  String get editStudent => 'Редактировать ученика';

  @override
  String get firstName => 'Имя';

  @override
  String get lastName => 'Фамилия';

  @override
  String get parentPhoneNumber => 'Номер телефона родителя';

  @override
  String get isActive => 'Активен';

  @override
  String get studentFacePhoto => 'Фото лица ученика';

  @override
  String get updatePhotoOptional => 'Обновить фото (необязательно)';

  @override
  String get requiredForFaceRecognition => 'Требуется для распознавания лиц';

  @override
  String get addStudent => 'Добавить ученика';

  @override
  String get saveChanges => 'Сохранить изменения';

  @override
  String get studentsList => 'Список учеников';

  @override
  String get noStudents => 'Нет учеников';

  @override
  String get studentsAssignedWillAppear =>
      'Здесь появятся ученики, привязанные к классам и родителям.';

  @override
  String get deleteClassTitle => 'Удалить класс';

  @override
  String get deleteClassConfirm =>
      'Вы уверены, что хотите удалить этот класс? Это может повлиять на связанных учеников и камеры.';

  @override
  String get classManagement => 'Управление классами';

  @override
  String get createNewClass => 'Создать новый класс';

  @override
  String get editClass => 'Редактировать класс';

  @override
  String get classNameLabel => 'Название класса';

  @override
  String get classNameHint => 'например, 9А, 10Б';

  @override
  String get gradeOptional => 'Параллель (необязательно)';

  @override
  String get gradeHint => 'Определяется автоматически, если пусто';

  @override
  String get createClass => 'Создать класс';

  @override
  String get existingClasses => 'Существующие классы';

  @override
  String get noClasses => 'Нет классов';

  @override
  String get createClassesMessage =>
      'Создайте классы для мониторинга посещаемости.';

  @override
  String gradeLabel(String grade) {
    return 'Класс $grade';
  }

  @override
  String get deleteCameraTitle => 'Удалить камеру';

  @override
  String get deleteCameraConfirm =>
      'Вы уверены, что хотите удалить эту камеру?';

  @override
  String get cameraManagement => 'Управление камерами';

  @override
  String get addNewCamera => 'Добавить камеру';

  @override
  String get editCamera => 'Редактировать камеру';

  @override
  String get cameraNameLabel => 'Название камеры';

  @override
  String get assignToClass => 'Привязать к классу';

  @override
  String get rtspUrl => 'RTSP URL';

  @override
  String get startTime => 'Время начала';

  @override
  String get endTime => 'Время окончания';

  @override
  String get detectSec => 'Детекция (сек)';

  @override
  String get waitMin => 'Ожидание (мин)';

  @override
  String get addCamera => 'Добавить камеру';

  @override
  String get registeredCameras => 'Зарегистрированные камеры';

  @override
  String get noCameras => 'Нет камер';

  @override
  String get classroomCamerasWillAppear => 'Здесь появятся камеры из классов.';

  @override
  String cameraListSubtitle(String className, String waitDuration) {
    return 'Класс: $className • Ожидание: $waitDurationм';
  }

  @override
  String get unassigned => 'Не привязана';

  @override
  String get noAttendanceRecords => 'Нет записей о посещаемости';

  @override
  String get recordsWillAppear =>
      'Записи появятся после начала распознавания лиц.';

  @override
  String inTimeOutTime(String inTime, String outTime) {
    return 'Приход $inTime  Уход $outTime';
  }

  @override
  String get noLiveData => 'Нет текущих данных';

  @override
  String get realtimeAttendanceMessage =>
      'Текущая посещаемость появится во время детекции.';

  @override
  String lastSeenTime(String time) {
    return 'Последний раз замечен в $time';
  }

  @override
  String get directorNotifications => 'Уведомления директора';

  @override
  String get schoolWideNotificationView =>
      'Просмотр общешкольных уведомлений можно будет включить позже.';

  @override
  String get noNotifications => 'Нет уведомлений';

  @override
  String get attendanceAlertsWillAppear =>
      'Здесь появятся уведомления о посещаемости.';

  @override
  String get studentNotFound => 'Ученик не найден';

  @override
  String classLabel(String classId) {
    return 'Класс $classId';
  }

  @override
  String parentLabel(String parentId) {
    return 'Родитель $parentId';
  }

  @override
  String get viewAttendanceHistoryButton => 'Посмотреть историю посещаемости';

  @override
  String get viewLiveStatusButton => 'Посмотреть текущий статус';

  @override
  String get signOutTooltip => 'Выйти из системы';

  @override
  String classTileLabel(String className) {
    return 'Класс: $className';
  }

  @override
  String classAttendanceRatio(String className, int arrived, int total) {
    return '$className • $arrived/$total пришли';
  }

  @override
  String get directorDashboard => 'Панель директора';

  @override
  String get parentDashboard => 'Панель родителя';

  @override
  String get notifications => 'Уведомления';

  @override
  String get grades => 'Оценки';

  @override
  String get noGrades => 'Оценок пока нет';

  @override
  String get noGradesMessage =>
      'Оценки появятся здесь, когда учитель их выставит.';

  @override
  String studentFallbackLabel(String id) {
    return 'Ученик №$id';
  }

  @override
  String get teacherMyClasses => 'Мои классы';

  @override
  String get teacherNoClassesTitle => 'Вам еще не назначен ни один класс';

  @override
  String get teacherNoClassesMessage =>
      'Это появится, когда директор назначит вам класс.';

  @override
  String classFallbackLabel(String classId) {
    return 'Класс №$classId';
  }

  @override
  String get journalStudentColumn => 'Ученик';

  @override
  String get journalScoreLabel => 'Оценка';

  @override
  String get journalCommentOptional => 'Комментарий (необязательно)';

  @override
  String get journalTeacherLabel => 'Учитель';

  @override
  String get journalNoComment => 'Без комментария';

  @override
  String get close => 'Закрыть';

  @override
  String get save => 'Сохранить';

  @override
  String get journalNoStudentsTitle => 'В этом классе не найдено учеников';

  @override
  String get journalNoStudentsMessage =>
      'Это появится, когда директор назначит учеников в этот класс.';

  @override
  String get teachers => 'Учителя';

  @override
  String get addNewTeacher => 'Новый учитель';

  @override
  String get create => 'Создать';

  @override
  String get existingTeachers => 'Существующие учителя';

  @override
  String get noTeachers => 'Пока нет учителей';

  @override
  String get noTeachersMessage =>
      'Добавьте нового учителя, используя форму выше.';

  @override
  String assignClassToTeacher(String name) {
    return 'Назначить класс для $name';
  }

  @override
  String get assignClassNoClasses => 'Сначала создайте класс.';

  @override
  String get noClassesAssignedYet => 'Пока не назначен ни один класс';

  @override
  String get removeAssignment => 'Убрать';

  @override
  String get addSubjectTitle => 'Добавить предмет';

  @override
  String get noTeachersForSubject => 'По этому предмету пока нет учителей';

  @override
  String get noSubjectsInClass => 'В этом классе пока нет предметов';

  @override
  String get addSubjectToStart =>
      'Нажмите «Добавить предмет», чтобы назначить учителя.';

  @override
  String get subjectsLabel => 'Предметы';

  @override
  String get subjectsAndTeachers => 'Предметы и учителя';

  @override
  String get viewJournal => 'Открыть журнал';

  @override
  String get removeAssignmentConfirm =>
      'Убрать этого учителя с этого предмета в классе? Уже выставленные оценки останутся.';

  @override
  String get subjectLabel => 'Предмет';

  @override
  String get assign => 'Назначить';

  @override
  String get classAssigned => 'Класс назначен';

  @override
  String get month1 => 'Январь';

  @override
  String get month2 => 'Февраль';

  @override
  String get month3 => 'Март';

  @override
  String get month4 => 'Апрель';

  @override
  String get month5 => 'Май';

  @override
  String get month6 => 'Июнь';

  @override
  String get month7 => 'Июль';

  @override
  String get month8 => 'Август';

  @override
  String get month9 => 'Сентябрь';

  @override
  String get month10 => 'Октябрь';

  @override
  String get month11 => 'Ноябрь';

  @override
  String get month12 => 'Декабрь';

  @override
  String get deleteTeacherTitle => 'Удалить учителя';

  @override
  String get deleteTeacherConfirm =>
      'Вы уверены, что хотите удалить этого учителя? Его назначения классов и выставленные оценки также будут удалены.';

  @override
  String get average => 'Средний балл';

  @override
  String get weekday1 => 'Пн';

  @override
  String get weekday2 => 'Вт';

  @override
  String get weekday3 => 'Ср';

  @override
  String get weekday4 => 'Чт';

  @override
  String get weekday5 => 'Пт';

  @override
  String get weekday6 => 'Сб';

  @override
  String get weekday7 => 'Вс';

  @override
  String get attendanceJournal => 'Журнал посещаемости';

  @override
  String get lastSeenLabel => 'Последний раз замечен';

  @override
  String get noAttendanceThisMonth =>
      'В этом месяце нет записей о посещаемости';

  @override
  String get noCameraForClassTitle => 'Для этого класса нет камеры';

  @override
  String get noCameraForClassMessage =>
      'Назначьте камеру этому классу в разделе «Управление камерами», чтобы видеть его статус в реальном времени.';

  @override
  String get studentNotAssignedToClass => 'Этот ученик ещё не назначен в класс';

  @override
  String get cameraNotAvailable =>
      'Съёмка с камеры недоступна на этом устройстве. Используйте «Галерею».';

  @override
  String get rooms => 'Кабинеты';

  @override
  String get roomManagement => 'Управление кабинетами';

  @override
  String get addNewRoom => 'Добавить кабинет';

  @override
  String get editRoom => 'Редактировать кабинет';

  @override
  String get roomNameLabel => 'Название кабинета';

  @override
  String get assignToRoom => 'Привязать к кабинету';

  @override
  String get positions => 'Смены';

  @override
  String get addPosition => 'Добавить смену';

  @override
  String get positionClassLabel => 'Класс';

  @override
  String get registeredRooms => 'Зарегистрированные кабинеты';

  @override
  String get noRooms => 'Нет кабинетов';

  @override
  String get roomsWillAppear => 'Кабинеты появятся здесь.';

  @override
  String get deleteRoomTitle => 'Удалить кабинет';

  @override
  String get deleteRoomConfirm =>
      'Вы уверены, что хотите удалить этот кабинет?';

  @override
  String get roomHasCamerasError =>
      'Сначала переназначьте или удалите камеры этого кабинета.';

  @override
  String cameraListSubtitleRoom(String roomName, String waitDuration) {
    return 'Кабинет: $roomName • Пауза: $waitDurationм';
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
    return '$className - Аналитика';
  }

  @override
  String get noDataTitle => 'Нет данных';

  @override
  String get noAttendanceDataLast30Days =>
      'Нет данных о посещаемости за последние 30 дней';

  @override
  String get perStudentDetails => 'Данные по каждому ученику';

  @override
  String get hoursLabel => 'Часы';

  @override
  String get thirtyDayTimeline => 'Хронология за 30 дней';

  @override
  String get noTimetableSubjectsTitle => 'Нет предметов в расписании';

  @override
  String get noTimetableSubjectsMessage =>
      'Сначала добавьте уроки в расписание этого класса.';

  @override
  String get tapToAssignTeacher => 'Нажмите, чтобы назначить учителя';

  @override
  String get timetableLabel => 'Расписание';

  @override
  String totalHoursPerWeek(String hours) {
    return 'Всего: $hours ч/нед';
  }

  @override
  String get noLessonsForDay => 'На этот день нет уроков';

  @override
  String get addLesson => 'Добавить урок';

  @override
  String get minutesUnit => 'мин';

  @override
  String get cameraOptionTooltip => 'Камера';

  @override
  String get galleryOptionTooltip => 'Галерея';

  @override
  String get noFrame => 'Нет кадра';

  @override
  String get selectMonth => 'Выберите месяц';

  @override
  String get generatePdfReport => 'Создать PDF-отчёт';

  @override
  String get pdfReportEyebrow => 'ОТЧЁТ О ПОСЕЩАЕМОСТИ';

  @override
  String get pdfNoDataForMonth =>
      'Нет данных о посещаемости за выбранный месяц';

  @override
  String get columnPresentDays => 'Дней присутствовал';

  @override
  String get columnLateDays => 'Дней опоздал';

  @override
  String get columnAbsentDays => 'Дней отсутствовал';

  @override
  String get columnPresentHours => 'Часов присутствовал';

  @override
  String get columnAbsentHours => 'Часов отсутствовал';

  @override
  String get columnRate => 'Процент';

  @override
  String get ratingAnalytics => 'Рейтинг';

  @override
  String get overallAverage => 'Средний балл';

  @override
  String get classRank => 'Класс';

  @override
  String get parallelRank => 'Параллель';

  @override
  String get schoolRank => 'Школа';

  @override
  String get classRanking => 'Рейтинг класса';

  @override
  String get parallelRanking => 'Рейтинг параллели';

  @override
  String get schoolRanking => 'Рейтинг школы';

  @override
  String get strongestSubject => 'Сильный предмет';

  @override
  String get weakestSubject => 'Требует внимания';

  @override
  String get subjectBreakdown => 'Предметы';

  @override
  String get lessonAttendanceRate => 'Посещаемость уроков';

  @override
  String get quarter1 => '1 четверть';

  @override
  String get quarter2 => '2 четверть';

  @override
  String get quarter3 => '3 четверть';

  @override
  String get quarter4 => '4 четверть';

  @override
  String get noGradesYetMessage => 'За этот период оценок ещё нет';

  @override
  String get achievementFirstPlace => '1 место';

  @override
  String get achievementTopThree => 'Топ 3';

  @override
  String get achievementTopTenPercent => 'Топ 10%';

  @override
  String get exportPdf => 'Экспорт PDF';

  @override
  String get classAverage => 'Средний по классу';

  @override
  String get parallelAverage => 'Средний по параллели';

  @override
  String get schoolAverage => 'Средний по школе';

  @override
  String get needsAttention => 'Требуют внимания';

  @override
  String get biggestDecline => 'Наибольшее снижение';

  @override
  String get lowestAverage => 'Самый низкий балл';

  @override
  String get trendVsPreviousQuarter => 'к прошлой четверти';

  @override
  String get pdfRatingEyebrow => 'ОТЧЁТ О РЕЙТИНГЕ';

  @override
  String get gradeCountSuffix => 'оценок';

  @override
  String get rankingScopeAll => 'Все';

  @override
  String get rankingScopeClasses => 'Классы';

  @override
  String get rankingScopeParallel => 'Параллель';

  @override
  String get selectClassPrompt => 'Выберите класс';

  @override
  String get selectParallelPrompt => 'Выберите параллель';

  @override
  String get topThree => 'Топ 3';

  @override
  String lessonSchedule(String className) {
    return 'Расписание — $className';
  }

  @override
  String get editLesson => 'Изменить урок';

  @override
  String get deleteLessonTitle => 'Удалить урок';

  @override
  String get deleteLessonConfirm =>
      'Удалить этот урок? Это действие необратимо.';

  @override
  String get roomLabel => 'Кабинет';

  @override
  String get ruznoma => 'Дневник';

  @override
  String get todayLessons => 'Сегодня';

  @override
  String get tomorrowLessons => 'Завтра';

  @override
  String get homeworkLabel => 'Домашнее задание';

  @override
  String get teacherNoteLabel => 'Заметка учителя';

  @override
  String get addHomeworkPrompt => 'Добавить задание или заметку';

  @override
  String get noLessonsToday => 'На этот день уроков нет';

  @override
  String get schoolCalendar => 'Школьный календарь';

  @override
  String get eventTypeHoliday => 'Праздник';

  @override
  String get eventTypeExam => 'Экзамен';

  @override
  String get eventTypeTest => 'Контрольная работа';

  @override
  String get eventTypeEvent => 'Мероприятие';

  @override
  String get addEvent => 'Добавить событие';

  @override
  String get eventTitleLabel => 'Название';

  @override
  String get eventDescriptionLabel => 'Описание (необязательно)';

  @override
  String get noUpcomingEvents => 'Нет предстоящих событий';

  @override
  String get deleteEventTitle => 'Удалить событие';

  @override
  String get deleteEventConfirm => 'Удалить это событие?';

  @override
  String get announcements => 'Объявления';

  @override
  String get postAnnouncement => 'Опубликовать объявление';

  @override
  String get announcementTitleLabel => 'Название';

  @override
  String get announcementBodyLabel => 'Текст';

  @override
  String get noAnnouncementsYet => 'Пока нет объявлений';

  @override
  String get deleteAnnouncementTitle => 'Удалить объявление';

  @override
  String get deleteAnnouncementConfirm => 'Удалить это объявление?';

  @override
  String get pickDatePrompt => 'Выберите дату';

  @override
  String get lessonWord => 'урок';

  @override
  String get lessonsCountSuffix => 'уроков';

  @override
  String untilTime(String time) {
    return 'до $time';
  }

  @override
  String get teacherWord => 'Учитель';

  @override
  String lessonOrdinal(int number) {
    return 'Урок $number';
  }

  @override
  String get retry => 'Повторить';

  @override
  String get logoutConfirmMessage => 'Вы уверены, что хотите выйти?';

  @override
  String get homeworkListTitle => 'Домашние задания';

  @override
  String get noHomeworkMessage => 'Домашних заданий пока нет';

  @override
  String get achievementsTitle => 'Достижения';

  @override
  String get achievementSchoolFirst => '№1 в школе';

  @override
  String get achievementTopThreeBadge => 'Топ 3';

  @override
  String get achievementExcellent => 'Отличник';

  @override
  String get achievementPerfectAttendance => 'Отличная посещаемость';

  @override
  String get achievementBigImprovement => 'Лучший прогресс';

  @override
  String achievementSubjectMaster(String subject) {
    return 'Мастер предмета «$subject»';
  }

  @override
  String get noAchievementsTitle => 'Пока нет достижений';

  @override
  String get noAchievementsMessage =>
      'Продолжайте учиться -- первый значок уже близко';

  @override
  String get studentHomeTitle => 'Моя страница';

  @override
  String get studentLoginLabel => 'Логин для входа';

  @override
  String get studentPasswordLabel => 'Пароль';

  @override
  String get studentLoginHelperText =>
      'Необязательно -- нужно только если ученик будет входить сам';

  @override
  String get journalScanTitle => 'Скан журнала';

  @override
  String get journalScanPrompt =>
      'Сфотографируйте страницу журнала или выберите из галереи. Оценки в сегодняшнем столбце будут распознаны автоматически.';

  @override
  String get journalScanTakePhoto => 'Сделать фото';

  @override
  String get journalScanPickGallery => 'Выбрать из галереи';

  @override
  String get journalScanEmptyTitle => 'Ничего не найдено';

  @override
  String get journalScanEmptyMessage =>
      'В сегодняшнем столбце этого фото оценки не найдены. Попробуйте сделать более чёткое, ровное фото.';

  @override
  String get journalScanConfirmAll => 'Подтвердить и сохранить';

  @override
  String journalScanSavedCount(int saved, int total) {
    return 'Сохранено $saved из $total оценок';
  }

  @override
  String journalScanNoMatch(String name) {
    return 'Нет совпадения для \"$name\" -- пропущено';
  }

  @override
  String journalScanRawName(String name) {
    return 'Распознано как: $name';
  }

  @override
  String get journalScanAbsent => 'Отсутствовал';

  @override
  String get attendanceToday => 'Посещаемость сегодня';

  @override
  String get sectionLearning => 'Учёба';

  @override
  String get sectionSchool => 'Школа';

  @override
  String arrivedOfTotal(int arrived, int total) {
    return 'Пришли $arrived из $total';
  }

  @override
  String get materialsTitle => 'Материалы';

  @override
  String get materialsSubtitle => 'Уроки и тесты для ваших классов';

  @override
  String get materialLibrary => 'Моя библиотека';

  @override
  String get materialHandedOut => 'Выдано';

  @override
  String get materialNew => 'Новый материал';

  @override
  String get materialTitleLabel => 'Название';

  @override
  String get materialDescriptionLabel => 'Краткое описание';

  @override
  String get materialEmptyTitle => 'Материалов пока нет';

  @override
  String get materialEmptyMessage => 'Создайте урок или тест и выдайте классу.';

  @override
  String get materialContentEmpty =>
      'Добавьте хотя бы одну страницу или вопрос.';

  @override
  String get materialPage => 'Страница';

  @override
  String get materialQuestion => 'Вопрос';

  @override
  String get materialAddPage => 'Страница';

  @override
  String get materialAddQuestion => 'Вопрос';

  @override
  String get materialPasteImport => 'Вставить из текста';

  @override
  String get materialPasteTitle => 'Вставьте свои вопросы';

  @override
  String get materialPasteHelp =>
      '# начинает страницу с объяснением, строка с номером — вопрос, * отмечает верный вариант, - неверный, а = делает вопрос с вводом ответа.';

  @override
  String get materialPasteAction => 'Разобрать текст';

  @override
  String materialPasteResult(int count) {
    return '$count блоков разобрано';
  }

  @override
  String get materialQuestionType => 'Тип вопроса';

  @override
  String get materialTypeSingle => 'Один верный ответ';

  @override
  String get materialTypeTrueFalse => 'Верно / Неверно';

  @override
  String get materialTypeFill => 'Ввести ответ';

  @override
  String get materialTypeMatch => 'Соединить пары';

  @override
  String get materialTypeOrder => 'Расставить по порядку';

  @override
  String get materialQuestionText => 'Текст вопроса';

  @override
  String get materialPageText => 'Текст страницы';

  @override
  String get materialOption => 'Вариант';

  @override
  String get materialAddOption => 'Добавить вариант';

  @override
  String get materialMarkCorrect =>
      'Нажмите кружок, чтобы отметить верный ответ';

  @override
  String get materialAcceptedAnswers => 'Принимаемые ответы';

  @override
  String get materialAcceptedHint =>
      'По одному в строке — все варианты написания засчитываются.';

  @override
  String get materialLeftItem => 'Слева';

  @override
  String get materialRightItem => 'Справа';

  @override
  String get materialOrderHint =>
      'Запишите элементы в правильном порядке — ученик увидит их перемешанными.';

  @override
  String get materialTrue => 'Верно';

  @override
  String get materialFalse => 'Неверно';

  @override
  String get materialAssign => 'Выдать';

  @override
  String get materialAssignTitle => 'Выдать классам';

  @override
  String get materialPickClasses => 'Каким классам';

  @override
  String get materialMode => 'Вид работы';

  @override
  String get materialModeControl => 'Контрольная';

  @override
  String get materialModeControlHint =>
      'С оценкой. Баллы скрыты до срока сдачи.';

  @override
  String get materialModePractice => 'Тренировка';

  @override
  String get materialModePracticeHint =>
      'Без оценки. Ученик сразу видит верно или нет.';

  @override
  String get materialDueAt => 'Срок сдачи';

  @override
  String get materialPickDue => 'Выберите срок';

  @override
  String get materialAttempts => 'Попытки';

  @override
  String get materialAttemptsUnlimited => 'Без ограничения';

  @override
  String get materialControlNeedsDue => 'Для контрольной нужен срок сдачи.';

  @override
  String get materialPickAtLeastOne => 'Выберите хотя бы один класс.';

  @override
  String get materialResults => 'Результаты';

  @override
  String materialSubmittedOf(int done, int total) {
    return 'Сдали $done из $total';
  }

  @override
  String get materialResultsHidden =>
      'Баллы откроются после срока сдачи или когда сдадут все.';

  @override
  String get materialNotSubmitted => 'Не сдано';

  @override
  String get materialTransfer => 'Перенести в журнал';

  @override
  String get materialTransferDone => 'Оценки перенесены в журнал';

  @override
  String get materialTransferred => 'В журнале';

  @override
  String get materialDuplicate => 'Сделать копию';

  @override
  String get materialLockedEdit =>
      'Материал уже выдан. Сделайте копию, чтобы менять вопросы.';

  @override
  String get materialDeleteTitle => 'Удалить материал?';

  @override
  String get materialDeleteConfirm =>
      'Он исчезнет из библиотеки и из всех классов, которым был выдан.';

  @override
  String get materialNoQuestions => 'нет вопросов';

  @override
  String materialQuestionsCount(int count) {
    return '$count вопросов';
  }

  @override
  String get assignmentsTitle => 'Задания';

  @override
  String get assignmentsNoneTitle => 'Пока ничего нет';

  @override
  String get assignmentsNoneMessage => 'Учителя пока не выдали заданий.';

  @override
  String get assignmentStart => 'Начать';

  @override
  String get assignmentContinue => 'Продолжить';

  @override
  String get assignmentRetry => 'Пройти снова';

  @override
  String get assignmentNext => 'Далее';

  @override
  String get assignmentCheck => 'Проверить';

  @override
  String get assignmentFinish => 'Завершить';

  @override
  String get assignmentCorrect => 'Верно!';

  @override
  String get assignmentWrong => 'Не совсем';

  @override
  String get assignmentOverdue => 'Срок прошёл';

  @override
  String get assignmentDone => 'Сдано';

  @override
  String assignmentDueLabel(String when) {
    return 'До $when';
  }

  @override
  String assignmentAttemptsLeft(int count) {
    return 'Осталось попыток: $count';
  }

  @override
  String get assignmentNoAttemptsLeft => 'Попыток не осталось';

  @override
  String get assignmentWaitingMark => 'Сдано. Балл появится после срока сдачи.';

  @override
  String get assignmentYourScore => 'Ваш результат';

  @override
  String get assignmentTypeAnswer => 'Введите ответ';

  @override
  String get assignmentTapInOrder => 'Нажимайте слова по порядку';

  @override
  String get assignmentMatchHint => 'Выберите по одному с каждой стороны';

  @override
  String get assignmentLeave => 'Выйти из задания?';

  @override
  String get assignmentLeaveMessage =>
      'Ответы сохранены — можно вернуться и продолжить.';

  @override
  String get materialScopeMine => 'Мои';

  @override
  String get materialScopeSchool => 'Школа';

  @override
  String materialByTeacher(String name) {
    return 'автор: $name';
  }

  @override
  String get materialReadOnly =>
      'Это чужой материал. Сделайте копию, чтобы изменить или выдать.';

  @override
  String get materialSchoolEmpty => 'Другие пока ничего не создали.';

  @override
  String get analysisByQuarter => 'По четвертям';

  @override
  String get analysisByMonth => 'За месяц';

  @override
  String get analysisNoMonthly => 'В этом месяце оценок нет.';

  @override
  String get analysisBestDay => 'Лучший день';

  @override
  String analysisDaysWithMarks(int count) {
    return 'Дней с оценками: $count';
  }

  @override
  String get aiTitle => 'AI-помощник';

  @override
  String get aiSubtitle =>
      'Черновик урока или теста, который вы проверите сами';

  @override
  String get aiStepSource => 'Источник';

  @override
  String get aiStepSettings => 'Настройки';

  @override
  String get aiStepReview => 'Проверка';

  @override
  String get aiSourceTopic => 'Тема';

  @override
  String get aiSourceTopicHint => 'Напишите тему, например «Теорема Пифагора»';

  @override
  String get aiSourcePhoto => 'Фото учебника';

  @override
  String get aiSourcePhotoHint => 'Сфотографируйте страницу — AI её прочитает';

  @override
  String get aiSourceText => 'Вставить текст';

  @override
  String get aiSourceTextHint => 'Вставьте текст из книги или документа';

  @override
  String get aiPickPhoto => 'Выбрать фото';

  @override
  String get aiPhotoReady => 'Фото прикреплено';

  @override
  String get aiNeedSource => 'Сначала заполните источник.';

  @override
  String get aiQuestionCount => 'Вопросов';

  @override
  String get aiPageCount => 'Страниц объяснения';

  @override
  String get aiDifficulty => 'Сложность';

  @override
  String get aiDifficultyEasy => 'Лёгкая';

  @override
  String get aiDifficultyMedium => 'Средняя';

  @override
  String get aiDifficultyHard => 'Сложная';

  @override
  String get aiNeedTypes => 'Выберите хотя бы один тип вопроса.';

  @override
  String get aiGenerate => 'Создать';

  @override
  String get aiWorking => 'Составляю материал…';

  @override
  String get aiWorkingHint => 'Обычно это занимает 20–30 секунд.';

  @override
  String get aiReviewWarning =>
      'AI может ошибаться. Прочитайте каждый блок и исправьте перед сохранением.';

  @override
  String aiDropped(int count) {
    return 'Удалено непригодных блоков: $count.';
  }

  @override
  String get aiSaveMaterial => 'Сохранить как материал';

  @override
  String get aiRegenerate => 'Создать заново';

  @override
  String get aiBack => 'Назад';

  @override
  String get aiNext => 'Далее';

  @override
  String get passwordChangeTitle => 'Смените пароль';

  @override
  String get passwordChangeWhy =>
      'Аккаунт всё ещё использует пароль по умолчанию. Задайте свой, прежде чем продолжить.';

  @override
  String get passwordCurrent => 'Текущий пароль';

  @override
  String get passwordNew => 'Новый пароль';

  @override
  String get passwordRepeat => 'Повторите новый пароль';

  @override
  String get passwordTooShort => 'Минимум 8 символов.';

  @override
  String get passwordMismatch => 'Пароли не совпадают.';

  @override
  String get passwordIsDefault => 'Выберите пароль, отличный от стандартного.';

  @override
  String get passwordChanged => 'Пароль изменён.';

  @override
  String get passwordSave => 'Сохранить пароль';

  @override
  String get serverAddress => 'Адрес сервера';

  @override
  String get serverAddressHint => 'Оставьте пустым для встроенного адреса';

  @override
  String get serverAddressSaved => 'Адрес сохранён. Перезапустите приложение.';

  @override
  String serverAddressCurrent(String url) {
    return 'Сейчас: $url';
  }

  @override
  String get ratingHighAchievers => 'Отличники';

  @override
  String get subjectStrengths => 'Сильные и слабые предметы';

  @override
  String subjectCoverage(int students, int grades) {
    return '$students учеников / $grades оценок';
  }

  @override
  String get awaitingDetection => 'Ещё не проверено';

  @override
  String get profileTitle => 'Профиль';

  @override
  String get streakDaysInARow => 'дней подряд';

  @override
  String streakBest(int days) {
    return 'Лучший результат: $days дней';
  }

  @override
  String get streakStartToday => 'Приходи завтра — счёт начнётся заново';

  @override
  String get identifierLabel => 'Телефон, почта или логин';

  @override
  String get identifierHint => '98 764 40 02';

  @override
  String get codeTitle => 'Подтвердите номер';

  @override
  String codeSentTo(String phone) {
    return 'Код отправлен на $phone';
  }

  @override
  String get codeNotDelivered => 'SMS ещё не подключены. Спросите код в школе.';

  @override
  String get codeLabel => 'Код из SMS';

  @override
  String get codeResend => 'Отправить снова';

  @override
  String get codeVerify => 'Далее';

  @override
  String get setupTitle => 'Придумайте пароль';

  @override
  String get setupSubtitle =>
      'Входить будете по номеру телефона и этому паролю.';

  @override
  String get setupSave => 'Сохранить и войти';

  @override
  String get parentNoAccountHint =>
      'Этот номер не зарегистрирован. Обратитесь в школу.';

  @override
  String get lessonTimeInvalid => 'Формат ЧЧ:ММ, например 08:30';

  @override
  String get registerTitle => 'Регистрация';

  @override
  String get registerSubtitle =>
      'Введите номер, который записан в школе. На него придёт код.';

  @override
  String get registerAction => 'Нет аккаунта? Зарегистрируйтесь';

  @override
  String get copyAction => 'Копировать';

  @override
  String get copiedToClipboard => 'Скопировано';

  @override
  String get schoolSettings => 'Настройки школы';

  @override
  String get liveVideoSetting => 'Онлайн-видео';

  @override
  String get liveVideoSettingHint =>
      'Когда выключено, никто в школе не может открыть камеру';

  @override
  String get liveVideoOffByDirector => 'Онлайн-видео отключено директором';

  @override
  String get groupModeSetting => 'Режим групп';

  @override
  String get groupModeSettingHint =>
      'Для академий: один кабинет, несколько групп в день. Камера привязана к кабинету, а расписание решает, чья группа перед ней';

  @override
  String get smsEnabledSetting => 'SMS-уведомления';

  @override
  String get smsEnabledSettingHint =>
      'Когда выключено, родителям не отправляются SMS о посещаемости и данные для входа -- выключите, пока расписание внесено, а камеры ещё нет';

  @override
  String get schoolActiveSetting => 'Учёт посещаемости';

  @override
  String get schoolActiveSettingHint =>
      'Когда выключено, по всей школе не записывается ни \"пришёл\", ни \"не пришёл\" -- используйте, чтобы приостановить учёт, пока камеры ещё не установлены';

  @override
  String get cameraGroups => 'Группы';

  @override
  String get cameraGroupsHint => 'Кто находится перед этой камерой и когда';

  @override
  String get addGroupSlot => 'Добавить группу';

  @override
  String get everyDay => 'Каждый день';

  @override
  String get noGroupSlots => 'Групп пока нет';

  @override
  String get slotSaved => 'Добавлено';

  @override
  String get deleteSlot => 'Удалить';

  @override
  String get dashTodayStatus => 'Сегодня в школе';

  @override
  String get dashArrived => 'пришли';

  @override
  String get dashLate => 'опоздали';

  @override
  String get dashMissing => 'отсутствуют';

  @override
  String get dashWaiting => 'ожидаются';

  @override
  String get dashArrivalTime => 'Время прихода';

  @override
  String get dashArrivalSubtitle => 'накопительно с начала дня';

  @override
  String get dashTodayGroups => 'Сегодняшние группы';

  @override
  String get dashByClass => 'По классам';

  @override
  String get dashGroupsSubtitle => 'группы с занятием сегодня и их состояние';

  @override
  String get dashClassSubtitle => 'самые пустые сверху';

  @override
  String get dashNoGroupsToday => 'Сегодня ни у одной группы нет занятий';

  @override
  String get dashNoClassData => 'Нет данных о классах';

  @override
  String get dashRecentArrivals => 'Последние пришедшие';

  @override
  String get dashNobodyYet => 'Пока никто не пришёл';

  @override
  String get dashArrivedNoTime => 'Пришедшие есть, но время не записано';

  @override
  String get dashNoClass => 'Без класса';

  @override
  String get dashLessonRunning => 'идёт урок';

  @override
  String get dashLessonUpcoming => 'не началось';

  @override
  String get dashLessonFinished => 'завершено';

  @override
  String get dashShowLess => 'Свернуть';

  @override
  String get dashControlPanel => 'Панель управления';

  @override
  String dashMoreClasses(int count) {
    return 'Ещё $count';
  }
}
