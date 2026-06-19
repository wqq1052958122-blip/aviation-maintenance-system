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
