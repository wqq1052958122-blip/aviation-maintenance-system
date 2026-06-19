# 数据库对接说明

## 数据库名称

后端依赖数据库：

```text
aviation_maintenance
```

## 后端依赖的表

后端直接依赖以下核心表：

- `Aircraft`
- `ComponentModel`
- `Component`
- `InstallationRecord`
- `MaintenanceRecord`
- `FlightLog`
- `RetirementRecord`
- `Operator`

## 后端依赖的视图

后端查询以下视图：

- `v_current_installation`
- `v_component_profile`
- `v_component_lifecycle`
- `v_component_flight_usage`
- `v_model_maintenance_stats`

## 后端依赖的存储过程

后端调用以下存储过程：

- `sp_replace_component`
- `sp_retire_component`
- `sp_complete_maintenance`

## 后端不会修改数据库结构

后端只适配现有 MySQL 数据库，不会修改表结构、触发器、视图、存储过程或索引。

如果数据库字段、视图名、视图字段、存储过程名称或参数顺序发生变化，需要通知后端同步修改接口代码。

## SQL 执行顺序

推荐建库顺序：

```text
1. 01_create_tables.sql
2. 02_seed_data.sql
3. 03_triggers.sql
4. 04_procedures.sql
5. 05_views_queries.sql
6. 07_indexes.sql
```

测试脚本 `06_test_illegal_ops.sql` 和 `08_test_procedures.sql` 用于演示和验证，不是后端启动必需脚本。

## 错误对接

数据库触发器或存储过程如果使用：

```sql
SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '业务错误信息';
```

后端会提取 `MESSAGE_TEXT`，并返回：

```json
{
  "success": false,
  "message": "业务错误信息"
}
```

HTTP 状态码为 400。
