-- =====================================================
-- 文件：05_views_queries.sql
-- 作用：视图 + 复杂查询
-- 增强点：新增 v_component_profile，生命周期追溯更完整
-- =====================================================
USE aviation_maintenance;

DROP VIEW IF EXISTS v_component_full_timeline;
DROP VIEW IF EXISTS v_pending_maintenance_plan;
DROP VIEW IF EXISTS v_audit_log_detail;
DROP VIEW IF EXISTS v_component_life_warning;
DROP VIEW IF EXISTS v_retirement_reason_stats;
DROP VIEW IF EXISTS v_current_installation;
DROP VIEW IF EXISTS v_component_profile;
DROP VIEW IF EXISTS v_component_lifecycle;
DROP VIEW IF EXISTS v_component_flight_usage;
DROP VIEW IF EXISTS v_model_maintenance_stats;

CREATE VIEW v_current_installation AS
SELECT
    ir.installation_id,
    c.component_no,
    cm.model_code,
    cm.category,
    a.aircraft_no,
    a.aircraft_model,
    ir.install_position,
    ir.install_time,
    c.status AS component_status,
    o.operator_name AS installer
FROM InstallationRecord ir
JOIN Component c ON ir.component_id = c.component_id
JOIN ComponentModel cm ON c.model_id = cm.model_id
JOIN Aircraft a ON ir.aircraft_id = a.aircraft_id
LEFT JOIN Operator o ON ir.operator_id = o.operator_id
WHERE ir.uninstall_time IS NULL;

CREATE VIEW v_component_profile AS
SELECT
    c.component_id,
    c.component_no,
    cm.model_code,
    cm.category,
    c.batch_no,
    c.production_date,
    c.created_at AS stock_in_time,
    c.status,
    c.is_retired,
    c.total_flight_hours AS stored_total_flight_hours,
    a.aircraft_no AS current_aircraft_no,
    ir.install_position AS current_install_position,
    ir.install_time AS current_install_time,
    rr.retirement_time,
    rr.retirement_reason,
    approver.operator_name AS retirement_approved_by
FROM Component c
JOIN ComponentModel cm ON c.model_id = cm.model_id
LEFT JOIN InstallationRecord ir ON c.component_id = ir.component_id AND ir.uninstall_time IS NULL
LEFT JOIN Aircraft a ON ir.aircraft_id = a.aircraft_id
LEFT JOIN RetirementRecord rr ON c.component_id = rr.component_id
LEFT JOIN Operator approver ON rr.approved_by = approver.operator_id;

CREATE VIEW v_component_lifecycle AS
SELECT c.component_no, c.created_at AS event_time, 'in_stock' AS event_type,
       CONCAT('Component entered inventory. Model: ', cm.model_code, ', category: ', cm.category, ', batch: ', COALESCE(c.batch_no, 'N/A')) AS event_detail
FROM Component c JOIN ComponentModel cm ON c.model_id = cm.model_id
UNION ALL
SELECT c.component_no, ir.install_time AS event_time, 'installed' AS event_type,
       CONCAT('Installed on aircraft ', a.aircraft_no, ' at ', ir.install_position, '. Reason: ', COALESCE(ir.install_reason, 'N/A'), ', installer: ', COALESCE(o.operator_name, 'N/A')) AS event_detail
FROM InstallationRecord ir
JOIN Component c ON ir.component_id = c.component_id
JOIN Aircraft a ON ir.aircraft_id = a.aircraft_id
LEFT JOIN Operator o ON ir.operator_id = o.operator_id
UNION ALL
SELECT c.component_no, ir.uninstall_time AS event_time, 'removed' AS event_type,
       CONCAT('Removed from aircraft ', a.aircraft_no, ' at ', ir.install_position, '. Reason: ', COALESCE(ir.uninstall_reason, 'N/A'), ', remover: ', COALESCE(o.operator_name, 'N/A')) AS event_detail
FROM InstallationRecord ir
JOIN Component c ON ir.component_id = c.component_id
JOIN Aircraft a ON ir.aircraft_id = a.aircraft_id
LEFT JOIN Operator o ON ir.uninstall_operator_id = o.operator_id
WHERE ir.uninstall_time IS NOT NULL
UNION ALL
SELECT c.component_no, mr.start_time AS event_time, 'maintenance_start' AS event_type,
       CONCAT('Maintenance started. Type: ', mr.maintenance_type, ', technician: ', COALESCE(o.operator_name, 'N/A')) AS event_detail
FROM MaintenanceRecord mr
JOIN Component c ON mr.component_id = c.component_id
LEFT JOIN Operator o ON mr.technician_id = o.operator_id
UNION ALL
SELECT c.component_no, mr.end_time AS event_time, 'maintenance_end' AS event_type,
       CONCAT('Maintenance finished. Type: ', mr.maintenance_type, ', result: ', mr.result, ', description: ', COALESCE(mr.description, 'N/A')) AS event_detail
FROM MaintenanceRecord mr
JOIN Component c ON mr.component_id = c.component_id
WHERE mr.end_time IS NOT NULL
UNION ALL
SELECT c.component_no, rr.retirement_time AS event_time, 'retired' AS event_type,
       CONCAT('Component retired. Reason: ', rr.retirement_reason, ', approved by: ', COALESCE(o.operator_name, 'N/A')) AS event_detail
FROM RetirementRecord rr
JOIN Component c ON rr.component_id = c.component_id
LEFT JOIN Operator o ON rr.approved_by = o.operator_id;

CREATE VIEW v_component_flight_usage AS
SELECT
    c.component_no,
    cm.model_code,
    cm.category,
    a.aircraft_no,
    COUNT(fl.flight_id) AS flight_count,
    COALESCE(SUM(fl.flight_hours), 0) AS calculated_total_flight_hours,
    MIN(fl.takeoff_time) AS first_flight_time,
    MAX(fl.landing_time) AS last_flight_time
FROM Component c
JOIN ComponentModel cm ON c.model_id = cm.model_id
JOIN InstallationRecord ir ON c.component_id = ir.component_id
JOIN Aircraft a ON ir.aircraft_id = a.aircraft_id
LEFT JOIN FlightLog fl
    ON fl.aircraft_id = ir.aircraft_id
   AND fl.takeoff_time >= ir.install_time
   AND (ir.uninstall_time IS NULL OR fl.landing_time <= ir.uninstall_time)
GROUP BY c.component_no, cm.model_code, cm.category, a.aircraft_no;

CREATE VIEW v_model_maintenance_stats AS
SELECT
    cm.model_code,
    cm.category,
    COUNT(DISTINCT c.component_id) AS component_count,
    COUNT(mr.maintenance_id) AS maintenance_count,
    ROUND(AVG(CASE WHEN mr.end_time IS NOT NULL THEN TIMESTAMPDIFF(HOUR, mr.start_time, mr.end_time) ELSE NULL END), 2) AS avg_maintenance_hours
FROM ComponentModel cm
JOIN Component c ON cm.model_id = c.model_id
LEFT JOIN MaintenanceRecord mr ON c.component_id = mr.component_id
GROUP BY cm.model_code, cm.category;

CREATE VIEW v_component_life_warning AS
SELECT
    c.component_no,
    cm.model_code,
    cm.category,
    cm.design_life_hours,
    COALESCE(usage_stats.used_hours, 0) AS used_hours,
    ROUND(GREATEST(cm.design_life_hours - COALESCE(usage_stats.used_hours, 0), 0), 2) AS remaining_life_hours,
    ROUND(COALESCE(usage_stats.used_hours, 0) / cm.design_life_hours, 4) AS life_usage_ratio,
    CASE
        WHEN COALESCE(usage_stats.used_hours, 0) / cm.design_life_hours >= 0.9 THEN 'critical'
        WHEN COALESCE(usage_stats.used_hours, 0) / cm.design_life_hours >= 0.7 THEN 'warning'
        ELSE 'normal'
    END AS warning_level
FROM Component c
JOIN ComponentModel cm ON c.model_id = cm.model_id
LEFT JOIN (
    SELECT component_no, SUM(calculated_total_flight_hours) AS used_hours
    FROM v_component_flight_usage
    GROUP BY component_no
) usage_stats ON c.component_no = usage_stats.component_no;

CREATE VIEW v_retirement_reason_stats AS
SELECT
    retirement_reason,
    COUNT(*) AS retirement_count
FROM RetirementRecord
GROUP BY retirement_reason;

CREATE VIEW v_audit_log_detail AS
SELECT
    al.audit_id,
    al.operation_time,
    al.operation_type,
    al.target_table,
    al.target_id,
    al.operation_detail,
    al.operator_id,
    o.operator_name,
    o.role AS operator_role
FROM AuditLog al
LEFT JOIN Operator o ON al.operator_id = o.operator_id;

CREATE VIEW v_pending_maintenance_plan AS
SELECT
    mp.plan_id,
    c.component_no,
    cm.model_code,
    cm.category,
    mp.planned_type,
    mp.planned_time,
    mp.planned_reason,
    mp.status,
    mp.created_at,
    mp.created_by,
    o.operator_name AS created_by_name,
    mp.related_maintenance_id
FROM MaintenancePlan mp
JOIN Component c ON mp.component_id = c.component_id
JOIN ComponentModel cm ON c.model_id = cm.model_id
LEFT JOIN Operator o ON mp.created_by = o.operator_id
WHERE mp.status = 'pending';

CREATE VIEW v_component_full_timeline AS
SELECT
    c.component_no,
    c.created_at AS event_time,
    'stock_in' AS event_type,
    'Component entered inventory' AS event_title,
    CONCAT('Model: ', cm.model_code, ', category: ', cm.category, ', batch: ', COALESCE(c.batch_no, 'N/A')) AS event_detail,
    'Component' AS source_table,
    c.component_id AS source_id
FROM Component c
JOIN ComponentModel cm ON c.model_id = cm.model_id
UNION ALL
SELECT
    c.component_no,
    ir.install_time,
    'installation',
    'Component installed',
    CONCAT('Aircraft: ', a.aircraft_no, ', position: ', ir.install_position, ', reason: ', COALESCE(ir.install_reason, 'N/A')),
    'InstallationRecord',
    ir.installation_id
FROM InstallationRecord ir
JOIN Component c ON ir.component_id = c.component_id
JOIN Aircraft a ON ir.aircraft_id = a.aircraft_id
UNION ALL
SELECT
    c.component_no,
    ir.uninstall_time,
    'uninstallation',
    'Component removed',
    CONCAT('Aircraft: ', a.aircraft_no, ', position: ', ir.install_position, ', reason: ', COALESCE(ir.uninstall_reason, 'N/A')),
    'InstallationRecord',
    ir.installation_id
FROM InstallationRecord ir
JOIN Component c ON ir.component_id = c.component_id
JOIN Aircraft a ON ir.aircraft_id = a.aircraft_id
WHERE ir.uninstall_time IS NOT NULL
UNION ALL
SELECT
    c.component_no,
    mr.start_time,
    'maintenance_start',
    'Maintenance started',
    CONCAT('Type: ', mr.maintenance_type, ', technician: ', COALESCE(o.operator_name, 'N/A'), ', description: ', COALESCE(mr.description, 'N/A')),
    'MaintenanceRecord',
    mr.maintenance_id
FROM MaintenanceRecord mr
JOIN Component c ON mr.component_id = c.component_id
LEFT JOIN Operator o ON mr.technician_id = o.operator_id
UNION ALL
SELECT
    c.component_no,
    mr.end_time,
    'maintenance_complete',
    'Maintenance completed',
    CONCAT('Type: ', mr.maintenance_type, ', result: ', mr.result, ', description: ', COALESCE(mr.description, 'N/A')),
    'MaintenanceRecord',
    mr.maintenance_id
FROM MaintenanceRecord mr
JOIN Component c ON mr.component_id = c.component_id
WHERE mr.end_time IS NOT NULL
UNION ALL
SELECT
    c.component_no,
    rr.retirement_time,
    'retirement',
    'Component retired',
    CONCAT('Reason: ', rr.retirement_reason, ', approved by: ', COALESCE(o.operator_name, 'N/A')),
    'RetirementRecord',
    rr.retirement_id
FROM RetirementRecord rr
JOIN Component c ON rr.component_id = c.component_id
LEFT JOIN Operator o ON rr.approved_by = o.operator_id
UNION ALL
SELECT
    c.component_no,
    mp.created_at,
    'maintenance_plan_created',
    'Maintenance plan created',
    CONCAT('Type: ', mp.planned_type, ', planned time: ', DATE_FORMAT(mp.planned_time, '%Y-%m-%d %H:%i:%s'), ', reason: ', COALESCE(mp.planned_reason, 'N/A')),
    'MaintenancePlan',
    mp.plan_id
FROM MaintenancePlan mp
JOIN Component c ON mp.component_id = c.component_id
UNION ALL
SELECT
    c.component_no,
    mp.completed_at,
    CONCAT('maintenance_plan_', mp.status),
    CASE mp.status
        WHEN 'completed' THEN 'Maintenance plan completed'
        ELSE 'Maintenance plan cancelled'
    END,
    CONCAT('Type: ', mp.planned_type, ', status: ', mp.status, ', related maintenance ID: ', COALESCE(CAST(mp.related_maintenance_id AS CHAR), 'N/A')),
    'MaintenancePlan',
    mp.plan_id
FROM MaintenancePlan mp
JOIN Component c ON mp.component_id = c.component_id
WHERE mp.status IN ('completed', 'cancelled');

SHOW FULL TABLES WHERE Table_type = 'VIEW';

SELECT * FROM v_current_installation ORDER BY aircraft_no, install_position;
SELECT * FROM v_component_profile ORDER BY component_no;
SELECT component_no, event_time, event_type, event_detail FROM v_component_lifecycle WHERE component_no IN ('HYD-001', 'ENG-001') ORDER BY component_no, event_time;
SELECT * FROM v_component_flight_usage WHERE component_no IN ('ENG-001', 'ENG-002', 'HYD-001') ORDER BY component_no, aircraft_no;
SELECT * FROM v_model_maintenance_stats ORDER BY maintenance_count DESC;
SELECT * FROM v_component_life_warning ORDER BY life_usage_ratio DESC, component_no;
SELECT * FROM v_retirement_reason_stats ORDER BY retirement_count DESC, retirement_reason;
SELECT * FROM v_audit_log_detail ORDER BY operation_time DESC, audit_id DESC;
SELECT * FROM v_pending_maintenance_plan ORDER BY planned_time, plan_id;
SELECT * FROM v_component_full_timeline ORDER BY component_no, event_time, source_table, source_id;
