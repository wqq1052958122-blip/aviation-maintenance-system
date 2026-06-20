from typing import Optional

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import text
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.orm import Session

from app.database import get_db
from app.openapi_docs import SUCCESS_RESPONSE
from app.schemas import MaintenancePlanAction, MaintenancePlanCreate, MaintenancePlanStart
from app.utils.db_errors import raise_db_error
from app.utils.responses import ok


router = APIRouter(tags=["maintenance-plans"])


def get_component_id(db: Session, component_no: str) -> int:
    component_id = db.execute(
        text("SELECT component_id FROM Component WHERE component_no = :component_no"),
        {"component_no": component_no},
    ).scalar_one_or_none()
    if component_id is None:
        raise HTTPException(status_code=404, detail="Component does not exist.")
    return int(component_id)


def lock_pending_plan(db: Session, plan_id: int):
    plan = db.execute(
        text(
            """
            SELECT
                mp.plan_id,
                mp.status,
                mp.planned_type,
                mp.related_maintenance_id,
                mr.result AS related_maintenance_result,
                c.component_no
            FROM MaintenancePlan mp
            JOIN Component c ON mp.component_id = c.component_id
            LEFT JOIN MaintenanceRecord mr
                ON mp.related_maintenance_id = mr.maintenance_id
            WHERE mp.plan_id = :plan_id
            FOR UPDATE
            """
        ),
        {"plan_id": plan_id},
    ).mappings().first()
    if plan is None:
        raise HTTPException(status_code=404, detail="Maintenance plan does not exist.")
    if plan["status"] != "pending":
        raise HTTPException(
            status_code=400,
            detail=(
                "Only pending maintenance plans can be changed. "
                f"Current status: {plan['status']}."
            ),
        )
    return plan


@router.get(
    "/maintenance-plans",
    summary="查询维修计划",
    description="查询视图 v_maintenance_plan_detail，返回待执行、已完成和已取消的全部维修计划。",
    response_model=dict,
    responses=SUCCESS_RESPONSE,
)
def list_maintenance_plans(db: Session = Depends(get_db)):
    try:
        rows = db.execute(
            text(
                """
                SELECT *
                FROM v_maintenance_plan_detail
                ORDER BY
                    CASE status WHEN 'pending' THEN 0 ELSE 1 END,
                    planned_time DESC,
                    plan_id DESC
                """
            )
        ).mappings().all()
        return ok([dict(row) for row in rows])
    except SQLAlchemyError as exc:
        raise_db_error(exc, db)


@router.post(
    "/maintenance-plans/{plan_id}/start",
    summary="开始执行维修计划",
    description=(
        "调用 sp_start_maintenance_plan，在同一事务中锁定计划、创建 pending 维修工单、"
        "关联 related_maintenance_id 并写入 AuditLog。"
    ),
    response_model=dict,
    responses=SUCCESS_RESPONSE,
)
def start_maintenance_plan(
    plan_id: int,
    payload: MaintenancePlanStart,
    db: Session = Depends(get_db),
):
    try:
        db.execute(
            text(
                """
                CALL sp_start_maintenance_plan(
                    :plan_id,
                    :start_time,
                    :technician_id,
                    :description
                )
                """
            ),
            {"plan_id": plan_id, **payload.model_dump()},
        )
        db.commit()
        maintenance_id = db.execute(
            text(
                """
                SELECT related_maintenance_id
                FROM MaintenancePlan
                WHERE plan_id = :plan_id
                """
            ),
            {"plan_id": plan_id},
        ).scalar_one()
        return ok(
            {
                "plan_id": plan_id,
                "status": "pending",
                "execution_status": "in_progress",
                "maintenance_id": int(maintenance_id),
            }
        )
    except SQLAlchemyError as exc:
        raise_db_error(exc, db)


@router.post(
    "/maintenance-plans",
    summary="创建维修计划",
    description="创建 pending 状态的 MaintenancePlan，并在同一事务内写入 AuditLog。",
    response_model=dict,
    responses=SUCCESS_RESPONSE,
)
def create_maintenance_plan(
    payload: MaintenancePlanCreate,
    db: Session = Depends(get_db),
):
    if payload.related_maintenance_id is not None:
        raise HTTPException(
            status_code=400,
            detail="Create the plan first, then use the start endpoint to create its maintenance record.",
        )
    component_id = get_component_id(db, payload.component_no)
    params = payload.model_dump()
    params["component_id"] = component_id
    try:
        result = db.execute(
            text(
                """
                INSERT INTO MaintenancePlan (
                    component_id, planned_type, planned_time, planned_reason,
                    status, created_by, related_maintenance_id
                )
                VALUES (
                    :component_id, :planned_type, :planned_time, :planned_reason,
                    'pending', :created_by, :related_maintenance_id
                )
                """
            ),
            params,
        )
        plan_id = int(result.lastrowid)
        db.execute(
            text(
                """
                INSERT INTO AuditLog (
                    operator_id, operation_type, target_table, target_id,
                    operation_time, operation_detail
                )
                VALUES (
                    :created_by, 'maintenance_plan_created', 'MaintenancePlan',
                    :plan_id, NOW(),
                    CONCAT('Created maintenance plan for component ', :component_no,
                           '; type: ', :planned_type)
                )
                """
            ),
            {**params, "plan_id": plan_id},
        )
        db.commit()
        return ok({"plan_id": plan_id, "status": "pending"})
    except SQLAlchemyError as exc:
        raise_db_error(exc, db)


@router.post(
    "/maintenance-plans/{plan_id}/complete",
    summary="完成维修计划",
    description="兼容入口：仅关联工单已经结束的 pending 计划可完成。正常流程由维修完成事务自动完成计划。",
    response_model=dict,
    responses=SUCCESS_RESPONSE,
)
def complete_maintenance_plan(
    plan_id: int,
    payload: Optional[MaintenancePlanAction] = None,
    db: Session = Depends(get_db),
):
    action = payload or MaintenancePlanAction()
    try:
        plan = lock_pending_plan(db, plan_id)
        if plan["related_maintenance_id"] is None:
            raise HTTPException(
                status_code=400,
                detail="Maintenance plan must be started before it can be completed.",
            )
        if plan["related_maintenance_result"] == "pending":
            raise HTTPException(
                status_code=400,
                detail="Related maintenance record must be completed first.",
            )
        db.execute(
            text(
                """
                UPDATE MaintenancePlan
                SET status = 'completed',
                    completed_at = NOW()
                WHERE plan_id = :plan_id
                """
            ),
            {
                "plan_id": plan_id,
            },
        )
        db.execute(
            text(
                """
                INSERT INTO AuditLog (
                    operator_id, operation_type, target_table, target_id,
                    operation_time, operation_detail
                )
                VALUES (
                    :operator_id, 'maintenance_plan_completed', 'MaintenancePlan',
                    :plan_id, NOW(),
                    CONCAT('Completed maintenance plan for component ', :component_no,
                           '; type: ', :planned_type)
                )
                """
            ),
            {
                "operator_id": action.operator_id,
                "plan_id": plan_id,
                "component_no": plan["component_no"],
                "planned_type": plan["planned_type"],
            },
        )
        db.commit()
        return ok({"plan_id": plan_id, "status": "completed"})
    except SQLAlchemyError as exc:
        raise_db_error(exc, db)


@router.post(
    "/maintenance-plans/{plan_id}/cancel",
    summary="取消维修计划",
    description="仅 pending 计划可取消；更新取消时间并在同一事务内写入 AuditLog。",
    response_model=dict,
    responses=SUCCESS_RESPONSE,
)
def cancel_maintenance_plan(
    plan_id: int,
    payload: Optional[MaintenancePlanAction] = None,
    db: Session = Depends(get_db),
):
    action = payload or MaintenancePlanAction()
    try:
        plan = lock_pending_plan(db, plan_id)
        if plan["related_maintenance_id"] is not None:
            raise HTTPException(
                status_code=400,
                detail="Started maintenance plan cannot be cancelled.",
            )
        db.execute(
            text(
                """
                UPDATE MaintenancePlan
                SET status = 'cancelled', completed_at = NOW()
                WHERE plan_id = :plan_id
                """
            ),
            {"plan_id": plan_id},
        )
        db.execute(
            text(
                """
                INSERT INTO AuditLog (
                    operator_id, operation_type, target_table, target_id,
                    operation_time, operation_detail
                )
                VALUES (
                    :operator_id, 'maintenance_plan_cancelled', 'MaintenancePlan',
                    :plan_id, NOW(),
                    CONCAT('Cancelled maintenance plan for component ', :component_no,
                           '; type: ', :planned_type)
                )
                """
            ),
            {
                "operator_id": action.operator_id,
                "plan_id": plan_id,
                "component_no": plan["component_no"],
                "planned_type": plan["planned_type"],
            },
        )
        db.commit()
        return ok({"plan_id": plan_id, "status": "cancelled"})
    except SQLAlchemyError as exc:
        raise_db_error(exc, db)
