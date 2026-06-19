from typing import Optional

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import text
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.orm import Session

from app.database import get_db
from app.openapi_docs import SUCCESS_RESPONSE
from app.schemas import MaintenancePlanAction, MaintenancePlanCreate
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
            SELECT mp.plan_id, mp.status, mp.planned_type, c.component_no
            FROM MaintenancePlan mp
            JOIN Component c ON mp.component_id = c.component_id
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
    summary="查询待执行维修计划",
    description="优先查询视图 v_pending_maintenance_plan，按计划时间返回待执行维修计划。",
    response_model=dict,
    responses=SUCCESS_RESPONSE,
)
def list_maintenance_plans(db: Session = Depends(get_db)):
    try:
        rows = db.execute(
            text(
                """
                SELECT *
                FROM v_pending_maintenance_plan
                ORDER BY planned_time ASC, plan_id ASC
                """
            )
        ).mappings().all()
        return ok([dict(row) for row in rows])
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
    description="仅 pending 计划可完成；更新完成时间并在同一事务内写入 AuditLog。",
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
        db.execute(
            text(
                """
                UPDATE MaintenancePlan
                SET status = 'completed',
                    completed_at = NOW(),
                    related_maintenance_id = COALESCE(
                        :related_maintenance_id,
                        related_maintenance_id
                    )
                WHERE plan_id = :plan_id
                """
            ),
            {
                "plan_id": plan_id,
                "related_maintenance_id": action.related_maintenance_id,
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
