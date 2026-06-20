from decimal import Decimal

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import text
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.orm import Session

from app.database import get_db
from app.openapi_docs import SUCCESS_RESPONSE
from app.schemas import FlightCreate
from app.utils.db_errors import raise_db_error
from app.utils.responses import ok

router = APIRouter(tags=["flights"])


def get_aircraft_id(db: Session, aircraft_no: str) -> int:
    row = db.execute(
        text("SELECT aircraft_id, service_status FROM Aircraft WHERE aircraft_no = :aircraft_no"),
        {"aircraft_no": aircraft_no},
    ).mappings().first()
    if row is None:
        raise HTTPException(status_code=400, detail="Aircraft does not exist.")
    if row["service_status"] != "active":
        raise HTTPException(status_code=400, detail="Only active aircraft can record a completed flight.")
    return int(row["aircraft_id"])


@router.post(
    "/flights",
    summary="创建飞行日志",
    description=(
        "插入 FlightLog。前端不要传 flight_hours，后端根据 takeoff_time 和 landing_time "
        "自动计算飞行小时数，保留两位小数。仅 active 飞机可登记已完成飞行，"
        "landing_time 必须晚于 takeoff_time，数据库会拒绝时间重叠的任务。"
    ),
    response_model=dict,
    responses=SUCCESS_RESPONSE,
)
def create_flight(payload: FlightCreate, db: Session = Depends(get_db)):
    if payload.landing_time <= payload.takeoff_time:
        raise HTTPException(status_code=400, detail="landing_time must be later than takeoff_time.")

    minutes = (payload.landing_time - payload.takeoff_time).total_seconds() / 3600
    flight_hours = Decimal(str(round(minutes, 2)))

    params = payload.model_dump()
    params["aircraft_id"] = get_aircraft_id(db, payload.aircraft_no)
    params["flight_hours"] = flight_hours

    try:
        result = db.execute(
            text(
                """
                INSERT INTO FlightLog (
                    aircraft_id, mission_no, takeoff_time, landing_time,
                    flight_hours, mission_type, recorded_by
                )
                VALUES (
                    :aircraft_id, :mission_no, :takeoff_time, :landing_time,
                    :flight_hours, :mission_type, :recorded_by
                )
                """
            ),
            params,
        )
        aircraft_status = db.execute(
            text("SELECT service_status FROM Aircraft WHERE aircraft_id = :aircraft_id"),
            {"aircraft_id": params["aircraft_id"]},
        ).scalar_one()
        db.commit()
        return ok({
            "flight_id": result.lastrowid,
            "flight_hours": flight_hours,
            "aircraft_status": aircraft_status,
        })
    except SQLAlchemyError as exc:
        raise_db_error(exc, db)


@router.get(
    "/flights",
    summary="查询飞行日志",
    description=(
        "查询 FlightLog，并带出 aircraft_no 和记录人名称。新增飞行日志后可测试该接口确认写入成功。"
    ),
    response_model=dict,
    responses=SUCCESS_RESPONSE,
)
def list_flights(db: Session = Depends(get_db)):
    rows = db.execute(
        text(
            """
            SELECT fl.*, a.aircraft_no, o.operator_name AS recorder_name
            FROM FlightLog fl
            JOIN Aircraft a ON fl.aircraft_id = a.aircraft_id
            LEFT JOIN Operator o ON fl.recorded_by = o.operator_id
            ORDER BY fl.takeoff_time DESC, fl.flight_id DESC
            """
        )
    ).mappings().all()
    return ok([dict(row) for row in rows])
