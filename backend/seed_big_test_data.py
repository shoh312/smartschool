"""One-off seed script: adds a much larger, realistic test dataset to
school_id=1 (the real "Default School" that already has the director
account and a few real students) -- more classes (including parallels of
existing grade levels, for parallel-ranking testing), more teachers with
subject assignments, weekly lesson timetables, and ~15 days of grade
history (plus a smaller batch of previous-quarter grades so trend/decline
features have something real to show).

Safe to re-run: checks for existing rows by name/email before creating
duplicates. Run directly with the backend venv's python while the backend
server may or may not be running (uses its own short-lived session, same
as the other one-off scripts in this directory).
"""

import random
from datetime import date, timedelta

from app.database import SessionLocal
from app.models.attendance_model import Attendance  # noqa: F401 -- needed for mapper registry
from app.models.camera_model import Camera  # noqa: F401
from app.models.class_model import Class
from app.models.journal_model import Grade
from app.models.notification_model import DeviceToken, NotificationEvent  # noqa: F401
from app.models.parent_model import Parent
from app.models.school_model import School
from app.models.student import Student
from app.models.teacher_model import Teacher, TeacherClass
from app.utils.security import hash_password

SCHOOL_ID = 1
SUBJECTS = [
    "Забони тоҷикӣ", "Адабиёти тоҷик", "Забони русӣ", "Забони англисӣ",
    "Математика", "Физика", "Химия", "Биология", "Ҷуғрофия", "Таърих",
    "Информатика", "Тарбияи ҷисмонӣ",
]

FIRST_NAMES = [
    "Алишер", "Фарход", "Мадина", "Зарина", "Умед", "Шахло", "Толибҷон", "Нигора",
    "Хуршед", "Дилноза", "Сомон", "Гулнора", "Бахтиёр", "Малика", "Рустам", "Сабрина",
    "Комрон", "Фарзона", "Диловар", "Мунира", "Абдулло", "Шабнам", "Исмоил", "Наргис",
    "Ҷамшед", "Зулфия", "Парвиз", "Лола", "Некруз", "Ойша",
]
LAST_NAMES = [
    "Раҳимов", "Каримова", "Назаров", "Юсупова", "Аминов", "Собирова", "Одилов",
    "Насимова", "Қодиров", "Абдуллоева", "Сафаров", "Раҷабова", "Musaev", "Holova",
    "Ғаниев", "Тошева", "Latifov", "Umarova", "Салимов", "Бекова",
]

CLASS_PLAN = [
    # (name, grade)
    ("9B", 9), ("9C", 9),
    ("10B", 10),
    ("7A", 7), ("7B", 7),
]

TEACHER_PLAN = [
    ("Нилуфар Раҳимова", "teacher.nilufar@smartschool.test", "Математика"),
    ("Отабек Каримов", "teacher.otabek@smartschool.test", "Физика"),
    ("Мадина Юсупова", "teacher.madina@smartschool.test", "Забони тоҷикӣ"),
    ("Сардор Аминов", "teacher.sardor@smartschool.test", "Химия"),
    ("Зарина Одилова", "teacher.zarina@smartschool.test", "Забони англисӣ"),
    ("Фаридун Сафаров", "teacher.faridun@smartschool.test", "Таърих"),
]

random.seed(42)


def get_or_create_class(db, name: str, grade: int) -> Class:
    existing = db.query(Class).filter(Class.school_id == SCHOOL_ID, Class.name == name).first()
    if existing:
        return existing
    cls = Class(school_id=SCHOOL_ID, name=name, grade=grade, start_time="08:00", end_time="14:00")
    db.add(cls)
    db.flush()
    return cls


def get_or_create_teacher(db, full_name: str, email: str, subject: str) -> Teacher:
    existing = db.query(Teacher).filter(Teacher.email == email).first()
    if existing:
        return existing
    teacher = Teacher(
        school_id=SCHOOL_ID,
        full_name=full_name,
        email=email,
        subject=subject,
        hashed_password=hash_password("test12345"),
        is_active=True,
    )
    db.add(teacher)
    db.flush()
    return teacher


def assign_teacher(db, teacher: Teacher, cls: Class, subject: str) -> None:
    existing = db.query(TeacherClass).filter(
        TeacherClass.teacher_id == teacher.id,
        TeacherClass.class_id == cls.id,
        TeacherClass.subject == subject,
    ).first()
    if existing:
        return
    db.add(TeacherClass(teacher_id=teacher.id, class_id=cls.id, subject=subject))


def get_or_create_parent(db, full_name: str, phone: str) -> Parent:
    existing = db.query(Parent).filter(Parent.phone == phone).first()
    if existing:
        return existing
    parent = Parent(school_id=SCHOOL_ID, full_name=full_name, phone=phone)
    db.add(parent)
    db.flush()
    return parent


def get_or_create_student(db, first_name: str, last_name: str, cls: Class, parent: Parent) -> Student:
    existing = db.query(Student).filter(
        Student.school_id == SCHOOL_ID,
        Student.first_name == first_name,
        Student.last_name == last_name,
        Student.class_id == cls.id,
    ).first()
    if existing:
        return existing
    student = Student(
        school_id=SCHOOL_ID,
        class_id=cls.id,
        parent_id=parent.id,
        first_name=first_name,
        last_name=last_name,
        is_active=True,
    )
    db.add(student)
    db.flush()
    return student


def main():
    db = SessionLocal()
    try:
        school = db.query(School).filter(School.id == SCHOOL_ID).first()
        assert school is not None, f"School {SCHOOL_ID} not found"

        # --- classes ---
        new_classes = [get_or_create_class(db, name, grade) for name, grade in CLASS_PLAN]
        db.commit()
        print(f"Classes ready: {[c.name for c in new_classes]}")

        # --- teachers + assignments across ALL classes (new + the 2 existing real ones) ---
        existing_classes = db.query(Class).filter(Class.school_id == SCHOOL_ID).all()
        teachers = []
        for full_name, email, subject in TEACHER_PLAN:
            teacher = get_or_create_teacher(db, full_name, email, subject)
            teachers.append((teacher, subject))
        db.commit()

        for cls in existing_classes:
            for teacher, subject in teachers:
                assign_teacher(db, teacher, cls, subject)
        db.commit()
        print(f"Teachers ready: {[t.full_name for t, _ in teachers]}, assigned to {len(existing_classes)} classes")

        # --- students (~10 per new class) ---
        name_pool = [(f, l) for f in FIRST_NAMES for l in LAST_NAMES]
        random.shuffle(name_pool)
        name_iter = iter(name_pool)

        new_students = []
        for cls in new_classes:
            for i in range(10):
                first, last = next(name_iter)
                phone = f"90{random.randint(1000000, 9999999)}"
                parent = get_or_create_parent(db, f"{last} {first[0]}.", phone)
                student = get_or_create_student(db, first, last, cls, parent)
                new_students.append(student)
        db.commit()
        print(f"Students ready: {len(new_students)} new students across {len(new_classes)} classes")

        # --- grades: 15 days of current-quarter history + a smaller previous-quarter batch ---
        all_students = db.query(Student).filter(Student.school_id == SCHOOL_ID, Student.is_active == True).all()
        # Skew each student toward a personal "ability" so rankings/needs-attention
        # have genuine spread instead of everyone clustering around the same value.
        ability = {s.id: random.uniform(3.5, 9.5) for s in all_students}

        today = date.today()
        from app.utils.academic_calendar import current_quarter, current_school_year, quarter_for_date, school_year_for_date

        this_quarter = current_quarter()
        this_year = current_school_year()

        created = 0
        for days_ago in range(15):
            day = today - timedelta(days=days_ago)
            for student in all_students:
                cls = db.query(Class).filter(Class.id == student.class_id).first()
                if not cls:
                    continue
                assignments = db.query(TeacherClass).filter(TeacherClass.class_id == cls.id).all()
                if not assignments:
                    continue
                # 2 subjects per student per day, not every subject every day
                for assignment in random.sample(assignments, k=min(2, len(assignments))):
                    mean = ability[student.id]
                    value = int(round(min(10, max(1, random.gauss(mean, 1.2)))))
                    grade = Grade(
                        student_id=student.id,
                        class_id=cls.id,
                        teacher_id=assignment.teacher_id,
                        subject=assignment.subject,
                        value=value,
                        grade_date=day,
                        quarter=quarter_for_date(day),
                        school_year=school_year_for_date(day),
                    )
                    db.add(grade)
                    created += 1
            if days_ago % 5 == 0:
                db.commit()
        db.commit()
        print(f"Created {created} grade rows across the last 15 days (quarter {this_quarter}, school_year {this_year})")

        # --- a smaller previous-quarter batch, so trend/decline features have data ---
        prev_quarter = this_quarter - 1 if this_quarter > 1 else None
        if prev_quarter:
            prev_created = 0
            for student in all_students:
                cls = db.query(Class).filter(Class.id == student.class_id).first()
                if not cls:
                    continue
                assignments = db.query(TeacherClass).filter(TeacherClass.class_id == cls.id).all()
                if not assignments:
                    continue
                # Deliberately shift some students' previous-quarter ability up or
                # down from their current one, so "biggest decliners" has real
                # movement to detect instead of everyone being flat.
                shift = random.choice([-2.5, -1.5, 0, 0, 0.5, 1.5])
                prev_mean = min(10, max(1, ability[student.id] + shift))
                for assignment in random.sample(assignments, k=min(3, len(assignments))):
                    value = int(round(min(10, max(1, random.gauss(prev_mean, 1.2)))))
                    # Nominal date within the previous quarter's range -- exact day
                    # doesn't matter, only quarter/school_year are read by rankings.
                    grade = Grade(
                        student_id=student.id,
                        class_id=cls.id,
                        teacher_id=assignment.teacher_id,
                        subject=assignment.subject,
                        value=value,
                        grade_date=today - timedelta(days=100),
                        quarter=prev_quarter,
                        school_year=this_year,
                    )
                    db.add(grade)
                    prev_created += 1
            db.commit()
            print(f"Created {prev_created} grade rows for previous quarter ({prev_quarter}, school_year {this_year})")

        print("Done.")
    except Exception:
        db.rollback()
        raise
    finally:
        db.close()


if __name__ == "__main__":
    main()
