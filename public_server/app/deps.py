from dataclasses import dataclass

from fastapi import Depends, Header, HTTPException, status
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.parent_model import Parent
from app.models.school_model import School
from app.models.student_model import Student
from app.utils.security import verify_parent_access_token, verify_school_key, verify_student_access_token


def get_current_parent(
    authorization: str | None = Header(default=None),
    db: Session = Depends(get_db),
) -> Parent:
    if not authorization or not authorization.lower().startswith("bearer "):
        raise HTTPException(status_code=401, detail="Missing bearer token")

    parent_id = verify_parent_access_token(authorization.split(" ", 1)[1])
    parent = db.query(Parent).filter(Parent.id == parent_id).first()
    if not parent:
        raise HTTPException(status_code=401, detail="Parent not found")
    return parent


@dataclass
class PublicAuthActor:
    """A logged-in parent OR the student themself -- whichever the bearer
    token maps to. Unlike the local server's AuthActor, there's no
    multi-school `parent_ids` list here: Public Server's Parent is one
    global row per phone (see parent_model.py), so a single `parent.id`
    comparison is always enough.
    """

    role: str
    parent: Parent | None = None
    student: Student | None = None


def get_current_actor(
    authorization: str | None = Header(default=None),
    db: Session = Depends(get_db),
) -> PublicAuthActor:
    if not authorization or not authorization.lower().startswith("bearer "):
        raise HTTPException(status_code=401, detail="Missing bearer token")
    token = authorization.split(" ", 1)[1]

    try:
        parent_id = verify_parent_access_token(token)
        parent = db.query(Parent).filter(Parent.id == parent_id).first()
        if parent:
            return PublicAuthActor(role="parent", parent=parent)
    except HTTPException:
        pass

    student_id = verify_student_access_token(token)
    student = db.query(Student).filter(Student.id == student_id).first()
    if not student:
        raise HTTPException(status_code=401, detail="Student not found")
    return PublicAuthActor(role="student", student=student)


def student_ids_for_actor(db: Session, actor: PublicAuthActor) -> list[int]:
    """The set of student ids a "list my own data" endpoint (grades,
    attendance history) should scope to: every child for a parent, or just
    themself for a student.
    """
    if actor.role == "student" and actor.student is not None:
        return [actor.student.id]
    if actor.role == "parent" and actor.parent is not None:
        # Matches /students/me: "my children" has to mean the same set
        # everywhere, or a pupil who has left the school disappears from the
        # picker but their rows keep turning up in the lists below it.
        return [
            row[0]
            for row in db.query(Student.id).filter(
                Student.parent_id == actor.parent.id,
                Student.is_active == True,  # noqa: E712
            ).all()
        ]
    return []


def get_owned_student(student_id: int, db: Session, actor: PublicAuthActor) -> Student:
    """The one repeated ownership check every single-student endpoint used
    to duplicate (`if not student or student.parent_id != parent.id: ...`)
    -- now satisfied by either the owning parent or the student themself.
    """
    student = db.query(Student).filter(Student.id == student_id).first()
    if not student:
        raise HTTPException(status_code=404, detail="Student not found")

    owns = (actor.role == "parent" and actor.parent is not None and student.parent_id == actor.parent.id) or (
        actor.role == "student" and actor.student is not None and student.id == actor.student.id
    )
    if not owns:
        raise HTTPException(status_code=403, detail="Not your student")
    return student


def get_current_school(
    x_school_key: str | None = Header(default=None),
    db: Session = Depends(get_db),
) -> School:
    if not x_school_key:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED, detail="Missing X-School-Key"
        )

    # api_key_hash is per-school, so every active school must be checked
    # (there's no lookup-by-key column -- the raw key is never stored).
    for school in db.query(School).filter(School.is_active == True).all():
        if verify_school_key(x_school_key, school.api_key_hash):
            return school

    raise HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid school key"
    )
