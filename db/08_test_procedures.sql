-- =====================================================
-- 文件：08_test_procedures.sql
-- 作用：事务测试脚本
-- 使用方式：建议一段一段运行，保存测试结果截图
-- =====================================================
USE aviation_maintenance;

-- 测试1：正常更换 ENG-001 -> ENG-002
CALL sp_replace_component(
    'ENG-001',
    'ENG-002',
    'AC-1001',
    'left engine position',
    '2025-06-01 09:00:00',
    1,
    'replacement test: old engine removed'
);

SELECT component_no, status, is_retired
FROM Component
WHERE component_no IN ('ENG-001', 'ENG-002');

SELECT ir.installation_id, c.component_no, a.aircraft_no, ir.install_position, ir.install_time, ir.uninstall_time, ir.install_reason, ir.uninstall_reason
FROM InstallationRecord ir
JOIN Component c ON ir.component_id = c.component_id
JOIN Aircraft a ON ir.aircraft_id = a.aircraft_id
WHERE c.component_no IN ('ENG-001', 'ENG-002')
ORDER BY ir.install_time;

-- 测试2：正常退役已拆卸的 ENG-001
CALL sp_retire_component(
    'ENG-001',
    '2025-06-02 10:00:00',
    'life limit reached after replacement',
    3,
    'retired through transaction procedure'
);

SELECT component_no, status, is_retired FROM Component WHERE component_no = 'ENG-001';

SELECT rr.retirement_id, c.component_no, rr.retirement_time, rr.retirement_reason, o.operator_name AS approved_by
FROM RetirementRecord rr
JOIN Component c ON rr.component_id = c.component_id
LEFT JOIN Operator o ON rr.approved_by = o.operator_id
WHERE c.component_no = 'ENG-001';

-- 测试3：非法退役安装中的 ENG-002，应失败
CALL sp_retire_component(
    'ENG-002',
    '2025-06-03 10:00:00',
    'illegal retirement test',
    3,
    'this should fail because ENG-002 is still installed'
);

-- 测试4：维修完成事务，NAV-002 pending -> passed -> available
CALL sp_complete_maintenance(
    3,
    '2025-05-28 16:00:00',
    'passed',
    'Navigation module repaired and test passed.',
    NULL,
    NULL
);

SELECT c.component_no, c.status, mr.maintenance_id, mr.result, mr.start_time, mr.end_time, mr.description
FROM Component c
JOIN MaintenanceRecord mr ON c.component_id = mr.component_id
WHERE c.component_no = 'NAV-002';

-- 测试5：安装中部件在线检查通过后仍保持 installed
SET @nav001_id = (
    SELECT component_id
    FROM Component
    WHERE component_no = 'NAV-001'
);

INSERT INTO MaintenanceRecord (
    component_id, maintenance_type, start_time, end_time, result, description, technician_id
)
VALUES (
    @nav001_id,
    'online inspection',
    '2025-06-04 09:00:00',
    NULL,
    'pending',
    'Online inspection for installed-state verification.',
    2
);

SET @online_maintenance_id = LAST_INSERT_ID();

CALL sp_complete_maintenance(
    @online_maintenance_id,
    '2025-06-04 11:00:00',
    'passed',
    'Online inspection passed while component remains installed.',
    NULL,
    NULL
);

-- 预期：NAV-001 的 status 仍为 installed，且仍有有效安装记录。
SELECT
    c.component_no,
    c.status,
    COUNT(ir.installation_id) AS active_installation_count
FROM Component c
LEFT JOIN InstallationRecord ir
    ON c.component_id = ir.component_id
   AND ir.uninstall_time IS NULL
WHERE c.component_no = 'NAV-001'
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

-- 测试8：新增待执行维修计划并查询待办视图
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
WHERE component_no = 'ENG-003';

SET @test_plan_id = LAST_INSERT_ID();

SELECT *
FROM v_pending_maintenance_plan
WHERE plan_id = @test_plan_id;

UPDATE MaintenancePlan
SET status = 'completed'
WHERE plan_id = @test_plan_id;

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
WHERE component_no = 'ENG-003';

SET @cancelled_trace_plan_id = LAST_INSERT_ID();

UPDATE MaintenancePlan
SET status = 'cancelled'
WHERE plan_id = @cancelled_trace_plan_id;

-- 预期：completed 与 cancelled 两条计划都仍可在全量视图中查询。
SELECT *
FROM v_maintenance_plan_detail
WHERE plan_id IN (@test_plan_id, @cancelled_trace_plan_id)
ORDER BY plan_id;

-- 测试9：查询包含计划、安装、维修和退役事件的生命周期总时间轴
SELECT
    component_no, event_time, event_type, event_title,
    event_detail, source_table, source_id
FROM v_component_full_timeline
WHERE component_no IN ('ENG-001', 'ENG-002', 'ENG-003', 'NAV-001', 'NAV-002')
ORDER BY component_no, event_time, source_table, source_id;
