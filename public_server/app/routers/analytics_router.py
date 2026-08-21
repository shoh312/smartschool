from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.database import get_db
from app.deps import PublicAuthActor, get_current_actor, get_owned_student
from app.models.student_analytics_model import StudentAnalytics
from app.schemas.analytics_schema import QuarterPoint, RankInfo, StudentAnalyticsOverview, SubjectAverage

router = APIRouter(prefix="/analytics", tags=["analytics"])


@router.get("/student/{student_id}", response_model=StudentAnalyticsOverview)
def student_analytics(
    student_id: int,
    quarter: int | None = None,
    db: Session = Depends(get_db),
    actor: PublicAuthActor = Depends(get_current_actor),
):
    student = get_owned_student(student_id, db, actor)

    query = db.query(StudentAnalytics).filter(StudentAnalytics.student_id == student_id)
    if quarter is not None:
        query = query.filter(StudentAnalytics.quarter == quarter)
    # Always take the most recently synced matching snapshot, even with a
    # quarter filter applied: (student_id, quarter) alone isn't unique once
    # more than one school year exists (quarter 1 recurs every year) -- the
    # newest row for that quarter number is the one meant by "quarter 1"
    # with no year picker in the UI to disambiguate further.
    analytics = query.order_by(StudentAnalytics.updated_at.desc()).first()

    if not analytics:
        raise HTTPException(status_code=404, detail="No analytics synced yet for this student")

    return StudentAnalyticsOverview(
        student_id=student.id,
        first_name=student.first_name,
        last_name=student.last_name,
        quarter=analytics.quarter,
        school_year=analytics.school_year,
        overall_average=analytics.overall_average,
        class_rank=RankInfo(position=analytics.class_rank_position, out_of=analytics.class_rank_out_of),
        parallel_rank=RankInfo(position=analytics.parallel_rank_position, out_of=analytics.parallel_rank_out_of),
        school_rank=RankInfo(position=analytics.school_rank_position, out_of=analytics.school_rank_out_of),
        class_average=analytics.class_average,
        parallel_average=analytics.parallel_average,
        school_average=analytics.school_average,
        subject_breakdown=[SubjectAverage(**item) for item in (analytics.subject_breakdown or [])],
        strongest_subject=analytics.strongest_subject,
        weakest_subject=analytics.weakest_subject,
        lesson_attendance_rate=analytics.lesson_attendance_rate,
        trend=[QuarterPoint(**item) for item in (analytics.trend or [])],
        updated_at=analytics.updated_at.isoformat() if analytics.updated_at else None,
    )
