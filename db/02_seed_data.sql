-- =====================================================
-- 文件：02_seed_data.sql
-- 作用：插入初始化测试数据
-- =====================================================
USE aviation_maintenance;

INSERT INTO Operator (operator_name, role, phone) VALUES
('Zhang Wei', 'installer', '13800000001'),
('Li Ming', 'technician', '13800000002'),
('Wang Fang', 'approver', '13800000003'),
('Chen Jie', 'admin', '13800000004');

INSERT INTO Aircraft (aircraft_no, aircraft_model, service_status, start_date) VALUES
('AC-1001', 'A320', 'active', '2024-01-10'),
('AC-1002', 'A320', 'active', '2024-03-15');

INSERT INTO ComponentModel (model_code, category, design_life_hours, maintenance_cycle_hours, applicable_aircraft_model) VALUES
('ENG-A100', 'engine', 5000, 500, 'A320'),
('NAV-X200', 'navigation', 3000, 300, 'A320'),
('HYD-P300', 'hydraulic', 2500, 250, 'A320');

INSERT INTO Component (component_no, model_id, batch_no, production_date, status, total_flight_hours, is_retired) VALUES
('ENG-001', 1, 'BATCH-E-01', '2023-10-01', 'installed', 100.00, FALSE),
('ENG-002', 1, 'BATCH-E-01', '2023-10-05', 'available', 20.00, FALSE),
('ENG-003', 1, 'BATCH-E-02', '2024-01-12', 'in_stock', 0.00, FALSE),
('NAV-001', 2, 'BATCH-N-01', '2023-11-20', 'installed', 80.00, FALSE),
('HYD-001', 3, 'BATCH-H-01', '2023-09-15', 'removed', 60.00, FALSE),
('HYD-002', 3, 'BATCH-H-01', '2023-09-18', 'retired', 300.00, TRUE),
('NAV-002', 2, 'BATCH-N-02', '2024-02-01', 'under_maintenance', 15.00, FALSE);

INSERT INTO ComponentStatusTransitionRule (from_status, to_status, description) VALUES
('in_stock', 'available', 'Inventory inspection completed'),
('in_stock', 'installed', 'Install directly from inventory'),
('in_stock', 'under_maintenance', 'Inspection or repair before use'),
('in_stock', 'retired', 'Retire unusable inventory component'),
('available', 'installed', 'Install available component'),
('available', 'under_maintenance', 'Send available component to maintenance'),
('available', 'retired', 'Retire available component'),
('installed', 'removed', 'Remove component from aircraft'),
('installed', 'under_maintenance', 'Perform online maintenance'),
('removed', 'available', 'Release removed component after inspection'),
('removed', 'under_maintenance', 'Send removed component to maintenance'),
('removed', 'retired', 'Retire removed component'),
('under_maintenance', 'available', 'Maintenance passed for uninstalled component'),
('under_maintenance', 'installed', 'Online maintenance passed'),
('under_maintenance', 'removed', 'Maintenance failed but component is not retired'),
('under_maintenance', 'retired', 'Scrap component after maintenance');

INSERT INTO InstallationRecord (component_id, aircraft_id, install_position, install_time, uninstall_time, install_reason, uninstall_reason, operator_id, uninstall_operator_id) VALUES
(1, 1, 'left engine position', '2025-01-10 09:00:00', NULL, 'initial installation', NULL, 1, NULL),
(4, 1, 'navigation bay', '2025-02-01 10:00:00', NULL, 'initial installation', NULL, 1, NULL),
(5, 2, 'hydraulic system bay', '2025-01-15 08:30:00', '2025-04-01 16:00:00', 'initial installation', 'scheduled maintenance', 1, 1),
(5, 1, 'hydraulic system bay', '2025-04-10 09:30:00', '2025-05-10 15:00:00', 'reinstallation after maintenance', 'performance check', 1, 1);

INSERT INTO MaintenanceRecord (component_id, maintenance_type, start_time, end_time, result, description, technician_id) VALUES
(5, 'scheduled maintenance', '2025-04-02 09:00:00', '2025-04-05 17:00:00', 'passed', 'Hydraulic pressure test passed.', 2),
(1, 'online inspection', '2025-03-10 10:00:00', '2025-03-10 12:00:00', 'passed', 'Routine online inspection passed.', 2),
(7, 'fault repair', '2025-05-25 09:00:00', NULL, 'pending', 'Navigation module under repair.', 2);

INSERT INTO FlightLog (aircraft_id, mission_no, takeoff_time, landing_time, flight_hours, mission_type, recorded_by) VALUES
(1, 'FL-20250301-001', '2025-03-01 08:00:00', '2025-03-01 10:00:00', 2.00, 'training', 4),
(2, 'FL-20250305-001', '2025-03-05 09:00:00', '2025-03-05 11:30:00', 2.50, 'patrol', 4),
(1, 'FL-20250420-001', '2025-04-20 08:00:00', '2025-04-20 11:00:00', 3.00, 'training', 4),
(1, 'FL-20250515-001', '2025-05-15 14:00:00', '2025-05-15 16:00:00', 2.00, 'test flight', 4);

INSERT INTO RetirementRecord (component_id, retirement_time, retirement_reason, approved_by, remark) VALUES
(6, '2025-05-20 10:00:00', 'irreparable damage found during inspection', 3, 'Component marked as retired instead of physical deletion.');

SELECT 'Operator' AS table_name, COUNT(*) AS row_count FROM Operator
UNION ALL SELECT 'Aircraft', COUNT(*) FROM Aircraft
UNION ALL SELECT 'ComponentModel', COUNT(*) FROM ComponentModel
UNION ALL SELECT 'Component', COUNT(*) FROM Component
UNION ALL SELECT 'ComponentStatusTransitionRule', COUNT(*) FROM ComponentStatusTransitionRule
UNION ALL SELECT 'InstallationRecord', COUNT(*) FROM InstallationRecord
UNION ALL SELECT 'MaintenanceRecord', COUNT(*) FROM MaintenanceRecord
UNION ALL SELECT 'MaintenancePlan', COUNT(*) FROM MaintenancePlan
UNION ALL SELECT 'FlightLog', COUNT(*) FROM FlightLog
UNION ALL SELECT 'RetirementRecord', COUNT(*) FROM RetirementRecord
UNION ALL SELECT 'AuditLog', COUNT(*) FROM AuditLog;
