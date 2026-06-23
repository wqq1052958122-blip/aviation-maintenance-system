-- =====================================================
-- 文件：03_triggers.sql
-- 作用：数据库层非法操作拦截 + 状态自动更新
-- =====================================================
USE aviation_maintenance;

DELIMITER $$

-- 删除所有已存在的触发器，避免重复创建冲突
DROP TRIGGER IF EXISTS trg_before_insert_installation$$
DROP TRIGGER IF EXISTS trg_before_update_component_status$$
DROP TRIGGER IF EXISTS trg_before_update_aircraft_status$$
DROP TRIGGER IF EXISTS trg_before_insert_maintenance_plan$$
DROP TRIGGER IF EXISTS trg_before_update_maintenance_plan$$
DROP TRIGGER IF EXISTS trg_after_insert_installation$$
DROP TRIGGER IF EXISTS trg_before_update_installation$$
DROP TRIGGER IF EXISTS trg_after_update_installation$$
DROP TRIGGER IF EXISTS trg_before_insert_maintenance$$
DROP TRIGGER IF EXISTS trg_after_insert_maintenance$$
DROP TRIGGER IF EXISTS trg_before_update_maintenance$$
DROP TRIGGER IF EXISTS trg_before_insert_retirement$$
DROP TRIGGER IF EXISTS trg_after_insert_retirement$$
DROP TRIGGER IF EXISTS trg_before_delete_aircraft$$
DROP TRIGGER IF EXISTS trg_before_delete_component_model$$
DROP TRIGGER IF EXISTS trg_before_delete_component$$
DROP TRIGGER IF EXISTS trg_before_delete_installation$$
DROP TRIGGER IF EXISTS trg_before_delete_maintenance$$
DROP TRIGGER IF EXISTS trg_before_delete_flight$$
DROP TRIGGER IF EXISTS trg_before_delete_retirement$$
DROP TRIGGER IF EXISTS trg_before_delete_maintenance_plan$$
DROP TRIGGER IF EXISTS trg_before_delete_audit_log$$
DROP TRIGGER IF EXISTS trg_before_delete_operator$$
DROP TRIGGER IF EXISTS trg_before_insert_flight$$
DROP TRIGGER IF EXISTS trg_after_insert_flight$$
DROP TRIGGER IF EXISTS trg_before_update_flight$$
DROP TRIGGER IF EXISTS trg_after_insert_aircraft$$

-- =====================================================
-- 为在触发器启用前已由应用新增、但尚无安装位的飞机补齐标准位置。
-- 说明：此初始化操作用于数据迁移场景，确保所有飞机都有对应的安装位定义
-- =====================================================
INSERT INTO AircraftInstallPosition (
    aircraft_id, position_code, position_name, allowed_category, is_active
)
SELECT
    a.aircraft_id,
    p.position_code,
    p.position_name,
    p.allowed_category,
    TRUE
FROM Aircraft a
CROSS JOIN (
    SELECT 'left engine position' AS position_code, '左侧发动机' AS position_name, 'engine' AS allowed_category
    UNION ALL SELECT 'landing gear bay', '主起落架舱', 'landing_gear'
    UNION ALL SELECT 'avionics bay', '航电设备舱', 'avionics'
    UNION ALL SELECT 'navigation bay', '导航设备舱', 'navigation'
    UNION ALL SELECT 'hydraulic system bay', '液压系统舱', 'hydraulic'
    UNION ALL SELECT 'fuel control bay', '燃油控制舱', 'fuel'
    UNION ALL SELECT 'air conditioning bay', '空调系统舱', 'air_conditioning'
    UNION ALL SELECT 'brake assembly', '刹车组件位', 'brake'
    UNION ALL SELECT 'battery bay', '机载电源舱', 'battery'
) p
WHERE NOT EXISTS (
    SELECT 1
    FROM AircraftInstallPosition existing_position
    WHERE existing_position.aircraft_id = a.aircraft_id
      AND existing_position.position_code = p.position_code
)$$

-- =====================================================
-- 触发器：应用新增飞机后自动建立标准安装位
-- 触发时机：向Aircraft表插入记录之后
-- 作用：确保新增飞机自动拥有9个标准安装位置，使后续安装接口可立即使用
-- =====================================================
CREATE TRIGGER trg_after_insert_aircraft
AFTER INSERT ON Aircraft
FOR EACH ROW
BEGIN
    INSERT INTO AircraftInstallPosition (
        aircraft_id, position_code, position_name, allowed_category, is_active
    ) VALUES
        (NEW.aircraft_id, 'left engine position', '左侧发动机', 'engine', TRUE),
        (NEW.aircraft_id, 'landing gear bay', '主起落架舱', 'landing_gear', TRUE),
        (NEW.aircraft_id, 'avionics bay', '航电设备舱', 'avionics', TRUE),
        (NEW.aircraft_id, 'navigation bay', '导航设备舱', 'navigation', TRUE),
        (NEW.aircraft_id, 'hydraulic system bay', '液压系统舱', 'hydraulic', TRUE),
        (NEW.aircraft_id, 'fuel control bay', '燃油控制舱', 'fuel', TRUE),
        (NEW.aircraft_id, 'air conditioning bay', '空调系统舱', 'air_conditioning', TRUE),
        (NEW.aircraft_id, 'brake assembly', '刹车组件位', 'brake', TRUE),
        (NEW.aircraft_id, 'battery bay', '机载电源舱', 'battery', TRUE);
END$$

-- =====================================================
-- 触发器：组件状态转换合法性校验
-- 触发时机：更新Component表的status字段之前
-- 作用：强制组件状态转换必须符合预定义的状态转换规则表
--       非法转换会被拒绝并抛出异常
-- =====================================================
CREATE TRIGGER trg_before_update_component_status
BEFORE UPDATE ON Component
FOR EACH ROW
BEGIN
    DECLARE v_rule_count INT DEFAULT 0;

    -- 仅当状态字段发生变化时才校验
    IF NOT (OLD.status <=> NEW.status) THEN
        -- 查询状态转换规则表，检查从旧状态到新状态是否合法
        SELECT COUNT(*) INTO v_rule_count
        FROM ComponentStatusTransitionRule
        WHERE from_status = OLD.status
          AND to_status = NEW.status;

        -- 如果找不到合法转换规则，则拒绝更新
        IF v_rule_count = 0 THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Illegal component status transition.';
        END IF;
    END IF;
END$$

-- =====================================================
-- 触发器：飞机退役状态不可逆校验
-- 触发时机：更新Aircraft表的service_status字段之前
-- 作用：防止已退役的飞机重新启用（退役操作不可逆）
-- =====================================================
CREATE TRIGGER trg_before_update_aircraft_status
BEFORE UPDATE ON Aircraft
FOR EACH ROW
BEGIN
    IF OLD.service_status = 'retired'
       AND NEW.service_status <> 'retired' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Retired aircraft cannot return to service.';
    END IF;
END$$

-- =====================================================
-- 触发器：维修计划插入前的业务规则校验
-- 触发时机：向MaintenancePlan表插入记录之前
-- 作用：1) 确保关联的维修记录与计划属于同一组件
--       2) 已完成计划必须关联已完成的维修记录
-- =====================================================
CREATE TRIGGER trg_before_insert_maintenance_plan
BEFORE INSERT ON MaintenancePlan
FOR EACH ROW
BEGIN
    DECLARE v_related_component_count INT DEFAULT 0;
    DECLARE v_related_result VARCHAR(30) DEFAULT NULL;

    -- 规则1：如果计划关联了维修记录，必须确保属于同一组件
    IF NEW.related_maintenance_id IS NOT NULL THEN
        SELECT COUNT(*) INTO v_related_component_count
        FROM MaintenanceRecord
        WHERE maintenance_id = NEW.related_maintenance_id
          AND component_id = NEW.component_id;

        IF v_related_component_count = 0 THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Maintenance plan and related maintenance record must belong to the same component.';
        END IF;
    END IF;

    -- 规则2：状态为已完成(completed)的计划必须关联一个维修记录
    IF NEW.status = 'completed' THEN
        IF NEW.related_maintenance_id IS NULL THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Completed maintenance plan must reference a completed maintenance record.';
        END IF;

        -- 规则3：关联的维修记录必须已完成，不能是待处理状态
        SELECT result INTO v_related_result
        FROM MaintenanceRecord
        WHERE maintenance_id = NEW.related_maintenance_id;

        IF v_related_result = 'pending' THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Related maintenance record must be completed before the plan.';
        END IF;
    END IF;
END$$

-- =====================================================
-- 触发器：维修计划更新时的业务规则校验
-- 触发时机：更新MaintenancePlan表记录之前
-- 作用：1) 已完成或已取消的计划状态不可再变更
--       2) 待处理计划转为完成/取消时自动填充完成时间
--       3) 已开始的计划不可取消
--       4) 完成时间不能早于创建时间
--       5) 关联的维修记录必须与计划属于同一组件
--       6) 计划完成时关联的维修记录必须已完成
-- =====================================================
CREATE TRIGGER trg_before_update_maintenance_plan
BEFORE UPDATE ON MaintenancePlan
FOR EACH ROW
BEGIN
    DECLARE v_related_component_count INT DEFAULT 0;
    DECLARE v_related_result VARCHAR(30) DEFAULT NULL;

    -- 规则1：已完成或已取消的计划状态不可变更（终态保护）
    IF OLD.status IN ('completed', 'cancelled')
       AND NOT (OLD.status <=> NEW.status) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Completed or cancelled maintenance plan status cannot be changed.';
    END IF;

    -- 规则2：待处理计划转入完成或取消时，自动设置完成时间为当前时间
    IF OLD.status = 'pending'
       AND NEW.status IN ('completed', 'cancelled')
       AND NEW.completed_at IS NULL THEN
        SET NEW.completed_at = NOW();
    END IF;

    -- 规则3：已开始的计划（有关联维修记录）不可取消
    IF OLD.status = 'pending'
       AND OLD.related_maintenance_id IS NOT NULL
       AND NEW.status = 'cancelled' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Started maintenance plan cannot be cancelled.';
    END IF;

    -- 规则4：完成时间不能早于创建时间
    IF NEW.completed_at IS NOT NULL
       AND NEW.completed_at < NEW.created_at THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Maintenance plan completed_at cannot be earlier than created_at.';
    END IF;

    -- 规则5：更新时关联维修记录仍必须属于同一组件
    IF NEW.related_maintenance_id IS NOT NULL THEN
        SELECT COUNT(*) INTO v_related_component_count
        FROM MaintenanceRecord
        WHERE maintenance_id = NEW.related_maintenance_id
          AND component_id = NEW.component_id;

        IF v_related_component_count = 0 THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Maintenance plan and related maintenance record must belong to the same component.';
        END IF;
    END IF;

    -- 规则6：待处理计划转为已完成时，必须关联维修记录且该记录已完成
    IF OLD.status = 'pending' AND NEW.status = 'completed' THEN
        IF NEW.related_maintenance_id IS NULL THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Maintenance plan must be started before completion.';
        END IF;

        SELECT result INTO v_related_result
        FROM MaintenanceRecord
        WHERE maintenance_id = NEW.related_maintenance_id;

        IF v_related_result = 'pending' THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Related maintenance record must be completed before the plan.';
        END IF;
    END IF;
END$$

-- =====================================================
-- 触发器：安装记录插入前的综合业务规则校验
-- 触发时机：向InstallationRecord表插入记录之前
-- 作用：执行安装操作前的大量业务规则验证，确保数据完整性和业务合规性
--       包括：操作员权限、组件存在性、组件状态、装机状态、飞机存在性、
--       机型兼容性、安装位兼容性、位置独占性、设计寿命检查等
-- =====================================================
CREATE TRIGGER trg_before_insert_installation
BEFORE INSERT ON InstallationRecord
FOR EACH ROW
BEGIN
    DECLARE v_component_count INT DEFAULT 0;
    DECLARE v_aircraft_count INT DEFAULT 0;
    DECLARE v_current_install_count INT DEFAULT 0;
    DECLARE v_position_active_count INT DEFAULT 0;
    DECLARE v_component_status VARCHAR(30);
    DECLARE v_is_retired BOOLEAN;
    DECLARE v_aircraft_status VARCHAR(30);
    DECLARE v_aircraft_model VARCHAR(50);
    DECLARE v_applicable_aircraft_model VARCHAR(50);
    DECLARE v_installer_count INT DEFAULT 0;
    DECLARE v_position_count INT DEFAULT 0;
    DECLARE v_position_code VARCHAR(100);
    DECLARE v_position_allowed_category VARCHAR(50);
    DECLARE v_component_category VARCHAR(50);
    DECLARE v_design_life_hours DECIMAL(10,2) DEFAULT 0;
    DECLARE v_used_hours DECIMAL(12,2) DEFAULT 0;

    -- 规则1：只有安装员(installer)角色才能执行安装操作
    SELECT COUNT(*) INTO v_installer_count
    FROM Operator
    WHERE operator_id = NEW.operator_id
      AND role = 'installer';

    IF v_installer_count = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Only installer can perform installation';
    END IF;

    -- 规则2：组件必须存在
    SELECT COUNT(*) INTO v_component_count FROM Component WHERE component_id = NEW.component_id;
    IF v_component_count = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Component does not exist.';
    END IF;

    -- 获取组件状态信息
    SELECT status, is_retired INTO v_component_status, v_is_retired FROM Component WHERE component_id = NEW.component_id;

    -- 规则3：已退役组件不可安装
    IF v_component_status = 'retired' OR v_is_retired = TRUE THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Retired component cannot be installed.';
    END IF;

    -- 规则4：只有库存(in_stock)或可用(available)状态的组件才可安装
    IF v_component_status NOT IN ('in_stock', 'available') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Only in_stock or available components can be installed.';
    END IF;

    -- 规则5：组件不能有当前有效的安装记录（防止重复安装）
    SELECT COUNT(*) INTO v_current_install_count
    FROM InstallationRecord
    WHERE component_id = NEW.component_id AND uninstall_time IS NULL;

    IF v_current_install_count > 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Component already has an active installation record.';
    END IF;

    -- 规则6：飞机必须存在
    SELECT COUNT(*) INTO v_aircraft_count FROM Aircraft WHERE aircraft_id = NEW.aircraft_id;
    IF v_aircraft_count = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Aircraft does not exist.';
    END IF;

    -- 获取飞机状态和型号
    SELECT service_status, aircraft_model
    INTO v_aircraft_status, v_aircraft_model
    FROM Aircraft
    WHERE aircraft_id = NEW.aircraft_id;

    -- 获取组件的适用机型、类别和设计寿命
    SELECT cm.applicable_aircraft_model, cm.category, cm.design_life_hours
    INTO v_applicable_aircraft_model, v_component_category, v_design_life_hours
    FROM Component c
    JOIN ComponentModel cm ON c.model_id = cm.model_id
    WHERE c.component_id = NEW.component_id;

    -- 计算组件已使用的小时数（从历史安装记录关联飞行日志汇总）
    SELECT COALESCE(SUM(fl.flight_hours), 0)
    INTO v_used_hours
    FROM InstallationRecord ir
    LEFT JOIN FlightLog fl
      ON fl.aircraft_id = ir.aircraft_id
     AND fl.takeoff_time >= ir.install_time
     AND (ir.uninstall_time IS NULL OR fl.landing_time <= ir.uninstall_time)
    WHERE ir.component_id = NEW.component_id;

    -- 规则7：组件使用小时数不能超过设计寿命
    IF v_used_hours >= v_design_life_hours THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Component has reached its design life and cannot be installed.';
    END IF;

    -- 规则8：检查机型兼容性
    IF v_applicable_aircraft_model IS NOT NULL
       AND TRIM(v_applicable_aircraft_model) <> ''
       AND v_applicable_aircraft_model <> v_aircraft_model THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Component model is not compatible with the aircraft model.';
    END IF;

    -- 规则9：退役飞机不可接受新安装
    IF v_aircraft_status = 'retired' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Retired aircraft cannot accept new installation.';
    END IF;

    -- 规则10：安装位置必须属于该飞机且处于激活状态
    SELECT COUNT(*) INTO v_position_count
    FROM AircraftInstallPosition
    WHERE position_id = NEW.position_id
      AND aircraft_id = NEW.aircraft_id
      AND is_active = TRUE;

    IF v_position_count = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Installation position does not exist for this aircraft.';
    END IF;

    -- 获取位置代码和允许的类别
    SELECT position_code, allowed_category
    INTO v_position_code, v_position_allowed_category
    FROM AircraftInstallPosition
    WHERE position_id = NEW.position_id;

    -- 将位置代码填充到安装记录的install_position字段
    SET NEW.install_position = v_position_code;

    -- 规则11：组件类别必须匹配安装位置允许的类别
    IF v_component_category <> v_position_allowed_category THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Component category does not match installation position.';
    END IF;

    -- 规则12：同一飞机同一安装位置不能同时存在多个有效安装记录（位置独占性）
    SELECT COUNT(*) INTO v_position_active_count
    FROM InstallationRecord
    WHERE aircraft_id = NEW.aircraft_id
      AND position_id = NEW.position_id
      AND uninstall_time IS NULL;

    IF v_position_active_count > 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Aircraft position already has an active component.';
    END IF;

    -- 规则13：新增安装记录不应包含卸载时间
    IF NEW.uninstall_time IS NOT NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'New installation record should not have uninstall_time.';
    END IF;
END$$

-- =====================================================
-- 触发器：飞行记录插入前的综合业务规则校验
-- 触发时机：向FlightLog表插入记录之前
-- 作用：1) 验证飞机存在且为活动状态
--       2) 飞行时间不能早于飞机启用日期
--       3) 着陆时间不能在未来
--       4) 防止飞行时间重叠
--       5) 确保飞机所有安装位都已安装组件（配置完整性）
--       6) 检查是否有组件超过维修周期（安全飞行前置条件）
-- =====================================================
CREATE TRIGGER trg_before_insert_flight
BEFORE INSERT ON FlightLog
FOR EACH ROW
BEGIN
    DECLARE v_aircraft_count INT DEFAULT 0;
    DECLARE v_aircraft_status VARCHAR(30);
    DECLARE v_start_date DATE;
    DECLARE v_overlap_count INT DEFAULT 0;
    DECLARE v_missing_position_count INT DEFAULT 0;
    DECLARE v_overdue_component_count INT DEFAULT 0;

    -- 规则1：飞机必须存在
    SELECT COUNT(*) INTO v_aircraft_count
    FROM Aircraft
    WHERE aircraft_id = NEW.aircraft_id;

    IF v_aircraft_count = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Aircraft does not exist.';
    END IF;

    -- 获取飞机状态和启用日期
    SELECT service_status, start_date
    INTO v_aircraft_status, v_start_date
    FROM Aircraft
    WHERE aircraft_id = NEW.aircraft_id;

    -- 规则2：只有活动(active)状态的飞机才能记录飞行
    IF v_aircraft_status <> 'active' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Only active aircraft can record a completed flight.';
    END IF;

    -- 规则3：飞行时间不能早于飞机启用日期
    IF v_start_date IS NOT NULL AND DATE(NEW.takeoff_time) < v_start_date THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Flight time cannot be earlier than aircraft service start date.';
    END IF;

    -- 规则4：着陆时间不能在未来
    IF NEW.landing_time > NOW() THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Completed flight landing_time cannot be in the future.';
    END IF;

    -- 规则5：检查是否有重叠的飞行记录（同一飞机同一时间段不能有多次飞行）
    SELECT COUNT(*) INTO v_overlap_count
    FROM FlightLog
    WHERE aircraft_id = NEW.aircraft_id
      AND NEW.takeoff_time < landing_time
      AND NEW.landing_time > takeoff_time;

    IF v_overlap_count > 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Aircraft already has an overlapping flight log.';
    END IF;

    -- 规则6：飞机的所有激活安装位都必须已安装组件（配置完整性检查）
    SELECT COUNT(*) INTO v_missing_position_count
    FROM AircraftInstallPosition p
    WHERE p.aircraft_id = NEW.aircraft_id
      AND p.is_active = TRUE
      AND NOT EXISTS (
          SELECT 1
          FROM InstallationRecord ir
          WHERE ir.aircraft_id = NEW.aircraft_id
            AND ir.position_id = p.position_id
            AND ir.uninstall_time IS NULL
            AND ir.install_time <= NEW.takeoff_time
      );

    IF v_missing_position_count > 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Aircraft configuration is incomplete and cannot record a flight.';
    END IF;

    -- 规则7：检查是否有组件超过维修周期（从上次通过检查累计）
    SELECT COUNT(*) INTO v_overdue_component_count
    FROM InstallationRecord current_ir
    JOIN Component c ON current_ir.component_id = c.component_id
    JOIN ComponentModel cm ON c.model_id = cm.model_id
    LEFT JOIN (
        SELECT component_id, MAX(end_time) AS last_passed_time
        FROM MaintenanceRecord
        WHERE result = 'passed' AND end_time IS NOT NULL
        GROUP BY component_id
    ) lpm ON lpm.component_id = c.component_id
    WHERE current_ir.aircraft_id = NEW.aircraft_id
      AND current_ir.uninstall_time IS NULL
      AND current_ir.install_time <= NEW.takeoff_time
      AND (
          SELECT COALESCE(SUM(fl.flight_hours), 0)
          FROM InstallationRecord history_ir
          JOIN FlightLog fl
            ON fl.aircraft_id = history_ir.aircraft_id
           AND fl.takeoff_time >= history_ir.install_time
           AND (history_ir.uninstall_time IS NULL OR fl.landing_time <= history_ir.uninstall_time)
          WHERE history_ir.component_id = c.component_id
            AND (lpm.last_passed_time IS NULL OR fl.takeoff_time >= lpm.last_passed_time)
      ) >= cm.maintenance_cycle_hours;

    -- 如果有组件超过维修周期，拒绝本次飞行
    IF v_overdue_component_count > 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Aircraft has overdue scheduled maintenance and cannot record another flight.';
    END IF;
END$$

-- =====================================================
-- 触发器：飞行记录插入后的自动化维护计划生成和飞机状态更新
-- 触发时机：向FlightLog表插入记录之后
-- 作用：1) 当组件使用达到维修周期90%时，自动生成在线检查计划
--       2) 当组件使用达到维修周期时，自动将飞机转为维护状态
--       3) 当组件达到设计寿命时，自动生成寿命限制检查计划并停场
--       4) 记录相关的审计日志
-- =====================================================
CREATE TRIGGER trg_after_insert_flight
AFTER INSERT ON FlightLog
FOR EACH ROW
BEGIN
    DECLARE v_cycle_grounded INT DEFAULT 0;

    -- 第一部分：达到维修周期90%时提前生成在线检查计划
    -- 同一部件只保留一条待执行计划，避免重复生成
    INSERT INTO MaintenancePlan (
        component_id, planned_type, planned_time, planned_reason,
        status, created_by, related_maintenance_id
    )
    SELECT
        c.component_id,
        'online inspection',
        NEW.landing_time,
        CONCAT('Scheduled maintenance threshold reached after flight ', NEW.mission_no),
        'pending',
        NEW.recorded_by,
        NULL
    FROM InstallationRecord current_ir
    JOIN Component c ON current_ir.component_id = c.component_id
    JOIN ComponentModel cm ON c.model_id = cm.model_id
    LEFT JOIN (
        SELECT component_id, MAX(end_time) AS last_passed_time
        FROM MaintenanceRecord
        WHERE result = 'passed' AND end_time IS NOT NULL
        GROUP BY component_id
    ) lpm ON lpm.component_id = c.component_id
    WHERE current_ir.aircraft_id = NEW.aircraft_id
      AND current_ir.uninstall_time IS NULL
      AND NEW.takeoff_time >= current_ir.install_time
      AND (
          SELECT COALESCE(SUM(fl.flight_hours), 0)
          FROM InstallationRecord history_ir
          JOIN FlightLog fl
            ON fl.aircraft_id = history_ir.aircraft_id
           AND fl.takeoff_time >= history_ir.install_time
           AND (history_ir.uninstall_time IS NULL OR fl.landing_time <= history_ir.uninstall_time)
          WHERE history_ir.component_id = c.component_id
            AND (lpm.last_passed_time IS NULL OR fl.takeoff_time >= lpm.last_passed_time)
      ) >= cm.maintenance_cycle_hours * 0.9
      AND NOT EXISTS (
          SELECT 1
          FROM MaintenancePlan mp
          WHERE mp.component_id = c.component_id
            AND mp.planned_type = 'online inspection'
            AND mp.status = 'pending'
      );

    -- 第二部分：本次飞行后达到维修周期时立即停场
    -- 后续飞行由前置触发器（trg_before_insert_flight）拒绝
    UPDATE Aircraft a
    SET a.service_status = 'maintenance'
    WHERE a.aircraft_id = NEW.aircraft_id
      AND a.service_status = 'active'
      AND EXISTS (
          SELECT 1
          FROM InstallationRecord current_ir
          JOIN Component c ON current_ir.component_id = c.component_id
          JOIN ComponentModel cm ON c.model_id = cm.model_id
          LEFT JOIN (
              SELECT component_id, MAX(end_time) AS last_passed_time
              FROM MaintenanceRecord
              WHERE result = 'passed' AND end_time IS NOT NULL
              GROUP BY component_id
          ) lpm ON lpm.component_id = c.component_id
          WHERE current_ir.aircraft_id = NEW.aircraft_id
            AND current_ir.uninstall_time IS NULL
            AND NEW.takeoff_time >= current_ir.install_time
            AND (
                SELECT COALESCE(SUM(fl.flight_hours), 0)
                FROM InstallationRecord history_ir
                JOIN FlightLog fl
                  ON fl.aircraft_id = history_ir.aircraft_id
                 AND fl.takeoff_time >= history_ir.install_time
                 AND (history_ir.uninstall_time IS NULL OR fl.landing_time <= history_ir.uninstall_time)
                WHERE history_ir.component_id = c.component_id
                  AND (lpm.last_passed_time IS NULL OR fl.takeoff_time >= lpm.last_passed_time)
            ) >= cm.maintenance_cycle_hours
      );

    -- 记录维修周期停场的审计日志
    SET v_cycle_grounded = ROW_COUNT();
    IF v_cycle_grounded > 0 THEN
        INSERT INTO AuditLog (
            operator_id, operation_type, target_table, target_id,
            operation_time, operation_detail
        ) VALUES (
            NEW.recorded_by,
            'maintenance_cycle_grounding',
            'Aircraft',
            NEW.aircraft_id,
            NEW.landing_time,
            CONCAT('Aircraft moved to maintenance after flight ', NEW.mission_no, ' because an installed component reached its maintenance cycle')
        );
    END IF;

    -- 第三部分：组件达到设计寿命时生成寿命限制检查计划
    INSERT INTO MaintenancePlan (
        component_id,
        planned_type,
        planned_time,
        planned_reason,
        status,
        created_by,
        related_maintenance_id
    )
    SELECT
        c.component_id,
        'life_limit_check',
        NEW.landing_time,
        CONCAT('Component reached design life after flight ', NEW.mission_no),
        'pending',
        NEW.recorded_by,
        NULL
    FROM InstallationRecord current_ir
    JOIN Component c ON current_ir.component_id = c.component_id
    JOIN ComponentModel cm ON c.model_id = cm.model_id
    WHERE current_ir.aircraft_id = NEW.aircraft_id
      AND current_ir.uninstall_time IS NULL
      AND NEW.takeoff_time >= current_ir.install_time
      AND (
          SELECT COALESCE(SUM(fl.flight_hours), 0)
          FROM InstallationRecord history_ir
          JOIN FlightLog fl
            ON fl.aircraft_id = history_ir.aircraft_id
           AND fl.takeoff_time >= history_ir.install_time
           AND (history_ir.uninstall_time IS NULL OR fl.landing_time <= history_ir.uninstall_time)
          WHERE history_ir.component_id = c.component_id
      ) >= cm.design_life_hours
      AND NOT EXISTS (
          SELECT 1
          FROM MaintenancePlan mp
          WHERE mp.component_id = c.component_id
            AND mp.planned_type = 'life_limit_check'
            AND mp.status = 'pending'
      );

    -- 第四部分：达到设计寿命时立即将飞机转为维护状态（停场）
    UPDATE Aircraft a
    SET a.service_status = 'maintenance'
    WHERE a.aircraft_id = NEW.aircraft_id
      AND a.service_status = 'active'
      AND EXISTS (
          SELECT 1
          FROM InstallationRecord current_ir
          JOIN Component c ON current_ir.component_id = c.component_id
          JOIN ComponentModel cm ON c.model_id = cm.model_id
          WHERE current_ir.aircraft_id = NEW.aircraft_id
            AND current_ir.uninstall_time IS NULL
            AND NEW.takeoff_time >= current_ir.install_time
            AND (
                SELECT COALESCE(SUM(fl.flight_hours), 0)
                FROM InstallationRecord history_ir
                JOIN FlightLog fl
                  ON fl.aircraft_id = history_ir.aircraft_id
                 AND fl.takeoff_time >= history_ir.install_time
                 AND (history_ir.uninstall_time IS NULL OR fl.landing_time <= history_ir.uninstall_time)
                WHERE history_ir.component_id = c.component_id
            ) >= cm.design_life_hours
      );

    -- 记录设计寿命停场的审计日志
    IF ROW_COUNT() > 0 THEN
        INSERT INTO AuditLog (
            operator_id, operation_type, target_table, target_id,
            operation_time, operation_detail
        ) VALUES (
            NEW.recorded_by,
            'life_limit_grounding',
            'Aircraft',
            NEW.aircraft_id,
            NEW.landing_time,
            CONCAT('Aircraft moved to maintenance after flight ', NEW.mission_no, ' because an installed component reached design life')
        );
    END IF;
END$$

-- =====================================================
-- 触发器：阻止飞行日志更新
-- 触发时机：更新FlightLog表记录之前
-- 作用：飞行记录一旦创建便不可修改，保证飞行数据的历史真实性和审计合规性
-- =====================================================
CREATE TRIGGER trg_before_update_flight
BEFORE UPDATE ON FlightLog
FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Flight log cannot be modified.';
END$$

-- =====================================================
-- 触发器：安装完成后更新组件状态
-- 触发时机：向InstallationRecord表插入记录之后
-- 作用：当组件成功安装后，自动将组件状态更新为已安装(installed)
-- =====================================================
CREATE TRIGGER trg_after_insert_installation
AFTER INSERT ON InstallationRecord
FOR EACH ROW
BEGIN
    IF NEW.uninstall_time IS NULL THEN
        UPDATE Component SET status = 'installed' WHERE component_id = NEW.component_id;
    END IF;
END$$

-- =====================================================
-- 触发器：安装记录更新时的业务规则校验
-- 触发时机：更新InstallationRecord表记录之前
-- 作用：1) 核心字段不可变更（组件ID、飞机ID、安装位置、安装时间、安装操作员）
--       2) 只有安装员(installer)角色才能执行卸载操作
--       3) 已关闭的安装记录不可再次修改
--       4) 卸载时间不能早于安装时间
-- =====================================================
CREATE TRIGGER trg_before_update_installation
BEFORE UPDATE ON InstallationRecord
FOR EACH ROW
BEGIN
    DECLARE v_uninstaller_count INT DEFAULT 0;

    -- 规则1-5：核心字段不可变更，保护历史数据的完整性
    IF NOT (OLD.component_id <=> NEW.component_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'component_id in installation history cannot be changed.';
    END IF;
    IF NOT (OLD.aircraft_id <=> NEW.aircraft_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'aircraft_id in installation history cannot be changed.';
    END IF;
    IF NOT (OLD.install_position <=> NEW.install_position) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'install_position in installation history cannot be changed.';
    END IF;
    IF NOT (OLD.position_id <=> NEW.position_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'position_id in installation history cannot be changed.';
    END IF;
    IF NOT (OLD.install_time <=> NEW.install_time) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'install_time in installation history cannot be changed.';
    END IF;
    IF NOT (OLD.operator_id <=> NEW.operator_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'install operator in installation history cannot be changed.';
    END IF;

    -- 规则6：从有效安装转为卸载时，操作员必须是安装员角色
    IF OLD.uninstall_time IS NULL AND NEW.uninstall_time IS NOT NULL THEN
        SELECT COUNT(*) INTO v_uninstaller_count
        FROM Operator
        WHERE operator_id = NEW.uninstall_operator_id
          AND role = 'installer';

        IF v_uninstaller_count = 0 THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Only installer can perform uninstallation';
        END IF;
    END IF;

    -- 规则7：已关闭的安装记录（有卸载时间）不可再次修改
    IF OLD.uninstall_time IS NOT NULL THEN
        IF NOT (OLD.un