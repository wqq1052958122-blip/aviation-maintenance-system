from fastapi import APIRouter, Depends
from sqlalchemy import text
from sqlalchemy.orm import Session

from app.database import get_db
from app.openapi_docs import SUCCESS_RESPONSE
from app.utils.responses import ok

router = APIRouter(tags=["component-models"])


@router.get(
    "/component-models",
    summary="查询部件型号列表",
    description=(
        "查询 ComponentModel 表。新部件入库 POST /components 时，"
        "需要从这里选择 model_id。"
    ),
    response_model=dict,
    responses=SUCCESS_RESPONSE,
)
def list_component_models(db: Session = Depends(get_db)):
    rows = db.execute(text("SELECT * FROM ComponentModel ORDER BY model_id")).mappings().all()
    return ok([dict(row) for row in rows])
