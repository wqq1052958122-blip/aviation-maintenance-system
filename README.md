
## 本次整合与优化说明

本版本在原有数据库、后端和前端基础上进行了整合与收尾优化，主要目标是让系统能够更稳定地联动展示数据库功能，并提升前端页面的一致性和项目提交观感。

### 1. 数据库增强结果接入前端展示

为了让数据库新增的分析视图不只停留在 SQL 层，本次已将相关统计能力接入 Dashboard 页面。

新增后端接口：

* `GET /stats/component-life-warning`：获取部件寿命预警数据；
* `GET /stats/retirement-reasons`：获取退役原因统计数据；
* `GET /stats/db-integrity-checks`：获取数据库规则健康检查结果。

Dashboard 新增展示内容：

* 部件寿命预警表格，展示部件设计寿命、已用小时、剩余寿命、使用比例和预警等级；
* 退役原因统计图，用于展示不同退役原因的数量分布；
* 数据库规则健康检查卡片，用于展示退役状态一致性、安装型号适配、安装位置冲突等检查结果。

这样可以在前端直接体现数据库在寿命预警、统计分析和完整性规则检查方面的作用。

### 2. 前端文案与状态显示统一

本次对主要前端页面进行了轻量级清理和文案统一，涉及页面包括：

* Dashboard
* Components
* Installations
* Maintenances
* Flights
* Aircrafts
* Operators

主要调整包括：

* 删除明显的 `console.log`、`console.warn`、`console.error` 等调试输出；
* 删除部分废弃旧实现和无用注释；
* 统一按钮文案，例如新增类按钮统一为“新增…”，表单提交按钮统一为“提交”；
* 统一部件状态、维修结果、飞机状态和预警状态的中文显示；
* 安装列表不再直接显示英文部件状态；
* 错误提示统一为“操作失败：<后端返回信息>”的形式，既保留后端/数据库错误原因，也让前端提示更一致；
* 修复 Components 页面重复加载和未定义错误转换函数的问题。

### 3. README 文档补充

根目录新增并完善了 `README.md`，用于说明项目整体情况和启动方式。

README 中补充了：

* 项目简介；
* 技术栈说明；
* 项目目录结构；
* 数据库初始化顺序；
* `.env` 配置说明；
* Windows 下后端启动命令；
* Windows PowerShell 下前端使用 `npm.cmd` 启动的方式；
* 核心功能说明；
* 数据库设计亮点说明。

其中前端启动建议使用：

```powershell
cd aviation-frontend
npm.cmd install
npm.cmd run dev
```

原因是 Windows PowerShell 可能会限制 `npm.ps1` 脚本执行，使用 `npm.cmd` 可以避免执行策略问题。

### 4. 未修改内容说明

本次前端清理和文档补充没有修改数据库 SQL 文件，也没有修改后端核心业务逻辑。

未修改内容包括：

* 未修改 `db/*.sql`；
* 未修改数据库表结构、触发器、存储过程和视图定义；
* 未修改已有 API 路径；
* 未新增复杂页面；
* 未引入登录、权限等额外功能。

### 5. 验证情况

本次修改后已完成以下检查：

* `npm.cmd run build` 通过；
* `git diff --check` 通过；
* 未提交 `.env`、`.venv`、`node_modules` 等本地环境文件；
* 构建中仍存在原有第三方依赖的 `PURE annotation` 和大 chunk 警告，但不影响正常构建和运行。

### 6. 打包说明

最终打包时请注意不要包含以下本地文件或目录：

* `backend/.env`
* `backend/.venv/`
* `aviation-frontend/node_modules/`
* `__pycache__/`
* `*.pyc`

建议保留：

* `README.md`
* `db/*.sql`
* `backend/`
* `aviation-frontend/`
* `backend/.env.example`
* `backend/requirements.txt`
* `aviation-frontend/package.json`
# 航空部件生命周期与维修管理系统

本项目是以数据库设计为核心的航空部件生命周期管理课程项目。系统通过 MySQL 约束、触发器、存储过程、事务和视图维护部件从入库、安装、维修到退役的完整历史，并由 FastAPI 和 Vue 提供接口及可视化界面。

## 技术栈

- MySQL 8.0
- FastAPI
- Vue 3
- Element Plus
- ECharts

## 核心功能

- 部件入库
- 安装与拆卸
- 部件更换事务
- 维修管理
- 飞行日志
- 退役管理
- 生命周期追溯
- 部件寿命预警
- 数据库健康检查

## 数据库初始化

请使用 MySQL 8.0，按以下顺序执行 `db/` 中的脚本：

```text
01_create_tables.sql
02_seed_data.sql
03_triggers.sql
04_procedures.sql
05_views_queries.sql
07_indexes.sql
```

`06_test_illegal_ops.sql` 和 `08_test_procedures.sql` 是验证脚本，建议阅读注释后分段执行，不要作为初始化脚本一次性运行。

## 本地环境配置

后端配置模板位于 `backend/.env.example`。首次运行时复制为本地配置：

```powershell
cd backend
Copy-Item .env.example .env
```

然后编辑 `.env`，填写本机 MySQL 连接信息。

- `.env.example`：可提交的配置模板，不包含真实密码。
- `.env`：本地真实配置，不要提交到 Git。
- `.venv`、`node_modules` 和构建产物同样不要提交。

## Windows 启动后端

首次配置 Python 虚拟环境和依赖：

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

启动后可访问：

- API：`http://127.0.0.1:8000`
- Swagger：`http://127.0.0.1:8000/docs`

## Windows PowerShell 启动前端

```powershell
cd aviation-frontend
npm.cmd install
npm.cmd run dev
```

Windows PowerShell 可能因执行策略禁止运行 `npm.ps1`。使用 `npm.cmd` 可以绕过这一脚本执行策略限制，同时保持 npm 命令行为不变。

生产构建验证：

```powershell
cd aviation-frontend
npm.cmd run build
```

默认开发地址以 Vite 终端输出为准，通常为 `http://localhost:5173`。

## 目录结构

```text
aviation-project/
├── db/                  # MySQL 表、触发器、存储过程、视图和测试脚本
├── backend/             # FastAPI 后端
├── aviation-frontend/   # Vue 3 前端
├── AGENTS.md            # 项目协作与开发规则
└── README.md
```
