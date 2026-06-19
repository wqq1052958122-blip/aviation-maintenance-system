from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import text
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.orm import Session

from app.database import get_db
from app.openapi_docs import SUCCESS_RESPONSE
from app.schemas import InstallationCreate, InstallationUninstall
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

    try:
        result = db.execute(
            text(
                """
                INSERT INTO InstallationRecord (
                    component_id, aircraft_id, install_position, install_time,
                    install_reason, operator_id
                )
                VALUES (
                    :component_id, :aircraft_id, :install_position, :install_time,
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

@router.post("/replace", summary="更换部件", description="调用数据库存储过程 sp_replace_component")
def replace_component(payload: dict, db: Session = Depends(get_db)):
    try:
        # 严格按照 SQL 定义的 7 个参数顺序进行排列
        db.execute(
            text("CALL sp_replace_component("
                 ":old_component_no, "
                 ":new_component_no, "
                 ":aircraft_no, "
                 ":install_position, "
                 ":replace_time, "
                 ":operator_id, "
                 ":uninstall_reason)"),
            payload
        )
        db.commit()
        return ok({"status": "replaced"})
    except SQLAlchemyError as exc:
        raise_db_error(exc, db)