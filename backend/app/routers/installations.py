from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import text
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.orm import Session

from app.database import get_db
from app.routers.components import replace_component as replace_component_preferred
from app.openapi_docs import SUCCESS_RESPONSE
from app.schemas import ComponentReplace, InstallationCreate, InstallationUninstall
from app.utils.db_errors import raise_db_error
from app.utils.responses import ok

router = APIRouter(tags=["installations"])


def get_component_id(db: Session, component_no: str) -> int:
    value = db.execute(
        text("SELECT component_id FROM Component WHERE component_no = :component_no"),
        {"component_no": component_no},
    ).scalar_one_or_none()
    if value is None:
        raise HTTPException(status_code=400, detail="Component does not exist.")
    return int(value)


def get_aircraft_id(db: Session, aircraft_no: str) -> int:
    value = db.execute(
        text("SELECT aircraft_id FROM Aircraft WHERE aircraft_no = :aircraft_no"),
        {"aircraft_no": aircraft_no},
    ).scalar_one_or_none()
    if value is None:
        raise HTTPException(status_code=400, detail="Aircraft does not exist.")
    return int(value)


def get_position_id(db: Session, aircraft_id: int, install_position: str) -> int:
    value = db.execute(
        text(
            """
            SELECT position_id
            FROM AircraftInstallPosition
            WHERE aircraft_id = :aircraft_id
              AND position_code = :install_position
              AND is_active = TRUE
            """
        ),
        {"aircraft_id": aircraft_id, "install_position": install_position},
    ).scalar_one_or_none()
    if value is None:
        raise HTTPException(status_code=400, detail="Installation position does not exist for this aircraft.")
    return int(value)


@router.get(
    "/current-installations",
    summary="查询当前安装状态",
    description=(
        "查询视图 v_current_installation，只返回 uninstall_time 为空的当前有效安装记录。"
        "安装、拆卸、更换后建议重新测试该接口。"
    ),
    response_model=dict,
    responses=SUCCESS_RESPONSE,
)
def list_current_installations(db: Session = Depends(get_db)):
    rows = db.execute(
        text("SELECT * FROM v_current_installation ORDER BY aircraft_no, install_position")
    ).mappings().all()
    return ok([dict(row) for row in rows])


@router.get(
    "/install-positions",
    summary="查询飞机安装位置",
    description=(
        "查询规范化安装位置。可按 aircraft_no 过滤；传 component_no 时，"
        "只返回与该部件类别匹配的位置。前端筛选只是辅助，数据库触发器仍会最终校验。"
    ),
    response_model=dict,
    responses=SUCCESS_RESPONSE,
)
def list_install_positions(
    aircraft_no: Optional[str] = Query(default=None),
    component_no: Optional[str] = Query(default=None),
    db: Session = Depends(get_db),
):
    params = {}
    sql = """
        SELECT
            aip.position_id,
            a.aircraft_no,
            a.aircraft_model,
            aip.position_code,
            aip.position_name,
            aip.allowed_category,
            cc.category_name AS allowed_category_name,
            EXISTS (
                SELECT 1
                FROM InstallationRecord ir
                WHERE ir.position_id = aip.position_id
                  AND ir.uninstall_time IS NULL
            ) AS is_occupied
        FROM AircraftInstallPosition aip
        JOIN Aircraft a ON aip.aircraft_id = a.aircraft_id
        JOIN ComponentCategory cc ON aip.allowed_category = cc.category_code
        WHERE aip.is_active = TRUE
    """
    if aircraft_no:
        sql += " AND a.aircraft_no = :aircraft_no"
        params["aircraft_no"] = aircraft_no
    if component_no:
        get_component_id(db, component_no)
        sql += """
            AND aip.allowed_category = (
                SELECT cm.category
                FROM Component c
                JOIN ComponentModel cm ON c.model_id = cm.model_id
                WHERE c.component_no = :component_no
            )
        """
        params["component_no"] = component_no
    sql += " ORDER BY a.aircraft_no, aip.position_id"
    rows = db.execute(text(sql), params).mappings().all()
    return ok([dict(row) for row in rows])


@router.post(
    "/installations",
    summary="安装部件",
    description=(
        "普通安装部件。前端传 component_no 和 aircraft_no，后端转换为内部 ID 后插入 InstallationRecord。"
        "不要传 uninstall_time。数据库触发器会拦截退役部件安装、重复安装、位置冲突等非法操作。"
    ),
    response_model=dict,
    responses=SUCCESS_RESPONSE,
)
def create_installation(payload: InstallationCreate, db: Session = Depends(get_db)):
    params = payload.model_dump()
    params["component_id"] = get_component_id(db, payload.component_no)
    params["aircraft_id"] = get_aircraft_id(db, payload.aircraft_no)
    params["position_id"] = get_position_id(db, params["aircraft_id"], payload.install_position)

    try:
        result = db.execute(
            text(
                """
                INSERT INTO InstallationRecord (
                    component_id, aircraft_id, position_id, install_position, install_time,
                    install_reason, operator_id
                )
                VALUES (
                    :component_id, :aircraft_id, :position_id, :install_position, :install_time,
                    :install_reason, :operator_id
                )
                """
            ),
            params,
        )
        db.commit()
        return ok({"installation_id": result.lastrowid})
    except SQLAlchemyError as exc:
        raise_db_error(exc, db)


@router.post(
    "/installations/{installation_id}/uninstall",
    summary="拆卸部件",
    description=(
        "按 installation_id 拆卸当前安装记录。只更新 uninstall_time、"
        "uninstall_reason、uninstall_operator_id。已关闭的安装记录不能再次修改。"
    ),
    response_model=dict,
    responses=SUCCESS_RESPONSE,
)
def uninstall_installation(
    installation_id: int,
    payload: InstallationUninstall,
    db: Session = Depends(get_db),
):
    try:
        result = db.execute(
            text(
                """
                UPDATE InstallationRecord
                SET uninstall_time = :uninstall_time,
                    uninstall_reason = :uninstall_reason,
                    uninstall_operator_id = :uninstall_operator_id
                WHERE installation_id = :installation_id
                """
            ),
            {**payload.model_dump(), "installation_id": installation_id},
        )
        if result.rowcount == 0:
            raise HTTPException(status_code=400, detail="Installation record does not exist.")
        db.commit()
        return ok({"installation_id": installation_id, "status": "uninstalled"})
    except SQLAlchemyError as exc:
        raise_db_error(exc, db)

@router.post(
    "/replace",
    summary="更换部件（旧版）",
    description="旧版兼容入口；请优先使用 POST /components/replace。",
    response_model=dict,
    responses=SUCCESS_RESPONSE,
    deprecated=True,
)
def replace_component_legacy(payload: ComponentReplace, db: Session = Depends(get_db)):
    return replace_component_preferred(payload, db)
