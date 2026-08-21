from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from app.database import get_db
from app.deps import AuthActor, get_current_actor
from app.models.class_model import Class
from app.models.student import Student
from app.schemas.analytics_schema import (
    ClassSubjectAverage,
    LeaderboardEntry,
    NeedsAttentionResponse,
    StudentAnalyticsOverview,
)
from app.services import analytics_service
from app.utils.academic_calendar import current_quarter, current_school_year

router = APIRouter(prefix="/analytics", tags=["analytics"])

# No UI anywhere lets a caller pick a school year -- every request implicitly
# means "the current one". Once the app grows a year picker, thread an
# explicit school_year query param through these endpoints the same way
# quarter already is, instead of hardcoding current_school_year() here.
QuarterParam = Query(default=None, ge=1, le=4)


def _require_director_or_teacher(actor: AuthActor) -> None:
    if actor.role not in ("director", "teacher"):
        raise HTTPException(status_code=403, detail="Director or teacher access required")


def _actor_school_id(actor: AuthActor) -> int | None:
    return actor.director.school_id if actor.role == "director" else actor.teacher.school_id


def _student_overview(db: Session, student: Student, quarter: int, school_year: int) -> StudentAnalyticsOverview:
    return StudentAnalyticsOverview(**analytics_service.build_student_overview(db, student, quarter, school_year))


@router.get("/student/{student_id}", response_model=StudentAnalyticsOverview)
def student_analytics(
    student_id: int,
    quarter: int | None = QuarterParam,
    db: Session = Depends(get_db),
    actor: AuthActor = Depends(get_current_actor),
):
    student = db.query(Student).filter(Student.id == student_id).first()
    if not student:
        raise HTTPException(status_code=404, detail="Student not found")

    if actor.role == "parent":
        if student.parent_id not in actor.parent_ids:
            raise HTTPException(status_code=403, detail="Not your student")
    else:
        if student.school_id != _actor_school_id(actor):
            raise HTTPException(status_code=404, detail="Student not found")

    return _student_overview(db, student, quarter or current_quarter(), current_school_year())


@router.get("/class/{class_id}/ranking", response_model=list[LeaderboardEntry])
def class_ranking(
    class_id: int,
    quarter: int | None = QuarterParam,
    db: Session = Depends(get_db),
    actor: AuthActor = Depends(get_current_actor),
):
    _require_director_or_teacher(actor)
    school_class = db.query(Class).filter(Class.id == class_id).first()
    if not school_class or school_class.school_id != _actor_school_id(actor):
        raise HTTPException(status_code=404, detail="Class not found")

    student_ids = analytics_service.class_student_ids(db, class_id)
    return analytics_service.leaderboard(db, student_ids, quarter or current_quarter(), current_school_year())


@router.get("/class/{class_id}/subjects", response_model=list[ClassSubjectAverage])
def class_subject_breakdown(
    class_id: int,
    quarter: int | None = QuarterParam,
    db: Session = Depends(get_db),
    actor: AuthActor = Depends(get_current_actor),
):
    """Which subjects this class is strong and weak in.

    Staff only, and scoped to the caller's own school like every other
    class-level endpoint here -- a class id from another school reads as
    404, not 403, so the endpoint can't be used to probe what exists.
    """
    _require_director_or_teacher(actor)
    school_class = db.query(Class).filter(Class.id == class_id).first()
    if not school_class or school_class.school_id != _actor_school_id(actor):
        raise HTTPException(status_code=404, detail="Class not found")

    student_ids = analytics_service.class_student_ids(db, class_id)
    return analytics_service.class_subject_averages(
        db, student_ids, quarter or current_quarter(), current_school_year()
    )


@router.get("/parallel/{grade}/ranking", response_model=list[LeaderboardEntry])
def parallel_ranking(
    grade: int,
    quarter: int | None = QuarterParam,
    db: Session = Depends(get_db),
    actor: AuthActor = Depends(get_current_actor),
):
    _require_director_or_teacher(actor)
    student_ids = analytics_service.parallel_student_ids(db, _actor_school_id(actor), grade)
    return analytics_service.leaderboard(db, student_ids, quarter or current_quarter(), current_school_year())


@router.get("/school/ranking", response_model=list[LeaderboardEntry])
def school_ranking(
    quarter: int | None = QuarterParam,
    db: Session = Depends(get_db),
    actor: AuthActor = Depends(get_current_actor),
):
    _require_director_or_teacher(actor)
    student_ids = analytics_service.school_student_ids(db, _actor_school_id(actor))
    return analytics_service.leaderboard(db, student_ids, quarter or current_quarter(), current_school_year())


def _needs_attention(db: Session, student_ids: list[int], quarter: int, school_year: int) -> NeedsAttentionResponse:
    return NeedsAttentionResponse(
        bottom_performers=analytics_service.bottom_performers(db, student_ids, quarter, school_year),
        biggest_decliners=analytics_service.biggest_decliners(db, student_ids, quarter, school_year),
    )


@router.get("/class/{class_id}/needs-attention", response_model=NeedsAttentionResponse)
def class_needs_attention(
    class_id: int,
    quarter: int | None = QuarterParam,
    db: Session = Depends(get_db),
    actor: AuthActor = Depends(get_current_actor),
):
    _require_director_or_teacher(actor)
    school_class = db.query(Class).filter(Class.id == class_id).first()
    if not school_class or school_class.school_id != _actor_school_id(actor):
        raise HTTPException(status_code=404, detail="Class not found")

    student_ids = analytics_service.class_student_ids(db, class_id)
    return _needs_attention(db, student_ids, quarter or current_quarter(), current_school_year())


@router.get("/school/needs-attention", response_model=NeedsAttentionResponse)
def school_needs_attention(
    quarter: int | None = QuarterParam,
    db: Session = Depends(get_db),
    actor: AuthActor = Depends(get_current_actor),
):
    _require_director_or_teacher(actor)
    student_ids = analytics_service.school_student_ids(db, _actor_school_id(actor))
    return _needs_attention(db, student_ids, quarter or current_quarter(), current_school_year())
