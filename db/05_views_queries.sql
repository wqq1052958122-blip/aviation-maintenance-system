-- =====================================================
-- 文件：05_views_queries.sql
-- 作用：视图 + 复杂查询
-- 增强点：新增 v_component_profile，生命周期追溯更完整
-- =====================================================
USE aviation_maintenance;

-- 删除已存在的视图，避免重复创建冲突
DROP VIEW IF EXISTS v_component_full_timeline;
DROP VIEW IF EXISTS v_component_maintenance_due;
DROP VIEW IF EXISTS v_aircraft_component_replacement_stats;
DROP VIEW IF EXISTS v_component_maintenance_interval;
DROP VIEW IF EXISTS v_pending_maintenance_plan;
DROP VIEW IF EXISTS v_maintenance_plan_detail;
DROP VIEW IF EXISTS v_audit_log_detail;
DROP VIEW IF EXISTS v_component_life_warning;
DROP VIEW IF EXISTS v_retirement_reason_stats;
DROP VIEW IF EXISTS v_current_installation;
DROP VIEW IF EXISTS v_component_profile;
DROP VIEW IF EXISTS v_component_lifecycle;
DROP VIEW IF EXISTS v_component_flight_usage;
DROP VIEW IF EXISTS v_model_maintenance_stats;

-- =====================================================
-- 视图：当前安装状态
-- 功能描述：显示所有当前有效（未卸载）的组件安装记录
-- 用途：快速查看每架飞机每个位置安装了哪个组件
-- 包含字段：安装ID、组件编号、型号、类别、飞机编号、机型、
--           位置信息、安装时间、组件状态、安装员
-- =====================================================
CREATE VIEW v_current_installation AS
SELECT
    ir.installation_id,
    c.component_no,
    cm.model_code,
    cm.category,
    a.aircraft_no,
    a.aircraft_model,
    ir.position_id,
    ir.install_position,
    aip.position_name,
    aip.allowed_category,
    ir.install_time,
    c.status AS component_status,
    o.operator_name AS installer
FROM InstallationRecord ir
JOIN Component c ON ir.component_id = c.component_id
JOIN ComponentModel cm ON c.model_id = cm.model_id
JOIN Aircraft a ON ir.aircraft_id = a.aircraft_id
JOIN AircraftInstallPosition aip ON ir.position_id = aip.position_id
LEFT JOIN Operator o ON ir.operator_id = o.operator_id
WHERE ir.uninstall_time IS NULL;

-- =====================================================
-- 视图：组件完整档案
-- 功能描述：展示组件的完整信息，包括当前状态、当前位置和退役信息
-- 用途：组件全生命周期追溯的起点，可快速查看组件全貌
-- 包含字段：组件基本信息、当前安装位置、退役信息
-- 注意：一个组件只有一条记录，通过左连接获取最新状态
-- =====================================================
CREATE VIEW v_component_profile AS
SELECT
    c.component_id,
    c.component_no,
    cm.model_code,
    cm.category,
    c.batch_no,
    c.production_date,
    c.stock_in_time,
    c.status,
    c.is_retired,
    c.total_flight_hours AS stored_total_flight_hours,
    a.aircraft_no AS current_aircraft_no,
    ir.install_position AS current_install_position,
    aip.position_name AS current_position_name,
    aip.allowed_category AS current_position_allowed_category,
    ir.install_time AS current_install_time,
    rr.retirement_time,
    rr.retirement_reason,
    approver.operator_name AS retirement_approved_by
FROM Component c
JOIN ComponentModel cm ON c.model_id = cm.model_id
LEFT JOIN InstallationRecord ir ON c.component_id = ir.component_id AND ir.uninstall_time IS NULL
LEFT JOIN AircraftInstallPosition aip ON ir.position_id = aip.position_id
LEFT JOIN Aircraft a ON ir.aircraft_id = a.aircraft_id
LEFT JOIN RetirementRecord rr ON c.component_id = rr.component_id
LEFT JOIN Operator approver ON rr.approved_by = approver.operator_id;

-- =====================================================
-- 视图：组件生命周期事件
-- 功能描述：统一展示组件所有生命周期事件的时间线
-- 用途：组件全生命周期追溯，按时间顺序查看所有事件
-- 事件类型：入库(in_stock)、安装(installed)、卸载(removed)、
--           维修开始(maintenance_start)、维修结束(maintenance_end)、退役(retired)
-- 包含字段：组件编号、事件时间、事件类型、事件详情
-- =====================================================
CREATE VIEW v_component_lifecycle AS
SELECT c.component_no, c.stock_in_time AS event_time, 'in_stock' AS event_type,
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

-- =====================================================
-- 视图：组件飞行使用统计（权威飞行小时来源）
-- 功能描述：按安装时间区间关联FlightLog实时推导组件的飞行使用情况
-- 用途：计算组件实际飞行小时数，用于寿命计算和维护计划
-- 特点：不依赖Component.total_flight_hours冗余字段，保证数据准确性
-- 包含字段：组件编号、型号、类别、飞机编号、飞行次数、总飞行小时、
--           首次飞行时间、末次飞行时间
-- =====================================================
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

-- =====================================================
-- 视图：型号级别维修统计
-- 功能描述：按型号统计组件的维修情况
-- 用途：分析不同型号组件的维修频率和平均维修时长
-- 包含字段：型号代码、类别、组件数量、维修次数、平均维修小时数
-- =====================================================
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

-- =====================================================
-- 视图：组件维修间隔统计
-- 功能描述：计算已完成维修之间的时间间隔
-- 用途：分析部件与型号的维修可靠性和维修频率
-- 技术实现：使用LAG窗口函数获取上一次维修完成时间
-- 包含字段：维修ID、组件编号、型号、类别、维修类型、开始/结束时间、
--           维修结果、上次维修结束时间、维修间隔（小时）
-- =====================================================
CREATE VIEW v_component_maintenance_interval AS
SELECT
    history.maintenance_id,
    c.component_no,
    cm.model_code,
    cm.category,
    history.maintenance_type,
    history.start_time,
    history.end_time,
    history.result,
    history.previous_maintenance_end_time,
    CASE
        WHEN history.previous_maintenance_end_time IS NULL THEN NULL
        ELSE TIMESTAMPDIFF(
            HOUR,
            history.previous_maintenance_end_time,
            history.start_time
        )
    END AS maintenance_interval_hours
FROM (
    SELECT
        mr.*,
        LAG(mr.end_time) OVER (
            PARTITION BY mr.component_id
            ORDER BY mr.end_time, mr.maintenance_id
        ) AS previous_maintenance_end_time
    FROM MaintenanceRecord mr
    WHERE mr.end_time IS NOT NULL
) history
JOIN Component c ON history.component_id = c.component_id
JOIN ComponentModel cm ON c.model_id = cm.model_id;

-- =====================================================
-- 视图：飞机组件更换统计
-- 功能描述：按飞机与安装位置统计历史安装次数和部件更换次数
-- 用途：分析哪些位置最常更换组件，评估维护工作量
-- 包含字段：飞机编号、机型、位置信息、安装次数、卸载次数、更换次数、
--           首次安装时间、最近安装时间
-- 注意：更换次数 = 安装次数 - 1（第一次安装不算更换）
-- =====================================================
CREATE VIEW v_aircraft_component_replacement_stats AS
SELECT
    a.aircraft_no,
    a.aircraft_model,
    ir.position_id,
    ir.install_position,
    aip.position_name,
    aip.allowed_category AS category,
    COUNT(*) AS installation_count,
    SUM(CASE WHEN ir.uninstall_time IS NOT NULL THEN 1 ELSE 0 END) AS removal_count,
    GREATEST(COUNT(*) - 1, 0) AS replacement_count,
    MIN(ir.install_time) AS first_install_time,
    MAX(ir.install_time) AS latest_install_time
FROM InstallationRecord ir
JOIN Aircraft a ON ir.aircraft_id = a.aircraft_id
JOIN AircraftInstallPosition aip ON ir.position_id = aip.position_id
GROUP BY
    a.aircraft_no,
    a.aircraft_model,
    ir.position_id,
    ir.install_position,
    aip.position_name,
    aip.allowed_category;

-- =====================================================
-- 视图：组件维修到期状态
-- 功能描述：基于上一次通过维修后的实际飞行小时计算下次周期维修到期程度
-- 用途：预测哪些组件需要尽快安排维修
-- 技术实现：使用CTE（公共表表达式）计算上次通过维修时间
--           和自上次维修以来的飞行小时
-- 包含字段：组件编号、型号、维修周期、上次通过维修时间、
--           自上次维修飞行小时、剩余维修小时、使用率、到期等级
-- 等级说明：overdue（已超期）、due（即将到期≥90%）、
--           warning（警告≥70%）、normal（正常）
-- =====================================================
CREATE VIEW v_component_maintenance_due AS
WITH last_passed_maintenance AS (
    SELECT
        component_id,
        MAX(end_time) AS last_passed_maintenance_time
    FROM MaintenanceRecord
    WHERE result = 'passed'
      AND end_time IS NOT NULL
    GROUP BY component_id
),
hours_since_maintenance AS (
    SELECT
        c.component_id,
        COALESCE(SUM(fl.flight_hours), 0) AS hours_since_last_maintenance
    FROM Component c
    LEFT JOIN last_passed_maintenance lpm
        ON c.component_id = lpm.component_id
    LEFT JOIN InstallationRecord ir
        ON c.component_id = ir.component_id
    LEFT JOIN FlightLog fl
        ON fl.aircraft_id = ir.aircraft_id
       AND fl.takeoff_time >= ir.install_time
       AND (ir.uninstall_time IS NULL OR fl.landing_time <= ir.uninstall_time)
       AND (
           lpm.last_passed_maintenance_time IS NULL
           OR fl.takeoff_time >= lpm.last_passed_maintenance_time
       )
    GROUP BY c.component_id
)
SELECT
    c.component_no,
    cm.model_code,
    cm.category,
    cm.maintenance_cycle_hours,
    lpm.last_passed_maintenance_time,
    ROUND(COALESCE(hsm.hours_since_last_maintenance, 0), 2) AS hours_since_last_maintenance,
    ROUND(
        GREATEST(
            cm.maintenance_cycle_hours - COALESCE(hsm.hours_since_last_maintenance, 0),
            0
        ),
        2
    ) AS remaining_maintenance_hours,
    ROUND(
        COALESCE(hsm.hours_since_last_maintenance, 0) / cm.maintenance_cycle_hours,
        4
    ) AS maintenance_usage_ratio,
    CASE
        WHEN COALESCE(hsm.hours_since_last_maintenance, 0) >= cm.maintenance_cycle_hours THEN 'overdue'
        WHEN COALESCE(hsm.hours_since_last_maintenance, 0) / cm.maintenance_cycle_hours >= 0.9 THEN 'due'
        WHEN COALESCE(hsm.hours_since_last_maintenance, 0) / cm.maintenance_cycle_hours >= 0.7 THEN 'warning'
        ELSE 'normal'
    END AS maintenance_due_level
FROM Component c
JOIN ComponentModel cm ON c.model_id = cm.model_id
LEFT JOIN last_passed_maintenance lpm ON c.component_id = lpm.component_id
LEFT JOIN hours_since_maintenance hsm ON c.component_id = hsm.component_id
WHERE c.is_retired = FALSE;

-- =====================================================
-- 视图：组件寿命预警
-- 功能描述：基于实际飞行小时计算组件设计寿命使用情况
-- 用途：提前发现即将达到设计寿命的组件，安排更换或退役
-- 特点：只依赖v_component_flight_usage的推导值，不依赖可能未同步的冗余字段
-- 包含字段：组件编号、型号、类别、设计寿命、已使用小时、
--           剩余寿命、寿命使用率、预警等级
-- 等级说明：expired（已过期≥100%）、critical（临界≥90%）、
--           warning（警告≥70%）、normal（正常）
-- =====================================================
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
        WHEN COALESCE(usage_stats.used_hours, 0) / cm.design_life_hours >= 1.0 THEN 'expired'
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

-- =====================================================
-- 视图：退役原因统计
-- 功能描述：按退役原因分组统计退役数量
-- 用途：分析组件退役的主要原因，用于改进维护策略
-- 包含字段：退役原因、退役数量
-- =====================================================
CREATE VIEW v_retirement_reason_stats AS
SELECT
    retirement_reason,
    COUNT(*) AS retirement_count
FROM RetirementRecord
GROUP BY retirement_reason;

-- =====================================================
-- 视图：审计日志详情
-- 功能描述：展示审计日志的详细信息，关联操作员信息
-- 用途：系统操作审计和追溯
-- 包含字段：审计ID、操作时间、操作类型、目标表、目标ID、
--           操作详情、操作员ID、操作员姓名、操作员角色
-- =====================================================
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

-- =====================================================
-- 视图：维修计划详情
-- 功能描述：展示维修计划的完整信息，包括关联的维修记录
-- 用途：维修计划的统一查询和管理
-- 包含字段：计划ID、组件信息、计划类型、计划时间、原因、
--           状态、创建时间、完成时间、创建人、关联维修记录信息
-- =====================================================
CREATE VIEW v_maintenance_plan_detail AS
SELECT
    mp.plan_id,
    mp.component_id,
    c.component_no,
    cm.model_code,
    cm.category,
    mp.planned_type,
    mp.planned_time,
    mp.planned_reason,
    mp.status,
    mp.created_at,
    mp.completed_at,
    mp.created_by,
    o.operator_name AS created_by_name,
    mp.related_maintenance_id,
    mr.maintenance_type AS related_maintenance_type,
    mr.result AS related_maintenance_result
FROM MaintenancePlan mp
JOIN Component c ON mp.component_id = c.component_id
JOIN ComponentModel cm ON c.model_id = cm.model_id
LEFT JOIN Operator o ON mp.created_by = o.operator_id
LEFT JOIN MaintenanceRecord mr ON mp.related_maintenance_id = mr.maintenance_id;

-- =====================================================
-- 视图：待处理维修计划
-- 功能描述：只显示状态为pending的维修计划
-- 用途：快速查看所有待执行的维修计划
-- 包含字段：计划ID、组件编号、型号、类别、计划类型、计划时间、
--           原因、状态、创建时间、创建人、关联维修记录ID
-- =====================================================
CREATE VIEW v_pending_maintenance_plan AS
SELECT
    plan_id,
    component_no,
    model_code,
    category,
    planned_type,
    planned_time,
    planned_reason,
    status,
    created_at,
    created_by,
    created_by_name,
    related_maintenance_id
FROM v_maintenance_plan_detail
WHERE status = 'pending';

-- =====================================================
-- 视图：组件完整时间线
-- 功能描述：统一展示组件所有生命周期事件的完整时间线
-- 用途：组件的全生命周期追溯，比v_component_lifecycle更详细
-- 事件类型：stock_in（入库）、installation（安装）、
--           uninstallation（卸载）、maintenance_start（维修开始）、
--           maintenance_complete（维修完成）、retirement（退役）、
--           maintenance_plan_created（计划创建）、
--           maintenance_plan_completed/cancelled（计划完成/取消）
-- 包含字段：组件编号、事件时间、事件类型、事件标题、事件详情、
--           来源表、来源ID
-- 特点：比v_component_lifecycle更结构化，包含来源表引用
-- =====================================================
CREATE VIEW v_component_full_timeline AS
SELECT
    c.component_no,
    c.stock_in_time AS event_time,
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

-- =====================================================
-- 查询：显示当前数据库中所有视图
-- 用途：验证视图创建结果
-- =====================================================
SHOW FULL TABLES WHERE Table_type = 'VIEW';

-- =====================================================
-- 查询示例：当前安装状态
-- 用途：查看所有飞机当前安装的组件
-- =====================================================
SELECT * FROM v_current_installation ORDER BY aircraft_no, install_position;

-- =====================================================
-- 查询示例：组件完整档案
-- 用途：查看所有组件的完整信息
-- =====================================================
SELECT * FROM v_component_profile ORDER BY component_no;

-- =====================================================
-- 查询示例：组件生命周期（指定组件）
-- 用途：查看特定组件的所有生命周期事件
-- =====================================================
SELECT component_no, event_time, event_type, event_detail FROM v_component_lifecycle WHERE component_no IN ('HYD-001', 'ENG-001') ORDER BY component_no, event_time;

-- =====================================================
-- 查询示例：组件飞行使用统计（指定组件）
-- 用途：查看特定组件的飞行使用情况
-- =====================================================
SELECT * FROM v_component_flight_usage WHERE component_no IN ('ENG-001', 'ENG-002', 'HYD-001') ORDER BY component_no, aircraft_no;

-- =====================================================
-- 查询示例：型号级别维修统计
-- 用途：分析不同型号组件的维护情况
-- =====================================================
SELECT * FROM v_model_maintenance_stats ORDER BY maintenance_count DESC;

-- =====================================================
-- 查询示例：组件维修间隔
-- 用途：分析组件的维修频率
-- =====================================================
SELECT * FROM v_component_maintenance_interval ORDER BY component_no, end_time;

-- =====================================================
-- 查询示例：飞机组件更换统计
-- 用途：分析哪些位置组件更换最频繁
-- =====================================================
SELECT * FROM v_aircraft_component_replacement_stats ORDER BY replacement_count DESC, aircraft_no, install_position;

-- =====================================================
-- 查询示例：组件维修到期状态
-- 用途：查看哪些组件即将或已经超过维修周期
-- =====================================================
SELECT * FROM v_component_maintenance_due ORDER BY maintenance_usage_ratio DESC, component_no;

-- =====================================================
-- 查询示例：组件寿命预警
-- 用途：查看哪些组件接近或达到设计寿命
-- =====================================================
SELECT * FROM v_component_life_warning ORDER BY life_usage_ratio DESC, component_no;

-- =====================================================
-- 查询示例：退役原因统计
-- 用途：分析组件退役的主要原因
-- =====================================================
SELECT * FROM v_retirement_reason_stats ORDER BY retirement_count DESC, retirement_reason;

-- =====================================================
-- 查询示例：审计日志详情
-- 用途：查看系统操作审计记录
-- =====================================================
SELECT * FROM v_audit_log_detail ORDER BY operation_time DESC, audit_id DESC;

-- =====================================================
-- 查询示例：维修计划详情
-- 用途：查看所有维修计划的完整信息
-- =====================================================
SELECT * FROM v_maintenance_plan_detail ORDER BY created_at DESC, plan_id DESC;

-- =====================================================
-- 查询示例：待处理维修计划
-- 用途：查看所有待执行的维修计划
-- =====================================================
SELECT * FROM v_pending_maintenance_plan ORDER BY planned_time, plan_id;

-- =====================================================
-- 查询示例：组件完整时间线
-- 用途：查看组件的全生命周期事件时间线
-- =====================================================
SELECT * FROM v_component_full_timeline ORDER BY component_no, event_time, source_table, source_id;