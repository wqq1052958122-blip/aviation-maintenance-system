-- =====================================================
-- 文件：06_test_illegal_ops.sql
-- 作用：非法操作拦截测试脚本
-- 使用方式：不要一次性全运行。请在 Navicat 中一段一段选中运行。
-- =====================================================
USE aviation_maintenance;

-- 测试0：查看当前关键状态，可正常运行
SELECT component_id, component_no, status, is_retired
FROM Component
WHERE component_no IN ('ENG-001', 'ENG-002', 'ENG-003', 'NAV-001', 'HYD-002')
ORDER BY component_id;

SELECT ir.installation_id, c.component_no, a.aircraft_no, ir.install_position, ir.install_time, ir.uninstall_time
FROM InstallationRecord ir
JOIN Component c ON ir.component_id = c.component_id
JOIN Aircraft a ON ir.aircraft_id = a.aircraft_id
WHERE ir.uninstall_time IS NULL
ORDER BY c.component_no;

-- 测试1：退役部件不能再次安装。预期：Retired component cannot be installed.
INSERT INTO InstallationRecord (component_id, aircraft_id, position_id, install_position, install_time, uninstall_time, install_reason, uninstall_reason, operator_id, uninstall_operator_id)
VALUES (6, 1, 4, 'hydraulic system bay', '2025-06-10 09:00:00', NULL, 'illegal installation for retired component', NULL, 1, NULL);

-- 测试2：已安装部件不能重复安装。预期：Only in_stock or available components can be installed. 或 active installation 报错
INSERT INTO InstallationRecord (component_id, aircraft_id, position_id, install_position, install_time, uninstall_time, install_reason, uninstall_reason, operator_id, uninstall_operator_id)
VALUES (4, 2, 10, 'navigation bay', '2025-06-10 10:00:00', NULL, 'illegal duplicate installation', NULL, 1, NULL);

-- 测试3：同一飞机同一位置不能同时安装多个部件。预期：Aircraft position already has an active component.
-- ENG-003 是 in_stock，可安装；但 AC-1001 的 left engine position 已被 ENG-001 占用，若已执行更换测试则被 ENG-002 占用。
INSERT INTO InstallationRecord (component_id, aircraft_id, position_id, install_position, install_time, uninstall_time, install_reason, uninstall_reason, operator_id, uninstall_operator_id)
VALUES (3, 1, 1, 'left engine position', '2025-06-10 11:00:00', NULL, 'illegal position conflict test', NULL, 1, NULL);

-- 测试4：不能直接删除核心业务数据。预期：Component cannot be physically deleted. Use retirement process instead.
DELETE FROM Component WHERE component_no = 'HYD-002';

-- 测试5：不能通过 UPDATE 覆盖安装历史。预期：aircraft_id in installation history cannot be changed.
UPDATE InstallationRecord SET aircraft_id = 2 WHERE installation_id = 1;

-- 测试6：已关闭的安装记录不能重复修改。预期：Closed installation record cannot be modified again.
UPDATE InstallationRecord ir
JOIN Component c ON ir.component_id = c.component_id
SET ir.uninstall_reason = 'illegal modify closed history'
WHERE c.component_no = 'HYD-001'
  AND ir.uninstall_time IS NOT NULL;

-- 测试7：飞行时间不合理应被拒绝。预期：Check constraint 'chk_flight_time' is violated.
INSERT INTO FlightLog (aircraft_id, mission_no, takeoff_time, landing_time, flight_hours, mission_type, recorded_by)
VALUES (1, 'FL-ILLEGAL-001', '2025-06-11 12:00:00', '2025-06-11 10:00:00', 2.00, 'illegal time test', 4);

-- 测试8：安装中的部件不能直接退役。预期：Installed component must be uninstalled before retirement.
CALL sp_retire_component('NAV-001', '2025-06-12 10:00:00', 'illegal retirement test', 3, 'this should fail because NAV-001 is still installed');

-- 测试9：status = retired 时 is_retired 必须为 TRUE。预期：chk_retired_status_consistency 约束失败。
UPDATE Component
SET status = 'retired', is_retired = FALSE
WHERE component_no = 'ENG-003';

-- 测试10：is_retired = TRUE 时 status 必须为 retired。预期：chk_retired_status_consistency 约束失败。
UPDATE Component
SET status = 'available', is_retired = TRUE
WHERE component_no = 'ENG-003';

-- 测试11：部件型号与飞机型号不匹配时禁止安装。
-- 请将以下整段作为一个测试执行；INSERT 预期失败并返回清晰错误，随后单独执行 ROLLBACK。
START TRANSACTION;

UPDATE Aircraft
SET aircraft_model = 'B737'
WHERE aircraft_no = 'AC-1002';

INSERT INTO InstallationRecord (
    component_id, aircraft_id, position_id, install_position, install_time, uninstall_time,
    install_reason, uninstall_reason, operator_id, uninstall_operator_id
)
SELECT
    c.component_id, a.aircraft_id, aip.position_id, aip.position_code, '2025-06-13 09:00:00', NULL,
    'aircraft model compatibility test', NULL, 1, NULL
FROM Component c
JOIN Aircraft a ON a.aircraft_no = 'AC-1002'
JOIN AircraftInstallPosition aip ON aip.aircraft_id = a.aircraft_id AND aip.position_code = 'left engine position'
WHERE c.component_no = 'ENG-003';

-- 预期错误：Component model is not compatible with the aircraft model.
ROLLBACK;

-- 测试12：retired 是终态，不能回到 available。预期：Illegal component status transition.
UPDATE Component
SET status = 'available', is_retired = FALSE
WHERE component_no = 'HYD-002';

-- 测试13：已完成的维修计划不能再次修改状态。
-- 先逐句执行前三句创建并完成计划；最后一条 UPDATE 预期失败。
INSERT INTO MaintenancePlan (
    component_id, planned_type, planned_time, planned_reason, status, created_by
)
SELECT component_id, 'status lock test', '2025-06-14 09:00:00',
       'verify completed plan status is immutable', 'pending', 2
FROM Component
WHERE component_no = 'ENG-003';

SET @completed_plan_id = LAST_INSERT_ID();

UPDATE MaintenancePlan
SET status = 'completed'
WHERE plan_id = @completed_plan_id;

UPDATE MaintenancePlan
SET status = 'cancelled'
WHERE plan_id = @completed_plan_id;

-- 测试14：已取消的维修计划不能再次修改状态。
-- 先逐句执行前三句创建并取消计划；最后一条 UPDATE 预期失败。
INSERT INTO MaintenancePlan (
    component_id, planned_type, planned_time, planned_reason, status, created_by
)
SELECT component_id, 'cancel lock test', '2025-06-15 09:00:00',
       'verify cancelled plan status is immutable', 'pending', 2
FROM Component
WHERE component_no = 'ENG-003';

SET @cancelled_plan_id = LAST_INSERT_ID();

UPDATE MaintenancePlan
SET status = 'cancelled'
WHERE plan_id = @cancelled_plan_id;

UPDATE MaintenancePlan
SET status = 'completed'
WHERE plan_id = @cancelled_plan_id;

-- 测试15：维修计划完成时间不能早于创建时间。
-- 预期：chk_plan_completed_after_created 约束失败。
INSERT INTO MaintenancePlan (
    component_id, planned_type, planned_time, planned_reason,
    status, created_by, created_at, completed_at
)
SELECT
    component_id, 'invalid time test', '2025-06-20 09:00:00',
    'completed_at earlier than created_at', 'completed', 2,
    '2025-06-19 10:00:00', '2025-06-19 09:00:00'
FROM Component
WHERE component_no = 'ENG-003';

-- 测试16：维修计划不能物理删除。
-- 前两句创建测试计划，DELETE 预期：Maintenance plan cannot be physically deleted.
INSERT INTO MaintenancePlan (
    component_id, planned_type, planned_time, planned_reason, status, created_by
)
SELECT component_id, 'delete protection test', '2025-06-21 09:00:00',
       'verify maintenance plan delete protection', 'pending', 2
FROM Component
WHERE component_no = 'ENG-003';

SET @delete_protected_plan_id = LAST_INSERT_ID();

DELETE FROM MaintenancePlan
WHERE plan_id = @delete_protected_plan_id;

-- 测试17：审计日志不能物理删除。
-- 前两句创建测试日志，DELETE 预期：Audit log cannot be physically deleted.
INSERT INTO AuditLog (
    operator_id, operation_type, target_table, target_id, operation_detail
)
VALUES (4, 'delete_protection_test', 'AuditLog', NULL, 'verify audit log delete protection');

SET @delete_protected_audit_id = LAST_INSERT_ID();

DELETE FROM AuditLog
WHERE audit_id = @delete_protected_audit_id;

-- 测试18：部件类别与安装位置允许类别必须一致。预期：Component category does not match installation position.
-- LDG-001 是 landing_gear 类，battery bay 只允许 battery 类。
INSERT INTO InstallationRecord (component_id, aircraft_id, position_id, install_position, install_time, uninstall_time, install_reason, uninstall_reason, operator_id, uninstall_operator_id)
VALUES (10, 1, 5, 'battery bay', '2025-06-22 09:00:00', NULL, 'category mismatch test', NULL, 1, NULL);
