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
INSERT INTO InstallationRecord (component_id, aircraft_id, install_position, install_time, uninstall_time, install_reason, uninstall_reason, operator_id, uninstall_operator_id)
VALUES (6, 1, 'illegal test position', '2025-06-10 09:00:00', NULL, 'illegal installation for retired component', NULL, 1, NULL);

-- 测试2：已安装部件不能重复安装。预期：Only in_stock or available components can be installed. 或 active installation 报错
INSERT INTO InstallationRecord (component_id, aircraft_id, install_position, install_time, uninstall_time, install_reason, uninstall_reason, operator_id, uninstall_operator_id)
VALUES (4, 2, 'navigation bay duplicate test', '2025-06-10 10:00:00', NULL, 'illegal duplicate installation', NULL, 1, NULL);

-- 测试3：同一飞机同一位置不能同时安装多个部件。预期：Aircraft position already has an active component.
-- ENG-003 是 in_stock，可安装；但 AC-1001 的 left engine position 已被 ENG-001 占用，若已执行更换测试则被 ENG-002 占用。
INSERT INTO InstallationRecord (component_id, aircraft_id, install_position, install_time, uninstall_time, install_reason, uninstall_reason, operator_id, uninstall_operator_id)
VALUES (3, 1, 'left engine position', '2025-06-10 11:00:00', NULL, 'illegal position conflict test', NULL, 1, NULL);

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
