from fastapi import APIRouter, Depends
from sqlalchemy import text
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.orm import Session

from app.database import get_db
from app.openapi_docs import SUCCESS_RESPONSE
from app.utils.db_errors import raise_db_error
from app.utils.responses import ok


router = APIRouter(tags=["audit-logs"])


@router.get(
    "/audit-logs/recent",
    summary="查询最近审计日志",
    description="查询视图 v_audit_log_detail，返回最近 20 条业务操作审计记录。",
    response_model=dict,
    responses=SUCCESS_RESPONSE,
)
def list_recent_audit_logs(db: Session = Depends(get_db)):
    try:
        rows = db.execute(
            text(
                """
                SELECT *
                FROM v_audit_log_detail
                ORDER BY operation_time DESC
                LIMIT 20
                """
            )
        ).mappings().all()
        return ok([dict(row) for row in rows])
    except SQLAlchemyError as exc:
        raise_db_error(exc, db)
