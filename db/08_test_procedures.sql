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
    component_no, model_code, category, design_life_hours, used_hours,
    remaining_life_hours, life_usage_ratio, warning_level
FROM v_component_life_warning
ORDER BY life_usage_ratio DESC, component_no;

SELECT retirement_reason, retirement_count
FROM v_retirement_reason_stats
ORDER BY retirement_count DESC, retirement_reason;
