-- =====================================================
-- 文件：07_indexes.sql
-- 作用：索引设计
-- 说明：用于提升生命周期追溯、当前有效安装、飞行统计、维修统计等查询效率
-- =====================================================
USE aviation_maintenance;

CREATE INDEX idx_component_status ON Component(status, is_retired);
CREATE INDEX idx_install_component_active ON InstallationRecord(component_id, uninstall_time);
CREATE INDEX idx_install_aircraft_position_active ON InstallationRecord(aircraft_id, install_position, uninstall_time);
CREATE INDEX idx_install_time_range ON InstallationRecord(install_time, uninstall_time);
CREATE INDEX idx_flight_aircraft_time ON FlightLog(aircraft_id, takeoff_time, landing_time);
CREATE INDEX idx_maintenance_component_time ON MaintenanceRecord(component_id, start_time, end_time);
CREATE INDEX idx_retirement_component_time ON RetirementRecord(component_id, retirement_time);

SHOW INDEX FROM Component;
SHOW INDEX FROM InstallationRecord;
SHOW INDEX FROM FlightLog;
SHOW INDEX FROM MaintenanceRecord;
