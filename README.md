# 航空部件生命周期与维修管理系统

本项目是一个以数据库设计为核心的航空维修管理课程项目，围绕航空部件从入库、安装、拆卸、维修、更换到退役的完整生命周期展开。

系统使用 MySQL 约束、触发器、存储过程、事务和视图维护核心业务规则，FastAPI 提供统一接口，Vue 3 负责管理界面与数据可视化。项目重点不是模拟订票业务，而是展示数据库在航空维修数据完整性、历史追溯和风险分析中的作用。

> 项目中的飞机、部件型号、设计寿命、维修周期和飞行记录均为教学模拟数据，不代表真实航空器参数或适航标准。

## 系统展示

适合课程答辩重点展示以下页面：

- Landing 首页：航空科技风系统门户与功能入口。
- Dashboard：寿命风险、维修计划、数据库健康状态、审计日志及统计图表。
- 部件管理：部件档案、飞行使用统计和完整生命周期时间轴。
- 机队管理：飞机基础信息与当前安装部件配置。
- 维修管理：维修工单以及 pending、completed、cancelled 全状态维修计划。

## 技术栈

- 数据库：MySQL 8.0
- 后端：FastAPI、SQLAlchemy、PyMySQL
- 前端：Vue 3、Vite
- UI：Element Plus
- 图表：ECharts

## 核心功能

- 部件入库与基础档案管理
- 部件状态和退役状态管理
- 飞机与安装位置管理
- 部件安装、拆卸与事务更换
- 维修工单创建与完成
- 维修计划创建、完成和取消
- 飞行日志与部件飞行小时统计
- 部件寿命预警
- 部件退役管理
- 完整生命周期时间轴
- 关键业务操作审计
- 数据库完整性健康检查

## 数据库设计亮点

### 触发器与完整性约束

- 保护 `Component.status` 与 `Component.is_retired` 一致。
- 检查部件型号与飞机型号是否适配。
- 防止同一飞机安装位置存在多个当前有效部件。
- 保护安装、维修和维修计划的时间顺序。
- 禁止核心历史记录被物理删除。

### 存储过程与事务

- `sp_replace_component`：在同一事务内完成旧部件拆卸、新部件安装和审计记录。
- `sp_retire_component`：执行部件退役并保留退役原因和审批信息。
- `sp_complete_maintenance`：完成维修并根据安装状态更新部件状态。

### 状态流转规则

`ComponentStatusTransitionRule` 保存合法状态流转，`trg_before_update_component_status` 拒绝非法变化。同一状态更新允许，`retired` 为终态。

### 权威飞行小时统计

寿命预警以 `FlightLog + InstallationRecord` 按安装时间区间推导出的飞行小时为准。`Component.total_flight_hours` 仅作为历史兼容字段，不作为寿命判断依据。

### 生命周期、计划与审计

- `v_component_full_timeline` 汇总入库、安装、拆卸、维修、退役和维修计划事件。
- `MaintenancePlan` 支持计划性维护及完成、取消后的历史追溯。
- `AuditLog` 记录更换、退役、维修完成和维修计划操作。

## 项目目录

```text
aviation-project/
├── aviation-frontend/       # Vue 3 前端
│   ├── src/api/             # 前端 API 封装
│   ├── src/views/           # Landing 与后台业务页面
│   └── package.json
├── backend/                 # FastAPI 后端
│   ├── app/routers/         # API 路由
│   ├── app/schemas.py       # Pydantic 请求模型
│   ├── .env.example         # 环境配置模板
│   └── requirements.txt
├── db/                      # MySQL 初始化与测试脚本
├── AGENTS.md                # 项目协作规则
└── README.md
```

## 数据库初始化

请使用 MySQL 8.0，并严格按以下顺序执行 `db/` 下的脚本：

```text
01_create_tables.sql
02_seed_data.sql
03_triggers.sql
04_procedures.sql
05_views_queries.sql
07_indexes.sql
```

说明：

- `01_create_tables.sql` 会删除并重新创建 `aviation_maintenance` 数据库，请提前备份已有数据。
- `02_seed_data.sql` 插入教学演示数据。
- `06_test_illegal_ops.sql` 是非法操作拦截测试。
- `08_test_procedures.sql` 是存储过程和事务验证脚本。
- `06` 和 `08` 不属于初始化步骤，建议根据注释分段执行。

## 本地环境配置

后端配置模板位于 `backend/.env.example`。首次运行时复制模板：

```powershell
cd backend
Copy-Item .env.example .env
```

编辑 `.env` 并填写本机 MySQL 配置：

```dotenv
DB_HOST=localhost
DB_PORT=3306
DB_USER=root
DB_PASSWORD=your_password
DB_NAME=aviation_maintenance
```

- `.env.example` 是可提交的配置模板。
- `.env` 保存本地真实配置，不要提交到 Git。
- 不要提交 `.venv/`、`node_modules/`、`dist/`、`__pycache__/` 或 `*.pyc`。

## Windows 启动后端

首次运行时创建虚拟环境并安装依赖：

```powershell
cd backend
python -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r requirements.txt
```

启动 FastAPI：

```powershell
cd backend
.\.venv\Scripts\python.exe -m uvicorn app.main:app --reload
```

服务地址：

- API：`http://127.0.0.1:8000`
- Swagger：`http://127.0.0.1:8000/docs`
- 健康检查：`http://127.0.0.1:8000/health`

## Windows PowerShell 启动前端

```powershell
cd aviation-frontend
npm.cmd install
npm.cmd run dev
```

Vite 默认开发地址通常为 `http://localhost:5173`，请以终端输出为准。

Windows PowerShell 可能因执行策略禁止运行 `npm.ps1`。使用 `npm.cmd` 可以绕过该脚本执行策略限制，同时保持 npm 命令行为不变。

生产构建验证：

```powershell
cd aviation-frontend
npm.cmd run build
```

## 教学模拟数据规模

当前 `02_seed_data.sql` 提供以下演示数据：

| 数据对象 | 数量 |
|---|---:|
| 飞机 | 9 |
| 部件型号 | 16 |
| 部件实例 | 66 |
| 安装记录 | 48 |
| 当前有效安装 | 28 |
| 历史安装/拆卸 | 20 |
| 飞行记录 | 40 |
| 维修记录 | 31 |
| 维修计划 | 20 |
| 退役记录 | 12 |
| 操作人员 | 10 |
| 审计日志 | 24 |

数据覆盖：

- A320、B737、A330 三种教学模拟机型。
- 服役中、维修中、已退役三种飞机状态。
- 发动机、起落架、航电、导航、液压、燃油、空调、刹车和机载电源部件。
- 在库、可用、已安装、已拆卸、维修中、已退役全部部件状态。
- 正常、预警、严重三档寿命风险。
- pending、completed、cancelled 全状态维修计划。
- 部件更换、维修失败、报废、经济性退役和寿命退役等典型场景。

## 关键 API

所有成功响应统一为：

```json
{
  "success": true,
  "data": {}
}
```

错误响应统一通过 `message` 返回：

```json
{
  "success": false,
  "message": "错误信息"
}
```

### 部件与生命周期

- `GET /components`
- `POST /components`
- `GET /components/{component_no}/profile`
- `GET /components/{component_no}/lifecycle`
- `GET /components/{component_no}/full-timeline`
- `GET /components/{component_no}/flight-usage`
- `POST /components/replace`
- `POST /components/{component_no}/retire`

### 安装与飞机

- `GET /aircrafts`
- `POST /aircrafts`
- `PUT /aircrafts/{aircraft_no}/status`
- `GET /current-installations`
- `GET /install-positions`
- `POST /installations`
- `POST /installations/{installation_id}/uninstall`

### 维修与维修计划

- `GET /maintenances`
- `POST /maintenances`
- `POST /maintenances/{maintenance_id}/complete`
- `GET /components/{component_no}/maintenances`
- `GET /maintenance-plans`
- `POST /maintenance-plans`
- `POST /maintenance-plans/{plan_id}/complete`
- `POST /maintenance-plans/{plan_id}/cancel`

### 飞行、统计与审计

- `GET /flights`
- `POST /flights`
- `GET /stats/summary`
- `GET /stats/model-maintenance`
- `GET /stats/component-life-warning`
- `GET /stats/retirement-reasons`
- `GET /stats/db-integrity-checks`
- `GET /audit-logs/recent`

完整请求模型和返回结构请以 Swagger 为准。

## 测试与验证

### 数据库测试

按初始化顺序完成后：

1. 分段执行 `db/06_test_illegal_ops.sql`，验证非法状态流转、时间约束、删除保护、型号适配和安装位置冲突。
2. 分段执行 `db/08_test_procedures.sql`，验证更换、退役、维修完成、审计日志和生命周期时间轴。
3. 查询以下视图确认数据：

```sql
SELECT * FROM v_component_life_warning ORDER BY life_usage_ratio DESC;
SELECT * FROM v_component_full_timeline ORDER BY component_no, event_time;
SELECT * FROM v_maintenance_plan_detail ORDER BY created_at DESC;
SELECT * FROM v_audit_log_detail ORDER BY operation_time DESC;
```

### 后端检查

启动服务后首先访问：

```text
GET /health
```

然后在 Swagger 中测试部件时间轴、维修计划、统计和审计接口。

### 前端检查

```powershell
cd aviation-frontend
npm.cmd run build
```

## 注意事项

- 所有航空参数均为教学模拟值，不可用于真实维修或适航决策。
- 数据库初始化脚本会重建数据库，执行前请确认目标环境。
- 核心业务记录不应通过 `DELETE` 删除，应使用状态流转或退役流程。
- 部件更换优先使用 `POST /components/replace`；`POST /replace` 仅为旧版兼容入口。
- 测试脚本包含预期失败的语句，请根据注释逐段执行。

## 项目总结

本项目通过前后端界面展示数据库业务能力，但核心仍是数据库设计：业务约束由表约束、触发器、存储过程、事务和视图共同保证。系统能够保留航空部件完整历史、阻止非法操作、追踪责任人，并通过飞行记录推导寿命风险，适合作为数据库课程设计和答辩演示项目。
