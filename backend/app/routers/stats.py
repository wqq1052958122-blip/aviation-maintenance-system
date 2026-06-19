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