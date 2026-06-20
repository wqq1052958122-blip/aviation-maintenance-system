from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import text
from sqlalchemy.orm import Session

from app.database import get_db
from app.openapi_docs import SUCCESS_RESPONSE
from app.utils.responses import ok

from datetime import date
from typing import Literal, Optional
from pydantic import BaseModel
from sqlalchemy.exc import SQLAlchemyError
from app.utils.db_errors import raise_db_error

class AircraftCreate(BaseModel):
    aircraft_no: str
    aircraft_model: str
    start_date: Optional[date] = None

class AircraftStatusUpdate(BaseModel):
    service_status: Literal["active", "maintenance", "retired"]

# 在 AircraftStatusUpdate 下面加上这个：
class OperatorCreate(BaseModel):
    operator_name: str
    role: str
    phone: Optional[str] = None


router = APIRouter(tags=["basic"])




@router.get(
    "/aircrafts",
    summary="查询飞机列表",
    description=(
        "查询 Aircraft 表中的飞机基础信息。"
        "安装部件时需要从这里获取 aircraft_no，例如 AC-1001。"
    ),
    response_model=dict,
    responses=SUCCESS_RESPONSE,
)
def list_aircrafts(db: Session = Depends(get_db)):
    rows = db.execute(text("SELECT * FROM Aircraft ORDER BY aircraft_no")).mappings().all()
    return ok([dict(row) for row in rows])


@router.get(
    "/operators",
    summary="查询操作人员列表",
    description=(
        "查询 Operator 表中的操作人员。"
        "安装、拆卸、维修、审批接口会用到 operator_id。"
    ),
    response_model=dict,
    responses=SUCCESS_RESPONSE,
)
def list_operators(db: Session = Depends(get_db)):
    rows = db.execute(text("SELECT * FROM Operator ORDER BY operator_id")).mappings().all()
    return ok([dict(row) for row in rows])


@router.post(
    "/aircrafts",
    summary="新增飞机",
    description="录入新购买的飞机",
    response_model=dict,
    responses=SUCCESS_RESPONSE,
)
def create_aircraft(payload: AircraftCreate, db: Session = Depends(get_db)):
    try:
        db.execute(
            text("""
                INSERT INTO Aircraft (aircraft_no, aircraft_model, service_status, start_date) 
                VALUES (:aircraft_no, :aircraft_model, 'active', :start_date)
            """),
            payload.model_dump()
        )
        db.commit()
        return ok({"message": "Aircraft created successfully"})
    except SQLAlchemyError as exc:
        raise_db_error(exc, db)

@router.put(
    "/aircrafts/{aircraft_no}/status",
    summary="更新飞机状态",
    description="更改服役状态：active/maintenance/retired",
    response_model=dict,
    responses=SUCCESS_RESPONSE,
)
def update_aircraft_status(aircraft_no: str, payload: AircraftStatusUpdate, db: Session = Depends(get_db)):
    try:
        aircraft_exists = db.execute(
            text("SELECT 1 FROM Aircraft WHERE aircraft_no = :aircraft_no"),
            {"aircraft_no": aircraft_no},
        ).scalar_one_or_none()
        if aircraft_exists is None:
            raise HTTPException(status_code=404, detail="Aircraft does not exist.")

        db.execute(
            text("UPDATE Aircraft SET service_status = :service_status WHERE aircraft_no = :aircraft_no"),
            {"service_status": payload.service_status, "aircraft_no": aircraft_no}
        )
        db.commit()
        return ok({"message": f"Status updated to {payload.service_status}"})
    except SQLAlchemyError as exc:
        raise_db_error(exc, db)

@router.post(
    "/operators",
    summary="新增操作人员",
    description="录入新的工程师、审批员等操作人员",
    response_model=dict,
    responses=SUCCESS_RESPONSE,
)
def create_operator(payload: OperatorCreate, db: Session = Depends(get_db)):
    try:
        db.execute(
            text("""
                INSERT INTO Operator (operator_name, role, phone) 
                VALUES (:operator_name, :role, :phone)
            """),
            payload.model_dump()
        )
        db.commit()
        return ok({"message": "Operator created successfully"})
    except SQLAlchemyError as exc:
        raise_db_error(exc, db)
