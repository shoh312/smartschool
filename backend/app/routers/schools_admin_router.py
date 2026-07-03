from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.database import get_db
from app.deps import get_current_superadmin
from app.models.school_model import School
from app.schemas.schools_admin_schema import SchoolCreate, SchoolResponse

router = APIRouter(
    prefix="/schools",
    tags=["schools-admin"],
    dependencies=[Depends(get_current_superadmin)],
)


@router.get("", response_model=list[SchoolResponse])
def list_schools(db: Session = Depends(get_db)):
    return db.query(School).order_by(School.name.asc()).all()


@router.post("", response_model=SchoolResponse)
def create_school(payload: SchoolCreate, db: Session = Depends(get_db)):
    school = School(
        name=payload.name.strip(),
        address=payload.address,
        phone=payload.phone,
        is_active=True,
    )
    db.add(school)
    db.commit()
    db.refresh(school)
    return school
