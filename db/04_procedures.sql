-- =====================================================
-- 文件：04_procedures.sql
-- 作用：事务 / 存储过程
-- 增强点：新增维修完成事务 sp_complete_maintenance
-- =====================================================
USE aviation_maintenance;

DELIMITER $$

DROP PROCEDURE IF EXISTS sp_replace_component$$
DROP PROCEDURE IF EXISTS sp_retire_component$$
DROP PROCEDURE IF EXISTS sp_start_maintenance_plan$$
DROP PROCEDURE IF EXISTS sp_complete_maintenance$$

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

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    SET v_replace_time = COALESCE(p_replace_time, NOW());
    START TRANSACTION;

    SELECT COUNT(*) INTO v_old_count FROM Component WHERE component_no = p_old_component_no;
    IF v_old_count = 0 THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Old component does not exist.'; END IF;
    SELECT component_id INTO v_old_component_id
    FROM Component
    WHERE component_no = p_old_component_no
    FOR UPDATE;

    SELECT COUNT(*) INTO v_new_count FROM Component WHERE component_no = p_new_component_no;
    IF v_new_count = 0 THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'New component does not exist.'; END IF;
    SELECT component_id, status, is_retired INTO v_new_component_id, v_new_status, v_new_is_retired
    FROM Component
    WHERE component_no = p_new_component_no
    FOR UPDATE;

    IF v_old_component_id = v_new_component_id THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Old component and new component cannot be the same.';
    END IF;

    SELECT COUNT(*) INTO v_aircraft_count FROM Aircraft WHERE aircraft_no = p_aircraft_no;
    IF v_aircraft_count = 0 THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Aircraft does not exist.'; END IF;
    SELECT aircraft_id INTO v_aircraft_id
    FROM Aircraft
    WHERE aircraft_no = p_aircraft_no
    FOR UPDATE;

    SELECT COUNT(*) INTO v_position_count
    FROM AircraftInstallPosition
    WHERE aircraft_id = v_aircraft_id
      AND position_code = p_install_position
      AND is_active = TRUE;

    IF v_position_count = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Installation position does not exist for this aircraft.';
    END IF;

    SELECT position_id INTO v_position_id
    FROM AircraftInstallPosition
    WHERE aircraft_id = v_aircraft_id
      AND position_code = p_install_position
      AND is_active = TRUE
    LIMIT 1
    FOR UPDATE;

    SELECT COUNT(*) INTO v_operator_count FROM Operator WHERE operator_id = p_operator_id;
    IF v_operator_count = 0 THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Operator does not exist.'; END IF;

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

    SELECT installation_id INTO v_old_installation_id
    FROM InstallationRecord
    WHERE component_id = v_old_component_id
      AND aircraft_id = v_aircraft_id
      AND position_id = v_position_id
      AND uninstall_time IS NULL
      AND install_time <= v_replace_time
    LIMIT 1
    FOR UPDATE;

    IF v_new_status NOT IN ('in_stock', 'available') OR v_new_is_retired = TRUE THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'New component is not installable.';
    END IF;

    SELECT COUNT(*) INTO v_active_new_install_count
    FROM InstallationRecord
    WHERE component_id = v_new_component_id AND uninstall_time IS NULL;

    IF v_active_new_install_count > 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'New component already has an active installation record.';
    END IF;

    UPDATE InstallationRecord
    SET uninstall_time = v_replace_time,
        uninstall_reason = COALESCE(p_uninstall_reason, 'component replacement'),
        uninstall_operator_id = p_operator_id
    WHERE installation_id = v_old_installation_id;

    INSERT INTO InstallationRecord (
        component_id, aircraft_id, position_id, install_position, install_time, uninstall_time,
        install_reason, uninstall_reason, operator_id, uninstall_operator_id
    ) VALUES (
        v_new_component_id, v_aircraft_id, v_position_id, p_install_position, v_replace_time, NULL,
        CONCAT('replacement for ', p_old_component_no), NULL, p_operator_id, NULL
    );

    SET v_new_installation_id = LAST_INSERT_ID();

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

    COMMIT;
END$$

CREATE PROCEDURE sp_retire_component(
    IN p_component_no VARCHAR(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci,
    IN p_retirement_time DATETIME,
    IN p_retirement_reason VARCHAR(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci,
    IN p_approved_by INT,
    IN p_remark TEXT CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci
)
BEGIN
    DECLARE v_component_id INT;
    DECLARE v_component_count INT DEFAULT 0;
    DECLARE v_operator_count INT DEFAULT 0;
    DECLARE v_active_install_count INT DEFAULT 0;
    DECLARE v_component_status VARCHAR(30);
    DECLARE v_is_retired BOOLEAN;
    DECLARE v_retirement_time DATETIME;
    DECLARE v_retirement_id INT;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    SET v_retirement_time = COALESCE(p_retirement_time, NOW());
    START TRANSACTION;

    SELECT COUNT(*) INTO v_component_count FROM Component WHERE component_no = p_component_no;
    IF v_component_count = 0 THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Component does not exist.'; END IF;
    SELECT component_id, status, is_retired INTO v_component_id, v_component_status, v_is_retired
    FROM Component
    WHERE component_no = p_component_no
    FOR UPDATE;

    SELECT COUNT(*) INTO v_operator_count FROM Operator WHERE operator_id = p_approved_by;
    IF v_operator_count = 0 THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Approver does not exist.'; END IF;

    IF v_component_status = 'retired' OR v_is_retired = TRUE THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Component is already retired.';
    END IF;

    SELECT COUNT(*) INTO v_active_install_count
    FROM InstallationRecord
    WHERE component_id = v_component_id AND uninstall_time IS NULL;

    IF v_active_install_count > 0 OR v_component_status = 'installed' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Installed component must be uninstalled before retirement.';
    END IF;

    INSERT INTO RetirementRecord (component_id, retirement_time, retirement_reason, approved_by, remark)
    VALUES (v_component_id, v_retirement_time, p_retirement_reason, p_approved_by, p_remark);

    SET v_retirement_id = LAST_INSERT_ID();

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

    COMMIT;
END$$

CREATE PROCEDURE sp_start_maintenance_plan(
    IN p_plan_id INT,
    IN p_start_time DATETIME,
    IN p_technician_id INT,
    IN p_description TEXT CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci
)
BEGIN
    DECLARE v_plan_count INT DEFAULT 0;
    DECLARE v_component_id INT;
    DECLARE v_component_no VARCHAR(50);
    DECLARE v_planned_type VARCHAR(50);
    DECLARE v_plan_status VARCHAR(30);
    DECLARE v_related_maintenance_id INT;
    DECLARE v_technician_count INT DEFAULT 0;
    DECLARE v_maintenance_id INT;
    DECLARE v_start_time DATETIME;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    SET v_start_time = COALESCE(p_start_time, NOW());
    START TRANSACTION;

    SELECT COUNT(*) INTO v_plan_count
    FROM MaintenancePlan
    WHERE plan_id = p_plan_id;

    IF v_plan_count = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Maintenance plan does not exist.';
    END IF;

    SELECT mp.component_id, c.component_no, mp.planned_type,
           mp.status, mp.related_maintenance_id
    INTO v_component_id, v_component_no, v_planned_type,
         v_plan_status, v_related_maintenance_id
    FROM MaintenancePlan mp
    JOIN Component c ON mp.component_id = c.component_id
    WHERE mp.plan_id = p_plan_id
    FOR UPDATE;

    IF v_plan_status <> 'pending' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Only pending maintenance plans can be started.';
    END IF;

    IF v_related_maintenance_id IS NOT NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Maintenance plan has already been started.';
    END IF;

    SELECT COUNT(*) INTO v_technician_count
    FROM Operator
    WHERE operator_id = p_technician_id
      AND role = 'technician';

    IF v_technician_count = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Only technician can start maintenance plan execution.';
    END IF;

    INSERT INTO MaintenanceRecord (
        component_id, maintenance_type, start_time, end_time,
        result, description, technician_id
    ) VALUES (
        v_component_id, v_planned_type, v_start_time, NULL,
        'pending', p_description, p_technician_id
    );

    SET v_maintenance_id = LAST_INSERT_ID();

    UPDATE MaintenancePlan
    SET related_maintenance_id = v_maintenance_id
    WHERE plan_id = p_plan_id;

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

    COMMIT;
END$$

CREATE PROCEDURE sp_complete_maintenance(
    IN p_maintenance_id INT,
    IN p_end_time DATETIME,
    IN p_result VARCHAR(30) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci,
    IN p_description TEXT CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci,
    IN p_approved_by INT,
    IN p_retirement_reason VARCHAR(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci
)
BEGIN
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

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    SET v_end_time = COALESCE(p_end_time, NOW());
    START TRANSACTION;

    SELECT COUNT(*) INTO v_count FROM MaintenanceRecord WHERE maintenance_id = p_maintenance_id;
    IF v_count = 0 THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Maintenance record does not exist.'; END IF;

    SELECT mr.component_id, c.component_no, mr.start_time, mr.result
    INTO v_component_id, v_component_no, v_start_time, v_old_result
    FROM MaintenanceRecord mr
    JOIN Component c ON mr.component_id = c.component_id
    WHERE mr.maintenance_id = p_maintenance_id
    FOR UPDATE;

    IF v_old_result <> 'pending' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Only pending maintenance can be completed.';
    END IF;

    IF p_result NOT IN ('passed', 'failed', 'scrapped') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Invalid maintenance result.';
    END IF;

    IF v_end_time < v_start_time THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'maintenance end_time cannot be earlier than start_time.';
    END IF;

    SELECT COUNT(*) INTO v_operator_count
    FROM Operator
    WHERE operator_id = p_approved_by
      AND role = 'approver';

    IF v_operator_count = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Only approver can approve maintenance completion';
    END IF;

    SELECT COUNT(*) INTO v_active_install_count
    FROM InstallationRecord
    WHERE component_id = v_component_id
      AND uninstall_time IS NULL;

    IF p_result = 'scrapped' AND v_active_install_count > 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Installed component must be uninstalled before scrapping.';
    END IF;

    UPDATE MaintenanceRecord
    SET end_time = v_end_time,
        result = p_result,
        description = COALESCE(p_description, description)
    WHERE maintenance_id = p_maintenance_id;

    IF p_result = 'passed' THEN
        UPDATE Component
        SET status = IF(v_active_install_count > 0, 'installed', 'available')
        WHERE component_id = v_component_id
          AND is_retired = FALSE;
    ELSEIF p_result = 'failed' THEN
        IF v_active_install_count > 0 THEN
            UPDATE Aircraft a
            JOIN InstallationRecord ir ON ir.aircraft_id = a.aircraft_id
            SET a.service_status = 'maintenance'
            WHERE ir.component_id = v_component_id
              AND ir.uninstall_time IS NULL
              AND a.service_status <> 'retired';
        ELSE
            UPDATE Component
            SET status = 'removed'
            WHERE component_id = v_component_id
              AND is_retired = FALSE;
        END IF;

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
            SELECT 1
            FROM MaintenancePlan
            WHERE component_id = v_component_id
              AND status = 'pending'
              AND planned_type = IF(v_active_install_count > 0, 'post_removal_inspection', 'repair')
        );

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
        INSERT INTO RetirementRecord (component_id, retirement_time, retirement_reason, approved_by, remark)
        VALUES (v_component_id, v_end_time, COALESCE(p_retirement_reason, 'scrapped after maintenance'), p_approved_by, 'retired by sp_complete_maintenance');
    END IF;

    SELECT MAX(plan_id) INTO v_related_plan_id
    FROM MaintenancePlan
    WHERE related_maintenance_id = p_maintenance_id
      AND status = 'pending';

    IF v_related_plan_id IS NOT NULL THEN
        UPDATE MaintenancePlan
        SET status = 'completed',
            completed_at = v_end_time
        WHERE plan_id = v_related_plan_id;

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

    COMMIT;
END$$

DELIMITER ;

SELECT ROUTINE_NAME, ROUTINE_TYPE, CREATED
FROM INFORMATION_SCHEMA.ROUTINES
WHERE ROUTINE_SCHEMA = 'aviation_maintenance'
ORDER BY ROUTINE_NAME;
