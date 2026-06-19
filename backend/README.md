# 航空部件生命周期与维修管理系统后端说明

## 1. 项目简介

本项目是数据库课程大作业“航空部件生命周期与维修管理系统”的后端部分。系统的核心对象是航空部件 `Component`，主要追踪部件从入库、安装、拆卸、维修、再次安装到退役的完整生命周期。

项目采用三层结构：

```text
前端页面 → FastAPI 后端 API → MySQL 数据库
```



## 2. 技术栈

本项目后端使用：

- Python
- FastAPI
- Uvicorn
- SQLAlchemy
- PyMySQL
- Pydantic
- python-dotenv
- MySQL

依赖以 `backend/requirements.txt` 为准。

## 3. 目前后端实现的功能

当前后端已经实现以下功能模块：

- 健康检查：提供 `GET /health`，用于确认 FastAPI 服务是否正常启动。
- 基础数据查询：提供飞机、部件型号、部件、操作人员等基础查询接口，方便前端做下拉选择和列表展示。
- 当前安装查询：通过数据库视图 `v_current_installation` 查询当前仍安装在飞机上的部件。
- 部件入库：提供 `POST /components`，支持新增部件实例，默认状态为 `in_stock`。
- 部件档案查询：通过 `v_component_profile` 查询单个部件的型号、批次、状态、当前安装和退役信息。
- 生命周期追溯：通过 `v_component_lifecycle` 返回部件从入库、安装、拆卸、维修到退役的时间线。
- 部件飞行使用统计：通过 `v_component_flight_usage` 查询部件经历的飞行次数和累计飞行小时。
- 部件安装：提供 `POST /installations`，前端传部件编号和飞机编号，后端转换成数据库 ID 后写入安装记录。
- 部件拆卸：提供 `POST /installations/{installation_id}/uninstall`，通过填写拆卸时间关闭安装历史记录，不删除历史。
- 部件更换：提供 `POST /components/replace`，调用存储过程 `sp_replace_component`，保证旧部件拆卸和新部件安装在同一事务中完成。
- 维修管理：提供创建维修记录、完成维修、查询某部件维修历史等接口。
- 维修完成事务：`POST /maintenances/{maintenance_id}/complete` 调用 `sp_complete_maintenance`，根据 `passed`、`failed`、`scrapped` 更新部件状态。
- 部件退役：提供 `POST /components/{component_no}/retire`，调用 `sp_retire_component`，通过退役记录和状态标记完成退役，不做物理删除。
- 飞行日志：提供 `POST /flights` 和 `GET /flights`，新增飞行日志时后端自动根据起降时间计算 `flight_hours`。
- 统计分析：提供 `GET /stats/model-maintenance`，通过视图 `v_model_maintenance_stats` 查询部件型号维修统计。
- 统一响应格式：所有接口统一返回 `success/data/message`，方便前端处理成功和失败。
- 数据库错误透传：触发器或存储过程抛出的业务错误会被后端转换成前端可读的 `message`。
- Swagger 接口说明：所有接口说明、请求体示例和响应示例已经写入 `http://127.0.0.1:8000/docs`。

注意：后端没有实现登录注册、权限系统、前端页面和物理删除接口。

## 4. 项目目录结构

当前项目主要结构如下：

```text
Database/
├── backend/
│   ├── app/
│   │   ├── main.py
│   │   ├── database.py
│   │   ├── schemas.py
│   │   ├── openapi_docs.py
│   │   ├── routers/
│   │   └── utils/
│   ├── docs/
│   ├── .env.example
│   ├── requirements.txt
│   └── README.md
├── db/
│   └── db/
│       ├── 01_create_tables.sql
│       ├── 02_seed_data.sql
│       ├── 03_triggers.sql
│       ├── 04_procedures.sql
│       ├── 05_views_queries.sql
│       ├── 06_test_illegal_ops.sql
│       ├── 07_indexes.sql
│       ├── 08_test_procedures.sql
│       └── README_DATABASE.md
├── docs/
│   └── BACKEND_EXPLANATION_FOR_ME.md
└── README.md
```

主要文件说明：

- `backend/app/main.py`：FastAPI 入口，注册接口路由和统一异常处理。
- `backend/app/database.py`：读取 `.env`，创建 MySQL 数据库连接。
- `backend/app/schemas.py`：定义 POST 请求体格式和 Swagger 示例。
- `backend/app/openapi_docs.py`：定义 Swagger 页面中的接口说明和响应示例。
- `backend/app/routers/`：按业务模块拆分接口，例如部件、安装、维修、飞行日志、统计等。
- `backend/app/utils/`：放通用工具，例如统一响应格式和数据库错误处理。
- `backend/docs/DB_COORDINATION.md`：给数据库同学看的后端数据库依赖说明。
- `backend/docs/DB_CHANGE_REQUESTS.md`：记录后端发现的数据库设计风险和修改建议。
- `backend/docs/TEST_CASES.md`：后端接口测试和答辩演示流程。
- `docs/BACKEND_EXPLANATION_FOR_ME.md`：后端负责人自学和答辩理解文档。
- `db/db/`：数据库 SQL 文件目录。
- `backend/.env.example`：环境变量模板，可以发给组员。
- `backend/requirements.txt`：Python 依赖列表。
- `backend/README.md`：后端目录内的简版启动说明。

## 5. 环境配置

使用前需要在 `backend/` 目录下复制 `.env.example` 为 `.env`：

```env
DB_HOST=localhost
DB_PORT=3306
DB_USER=root
DB_PASSWORD=your_mysql_password
DB_NAME=aviation_maintenance
```

字段说明：

- `DB_HOST`：数据库地址，本机数据库一般是 `localhost`。
- `DB_PORT`：MySQL 默认端口，一般是 `3306`。
- `DB_USER`：数据库用户名，例如 `root`。
- `DB_PASSWORD`：自己的 MySQL 密码。
- `DB_NAME`：数据库名，本项目为 `aviation_maintenance`。



## 6. 数据库准备

后端依赖 MySQL 数据库：

```text
aviation_maintenance
```

当前 SQL 文件实际位于 `db/db/` 目录。推荐执行顺序：

1. `db/db/01_create_tables.sql`
2. `db/db/02_seed_data.sql`
3. `db/db/03_triggers.sql`
4. `db/db/04_procedures.sql`
5. `db/db/05_views_queries.sql`
6. `db/db/07_indexes.sql`

说明：

- 如果没有执行 `01_create_tables.sql`，接口会报表不存在。
- 如果没有执行 `02_seed_data.sql`，查询接口可能返回空数组。
- 如果没有执行 `05_views_queries.sql`，生命周期、当前安装、统计等查询接口可能失败。
- 如果没有执行 `04_procedures.sql`，更换、退役、维修完成等接口可能失败。
- `06_test_illegal_ops.sql` 和 `08_test_procedures.sql` 是测试脚本，不是后端启动必须执行的脚本。

## 7. 安装依赖

在 `backend/` 目录下执行：

```bash
cd backend
python -m pip install -r requirements.txt
```

如果已经使用 Conda 或其他 Python 环境，也要确认当前环境里能导入 FastAPI、SQLAlchemy、PyMySQL、python-dotenv 和 Uvicorn。

## 8. 启动后端

在 `backend/` 目录下执行：

```bash
uvicorn app.main:app --reload
```

启动成功后访问：

```text
http://127.0.0.1:8000/docs
```

这是 FastAPI 自动生成的 Swagger 接口测试页面。当前项目的接口说明和请求示例已经写入 Swagger 页面，前端同学可以直接看这里。

## 9. 如何测试接口

建议按下面顺序先测试查询接口：

1. `GET /health`
2. `GET /aircrafts`
3. `GET /components`
4. `GET /component-models`
5. `GET /operators`

说明：

- `GET /health` 成功只代表后端服务启动成功。
- 查询接口能返回数据，才说明数据库连接和基础数据基本正常。
- 如果接口返回 `data: []`，说明数据库连接成功，但表里可能没有数据，通常要检查是否执行了 `02_seed_data.sql`。
- Swagger 里的 POST 会真实写入或修改数据库，不是模拟测试。
- 测试 POST 接口时建议使用明显的测试编号，例如 `TEST-ENG-001`，避免污染正式演示数据。

## 10. 前端对接说明

前端同学主要看 Swagger：

```text
http://127.0.0.1:8000/docs
```

当前项目没有单独的 `docs/API_FOR_FRONTEND.md` 文件，接口说明、分组说明、请求体示例和响应示例已经写在 Swagger 页面里。

统一成功响应：

```json
{
  "success": true,
  "data": {}
}
```

统一失败响应：

```json
{
  "success": false,
  "message": "错误原因"
}
```

前端只需要判断 `success`。如果 `success` 为 `true`，展示 `data`；如果 `success` 为 `false`，直接展示 `message`。

前端不要直接连接数据库，也不要调用 DELETE。项目要求核心业务数据保留历史，退役通过状态和退役记录处理，不做物理删除。

## 11. 数据库对接说明

数据库同学主要看：

```text
backend/docs/DB_COORDINATION.md
backend/docs/DB_CHANGE_REQUESTS.md
```

后端依赖数据库中的表、视图、存储过程和触发器。

后端依赖的核心表包括：

- `Aircraft`
- `ComponentModel`
- `Component`
- `InstallationRecord`
- `MaintenanceRecord`
- `FlightLog`
- `RetirementRecord`
- `Operator`

后端依赖的视图包括：

- `v_current_installation`
- `v_component_profile`
- `v_component_lifecycle`
- `v_component_flight_usage`
- `v_model_maintenance_stats`

后端依赖的存储过程包括：

- `sp_replace_component`
- `sp_retire_component`
- `sp_complete_maintenance`

如果数据库字段名、视图名、存储过程名或参数发生变动，需要通知后端同步修改。后端不会擅自修改数据库结构；如果发现数据库设计问题，会写入 `backend/docs/DB_CHANGE_REQUESTS.md`。

## 12. 常见问题

### Q1：后端能启动，但 `/components` 报错怎么办？

可能原因包括：`.env` 配置错误、MySQL 没启动、数据库没创建、表没创建、当前连接的数据库不是 `aviation_maintenance`。先检查 `.env`，再确认 SQL 是否按顺序执行。

### Q2：`/health` 成功是否代表数据库正常？

不一定。`/health` 只说明 FastAPI 服务正常，数据库要用 `/components`、`/aircrafts`、`/component-models` 等接口测试。

### Q3：Swagger 里的 POST 是不是真的写入数据库？

是。Swagger 的 `Try it out` 会真实调用接口，POST 会真实新增或修改数据库。

### Q4：为什么没有 DELETE 接口？

因为项目要求核心业务数据历史保留。部件退役通过 `Component.status`、`Component.is_retired` 和 `RetirementRecord` 记录，不做物理删除。

### Q5：前端调用接口返回 422 是什么？

通常是请求 JSON 格式、字段名、字段类型不符合后端 `schemas.py` 中的 Pydantic 模型要求。前端应对照 Swagger 的请求示例修改。

### Q6：前端调用接口返回 400 是什么？

通常是业务规则不允许，例如退役部件不能安装、重复安装、安装位置冲突、维修时间不合理等。前端应直接展示后端返回的 `message`。

### Q7：接口返回 500 怎么办？

先看后端 uvicorn 终端报错，再检查数据库连接、表/视图/存储过程是否存在，以及后端 SQL 是否和数据库字段一致。

## 13. 交付注意事项

给同学代码时不要包含：

- `.env`
- `venv/`
- `.venv/`
- `__pycache__/`
- `*.pyc`

应该包含：

- 后端代码：`backend/app/`
- 后端文档：`backend/docs/`
- 项目说明文档：`docs/`
- 数据库 SQL 文件：`db/db/`
- 环境变量模板：`backend/.env.example`
- 依赖文件：`backend/requirements.txt`
- README：`README.md` 和 `backend/README.md`

如果对接时出现问题，先判断是前端请求格式问题、后端接口逻辑问题，还是数据库对象缺失或规则拦截问题。错误响应里的 `message` 通常是第一排查线索。
