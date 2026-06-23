-- =====================================================
-- 文件：04_procedures.sql
-- 作用：事务 / 存储过程
-- 增强点：新增维修完成事务 sp_complete_maintenance
-- =====================================================
USE aviation_maintenance;

DELIMITER $$

-- 删除已存在的存储过程，避免重复创建冲突
DROP PROCEDURE IF EXISTS sp_replace_component$$
DROP PROCEDURE IF EXISTS sp_retire_component$$
DROP PROCEDURE IF EXISTS sp_start_maintenance_plan$$
DROP PROCEDURE IF EXISTS sp_complete_maintenance$$

-- =====================================================
-- 存储过程：组件更换
-- 功能描述：将飞机上某位置的旧组件替换为新组件
-- 参数说明：
--   p_old_component_no: 旧组件编号
--   p_new_component_no: 新组件编号
--   p_aircraft_no: 飞机编号
--   p_install_position: 安装位置代码
--   p_replace_time: 更换时间（可为NULL，默认当前时间）
--   p_operator_id: 操作员ID
--   p_uninstall_reason: 卸载原因
-- 事务特性：使用START TRANSACTION和COMMIT/ROLLBACK确保原子性
-- 业务规则：
--   1. 旧组件必须在指定飞机和位置上有有效安装记录
--   2. 新组件必须处于可安装状态（in_stock/available且未退役）
--   3. 新组件不能已有有效安装记录
--   4. 同一组件不能替换自己
--   5. 自动创建卸载记录和新安装记录
--   6. 记录审计日志
-- =====================================================
CREATE PROCEDURE sp_replace_component(
    IN p_old_component_no VARCHAR(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci,
    IN p_new_component_no VARCHAR(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci,
    IN p_aircraft_no VARCHAR(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci,
    IN p_install_position VARCHAR(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci,
    IN p_replace_time DATETIME,
    IN p_operator_id INT,
    IN p_uninstall_reason VARCHAR(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci
)
BEGIN
    -- 声明变量用于存储查询结果
    DECLARE v_old_component_id INT;
    DECLARE v_new_component_id INT;
    DECLARE v_aircraft_id INT;
    DECLARE v_old_installation_id INT;
    DECLARE v_new_installation_id INT;
    DECLARE v_old_count INT DEFAULT 0;
    DECLARE v_new_count INT DEFAULT 0;
    DECLARE v_aircraft_count INT DEFAULT 0;
    DECLARE v_operator_count INT DEFAULT 0;
    DECLARE v_position_count INT DEFAULT 0;
    DECLARE v_position_id INT;
    DECLARE v_active_old_install_count INT DEFAULT 0;
    DECLARE v_active_new_install_count INT DEFAULT 0;
    DECLARE v_new_status VARCHAR(30);
    DECLARE v_new_is_retired BOOLEAN;
    DECLARE v_replace_time DATETIME;

    -- 异常处理：发生任何SQL异常时回滚事务并重新抛出错误
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    -- 设置更换时间为当前时间（如果未指定）
    SET v_replace_time = COALESCE(p_replace_time, NOW());
    START TRANSACTION;

    -- 验证旧组件是否存在
    SELECT COUNT(*) INTO v_old_count FROM Component WHERE component_no = p_old_component_no;
    IF v_old_count = 0 THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Old component does not exist.'; END IF;
    -- 锁定旧组件记录，防止并发修改
    SELECT component_id INTO v_old_component_id
    FROM Component
    WHERE component_no = p_old_component_no
    FOR UPDATE;

    -- 验证新组件是否存在
    SELECT COUNT(*) INTO v_new_count FROM Component WHERE component_no = p_new_component_no;
    IF v_new_count = 0 THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'New component does not exist.'; END IF;
    -- 锁定新组件记录，获取其状态和退役标志
    SELECT component_id, status, is_retired INTO v_new_component_id, v_new_status, v_new_is_retired
    FROM Component
    WHERE component_no = p_new_component_no
    FOR UPDATE;

    -- 规则：旧组件和新组件不能是同一个
    IF v_old_component_id = v_new_component_id THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Old component and new component cannot be the same.';
    END IF;

    -- 验证飞机是否存在
    SELECT COUNT(*) INTO v_aircraft_count FROM Aircraft WHERE aircraft_no = p_aircraft_no;
    IF v_aircraft_count = 0 THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Aircraft does not exist.'; END IF;
    -- 锁定飞机记录
    SELECT aircraft_id INTO v_aircraft_id
    FROM Aircraft
    WHERE aircraft_no = p_aircraft_no
    FOR UPDATE;

    -- 验证安装位置是否属于该飞机且处于激活状态
    SELECT COUNT(*) INTO v_position_count
    FROM AircraftInstallPosition
    WHERE aircraft_id = v_aircraft_id
      AND position_code = p_install_position
      AND is_active = TRUE;

    IF v_position_count = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Installation position does not exist for this aircraft.';
    END IF;

    -- 获取位置ID并锁定
    SELECT position_id INTO v_position_id
    FROM AircraftInstallPosition
    WHERE aircraft_id = v_aircraft_id
      AND position_code = p_install_position
      AND is_active = TRUE
    LIMIT 1
    FOR UPDATE;

    -- 验证操作员是否存在
    SELECT COUNT(*) INTO v_operator_count FROM Operator WHERE operator_id = p_operator_id;
    IF v_operator_count = 0 THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Operator does not exist.'; END IF;

    -- 验证旧组件在指定飞机和位置上是否有有效安装记录
    SELECT COUNT(*) INTO v_active_old_install_count
    FROM InstallationRecord
    WHERE component_id = v_old_component_id
      AND aircraft_id = v_aircraft_id
      AND position_id = v_position_id
      AND uninstall_time IS NULL
      AND install_time <= v_replace_time;

    IF v_active_old_install_count = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Old component has no active installation at the given aircraft and position.';
    END IF;

    -- 获取旧组件的安装记录ID并锁定
    SELECT installation_id INTO v_old_installation_id
    FROM InstallationRecord
    WHERE component_id = v_old_component_id
      AND aircraft_id = v_aircraft_id
      AND position_id = v_position_id
      AND uninstall_time IS NULL
      AND install_time <= v_replace_time
    LIMIT 1
    FOR UPDATE;

    -- 验证新组件是否可安装（状态必须为in_stock或available，且未退役）
    IF v_new_status NOT IN ('in_stock', 'available') OR v_new_is_retired = TRUE THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'New component is not installable.';
    END IF;

    -- 验证新组件没有其他有效的安装记录
    SELECT COUNT(*) INTO v_active_new_install_count
    FROM InstallationRecord
    WHERE component_id = v_new_component_id AND uninstall_time IS NULL;

    IF v_active_new_install_count > 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'New component already has an active installation record.';
    END IF;

    -- 执行更换操作：更新旧组件的卸载信息
    UPDATE InstallationRecord
    SET uninstall_time = v_replace_time,
        uninstall_reason = COALESCE(p_uninstall_reason, 'component replacement'),
        uninstall_operator_id = p_operator_id
    WHERE installation_id = v_old_installation_id;

    -- 插入新组件的安装记录
    INSERT INTO InstallationRecord (
        component_id, aircraft_id, position_id, install_position, install_time, uninstall_time,
        install_reason, uninstall_reason, operator_id, uninstall_operator_id
    ) VALUES (
        v_new_component_id, v_aircraft_id, v_position_id, p_install_position, v_replace_time, NULL,
        CONCAT('replacement for ', p_old_component_no), NULL, p_operator_id, NULL
    );

    -- 获取新安装记录的ID
    SET v_new_installation_id = LAST_INSERT_ID();

    -- 记录审计日志
    INSERT INTO AuditLog (
        operator_id, operation_type, target_table, target_id, operation_time, operation_detail
    ) VALUES (
        p_operator_id,
        'component_replacement',
        'InstallationRecord',
        v_new_installation_id,
        v_replace_time,
        CONCAT(
            'Replaced component ', p_old_component_no, ' with ', p_new_component_no,
            ' on aircraft ', p_aircraft_no, ' at ', p_install_position,
            '; closed installation_id=', v_old_installation_id
        )
    );

    -- 提交事务
    COMMIT;
END$$

-- =====================================================
-- 存储过程：组件退役
-- 功能描述：将组件标记为退役状态
-- 参数说明：
--   p_component_no: 组件编号
--   p_retirement_time: 退役时间（可为NULL，默认当前时间）
--   p_retirement_reason: 退役原因
--   p_approved_by: 审批人ID
--   p_remark: 备注信息
-- 事务特性：使用START TRANSACTION和COMMIT/ROLLBACK确保原子性
-- 业务规则：
--   1. 组件必须存在且未退役
--   2. 已安装的组件必须先卸载才能退役
--   3. 自动创建退役记录
--   4. 自动更新组件状态为retired
--   5. 触发器trg_after_insert_retirement会自动更新组件状态
--   6. 记录审计日志
-- =====================================================
CREATE PROCEDURE sp_retire_component(
    IN p_component_no VARCHAR(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci,
    IN p_retirement_time DATETIME,
    IN p_retirement_reason VARCHAR(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci,
    IN p_approved_by INT,
    IN p_remark TEXT CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci
)
BEGIN
    -- 声明变量
    DECLARE v_component_id INT;
    DECLARE v_component_count INT DEFAULT 0;
    DECLARE v_operator_count INT DEFAULT 0;
    DECLARE v_active_install_count INT DEFAULT 0;
    DECLARE v_component_status VARCHAR(30);
    DECLARE v_is_retired BOOLEAN;
    DECLARE v_retirement_time DATETIME;
    DECLARE v_retirement_id INT;

    -- 异常处理：发生任何SQL异常时回滚事务并重新抛出错误
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    -- 设置退役时间为当前时间（如果未指定）
    SET v_retirement_time = COALESCE(p_retirement_time, NOW());
    START TRANSACTION;

    -- 验证组件是否存在
    SELECT COUNT(*) INTO v_component_count FROM Component WHERE component_no = p_component_no;
    IF v_component_count = 0 THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Component does not exist.'; END IF;
    -- 锁定组件记录，获取其状态和退役标志
    SELECT component_id, status, is_retired INTO v_component_id, v_component_status, v_is_retired
    FROM Component
    WHERE component_no = p_component_no
    FOR UPDATE;

    -- 验证审批人是否存在
    SELECT COUNT(*) INTO v_operator_count FROM Operator WHERE operator_id = p_approved_by;
    IF v_operator_count = 0 THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Approver does not exist.'; END IF;

    -- 规则：组件不能已退役
    IF v_component_status = 'retired' OR v_is_retired = TRUE THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Component is already retired.';
    END IF;

    -- 规则：已安装的组件必须先卸载才能退役
    SELECT COUNT(*) INTO v_active_install_count
    FROM InstallationRecord
    WHERE component_id = v_component_id AND uninstall_time IS NULL;

    IF v_active_install_count > 0 OR v_component_status = 'installed' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Installed component must be uninstalled before retirement.';
    END IF;

    -- 插入退役记录（触发器trg_after_insert_retirement会自动更新组件状态为retired）
    INSERT INTO RetirementRecord (component_id, retirement_time, retirement_reason, approved_by, remark)
    VALUES (v_component_id, v_retirement_time, p_retirement_reason, p_approved_by, p_remark);

    -- 获取退役记录ID
    SET v_retirement_id = LAST_INSERT_ID();

    -- 记录审计日志
    INSERT INTO AuditLog (
        operator_id, operation_type, target_table, target_id, operation_time, operation_detail
    ) VALUES (
        p_approved_by,
        'component_retirement',
        'RetirementRecord',
        v_retirement_id,
        v_retirement_time,
        CONCAT('Retired component ', p_component_no, '; reason: ', p_retirement_reason)
    );

    -- 提交事务
    COMMIT;
END$$

-- =====================================================
-- 存储过程：开始执行维修计划
-- 功能描述：将待处理的维修计划转为执行状态，创建对应的维修记录
-- 参数说明：
--   p_plan_id: 维修计划ID
--   p_start_time: 开始时间（可为NULL，默认当前时间）
--   p_technician_id: 技术员ID
--   p_description: 维修描述
-- 事务特性：使用START TRANSACTION和COMMIT/ROLLBACK确保原子性
-- 业务规则：
--   1. 维修计划必须存在且状态为pending
--   2. 维修计划不能已关联维修记录（未开始）
--   3. 只有技术员(technician)角色才能开始执行
--   4. 自动创建维修记录（状态为pending）
--   5. 更新维修计划关联维修记录ID
--   6. 记录审计日志
-- =====================================================
CREATE PROCEDURE sp_start_maintenance_plan(
    IN p_plan_id INT,
    IN p_start_time DATETIME,
    IN p_technician_id INT,
    IN p_description TEXT CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci
)
BEGIN
    -- 声明变量
    DECLARE v_plan_count INT DEFAULT 0;
    DECLARE v_component_id INT;
    DECLARE v_component_no VARCHAR(50);
    DECLARE v_planned_type VARCHAR(50);
    DECLARE v_plan_status VARCHAR(30);
    DECLARE v_related_maintenance_id INT;
    DECLARE v_technician_count INT DEFAULT 0;
    DECLARE v_maintenance_id INT;
    DECLARE v_start_time DATETIME;

    -- 异常处理：发生任何SQL异常时回滚事务并重新抛出错误
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    -- 设置开始时间为当前时间（如果未指定）
    SET v_start_time = COALESCE(p_start_time, NOW());
    START TRANSACTION;

    -- 验证维修计划是否存在
    SELECT COUNT(*) INTO v_plan_count
    FROM MaintenancePlan
    WHERE plan_id = p_plan_id;

    IF v_plan_count = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Maintenance plan does not exist.';
    END IF;

    -- 锁定维修计划记录，获取详细信息
    SELECT mp.component_id, c.component_no, mp.planned_type,
           mp.status, mp.related_maintenance_id
    INTO v_component_id, v_component_no, v_planned_type,
         v_plan_status, v_related_maintenance_id
    FROM MaintenancePlan mp
    JOIN Component c ON mp.component_id = c.component_id
    WHERE mp.plan_id = p_plan_id
    FOR UPDATE;

    -- 规则：只有待处理状态的计划才能开始执行
    IF v_plan_status <> 'pending' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Only pending maintenance plans can be started.';
    END IF;

    -- 规则：计划不能已关联维修记录
    IF v_related_maintenance_id IS NOT NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Maintenance plan has already been started.';
    END IF;

    -- 验证操作员是否为技术员角色
    SELECT COUNT(*) INTO v_technician_count
    FROM Operator
    WHERE operator_id = p_technician_id
      AND role = 'technician';

    IF v_technician_count = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Only technician can start maintenance plan execution.';
    END IF;

    -- 创建维修记录（状态为pending）
    INSERT INTO MaintenanceRecord (
        component_id, maintenance_type, start_time, end_time,
        result, description, technician_id
    ) VALUES (
        v_component_id, v_planned_type, v_start_time, NULL,
        'pending', p_description, p_technician_id
    );

    -- 获取新创建的维修记录ID
    SET v_maintenance_id = LAST_INSERT_ID();

    -- 更新维修计划，关联维修记录ID
    UPDATE MaintenancePlan
    SET related_maintenance_id = v_maintenance_id
    WHERE plan_id = p_plan_id;

    -- 记录审计日志
    INSERT INTO AuditLog (
        operator_id, operation_type, target_table, target_id,
        operation_time, operation_detail
    ) VALUES (
        p_technician_id,
        'maintenance_plan_started',
        'MaintenancePlan',
        p_plan_id,
        v_start_time,
        CONCAT(
            'Started maintenance plan for component ', v_component_no,
            '; maintenance_id: ', v_maintenance_id,
            '; type: ', v_planned_type
        )
    );

    -- 提交事务
    COMMIT;
END$$

-- =====================================================
-- 存储过程：完成维修
-- 功能描述：完成待处理的维修记录，处理各种维修结果
-- 参数说明：
--   p_maintenance_id: 维修记录ID
--   p_end_time: 完成时间（可为NULL，默认当前时间）
--   p_result: 维修结果（passed/failed/scrapped）
--   p_description: 维修描述
--   p_approved_by: 审批人ID
--   p_retirement_reason: 退役原因（仅在scrapped时需要）
-- 事务特性：使用START TRANSACTION和COMMIT/ROLLBACK确保原子性
-- 业务规则：
--   1. 维修记录必须存在且状态为pending
--   2. 只有审批人(approver)角色才能完成维修
--   3. 结果必须为passed/failed/scrapped之一
--   4. 完成时间不能早于开始时间
--   5. scrapped结果要求组件必须已卸载
--   6. passed：组件恢复可用/已安装状态，飞机恢复活动状态
--   7. failed：创建返工计划，组件/飞机进入维护状态
--   8. scrapped：创建退役记录
--   9. 自动完成关联的维修计划
--   10. 记录审计日志
-- =====================================================
CREATE PROCEDURE sp_complete_maintenance(
    IN p_maintenance_id INT,
    IN p_end_time DATETIME,
    IN p_result VARCHAR(30) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci,
    IN p_description TEXT CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci,
    IN p_approved_by INT,
    IN p_retirement_reason VARCHAR(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci
)
BEGIN
    -- 声明变量
    DECLARE v_count INT DEFAULT 0;
    DECLARE v_component_id INT;
    DECLARE v_component_no VARCHAR(50);
    DECLARE v_start_time DATETIME;
    DECLARE v_old_result VARCHAR(30);
    DECLARE v_end_time DATETIME;
    DECLARE v_operator_count INT DEFAULT 0;
    DECLARE v_active_install_count INT DEFAULT 0;
    DECLARE v_rework_plan_id INT DEFAULT NULL;
    DECLARE v_related_plan_id INT DEFAULT NULL;
    DECLARE v_aircraft_id INT DEFAULT NULL;
    DECLARE v_aircraft_released INT DEFAULT 0;

    -- 异常处理：发生任何SQL异常时回滚事务并重新抛出错误
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    -- 设置完成时间为当前时间（如果未指定）
    SET v_end_time = COALESCE(p_end_time, NOW());
    START TRANSACTION;

    -- 验证维修记录是否存在
    SELECT COUNT(*) INTO v_count FROM MaintenanceRecord WHERE maintenance_id = p_maintenance_id;
    IF v_count = 0 THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Maintenance record does not exist.'; END IF;

    -- 锁定维修记录，获取组件信息
    SELECT mr.component_id, c.component_no, mr.start_time, mr.result
    INTO v_component_id, v_component_no, v_start_time, v_old_result
    FROM MaintenanceRecord mr
    JOIN Component c ON mr.component_id = c.component_id
    WHERE mr.maintenance_id = p_maintenance_id
    FOR UPDATE;

    -- 规则：只有待处理的维修记录才能完成
    IF v_old_result <> 'pending' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Only pending maintenance can be completed.';
    END IF;

    -- 规则：维修结果必须是三种之一
    IF p_result NOT IN ('passed', 'failed', 'scrapped') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Invalid maintenance result.';
    END IF;

    -- 规则：完成时间不能早于开始时间
    IF v_end_time < v_start_time THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'maintenance end_time cannot be earlier than start_time.';
    END IF;

    -- 验证操作员是否为审批人角色
    SELECT COUNT(*) INTO v_operator_count
    FROM Operator
    WHERE operator_id = p_approved_by
      AND role = 'approver';

    IF v_operator_count = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Only approver can approve maintenance completion';
    END IF;

    -- 检查组件当前是否有有效安装（用于后续逻辑判断）
    SELECT COUNT(*) INTO v_active_install_count
    FROM InstallationRecord
    WHERE component_id = v_component_id
      AND uninstall_time IS NULL;

    -- 规则：如果结果是scrapped，组件必须先卸载
    IF p_result = 'scrapped' AND v_active_install_count > 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Installed component must be uninstalled before scrapping.';
    END IF;

    -- 更新维修记录
    UPDATE MaintenanceRecord
    SET end_time = v_end_time,
        result = p_result,
        description = COALESCE(p_description, description)
    WHERE maintenance_id = p_maintenance_id;

    -- 根据不同的维修结果执行不同的业务逻辑
    IF p_result = 'passed' THEN
        -- 维修通过：组件恢复可用状态
        UPDATE Component
        SET status = IF(v_active_install_count > 0, 'installed', 'available')
        WHERE component_id = v_component_id
          AND is_retired = FALSE;

        -- 如果组件当前已安装，检查飞机是否可以恢复活动状态
        -- 条件：没有待处理的维修记录、没有超过维修周期的组件、没有达到设计寿命的组件
        IF v_active_install_count > 0 THEN
            SELECT MAX(aircraft_id) INTO v_aircraft_id
            FROM InstallationRecord
            WHERE component_id = v_component_id
              AND uninstall_time IS NULL;

            UPDATE Aircraft a
            SET a.service_status = 'active'
            WHERE a.aircraft_id = v_aircraft_id
              AND a.service_status = 'maintenance'
              AND NOT EXISTS (
                  -- 检查是否有其他组件有待处理的维修
                  SELECT 1
                  FROM InstallationRecord active_ir
                  JOIN MaintenanceRecord pending_mr
                    ON pending_mr.component_id = active_ir.component_id
                   AND pending_mr.result = 'pending'
                  WHERE active_ir.aircraft_id = a.aircraft_id
                    AND active_ir.uninstall_time IS NULL
              )
              AND NOT EXISTS (
                  -- 检查是否有其他组件超过维修周期
                  SELECT 1
                  FROM InstallationRecord active_ir
                  JOIN Component active_c ON active_ir.component_id = active_c.component_id
                  JOIN ComponentModel active_cm ON active_c.model_id = active_cm.model_id
                  LEFT JOIN (
                      SELECT component_id, MAX(end_time) AS last_passed_time
                      FROM MaintenanceRecord
                      WHERE result = 'passed' AND end_time IS NOT NULL
                      GROUP BY component_id
                  ) lpm ON lpm.component_id = active_c.component_id
                  WHERE active_ir.aircraft_id = a.aircraft_id
                    AND active_ir.uninstall_time IS NULL
                    AND (
                        SELECT COALESCE(SUM(fl.flight_hours), 0)
                        FROM InstallationRecord history_ir
                        JOIN FlightLog fl
                          ON fl.aircraft_id = history_ir.aircraft_id
                         AND fl.takeoff_time >= history_ir.install_time
                         AND (history_ir.uninstall_time IS NULL OR fl.landing_time <= history_ir.uninstall_time)
                        WHERE history_ir.component_id = active_c.component_id
                          AND (lpm.last_passed_time IS NULL OR fl.takeoff_time >= lpm.last_passed_time)
                    ) >= active_cm.maintenance_cycle_hours
              )
              AND NOT EXISTS (
                  -- 检查是否有其他组件达到设计寿命
                  SELECT 1
                  FROM InstallationRecord active_ir
                  JOIN Component active_c ON active_ir.component_id = active_c.component_id
                  JOIN ComponentModel active_cm ON active_c.model_id = active_cm.model_id
                  WHERE active_ir.aircraft_id = a.aircraft_id
                    AND active_ir.uninstall_time IS NULL
                    AND (
                        SELECT COALESCE(SUM(fl.flight_hours), 0)
                        FROM InstallationRecord history_ir
                        JOIN FlightLog fl
                          ON fl.aircraft_id = history_ir.aircraft_id
                         AND fl.takeoff_time >= history_ir.install_time
                         AND (history_ir.uninstall_time IS NULL OR fl.landing_time <= history_ir.uninstall_time)
                        WHERE history_ir.component_id = active_c.component_id
                    ) >= active_cm.design_life_hours
              );

            -- 如果飞机恢复活动状态，记录审计日志
            SET v_aircraft_released = ROW_COUNT();
            IF v_aircraft_released > 0 THEN
                INSERT INTO AuditLog (
                    operator_id, operation_type, target_table, target_id,
                    operation_time, operation_detail
                ) VALUES (
                    p_approved_by,
                    'maintenance_cycle_release',
                    'Aircraft',
                    v_aircraft_id,
                    v_end_time,
                    CONCAT('Aircraft returned to active service after approved maintenance for component ', v_component_no)
                );
            END IF;
        END IF;

    ELSEIF p_result = 'failed' THEN
        -- 维修失败：创建返工计划
        IF v_active_install_count > 0 THEN
            -- 如果组件已安装，飞机进入维护状态
            UPDATE Aircraft a
            JOIN InstallationRecord ir ON ir.aircraft_id = a.aircraft_id
            SET a.service_status = 'maintenance'
            WHERE ir.component_id = v_component_id
              AND ir.uninstall_time IS NULL
              AND a.service_status <> 'retired';
        ELSE
            -- 如果组件未安装，状态改为removed
            UPDATE Component
            SET status = 'removed'
            WHERE component_id = v_component_id
              AND is_retired = FALSE;
        END IF;

        -- 创建返工计划（在线检查失败时需要先卸载后再维修）
        INSERT INTO MaintenancePlan (
            component_id, planned_type, planned_time, planned_reason,
            status, created_by, related_maintenance_id
        )
        SELECT
            v_component_id,
            IF(v_active_install_count > 0, 'post_removal_inspection', 'repair'),
            v_end_time,
            IF(
                v_active_install_count > 0,
                'Online inspection failed; remove component before workshop maintenance',
                'Maintenance failed; rework is required'
            ),
            'pending',
            p_approved_by,
            p_maintenance_id
        WHERE NOT EXISTS (
            -- 避免重复创建相同的返工计划
            SELECT 1
            FROM MaintenancePlan
            WHERE component_id = v_component_id
              AND status = 'pending'
              AND planned_type = IF(v_active_install_count > 0, 'post_removal_inspection', 'repair')
        );

        -- 如果创建了返工计划，记录审计日志
        IF ROW_COUNT() > 0 THEN
            SET v_rework_plan_id = LAST_INSERT_ID();
            INSERT INTO AuditLog (
                operator_id, operation_type, target_table, target_id,
                operation_time, operation_detail
            ) VALUES (
                p_approved_by,
                'create_maintenance_plan',
                'MaintenancePlan',
                v_rework_plan_id,
                v_end_time,
                CONCAT('Created rework plan after failed maintenance for component ', v_component_no)
            );
        END IF;

    ELSEIF p_result = 'scrapped' THEN
        -- 维修报废：创建退役记录
        INSERT INTO RetirementRecord (component_id, retirement_time, retirement_reason, approved_by, remark)
        VALUES (v_component_id, v_end_time, COALESCE(p_retirement_reason, 'scrapped after maintenance'), p_approved_by, 'retired by sp_complete_maintenance');
        -- 触发器trg_after_insert_retirement会自动更新组件状态为retired
    END IF;

    -- 自动完成关联的维修计划
    SELECT MAX(plan_id) INTO v_related_plan_id
    FROM MaintenancePlan
    WHERE related_maintenance_id = p_maintenance_id
      AND status = 'pending';

    IF v_related_plan_id IS NOT NULL THEN
        UPDATE MaintenancePlan
        SET status = 'completed',
            completed_at = v_end_time
        WHERE plan_id = v_related_plan_id;

        -- 记录维修计划完成的审计日志
        INSERT INTO AuditLog (
            operator_id, operation_type, target_table, target_id,
            operation_time, operation_detail
        ) VALUES (
            p_approved_by,
            'maintenance_plan_completed',
            'MaintenancePlan',
            v_related_plan_id,
            v_end_time,
            CONCAT(
                'Completed maintenance plan for component ', v_component_no,
                '; maintenance_id: ', p_maintenance_id,
                '; result: ', p_result
            )
        );
    END IF;

    -- 记录维修完成的审计日志
    INSERT INTO AuditLog (
        operator_id, operation_type, target_table, target_id, operation_time, operation_detail
    ) VALUES (
        p_approved_by,
        'maintenance_completion',
        'MaintenanceRecord',
        p_maintenance_id,
        v_end_time,
        CONCAT('Completed maintenance for component ', v_component_no, '; result: ', p_result)
    );

    -- 提交事务
    COMMIT;
END$$

DELIMITER ;

-- 查询当前数据库中的所有存储过程和函数，用于验证创建结果
SELECT ROUTINE_NAME, ROUTINE_TYPE, CREATED
FROM INFORMATION_SCHEMA.ROUTINES
WHERE ROUTINE_SCHEMA = 'aviation_maintenance'
ORDER BY ROUTINE_NAME;