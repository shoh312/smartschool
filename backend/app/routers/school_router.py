import os

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.database import get_db
from app.deps import get_current_director
from app.models.camera_model import Camera
from app.models.camera_position_model import CameraPosition
from app.models.class_model import Class
from app.models.lesson_model import Lesson
from app.models.director_model import Director
from app.models.school_model import School
from app.schemas.school_schema import (
    CameraCreate,
    CameraPositionCreate,
    CameraPositionResponse,
    CameraResponse,
    ClassCreate,
    ClassResponse,
    SchoolSettings,
    SchoolSettingsUpdate,
)
from app.services.camera_position_service import Slot, conflicts_with, normalise_time, valid_time

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
    # "homework" has no ORM model (the feature was removed from the app) but
    # the table -- and its FK to classes -- is still in the database on
    # installations that had it. A fresh database never creates it, so guard
    # with to_regclass the same way database.py does for room_positions.
    if db.execute(text("SELECT to_regclass('public.homework')")).scalar():
        db.execute(text("DELETE FROM homework WHERE class_id = :class_id"), {"class_id": class_id})

    photo_paths = [s.photo for s in students if s.photo]

    db.query(Camera).filter(Camera.class_id == class_id).update({"class_id": None}, synchronize_session=False)
    db.query(Student).filter(Student.class_id == class_id).delete(synchronize_session=False)
    db.delete(school_class)
    db.commit()

    for photo_path in photo_paths:
        if os.path.exists(photo_path):
            os.remove(photo_path)

    return {"message": "Class deleted"}


@router.get("/cameras", response_model=list[CameraResponse])
def list_cameras(db: Session = Depends(get_db), director: Director = Depends(get_current_director)):
    return db.query(Camera).filter(Camera.school_id == director.school_id).order_by(Camera.id.desc()).all()


@router.get("/cameras/status")
def camera_status(db: Session = Depends(get_db), director: Director = Depends(get_current_director)):
    """What each of this school's cameras is doing right now.

    Reports the loop's own view -- connected, recognising, how many seconds
    until the next window -- rather than anything inferred from the data it
    produces. On a morning when nobody has arrived yet those are the same
    empty database and completely different situations: a camera counting
    down, and a camera that never started.
    """
    from app.ai.live_detection import camera_statuses

    cameras = {
        camera.id: camera
        for camera in db.query(Camera).filter(Camera.school_id == director.school_id).all()
    }
    classes = {c.id: c.name for c in db.query(Class).filter(Class.school_id == director.school_id).all()}

    rows = []
    for status in camera_statuses():
        camera = cameras.get(status.get("camera_id"))
        if camera is None:
            continue        # another school's camera; not this director's business
        rows.append({
            **status,
            "camera_name": camera.name,
            # `class_id` in the status is whichever class is in session right
            # now, and is null outside lesson hours. `camera_class_id` is the
            # room the camera is bolted to, which never changes -- a watcher
            # following one class needs that one, or it loses its camera the
            # moment the bell goes and reports it as dead.
            "camera_class_id": camera.class_id,
            "class_name": classes.get(status.get("class_id") or camera.class_id),
        })
    return rows


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


@router.get("/school/settings", response_model=SchoolSettings)
def get_school_settings(db: Session = Depends(get_db), director: Director = Depends(get_current_director)):
    school = db.query(School).filter(School.id == director.school_id).first()
    if not school:
        raise HTTPException(status_code=404, detail="School not found")
    return school


@router.put("/school/settings", response_model=SchoolSettings)
def update_school_settings(
    payload: SchoolSettingsUpdate,
    db: Session = Depends(get_db),
    director: Director = Depends(get_current_director),
):
    """Both switches change what everyone else in the school sees, which is
    why they are the director's and not a per-device preference."""
    school = db.query(School).filter(School.id == director.school_id).first()
    if not school:
        raise HTTPException(status_code=404, detail="School not found")

    if payload.live_video_enabled is not None:
        school.live_video_enabled = payload.live_video_enabled
    if payload.group_mode is not None:
        school.group_mode = payload.group_mode

    db.commit()
    db.refresh(school)
    return school


# Mon-Sat: an academy that works Saturdays is the normal case here, and a
# lesson on a day nobody comes simply never matches anything.
_WORKING_DAYS = (0, 1, 2, 3, 4, 5)


def _sync_lessons_for_position(db: Session, position: CameraPosition) -> None:
    """Writes the lessons a position implies, so the rest of the app keeps
    working in group mode.

    An academy keeps no lesson timetable -- but the diary, the subject
    register and the per-lesson \"absent\" mark all read lessons. Deriving
    them from the position means the director enters the schedule once, on
    the camera, and every one of those features keeps working with no
    special case anywhere.

    A slot with no weekday repeats every day, so it becomes one lesson per
    working day. They are removed with the position (position_id cascades).
    """
    minutes = _minutes_between(position.start_time, position.end_time)
    days = [position.day_of_week] if position.day_of_week is not None else list(_WORKING_DAYS)
    for day in days:
        db.add(Lesson(
            class_id=position.class_id,
            subject=position.subject or "",
            day_of_week=day,
            start_time=position.start_time,
            duration_minutes=minutes,
            position_id=position.id,
        ))


def _minutes_between(start: str, end: str) -> int:
    sh, sm = (int(part) for part in start.split(":"))
    eh, em = (int(part) for part in end.split(":"))
    return max(5, (eh * 60 + em) - (sh * 60 + sm))


def _require_camera(db: Session, camera_id: int, director: Director) -> Camera:
    camera = db.query(Camera).filter(
        Camera.id == camera_id,
        Camera.school_id == director.school_id,
    ).first()
    if not camera:
        raise HTTPException(status_code=404, detail="Camera not found")
    return camera


def _position_rows(db: Session, camera_id: int) -> list[CameraPosition]:
    return db.query(CameraPosition).filter(
        CameraPosition.camera_id == camera_id
    ).order_by(CameraPosition.start_time.asc()).all()


def _as_response(db: Session, row: CameraPosition) -> CameraPositionResponse:
    school_class = db.query(Class).filter(Class.id == row.class_id).first()
    return CameraPositionResponse(
        id=row.id,
        camera_id=row.camera_id,
        class_id=row.class_id,
        class_name=school_class.name if school_class else None,
        subject=row.subject,
        day_of_week=row.day_of_week,
        start_time=row.start_time,
        end_time=row.end_time,
    )


@router.get("/cameras/{camera_id}/positions", response_model=list[CameraPositionResponse])
def list_camera_positions(
    camera_id: int,
    db: Session = Depends(get_db),
    director: Director = Depends(get_current_director),
):
    _require_camera(db, camera_id, director)
    return [_as_response(db, row) for row in _position_rows(db, camera_id)]


@router.post("/cameras/{camera_id}/positions", response_model=CameraPositionResponse)
def create_camera_position(
    camera_id: int,
    payload: CameraPositionCreate,
    db: Session = Depends(get_db),
    director: Director = Depends(get_current_director),
):
    """Adds one slot: from when to when, and whose group.

    Overlaps are refused rather than stored. Two groups in one room at one
    time is not a schedule the camera can act on -- it would load one roster
    and mark the other group absent, every day, with nothing to show why.
    """
    _require_camera(db, camera_id, director)

    school_class = db.query(Class).filter(
        Class.id == payload.class_id,
        Class.school_id == director.school_id,
    ).first()
    if not school_class:
        raise HTTPException(status_code=404, detail="Class not found")

    if not valid_time(payload.start_time) or not valid_time(payload.end_time):
        raise HTTPException(status_code=422, detail="Вақт бояд ба намуди HH:MM бошад")

    start = normalise_time(payload.start_time)
    end = normalise_time(payload.end_time)
    if start >= end:
        raise HTTPException(status_code=422, detail="Вақти анҷом бояд аз оғоз дертар бошад")

    existing = [
        Slot(id=row.id, class_id=row.class_id, start_time=row.start_time,
             end_time=row.end_time, day_of_week=row.day_of_week)
        for row in _position_rows(db, camera_id)
    ]
    clash = conflicts_with(existing, Slot(
        id=None, class_id=payload.class_id, start_time=start,
        end_time=end, day_of_week=payload.day_of_week,
    ))
    if clash is not None:
        raise HTTPException(
            status_code=409,
            detail="Ин вақт бо %s–%s банд аст" % (clash.start_time, clash.end_time),
        )

    row = CameraPosition(
        camera_id=camera_id,
        class_id=payload.class_id,
        subject=(payload.subject or school_class.name).strip(),
        day_of_week=payload.day_of_week,
        start_time=start,
        end_time=end,
    )
    db.add(row)
    db.flush()
    _sync_lessons_for_position(db, row)
    db.commit()
    db.refresh(row)
    return _as_response(db, row)


@router.delete("/cameras/{camera_id}/positions/{position_id}", status_code=204)
def delete_camera_position(
    camera_id: int,
    position_id: int,
    db: Session = Depends(get_db),
    director: Director = Depends(get_current_director),
):
    _require_camera(db, camera_id, director)
    row = db.query(CameraPosition).filter(
        CameraPosition.id == position_id,
        CameraPosition.camera_id == camera_id,
    ).first()
    if not row:
        raise HTTPException(status_code=404, detail="Position not found")
    db.delete(row)
    db.commit()


@router.get("/classes/{class_id}/camera", response_model=CameraResponse)
def camera_for_class(
    class_id: int,
    db: Session = Depends(get_db),
    director: Director = Depends(get_current_director),
):
    """The camera that watches this class, however it is attached.

    A school bolts a camera to a class and that is the answer. An academy
    bolts it to a *room*, and which group is in front of it is a question for
    the timetable -- so a group-mode camera has no class_id at all, and the
    live view found nothing to show for any group. Looking through the
    positions as well is what makes "watch this group" work in both.
    """
    school_class = db.query(Class).filter(
        Class.id == class_id,
        Class.school_id == director.school_id,
    ).first()
    if not school_class:
        raise HTTPException(status_code=404, detail="Class not found")

    direct = db.query(Camera).filter(
        Camera.class_id == class_id,
        Camera.school_id == director.school_id,
        Camera.is_active == True,  # noqa: E712
    ).first()
    if direct:
        return direct

    by_position = (
        db.query(Camera)
        .join(CameraPosition, CameraPosition.camera_id == Camera.id)
        .filter(
            CameraPosition.class_id == class_id,
            Camera.school_id == director.school_id,
            Camera.is_active == True,  # noqa: E712
        )
        .first()
    )
    if not by_position:
        raise HTTPException(status_code=404, detail="No camera for this class")
    return by_position
