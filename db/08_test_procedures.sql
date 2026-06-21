-- =====================================================
-- 文件：08_test_procedures.sql
-- 作用：事务测试脚本
-- 使用方式：建议一段一段运行，保存测试结果截图
-- =====================================================
USE aviation_maintenance;

-- 测试1：正常更换 ENG-004 -> ENG-005
CALL sp_replace_component(
    'ENG-004',
    'ENG-005',
    'AC-1007',
    'left engine position',
    '2025-06-01 09:00:00',
    1,
    'replacement test: old engine removed'
);

SELECT component_no, status, is_retired
FROM Component
WHERE component_no IN ('ENG-004', 'ENG-005');

SELECT ir.installation_id, c.component_no, a.aircraft_no, ir.install_position, ir.install_time, ir.uninstall_time, ir.install_reason, ir.uninstall_reason
FROM InstallationRecord ir
JOIN Component c ON ir.component_id = c.component_id
JOIN Aircraft a ON ir.aircraft_id = a.aircraft_id
WHERE c.component_no IN ('ENG-004', 'ENG-005')
ORDER BY ir.install_time;

-- 测试2：正常退役已拆卸的 ENG-004
CALL sp_retire_component(
    'ENG-004',
    '2025-06-02 10:00:00',
    'life limit reached after replacement',
    3,
    'retired through transaction procedure'
);

SELECT component_no, status, is_retired FROM Component WHERE component_no = 'ENG-004';

SELECT rr.retirement_id, c.component_no, rr.retirement_time, rr.retirement_reason, o.operator_name AS approved_by
FROM RetirementRecord rr
JOIN Component c ON rr.component_id = c.component_id
LEFT JOIN Operator o ON rr.approved_by = o.operator_id
WHERE c.component_no = 'ENG-004';

-- 测试3：非法退役安装中的 ENG-005，应失败
CALL sp_retire_component(
    'ENG-005',
    '2025-06-03 10:00:00',
    'illegal retirement test',
    3,
    'this should fail because ENG-005 is still installed'
);

-- 测试4：维修完成事务，NAV-007 pending -> passed -> available
SET @nav007_maintenance_id = (
    SELECT mr.maintenance_id
    FROM MaintenanceRecord mr
    JOIN Component c ON mr.component_id = c.component_id
    WHERE c.component_no = 'NAV-007' AND mr.result = 'pending'
    LIMIT 1
);
CALL sp_complete_maintenance(
    @nav007_maintenance_id,
    '2026-06-18 16:00:00',
    'passed',
    'Navigation module repaired and test passed.',
    3,
    NULL
);

SELECT c.component_no, c.status, mr.maintenance_id, mr.result, mr.start_time, mr.end_time, mr.description
FROM Component c
JOIN MaintenanceRecord mr ON c.component_id = mr.component_id
WHERE c.component_no = 'NAV-007';

-- 测试5：安装中部件在线检查通过后仍保持 installed
SET @online_maintenance_id = (
    SELECT mr.maintenance_id
    FROM MaintenanceRecord mr
    JOIN Component c ON mr.component_id = c.component_id
    WHERE c.component_no = 'NAV-005' AND mr.result = 'pending'
    LIMIT 1
);

CALL sp_complete_maintenance(
    @online_maintenance_id,
    '2026-06-18 18:00:00',
    'passed',
    'Online inspection passed while component remains installed.',
    3,
    NULL
);

-- 预期：NAV-005 的 status 仍为 installed，且仍有有效安装记录。
SELECT
    c.component_no,
    c.status,
    COUNT(ir.installation_id) AS active_installation_count
FROM Component c
LEFT JOIN InstallationRecord ir
    ON c.component_id = ir.component_id
   AND ir.uninstall_time IS NULL
WHERE c.component_no = 'NAV-005'
GROUP BY c.component_no, c.status;

-- 测试6：查询新增统计视图
SELECT
    component_no, aircraft_no, flight_count,
    calculated_total_flight_hours, first_flight_time, last_flight_time
FROM v_component_flight_usage
ORDER BY component_no, aircraft_no;

SELECT
    component_no, model_code, category, design_life_hours, used_hours,
    remaining_life_hours, life_usage_ratio, warning_level
FROM v_component_life_warning
ORDER BY life_usage_ratio DESC, component_no;

-- 验证寿命预警 used_hours 与 FlightLog + InstallationRecord 推导值一致。
-- stored_total_flight_hours 仅用于展示历史兼容字段，不参与预警计算。
SELECT
    lw.component_no,
    c.total_flight_hours AS stored_total_flight_hours,
    COALESCE(fu.derived_used_hours, 0) AS derived_used_hours,
    lw.used_hours AS warning_used_hours,
    CASE
        WHEN lw.used_hours = COALESCE(fu.derived_used_hours, 0) THEN 'matched'
        ELSE 'mismatched'
    END AS verification_result
FROM v_component_life_warning lw
JOIN Component c ON lw.component_no = c.component_no
LEFT JOIN (
    SELECT component_no, SUM(calculated_total_flight_hours) AS derived_used_hours
    FROM v_component_flight_usage
    GROUP BY component_no
) fu ON lw.component_no = fu.component_no
ORDER BY lw.component_no;

SELECT retirement_reason, retirement_count
FROM v_retirement_reason_stats
ORDER BY retirement_count DESC, retirement_reason;

-- 测试7：确认成功执行的存储过程已在同一事务内写入审计日志
SELECT
    audit_id, operator_id, operation_type, target_table, target_id,
    operation_time, operation_detail
FROM AuditLog
WHERE operation_type IN (
    'component_replacement',
    'component_retirement',
    'maintenance_completion'
)
ORDER BY audit_id;

SELECT *
FROM v_audit_log_detail
ORDER BY operation_time DESC, audit_id DESC;

-- 测试8：维修计划开始执行 -> 创建关联工单 -> 工单完成后计划自动完成。
INSERT INTO MaintenancePlan (
    component_id, planned_type, planned_time, planned_reason, status, created_by
)
SELECT
    component_id,
    'scheduled inspection',
    '2025-07-01 09:00:00',
    'procedure test maintenance plan',
    'pending',
    2
FROM Component
WHERE component_no = 'ENG-006';

SET @test_plan_id = LAST_INSERT_ID();

SELECT *
FROM v_pending_maintenance_plan
WHERE plan_id = @test_plan_id;

CALL sp_start_maintenance_plan(
    @test_plan_id,
    '2025-07-01 09:00:00',
    2,
    'Start work order from maintenance plan.'
);

SET @test_plan_maintenance_id = (
    SELECT related_maintenance_id FROM MaintenancePlan WHERE plan_id = @test_plan_id
);

CALL sp_complete_maintenance(
    @test_plan_maintenance_id,
    '2025-07-01 12:00:00',
    'passed',
    'Planned maintenance completed and passed.',
    3,
    NULL
);

INSERT INTO MaintenancePlan (
    component_id, planned_type, planned_time, planned_reason, status, created_by
)
SELECT
    component_id,
    'cancelled plan trace test',
    '2025-07-02 09:00:00',
    'verify cancelled plan remains traceable',
    'pending',
    2
FROM Component
WHERE component_no = 'ENG-006';

SET @cancelled_trace_plan_id = LAST_INSERT_ID();

UPDATE MaintenancePlan
SET status = 'cancelled'
WHERE plan_id = @cancelled_trace_plan_id;

-- 预期：completed 与 cancelled 两条计划都仍可在全量视图中查询。
SELECT *
FROM v_maintenance_plan_detail
WHERE plan_id IN (@test_plan_id, @cancelled_trace_plan_id)
ORDER BY plan_id;

-- 测试8.1：无效技师启动计划时，过程应回滚，不创建工单和启动审计。
INSERT INTO MaintenancePlan (
    component_id, planned_type, planned_time, planned_reason, status, created_by
)
SELECT component_id, 'repair', '2025-07-03 09:00:00',
       'rollback verification plan', 'pending', 2
FROM Component
WHERE component_no = 'ENG-006';

SET @rollback_plan_id = LAST_INSERT_ID();

-- 预期失败：Only technician can start maintenance plan execution.
CALL sp_start_maintenance_plan(
    @rollback_plan_id,
    '2025-07-03 09:00:00',
    3,
    'This execution must rollback.'
);

SELECT plan_id, status, related_maintenance_id
FROM MaintenancePlan
WHERE plan_id = @rollback_plan_id;

SELECT COUNT(*) AS unexpected_start_audit_count
FROM AuditLog
WHERE operation_type = 'maintenance_plan_started'
  AND target_id = @rollback_plan_id;

-- 测试9：查询包含计划、安装、维修和退役事件的生命周期总时间轴
SELECT
    component_no, event_time, event_type, event_title,
    event_detail, source_table, source_id
FROM v_component_full_timeline
WHERE component_no IN ('ENG-001', 'ENG-002', 'ENG-004', 'ENG-005', 'NAV-005', 'NAV-007')
ORDER BY component_no, event_time, source_table, source_id;

-- 测试10：创建安装中部件的在线检查，验证不需要先拆卸。
INSERT INTO MaintenanceRecord (
    component_id, maintenance_type, start_time, end_time,
    result, description, technician_id
)
SELECT component_id, 'online inspection', '2026-06-20 09:00:00', NULL,
       'pending', 'online inspection trigger verification', 2
FROM Component
WHERE component_no = 'NAV-006';

SET @new_online_maintenance_id = LAST_INSERT_ID();

CALL sp_complete_maintenance(
    @new_online_maintenance_id,
    '2026-06-20 10:00:00',
    'passed',
    'Online inspection passed.',
    3,
    NULL
);

-- 预期：NAV-006 仍为 installed，当前安装记录仍存在。
SELECT c.component_no, c.status, COUNT(ir.installation_id) AS active_installation_count
FROM Component c
LEFT JOIN InstallationRecord ir
  ON c.component_id = ir.component_id
 AND ir.uninstall_time IS NULL
WHERE c.component_no = 'NAV-006'
GROUP BY c.component_no, c.status;

-- 测试11：维修未通过不直接退役，而是进入 removed 并自动创建返修计划。
INSERT INTO MaintenanceRecord (
    component_id, maintenance_type, start_time, end_time,
    result, description, technician_id
)
SELECT component_id, 'repair', '2026-06-20 11:00:00', NULL,
       'pending', 'failed maintenance workflow verification', 2
FROM Component
WHERE component_no = 'ENG-006';

SET @failed_maintenance_id = LAST_INSERT_ID();

CALL sp_complete_maintenance(
    @failed_maintenance_id,
    '2026-06-20 12:00:00',
    'failed',
    'Maintenance did not pass; rework required.',
    3,
    NULL
);

SELECT component_no, status, is_retired
FROM Component
WHERE component_no = 'ENG-006';

SELECT plan_id, component_no, planned_type, status, related_maintenance_id
FROM v_maintenance_plan_detail
WHERE component_no = 'ENG-006'
  AND related_maintenance_id = @failed_maintenance_id;

-- 测试12：查看到寿部件、强制寿命检查计划和自动停场审计。
SELECT component_no, design_life_hours, used_hours, remaining_life_hours,
       life_usage_ratio, warning_level
FROM v_component_life_warning
WHERE warning_level = 'expired'
ORDER BY life_usage_ratio DESC;

SELECT plan_id, component_no, planned_type, planned_time, status
FROM v_maintenance_plan_detail
WHERE planned_type = 'life_limit_check'
ORDER BY planned_time DESC, plan_id DESC;

SELECT audit_id, operation_type, target_table, target_id, operation_time, operation_detail
FROM AuditLog
WHERE operation_type = 'life_limit_grounding'
ORDER BY operation_time DESC, audit_id DESC;

-- 测试13：事务内模拟一次“飞行后刚好到寿”，验证自动停场和强制计划。
-- 整段执行后会 ROLLBACK，不保留模拟数据。
START TRANSACTION;

SET @life_test_component_id = (
    SELECT ir.component_id
    FROM InstallationRecord ir
    JOIN Aircraft a ON ir.aircraft_id = a.aircraft_id
    WHERE ir.uninstall_time IS NULL
      AND a.service_status = 'active'
    ORDER BY ir.installation_id
    LIMIT 1
);

SET @life_test_aircraft_id = (
    SELECT aircraft_id
    FROM InstallationRecord
    WHERE component_id = @life_test_component_id
      AND uninstall_time IS NULL
    LIMIT 1
);

SET @life_test_model_id = (
    SELECT model_id FROM Component WHERE component_id = @life_test_component_id
);

SET @life_test_used_hours = (
    SELECT COALESCE(SUM(calculated_total_flight_hours), 0)
    FROM v_component_flight_usage
    WHERE component_no = (
        SELECT component_no FROM Component WHERE component_id = @life_test_component_id
    )
);

UPDATE ComponentModel
SET design_life_hours = FLOOR(@life_test_used_hours) + 1
WHERE model_id = @life_test_model_id;

INSERT INTO FlightLog (
    aircraft_id, mission_no, takeoff_time, landing_time,
    flight_hours, mission_type, recorded_by
)
VALUES (
    @life_test_aircraft_id,
    'FL-LIFE-LIMIT-TRANSACTION-TEST',
    '2026-06-19 09:00:00',
    '2026-06-19 10:00:00',
    1.00,
    'life limit workflow test',
    4
);

-- 预期：warning_level=expired、飞机状态=maintenance，并存在 pending life_limit_check。
SELECT component_no, design_life_hours, used_hours, life_usage_ratio, warning_level
FROM v_component_life_warning
WHERE component_no = (
    SELECT component_no FROM Component WHERE component_id = @life_test_component_id
);

SELECT aircraft_no, service_status
FROM Aircraft
WHERE aircraft_id = @life_test_aircraft_id;

SELECT component_no, planned_type, status, planned_reason
FROM v_maintenance_plan_detail
WHERE component_id = @life_test_component_id
  AND planned_type = 'life_limit_check'
  AND status = 'pending';

ROLLBACK;

-- 测试14：查询三类加分分析视图。
SELECT *
FROM v_component_maintenance_interval
ORDER BY component_no, end_time;

SELECT *
FROM v_aircraft_component_replacement_stats
ORDER BY replacement_count DESC, aircraft_no, install_position;

SELECT *
FROM v_component_maintenance_due
ORDER BY maintenance_usage_ratio DESC, component_no;
