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