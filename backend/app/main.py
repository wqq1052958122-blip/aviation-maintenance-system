from fastapi import FastAPI, HTTPException, Request
from fastapi.exceptions import RequestValidationError
from sqlalchemy.exc import IntegrityError, OperationalError, SQLAlchemyError

from app.routers import (
    aircrafts,
    component_models,
    components,
    flights,
    installations,
    maintenances,
    stats,
)
from app.utils.db_errors import extract_db_message
from app.openapi_docs import OPENAPI_TAGS, SUCCESS_RESPONSE
from app.utils.responses import fail, ok

app = FastAPI(
    title="Aviation Maintenance Backend",
    version="1.0.0",
    description=(
        "航空部件生命周期与维修管理系统后端接口。"
        "所有成功响应统一为 {success: true, data: ...}，"
        "所有失败响应统一为 {success: false, message: ...}。"
        "不要调用 DELETE 接口，核心业务数据不允许物理删除。"
    ),
    openapi_tags=OPENAPI_TAGS,
)


@app.exception_handler(IntegrityError)
@app.exception_handler(OperationalError)
@app.exception_handler(SQLAlchemyError)
async def sqlalchemy_exception_handler(request: Request, exc: SQLAlchemyError):
    return fail(extract_db_message(exc), status_code=400)


@app.exception_handler(HTTPException)
async def http_exception_handler(request: Request, exc: HTTPException):
    return fail(str(exc.detail), status_code=exc.status_code)


@app.exception_handler(RequestValidationError)
async def validation_exception_handler(request: Request, exc: RequestValidationError):
    return fail(str(exc.errors()), status_code=400)


@app.exception_handler(Exception)
async def general_exception_handler(request: Request, exc: Exception):
    return fail(str(exc), status_code=500)


@app.get(
    "/health",
    tags=["health"],
    summary="健康检查",
    description="检查后端服务是否正常启动。建议打开 Swagger 后第一个测试该接口。",
    response_model=dict,
    responses=SUCCESS_RESPONSE,
)
def health():
    return ok({"status": "ok"})


app.include_router(aircrafts.router)
app.include_router(component_models.router)
app.include_router(components.router)
app.include_router(installations.router)
app.include_router(maintenances.router)
app.include_router(flights.router)
app.include_router(stats.router)
