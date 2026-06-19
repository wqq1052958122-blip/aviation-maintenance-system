# 数据库变更建议记录

本文只记录后端阅读 SQL 后发现的问题和风险，不直接修改数据库 SQL。

## 1. `Component.status` 与 `Component.is_retired` 的一致性

现状：表约束已保证 `is_retired = TRUE` 时 `status` 必须为 `retired`。但仍允许 `is_retired = FALSE` 且 `status = 'retired'` 的组合。

影响：极端情况下可能出现状态字段显示已退役，但布尔字段显示未退役，前端和统计逻辑可能产生歧义。

建议：如果课程环境 MySQL CHECK 约束可稳定执行，可将一致性约束强化为 `status='retired'` 与 `is_retired=TRUE` 双向一致。

## 2. `Component.created_at` 作为入库时间

现状：`v_component_lifecycle` 使用 `Component.created_at` 作为入库事件时间。

影响：如果初始化历史数据或迁移数据时没有显式指定 `created_at`，生命周期时间线中的入库时间会变成导入数据库的时间，而不一定是真实入库时间。

建议：如需更严谨追溯，可增加独立字段 `stock_in_time` 或在导入历史数据时显式设置 `created_at`。

## 3. `FlightLog.flight_hours` 与起降时间一致性

现状：表中同时存储 `takeoff_time`、`landing_time` 和 `flight_hours`，数据库只检查 `flight_hours > 0`，没有强制校验它等于起降时间差。

影响：如果绕过后端直接写库，可能出现飞行小时数与起降时间不一致，进而影响部件飞行使用统计。

建议：可在数据库层增加生成列、触发器校验，或约定所有写入统一通过后端和存储过程完成。

## 4. 安装历史时间区间重叠

现状：触发器拦截了当前有效安装冲突，即同一部件不能有多个 `uninstall_time IS NULL` 记录，同一飞机同一位置不能同时有多个当前有效部件。

影响：对于已经关闭的历史区间，数据库没有完全阻止时间段重叠。例如同一部件在历史上可能出现两个重叠的已关闭安装区间。

建议：如项目需要严格历史追溯，可增加触发器检查同一部件、同一飞机同一位置的安装时间区间不能重叠。

## 5. 部件型号适用飞机型号校验

现状：`ComponentModel.applicable_aircraft_model` 记录适用飞机型号，但安装触发器未强制校验该字段与 `Aircraft.aircraft_model` 一致。

影响：数据库可能允许 A320 适用部件安装到其他型号飞机上。

建议：在 `trg_before_insert_installation` 中增加部件型号适配校验，或改为建立更规范的型号适配关系表。
