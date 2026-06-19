from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import text
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.orm import Session

from app.database import get_db
from app.openapi_docs import SUCCESS_RESPONSE
from app.schemas import ComponentCreate, ComponentReplace, ComponentRetire
from app.utils.db_errors import raise_db_error
from app.utils.responses import ok

router = APIRouter(tags=["components"])


def get_component_id(db: Session, component_no: str) -> int:
    component_id = db.execute(
        text("SELECT component_id FROM Component WHERE component_no = :component_no"),
        {"component_no": component_no},
    ).scalar_one_or_none()
    if component_id is None:
        raise HTTPException(status_code=404, detail="Component does not exist.")
    return int(component_id)


@router.get(
    "/components",
    summary="查询部件列表",
    description=(
        "查询 Component 表中的所有部件实例。测试重点是 component_no、status、"
        "total_flight_hours、is_retired。"
    ),
    response_model=dict,
    responses=SUCCESS_RESPONSE,
)
def list_components(db: Session = Depends(get_db)):
    rows = db.execute(text("SELECT * FROM Component ORDER BY component_id")).mappings().all()
    return ok([dict(row) for row in rows])


@router.post(
    "/components",
    summary="新部件入库",
    description=(
        "新增一个部件实例。后端默认 status='in_stock'、total_flight_hours=0、"
        "is_retired=false。component_no 不能重复。"
    ),
    response_model=dict,
    responses=SUCCESS_RESPONSE,
)
def create_component(payload: ComponentCreate, db: Session = Depends(get_db)):
    try:
        result = db.execute(
            text(
                """
                INSERT INTO Component (
                    component_no, model_id, batch_no, production_date,
                    status, total_flight_hours, is_retired
                )
                VALUES (
                    :component_no, :model_id, :batch_no, :production_date,
                    'in_stock', 0, FALSE
                )
                """
            ),
            payload.model_dump(),
        )
        db.commit()
        return ok({"component_id": result.lastrowid, "component_no": payload.component_no})
    except SQLAlchemyError as exc:
        raise_db_error(exc, db)


@router.get(
    "/components/{component_no}/profile",
    summary="查询部件档案",
    description=(
        "查询视图 v_component_profile，返回部件基础信息、当前安装信息和退役信息。"
        "示例路径：/components/ENG-001/profile。"
    ),
    response_model=dict,
    responses=SUCCESS_RESPONSE,
)
def get_component_profile(component_no: str, db: Session = Depends(get_db)):
    row = db.execute(
        text("SELECT * FROM v_component_profile WHERE component_no = :component_no"),
        {"component_no": component_no},
    ).mappings().first()
    if row is None:
        raise HTTPException(status_code=404, detail="Component does not exist.")
    return ok(dict(row))


@router.get(
    "/components/{component_no}/lifecycle",
    summary="查询部件生命周期时间线",
    description=(
        "查询视图 v_component_lifecycle，按 event_time 升序返回入库、安装、拆卸、"
        "维修开始、维修完成、退役等事件。推荐测试 HYD-001。"
    ),
    response_model=dict,
    responses=SUCCESS_RESPONSE,
)
def get_component_lifecycle(component_no: str, db: Session = Depends(get_db)):
    get_component_id(db, component_no)
    rows = db.execute(
        text(
            """
            SELECT event_time, event_type, event_detail
            FROM v_component_lifecycle
            WHERE component_no = :component_no
            ORDER BY event_time ASC
            """
        ),
        {"component_no": component_no},
    ).mappings().all()
    return ok({"component_no": component_no, "timeline": [dict(row) for row in rows]})


@router.get(
    "/components/{component_no}/full-timeline",
    summary="查询部件完整生命周期时间轴",
    description=(
        "查询视图 v_component_full_timeline，按时间升序返回入库、安装、拆卸、"
        "维修、退役及维修计划事件，不影响原 lifecycle 接口。"
    ),
    response_model=dict,
    responses=SUCCESS_RESPONSE,
)
def get_component_full_timeline(component_no: str, db: Session = Depends(get_db)):
    get_component_id(db, component_no)
    rows = db.execute(
        text(
            """
            SELECT *
            FROM v_component_full_timeline
            WHERE component_no = :component_no
            ORDER BY event_time ASC
            """
        ),
        {"component_no": component_no},
    ).mappings().all()
    return ok({"component_no": component_no, "timeline": [dict(row) for row in rows]})


@router.get(
    "/components/{component_no}/flight-usage",
    summary="查询部件飞行使用统计",
    description=(
        "查询视图 v_component_flight_usage，返回该部件关联飞行次数、累计飞行小时、"
        "首次和最后飞行时间。推荐测试 ENG-001。"
    ),
    response_model=dict,
    responses=SUCCESS_RESPONSE,
)
def get_component_flight_usage(component_no: str, db: Session = Depends(get_db)):
    rows = db.execute(
        text(
            """
            SELECT *
            FROM v_component_flight_usage
            WHERE component_no = :component_no
            ORDER BY aircraft_no
            """
        ),
        {"component_no": component_no},
    ).mappings().all()
    return ok([dict(row) for row in rows])


@router.post(
    "/components/replace",
    summary="更换部件",
    description=(
        "调用存储过程 sp_replace_component 完成旧部件拆卸和新部件安装。"
        "不要在前端拆成多个接口调用。旧部件必须当前安装在指定飞机和位置，"
        "新部件必须可安装。"
    ),
    response_model=dict,
    responses=SUCCESS_RESPONSE,
)
def replace_component(payload: ComponentReplace, db: Session = Depends(get_db)):
    try:
        db.execute(
            text(
                """
                CALL sp_replace_component(
                    :old_component_no,
                    :new_component_no,
                    :aircraft_no,
                    :install_position,
                    :replace_time,
                    :operator_id,
                    :uninstall_reason
                )
                """
            ),
            payload.model_dump(),
        )
        db.commit()
        return ok({"message": "component replaced"})
    except SQLAlchemyError as exc:
        raise_db_error(exc, db)


@router.post(
    "/components/{component_no}/retire",
    summary="退役部件",
    description=(
        "调用存储过程 sp_retire_component 完成退役。安装中的部件不能直接退役，"
        "必须先拆卸。成功后 Component.status='retired' 且 is_retired=true。"
    ),
    response_model=dict,
    responses=SUCCESS_RESPONSE,
)
def retire_component(component_no: str, payload: ComponentRetire, db: Session = Depends(get_db)):
    params = payload.model_dump()
    params["component_no"] = component_no
    try:
        db.execute(
            text(
                """
                CALL sp_retire_component(
                    :component_no,
                    :retirement_time,
                    :retirement_reason,
                    :approved_by,
                    :remark
                )
                """
            ),
            params,
        )
        db.commit()
        return ok({"component_no": component_no, "status": "retired"})
    except SQLAlchemyError as exc:
        raise_db_error(exc, db)
