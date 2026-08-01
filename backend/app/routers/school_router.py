from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.database import get_db
from app.deps import get_current_director
from app.models.camera_model import Camera
from app.models.class_model import Class
from app.models.director_model import Director
from app.schemas.school_schema import CameraCreate, CameraResponse, ClassCreate, ClassResponse

router = APIRouter(tags=["school"], dependencies=[Depends(get_current_director)])


def _grade_from_name(name: str) -> int | None:
    digits = "".join(char for char in name if char.isdigit())
    return int(digits) if digits else None


@router.get("/classes", response_model=list[ClassResponse])
def list_classes(db: Session = Depends(get_db), director: Director = Depends(get_current_director)):
    return db.query(Class).filter(Class.school_id == director.school_id).order_by(Class.name.asc()).all()


@router.post("/classes", response_model=ClassResponse)
def create_class(payload: ClassCreate, db: Session = Depends(get_db), director: Director = Depends(get_current_director)):
    class_name = payload.name.strip().upper()
    if not class_name:
        raise HTTPException(status_code=400, detail="Class name is required")

    existing = db.query(Class).filter(Class.name == class_name, Class.school_id == director.school_id).first()
    if existing:
        return existing

    school_class = Class(
        school_id=director.school_id,
        name=class_name,
        grade=payload.grade if payload.grade is not None else _grade_from_name(class_name),
        start_time=payload.start_time,
        end_time=payload.end_time,
        detect_duration_seconds=payload.detect_duration_seconds,
        wait_duration_minutes=payload.wait_duration_minutes,
        timetable=payload.timetable,
    )
    db.add(school_class)
    db.commit()
    db.refresh(school_class)
    return school_class


@router.put("/classes/{class_id}", response_model=ClassResponse)
def update_class(class_id: int, payload: ClassCreate, db: Session = Depends(get_db),
                  director: Director = Depends(get_current_director)):
    school_class = db.query(Class).filter(Class.id == class_id, Class.school_id == director.school_id).first()
    if not school_class:
        raise HTTPException(status_code=404, detail="Class not found")

    class_name = payload.name.strip().upper()
    if not class_name:
        raise HTTPException(status_code=400, detail="Class name is required")

    school_class.name = class_name
    school_class.grade = payload.grade if payload.grade is not None else _grade_from_name(class_name)
    school_class.start_time = payload.start_time
    school_class.end_time = payload.end_time
    school_class.detect_duration_seconds = payload.detect_duration_seconds
    school_class.wait_duration_minutes = payload.wait_duration_minutes
    school_class.timetable = payload.timetable

    db.commit()
    db.refresh(school_class)
    return school_class


@router.delete("/classes/{class_id}")
def delete_class(class_id: int, db: Session = Depends(get_db), director: Director = Depends(get_current_director)):
    school_class = db.query(Class).filter(Class.id == class_id, Class.school_id == director.school_id).first()
    if not school_class:
        raise HTTPException(status_code=404, detail="Class not found")

    from sqlalchemy import text
    from app.models.student import Student
    from app.models.attendance_model import Attendance
    from app.models.notification_model import NotificationEvent
    from app.models.journal_model import Grade
    from app.models.teacher_model import TeacherClass

    students = db.query(Student).filter(Student.class_id == class_id).all()
    student_ids = [s.id for s in students]

    attendances = db.query(Attendance).filter(Attendance.student_id.in_(student_ids)).all()
    attendance_ids = [a.id for a in attendances]
    if attendance_ids:
        db.query(NotificationEvent).filter(NotificationEvent.attendance_id.in_(attendance_ids)).delete(synchronize_session=False)
    if student_ids:
        db.query(NotificationEvent).filter(NotificationEvent.student_id.in_(student_ids)).delete(synchronize_session=False)
    if attendance_ids:
        db.query(Attendance).filter(Attendance.id.in_(attendance_ids)).delete(synchronize_session=False)

    db.query(Grade).filter((Grade.class_id == class_id) | (Grade.student_id.in_(student_ids))).delete(synchronize_session=False)
    db.query(TeacherClass).filter(TeacherClass.class_id == class_id).delete(synchronize_session=False)
    db.execute(text("DELETE FROM homework WHERE class_id = :class_id"), {"class_id": class_id})

    db.query(Camera).filter(Camera.class_id == class_id).update({"class_id": None}, synchronize_session=False)
    db.query(Student).filter(Student.class_id == class_id).delete(synchronize_session=False)
    db.delete(school_class)
    db.commit()
    return {"message": "Class deleted"}


@router.get("/cameras", response_model=list[CameraResponse])
def list_cameras(db: Session = Depends(get_db), director: Director = Depends(get_current_director)):
    return db.query(Camera).filter(Camera.school_id == director.school_id).order_by(Camera.id.desc()).all()


@router.post("/cameras", response_model=CameraResponse)
def create_camera(payload: CameraCreate, db: Session = Depends(get_db), director: Director = Depends(get_current_director)):
    if payload.class_id:
        school_class = db.query(Class).filter(Class.id == payload.class_id, Class.school_id == director.school_id).first()
        if not school_class:
            raise HTTPException(status_code=404, detail="Class not found")

    camera = Camera(school_id=director.school_id, **payload.model_dump())
    db.add(camera)
    db.commit()
    db.refresh(camera)
    return camera


@router.put("/cameras/{camera_id}", response_model=CameraResponse)
def update_camera(camera_id: int, payload: CameraCreate, db: Session = Depends(get_db),
                   director: Director = Depends(get_current_director)):
    camera = db.query(Camera).filter(Camera.id == camera_id, Camera.school_id == director.school_id).first()
    if not camera:
        raise HTTPException(status_code=404, detail="Camera not found")

    if payload.class_id:
        school_class = db.query(Class).filter(Class.id == payload.class_id, Class.school_id == director.school_id).first()
        if not school_class:
            raise HTTPException(status_code=404, detail="Class not found")

    for key, value in payload.model_dump().items():
        setattr(camera, key, value)

    db.commit()
    db.refresh(camera)
    return camera


@router.delete("/cameras/{camera_id}")
def delete_camera(camera_id: int, db: Session = Depends(get_db), director: Director = Depends(get_current_director)):
    camera = db.query(Camera).filter(Camera.id == camera_id, Camera.school_id == director.school_id).first()
    if not camera:
        raise HTTPException(status_code=404, detail="Camera not found")

    from app.models.attendance_model import Attendance
    from app.models.notification_model import NotificationEvent
    attendances = db.query(Attendance).filter(Attendance.camera_id == camera_id).all()
    attendance_ids = [a.id for a in attendances]
    if attendance_ids:
        db.query(NotificationEvent).filter(NotificationEvent.attendance_id.in_(attendance_ids)).delete(synchronize_session=False)
    db.query(Attendance).filter(Attendance.camera_id == camera_id).delete(synchronize_session=False)
    db.delete(camera)
    db.commit()
    return {"message": "Camera deleted"}
