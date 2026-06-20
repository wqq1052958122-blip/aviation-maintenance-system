-- =====================================================
-- 文件：07_indexes.sql
-- 作用：索引设计
-- 说明：用于提升生命周期追溯、当前有效安装、飞行统计、维修统计等查询效率
-- =====================================================
USE aviation_maintenance;

CREATE INDEX idx_component_status ON Component(status, is_retired);
CREATE INDEX idx_component_model_category ON ComponentModel(category);
CREATE INDEX idx_position_category ON AircraftInstallPosition(aircraft_id, allowed_category, is_active);
CREATE INDEX idx_install_component_active ON InstallationRecord(component_id, uninstall_time);
CREATE INDEX idx_install_aircraft_position_active ON InstallationRecord(aircraft_id, position_id, uninstall_time);
CREATE UNIQUE INDEX uq_install_active_component ON InstallationRecord(active_component_id);
CREATE UNIQUE INDEX uq_install_active_position ON InstallationRecord(active_aircraft_id, active_position_id);
CREATE INDEX idx_install_time_range ON InstallationRecord(install_time, uninstall_time);
CREATE INDEX idx_flight_aircraft_time ON FlightLog(aircraft_id, takeoff_time, landing_time);
CREATE INDEX idx_maintenance_component_time ON MaintenanceRecord(component_id, start_time, end_time);
CREATE INDEX idx_plan_status_time ON MaintenancePlan(status, planned_time);
CREATE INDEX idx_plan_component_status ON MaintenancePlan(component_id, status);
CREATE UNIQUE INDEX uq_plan_related_maintenance ON MaintenancePlan(related_maintenance_id);
CREATE INDEX idx_retirement_component_time ON RetirementRecord(component_id, retirement_time);
CREATE INDEX idx_audit_operation_time ON AuditLog(operation_time, operation_type);

SHOW INDEX FROM Component;
SHOW INDEX FROM InstallationRecord;
SHOW INDEX FROM FlightLog;
SHOW INDEX FROM MaintenanceRecord;
SHOW INDEX FROM MaintenancePlan;
SHOW INDEX FROM AuditLog;
