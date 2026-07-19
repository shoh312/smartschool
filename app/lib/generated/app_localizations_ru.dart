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
  String get logout => 'Выйти';

  @override
  String get invalidPhoneError => 'Введите корректный номер телефона';

  @override
  String errorPrefix(String error) {
    return 'Ошибка: $error';
  }

  @override
  String get needSupport => 'Нужна помощь? ';

  @override
  String get contact => 'Контакты';

  @override
  String get roleDirector => 'Директор';

  @override
  String get roleParent => 'Родитель';

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
}
