
from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile
from sqlalchemy.orm import Session, selectinload

from app.database import get_db
from app.deps import AuthActor, get_current_actor, get_current_teacher
from app.models.journal_model import Grade
from app.models.material_model import (
    MODE_CONTROL,
    Material,
    MaterialAssignment,
    MaterialAttempt,
)
from app.models.student import Student
from app.models.teacher_model import Teacher
from app.schemas.material_schema import (
    AiGenerateResponse,
    AssignmentCreate,
    AssignmentOut,
    AssignmentResultsOut,
    GradeTransferRequest,
    MaterialCreate,
    MaterialOut,
    MaterialSummaryOut,
    MaterialUpdate,
    PasteImportRequest,
    PasteImportResponse,
)
from app.services import analytics_service, material_service
from app.services.material_ai_service import MaterialAiError, generate_material
from app.services.material_grading import PasteImportError, parse_pasted_blocks
from app.services.sync_outbox_service import (
    enqueue_grade_event,
    enqueue_material_assignment_event,
    enqueue_material_event,
    enqueue_student_analytics_event,
)
from app.utils.academic_calendar import current_quarter, quarter_for_date, school_year_for_date

router = APIRouter(tags=["materials"])

SCHOOL_TZ = timezone(timedelta(hours=5))


def _school_today():
    return datetime.now(SCHOOL_TZ).date()


def _resolve_subject(teacher: Teacher, requested: str | None) -> str:
    subject = (requested or teacher.subject or "").strip()
    if not subject:
        raise HTTPException(
            status_code=400,
            detail="No subject set on your account -- pass one explicitly",
        )
    return subject


@router.get("/materials", response_model=list[MaterialSummaryOut])
def list_materials(
    scope: str = "mine",
    db: Session = Depends(get_db),
    actor: AuthActor = Depends(get_current_actor),
):
    school_id = material_service.actor_school_id(actor)
    query = (
        db.query(Material)
        .options(selectinload(Material.blocks))
        .filter(Material.school_id == school_id)
    )
    if scope != "school" and actor.role == "teacher":
        query = query.filter(Material.teacher_id == actor.teacher.id)

    materials = query.order_by(
        Material.updated_at.desc().nullslast(), Material.id.desc()
    ).all()
    return [material_service.material_summary_out(db, m) for m in materials]


@router.post("/materials", response_model=MaterialOut)
def create_material(
    payload: MaterialCreate,
    db: Session = Depends(get_db),
    teacher: Teacher = Depends(get_current_teacher),
):
    material = Material(
        school_id=teacher.school_id,
        teacher_id=teacher.id,
        subject=_resolve_subject(teacher, payload.subject),
        title=payload.title.strip(),
        description=payload.description,
    )
    db.add(material)
    db.flush()
    material_service.replace_blocks(db, material, payload.blocks)
    db.commit()
    db.refresh(material)
    return material_service.material_out(db, material)


@router.get("/materials/{material_id}", response_model=MaterialOut)
def get_material(
    material_id: int,
    db: Session = Depends(get_db),
    actor: AuthActor = Depends(get_current_actor),
):
    material = material_service.get_readable_material(
        db, material_id, material_service.actor_school_id(actor)
    )
    return material_service.material_out(db, material)


@router.patch("/materials/{material_id}", response_model=MaterialOut)
def update_material(
    material_id: int,
    payload: MaterialUpdate,
    db: Session = Depends(get_db),
    teacher: Teacher = Depends(get_current_teacher),
):
    material = material_service.get_owned_material(db, material_id, teacher)

    if payload.title is not None:
        material.title = payload.title.strip()
    if payload.description is not None:
        material.description = payload.description
    if payload.blocks is not None:
        published = (
            db.query(MaterialAssignment)
            .filter(
                MaterialAssignment.material_id == material.id,
                MaterialAssignment.published_at.isnot(None),
            )
            .count()
        )
        if published:
            raise HTTPException(
                status_code=409,
                detail="This material has already been handed out -- make a copy to change the questions",
            )
        material_service.replace_blocks(db, material, payload.blocks)

    db.commit()
    db.refresh(material)
    _sync_material(db, material)
    return material_service.material_out(db, material)


@router.delete("/materials/{material_id}", status_code=204)
def delete_material(
    material_id: int,
    db: Session = Depends(get_db),
    teacher: Teacher = Depends(get_current_teacher),
):
    material = material_service.get_owned_material(db, material_id, teacher)
    db.delete(material)
    db.commit()
    return None


@router.post("/materials/{material_id}/duplicate", response_model=MaterialOut)
def duplicate_material(
    material_id: int,
    db: Session = Depends(get_db),
    teacher: Teacher = Depends(get_current_teacher),
):
    source = material_service.get_readable_material(db, material_id, teacher.school_id)
    copy = Material(
        school_id=source.school_id,
        teacher_id=teacher.id,
        subject=teacher.subject or source.subject,
        title=f"{source.title} (nusxa)",
        description=source.description,
    )
    db.add(copy)
    db.flush()
    for block in sorted(source.blocks, key=lambda b: b.position):
        db.add(
            type(block)(
                material_id=copy.id,
                position=block.position,
                block_type=block.block_type,
                body=block.body,
                question_type=block.question_type,
                options=block.options,
                correct=block.correct,
                points=block.points,
            )
        )
    db.commit()
    db.refresh(copy)
    return material_service.material_out(db, copy)


@router.post("/materials/ai/generate", response_model=AiGenerateResponse)
async def ai_generate_material(
    kind: str = Form("lesson"),
    topic: str | None = Form(None),
    source_text: str | None = Form(None),
    class_name: str | None = Form(None),
    question_count: int = Form(8),
    page_count: int = Form(3),
    question_types: str = Form("single"),
    difficulty: str = Form("medium"),
    language: str = Form("tojik (kirill)"),
    file: UploadFile | None = File(None),
    teacher: Teacher = Depends(get_current_teacher),
):
    image_bytes = await file.read() if file is not None else None
    if image_bytes is not None and not image_bytes:
        image_bytes = None

    # generate_material calls Gemini over a blocking HTTP client with sleeps
    # between retries. Running it inline would freeze the event loop for tens
    # of seconds -- long enough for the relay websocket to miss its pings and
    # drop the school offline. Off it goes to a worker thread instead.
    import functools
    import anyio

    work = functools.partial(
        generate_material,
        subject=_resolve_subject(teacher, None),
        kind=kind,
        topic=topic,
        source_text=source_text,
        image_bytes=image_bytes,
        image_mime=file.content_type if file is not None else None,
        class_name=class_name,
        question_count=question_count,
        page_count=page_count,
        question_types=[t.strip() for t in question_types.split(",") if t.strip()],
        difficulty=difficulty,
        language=language,
    )
    try:
        result = await anyio.to_thread.run_sync(work)
    except MaterialAiError as exc:
        raise HTTPException(status_code=502, detail=str(exc))

    return AiGenerateResponse(**result)


@router.post("/materials/parse-paste", response_model=PasteImportResponse)
def parse_paste(
    payload: PasteImportRequest,
    _teacher: Teacher = Depends(get_current_teacher),
):
    try:
        return PasteImportResponse(blocks=parse_pasted_blocks(payload.text))
    except PasteImportError as exc:
        raise HTTPException(status_code=400, detail=str(exc))


@router.get("/material-assignments", response_model=list[AssignmentOut])
def list_assignments(
    class_id: int | None = None,
    material_id: int | None = None,
    db: Session = Depends(get_db),
    actor: AuthActor = Depends(get_current_actor),
):
    school_id = material_service.actor_school_id(actor)
    query = (
        db.query(MaterialAssignment)
        .options(selectinload(MaterialAssignment.material).selectinload(Material.blocks))
        .join(Material, Material.id == MaterialAssignment.material_id)
        .filter(Material.school_id == school_id)
    )
    if actor.role == "teacher":
        query = query.filter(MaterialAssignment.teacher_id == actor.teacher.id)
    if class_id is not None:
        query = query.filter(MaterialAssignment.class_id == class_id)
    if material_id is not None:
        query = query.filter(MaterialAssignment.material_id == material_id)
    assignments = query.order_by(MaterialAssignment.id.desc()).all()
    return [material_service.assignment_out(db, a) for a in assignments]


@router.post("/material-assignments", response_model=list[AssignmentOut])
def create_assignments(
    payload: AssignmentCreate,
    db: Session = Depends(get_db),
    teacher: Teacher = Depends(get_current_teacher),
):
    material = material_service.get_owned_material(db, payload.material_id, teacher)
    if material.question_count == 0 and not material.blocks:
        raise HTTPException(status_code=400, detail="This material is empty")

    if payload.mode == MODE_CONTROL and payload.due_at is None:
        raise HTTPException(
            status_code=400,
            detail="A control assignment needs a deadline",
        )

    now = datetime.utcnow()
    results: list[MaterialAssignment] = []
    for class_id in dict.fromkeys(payload.class_ids):
        material_service.require_teaches_class(db, teacher, class_id, material.subject)
        assignment = (
            db.query(MaterialAssignment)
            .filter(
                MaterialAssignment.material_id == material.id,
                MaterialAssignment.class_id == class_id,
            )
            .first()
        )
        if assignment is None:
            assignment = MaterialAssignment(
                material_id=material.id,
                class_id=class_id,
                teacher_id=teacher.id,
            )
            db.add(assignment)
        assignment.mode = payload.mode
        assignment.due_at = payload.due_at
        assignment.max_attempts = payload.max_attempts
        assignment.published_at = assignment.published_at or now
        results.append(assignment)

    db.commit()
    for assignment in results:
        db.refresh(assignment)
    _sync_material(db, material)
    for assignment in results:
        enqueue_material_assignment_event(db, assignment, operation="upsert")
    db.commit()
    return [material_service.assignment_out(db, a) for a in results]


@router.patch("/material-assignments/{assignment_id}", response_model=AssignmentOut)
def update_assignment(
    assignment_id: int,
    payload: AssignmentCreate,
    db: Session = Depends(get_db),
    teacher: Teacher = Depends(get_current_teacher),
):
    assignment = material_service.get_owned_assignment(db, assignment_id, teacher)
    if payload.mode == MODE_CONTROL and payload.due_at is None:
        raise HTTPException(status_code=400, detail="A control assignment needs a deadline")
    assignment.mode = payload.mode
    assignment.due_at = payload.due_at
    assignment.max_attempts = payload.max_attempts
    db.commit()
    db.refresh(assignment)
    enqueue_material_assignment_event(db, assignment, operation="upsert")
    db.commit()
    return material_service.assignment_out(db, assignment)


@router.delete("/material-assignments/{assignment_id}", status_code=204)
def delete_assignment(
    assignment_id: int,
    db: Session = Depends(get_db),
    teacher: Teacher = Depends(get_current_teacher),
):
    assignment = material_service.get_owned_assignment(db, assignment_id, teacher)
    enqueue_material_assignment_event(db, assignment, operation="delete")
    db.delete(assignment)
    db.commit()
    return None


@router.get("/material-assignments/{assignment_id}/results", response_model=AssignmentResultsOut)
def assignment_results(
    assignment_id: int,
    db: Session = Depends(get_db),
    actor: AuthActor = Depends(get_current_actor),
):
    assignment = material_service.get_visible_assignment(db, assignment_id, actor)
    summary, rows = material_service.assignment_results(db, assignment)
    return AssignmentResultsOut(
        assignment=summary,
        results_visible=summary.results_visible,
        rows=rows,
    )


@router.post("/material-assignments/{assignment_id}/transfer-grades", response_model=AssignmentResultsOut)
def transfer_grades(
    assignment_id: int,
    payload: GradeTransferRequest,
    db: Session = Depends(get_db),
    teacher: Teacher = Depends(get_current_teacher),
):
    assignment = material_service.get_owned_assignment(db, assignment_id, teacher)
    material = assignment.material

    summary, _rows = material_service.assignment_results(db, assignment)
    if not summary.results_visible:
        raise HTTPException(
            status_code=409,
            detail="Results are still hidden -- wait for the deadline or for everyone to submit",
        )
    if assignment.mode != MODE_CONTROL:
        raise HTTPException(
            status_code=400,
            detail="Practice work is not graded",
        )
    material_service.require_teaches_class(db, teacher, assignment.class_id, material.subject)

    today = assignment.published_at.date() if assignment.published_at else _school_today()
    quarter = quarter_for_date(today)
    school_year = school_year_for_date(today)

    attempts = {
        attempt.student_id: attempt
        for attempt in db.query(MaterialAttempt)
        .filter(
            MaterialAttempt.assignment_id == assignment.id,
            MaterialAttempt.submitted_at.isnot(None),
        )
        .all()
    }

    touched: list[tuple[int, int, int | None]] = []
    for item in payload.items:
        student = (
            db.query(Student)
            .filter(Student.id == item.student_id, Student.class_id == assignment.class_id)
            .first()
        )
        if not student:
            raise HTTPException(
                status_code=404,
                detail=f"Student {item.student_id} is not in this class",
            )
        attempt = attempts.get(student.id)
        if attempt is not None and attempt.transferred:
            continue

        grade = Grade(
            student_id=student.id,
            class_id=assignment.class_id,
            teacher_id=teacher.id,
            subject=material.subject,
            quarter=quarter,
            school_year=school_year,
            value=item.value,
            comment=material.title,
            grade_date=today,
        )
        db.add(grade)
        db.flush()
        enqueue_grade_event(db, grade, operation="upsert")
        if attempt is not None:
            attempt.transferred = True
        touched.append((student.id, quarter, school_year))

    assignment.grades_transferred_at = datetime.utcnow()
    db.commit()

    for student_id, quarter_no, year in touched:
        student = db.query(Student).filter(Student.id == student_id).first()
        if student:
            overview = analytics_service.build_student_overview(db, student, quarter_no, year)
            enqueue_student_analytics_event(db, student, overview)
    db.commit()

    summary, rows = material_service.assignment_results(db, assignment)
    return AssignmentResultsOut(
        assignment=summary,
        results_visible=summary.results_visible,
        rows=rows,
    )


def _sync_material(db: Session, material: Material) -> None:
    enqueue_material_event(db, material, operation="upsert")
    db.commit()
