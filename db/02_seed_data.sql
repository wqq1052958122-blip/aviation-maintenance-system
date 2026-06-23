-- =====================================================
-- 文件：02_seed_data.sql
-- 作用：航空部件生命周期与维修管理系统教学演示数据 + 十万级规模扩展数据
-- 说明：寿命、周期和飞行时长均为课程展示用模拟值，不代表真实航空参数；后半部分另含十万级关联业务数据。
-- 执行位置：01_create_tables.sql 之后，03_triggers.sql 之前。
-- =====================================================
USE aviation_maintenance;

INSERT INTO Operator (operator_name, role, phone, created_at) VALUES
('Zhang Wei', 'installer', '13800000001', '2024-01-02 09:00:00'),
('Li Ming', 'technician', '13800000002', '2024-01-02 09:10:00'),
('Wang Fang', 'approver', '13800000003', '2024-01-02 09:20:00'),
('Chen Jie', 'admin', '13800000004', '2024-01-02 09:30:00'),
('Liu Yang', 'installer', '13800000005', '2024-02-01 08:30:00'),
('Zhao Min', 'technician', '13800000006', '2024-02-01 08:40:00'),
('Sun Hao', 'approver', '13800000007', '2024-02-01 08:50:00'),
('Wu Qian', 'technician', '13800000008', '2024-03-01 09:00:00'),
('Zhou Lin', 'installer', '13800000009', '2024-03-01 09:10:00'),
('Xu Lei', 'admin', '13800000010', '2024-03-01 09:20:00');

INSERT INTO Aircraft (aircraft_no, aircraft_model, service_status, start_date, created_at) VALUES
('AC-1001', 'A320', 'active', '2021-03-18', '2024-01-05 08:00:00'),
('AC-1002', 'A320', 'active', '2021-08-12', '2024-01-05 08:10:00'),
('AC-1003', 'B737', 'active', '2020-05-20', '2024-01-05 08:20:00'),
('AC-1004', 'B737', 'active', '2022-01-15', '2024-01-05 08:30:00'),
('AC-1005', 'A330', 'active', '2019-11-08', '2024-01-05 08:40:00'),
('AC-1006', 'A330', 'maintenance', '2020-09-22', '2024-01-05 08:50:00'),
('AC-1007', 'A320', 'active', '2023-02-10', '2024-01-05 09:00:00'),
('AC-1008', 'B737', 'maintenance', '2022-06-30', '2024-01-05 09:10:00'),
('AC-1009', 'A320', 'retired', '2012-04-16', '2024-01-05 09:20:00');

INSERT INTO ComponentCategory (category_code, category_name, description) VALUES
('engine', '发动机', '航空动力系统教学模拟部件'),
('landing_gear', '起落架', '起落架及收放机构教学模拟部件'),
('avionics', '航电系统', '航空电子与控制模块'),
('navigation', '导航系统', '导航与定位模块'),
('hydraulic', '液压系统', '液压泵与控制组件'),
('fuel', '燃油系统', '燃油输送与控制组件'),
('air_conditioning', '空调系统', '环境控制系统组件'),
('brake', '刹车系统', '机轮制动系统组件'),
('battery', '机载电源', '机载电池与备用电源组件');

INSERT INTO ComponentModel (model_code, category, design_life_hours, maintenance_cycle_hours, applicable_aircraft_model) VALUES
('ENG-A320-T', 'engine', 120, 45, 'A320'),
('ENG-B737-T', 'engine', 100, 50, 'B737'),
('ENG-A330-T', 'engine', 120, 60, 'A330'),
('LDG-A320-T', 'landing_gear', 75, 65, 'A320'),
('LDG-B737-T', 'landing_gear', 90, 55, 'B737'),
('LDG-A330-T', 'landing_gear', 100, 65, 'A330'),
('NAV-UNIV-T', 'navigation', 300, 30, NULL),
('AVI-A320-T', 'avionics', 62, 50, 'A320'),
('AVI-B737-T', 'avionics', 80, 45, 'B737'),
('AVI-A330-T', 'avionics', 90, 55, 'A330'),
('HYD-UNIV-T', 'hydraulic', 300, 50, NULL),
('FUEL-UNIV-T', 'fuel', 300, 55, NULL),
('ECS-UNIV-T', 'air_conditioning', 150, 50, NULL),
('BRK-A320-T', 'brake', 260, 45, 'A320'),
('BRK-B737-T', 'brake', 60, 40, 'B737'),
('BRK-A330-T', 'brake', 70, 45, 'A330'),
('BAT-UNIV-T', 'battery', 55, 50, NULL);

-- 为每架飞机建立统一演示安装位；类别与位置一一对应。
INSERT INTO AircraftInstallPosition (aircraft_id, position_code, position_name, allowed_category)
SELECT a.aircraft_id, p.position_code, p.position_name, p.allowed_category
FROM Aircraft a
CROSS JOIN (
    SELECT 'left engine position' position_code, '左侧发动机' position_name, 'engine' allowed_category
    UNION ALL SELECT 'landing gear bay', '主起落架舱', 'landing_gear'
    UNION ALL SELECT 'avionics bay', '航电设备舱', 'avionics'
    UNION ALL SELECT 'navigation bay', '导航设备舱', 'navigation'
    UNION ALL SELECT 'hydraulic system bay', '液压系统舱', 'hydraulic'
    UNION ALL SELECT 'fuel control bay', '燃油控制舱', 'fuel'
    UNION ALL SELECT 'air conditioning bay', '空调系统舱', 'air_conditioning'
    UNION ALL SELECT 'brake assembly', '刹车组件位', 'brake'
    UNION ALL SELECT 'battery bay', '机载电源舱', 'battery'
) p;

-- 93 个部件实例：55 已安装、12 已退役、5 已拆卸、5 维修中、11 可用、5 在库。
INSERT INTO Component (component_no, model_id, batch_no, production_date, stock_in_time, status, total_flight_hours, is_retired) VALUES
('ENG-001', (SELECT model_id FROM ComponentModel WHERE model_code='ENG-A320-T'), 'E-A-01', '2020-01-10', '2020-02-01 09:00:00', 'retired', 126, 1),
('ENG-002', (SELECT model_id FROM ComponentModel WHERE model_code='ENG-A320-T'), 'E-A-02', '2021-04-12', '2021-05-01 09:00:00', 'installed', 0, 0),
('ENG-003', (SELECT model_id FROM ComponentModel WHERE model_code='ENG-A320-T'), 'E-A-02', '2021-06-16', '2021-07-01 09:00:00', 'installed', 0, 0),
('ENG-004', (SELECT model_id FROM ComponentModel WHERE model_code='ENG-A320-T'), 'E-A-03', '2022-08-03', '2022-08-20 09:00:00', 'installed', 0, 0),
('ENG-005', (SELECT model_id FROM ComponentModel WHERE model_code='ENG-A320-T'), 'E-A-04', '2023-05-02', '2023-05-20 09:00:00', 'available', 0, 0),
('ENG-006', (SELECT model_id FROM ComponentModel WHERE model_code='ENG-A320-T'), 'E-A-05', '2024-04-08', '2024-04-25 09:00:00', 'available', 0, 0),
('ENB-001', (SELECT model_id FROM ComponentModel WHERE model_code='ENG-B737-T'), 'E-B-01', '2019-03-11', '2019-04-01 09:00:00', 'retired', 78, 1),
('ENB-002', (SELECT model_id FROM ComponentModel WHERE model_code='ENG-B737-T'), 'E-B-02', '2020-02-15', '2020-03-01 09:00:00', 'installed', 0, 0),
('ENB-003', (SELECT model_id FROM ComponentModel WHERE model_code='ENG-B737-T'), 'E-B-03', '2021-09-20', '2021-10-05 09:00:00', 'installed', 0, 0),
('ENB-004', (SELECT model_id FROM ComponentModel WHERE model_code='ENG-B737-T'), 'E-B-04', '2023-01-18', '2023-02-02 09:00:00', 'available', 0, 0),
('EN3-001', (SELECT model_id FROM ComponentModel WHERE model_code='ENG-A330-T'), 'E-3-01', '2019-06-10', '2019-07-01 09:00:00', 'removed', 0, 0),
('EN3-002', (SELECT model_id FROM ComponentModel WHERE model_code='ENG-A330-T'), 'E-3-02', '2020-04-18', '2020-05-05 09:00:00', 'installed', 0, 0),
('EN3-003', (SELECT model_id FROM ComponentModel WHERE model_code='ENG-A330-T'), 'E-3-03', '2021-11-21', '2021-12-05 09:00:00', 'installed', 0, 0),
('EN3-004', (SELECT model_id FROM ComponentModel WHERE model_code='ENG-A330-T'), 'E-3-04', '2023-03-01', '2023-03-18 09:00:00', 'under_maintenance', 0, 0),
('NAV-001', (SELECT model_id FROM ComponentModel WHERE model_code='NAV-UNIV-T'), 'N-01', '2019-01-08', '2019-02-01 09:00:00', 'retired', 315, 1),
('NAV-002', (SELECT model_id FROM ComponentModel WHERE model_code='NAV-UNIV-T'), 'N-02', '2020-05-12', '2020-06-01 09:00:00', 'installed', 0, 0),
('NAV-003', (SELECT model_id FROM ComponentModel WHERE model_code='NAV-UNIV-T'), 'N-03', '2020-08-13', '2020-09-01 09:00:00', 'installed', 0, 0),
('NAV-004', (SELECT model_id FROM ComponentModel WHERE model_code='NAV-UNIV-T'), 'N-04', '2021-02-14', '2021-03-01 09:00:00', 'installed', 0, 0),
('NAV-005', (SELECT model_id FROM ComponentModel WHERE model_code='NAV-UNIV-T'), 'N-05', '2021-05-15', '2021-06-01 09:00:00', 'installed', 0, 0),
('NAV-006', (SELECT model_id FROM ComponentModel WHERE model_code='NAV-UNIV-T'), 'N-06', '2021-08-16', '2021-09-01 09:00:00', 'installed', 0, 0),
('NAV-007', (SELECT model_id FROM ComponentModel WHERE model_code='NAV-UNIV-T'), 'N-07', '2022-02-17', '2022-03-01 09:00:00', 'under_maintenance', 0, 0),
('NAV-008', (SELECT model_id FROM ComponentModel WHERE model_code='NAV-UNIV-T'), 'N-08', '2023-02-18', '2023-03-01 09:00:00', 'available', 0, 0),
('HYD-001', (SELECT model_id FROM ComponentModel WHERE model_code='HYD-UNIV-T'), 'H-01', '2019-04-03', '2019-05-01 09:00:00', 'retired', 184, 1),
('HYD-002', (SELECT model_id FROM ComponentModel WHERE model_code='HYD-UNIV-T'), 'H-02', '2020-03-04', '2020-04-01 09:00:00', 'installed', 0, 0),
('HYD-003', (SELECT model_id FROM ComponentModel WHERE model_code='HYD-UNIV-T'), 'H-03', '2020-07-05', '2020-08-01 09:00:00', 'installed', 0, 0),
('HYD-004', (SELECT model_id FROM ComponentModel WHERE model_code='HYD-UNIV-T'), 'H-04', '2021-01-06', '2021-02-01 09:00:00', 'installed', 0, 0),
('HYD-005', (SELECT model_id FROM ComponentModel WHERE model_code='HYD-UNIV-T'), 'H-05', '2021-06-07', '2021-07-01 09:00:00', 'removed', 0, 0),
('HYD-006', (SELECT model_id FROM ComponentModel WHERE model_code='HYD-UNIV-T'), 'H-06', '2022-01-08', '2022-02-01 09:00:00', 'under_maintenance', 0, 0),
('AVI-001', (SELECT model_id FROM ComponentModel WHERE model_code='AVI-A320-T'), 'AV-A-01', '2019-05-01', '2019-06-01 09:00:00', 'retired', 51, 1),
('AVI-002', (SELECT model_id FROM ComponentModel WHERE model_code='AVI-A320-T'), 'AV-A-02', '2020-05-01', '2020-06-01 09:00:00', 'installed', 0, 0),
('AVI-003', (SELECT model_id FROM ComponentModel WHERE model_code='AVI-A320-T'), 'AV-A-03', '2022-05-01', '2022-06-01 09:00:00', 'available', 0, 0),
('AVI-004', (SELECT model_id FROM ComponentModel WHERE model_code='AVI-A320-T'), 'AV-A-04', '2024-05-01', '2024-06-01 09:00:00', 'in_stock', 0, 0),
('AVB-001', (SELECT model_id FROM ComponentModel WHERE model_code='AVI-B737-T'), 'AV-B-01', '2019-07-01', '2019-08-01 09:00:00', 'removed', 0, 0),
('AVB-002', (SELECT model_id FROM ComponentModel WHERE model_code='AVI-B737-T'), 'AV-B-02', '2020-07-01', '2020-08-01 09:00:00', 'installed', 0, 0),
('AVB-003', (SELECT model_id FROM ComponentModel WHERE model_code='AVI-B737-T'), 'AV-B-03', '2022-07-01', '2022-08-01 09:00:00', 'under_maintenance', 0, 0),
('AV3-001', (SELECT model_id FROM ComponentModel WHERE model_code='AVI-A330-T'), 'AV-3-01', '2018-07-01', '2018-08-01 09:00:00', 'retired', 76, 1),
('AV3-002', (SELECT model_id FROM ComponentModel WHERE model_code='AVI-A330-T'), 'AV-3-02', '2020-07-01', '2020-08-01 09:00:00', 'installed', 0, 0),
('AV3-003', (SELECT model_id FROM ComponentModel WHERE model_code='AVI-A330-T'), 'AV-3-03', '2022-07-01', '2022-08-01 09:00:00', 'available', 0, 0),
('LDG-001', (SELECT model_id FROM ComponentModel WHERE model_code='LDG-A320-T'), 'L-A-01', '2018-01-01', '2018-02-01 09:00:00', 'retired', 63, 1),
('LDG-002', (SELECT model_id FROM ComponentModel WHERE model_code='LDG-A320-T'), 'L-A-02', '2021-01-01', '2021-02-01 09:00:00', 'available', 0, 0),
('LDG-003', (SELECT model_id FROM ComponentModel WHERE model_code='LDG-A320-T'), 'L-A-03', '2024-01-01', '2024-02-01 09:00:00', 'in_stock', 0, 0),
('LDB-001', (SELECT model_id FROM ComponentModel WHERE model_code='LDG-B737-T'), 'L-B-01', '2019-01-01', '2019-02-01 09:00:00', 'removed', 0, 0),
('LDB-002', (SELECT model_id FROM ComponentModel WHERE model_code='LDG-B737-T'), 'L-B-02', '2021-01-01', '2021-02-01 09:00:00', 'available', 0, 0),
('LDB-003', (SELECT model_id FROM ComponentModel WHERE model_code='LDG-B737-T'), 'L-B-03', '2024-01-01', '2024-02-01 09:00:00', 'in_stock', 0, 0),
('LD3-001', (SELECT model_id FROM ComponentModel WHERE model_code='LDG-A330-T'), 'L-3-01', '2018-04-01', '2018-05-01 09:00:00', 'removed', 0, 0),
('LD3-002', (SELECT model_id FROM ComponentModel WHERE model_code='LDG-A330-T'), 'L-3-02', '2020-04-01', '2020-05-01 09:00:00', 'installed', 0, 0),
('LD3-003', (SELECT model_id FROM ComponentModel WHERE model_code='LDG-A330-T'), 'L-3-03', '2022-04-01', '2022-05-01 09:00:00', 'under_maintenance', 0, 0),
('FUEL-001', (SELECT model_id FROM ComponentModel WHERE model_code='FUEL-UNIV-T'), 'F-01', '2019-01-20', '2019-02-10 09:00:00', 'retired', 214, 1),
('FUEL-002', (SELECT model_id FROM ComponentModel WHERE model_code='FUEL-UNIV-T'), 'F-02', '2020-01-20', '2020-02-10 09:00:00', 'installed', 0, 0),
('FUEL-003', (SELECT model_id FROM ComponentModel WHERE model_code='FUEL-UNIV-T'), 'F-03', '2021-01-20', '2021-02-10 09:00:00', 'installed', 0, 0),
('FUEL-004', (SELECT model_id FROM ComponentModel WHERE model_code='FUEL-UNIV-T'), 'F-04', '2022-01-20', '2022-02-10 09:00:00', 'installed', 0, 0),
('FUEL-005', (SELECT model_id FROM ComponentModel WHERE model_code='FUEL-UNIV-T'), 'F-05', '2023-01-20', '2023-02-10 09:00:00', 'available', 0, 0),
('ECS-001', (SELECT model_id FROM ComponentModel WHERE model_code='ECS-UNIV-T'), 'C-01', '2019-02-20', '2019-03-10 09:00:00', 'retired', 158, 1),
('ECS-002', (SELECT model_id FROM ComponentModel WHERE model_code='ECS-UNIV-T'), 'C-02', '2020-02-20', '2020-03-10 09:00:00', 'installed', 0, 0),
('ECS-003', (SELECT model_id FROM ComponentModel WHERE model_code='ECS-UNIV-T'), 'C-03', '2021-02-20', '2021-03-10 09:00:00', 'installed', 0, 0),
('ECS-004', (SELECT model_id FROM ComponentModel WHERE model_code='ECS-UNIV-T'), 'C-04', '2022-02-20', '2022-03-10 09:00:00', 'installed', 0, 0),
('ECS-005', (SELECT model_id FROM ComponentModel WHERE model_code='ECS-UNIV-T'), 'C-05', '2024-02-20', '2024-03-10 09:00:00', 'in_stock', 0, 0),
('BRK-001', (SELECT model_id FROM ComponentModel WHERE model_code='BRK-A320-T'), 'R-A-01', '2019-03-20', '2019-04-10 09:00:00', 'retired', 196, 1),
('BRK-002', (SELECT model_id FROM ComponentModel WHERE model_code='BRK-A320-T'), 'R-A-02', '2020-03-20', '2020-04-10 09:00:00', 'installed', 0, 0),
('BRK-003', (SELECT model_id FROM ComponentModel WHERE model_code='BRK-A320-T'), 'R-A-03', '2023-03-20', '2023-04-10 09:00:00', 'available', 0, 0),
('BRB-001', (SELECT model_id FROM ComponentModel WHERE model_code='BRK-B737-T'), 'R-B-01', '2019-06-20', '2019-07-10 09:00:00', 'retired', 64, 1),
('BRB-002', (SELECT model_id FROM ComponentModel WHERE model_code='BRK-B737-T'), 'R-B-02', '2020-06-20', '2020-07-10 09:00:00', 'installed', 0, 0),
('BRB-003', (SELECT model_id FROM ComponentModel WHERE model_code='BRK-B737-T'), 'R-B-03', '2023-06-20', '2023-07-10 09:00:00', 'available', 0, 0),
('BAT-001', (SELECT model_id FROM ComponentModel WHERE model_code='BAT-UNIV-T'), 'B-01', '2019-08-20', '2019-09-10 09:00:00', 'retired', 48, 1),
('BAT-002', (SELECT model_id FROM ComponentModel WHERE model_code='BAT-UNIV-T'), 'B-02', '2021-08-20', '2021-09-10 09:00:00', 'installed', 0, 0),
('BAT-003', (SELECT model_id FROM ComponentModel WHERE model_code='BAT-UNIV-T'), 'B-03', '2024-08-20', '2024-09-10 09:00:00', 'in_stock', 0, 0),
-- 在役机队完整配置件：用于补齐各飞机当前有效安装位，保留原有库存与维修演示数据。
('LDG-004', (SELECT model_id FROM ComponentModel WHERE model_code='LDG-A320-T'), 'CFG-1001-LDG', '2025-06-01', '2025-07-01 09:00:00', 'installed', 0, 0),
('LDG-005', (SELECT model_id FROM ComponentModel WHERE model_code='LDG-A320-T'), 'CFG-1002-LDG', '2025-06-02', '2025-07-02 09:00:00', 'installed', 0, 0),
('AVI-005', (SELECT model_id FROM ComponentModel WHERE model_code='AVI-A320-T'), 'CFG-1002-AVI', '2025-06-02', '2025-07-02 09:10:00', 'installed', 0, 0),
('HYD-007', (SELECT model_id FROM ComponentModel WHERE model_code='HYD-UNIV-T'), 'CFG-1002-HYD', '2025-06-02', '2025-07-02 09:20:00', 'installed', 0, 0),
('BRK-004', (SELECT model_id FROM ComponentModel WHERE model_code='BRK-A320-T'), 'CFG-1002-BRK', '2025-06-02', '2025-07-02 09:30:00', 'installed', 0, 0),
('BAT-004', (SELECT model_id FROM ComponentModel WHERE model_code='BAT-UNIV-T'), 'CFG-1002-BAT', '2025-06-02', '2025-07-02 09:40:00', 'installed', 0, 0),
('LDB-004', (SELECT model_id FROM ComponentModel WHERE model_code='LDG-B737-T'), 'CFG-1003-LDG', '2025-06-03', '2025-07-03 09:00:00', 'installed', 0, 0),
('FUEL-006', (SELECT model_id FROM ComponentModel WHERE model_code='FUEL-UNIV-T'), 'CFG-1003-FUEL', '2025-06-03', '2025-07-03 09:10:00', 'installed', 0, 0),
('ECS-006', (SELECT model_id FROM ComponentModel WHERE model_code='ECS-UNIV-T'), 'CFG-1003-ECS', '2025-06-03', '2025-07-03 09:20:00', 'installed', 0, 0),
('BAT-005', (SELECT model_id FROM ComponentModel WHERE model_code='BAT-UNIV-T'), 'CFG-1003-BAT', '2025-06-03', '2025-07-03 09:30:00', 'installed', 0, 0),
('LDB-005', (SELECT model_id FROM ComponentModel WHERE model_code='LDG-B737-T'), 'CFG-1004-LDG', '2025-06-04', '2025-07-04 09:00:00', 'installed', 0, 0),
('AVB-004', (SELECT model_id FROM ComponentModel WHERE model_code='AVI-B737-T'), 'CFG-1004-AVI', '2025-06-04', '2025-07-04 09:10:00', 'installed', 0, 0),
('HYD-008', (SELECT model_id FROM ComponentModel WHERE model_code='HYD-UNIV-T'), 'CFG-1004-HYD', '2025-06-04', '2025-07-04 09:20:00', 'installed', 0, 0),
('BRB-004', (SELECT model_id FROM ComponentModel WHERE model_code='BRK-B737-T'), 'CFG-1004-BRK', '2025-06-04', '2025-07-04 09:30:00', 'installed', 0, 0),
('BAT-006', (SELECT model_id FROM ComponentModel WHERE model_code='BAT-UNIV-T'), 'CFG-1004-BAT', '2025-06-04', '2025-07-04 09:40:00', 'installed', 0, 0),
('FUEL-007', (SELECT model_id FROM ComponentModel WHERE model_code='FUEL-UNIV-T'), 'CFG-1005-FUEL', '2025-06-05', '2025-07-05 09:00:00', 'installed', 0, 0),
('ECS-007', (SELECT model_id FROM ComponentModel WHERE model_code='ECS-UNIV-T'), 'CFG-1005-ECS', '2025-06-05', '2025-07-05 09:10:00', 'installed', 0, 0),
('BR3-001', (SELECT model_id FROM ComponentModel WHERE model_code='BRK-A330-T'), 'CFG-1005-BRK', '2025-06-05', '2025-07-05 09:20:00', 'installed', 0, 0),
('BAT-007', (SELECT model_id FROM ComponentModel WHERE model_code='BAT-UNIV-T'), 'CFG-1005-BAT', '2025-06-05', '2025-07-05 09:30:00', 'installed', 0, 0),
('LDG-006', (SELECT model_id FROM ComponentModel WHERE model_code='LDG-A320-T'), 'CFG-1007-LDG', '2025-06-07', '2025-07-07 09:00:00', 'installed', 0, 0),
('AVI-006', (SELECT model_id FROM ComponentModel WHERE model_code='AVI-A320-T'), 'CFG-1007-AVI', '2025-06-07', '2025-07-07 09:10:00', 'installed', 0, 0),
('NAV-009', (SELECT model_id FROM ComponentModel WHERE model_code='NAV-UNIV-T'), 'CFG-1007-NAV', '2025-06-07', '2025-07-07 09:20:00', 'installed', 0, 0),
('HYD-009', (SELECT model_id FROM ComponentModel WHERE model_code='HYD-UNIV-T'), 'CFG-1007-HYD', '2025-06-07', '2025-07-07 09:30:00', 'installed', 0, 0),
('FUEL-008', (SELECT model_id FROM ComponentModel WHERE model_code='FUEL-UNIV-T'), 'CFG-1007-FUEL', '2025-06-07', '2025-07-07 09:40:00', 'installed', 0, 0),
('ECS-008', (SELECT model_id FROM ComponentModel WHERE model_code='ECS-UNIV-T'), 'CFG-1007-ECS', '2025-06-07', '2025-07-07 09:50:00', 'installed', 0, 0),
('BRK-005', (SELECT model_id FROM ComponentModel WHERE model_code='BRK-A320-T'), 'CFG-1007-BRK', '2025-06-07', '2025-07-07 10:00:00', 'installed', 0, 0),
('BAT-008', (SELECT model_id FROM ComponentModel WHERE model_code='BAT-UNIV-T'), 'CFG-1007-BAT', '2025-06-07', '2025-07-07 10:10:00', 'installed', 0, 0);

-- 完整配置件在本项目飞行日志统计期开始前已入库，保证安装时间不早于入库时间。
UPDATE Component
SET production_date = '2023-01-01',
    stock_in_time = '2023-06-01 09:00:00'
WHERE batch_no LIKE 'CFG-%';

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

-- 23 条历史安装记录，包含典型更换链条、拆卸维修、重新安装与最终退役事件。
INSERT INTO InstallationRecord (component_id, aircraft_id, position_id, install_position, install_time, uninstall_time, install_reason, uninstall_reason, operator_id, uninstall_operator_id) VALUES
((SELECT component_id FROM Component WHERE component_no='ENG-001'), (SELECT aircraft_id FROM Aircraft WHERE aircraft_no='AC-1002'), (SELECT position_id FROM AircraftInstallPosition p JOIN Aircraft a ON p.aircraft_id=a.aircraft_id WHERE a.aircraft_no='AC-1002' AND p.position_code='left engine position'), 'left engine position', '2021-01-10 08:00:00', '2021-12-01 18:00:00', 'initial installation', 'scheduled inspection', 1, 5),
((SELECT component_id FROM Component WHERE component_no='ENG-001'), (SELECT aircraft_id FROM Aircraft WHERE aircraft_no='AC-1001'), (SELECT position_id FROM AircraftInstallPosition p JOIN Aircraft a ON p.aircraft_id=a.aircraft_id WHERE a.aircraft_no='AC-1001' AND p.position_code='left engine position'), 'left engine position', '2023-01-05 08:00:00', '2024-12-20 18:00:00', 'initial installation', 'life limit reached', 1, 5),
((SELECT component_id FROM Component WHERE component_no='NAV-001'), (SELECT aircraft_id FROM Aircraft WHERE aircraft_no='AC-1001'), (SELECT position_id FROM AircraftInstallPosition p JOIN Aircraft a ON p.aircraft_id=a.aircraft_id WHERE a.aircraft_no='AC-1001' AND p.position_code='navigation bay'), 'navigation bay', '2023-01-05 08:10:00', '2024-11-18 16:00:00', 'initial installation', 'navigation replacement', 1, 5),
((SELECT component_id FROM Component WHERE component_no='HYD-001'), (SELECT aircraft_id FROM Aircraft WHERE aircraft_no='AC-1002'), (SELECT position_id FROM AircraftInstallPosition p JOIN Aircraft a ON p.aircraft_id=a.aircraft_id WHERE a.aircraft_no='AC-1002' AND p.position_code='hydraulic system bay'), 'hydraulic system bay', '2023-02-01 09:00:00', '2024-09-20 15:00:00', 'initial installation', 'irreparable leakage', 5, 9),
((SELECT component_id FROM Component WHERE component_no='AVI-001'), (SELECT aircraft_id FROM Aircraft WHERE aircraft_no='AC-1002'), (SELECT position_id FROM AircraftInstallPosition p JOIN Aircraft a ON p.aircraft_id=a.aircraft_id WHERE a.aircraft_no='AC-1002' AND p.position_code='avionics bay'), 'avionics bay', '2023-02-01 09:10:00', '2024-08-10 15:00:00', 'initial installation', 'economic retirement', 5, 9),
((SELECT component_id FROM Component WHERE component_no='LDG-001'), (SELECT aircraft_id FROM Aircraft WHERE aircraft_no='AC-1009'), (SELECT position_id FROM AircraftInstallPosition p JOIN Aircraft a ON p.aircraft_id=a.aircraft_id WHERE a.aircraft_no='AC-1009' AND p.position_code='landing gear bay'), 'landing gear bay', '2022-01-10 08:00:00', '2024-06-01 17:00:00', 'initial installation', 'aircraft retirement', 1, 5),
((SELECT component_id FROM Component WHERE component_no='FUEL-001'), (SELECT aircraft_id FROM Aircraft WHERE aircraft_no='AC-1009'), (SELECT position_id FROM AircraftInstallPosition p JOIN Aircraft a ON p.aircraft_id=a.aircraft_id WHERE a.aircraft_no='AC-1009' AND p.position_code='fuel control bay'), 'fuel control bay', '2022-01-10 08:10:00', '2024-06-01 17:10:00', 'initial installation', 'aircraft retirement', 1, 5),
((SELECT component_id FROM Component WHERE component_no='ECS-001'), (SELECT aircraft_id FROM Aircraft WHERE aircraft_no='AC-1009'), (SELECT position_id FROM AircraftInstallPosition p JOIN Aircraft a ON p.aircraft_id=a.aircraft_id WHERE a.aircraft_no='AC-1009' AND p.position_code='air conditioning bay'), 'air conditioning bay', '2022-01-10 08:20:00', '2024-06-01 17:20:00', 'initial installation', 'aircraft retirement', 1, 5),
((SELECT component_id FROM Component WHERE component_no='BRK-001'), (SELECT aircraft_id FROM Aircraft WHERE aircraft_no='AC-1009'), (SELECT position_id FROM AircraftInstallPosition p JOIN Aircraft a ON p.aircraft_id=a.aircraft_id WHERE a.aircraft_no='AC-1009' AND p.position_code='brake assembly'), 'brake assembly', '2022-01-10 08:30:00', '2024-06-01 17:30:00', 'initial installation', 'aircraft retirement', 1, 5),
((SELECT component_id FROM Component WHERE component_no='BAT-001'), (SELECT aircraft_id FROM Aircraft WHERE aircraft_no='AC-1009'), (SELECT position_id FROM AircraftInstallPosition p JOIN Aircraft a ON p.aircraft_id=a.aircraft_id WHERE a.aircraft_no='AC-1009' AND p.position_code='battery bay'), 'battery bay', '2022-01-10 08:40:00', '2024-06-01 17:40:00', 'initial installation', 'aircraft retirement', 1, 5),
((SELECT component_id FROM Component WHERE component_no='ENB-001'), (SELECT aircraft_id FROM Aircraft WHERE aircraft_no='AC-1003'), (SELECT position_id FROM AircraftInstallPosition p JOIN Aircraft a ON p.aircraft_id=a.aircraft_id WHERE a.aircraft_no='AC-1003' AND p.position_code='left engine position'), 'left engine position', '2022-04-01 08:00:00', '2024-10-01 18:00:00', 'initial installation', 'maintenance failure', 5, 9),
((SELECT component_id FROM Component WHERE component_no='AV3-001'), (SELECT aircraft_id FROM Aircraft WHERE aircraft_no='AC-1005'), (SELECT position_id FROM AircraftInstallPosition p JOIN Aircraft a ON p.aircraft_id=a.aircraft_id WHERE a.aircraft_no='AC-1005' AND p.position_code='avionics bay'), 'avionics bay', '2022-05-01 08:00:00', '2024-07-12 18:00:00', 'initial installation', 'irreparable damage', 1, 5),
((SELECT component_id FROM Component WHERE component_no='BRB-001'), (SELECT aircraft_id FROM Aircraft WHERE aircraft_no='AC-1004'), (SELECT position_id FROM AircraftInstallPosition p JOIN Aircraft a ON p.aircraft_id=a.aircraft_id WHERE a.aircraft_no='AC-1004' AND p.position_code='brake assembly'), 'brake assembly', '2022-06-01 08:00:00', '2024-05-15 18:00:00', 'initial installation', 'replacement retirement', 5, 9),
((SELECT component_id FROM Component WHERE component_no='EN3-001'), (SELECT aircraft_id FROM Aircraft WHERE aircraft_no='AC-1006'), (SELECT position_id FROM AircraftInstallPosition p JOIN Aircraft a ON p.aircraft_id=a.aircraft_id WHERE a.aircraft_no='AC-1006' AND p.position_code='left engine position'), 'left engine position', '2023-03-01 08:00:00', '2025-02-10 16:00:00', 'initial installation', 'scheduled overhaul', 1, 5),
((SELECT component_id FROM Component WHERE component_no='HYD-005'), (SELECT aircraft_id FROM Aircraft WHERE aircraft_no='AC-1007'), (SELECT position_id FROM AircraftInstallPosition p JOIN Aircraft a ON p.aircraft_id=a.aircraft_id WHERE a.aircraft_no='AC-1007' AND p.position_code='hydraulic system bay'), 'hydraulic system bay', '2023-04-01 08:00:00', '2025-01-20 16:00:00', 'initial installation', 'pressure instability', 5, 9),
((SELECT component_id FROM Component WHERE component_no='AVB-001'), (SELECT aircraft_id FROM Aircraft WHERE aircraft_no='AC-1008'), (SELECT position_id FROM AircraftInstallPosition p JOIN Aircraft a ON p.aircraft_id=a.aircraft_id WHERE a.aircraft_no='AC-1008' AND p.position_code='avionics bay'), 'avionics bay', '2023-05-01 08:00:00', '2025-02-15 16:00:00', 'initial installation', 'fault isolation', 5, 9),
((SELECT component_id FROM Component WHERE component_no='LDB-001'), (SELECT aircraft_id FROM Aircraft WHERE aircraft_no='AC-1008'), (SELECT position_id FROM AircraftInstallPosition p JOIN Aircraft a ON p.aircraft_id=a.aircraft_id WHERE a.aircraft_no='AC-1008' AND p.position_code='landing gear bay'), 'landing gear bay', '2023-05-01 08:10:00', '2025-02-15 16:10:00', 'initial installation', 'scheduled inspection', 5, 9),
((SELECT component_id FROM Component WHERE component_no='LD3-001'), (SELECT aircraft_id FROM Aircraft WHERE aircraft_no='AC-1006'), (SELECT position_id FROM AircraftInstallPosition p JOIN Aircraft a ON p.aircraft_id=a.aircraft_id WHERE a.aircraft_no='AC-1006' AND p.position_code='landing gear bay'), 'landing gear bay', '2023-03-01 08:10:00', '2025-02-10 16:10:00', 'initial installation', 'wear inspection', 1, 5),
((SELECT component_id FROM Component WHERE component_no='ENG-002'), (SELECT aircraft_id FROM Aircraft WHERE aircraft_no='AC-1002'), (SELECT position_id FROM AircraftInstallPosition p JOIN Aircraft a ON p.aircraft_id=a.aircraft_id WHERE a.aircraft_no='AC-1002' AND p.position_code='left engine position'), 'left engine position', '2022-01-01 08:00:00', '2023-01-01 08:00:00', 'initial installation', 'fleet reassignment', 1, 5),
((SELECT component_id FROM Component WHERE component_no='NAV-002'), (SELECT aircraft_id FROM Aircraft WHERE aircraft_no='AC-1002'), (SELECT position_id FROM AircraftInstallPosition p JOIN Aircraft a ON p.aircraft_id=a.aircraft_id WHERE a.aircraft_no='AC-1002' AND p.position_code='navigation bay'), 'navigation bay', '2022-01-01 08:10:00', '2023-01-01 08:10:00', 'initial installation', 'navigation upgrade', 1, 5),
((SELECT component_id FROM Component WHERE component_no='HYD-002'), (SELECT aircraft_id FROM Aircraft WHERE aircraft_no='AC-1002'), (SELECT position_id FROM AircraftInstallPosition p JOIN Aircraft a ON p.aircraft_id=a.aircraft_id WHERE a.aircraft_no='AC-1002' AND p.position_code='hydraulic system bay'), 'hydraulic system bay', '2022-01-01 08:20:00', '2023-01-01 08:20:00', 'initial installation', 'fleet reassignment', 1, 5);

-- AC-1007 左发动机位置形成三代部件更换链，突出更换频率分析效果。
INSERT INTO InstallationRecord (component_id, aircraft_id, position_id, install_position, install_time, uninstall_time, install_reason, uninstall_reason, operator_id, uninstall_operator_id) VALUES
((SELECT component_id FROM Component WHERE component_no='ENG-005'), (SELECT aircraft_id FROM Aircraft WHERE aircraft_no='AC-1007'), (SELECT position_id FROM AircraftInstallPosition p JOIN Aircraft a ON p.aircraft_id=a.aircraft_id WHERE a.aircraft_no='AC-1007' AND p.position_code='left engine position'), 'left engine position', '2023-06-01 08:00:00', '2024-01-15 16:00:00', 'fleet introduction installation', 'scheduled rotation', 1, 5),
((SELECT component_id FROM Component WHERE component_no='ENG-006'), (SELECT aircraft_id FROM Aircraft WHERE aircraft_no='AC-1007'), (SELECT position_id FROM AircraftInstallPosition p JOIN Aircraft a ON p.aircraft_id=a.aircraft_id WHERE a.aircraft_no='AC-1007' AND p.position_code='left engine position'), 'left engine position', '2024-05-01 08:00:00', '2024-12-20 16:00:00', 'scheduled rotation installation', 'oil trend inspection replacement', 5, 9);

-- 55 条当前有效安装记录；6 架在役飞机的 9 个有效位置均完整配置，另保留 1 条维修飞机安装记录。
INSERT INTO InstallationRecord (component_id, aircraft_id, position_id, install_position, install_time, uninstall_time, install_reason, operator_id) VALUES
((SELECT component_id FROM Component WHERE component_no='ENG-002'), (SELECT aircraft_id FROM Aircraft WHERE aircraft_no='AC-1001'), (SELECT position_id FROM AircraftInstallPosition p JOIN Aircraft a ON p.aircraft_id=a.aircraft_id WHERE a.aircraft_no='AC-1001' AND p.position_code='left engine position'), 'left engine position', '2025-01-01 08:00:00', NULL, 'replacement installation', 1),
((SELECT component_id FROM Component WHERE component_no='NAV-002'), (SELECT aircraft_id FROM Aircraft WHERE aircraft_no='AC-1001'), (SELECT position_id FROM AircraftInstallPosition p JOIN Aircraft a ON p.aircraft_id=a.aircraft_id WHERE a.aircraft_no='AC-1001' AND p.position_code='navigation bay'), 'navigation bay', '2025-01-01 08:10:00', NULL, 'replacement installation', 1),
((SELECT component_id FROM Component WHERE component_no='HYD-002'), (SELECT aircraft_id FROM Aircraft WHERE aircraft_no='AC-1001'), (SELECT position_id FROM AircraftInstallPosition p JOIN Aircraft a ON p.aircraft_id=a.aircraft_id WHERE a.aircraft_no='AC-1001' AND p.position_code='hydraulic system bay'), 'hydraulic system bay', '2025-01-01 08:20:00', NULL, 'reinstallation after maintenance', 1),
((SELECT component_id FROM Component WHERE component_no='AVI-002'), (SELECT aircraft_id FROM Aircraft WHERE aircraft_no='AC-1001'), (SELECT position_id FROM AircraftInstallPosition p JOIN Aircraft a ON p.aircraft_id=a.aircraft_id WHERE a.aircraft_no='AC-1001' AND p.position_code='avionics bay'), 'avionics bay', '2025-01-01 08:30:00', NULL, 'normal installation', 1),
((SELECT component_id FROM Component WHERE component_no='FUEL-002'), (SELECT aircraft_id FROM Aircraft WHERE aircraft_no='AC-1001'), (SELECT position_id FROM AircraftInstallPosition p JOIN Aircraft a ON p.aircraft_id=a.aircraft_id WHERE a.aircraft_no='AC-1001' AND p.position_code='fuel control bay'), 'fuel control bay', '2025-01-01 08:40:00', NULL, 'normal installation', 1),
((SELECT component_id FROM Component WHERE component_no='ECS-002'), (SELECT aircraft_id FROM Aircraft WHERE aircraft_no='AC-1001'), (SELECT position_id FROM AircraftInstallPosition p JOIN Aircraft a ON p.aircraft_id=a.aircraft_id WHERE a.aircraft_no='AC-1001' AND p.position_code='air conditioning bay'), 'air conditioning bay', '2025-01-01 08:50:00', NULL, 'normal installation', 1),
((SELECT component_id FROM Component WHERE component_no='BRK-002'), (SELECT aircraft_id FROM Aircraft WHERE aircraft_no='AC-1001'), (SELECT position_id FROM AircraftInstallPosition p JOIN Aircraft a ON p.aircraft_id=a.aircraft_id WHERE a.aircraft_no='AC-1001' AND p.position_code='brake assembly'), 'brake assembly', '2025-01-01 09:00:00', NULL, 'normal installation', 1),
((SELECT component_id FROM Component WHERE component_no='BAT-002'), (SELECT aircraft_id FROM Aircraft WHERE aircraft_no='AC-1001'), (SELECT position_id FROM AircraftInstallPosition p JOIN Aircraft a ON p.aircraft_id=a.aircraft_id WHERE a.aircraft_no='AC-1001' AND p.position_code='battery bay'), 'battery bay', '2025-01-01 09:10:00', NULL, 'normal installation', 1),
((SELECT component_id FROM Component WHERE component_no='ENG-003'), (SELECT aircraft_id FROM Aircraft WHERE aircraft_no='AC-1002'), (SELECT position_id FROM AircraftInstallPosition p JOIN Aircraft a ON p.aircraft_id=a.aircraft_id WHERE a.aircraft_no='AC-1002' AND p.position_code='left engine position'), 'left engine position', '2025-01-02 08:00:00', NULL, 'normal installation', 5),
((SELECT component_id FROM Component WHERE component_no='NAV-003'), (SELECT aircraft_id FROM Aircraft WHERE aircraft_no='AC-1002'), (SELECT position_id FROM AircraftInstallPosition p JOIN Aircraft a ON p.aircraft_id=a.aircraft_id WHERE a.aircraft_no='AC-1002' AND p.position_code='navigation bay'), 'navigation bay', '2025-01-02 08:10:00', NULL, 'normal installation', 5),
((SELECT component_id FROM Component WHERE component_no='FUEL-003'), (SELECT aircraft_id FROM Aircraft WHERE aircraft_no='AC-1002'), (SELECT position_id FROM AircraftInstallPosition p JOIN Aircraft a ON p.aircraft_id=a.aircraft_id WHERE a.aircraft_no='AC-1002' AND p.position_code='fuel control bay'), 'fuel control bay', '2025-01-02 08:20:00', NULL, 'normal installation', 5),
((SELECT component_id FROM Component WHERE component_no='ECS-003'), (SELECT aircraft_id FROM Aircraft WHERE aircraft_no='AC-1002'), (SELECT position_id FROM AircraftInstallPosition p JOIN Aircraft a ON p.aircraft_id=a.aircraft_id WHERE a.aircraft_no='AC-1002' AND p.position_code='air conditioning bay'), 'air conditioning bay', '2025-01-02 08:30:00', NULL, 'normal installation', 5),
((SELECT component_id FROM Component WHERE component_no='ENB-002'), (SELECT aircraft_id FROM Aircraft WHERE aircraft_no='AC-1003'), (SELECT position_id FROM AircraftInstallPosition p JOIN Aircraft a ON p.aircraft_id=a.aircraft_id WHERE a.aircraft_no='AC-1003' AND p.position_code='left engine position'), 'left engine position', '2025-01-03 08:00:00', NULL, 'replacement installation', 9),
((SELECT component_id FROM Component WHERE component_no='NAV-004'), (SELECT aircraft_id FROM Aircraft WHERE aircraft_no='AC-1003'), (SELECT position_id FROM AircraftInstallPosition p JOIN Aircraft a ON p.aircraft_id=a.aircraft_id WHERE a.aircraft_no='AC-1003' AND p.position_code='navigation bay'), 'navigation bay', '2025-01-03 08:10:00', NULL, 'normal installation', 9),
((SELECT component_id FROM Component WHERE component_no='HYD-003'), (SELECT aircraft_id FROM Aircraft WHERE aircraft_no='AC-1003'), (SELECT position_id FROM AircraftInstallPosition p JOIN Aircraft a ON p.aircraft_id=a.aircraft_id WHERE a.aircraft_no='AC-1003' AND p.position_code='hydraulic system bay'), 'hydraulic system bay', '2025-01-03 08:20:00', NULL, 'normal installation', 9),
((SELECT component_id FROM Component WHERE component_no='AVB-002'), (SELECT aircraft_id FROM Aircraft WHERE aircraft_no='AC-1003'), (SELECT position_id FROM AircraftInstallPosition p JOIN Aircraft a ON p.aircraft_id=a.aircraft_id WHERE a.aircraft_no='AC-1003' AND p.position_code='avionics bay'), 'avionics bay', '2025-01-03 08:30:00', NULL, 'normal installation', 9),
((SELECT component_id FROM Component WHERE component_no='BRB-002'), (SELECT aircraft_id FROM Aircraft WHERE aircraft_no='AC-1003'), (SELECT position_id FROM AircraftInstallPosition p JOIN Aircraft a ON p.aircraft_id=a.aircraft_id WHERE a.aircraft_no='AC-1003' AND p.position_code='brake assembly'), 'brake assembly', '2025-01-03 08:40:00', NULL, 'replacement installation', 9),
((SELECT component_id FROM Component WHERE component_no='ENB-003'), (SELECT aircraft_id FROM Aircraft WHERE aircraft_no='AC-1004'), (SELECT position_id FROM AircraftInstallPosition p JOIN Aircraft a ON p.aircraft_id=a.aircraft_id WHERE a.aircraft_no='AC-1004' AND p.position_code='left engine position'), 'left engine position', '2025-01-04 08:00:00', NULL, 'normal installation', 5),
((SELECT component_id FROM Component WHERE component_no='NAV-005'), (SELECT aircraft_id FROM Aircraft WHERE aircraft_no='AC-1004'), (SELECT position_id FROM AircraftInstallPosition p JOIN Aircraft a ON p.aircraft_id=a.aircraft_id WHERE a.aircraft_no='AC-1004' AND p.position_code='navigation bay'), 'navigation bay', '2025-01-04 08:10:00', NULL, 'normal installation', 5),
((SELECT component_id FROM Component WHERE component_no='FUEL-004'), (SELECT aircraft_id FROM Aircraft WHERE aircraft_no='AC-1004'), (SELECT position_id FROM AircraftInstallPosition p JOIN Aircraft a ON p.aircraft_id=a.aircraft_id WHERE a.aircraft_no='AC-1004' AND p.position_code='fuel control bay'), 'fuel control bay', '2025-01-04 08:20:00', NULL, 'normal installation', 5),
((SELECT component_id FROM Component WHERE component_no='ECS-004'), (SELECT aircraft_id FROM Aircraft WHERE aircraft_no='AC-1004'), (SELECT position_id FROM AircraftInstallPosition p JOIN Aircraft a ON p.aircraft_id=a.aircraft_id WHERE a.aircraft_no='AC-1004' AND p.position_code='air conditioning bay'), 'air conditioning bay', '2025-01-04 08:30:00', NULL, 'normal installation', 5),
((SELECT component_id FROM Component WHERE component_no='EN3-002'), (SELECT aircraft_id FROM Aircraft WHERE aircraft_no='AC-1005'), (SELECT position_id FROM AircraftInstallPosition p JOIN Aircraft a ON p.aircraft_id=a.aircraft_id WHERE a.aircraft_no='AC-1005' AND p.position_code='left engine position'), 'left engine position', '2025-01-05 08:00:00', NULL, 'normal installation', 1),
((SELECT component_id FROM Component WHERE component_no='NAV-006'), (SELECT aircraft_id FROM Aircraft WHERE aircraft_no='AC-1005'), (SELECT position_id FROM AircraftInstallPosition p JOIN Aircraft a ON p.aircraft_id=a.aircraft_id WHERE a.aircraft_no='AC-1005' AND p.position_code='navigation bay'), 'navigation bay', '2025-01-05 08:10:00', NULL, 'normal installation', 1),
((SELECT component_id FROM Component WHERE component_no='HYD-004'), (SELECT aircraft_id FROM Aircraft WHERE aircraft_no='AC-1005'), (SELECT position_id FROM AircraftInstallPosition p JOIN Aircraft a ON p.aircraft_id=a.aircraft_id WHERE a.aircraft_no='AC-1005' AND p.position_code='hydraulic system bay'), 'hydraulic system bay', '2025-01-05 08:20:00', NULL, 'normal installation', 1),
((SELECT component_id FROM Component WHERE component_no='AV3-002'), (SELECT aircraft_id FROM Aircraft WHERE aircraft_no='AC-1005'), (SELECT position_id FROM AircraftInstallPosition p JOIN Aircraft a ON p.aircraft_id=a.aircraft_id WHERE a.aircraft_no='AC-1005' AND p.position_code='avionics bay'), 'avionics bay', '2025-01-05 08:30:00', NULL, 'replacement installation', 1),
((SELECT component_id FROM Component WHERE component_no='LD3-002'), (SELECT aircraft_id FROM Aircraft WHERE aircraft_no='AC-1005'), (SELECT position_id FROM AircraftInstallPosition p JOIN Aircraft a ON p.aircraft_id=a.aircraft_id WHERE a.aircraft_no='AC-1005' AND p.position_code='landing gear bay'), 'landing gear bay', '2025-01-05 08:40:00', NULL, 'normal installation', 1),
((SELECT component_id FROM Component WHERE component_no='EN3-003'), (SELECT aircraft_id FROM Aircraft WHERE aircraft_no='AC-1006'), (SELECT position_id FROM AircraftInstallPosition p JOIN Aircraft a ON p.aircraft_id=a.aircraft_id WHERE a.aircraft_no='AC-1006' AND p.position_code='left engine position'), 'left engine position', '2025-02-12 08:00:00', NULL, 'replacement installation', 5),
((SELECT component_id FROM Component WHERE component_no='ENG-004'), (SELECT aircraft_id FROM Aircraft WHERE aircraft_no='AC-1007'), (SELECT position_id FROM AircraftInstallPosition p JOIN Aircraft a ON p.aircraft_id=a.aircraft_id WHERE a.aircraft_no='AC-1007' AND p.position_code='left engine position'), 'left engine position', '2025-01-07 08:00:00', NULL, 'normal installation', 9);

-- 补齐在役飞机当前配置；统一作为 2024 年初基线配置导入，早于各在役飞机首条飞行日志。
INSERT INTO InstallationRecord (component_id, aircraft_id, position_id, install_position, install_time, uninstall_time, install_reason, operator_id) VALUES
((SELECT component_id FROM Component WHERE component_no='LDG-004'), (SELECT aircraft_id FROM Aircraft WHERE aircraft_no='AC-1001'), (SELECT position_id FROM AircraftInstallPosition p JOIN Aircraft a ON p.aircraft_id=a.aircraft_id WHERE a.aircraft_no='AC-1001' AND p.position_code='landing gear bay'), 'landing gear bay', '2025-09-01 09:00:00', NULL, 'fleet configuration completion', 1),
((SELECT component_id FROM Component WHERE component_no='LDG-005'), (SELECT aircraft_id FROM Aircraft WHERE aircraft_no='AC-1002'), (SELECT position_id FROM AircraftInstallPosition p JOIN Aircraft a ON p.aircraft_id=a.aircraft_id WHERE a.aircraft_no='AC-1002' AND p.position_code='landing gear bay'), 'landing gear bay', '2025-09-02 09:00:00', NULL, 'fleet configuration completion', 1),
((SELECT component_id FROM Component WHERE component_no='AVI-005'), (SELECT aircraft_id FROM Aircraft WHERE aircraft_no='AC-1002'), (SELECT position_id FROM AircraftInstallPosition p JOIN Aircraft a ON p.aircraft_id=a.aircraft_id WHERE a.aircraft_no='AC-1002' AND p.position_code='avionics bay'), 'avionics bay', '2025-09-02 09:10:00', NULL, 'fleet configuration completion', 1),
((SELECT component_id FROM Component WHERE component_no='HYD-007'), (SELECT aircraft_id FROM Aircraft WHERE aircraft_no='AC-1002'), (SELECT position_id FROM AircraftInstallPosition p JOIN Aircraft a ON p.aircraft_id=a.aircraft_id WHERE a.aircraft_no='AC-1002' AND p.position_code='hydraulic system bay'), 'hydraulic system bay', '2025-09-02 09:20:00', NULL, 'fleet configuration completion', 1),
((SELECT component_id FROM Component WHERE component_no='BRK-004'), (SELECT aircraft_id FROM Aircraft WHERE aircraft_no='AC-1002'), (SELECT position_id FROM AircraftInstallPosition p JOIN Aircraft a ON p.aircraft_id=a.aircraft_id WHERE a.aircraft_no='AC-1002' AND p.position_code='brake assembly'), 'brake assembly', '2025-09-02 09:30:00', NULL, 'fleet configuration completion', 1),
((SELECT component_id FROM Component WHERE component_no='BAT-004'), (SELECT aircraft_id FROM Aircraft WHERE aircraft_no='AC-1002'), (SELECT position_id FROM AircraftInstallPosition p JOIN Aircraft a ON p.aircraft_id=a.aircraft_id WHERE a.aircraft_no='AC-1002' AND p.position_code='battery bay'), 'battery bay', '2025-09-02 09:40:00', NULL, 'fleet configuration completion', 1),
((SELECT component_id FROM Component WHERE component_no='LDB-004'), (SELECT aircraft_id FROM Aircraft WHERE aircraft_no='AC-1003'), (SELECT position_id FROM AircraftInstallPosition p JOIN Aircraft a ON p.aircraft_id=a.aircraft_id WHERE a.aircraft_no='AC-1003' AND p.position_code='landing gear bay'), 'landing gear bay', '2025-09-03 09:00:00', NULL, 'fleet configuration completion', 5),
((SELECT component_id FROM Component WHERE component_no='FUEL-006'), (SELECT aircraft_id FROM Aircraft WHERE aircraft_no='AC-1003'), (SELECT position_id FROM AircraftInstallPosition p JOIN Aircraft a ON p.aircraft_id=a.aircraft_id WHERE a.aircraft_no='AC-1003' AND p.position_code='fuel control bay'), 'fuel control bay', '2025-09-03 09:10:00', NULL, 'fleet configuration completion', 5),
((SELECT component_id FROM Component WHERE component_no='ECS-006'), (SELECT aircraft_id FROM Aircraft WHERE aircraft_no='AC-1003'), (SELECT position_id FROM AircraftInstallPosition p JOIN Aircraft a ON p.aircraft_id=a.aircraft_id WHERE a.aircraft_no='AC-1003' AND p.position_code='air conditioning bay'), 'air conditioning bay', '2025-09-03 09:20:00', NULL, 'fleet configuration completion', 5),
((SELECT component_id FROM Component WHERE component_no='BAT-005'), (SELECT aircraft_id FROM Aircraft WHERE aircraft_no='AC-1003'), (SELECT position_id FROM AircraftInstallPosition p JOIN Aircraft a ON p.aircraft_id=a.aircraft_id WHERE a.aircraft_no='AC-1003' AND p.position_code='battery bay'), 'battery bay', '2025-09-03 09:30:00', NULL, 'fleet configuration completion', 5),
((SELECT component_id FROM Component WHERE component_no='LDB-005'), (SELECT aircraft_id FROM Aircraft WHERE aircraft_no='AC-1004'), (SELECT position_id FROM AircraftInstallPosition p JOIN Aircraft a ON p.aircraft_id=a.aircraft_id WHERE a.aircraft_no='AC-1004' AND p.position_code='landing gear bay'), 'landing gear bay', '2025-09-04 09:00:00', NULL, 'fleet configuration completion', 5),
((SELECT component_id FROM Component WHERE component_no='AVB-004'), (SELECT aircraft_id FROM Aircraft WHERE aircraft_no='AC-1004'), (SELECT position_id FROM AircraftInstallPosition p JOIN Aircraft a ON p.aircraft_id=a.aircraft_id WHERE a.aircraft_no='AC-1004' AND p.position_code='avionics bay'), 'avionics bay', '2025-09-04 09:10:00', NULL, 'fleet configuration completion', 5),
((SELECT component_id FROM Component WHERE component_no='HYD-008'), (SELECT aircraft_id FROM Aircraft WHERE aircraft_no='AC-1004'), (SELECT position_id FROM AircraftInstallPosition p JOIN Aircraft a ON p.aircraft_id=a.aircraft_id WHERE a.aircraft_no='AC-1004' AND p.position_code='hydraulic system bay'), 'hydraulic system bay', '2025-09-04 09:20:00', NULL, 'fleet configuration completion', 5),
((SELECT component_id FROM Component WHERE component_no='BRB-004'), (SELECT aircraft_id FROM Aircraft WHERE aircraft_no='AC-1004'), (SELECT position_id FROM AircraftInstallPosition p JOIN Aircraft a ON p.aircraft_id=a.aircraft_id WHERE a.aircraft_no='AC-1004' AND p.position_code='brake assembly'), 'brake assembly', '2025-09-04 09:30:00', NULL, 'fleet configuration completion', 5),
((SELECT component_id FROM Component WHERE component_no='BAT-006'), (SELECT aircraft_id FROM Aircraft WHERE aircraft_no='AC-1004'), (SELECT position_id FROM AircraftInstallPosition p JOIN Aircraft a ON p.aircraft_id=a.aircraft_id WHERE a.aircraft_no='AC-1004' AND p.position_code='battery bay'), 'battery bay', '2025-09-04 09:40:00', NULL, 'fleet configuration completion', 5),
((SELECT component_id FROM Component WHERE component_no='FUEL-007'), (SELECT aircraft_id FROM Aircraft WHERE aircraft_no='AC-1005'), (SELECT position_id FROM AircraftInstallPosition p JOIN Aircraft a ON p.aircraft_id=a.aircraft_id WHERE a.aircraft_no='AC-1005' AND p.position_code='fuel control bay'), 'fuel control bay', '2025-09-05 09:00:00', NULL, 'fleet configuration completion', 1),
((SELECT component_id FROM Component WHERE component_no='ECS-007'), (SELECT aircraft_id FROM Aircraft WHERE aircraft_no='AC-1005'), (SELECT position_id FROM AircraftInstallPosition p JOIN Aircraft a ON p.aircraft_id=a.aircraft_id WHERE a.aircraft_no='AC-1005' AND p.position_code='air conditioning bay'), 'air conditioning bay', '2025-09-05 09:10:00', NULL, 'fleet configuration completion', 1),
((SELECT component_id FROM Component WHERE component_no='BR3-001'), (SELECT aircraft_id FROM Aircraft WHERE aircraft_no='AC-1005'), (SELECT position_id FROM AircraftInstallPosition p JOIN Aircraft a ON p.aircraft_id=a.aircraft_id WHERE a.aircraft_no='AC-1005' AND p.position_code='brake assembly'), 'brake assembly', '2025-09-05 09:20:00', NULL, 'fleet configuration completion', 1),
((SELECT component_id FROM Component WHERE component_no='BAT-007'), (SELECT aircraft_id FROM Aircraft WHERE aircraft_no='AC-1005'), (SELECT position_id FROM AircraftInstallPosition p JOIN Aircraft a ON p.aircraft_id=a.aircraft_id WHERE a.aircraft_no='AC-1005' AND p.position_code='battery bay'), 'battery bay', '2025-09-05 09:30:00', NULL, 'fleet configuration completion', 1),
((SELECT component_id FROM Component WHERE component_no='LDG-006'), (SELECT aircraft_id FROM Aircraft WHERE aircraft_no='AC-1007'), (SELECT position_id FROM AircraftInstallPosition p JOIN Aircraft a ON p.aircraft_id=a.aircraft_id WHERE a.aircraft_no='AC-1007' AND p.position_code='landing gear bay'), 'landing gear bay', '2025-09-07 09:00:00', NULL, 'fleet configuration completion', 9),
((SELECT component_id FROM Component WHERE component_no='AVI-006'), (SELECT aircraft_id FROM Aircraft WHERE aircraft_no='AC-1007'), (SELECT position_id FROM AircraftInstallPosition p JOIN Aircraft a ON p.aircraft_id=a.aircraft_id WHERE a.aircraft_no='AC-1007' AND p.position_code='avionics bay'), 'avionics bay', '2025-09-07 09:10:00', NULL, 'fleet configuration completion', 9),
((SELECT component_id FROM Component WHERE component_no='NAV-009'), (SELECT aircraft_id FROM Aircraft WHERE aircraft_no='AC-1007'), (SELECT position_id FROM AircraftInstallPosition p JOIN Aircraft a ON p.aircraft_id=a.aircraft_id WHERE a.aircraft_no='AC-1007' AND p.position_code='navigation bay'), 'navigation bay', '2025-09-07 09:20:00', NULL, 'fleet configuration completion', 9),
((SELECT component_id FROM Component WHERE component_no='HYD-009'), (SELECT aircraft_id FROM Aircraft WHERE aircraft_no='AC-1007'), (SELECT position_id FROM AircraftInstallPosition p JOIN Aircraft a ON p.aircraft_id=a.aircraft_id WHERE a.aircraft_no='AC-1007' AND p.position_code='hydraulic system bay'), 'hydraulic system bay', '2025-09-07 09:30:00', NULL, 'fleet configuration completion', 9),
((SELECT component_id FROM Component WHERE component_no='FUEL-008'), (SELECT aircraft_id FROM Aircraft WHERE aircraft_no='AC-1007'), (SELECT position_id FROM AircraftInstallPosition p JOIN Aircraft a ON p.aircraft_id=a.aircraft_id WHERE a.aircraft_no='AC-1007' AND p.position_code='fuel control bay'), 'fuel control bay', '2025-09-07 09:40:00', NULL, 'fleet configuration completion', 9),
((SELECT component_id FROM Component WHERE component_no='ECS-008'), (SELECT aircraft_id FROM Aircraft WHERE aircraft_no='AC-1007'), (SELECT position_id FROM AircraftInstallPosition p JOIN Aircraft a ON p.aircraft_id=a.aircraft_id WHERE a.aircraft_no='AC-1007' AND p.position_code='air conditioning bay'), 'air conditioning bay', '2025-09-07 09:50:00', NULL, 'fleet configuration completion', 9),
((SELECT component_id FROM Component WHERE component_no='BRK-005'), (SELECT aircraft_id FROM Aircraft WHERE aircraft_no='AC-1007'), (SELECT position_id FROM AircraftInstallPosition p JOIN Aircraft a ON p.aircraft_id=a.aircraft_id WHERE a.aircraft_no='AC-1007' AND p.position_code='brake assembly'), 'brake assembly', '2025-09-07 10:00:00', NULL, 'fleet configuration completion', 9),
((SELECT component_id FROM Component WHERE component_no='BAT-008'), (SELECT aircraft_id FROM Aircraft WHERE aircraft_no='AC-1007'), (SELECT position_id FROM AircraftInstallPosition p JOIN Aircraft a ON p.aircraft_id=a.aircraft_id WHERE a.aircraft_no='AC-1007' AND p.position_code='battery bay'), 'battery bay', '2025-09-07 10:10:00', NULL, 'fleet configuration completion', 9);

UPDATE InstallationRecord ir
JOIN Component c ON ir.component_id = c.component_id
SET ir.install_time = TIMESTAMP('2024-01-01', TIME(ir.install_time)),
    ir.install_reason = 'baseline fleet configuration'
WHERE c.batch_no LIKE 'CFG-%'
  AND ir.uninstall_time IS NULL;

-- 40 条维修记录，覆盖多种类型和 pending/passed/failed/scrapped 结果，并形成可分析的维修间隔。
INSERT INTO MaintenanceRecord (component_id, maintenance_type, start_time, end_time, result, description, technician_id) VALUES
((SELECT component_id FROM Component WHERE component_no='ENG-001'), 'scheduled inspection', '2021-12-02 08:00:00', '2021-12-05 16:00:00', 'passed', '拆卸后计划检查通过，部件获准后续重新安装。', 2),
((SELECT component_id FROM Component WHERE component_no='ENG-001'), 'overhaul', '2024-12-21 08:00:00', '2024-12-28 17:00:00', 'scrapped', 'Life limit and turbine damage confirmed.', 2),
((SELECT component_id FROM Component WHERE component_no='NAV-001'), 'replacement check', '2024-11-19 08:00:00', '2024-11-20 15:00:00', 'failed', 'Navigation signal remained unstable.', 6),
((SELECT component_id FROM Component WHERE component_no='HYD-001'), 'fault repair', '2024-09-21 08:00:00', '2024-09-25 16:00:00', 'scrapped', 'Irreparable hydraulic leakage found.', 8),
((SELECT component_id FROM Component WHERE component_no='AVI-001'), 'fault repair', '2024-08-11 08:00:00', '2024-08-13 16:00:00', 'failed', 'Control module failed bench test.', 2),
((SELECT component_id FROM Component WHERE component_no='ENB-001'), 'overhaul', '2024-10-02 08:00:00', '2024-10-09 17:00:00', 'scrapped', 'Core damage exceeds repair limit.', 6),
((SELECT component_id FROM Component WHERE component_no='AV3-001'), 'fault repair', '2024-07-13 08:00:00', '2024-07-15 17:00:00', 'scrapped', 'Irreparable circuit damage.', 8),
((SELECT component_id FROM Component WHERE component_no='BRB-001'), 'replacement check', '2024-05-16 08:00:00', '2024-05-17 12:00:00', 'failed', 'Brake wear exceeds teaching threshold.', 2),
((SELECT component_id FROM Component WHERE component_no='ENG-002'), 'online inspection', '2025-02-11 08:00:00', '2025-02-11 12:00:00', 'passed', 'Online inspection passed while installed.', 6),
((SELECT component_id FROM Component WHERE component_no='NAV-002'), 'online inspection', '2025-02-12 16:00:00', '2025-02-12 18:00:00', 'passed', 'Navigation line accuracy check passed after landing.', 2),
((SELECT component_id FROM Component WHERE component_no='HYD-002'), 'online inspection', '2025-02-14 08:00:00', '2025-02-14 11:00:00', 'passed', 'Hydraulic pressure stable.', 8),
((SELECT component_id FROM Component WHERE component_no='AVI-002'), 'online inspection', '2025-03-01 08:00:00', '2025-03-01 15:00:00', 'passed', 'Installed avionics self-test passed.', 6),
((SELECT component_id FROM Component WHERE component_no='FUEL-002'), 'online inspection', '2025-03-03 08:00:00', '2025-03-03 12:00:00', 'passed', 'Fuel control response normal.', 2),
((SELECT component_id FROM Component WHERE component_no='ECS-002'), 'online inspection', '2025-03-05 08:00:00', '2025-03-05 12:00:00', 'passed', 'Installed cabin pressure sensor calibration passed.', 8),
((SELECT component_id FROM Component WHERE component_no='BRK-002'), 'online inspection', '2025-03-08 08:00:00', '2025-03-08 13:00:00', 'passed', 'Installed brake wear inspection passed.', 6),
((SELECT component_id FROM Component WHERE component_no='ENG-003'), 'online inspection', '2025-03-10 08:00:00', '2025-03-10 12:00:00', 'passed', 'Engine trend data normal.', 2),
((SELECT component_id FROM Component WHERE component_no='NAV-003'), 'online inspection', '2025-03-12 15:00:00', '2025-03-12 18:00:00', 'passed', 'Installed navigation replacement verification passed after landing.', 8),
((SELECT component_id FROM Component WHERE component_no='ENB-002'), 'online inspection', '2025-03-15 14:00:00', '2025-03-15 18:00:00', 'passed', 'Engine line inspection completed after landing.', 6),
((SELECT component_id FROM Component WHERE component_no='NAV-004'), 'online inspection', '2025-03-18 13:00:00', '2025-03-18 16:00:00', 'passed', 'Installed navigation signal check passed after calibration.', 2),
((SELECT component_id FROM Component WHERE component_no='HYD-003'), 'online inspection', '2025-03-21 08:00:00', '2025-03-21 12:00:00', 'passed', 'Pressure test passed.', 8),
((SELECT component_id FROM Component WHERE component_no='AVB-002'), 'online inspection', '2025-03-23 08:00:00', '2025-03-23 14:00:00', 'passed', 'Installed avionics inspection passed.', 6),
((SELECT component_id FROM Component WHERE component_no='EN3-002'), 'online inspection', '2025-03-25 08:00:00', '2025-03-25 12:00:00', 'passed', 'Installed engine trend inspection completed.', 2),
((SELECT component_id FROM Component WHERE component_no='NAV-006'), 'online inspection', '2025-04-01 08:00:00', '2025-04-01 12:00:00', 'passed', 'Navigation line check passed.', 8),
((SELECT component_id FROM Component WHERE component_no='LD3-002'), 'online inspection', '2025-04-03 08:00:00', '2025-04-03 12:00:00', 'passed', 'Installed landing gear functional inspection passed.', 6),
((SELECT component_id FROM Component WHERE component_no='ENG-004'), 'online inspection', '2025-04-06 08:00:00', '2025-04-06 12:00:00', 'passed', 'Installed engine oil sensor signal inspection passed.', 2),
((SELECT component_id FROM Component WHERE component_no='EN3-004'), 'overhaul', '2026-06-10 08:00:00', NULL, 'pending', 'Engine overhaul in progress.', 6),
((SELECT component_id FROM Component WHERE component_no='NAV-007'), 'fault repair', '2026-06-11 08:00:00', NULL, 'pending', 'Navigation fault isolation in progress.', 8),
((SELECT component_id FROM Component WHERE component_no='HYD-006'), 'fault repair', '2026-06-12 08:00:00', NULL, 'pending', 'Hydraulic pump repair in progress.', 2),
((SELECT component_id FROM Component WHERE component_no='AVB-003'), 'replacement check', '2026-06-13 08:00:00', NULL, 'pending', 'Replacement verification pending.', 6),
((SELECT component_id FROM Component WHERE component_no='LD3-003'), 'scheduled inspection', '2026-06-14 08:00:00', NULL, 'pending', 'Landing gear inspection pending.', 8),
((SELECT component_id FROM Component WHERE component_no='HYD-005'), 'scheduled inspection', '2025-02-01 08:00:00', '2025-02-02 16:00:00', 'failed', 'Pressure fluctuation requires further repair.', 2),
((SELECT component_id FROM Component WHERE component_no='NAV-005'), 'online inspection', '2026-06-16 09:00:00', NULL, 'pending', 'Online inspection for installed-state verification.', 2);

-- 补充同一部件的多次已完成维修，使维修间隔和周期预警呈现 normal/warning/due/overdue 多层结果。
INSERT INTO MaintenanceRecord (component_id, maintenance_type, start_time, end_time, result, description, technician_id) VALUES
((SELECT component_id FROM Component WHERE component_no='ENG-002'), 'online inspection', '2025-04-11 08:00:00', '2025-04-11 12:00:00', 'passed', 'Quarterly engine trend inspection passed.', 2),
((SELECT component_id FROM Component WHERE component_no='ENG-002'), 'online inspection', '2025-07-15 08:00:00', '2025-07-15 12:00:00', 'passed', 'Recent engine cycle inspection passed.', 6),
((SELECT component_id FROM Component WHERE component_no='NAV-002'), 'online inspection', '2025-04-12 08:00:00', '2025-04-12 11:00:00', 'passed', 'Navigation accuracy inspection passed.', 8),
((SELECT component_id FROM Component WHERE component_no='NAV-002'), 'online inspection', '2025-07-15 08:00:00', '2025-07-15 11:00:00', 'passed', 'Navigation cycle reset inspection passed.', 2),
((SELECT component_id FROM Component WHERE component_no='HYD-002'), 'online inspection', '2025-04-13 08:00:00', '2025-04-13 11:00:00', 'passed', 'Hydraulic pressure trend normal.', 6),
((SELECT component_id FROM Component WHERE component_no='HYD-002'), 'online inspection', '2025-07-15 08:00:00', '2025-07-15 11:00:00', 'passed', 'Hydraulic periodic inspection passed.', 8),
((SELECT component_id FROM Component WHERE component_no='BRK-002'), 'online inspection', '2025-07-15 09:00:00', '2025-07-15 12:00:00', 'passed', 'Brake wear inspection passed.', 6),
((SELECT component_id FROM Component WHERE component_no='AVI-002'), 'online inspection', '2025-08-11 08:00:00', '2025-08-11 11:00:00', 'passed', 'Avionics inspection after latest flight passed.', 2);

-- 57 条候选飞行记录；插入后仅保留在飞行全程具备完整位置配置的记录。
INSERT INTO FlightLog (aircraft_id, mission_no, takeoff_time, landing_time, flight_hours, mission_type, recorded_by) VALUES
((SELECT aircraft_id FROM Aircraft WHERE aircraft_no='AC-1001'), 'FL-240210-01', '2024-02-10 07:00:00', '2024-02-10 13:00:00', 6.00, 'training', 4),
((SELECT aircraft_id FROM Aircraft WHERE aircraft_no='AC-1001'), 'FL-240410-01', '2024-04-10 07:00:00', '2024-04-10 13:00:00', 6.00, 'patrol', 10),
((SELECT aircraft_id FROM Aircraft WHERE aircraft_no='AC-1001'), 'FL-240610-01', '2024-06-10 07:00:00', '2024-06-10 13:00:00', 6.00, 'transport', 4),
((SELECT aircraft_id FROM Aircraft WHERE aircraft_no='AC-1001'), 'FL-240910-01', '2024-09-10 07:00:00', '2024-09-10 13:00:00', 6.00, 'training', 10),
((SELECT aircraft_id FROM Aircraft WHERE aircraft_no='AC-1002'), 'FL-240112-02', '2024-01-12 08:00:00', '2024-01-12 13:00:00', 5.00, 'training', 4),
((SELECT aircraft_id FROM Aircraft WHERE aircraft_no='AC-1002'), 'FL-240412-02', '2024-04-12 08:00:00', '2024-04-12 13:00:00', 5.00, 'patrol', 10),
((SELECT aircraft_id FROM Aircraft WHERE aircraft_no='AC-1002'), 'FL-240712-02', '2024-07-12 08:00:00', '2024-07-12 13:00:00', 5.00, 'transport', 4),
((SELECT aircraft_id FROM Aircraft WHERE aircraft_no='AC-1003'), 'FL-240215-03', '2024-02-15 08:00:00', '2024-02-15 13:00:00', 5.00, 'training', 10),
((SELECT aircraft_id FROM Aircraft WHERE aircraft_no='AC-1003'), 'FL-240515-03', '2024-05-15 08:00:00', '2024-05-15 13:00:00', 5.00, 'patrol', 4),
((SELECT aircraft_id FROM Aircraft WHERE aircraft_no='AC-1003'), 'FL-240815-03', '2024-08-15 08:00:00', '2024-08-15 13:00:00', 5.00, 'transport', 10),
((SELECT aircraft_id FROM Aircraft WHERE aircraft_no='AC-1004'), 'FL-240118-04', '2024-01-18 08:00:00', '2024-01-18 12:00:00', 4.00, 'training', 4),
((SELECT aircraft_id FROM Aircraft WHERE aircraft_no='AC-1004'), 'FL-240418-04', '2024-04-18 08:00:00', '2024-04-18 12:00:00', 4.00, 'patrol', 10),
((SELECT aircraft_id FROM Aircraft WHERE aircraft_no='AC-1005'), 'FL-240220-05', '2024-02-20 07:00:00', '2024-02-20 13:00:00', 6.00, 'training', 4),
((SELECT aircraft_id FROM Aircraft WHERE aircraft_no='AC-1005'), 'FL-240520-05', '2024-05-20 07:00:00', '2024-05-20 13:00:00', 6.00, 'patrol', 10),
((SELECT aircraft_id FROM Aircraft WHERE aircraft_no='AC-1009'), 'FL-230310-09', '2023-03-10 09:00:00', '2023-03-10 13:00:00', 4.00, 'training', 4),
((SELECT aircraft_id FROM Aircraft WHERE aircraft_no='AC-1009'), 'FL-230810-09', '2023-08-10 09:00:00', '2023-08-10 13:00:00', 4.00, 'patrol', 10),
((SELECT aircraft_id FROM Aircraft WHERE aircraft_no='AC-1009'), 'FL-240210-09', '2024-02-10 09:00:00', '2024-02-10 13:00:00', 4.00, 'transport', 4),
((SELECT aircraft_id FROM Aircraft WHERE aircraft_no='AC-1001'), 'FL-250101-01', '2025-01-10 06:00:00', '2025-01-10 13:00:00', 7.00, 'training', 4),
((SELECT aircraft_id FROM Aircraft WHERE aircraft_no='AC-1001'), 'FL-250201-01', '2025-02-10 06:00:00', '2025-02-10 13:00:00', 7.00, 'patrol', 10),
((SELECT aircraft_id FROM Aircraft WHERE aircraft_no='AC-1001'), 'FL-250301-01', '2025-03-10 06:00:00', '2025-03-10 13:00:00', 7.00, 'transport', 4),
((SELECT aircraft_id FROM Aircraft WHERE aircraft_no='AC-1001'), 'FL-250401-01', '2025-04-10 06:00:00', '2025-04-10 13:00:00', 7.00, 'training', 10),
((SELECT aircraft_id FROM Aircraft WHERE aircraft_no='AC-1001'), 'FL-250501-01', '2025-05-10 06:00:00', '2025-05-10 13:00:00', 7.00, 'patrol', 4),
((SELECT aircraft_id FROM Aircraft WHERE aircraft_no='AC-1001'), 'FL-250601-01', '2025-06-10 06:00:00', '2025-06-10 13:00:00', 7.00, 'transport', 10),
((SELECT aircraft_id FROM Aircraft WHERE aircraft_no='AC-1001'), 'FL-250701-01', '2025-07-10 06:00:00', '2025-07-10 13:00:00', 7.00, 'training', 4),
((SELECT aircraft_id FROM Aircraft WHERE aircraft_no='AC-1001'), 'FL-250801-01', '2025-08-10 06:00:00', '2025-08-10 15:00:00', 9.00, 'patrol', 10),
((SELECT aircraft_id FROM Aircraft WHERE aircraft_no='AC-1002'), 'FL-250112-02', '2025-01-12 07:00:00', '2025-01-12 14:00:00', 7.00, 'training', 4),
((SELECT aircraft_id FROM Aircraft WHERE aircraft_no='AC-1002'), 'FL-250212-02', '2025-02-12 07:00:00', '2025-02-12 14:00:00', 7.00, 'patrol', 10),
((SELECT aircraft_id FROM Aircraft WHERE aircraft_no='AC-1002'), 'FL-250312-02', '2025-03-12 07:00:00', '2025-03-12 14:00:00', 7.00, 'transport', 4),
((SELECT aircraft_id FROM Aircraft WHERE aircraft_no='AC-1002'), 'FL-250412-02', '2025-04-12 07:00:00', '2025-04-12 14:00:00', 7.00, 'training', 10),
((SELECT aircraft_id FROM Aircraft WHERE aircraft_no='AC-1002'), 'FL-250512-02', '2025-05-12 07:00:00', '2025-05-12 14:00:00', 7.00, 'patrol', 4),
((SELECT aircraft_id FROM Aircraft WHERE aircraft_no='AC-1002'), 'FL-250612-02', '2025-06-12 07:00:00', '2025-06-12 14:00:00', 7.00, 'transport', 10),
((SELECT aircraft_id FROM Aircraft WHERE aircraft_no='AC-1003'), 'FL-250115-03', '2025-01-15 08:00:00', '2025-01-15 13:00:00', 5.00, 'training', 4),
((SELECT aircraft_id FROM Aircraft WHERE aircraft_no='AC-1003'), 'FL-250215-03', '2025-02-15 08:00:00', '2025-02-15 13:00:00', 5.00, 'patrol', 10),
((SELECT aircraft_id FROM Aircraft WHERE aircraft_no='AC-1003'), 'FL-250315-03', '2025-03-15 08:00:00', '2025-03-15 13:00:00', 5.00, 'transport', 4),
((SELECT aircraft_id FROM Aircraft WHERE aircraft_no='AC-1003'), 'FL-250415-03', '2025-04-15 08:00:00', '2025-04-15 13:00:00', 5.00, 'training', 10),
((SELECT aircraft_id FROM Aircraft WHERE aircraft_no='AC-1003'), 'FL-250515-03', '2025-05-15 08:00:00', '2025-05-15 13:00:00', 5.00, 'patrol', 4),
((SELECT aircraft_id FROM Aircraft WHERE aircraft_no='AC-1004'), 'FL-250118-04', '2025-01-18 08:00:00', '2025-01-18 12:00:00', 4.00, 'training', 10),
((SELECT aircraft_id FROM Aircraft WHERE aircraft_no='AC-1004'), 'FL-250218-04', '2025-02-18 08:00:00', '2025-02-18 12:00:00', 4.00, 'patrol', 4),
((SELECT aircraft_id FROM Aircraft WHERE aircraft_no='AC-1004'), 'FL-250318-04', '2025-03-18 08:00:00', '2025-03-18 12:00:00', 4.00, 'transport', 10),
((SELECT aircraft_id FROM Aircraft WHERE aircraft_no='AC-1004'), 'FL-250418-04', '2025-04-18 08:00:00', '2025-04-18 12:00:00', 4.00, 'training', 4),
((SELECT aircraft_id FROM Aircraft WHERE aircraft_no='AC-1004'), 'FL-250518-04', '2025-05-18 08:00:00', '2025-05-18 12:00:00', 4.00, 'patrol', 10),
((SELECT aircraft_id FROM Aircraft WHERE aircraft_no='AC-1005'), 'FL-250120-05', '2025-01-20 07:00:00', '2025-01-20 13:00:00', 6.00, 'transport', 4),
((SELECT aircraft_id FROM Aircraft WHERE aircraft_no='AC-1005'), 'FL-250220-05', '2025-02-20 07:00:00', '2025-02-20 13:00:00', 6.00, 'training', 10),
((SELECT aircraft_id FROM Aircraft WHERE aircraft_no='AC-1005'), 'FL-250320-05', '2025-03-20 07:00:00', '2025-03-20 13:00:00', 6.00, 'patrol', 4),
((SELECT aircraft_id FROM Aircraft WHERE aircraft_no='AC-1005'), 'FL-250420-05', '2025-04-20 07:00:00', '2025-04-20 13:00:00', 6.00, 'transport', 10),
((SELECT aircraft_id FROM Aircraft WHERE aircraft_no='AC-1005'), 'FL-250520-05', '2025-05-20 07:00:00', '2025-05-20 13:00:00', 6.00, 'training', 4),
((SELECT aircraft_id FROM Aircraft WHERE aircraft_no='AC-1006'), 'FL-250215-06', '2025-02-15 09:00:00', '2025-02-15 14:00:00', 5.00, 'test flight', 10),
((SELECT aircraft_id FROM Aircraft WHERE aircraft_no='AC-1006'), 'FL-250315-06', '2025-03-15 09:00:00', '2025-03-15 14:00:00', 5.00, 'test flight', 4),
((SELECT aircraft_id FROM Aircraft WHERE aircraft_no='AC-1006'), 'FL-250415-06', '2025-04-15 09:00:00', '2025-04-15 14:00:00', 5.00, 'training', 10),
((SELECT aircraft_id FROM Aircraft WHERE aircraft_no='AC-1006'), 'FL-250515-06', '2025-05-15 09:00:00', '2025-05-15 14:00:00', 5.00, 'training', 4),
((SELECT aircraft_id FROM Aircraft WHERE aircraft_no='AC-1007'), 'FL-250125-07', '2025-01-25 10:00:00', '2025-01-25 13:00:00', 3.00, 'training', 10),
((SELECT aircraft_id FROM Aircraft WHERE aircraft_no='AC-1007'), 'FL-250225-07', '2025-02-25 10:00:00', '2025-02-25 13:00:00', 3.00, 'patrol', 4),
((SELECT aircraft_id FROM Aircraft WHERE aircraft_no='AC-1007'), 'FL-250325-07', '2025-03-25 10:00:00', '2025-03-25 13:00:00', 3.00, 'transport', 10),
((SELECT aircraft_id FROM Aircraft WHERE aircraft_no='AC-1007'), 'FL-250425-07', '2025-04-25 10:00:00', '2025-04-25 13:00:00', 3.00, 'training', 4),
((SELECT aircraft_id FROM Aircraft WHERE aircraft_no='AC-1008'), 'FL-241201-08', '2024-12-01 11:00:00', '2024-12-01 13:00:00', 2.00, 'training', 10),
((SELECT aircraft_id FROM Aircraft WHERE aircraft_no='AC-1008'), 'FL-250101-08', '2025-01-01 11:00:00', '2025-01-01 13:00:00', 2.00, 'patrol', 4),
((SELECT aircraft_id FROM Aircraft WHERE aircraft_no='AC-1008'), 'FL-250201-08', '2025-02-01 11:00:00', '2025-02-01 13:00:00', 2.00, 'test flight', 10);

-- 飞行日志只能保留在全部有效安装位均有部件覆盖的航段。
-- 清理后仍保留 33 条代表性飞行记录，并杜绝“缺件飞行”的时间线硬伤。
DELETE fl
FROM FlightLog fl
WHERE EXISTS (
    SELECT 1
    FROM AircraftInstallPosition p
    WHERE p.aircraft_id = fl.aircraft_id
      AND p.is_active = TRUE
      AND NOT EXISTS (
          SELECT 1
          FROM InstallationRecord ir
          WHERE ir.aircraft_id = fl.aircraft_id
            AND ir.position_id = p.position_id
            AND ir.install_time <= fl.takeoff_time
            AND (ir.uninstall_time IS NULL OR ir.uninstall_time >= fl.landing_time)
      )
);

-- AC-1001 集中承载寿命分层演示：LDG-004 为预警、AVI-002 为严重、BAT-002 已到寿且维修逾期。
-- 因 BAT-002 已到设计寿命，飞机保持停场，必须完成部件更换后才能恢复服役。
UPDATE Aircraft
SET service_status = 'maintenance'
WHERE aircraft_no = 'AC-1001';

-- 21 条维修计划：4 待执行、4 执行中、8 completed、5 cancelled。
INSERT INTO MaintenancePlan (component_id, planned_type, planned_time, planned_reason, status, created_by, created_at, completed_at, related_maintenance_id) VALUES
((SELECT component_id FROM Component WHERE component_no='ENG-001'), 'scheduled_inspection', '2021-12-02 08:00:00', '首次拆卸后执行计划检查，为后续重新安装提供依据。', 'completed', 3, '2021-12-01 19:00:00', '2021-12-05 16:00:00', (SELECT maintenance_id FROM MaintenanceRecord WHERE component_id=(SELECT component_id FROM Component WHERE component_no='ENG-001') AND result='passed' LIMIT 1)),
((SELECT component_id FROM Component WHERE component_no='ENG-002'), 'life_limit_check', '2026-07-05 09:00:00', 'High life usage requires focused inspection.', 'pending', 3, '2026-06-15 09:00:00', NULL, NULL),
((SELECT component_id FROM Component WHERE component_no='NAV-002'), 'life_limit_check', '2026-07-06 09:00:00', 'Critical navigation life usage.', 'pending', 7, '2026-06-15 09:10:00', NULL, NULL),
((SELECT component_id FROM Component WHERE component_no='HYD-002'), 'preventive_maintenance', '2026-07-07 09:00:00', 'Preventive pressure inspection.', 'pending', 3, '2026-06-15 09:20:00', NULL, NULL),
((SELECT component_id FROM Component WHERE component_no='BRK-002'), 'life_limit_check', '2026-07-08 09:00:00', 'Brake life warning follow-up.', 'pending', 7, '2026-06-15 09:30:00', NULL, NULL),
((SELECT component_id FROM Component WHERE component_no='EN3-004'), 'scheduled_inspection', '2026-06-10 08:00:00', 'Follow-up after overhaul.', 'pending', 3, '2026-06-01 09:00:00', NULL, (SELECT maintenance_id FROM MaintenanceRecord WHERE component_id=(SELECT component_id FROM Component WHERE component_no='EN3-004') AND result='pending' LIMIT 1)),
((SELECT component_id FROM Component WHERE component_no='NAV-007'), 'preventive_maintenance', '2026-06-11 08:00:00', 'Navigation fault prevention plan.', 'pending', 7, '2026-06-01 09:10:00', NULL, (SELECT maintenance_id FROM MaintenanceRecord WHERE component_id=(SELECT component_id FROM Component WHERE component_no='NAV-007') AND result='pending' LIMIT 1)),
((SELECT component_id FROM Component WHERE component_no='HYD-006'), 'scheduled_inspection', '2026-06-12 08:00:00', 'Hydraulic repair quality review.', 'pending', 3, '2026-06-01 09:20:00', NULL, (SELECT maintenance_id FROM MaintenanceRecord WHERE component_id=(SELECT component_id FROM Component WHERE component_no='HYD-006') AND result='pending' LIMIT 1)),
((SELECT component_id FROM Component WHERE component_no='LD3-003'), 'preventive_maintenance', '2026-06-14 08:00:00', 'Landing gear preventive inspection.', 'pending', 7, '2026-06-01 09:30:00', NULL, (SELECT maintenance_id FROM MaintenanceRecord WHERE component_id=(SELECT component_id FROM Component WHERE component_no='LD3-003') AND result='pending' LIMIT 1)),
((SELECT component_id FROM Component WHERE component_no='ENG-003'), 'scheduled_inspection', '2025-03-10 08:00:00', 'Routine engine inspection.', 'completed', 3, '2025-03-01 09:00:00', '2025-03-10 12:00:00', (SELECT maintenance_id FROM MaintenanceRecord WHERE component_id=(SELECT component_id FROM Component WHERE component_no='ENG-003') LIMIT 1)),
((SELECT component_id FROM Component WHERE component_no='NAV-003'), 'post_replacement_check', '2025-03-12 15:00:00', 'Validate replacement installation after landing.', 'completed', 7, '2025-03-01 09:00:00', '2025-03-12 18:00:00', (SELECT maintenance_id FROM MaintenanceRecord WHERE component_id=(SELECT component_id FROM Component WHERE component_no='NAV-003') LIMIT 1)),
((SELECT component_id FROM Component WHERE component_no='ENB-002'), 'preventive_maintenance', '2025-03-16 09:00:00', 'Scheduled engine prevention task.', 'completed', 3, '2025-03-01 09:10:00', '2025-03-16 15:00:00', (SELECT maintenance_id FROM MaintenanceRecord WHERE component_id=(SELECT component_id FROM Component WHERE component_no='ENB-002') LIMIT 1)),
((SELECT component_id FROM Component WHERE component_no='HYD-003'), 'scheduled_inspection', '2025-03-21 08:00:00', 'Hydraulic pressure inspection.', 'completed', 7, '2025-03-05 09:00:00', '2025-03-21 12:00:00', (SELECT maintenance_id FROM MaintenanceRecord WHERE component_id=(SELECT component_id FROM Component WHERE component_no='HYD-003') LIMIT 1)),
((SELECT component_id FROM Component WHERE component_no='EN3-002'), 'preventive_maintenance', '2025-03-30 09:00:00', 'Teaching overhaul plan.', 'completed', 3, '2025-03-10 09:00:00', '2025-03-30 17:00:00', (SELECT maintenance_id FROM MaintenanceRecord WHERE component_id=(SELECT component_id FROM Component WHERE component_no='EN3-002') LIMIT 1)),
((SELECT component_id FROM Component WHERE component_no='NAV-006'), 'scheduled_inspection', '2025-04-01 08:00:00', 'Navigation line inspection.', 'completed', 7, '2025-03-15 09:00:00', '2025-04-01 12:00:00', (SELECT maintenance_id FROM MaintenanceRecord WHERE component_id=(SELECT component_id FROM Component WHERE component_no='NAV-006') LIMIT 1)),
((SELECT component_id FROM Component WHERE component_no='LD3-002'), 'scheduled_inspection', '2025-04-04 09:00:00', 'Landing gear scheduled check.', 'completed', 3, '2025-03-18 09:00:00', '2025-04-04 15:00:00', (SELECT maintenance_id FROM MaintenanceRecord WHERE component_id=(SELECT component_id FROM Component WHERE component_no='LD3-002') LIMIT 1)),
((SELECT component_id FROM Component WHERE component_no='ENG-005'), 'scheduled_inspection', '2025-05-10 09:00:00', 'Plan superseded by inventory rotation.', 'cancelled', 7, '2025-04-01 09:00:00', '2025-04-20 10:00:00', NULL),
((SELECT component_id FROM Component WHERE component_no='NAV-008'), 'preventive_maintenance', '2025-05-12 09:00:00', 'No longer required after scope change.', 'cancelled', 3, '2025-04-02 09:00:00', '2025-04-21 10:00:00', NULL),
((SELECT component_id FROM Component WHERE component_no='AVI-003'), 'post_replacement_check', '2025-05-14 09:00:00', 'Replacement task was deferred.', 'cancelled', 7, '2025-04-03 09:00:00', '2025-04-22 10:00:00', NULL),
((SELECT component_id FROM Component WHERE component_no='FUEL-005'), 'life_limit_check', '2025-05-16 09:00:00', 'Component moved back to reserve stock.', 'cancelled', 3, '2025-04-04 09:00:00', '2025-04-23 10:00:00', NULL),
((SELECT component_id FROM Component WHERE component_no='BRB-003'), 'scheduled_inspection', '2025-05-18 09:00:00', 'Fleet maintenance window changed.', 'cancelled', 7, '2025-04-05 09:00:00', '2025-04-24 10:00:00', NULL);

-- 12 条退役记录，原因覆盖寿命、维修失败、不可修复损伤、更换和经济性退役。
INSERT INTO RetirementRecord (component_id, retirement_time, retirement_reason, approved_by, remark) VALUES
((SELECT component_id FROM Component WHERE component_no='ENG-001'), '2024-12-29 10:00:00', 'life limit reached', 3, 'Retired after replacement by ENG-002.'),
((SELECT component_id FROM Component WHERE component_no='ENB-001'), '2024-10-10 10:00:00', 'scrapped after maintenance', 7, 'Maintenance failure resulted in retirement.'),
((SELECT component_id FROM Component WHERE component_no='NAV-001'), '2024-11-21 10:00:00', 'life limit reached after replacement', 3, 'Replaced by NAV-002.'),
((SELECT component_id FROM Component WHERE component_no='HYD-001'), '2024-09-26 10:00:00', 'irreparable damage found during inspection', 7, 'Irreparable leakage.'),
((SELECT component_id FROM Component WHERE component_no='AVI-001'), '2024-08-14 10:00:00', 'economic retirement', 3, 'Repair cost exceeded teaching threshold.'),
((SELECT component_id FROM Component WHERE component_no='AV3-001'), '2024-07-16 10:00:00', 'irreparable damage found during inspection', 7, 'Circuit damage confirmed.'),
((SELECT component_id FROM Component WHERE component_no='LDG-001'), '2024-06-03 10:00:00', 'economic retirement', 3, 'Retired with aircraft AC-1009.'),
((SELECT component_id FROM Component WHERE component_no='FUEL-001'), '2024-06-03 10:10:00', 'replacement retirement', 7, 'Retired after fleet configuration change.'),
((SELECT component_id FROM Component WHERE component_no='ECS-001'), '2024-06-03 10:20:00', 'life limit reached', 3, 'Reached teaching life threshold.'),
((SELECT component_id FROM Component WHERE component_no='BRK-001'), '2024-06-03 10:30:00', 'economic retirement', 7, 'Retired with aircraft AC-1009.'),
((SELECT component_id FROM Component WHERE component_no='BRB-001'), '2024-05-18 10:00:00', 'life limit reached after replacement', 3, 'Replaced during brake system upgrade.'),
((SELECT component_id FROM Component WHERE component_no='BAT-001'), '2024-06-03 10:40:00', 'replacement retirement', 7, 'Battery replaced during fleet retirement.' );

-- 30 条人工审计日志，覆盖关键业务类型及维修计划开始执行；均使用已有操作人员。
INSERT INTO AuditLog (operator_id, operation_type, target_table, target_id, operation_time, operation_detail) VALUES
(3, 'create_maintenance_plan', 'MaintenancePlan', (SELECT plan_id FROM MaintenancePlan WHERE component_id=(SELECT component_id FROM Component WHERE component_no='ENG-001') AND status='completed' LIMIT 1), '2021-12-01 19:00:00', 'Created maintenance plan for component ENG-001; type: scheduled_inspection'),
(3, 'maintenance_plan_completed', 'MaintenancePlan', (SELECT plan_id FROM MaintenancePlan WHERE component_id=(SELECT component_id FROM Component WHERE component_no='ENG-001') AND status='completed' LIMIT 1), '2021-12-05 16:00:00', 'Completed maintenance plan for component ENG-001; type: scheduled_inspection'),
(5, 'component_replacement', 'InstallationRecord', (SELECT installation_id FROM InstallationRecord WHERE component_id=(SELECT component_id FROM Component WHERE component_no='ENG-002') AND uninstall_time IS NULL LIMIT 1), '2025-01-01 08:00:00', 'Replaced component ENG-001 with ENG-002 on aircraft AC-1001 at left engine position'),
(5, 'component_replacement', 'InstallationRecord', (SELECT installation_id FROM InstallationRecord WHERE component_id=(SELECT component_id FROM Component WHERE component_no='NAV-002') AND uninstall_time IS NULL LIMIT 1), '2025-01-01 08:10:00', 'Replaced component NAV-001 with NAV-002 on aircraft AC-1001 at navigation bay'),
(9, 'component_replacement', 'InstallationRecord', (SELECT installation_id FROM InstallationRecord WHERE component_id=(SELECT component_id FROM Component WHERE component_no='ENB-002') AND uninstall_time IS NULL LIMIT 1), '2025-01-03 08:00:00', 'Replaced component ENB-001 with ENB-002 on aircraft AC-1003 at left engine position'),
(9, 'component_replacement', 'InstallationRecord', (SELECT installation_id FROM InstallationRecord WHERE component_id=(SELECT component_id FROM Component WHERE component_no='BRB-002') AND uninstall_time IS NULL LIMIT 1), '2025-01-03 08:40:00', 'Replaced component BRB-001 with BRB-002 on aircraft AC-1003 at brake assembly'),
(3, 'component_retirement', 'RetirementRecord', (SELECT retirement_id FROM RetirementRecord WHERE component_id=(SELECT component_id FROM Component WHERE component_no='ENG-001')), '2024-12-29 10:00:00', 'Retired component ENG-001; reason: life limit reached'),
(7, 'component_retirement', 'RetirementRecord', (SELECT retirement_id FROM RetirementRecord WHERE component_id=(SELECT component_id FROM Component WHERE component_no='HYD-001')), '2024-09-26 10:00:00', 'Retired component HYD-001; reason: irreparable damage found during inspection'),
(3, 'component_retirement', 'RetirementRecord', (SELECT retirement_id FROM RetirementRecord WHERE component_id=(SELECT component_id FROM Component WHERE component_no='AVI-001')), '2024-08-14 10:00:00', 'Retired component AVI-001; reason: economic retirement'),
(7, 'component_retirement', 'RetirementRecord', (SELECT retirement_id FROM RetirementRecord WHERE component_id=(SELECT component_id FROM Component WHERE component_no='BRB-001')), '2024-05-18 10:00:00', 'Retired component BRB-001; reason: life limit reached after replacement'),
(2, 'maintenance_completion', 'MaintenanceRecord', (SELECT maintenance_id FROM MaintenanceRecord WHERE component_id=(SELECT component_id FROM Component WHERE component_no='ENG-002') LIMIT 1), '2025-02-11 12:00:00', 'Completed maintenance for component ENG-002; result: passed'),
(6, 'maintenance_completion', 'MaintenanceRecord', (SELECT maintenance_id FROM MaintenanceRecord WHERE component_id=(SELECT component_id FROM Component WHERE component_no='NAV-002') LIMIT 1), '2025-02-12 18:00:00', 'Completed maintenance for component NAV-002; result: passed'),
(8, 'maintenance_completion', 'MaintenanceRecord', (SELECT maintenance_id FROM MaintenanceRecord WHERE component_id=(SELECT component_id FROM Component WHERE component_no='NAV-004') LIMIT 1), '2025-03-18 16:00:00', 'Completed maintenance for component NAV-004; result: passed'),
(2, 'maintenance_completion', 'MaintenanceRecord', (SELECT maintenance_id FROM MaintenanceRecord WHERE component_id=(SELECT component_id FROM Component WHERE component_no='EN3-002') LIMIT 1), '2025-03-25 12:00:00', 'Completed maintenance for component EN3-002; result: passed'),
(3, 'create_maintenance_plan', 'MaintenancePlan', (SELECT plan_id FROM MaintenancePlan WHERE component_id=(SELECT component_id FROM Component WHERE component_no='ENG-002') AND status='pending' LIMIT 1), '2026-06-15 09:00:00', 'Created maintenance plan for component ENG-002; type: life_limit_check'),
(7, 'create_maintenance_plan', 'MaintenancePlan', (SELECT plan_id FROM MaintenancePlan WHERE component_id=(SELECT component_id FROM Component WHERE component_no='NAV-002') AND status='pending' LIMIT 1), '2026-06-15 09:10:00', 'Created maintenance plan for component NAV-002; type: life_limit_check'),
(3, 'create_maintenance_plan', 'MaintenancePlan', (SELECT plan_id FROM MaintenancePlan WHERE component_id=(SELECT component_id FROM Component WHERE component_no='HYD-002') AND status='pending' LIMIT 1), '2026-06-15 09:20:00', 'Created maintenance plan for component HYD-002; type: preventive_maintenance'),
(7, 'create_maintenance_plan', 'MaintenancePlan', (SELECT plan_id FROM MaintenancePlan WHERE component_id=(SELECT component_id FROM Component WHERE component_no='LD3-003') AND status='pending' LIMIT 1), '2026-06-01 09:30:00', 'Created maintenance plan for component LD3-003; type: preventive_maintenance'),
(3, 'maintenance_plan_completed', 'MaintenancePlan', (SELECT plan_id FROM MaintenancePlan WHERE component_id=(SELECT component_id FROM Component WHERE component_no='ENG-003') AND status='completed' LIMIT 1), '2025-03-10 12:00:00', 'Completed maintenance plan for component ENG-003; type: scheduled_inspection'),
(7, 'maintenance_plan_completed', 'MaintenancePlan', (SELECT plan_id FROM MaintenancePlan WHERE component_id=(SELECT component_id FROM Component WHERE component_no='NAV-003') AND status='completed' LIMIT 1), '2025-03-12 18:00:00', 'Completed maintenance plan for component NAV-003; type: post_replacement_check'),
(3, 'maintenance_plan_completed', 'MaintenancePlan', (SELECT plan_id FROM MaintenancePlan WHERE component_id=(SELECT component_id FROM Component WHERE component_no='ENB-002') AND status='completed' LIMIT 1), '2025-03-16 15:00:00', 'Completed maintenance plan for component ENB-002; type: preventive_maintenance'),
(7, 'maintenance_plan_cancelled', 'MaintenancePlan', (SELECT plan_id FROM MaintenancePlan WHERE component_id=(SELECT component_id FROM Component WHERE component_no='ENG-005') AND status='cancelled' LIMIT 1), '2025-04-20 10:00:00', 'Cancelled maintenance plan for component ENG-005; type: scheduled_inspection'),
(3, 'maintenance_plan_cancelled', 'MaintenancePlan', (SELECT plan_id FROM MaintenancePlan WHERE component_id=(SELECT component_id FROM Component WHERE component_no='NAV-008') AND status='cancelled' LIMIT 1), '2025-04-21 10:00:00', 'Cancelled maintenance plan for component NAV-008; type: preventive_maintenance'),
(7, 'maintenance_plan_cancelled', 'MaintenancePlan', (SELECT plan_id FROM MaintenancePlan WHERE component_id=(SELECT component_id FROM Component WHERE component_no='AVI-003') AND status='cancelled' LIMIT 1), '2025-04-22 10:00:00', 'Cancelled maintenance plan for component AVI-003; type: post_replacement_check'),
(4, 'maintenance_completion', 'MaintenanceRecord', (SELECT maintenance_id FROM MaintenanceRecord WHERE component_id=(SELECT component_id FROM Component WHERE component_no='ENG-001') LIMIT 1), '2024-12-28 17:00:00', 'Completed maintenance for component ENG-001; result: scrapped'),
(10, 'component_retirement', 'RetirementRecord', (SELECT retirement_id FROM RetirementRecord WHERE component_id=(SELECT component_id FROM Component WHERE component_no='BAT-001')), '2024-06-03 10:40:00', 'Retired component BAT-001; reason: replacement retirement'),
(3, 'maintenance_plan_started', 'MaintenancePlan', (SELECT plan_id FROM MaintenancePlan WHERE component_id=(SELECT component_id FROM Component WHERE component_no='EN3-004') AND status='pending' LIMIT 1), '2026-06-10 08:00:00', CONCAT('Started maintenance plan for component EN3-004; maintenance_id: ', (SELECT maintenance_id FROM MaintenanceRecord WHERE component_id=(SELECT component_id FROM Component WHERE component_no='EN3-004') AND result='pending' LIMIT 1), '; type: scheduled_inspection')),
(7, 'maintenance_plan_started', 'MaintenancePlan', (SELECT plan_id FROM MaintenancePlan WHERE component_id=(SELECT component_id FROM Component WHERE component_no='NAV-007') AND status='pending' LIMIT 1), '2026-06-11 08:00:00', CONCAT('Started maintenance plan for component NAV-007; maintenance_id: ', (SELECT maintenance_id FROM MaintenanceRecord WHERE component_id=(SELECT component_id FROM Component WHERE component_no='NAV-007') AND result='pending' LIMIT 1), '; type: preventive_maintenance')),
(3, 'maintenance_plan_started', 'MaintenancePlan', (SELECT plan_id FROM MaintenancePlan WHERE component_id=(SELECT component_id FROM Component WHERE component_no='HYD-006') AND status='pending' LIMIT 1), '2026-06-12 08:00:00', CONCAT('Started maintenance plan for component HYD-006; maintenance_id: ', (SELECT maintenance_id FROM MaintenanceRecord WHERE component_id=(SELECT component_id FROM Component WHERE component_no='HYD-006') AND result='pending' LIMIT 1), '; type: scheduled_inspection')),
(7, 'maintenance_plan_started', 'MaintenancePlan', (SELECT plan_id FROM MaintenancePlan WHERE component_id=(SELECT component_id FROM Component WHERE component_no='LD3-003') AND status='pending' LIMIT 1), '2026-06-14 08:00:00', CONCAT('Started maintenance plan for component LD3-003; maintenance_id: ', (SELECT maintenance_id FROM MaintenanceRecord WHERE component_id=(SELECT component_id FROM Component WHERE component_no='LD3-003') AND result='pending' LIMIT 1), '; type: preventive_maintenance'));


-- =====================================================
-- 十万级业务规模扩展数据
-- 说明：本段保留上方教学演示数据，并新增一套独立编号的数据集。
-- 编号前缀：
--   AC-Sxxxx      扩展飞机
--   CMP-C-xxxx-*  当前已安装部件
--   CMP-H-xxxx-*  已更换的历史部件
--   CMP-S-xxxxx   备件库存
--   SIM-Fxxxxxx   扩展飞行任务
--
-- 执行顺序仍为：01_create_tables.sql -> 02_seed_data.sql -> 03_triggers.sql。
-- 本段使用临时辅助表批量构造数据，脚本结束前会删除，不会在数据库中留下辅助表。
-- =====================================================

-- 扩展型号的寿命和维修周期采用较大的教学模拟值，避免 55 次常规飞行
-- 在没有维护事件的情况下就触及原演示型号的极小阈值。
INSERT INTO ComponentModel (
    model_code, category, design_life_hours, maintenance_cycle_hours, applicable_aircraft_model
) VALUES
('ENG-A320-S', 'engine', 20000, 2000, 'A320'),
('ENG-B737-S', 'engine', 20000, 2000, 'B737'),
('ENG-A330-S', 'engine', 24000, 2400, 'A330'),
('LDG-A320-S', 'landing_gear', 25000, 2500, 'A320'),
('LDG-B737-S', 'landing_gear', 25000, 2500, 'B737'),
('LDG-A330-S', 'landing_gear', 28000, 2800, 'A330'),
('NAV-UNIV-S', 'navigation', 30000, 3000, NULL),
('AVI-A320-S', 'avionics', 22000, 2200, 'A320'),
('AVI-B737-S', 'avionics', 22000, 2200, 'B737'),
('AVI-A330-S', 'avionics', 24000, 2400, 'A330'),
('HYD-UNIV-S', 'hydraulic', 20000, 2000, NULL),
('FUEL-UNIV-S', 'fuel', 20000, 2000, NULL),
('ECS-UNIV-S', 'air_conditioning', 18000, 1800, NULL),
('BRK-A320-S', 'brake', 15000, 1500, 'A320'),
('BRK-B737-S', 'brake', 15000, 1500, 'B737'),
('BRK-A330-S', 'brake', 16000, 1600, 'A330'),
('BAT-UNIV-S', 'battery', 5000, 1000, NULL);

CREATE TEMPORARY TABLE tmp_scale_numbers (
    n INT NOT NULL PRIMARY KEY
) ENGINE=Memory;

-- 0 到 99,999 的连续序号；后续每张扩展表按不同范围引用这一序列。
INSERT INTO tmp_scale_numbers (n)
SELECT
    d0.n + 10 * d1.n + 100 * d2.n + 1000 * d3.n + 10000 * d4.n AS n
FROM
    (SELECT 0 AS n UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
     UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) d0
CROSS JOIN
    (SELECT 0 AS n UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
     UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) d1
CROSS JOIN
    (SELECT 0 AS n UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
     UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) d2
CROSS JOIN
    (SELECT 0 AS n UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
     UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) d3
CROSS JOIN
    (SELECT 0 AS n UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
     UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) d4;

CREATE TEMPORARY TABLE tmp_scale_position_map (
    position_index TINYINT NOT NULL PRIMARY KEY,
    position_code VARCHAR(100) NOT NULL,
    component_tag VARCHAR(10) NOT NULL
) ENGINE=Memory;

INSERT INTO tmp_scale_position_map (position_index, position_code, component_tag) VALUES
(0, 'left engine position', 'ENG'),
(1, 'landing gear bay', 'LDG'),
(2, 'avionics bay', 'AVI'),
(3, 'navigation bay', 'NAV'),
(4, 'hydraulic system bay', 'HYD'),
(5, 'fuel control bay', 'FUEL'),
(6, 'air conditioning bay', 'ECS'),
(7, 'brake assembly', 'BRK'),
(8, 'battery bay', 'BAT');

CREATE TEMPORARY TABLE tmp_scale_model_map (
    model_index TINYINT NOT NULL PRIMARY KEY,
    model_code VARCHAR(50) NOT NULL
) ENGINE=Memory;

INSERT INTO tmp_scale_model_map (model_index, model_code) VALUES
(0, 'ENG-A320-S'), (1, 'ENG-B737-S'), (2, 'ENG-A330-S'),
(3, 'LDG-A320-S'), (4, 'LDG-B737-S'), (5, 'LDG-A330-S'),
(6, 'NAV-UNIV-S'),
(7, 'AVI-A320-S'), (8, 'AVI-B737-S'), (9, 'AVI-A330-S'),
(10, 'HYD-UNIV-S'), (11, 'FUEL-UNIV-S'), (12, 'ECS-UNIV-S'),
(13, 'BRK-A320-S'), (14, 'BRK-B737-S'), (15, 'BRK-A330-S'),
(16, 'BAT-UNIV-S');

-- 1,000 架在役飞机：A320、B737、A330 的比例为 45% / 40% / 15%。
INSERT INTO Aircraft (aircraft_no, aircraft_model, service_status, start_date, created_at)
SELECT
    CONCAT('AC-S', LPAD(sn.n + 1, 4, '0')),
    CASE
        WHEN MOD(sn.n, 20) < 9 THEN 'A320'
        WHEN MOD(sn.n, 20) < 17 THEN 'B737'
        ELSE 'A330'
    END,
    'active',
    DATE_ADD('2018-01-01', INTERVAL MOD(sn.n * 13, 2000) DAY),
    DATE_ADD('2023-01-01 08:00:00', INTERVAL MOD(sn.n * 7, 300) DAY)
FROM tmp_scale_numbers sn
WHERE sn.n < 1000;

-- 每架扩展飞机均建立 9 个标准安装位，共 9,000 个安装位。
INSERT INTO AircraftInstallPosition (
    aircraft_id, position_code, position_name, allowed_category, is_active, created_at
)
SELECT
    a.aircraft_id,
    p.position_code,
    CASE p.position_code
        WHEN 'left engine position' THEN '左侧发动机'
        WHEN 'landing gear bay' THEN '主起落架舱'
        WHEN 'avionics bay' THEN '航电设备舱'
        WHEN 'navigation bay' THEN '导航设备舱'
        WHEN 'hydraulic system bay' THEN '液压系统舱'
        WHEN 'fuel control bay' THEN '燃油控制舱'
        WHEN 'air conditioning bay' THEN '空调系统舱'
        WHEN 'brake assembly' THEN '刹车组件位'
        WHEN 'battery bay' THEN '机载电源舱'
    END,
    CASE p.position_code
        WHEN 'left engine position' THEN 'engine'
        WHEN 'landing gear bay' THEN 'landing_gear'
        WHEN 'avionics bay' THEN 'avionics'
        WHEN 'navigation bay' THEN 'navigation'
        WHEN 'hydraulic system bay' THEN 'hydraulic'
        WHEN 'fuel control bay' THEN 'fuel'
        WHEN 'air conditioning bay' THEN 'air_conditioning'
        WHEN 'brake assembly' THEN 'brake'
        WHEN 'battery bay' THEN 'battery'
    END,
    TRUE,
    DATE_ADD('2023-01-01 08:00:00', INTERVAL MOD(sn.n * 7, 300) DAY)
FROM tmp_scale_numbers sn
JOIN Aircraft a
  ON a.aircraft_no = CONCAT('AC-S', LPAD(sn.n + 1, 4, '0'))
CROSS JOIN tmp_scale_position_map p
WHERE sn.n < 1000;

-- 9,000 个当前在役部件：每个激活安装位恰好对应一个当前部件。
INSERT INTO Component (
    component_no, model_id, batch_no, production_date, stock_in_time,
    status, total_flight_hours, is_retired
)
SELECT
    CONCAT('CMP-C-', LPAD(sn.n + 1, 4, '0'), '-', pm.component_tag),
    cm.model_id,
    CONCAT('B-C-', DATE_FORMAT(DATE_ADD('2022-01-01', INTERVAL MOD(sn.n * 17 + pm.position_index, 730) DAY), '%Y%m')),
    DATE_ADD('2022-01-01', INTERVAL MOD(sn.n * 17 + pm.position_index, 730) DAY),
    DATE_ADD('2024-01-01 08:00:00', INTERVAL MOD(sn.n * 11 + pm.position_index, 300) DAY),
    'installed',
    0,
    FALSE
FROM tmp_scale_numbers sn
JOIN Aircraft a
  ON a.aircraft_no = CONCAT('AC-S', LPAD(sn.n + 1, 4, '0'))
CROSS JOIN tmp_scale_position_map pm
JOIN ComponentModel cm
  ON cm.model_code = CASE pm.position_code
      WHEN 'left engine position' THEN CONCAT('ENG-', a.aircraft_model, '-S')
      WHEN 'landing gear bay' THEN CONCAT('LDG-', a.aircraft_model, '-S')
      WHEN 'avionics bay' THEN CONCAT('AVI-', a.aircraft_model, '-S')
      WHEN 'navigation bay' THEN 'NAV-UNIV-S'
      WHEN 'hydraulic system bay' THEN 'HYD-UNIV-S'
      WHEN 'fuel control bay' THEN 'FUEL-UNIV-S'
      WHEN 'air conditioning bay' THEN 'ECS-UNIV-S'
      WHEN 'brake assembly' THEN CONCAT('BRK-', a.aircraft_model, '-S')
      WHEN 'battery bay' THEN 'BAT-UNIV-S'
  END
WHERE sn.n < 1000;

-- 5,000 个可追溯的历史部件：1,000 个已退役、1,000 个正在维修、3,000 个维修后可用。
INSERT INTO Component (
    component_no, model_id, batch_no, production_date, stock_in_time,
    status, total_flight_hours, is_retired
)
SELECT
    CONCAT('CMP-H-', LPAD(FLOOR(sn.n / 9) + 1, 4, '0'), '-', pm.component_tag),
    cm.model_id,
    CONCAT('B-H-', DATE_FORMAT(DATE_ADD('2020-01-01', INTERVAL MOD(sn.n * 19, 900) DAY), '%Y%m')),
    DATE_ADD('2020-01-01', INTERVAL MOD(sn.n * 19, 900) DAY),
    DATE_ADD('2023-01-01 08:00:00', INTERVAL MOD(sn.n * 5, 300) DAY),
    CASE
        WHEN sn.n < 1000 THEN 'retired'
        WHEN sn.n < 2000 THEN 'under_maintenance'
        ELSE 'available'
    END,
    CASE
        WHEN sn.n < 1000 THEN 4500 + MOD(sn.n, 1200)
        ELSE 800 + MOD(sn.n, 900)
    END,
    CASE WHEN sn.n < 1000 THEN TRUE ELSE FALSE END
FROM tmp_scale_numbers sn
JOIN Aircraft a
  ON a.aircraft_no = CONCAT('AC-S', LPAD(FLOOR(sn.n / 9) + 1, 4, '0'))
JOIN tmp_scale_position_map pm
  ON pm.position_index = MOD(sn.n, 9)
JOIN ComponentModel cm
  ON cm.model_code = CASE pm.position_code
      WHEN 'left engine position' THEN CONCAT('ENG-', a.aircraft_model, '-S')
      WHEN 'landing gear bay' THEN CONCAT('LDG-', a.aircraft_model, '-S')
      WHEN 'avionics bay' THEN CONCAT('AVI-', a.aircraft_model, '-S')
      WHEN 'navigation bay' THEN 'NAV-UNIV-S'
      WHEN 'hydraulic system bay' THEN 'HYD-UNIV-S'
      WHEN 'fuel control bay' THEN 'FUEL-UNIV-S'
      WHEN 'air conditioning bay' THEN 'ECS-UNIV-S'
      WHEN 'brake assembly' THEN CONCAT('BRK-', a.aircraft_model, '-S')
      WHEN 'battery bay' THEN 'BAT-UNIV-S'
  END
WHERE sn.n < 5000;

-- 2,000 个备件库存：1,000 个已检验可用，1,000 个待装机库存。
INSERT INTO Component (
    component_no, model_id, batch_no, production_date, stock_in_time,
    status, total_flight_hours, is_retired
)
SELECT
    CONCAT('CMP-S-', LPAD(sn.n + 1, 5, '0')),
    cm.model_id,
    CONCAT('B-S-', DATE_FORMAT(DATE_ADD('2022-01-01', INTERVAL MOD(sn.n * 23, 700) DAY), '%Y%m')),
    DATE_ADD('2022-01-01', INTERVAL MOD(sn.n * 23, 700) DAY),
    DATE_ADD('2024-01-01 08:00:00', INTERVAL MOD(sn.n * 3, 300) DAY),
    CASE WHEN sn.n < 1000 THEN 'available' ELSE 'in_stock' END,
    0,
    FALSE
FROM tmp_scale_numbers sn
JOIN tmp_scale_model_map sm
  ON sm.model_index = MOD(sn.n, 17)
JOIN ComponentModel cm
  ON cm.model_code = sm.model_code
WHERE sn.n < 2000;

-- 5,000 条已关闭安装记录：历史部件在 2024 年装机并完成计划性更换。
INSERT INTO InstallationRecord (
    component_id, aircraft_id, position_id, install_position, install_time, uninstall_time,
    install_reason, uninstall_reason, operator_id, uninstall_operator_id
)
SELECT
    c.component_id,
    a.aircraft_id,
    p.position_id,
    pm.position_code,
    DATE_ADD('2024-01-01 08:00:00', INTERVAL MOD(sn.n * 3, 180) DAY),
    DATE_ADD('2024-01-01 08:00:00', INTERVAL (120 + MOD(sn.n * 3, 180)) DAY),
    'historical fleet configuration',
    CASE
        WHEN sn.n < 1000 THEN 'removed after defect assessment'
        WHEN sn.n < 2000 THEN 'removed for workshop maintenance'
        ELSE 'scheduled replacement during fleet rotation'
    END,
    CASE MOD(sn.n, 3) WHEN 0 THEN 1 WHEN 1 THEN 5 ELSE 9 END,
    CASE MOD(sn.n + 1, 3) WHEN 0 THEN 1 WHEN 1 THEN 5 ELSE 9 END
FROM tmp_scale_numbers sn
JOIN Aircraft a
  ON a.aircraft_no = CONCAT('AC-S', LPAD(FLOOR(sn.n / 9) + 1, 4, '0'))
JOIN tmp_scale_position_map pm
  ON pm.position_index = MOD(sn.n, 9)
JOIN AircraftInstallPosition p
  ON p.aircraft_id = a.aircraft_id
 AND p.position_code = pm.position_code
JOIN Component c
  ON c.component_no = CONCAT('CMP-H-', LPAD(FLOOR(sn.n / 9) + 1, 4, '0'), '-', pm.component_tag)
WHERE sn.n < 5000;

-- 9,000 条当前有效安装记录：每架新飞机在首个飞行周期前配置完整。
INSERT INTO InstallationRecord (
    component_id, aircraft_id, position_id, install_position, install_time,
    install_reason, operator_id
)
SELECT
    c.component_id,
    a.aircraft_id,
    p.position_id,
    pm.position_code,
    DATE_ADD('2025-01-01 08:00:00', INTERVAL MOD(sn.n * 7 + pm.position_index, 20) DAY),
    'scale dataset baseline configuration',
    CASE MOD(sn.n, 3) WHEN 0 THEN 1 WHEN 1 THEN 5 ELSE 9 END
FROM tmp_scale_numbers sn
JOIN Aircraft a
  ON a.aircraft_no = CONCAT('AC-S', LPAD(sn.n + 1, 4, '0'))
CROSS JOIN tmp_scale_position_map pm
JOIN AircraftInstallPosition p
  ON p.aircraft_id = a.aircraft_id
 AND p.position_code = pm.position_code
JOIN Component c
  ON c.component_no = CONCAT('CMP-C-', LPAD(sn.n + 1, 4, '0'), '-', pm.component_tag)
WHERE sn.n < 1000;

-- 55,000 条飞行日志：每架扩展飞机 55 次无重叠的常规任务。
-- 所有飞行均发生在 2025 年，晚于当前部件安装时间，且低于扩展型号的维修周期。
INSERT INTO FlightLog (
    aircraft_id, mission_no, takeoff_time, landing_time,
    flight_hours, mission_type, recorded_by
)
SELECT
    a.aircraft_id,
    CONCAT('SIM-F', LPAD(sn.n + 1, 6, '0')),
    DATE_ADD(
        '2025-02-01 06:00:00',
        INTERVAL (MOD(sn.n, 55) * 3 + MOD(FLOOR(sn.n / 55), 7)) DAY
    ),
    DATE_ADD(
        DATE_ADD(
            '2025-02-01 06:00:00',
            INTERVAL (MOD(sn.n, 55) * 3 + MOD(FLOOR(sn.n / 55), 7)) DAY
        ),
        INTERVAL (90 + MOD(sn.n, 5) * 15) MINUTE
    ),
    ROUND((90 + MOD(sn.n, 5) * 15) / 60, 2),
    CASE MOD(sn.n, 4)
        WHEN 0 THEN 'domestic rotation'
        WHEN 1 THEN 'regional rotation'
        WHEN 2 THEN 'cargo rotation'
        ELSE 'training rotation'
    END,
    CASE MOD(sn.n, 2) WHEN 0 THEN 4 ELSE 10 END
FROM tmp_scale_numbers sn
JOIN Aircraft a
  ON a.aircraft_no = CONCAT('AC-S', LPAD(FLOOR(sn.n / 55) + 1, 4, '0'))
WHERE sn.n < 55000;

-- 3,000 条已通过维修记录：历史部件完成车间检修后转为可用。
INSERT INTO MaintenanceRecord (
    component_id, maintenance_type, start_time, end_time, result, description, technician_id
)
SELECT
    c.component_id,
    'scheduled overhaul',
    DATE_ADD('2024-12-01 08:00:00', INTERVAL MOD(sn.n, 30) DAY),
    DATE_ADD(DATE_ADD('2024-12-01 08:00:00', INTERVAL MOD(sn.n, 30) DAY), INTERVAL 8 HOUR),
    'passed',
    'Historical component restored to available stock after scheduled overhaul.',
    CASE MOD(sn.n, 3) WHEN 0 THEN 2 WHEN 1 THEN 6 ELSE 8 END
FROM tmp_scale_numbers sn
JOIN Component c
  ON c.component_no = CONCAT('CMP-H-', LPAD(FLOOR(sn.n / 9) + 1, 4, '0'), '-',
        CASE MOD(sn.n, 9)
            WHEN 0 THEN 'ENG' WHEN 1 THEN 'LDG' WHEN 2 THEN 'AVI'
            WHEN 3 THEN 'NAV' WHEN 4 THEN 'HYD' WHEN 5 THEN 'FUEL'
            WHEN 6 THEN 'ECS' WHEN 7 THEN 'BRK' ELSE 'BAT'
        END)
WHERE sn.n BETWEEN 2000 AND 4999;

-- 1,000 条报废维修记录：与对应退役部件及退役记录形成完整链条。
INSERT INTO MaintenanceRecord (
    component_id, maintenance_type, start_time, end_time, result, description, technician_id
)
SELECT
    c.component_id,
    'defect assessment',
    DATE_ADD('2024-12-01 08:00:00', INTERVAL MOD(sn.n, 40) DAY),
    DATE_ADD(DATE_ADD('2024-12-01 08:00:00', INTERVAL MOD(sn.n, 40) DAY), INTERVAL 6 HOUR),
    'scrapped',
    'Irreparable defect confirmed during workshop assessment.',
    CASE MOD(sn.n, 3) WHEN 0 THEN 2 WHEN 1 THEN 6 ELSE 8 END
FROM tmp_scale_numbers sn
JOIN Component c
  ON c.component_no = CONCAT('CMP-H-', LPAD(FLOOR(sn.n / 9) + 1, 4, '0'), '-',
        CASE MOD(sn.n, 9)
            WHEN 0 THEN 'ENG' WHEN 1 THEN 'LDG' WHEN 2 THEN 'AVI'
            WHEN 3 THEN 'NAV' WHEN 4 THEN 'HYD' WHEN 5 THEN 'FUEL'
            WHEN 6 THEN 'ECS' WHEN 7 THEN 'BRK' ELSE 'BAT'
        END)
WHERE sn.n < 1000;

-- 1,000 条进行中维修记录：对应当前 under_maintenance 状态的历史部件。
INSERT INTO MaintenanceRecord (
    component_id, maintenance_type, start_time, end_time, result, description, technician_id
)
SELECT
    c.component_id,
    'workshop repair',
    DATE_ADD('2025-01-15 08:00:00', INTERVAL MOD(sn.n, 60) DAY),
    NULL,
    'pending',
    'Component is currently undergoing workshop repair.',
    CASE MOD(sn.n, 3) WHEN 0 THEN 2 WHEN 1 THEN 6 ELSE 8 END
FROM tmp_scale_numbers sn
JOIN Component c
  ON c.component_no = CONCAT('CMP-H-', LPAD(FLOOR(sn.n / 9) + 1, 4, '0'), '-',
        CASE MOD(sn.n, 9)
            WHEN 0 THEN 'ENG' WHEN 1 THEN 'LDG' WHEN 2 THEN 'AVI'
            WHEN 3 THEN 'NAV' WHEN 4 THEN 'HYD' WHEN 5 THEN 'FUEL'
            WHEN 6 THEN 'ECS' WHEN 7 THEN 'BRK' ELSE 'BAT'
        END)
WHERE sn.n BETWEEN 1000 AND 1999;

-- 1,000 条入库检验记录：已检验的备件状态为 available。
INSERT INTO MaintenanceRecord (
    component_id, maintenance_type, start_time, end_time, result, description, technician_id
)
SELECT
    c.component_id,
    'incoming inspection',
    DATE_ADD('2025-01-10 08:00:00', INTERVAL MOD(sn.n, 90) DAY),
    DATE_ADD(DATE_ADD('2025-01-10 08:00:00', INTERVAL MOD(sn.n, 90) DAY), INTERVAL 4 HOUR),
    'passed',
    'Incoming stock acceptance inspection completed successfully.',
    CASE MOD(sn.n, 3) WHEN 0 THEN 2 WHEN 1 THEN 6 ELSE 8 END
FROM tmp_scale_numbers sn
JOIN Component c
  ON c.component_no = CONCAT('CMP-S-', LPAD(sn.n + 1, 5, '0'))
WHERE sn.n < 1000;

-- 500 条已完成维修计划：关联到已通过的历史维修记录。
INSERT INTO MaintenancePlan (
    component_id, planned_type, planned_time, planned_reason, status,
    created_by, created_at, completed_at, related_maintenance_id
)
SELECT
    c.component_id,
    'post_removal_inspection',
    DATE_SUB(mr.start_time, INTERVAL 3 DAY),
    'Planned inspection after removal from fleet rotation.',
    'completed',
    CASE MOD(sn.n, 2) WHEN 0 THEN 3 ELSE 7 END,
    DATE_SUB(mr.start_time, INTERVAL 3 DAY),
    mr.end_time,
    mr.maintenance_id
FROM tmp_scale_numbers sn
JOIN Component c
  ON c.component_no = CONCAT('CMP-H-', LPAD(FLOOR(sn.n / 9) + 1, 4, '0'), '-',
        CASE MOD(sn.n, 9)
            WHEN 0 THEN 'ENG' WHEN 1 THEN 'LDG' WHEN 2 THEN 'AVI'
            WHEN 3 THEN 'NAV' WHEN 4 THEN 'HYD' WHEN 5 THEN 'FUEL'
            WHEN 6 THEN 'ECS' WHEN 7 THEN 'BRK' ELSE 'BAT'
        END)
JOIN MaintenanceRecord mr
  ON mr.component_id = c.component_id
 AND mr.result = 'passed'
 AND mr.maintenance_type = 'scheduled overhaul'
WHERE sn.n BETWEEN 2000 AND 2499;

-- 500 条已开始但尚未完成的维修计划：关联 pending 的维修记录。
INSERT INTO MaintenancePlan (
    component_id, planned_type, planned_time, planned_reason, status,
    created_by, created_at, completed_at, related_maintenance_id
)
SELECT
    c.component_id,
    'corrective maintenance',
    DATE_SUB(mr.start_time, INTERVAL 7 DAY),
    'Corrective maintenance plan started after workshop diagnosis.',
    'pending',
    CASE MOD(sn.n, 2) WHEN 0 THEN 3 ELSE 7 END,
    DATE_SUB(mr.start_time, INTERVAL 7 DAY),
    NULL,
    mr.maintenance_id
FROM tmp_scale_numbers sn
JOIN Component c
  ON c.component_no = CONCAT('CMP-H-', LPAD(FLOOR(sn.n / 9) + 1, 4, '0'), '-',
        CASE MOD(sn.n, 9)
            WHEN 0 THEN 'ENG' WHEN 1 THEN 'LDG' WHEN 2 THEN 'AVI'
            WHEN 3 THEN 'NAV' WHEN 4 THEN 'HYD' WHEN 5 THEN 'FUEL'
            WHEN 6 THEN 'ECS' WHEN 7 THEN 'BRK' ELSE 'BAT'
        END)
JOIN MaintenanceRecord mr
  ON mr.component_id = c.component_id
 AND mr.result = 'pending'
WHERE sn.n BETWEEN 1000 AND 1499;

-- 500 条尚未开始的周期检查计划：绑定到仍在飞行的当前部件。
INSERT INTO MaintenancePlan (
    component_id, planned_type, planned_time, planned_reason, status,
    created_by, created_at, completed_at, related_maintenance_id
)
SELECT
    c.component_id,
    'scheduled inspection',
    DATE_ADD('2025-12-01 09:00:00', INTERVAL MOD(sn.n, 180) DAY),
    'Next scheduled inspection for active fleet scale dataset.',
    'pending',
    CASE MOD(sn.n, 2) WHEN 0 THEN 3 ELSE 7 END,
    DATE_SUB(DATE_ADD('2025-12-01 09:00:00', INTERVAL MOD(sn.n, 180) DAY), INTERVAL 30 DAY),
    NULL,
    NULL
FROM tmp_scale_numbers sn
JOIN Component c
  ON c.component_no = CONCAT('CMP-C-', LPAD(FLOOR(sn.n / 9) + 1, 4, '0'), '-',
        CASE MOD(sn.n, 9)
            WHEN 0 THEN 'ENG' WHEN 1 THEN 'LDG' WHEN 2 THEN 'AVI'
            WHEN 3 THEN 'NAV' WHEN 4 THEN 'HYD' WHEN 5 THEN 'FUEL'
            WHEN 6 THEN 'ECS' WHEN 7 THEN 'BRK' ELSE 'BAT'
        END)
WHERE sn.n < 500;

-- 1,000 条退役记录：与 scrapped 维修结果及 retired 状态一一对应。
INSERT INTO RetirementRecord (
    component_id, retirement_time, retirement_reason, approved_by, remark
)
SELECT
    c.component_id,
    DATE_ADD('2025-01-10 10:00:00', INTERVAL MOD(sn.n, 30) DAY),
    CASE MOD(sn.n, 3)
        WHEN 0 THEN 'irreparable damage'
        WHEN 1 THEN 'failed defect assessment'
        ELSE 'economic retirement after workshop evaluation'
    END,
    CASE MOD(sn.n, 2) WHEN 0 THEN 3 ELSE 7 END,
    'Retired from the scale dataset after a completed scrapped maintenance assessment.'
FROM tmp_scale_numbers sn
JOIN Component c
  ON c.component_no = CONCAT('CMP-H-', LPAD(FLOOR(sn.n / 9) + 1, 4, '0'), '-',
        CASE MOD(sn.n, 9)
            WHEN 0 THEN 'ENG' WHEN 1 THEN 'LDG' WHEN 2 THEN 'AVI'
            WHEN 3 THEN 'NAV' WHEN 4 THEN 'HYD' WHEN 5 THEN 'FUEL'
            WHEN 6 THEN 'ECS' WHEN 7 THEN 'BRK' ELSE 'BAT'
        END)
WHERE sn.n < 1000;

-- 1,500 条关联审计日志：覆盖飞机建档、配置导入和飞行归档三类真实动作。
INSERT INTO AuditLog (
    operator_id, operation_type, target_table, target_id, operation_time, operation_detail
)
SELECT
    4,
    'aircraft_registration',
    'Aircraft',
    a.aircraft_id,
    DATE_ADD('2024-01-01 08:00:00', INTERVAL MOD(sn.n, 300) DAY),
    CONCAT('Registered scale dataset aircraft ', a.aircraft_no, '.')
FROM tmp_scale_numbers sn
JOIN Aircraft a
  ON a.aircraft_no = CONCAT('AC-S', LPAD(sn.n + 1, 4, '0'))
WHERE sn.n < 500;

INSERT INTO AuditLog (
    operator_id, operation_type, target_table, target_id, operation_time, operation_detail
)
SELECT
    CASE MOD(sn.n, 2) WHEN 0 THEN 1 ELSE 5 END,
    'baseline_installation',
    'InstallationRecord',
    ir.installation_id,
    ir.install_time,
    CONCAT('Scale dataset baseline configuration imported for ', c.component_no, ' on ', a.aircraft_no, '.')
FROM tmp_scale_numbers sn
JOIN Aircraft a
  ON a.aircraft_no = CONCAT('AC-S', LPAD(FLOOR(sn.n / 9) + 1, 4, '0'))
JOIN tmp_scale_position_map pm
  ON pm.position_index = MOD(sn.n, 9)
JOIN Component c
  ON c.component_no = CONCAT('CMP-C-', LPAD(FLOOR(sn.n / 9) + 1, 4, '0'), '-', pm.component_tag)
JOIN InstallationRecord ir
  ON ir.component_id = c.component_id
 AND ir.aircraft_id = a.aircraft_id
 AND ir.uninstall_time IS NULL
WHERE sn.n < 500;

INSERT INTO AuditLog (
    operator_id, operation_type, target_table, target_id, operation_time, operation_detail
)
SELECT
    fl.recorded_by,
    'flight_recorded',
    'FlightLog',
    fl.flight_id,
    fl.landing_time,
    CONCAT('Archived completed flight ', fl.mission_no, ' for scale dataset.')
FROM tmp_scale_numbers sn
JOIN FlightLog fl
  ON fl.mission_no = CONCAT('SIM-F', LPAD(sn.n + 1, 6, '0'))
WHERE sn.n < 500;

DROP TEMPORARY TABLE tmp_scale_model_map;
DROP TEMPORARY TABLE tmp_scale_position_map;
DROP TEMPORARY TABLE tmp_scale_numbers;

-- 扩展部分的预期新增行数：105,017 行。
-- 全库总行数会在原有演示数据基础上超过 105,000 行。
SELECT
    (SELECT COUNT(*) FROM Aircraft WHERE aircraft_no LIKE 'AC-S%') AS new_aircraft,
    (SELECT COUNT(*) FROM AircraftInstallPosition p JOIN Aircraft a ON a.aircraft_id = p.aircraft_id WHERE a.aircraft_no LIKE 'AC-S%') AS new_positions,
    (SELECT COUNT(*) FROM Component WHERE component_no LIKE 'CMP-C-%') AS new_current_components,
    (SELECT COUNT(*) FROM Component WHERE component_no LIKE 'CMP-H-%') AS new_historical_components,
    (SELECT COUNT(*) FROM Component WHERE component_no LIKE 'CMP-S-%') AS new_spare_components,
    (SELECT COUNT(*) FROM InstallationRecord ir JOIN Aircraft a ON a.aircraft_id = ir.aircraft_id WHERE a.aircraft_no LIKE 'AC-S%') AS new_installation_records,
    (SELECT COUNT(*) FROM FlightLog WHERE mission_no LIKE 'SIM-F%') AS new_flight_logs,
    (SELECT COUNT(*) FROM MaintenanceRecord mr JOIN Component c ON c.component_id = mr.component_id WHERE c.component_no LIKE 'CMP-%') AS new_maintenance_records,
    (SELECT COUNT(*) FROM MaintenancePlan mp JOIN Component c ON c.component_id = mp.component_id WHERE c.component_no LIKE 'CMP-%') AS new_maintenance_plans,
    (SELECT COUNT(*) FROM RetirementRecord rr JOIN Component c ON c.component_id = rr.component_id WHERE c.component_no LIKE 'CMP-H-%') AS new_retirement_records,
    (SELECT COUNT(*) FROM AuditLog WHERE operation_detail LIKE '%scale dataset%') AS new_audit_logs;


-- 扩展数据一致性核验：下列 *_errors 字段都应为 0。
SELECT
    (SELECT COUNT(*)
     FROM Component c
     LEFT JOIN InstallationRecord ir
       ON ir.component_id = c.component_id AND ir.uninstall_time IS NULL
     WHERE c.component_no LIKE 'CMP-C-%' AND ir.installation_id IS NULL) AS current_components_without_active_install_errors,
    (SELECT COUNT(*)
     FROM AircraftInstallPosition p
     JOIN Aircraft a ON a.aircraft_id = p.aircraft_id
     LEFT JOIN InstallationRecord ir
       ON ir.position_id = p.position_id AND ir.uninstall_time IS NULL
     WHERE a.aircraft_no LIKE 'AC-S%' AND p.is_active = TRUE AND ir.installation_id IS NULL) AS active_positions_without_component_errors,
    (SELECT COUNT(*)
     FROM InstallationRecord ir
     JOIN Aircraft a ON a.aircraft_id = ir.aircraft_id
     WHERE a.aircraft_no LIKE 'AC-S%'
       AND ir.uninstall_time IS NOT NULL
       AND ir.uninstall_time < ir.install_time) AS installation_time_order_errors,
    (SELECT COUNT(*)
     FROM FlightLog fl
     WHERE fl.mission_no LIKE 'SIM-F%'
       AND (fl.landing_time <= fl.takeoff_time OR fl.flight_hours <= 0)) AS flight_time_or_duration_errors,
    (SELECT COUNT(*)
     FROM Component c
     LEFT JOIN MaintenanceRecord mr
       ON mr.component_id = c.component_id AND mr.result = 'pending'
     WHERE c.component_no LIKE 'CMP-H-%'
       AND c.status = 'under_maintenance'
       AND mr.maintenance_id IS NULL) AS maintenance_status_link_errors,
    (SELECT COUNT(*)
     FROM Component c
     LEFT JOIN RetirementRecord rr ON rr.component_id = c.component_id
     WHERE c.component_no LIKE 'CMP-H-%'
       AND c.status = 'retired'
       AND rr.retirement_id IS NULL) AS retirement_status_link_errors;

-- 初始化后计数与一致性快速检查。
SELECT 'Operator' AS table_name, COUNT(*) AS row_count FROM Operator
UNION ALL SELECT 'Aircraft', COUNT(*) FROM Aircraft
UNION ALL SELECT 'ComponentCategory', COUNT(*) FROM ComponentCategory
UNION ALL SELECT 'ComponentModel', COUNT(*) FROM ComponentModel
UNION ALL SELECT 'Component', COUNT(*) FROM Component
UNION ALL SELECT 'ComponentStatusTransitionRule', COUNT(*) FROM ComponentStatusTransitionRule
UNION ALL SELECT 'AircraftInstallPosition', COUNT(*) FROM AircraftInstallPosition
UNION ALL SELECT 'InstallationRecord', COUNT(*) FROM InstallationRecord
UNION ALL SELECT 'MaintenanceRecord', COUNT(*) FROM MaintenanceRecord
UNION ALL SELECT 'MaintenancePlan', COUNT(*) FROM MaintenancePlan
UNION ALL SELECT 'FlightLog', COUNT(*) FROM FlightLog
UNION ALL SELECT 'RetirementRecord', COUNT(*) FROM RetirementRecord
UNION ALL SELECT 'AuditLog', COUNT(*) FROM AuditLog;

SELECT status, COUNT(*) AS component_count FROM Component GROUP BY status ORDER BY status;
SELECT service_status, COUNT(*) AS aircraft_count FROM Aircraft GROUP BY service_status ORDER BY service_status;
SELECT status, COUNT(*) AS plan_count FROM MaintenancePlan GROUP BY status ORDER BY status;
SELECT
    CASE
        WHEN status = 'pending' AND related_maintenance_id IS NULL THEN 'pending_not_started'
        WHEN status = 'pending' AND related_maintenance_id IS NOT NULL THEN 'in_progress'
        ELSE status
    END AS plan_display_status,
    COUNT(*) AS plan_count
FROM MaintenancePlan
GROUP BY plan_display_status
ORDER BY plan_display_status;
SELECT result, COUNT(*) AS maintenance_count FROM MaintenanceRecord GROUP BY result ORDER BY result;
