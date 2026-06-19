-- =====================================================
-- 文件：03_triggers.sql
-- 作用：数据库层非法操作拦截 + 状态自动更新
-- =====================================================
USE aviation_maintenance;

DELIMITER $$

DROP TRIGGER IF EXISTS trg_before_insert_installation$$
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
DROP TRIGGER IF EXISTS trg_before_delete_operator$$

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

    SELECT COUNT(*) INTO v_component_count FROM Component WHERE component_id = NEW.component_id;
    IF v_component_count = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Component does not exist.';
    END IF;

    SELECT status, is_retired INTO v_component_status, v_is_retired FROM Component WHERE component_id = NEW.component_id;

    IF v_component_status = 'retired' OR v_is_retired = TRUE THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Retired component cannot be installed.';
    END IF;

    IF v_component_status NOT IN ('in_stock', 'available') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Only in_stock or available components can be installed.';
    END IF;

    SELECT COUNT(*) INTO v_current_install_count
    FROM InstallationRecord
    WHERE component_id = NEW.component_id AND uninstall_time IS NULL;

    IF v_current_install_count > 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Component already has an active installation record.';
    END IF;

    SELECT COUNT(*) INTO v_aircraft_count FROM Aircraft WHERE aircraft_id = NEW.aircraft_id;
    IF v_aircraft_count = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Aircraft does not exist.';
    END IF;

    SELECT service_status INTO v_aircraft_status FROM Aircraft WHERE aircraft_id = NEW.aircraft_id;
    IF v_aircraft_status = 'retired' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Retired aircraft cannot accept new installation.';
    END IF;

    -- 新增：同一飞机同一安装位置不能同时存在多个有效安装记录
    SELECT COUNT(*) INTO v_position_active_count
    FROM InstallationRecord
    WHERE aircraft_id = NEW.aircraft_id
      AND install_position = NEW.install_position
      AND uninstall_time IS NULL;

    IF v_position_active_count > 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Aircraft position already has an active component.';
    END IF;

    IF NEW.uninstall_time IS NOT NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'New installation record should not have uninstall_time.';
    END IF;
END$$

CREATE TRIGGER trg_after_insert_installation
AFTER INSERT ON InstallationRecord
FOR EACH ROW
BEGIN
    IF NEW.uninstall_time IS NULL THEN
        UPDATE Component SET status = 'installed' WHERE component_id = NEW.component_id;
    END IF;
END$$

CREATE TRIGGER trg_before_update_installation
BEFORE UPDATE ON InstallationRecord
FOR EACH ROW
BEGIN
    IF NOT (OLD.component_id <=> NEW.component_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'component_id in installation history cannot be changed.';
    END IF;
    IF NOT (OLD.aircraft_id <=> NEW.aircraft_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'aircraft_id in installation history cannot be changed.';
    END IF;
    IF NOT (OLD.install_position <=> NEW.install_position) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'install_position in installation history cannot be changed.';
    END IF;
    IF NOT (OLD.install_time <=> NEW.install_time) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'install_time in installation history cannot be changed.';
    END IF;
    IF NOT (OLD.operator_id <=> NEW.operator_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'install operator in installation history cannot be changed.';
    END IF;

    IF OLD.uninstall_time IS NOT NULL THEN
        IF NOT (OLD.uninstall_time <=> NEW.uninstall_time)
           OR NOT (OLD.uninstall_reason <=> NEW.uninstall_reason)
           OR NOT (OLD.uninstall_operator_id <=> NEW.uninstall_operator_id) THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Closed installation record cannot be modified again.';
        END IF;
    END IF;

    IF NEW.uninstall_time IS NOT NULL AND NEW.uninstall_time < NEW.install_time THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'uninstall_time cannot be earlier than install_time.';
    END IF;
END$$

CREATE TRIGGER trg_after_update_installation
AFTER UPDATE ON InstallationRecord
FOR EACH ROW
BEGIN
    IF OLD.uninstall_time IS NULL AND NEW.uninstall_time IS NOT NULL THEN
        UPDATE Component SET status = 'removed'
        WHERE component_id = NEW.component_id AND status = 'installed';
    END IF;
END$$

CREATE TRIGGER trg_before_insert_maintenance
BEFORE INSERT ON MaintenanceRecord
FOR EACH ROW
BEGIN
    DECLARE v_component_count INT DEFAULT 0;
    DECLARE v_component_status VARCHAR(30);
    DECLARE v_is_retired BOOLEAN;
    DECLARE v_pending_maintenance_count INT DEFAULT 0;

    SELECT COUNT(*) INTO v_component_count FROM Component WHERE component_id = NEW.component_id;
    IF v_component_count = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Component does not exist.';
    END IF;

    SELECT status, is_retired INTO v_component_status, v_is_retired FROM Component WHERE component_id = NEW.component_id;

    IF v_component_status = 'retired' OR v_is_retired = TRUE THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Retired component cannot be maintained.';
    END IF;

    SELECT COUNT(*) INTO v_pending_maintenance_count
    FROM MaintenanceRecord
    WHERE component_id = NEW.component_id
      AND result = 'pending';

    IF v_pending_maintenance_count > 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Component already has a pending maintenance record.';
    END IF;

    IF NEW.end_time IS NOT NULL AND NEW.end_time < NEW.start_time THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'maintenance end_time cannot be earlier than start_time.';
    END IF;
END$$

CREATE TRIGGER trg_after_insert_maintenance
AFTER INSERT ON MaintenanceRecord
FOR EACH ROW
BEGIN
    IF NEW.result = 'pending' THEN
        UPDATE Component
        SET status = 'under_maintenance'
        WHERE component_id = NEW.component_id
          AND status NOT IN ('retired', 'installed');
    END IF;
END$$

CREATE TRIGGER trg_before_update_maintenance
BEFORE UPDATE ON MaintenanceRecord
FOR EACH ROW
BEGIN
    IF NOT (OLD.component_id <=> NEW.component_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'component_id in maintenance history cannot be changed.';
    END IF;
    IF NOT (OLD.start_time <=> NEW.start_time) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'maintenance start_time cannot be changed.';
    END IF;
    IF OLD.result <> 'pending' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Completed maintenance record cannot be modified again.';
    END IF;
    IF NEW.end_time IS NOT NULL AND NEW.end_time < NEW.start_time THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'maintenance end_time cannot be earlier than start_time.';
    END IF;
END$$

CREATE TRIGGER trg_before_insert_retirement
BEFORE INSERT ON RetirementRecord
FOR EACH ROW
BEGIN
    DECLARE v_component_count INT DEFAULT 0;
    DECLARE v_current_install_count INT DEFAULT 0;
    DECLARE v_component_status VARCHAR(30);
    DECLARE v_is_retired BOOLEAN;

    SELECT COUNT(*) INTO v_component_count FROM Component WHERE component_id = NEW.component_id;
    IF v_component_count = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Component does not exist.';
    END IF;

    SELECT status, is_retired INTO v_component_status, v_is_retired FROM Component WHERE component_id = NEW.component_id;
    IF v_component_status = 'retired' OR v_is_retired = TRUE THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Component is already retired.';
    END IF;

    SELECT COUNT(*) INTO v_current_install_count
    FROM InstallationRecord
    WHERE component_id = NEW.component_id AND uninstall_time IS NULL;

    IF v_current_install_count > 0 OR v_component_status = 'installed' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Installed component must be uninstalled before retirement.';
    END IF;
END$$

CREATE TRIGGER trg_after_insert_retirement
AFTER INSERT ON RetirementRecord
FOR EACH ROW
BEGIN
    UPDATE Component SET status = 'retired', is_retired = TRUE WHERE component_id = NEW.component_id;
END$$

CREATE TRIGGER trg_before_delete_aircraft BEFORE DELETE ON Aircraft FOR EACH ROW
BEGIN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Aircraft cannot be physically deleted.'; END$$
CREATE TRIGGER trg_before_delete_component_model BEFORE DELETE ON ComponentModel FOR EACH ROW
BEGIN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'ComponentModel cannot be physically deleted.'; END$$
CREATE TRIGGER trg_before_delete_component BEFORE DELETE ON Component FOR EACH ROW
BEGIN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Component cannot be physically deleted. Use retirement process instead.'; END$$
CREATE TRIGGER trg_before_delete_installation BEFORE DELETE ON InstallationRecord FOR EACH ROW
BEGIN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Installation history cannot be physically deleted.'; END$$
CREATE TRIGGER trg_before_delete_maintenance BEFORE DELETE ON MaintenanceRecord FOR EACH ROW
BEGIN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Maintenance record cannot be physically deleted.'; END$$
CREATE TRIGGER trg_before_delete_flight BEFORE DELETE ON FlightLog FOR EACH ROW
BEGIN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Flight log cannot be physically deleted.'; END$$
CREATE TRIGGER trg_before_delete_retirement BEFORE DELETE ON RetirementRecord FOR EACH ROW
BEGIN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Retirement record cannot be physically deleted.'; END$$
CREATE TRIGGER trg_before_delete_operator BEFORE DELETE ON Operator FOR EACH ROW
BEGIN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Operator record cannot be physically deleted.'; END$$

DELIMITER ;

SELECT TRIGGER_NAME, EVENT_MANIPULATION, EVENT_OBJECT_TABLE, ACTION_TIMING
FROM INFORMATION_SCHEMA.TRIGGERS
WHERE TRIGGER_SCHEMA = 'aviation_maintenance'
ORDER BY EVENT_OBJECT_TABLE, TRIGGER_NAME;
