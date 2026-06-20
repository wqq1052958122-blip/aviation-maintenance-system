from fastapi import APIRouter, Depends
from sqlalchemy import text
from sqlalchemy.orm import Session

from app.database import get_db
from app.openapi_docs import SUCCESS_RESPONSE
from app.utils.responses import ok

from sqlalchemy.exc import SQLAlchemyError
from app.utils.db_errors import raise_db_error


router = APIRouter(tags=["stats"])


@router.get(
    "/stats/model-maintenance",
    summary="查询型号维修统计",
    description=(
        "查询视图 v_model_maintenance_stats，返回每个部件型号的部件数量、维修次数、"
        "平均维修小时数。"
    ),
    response_model=dict,
    responses=SUCCESS_RESPONSE,
)
def model_maintenance_stats(db: Session = Depends(get_db)):
    rows = db.execute(
        text("SELECT * FROM v_model_maintenance_stats ORDER BY maintenance_count DESC")
    ).mappings().all()
    return ok([dict(row) for row in rows])


@router.get(
    "/stats/summary",
    summary="获取仪表盘顶部统计面板数据",
    response_model=dict,
    responses=SUCCESS_RESPONSE,
)
def get_dashboard_summary(db: Session = Depends(get_db)):
    try:
        # 1. 统计飞机总数
        aircraft_count = db.execute(text("SELECT COUNT(*) FROM Aircraft")).scalar() or 0
        
        # 2. 统计在库部件数 (状态为 available 或 in_stock)
        stock_count = db.execute(text("SELECT COUNT(*) FROM Component WHERE status IN ('in_stock', 'available')")).scalar() or 0
        
        # 3. 统计总维修工单数 (这里暂计历史总数，如果你有日期字段也可以加 WHERE 筛选本月)
        maintenance_count = db.execute(text("SELECT COUNT(*) FROM MaintenanceRecord")).scalar() or 0

        return ok({
            "aircraft_count": aircraft_count,
            "stock_count": stock_count,
            "maintenance_count": maintenance_count
        })
    except SQLAlchemyError as exc:
        raise_db_error(exc, db)

@router.get(
    "/stats/component-life-warning",
    summary="查询部件寿命预警",
    description="查询视图 v_component_life_warning，按寿命使用比例降序返回部件寿命预警。",
    response_model=dict,
    responses=SUCCESS_RESPONSE,
)
def get_component_life_warning(db: Session = Depends(get_db)):
    try:
        rows = db.execute(
            text(
                """
                SELECT
                    component_no,
                    model_code,
                    category,
                    design_life_hours,
                    used_hours,
                    remaining_life_hours,
                    life_usage_ratio,
                    warning_level
                FROM v_component_life_warning
                ORDER BY life_usage_ratio DESC, component_no
                """
            )
        ).mappings().all()
        return ok([dict(row) for row in rows])
    except SQLAlchemyError as exc:
        raise_db_error(exc, db)


@router.get(
    "/stats/retirement-reasons",
    summary="查询退役原因统计",
    description="查询视图 v_retirement_reason_stats，返回各退役原因的部件数量。",
    response_model=dict,
    responses=SUCCESS_RESPONSE,
)
def get_retirement_reason_stats(db: Session = Depends(get_db)):
    try:
        rows = db.execute(
            text(
                """
                SELECT retirement_reason, retirement_count
                FROM v_retirement_reason_stats
                ORDER BY retirement_count DESC, retirement_reason
                """
            )
        ).mappings().all()
        return ok([dict(row) for row in rows])
    except SQLAlchemyError as exc:
        raise_db_error(exc, db)


@router.get(
    "/stats/db-integrity-checks",
    summary="查询数据库完整性健康状态",
    description="统计退役状态、机型适配和当前安装位置冲突等数据库完整性异常。",
    response_model=dict,
    responses=SUCCESS_RESPONSE,
)
def get_db_integrity_checks(db: Session = Depends(get_db)):
    try:
        retired_status_inconsistent_count = db.execute(
            text(
                """
                SELECT COUNT(*)
                FROM Component
                WHERE
                    (status = 'retired' AND is_retired <> TRUE)
                    OR (status <> 'retired' AND is_retired = TRUE)
                """
            )
        ).scalar_one()

        incompatible_active_installation_count = db.execute(
            text(
                """
                SELECT COUNT(*)
                FROM InstallationRecord ir
                JOIN Component c ON ir.component_id = c.component_id
                JOIN ComponentModel cm ON c.model_id = cm.model_id
                JOIN Aircraft a ON ir.aircraft_id = a.aircraft_id
                WHERE ir.uninstall_time IS NULL
                  AND cm.applicable_aircraft_model IS NOT NULL
                  AND TRIM(cm.applicable_aircraft_model) <> ''
                  AND cm.applicable_aircraft_model <> a.aircraft_model
                """
            )
        ).scalar_one()

        active_position_conflict_count = db.execute(
            text(
                """
                SELECT COUNT(*)
                FROM (
                    SELECT aircraft_id, install_position
                    FROM InstallationRecord
                    WHERE uninstall_time IS NULL
                    GROUP BY aircraft_id, install_position
                    HAVING COUNT(*) > 1
                ) AS conflicts
                """
            )
        ).scalar_one()

        return ok({
            "retired_status_inconsistent_count": retired_status_inconsistent_count,
            "incompatible_active_installation_count": incompatible_active_installation_count,
            "active_position_conflict_count": active_position_conflict_count,
        })
    except SQLAlchemyError as exc:
        raise_db_error(exc, db)


@router.get("/stats/component-maintenance-interval", summary="查询部件维修间隔分析", response_model=dict, responses=SUCCESS_RESPONSE)
def get_component_maintenance_interval(db: Session = Depends(get_db)):
    try:
        rows = db.execute(text("SELECT * FROM v_component_maintenance_interval ORDER BY component_no, end_time DESC")).mappings().all()
        return ok([dict(row) for row in rows])
    except SQLAlchemyError as exc:
        raise_db_error(exc, db)


@router.get("/stats/aircraft-component-replacements", summary="查询飞机部件更换频率", response_model=dict, responses=SUCCESS_RESPONSE)
def get_aircraft_component_replacements(db: Session = Depends(get_db)):
    try:
        rows = db.execute(text("SELECT * FROM v_aircraft_component_replacement_stats ORDER BY replacement_count DESC, aircraft_no, install_position")).mappings().all()
        return ok([dict(row) for row in rows])
    except SQLAlchemyError as exc:
        raise_db_error(exc, db)


@router.get("/stats/component-maintenance-due", summary="查询部件周期维修预警", response_model=dict, responses=SUCCESS_RESPONSE)
def get_component_maintenance_due(db: Session = Depends(get_db)):
    try:
        rows = db.execute(text("SELECT * FROM v_component_maintenance_due ORDER BY maintenance_usage_ratio DESC, component_no")).mappings().all()
        return ok([dict(row) for row in rows])
    except SQLAlchemyError as exc:
        raise_db_error(exc, db)
