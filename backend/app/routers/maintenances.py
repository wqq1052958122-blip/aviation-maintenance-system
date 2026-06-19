from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import text
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.orm import Session

from app.database import get_db
from app.openapi_docs import SUCCESS_RESPONSE
from app.schemas import MaintenanceComplete, MaintenanceCreate
from app.utils.db_errors import raise_db_error
from app.utils.responses import ok

router = APIRouter(tags=["maintenances"])


def get_component_id(db: Session, component_no: str) -> int:
    value = db.execute(
        text("SELECT component_id FROM Component WHERE component_no = :component_no"),
        {"component_no": component_no},
    ).scalar_one_or_none()
    if value is None:
        raise HTTPException(status_code=400, detail="Component does not exist.")
    return int(value)


@router.post(
    "/maintenances",
    summary="创建维修记录",
    description=(
        "创建 MaintenanceRecord。后端默认 result='pending'、end_time=NULL。"
        "数据库会拦截退役部件维修和重复未完成维修。"
    ),
    response_model=dict,
    responses=SUCCESS_RESPONSE,
)
def create_maintenance(payload: MaintenanceCreate, db: Session = Depends(get_db)):
    params = payload.model_dump()
    params["component_id"] = get_component_id(db, payload.component_no)
    try:
        result = db.execute(
            text(
                """
                INSERT INTO MaintenanceRecord (
                    component_id, maintenance_type, start_time, end_time,
                    result, description, technician_id
                )
                VALUES (
                    :component_id, :maintenance_type, :start_time, NULL,
                    'pending', :description, :technician_id
                )
                """
            ),
            params,
        )
        db.commit()
        return ok({"maintenance_id": result.lastrowid, "result": "pending"})
    except SQLAlchemyError as exc:
        raise_db_error(exc, db)


@router.post(
    "/maintenances/{maintenance_id}/complete",
    summary="完成维修",
    description=(
        "调用存储过程 sp_complete_maintenance 完成维修。result 可为 passed、failed、scrapped。"
        "passed 会将部件变为 available，failed 会变为 removed，scrapped 会写入退役记录。"
    ),
    response_model=dict,
    responses=SUCCESS_RESPONSE,
)
def complete_maintenance(
    maintenance_id: int,
    payload: MaintenanceComplete,
    db: Session = Depends(get_db),
):
    params = payload.model_dump()
    params["maintenance_id"] = maintenance_id
    try:
        db.execute(
            text(
                """
                CALL sp_complete_maintenance(
                    :maintenance_id,
                    :end_time,
                    :result,
                    :description,
                    :approved_by,
                    :retirement_reason
                )
                """
            ),
            params,
        )
        db.commit()
        return ok({"maintenance_id": maintenance_id, "result": payload.result})
    except SQLAlchemyError as exc:
        raise_db_error(exc, db)


@router.get(
    "/components/{component_no}/maintenances",
    summary="查询部件维修记录",
    description=(
        "按 component_no 查询某个部件的维修历史，按开始时间倒序返回。"
        "创建维修和完成维修后可再次测试该接口确认变化。"
    ),
    response_model=dict,
    responses=SUCCESS_RESPONSE,
)
def list_component_maintenances(component_no: str, db: Session = Depends(get_db)):
    component_id = get_component_id(db, component_no)
    rows = db.execute(
        text(
            """
            SELECT mr.*, o.operator_name AS technician_name
            FROM MaintenanceRecord mr
            LEFT JOIN Operator o ON mr.technician_id = o.operator_id
            WHERE mr.component_id = :component_id
            ORDER BY mr.start_time DESC, mr.maintenance_id DESC
            """
        ),
        {"component_id": component_id},
    ).mappings().all()
    return ok([dict(row) for row in rows])

@router.get(
    "/maintenances",
    summary="查询所有维修记录",
    description="用于维修大盘页面一打开时展示全部工单数据",
    response_model=dict,
    responses=SUCCESS_RESPONSE,
)
def list_all_maintenances(db: Session = Depends(get_db)):
    try:
        # 注意：这里我们 JOIN 了 Component 表，为了把部件编号也显示在列表中
        rows = db.execute(
            text("""
                SELECT mr.*, c.component_no, o.operator_name AS technician_name
                FROM MaintenanceRecord mr
                JOIN Component c ON mr.component_id = c.component_id
                LEFT JOIN Operator o ON mr.technician_id = o.operator_id
                ORDER BY mr.start_time DESC, mr.maintenance_id DESC
            """)
        ).mappings().all()
        return ok([dict(row) for row in rows])
    except SQLAlchemyError as exc:
        raise_db_error(exc, db)