from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.parent_model import Parent
from app.models.student_model import Student
from app.models.verification_code_model import VerificationCode
from app.schemas.auth_schema import (
    LoginRequest,
    RequestCodeRequest,
    SetPasswordRequest,
    StudentLoginRequest,
    VerifyCodeRequest,
)
from app.services import verification_service as verification
from app.services.sms_service import code_message, send_sms
from app.utils.phone import normalize_phone
from app.utils.security import (
    create_parent_access_token,
    create_setup_token,
    create_student_access_token,
    verify_setup_token,
    verify_student_password,
)

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/login")
def login(payload: LoginRequest, db: Session = Depends(get_db)):
    normalized = normalize_phone(payload.phone)
    parent = db.query(Parent).filter(Parent.phone == normalized).first()

    if not parent:
        raise HTTPException(status_code=404, detail="phone_not_registered")

    if not parent.password_hash:
        return {"status": "needs_password", "phone": parent.phone}

    if not payload.password or not verification.verify_password(
        payload.password, parent.password_salt, parent.password_hash
    ):
        raise HTTPException(status_code=401, detail="invalid_credentials")

    return {
        "status": "login",
        "access_token": create_parent_access_token(parent.id),
        "parent_id": parent.id,
        "full_name": parent.full_name,
        "phone": parent.phone,
    }


@router.post("/request-code")
def request_code(payload: RequestCodeRequest, db: Session = Depends(get_db)):
    normalized = normalize_phone(payload.phone)
    parent = db.query(Parent).filter(Parent.phone == normalized).first()
    if not parent:
        raise HTTPException(status_code=404, detail="phone_not_registered")

    now = datetime.utcnow()
    recent = (
        db.query(VerificationCode)
        .filter(
            VerificationCode.phone == normalized,
            VerificationCode.created_at >= now - verification.RATE_WINDOW,
        )
        .count()
    )
    if not verification.may_send_code(recent):
        raise HTTPException(status_code=429, detail="too_many_requests")

    code = verification.generate_code()
    salt = verification.new_salt()
    db.add(
        VerificationCode(
            phone=normalized,
            code_salt=salt,
            code_hash=verification.hash_secret(code, salt),
            expires_at=verification.expiry_from(now),
            attempts=0,
        )
    )
    db.commit()

    result = send_sms(normalized, code_message(code))
    return {
        "status": "code_sent",
        "phone_masked": verification.mask_phone(normalized),
        "expires_in_seconds": int(verification.CODE_TTL.total_seconds()),
        "delivered": result.sent,
    }


@router.post("/verify-code")
def verify_code(payload: VerifyCodeRequest, db: Session = Depends(get_db)):
    normalized = normalize_phone(payload.phone)
    parent = db.query(Parent).filter(Parent.phone == normalized).first()
    if not parent:
        raise HTTPException(status_code=404, detail="phone_not_registered")

    record = (
        db.query(VerificationCode)
        .filter(VerificationCode.phone == normalized)
        .order_by(VerificationCode.id.desc())
        .first()
    )
    if not record:
        raise HTTPException(status_code=400, detail="code_not_requested")

    check = verification.check_code(
        payload.code,
        code_salt=record.code_salt,
        code_hash=record.code_hash,
        expires_at=record.expires_at,
        attempts=record.attempts,
        consumed_at=record.consumed_at,
        now=datetime.utcnow(),
    )
    if not check.ok:
        record.attempts += 1
        db.commit()
        raise HTTPException(status_code=400, detail=check.reason)

    record.consumed_at = datetime.utcnow()
    db.commit()

    return {
        "status": "verified",
        "setup_token": create_setup_token(parent.id, verification.SETUP_TOKEN_TTL),
        "full_name": parent.full_name,
    }


@router.post("/set-password")
def set_password(payload: SetPasswordRequest, db: Session = Depends(get_db)):
    parent_id = verify_setup_token(payload.setup_token)
    parent = db.query(Parent).filter(Parent.id == parent_id).first()
    if not parent:
        raise HTTPException(status_code=404, detail="phone_not_registered")

    if len(payload.password) < 4:
        raise HTTPException(status_code=400, detail="password_too_short")

    name = payload.full_name.strip()
    if name:
        parent.full_name = name

    salt, digest = verification.hash_password(payload.password)
    parent.password_salt = salt
    parent.password_hash = digest
    db.commit()

    return {
        "status": "login",
        "access_token": create_parent_access_token(parent.id),
        "parent_id": parent.id,
        "full_name": parent.full_name,
        "phone": parent.phone,
    }


@router.post("/student/login")
def student_login(payload: StudentLoginRequest, db: Session = Depends(get_db)):
    student = db.query(Student).filter(Student.username == payload.username).first()

    invalid = HTTPException(status_code=401, detail="invalid_credentials")
    if not student or not student.password_hash or not student.password_salt:
        raise invalid
    if not verify_student_password(payload.password, student.password_salt, student.password_hash):
        raise invalid
    if not student.is_active:
        raise invalid

    return {
        "status": "login",
        "access_token": create_student_access_token(student.id),
        "student_id": student.id,
        "full_name": f"{student.first_name} {student.last_name}".strip(),
        "class_name": student.class_name,
    }
