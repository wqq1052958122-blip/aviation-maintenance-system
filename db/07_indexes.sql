-- =====================================================
-- 文件：07_indexes.sql
-- 作用：索引设计
-- 说明：用于提升生命周期追溯、当前有效安装、飞行统计、维修统计等查询效率
-- =====================================================
USE aviation_maintenance;

-- =====================================================
-- 索引：组件状态查询
-- 表名：Component
-- 索引字段：status, is_retired
-- 用途：加速按状态和退役标志筛选组件的查询
-- 典型查询：查找可安装组件、查找未退役组件等
-- =====================================================
CREATE INDEX idx_component_status ON Component(status, is_retired);

-- =====================================================
-- 索引：组件型号类别查询
-- 表名：ComponentModel
-- 索引字段：category
-- 用途：加速按组件类别筛选的查询
-- 典型查询：按类别统计组件、按类别过滤组件列表
-- =====================================================
CREATE INDEX idx_component_model_category ON ComponentModel(category);

-- =====================================================
-- 索引：飞机安装位置查询
-- 表名：AircraftInstallPosition
-- 索引字段：aircraft_id, allowed_category, is_active
-- 用途：加速按飞机、位置类别和激活状态查询安装位置
-- 典型查询：查找某飞机可用的特定类别安装位、验证位置有效性
-- =====================================================
CREATE INDEX idx_position_category ON AircraftInstallPosition(aircraft_id, allowed_category, is_active);

-- =====================================================
-- 索引：组件有效安装查询
-- 表名：InstallationRecord
-- 索引字段：component_id, uninstall_time
-- 用途：加速查询组件当前是否有效安装（uninstall_time IS NULL）
-- 典型查询：检查组件是否有有效安装记录、获取组件的当前安装
-- =====================================================
CREATE INDEX idx_install_component_active ON InstallationRecord(component_id, uninstall_time);

-- =====================================================
-- 索引：飞机位置有效安装查询
-- 表名：InstallationRecord
-- 索引字段：aircraft_id, position_id, uninstall_time
-- 用途：加速查询某飞机某位置当前是否已安装组件
-- 典型查询：检查飞机某位置是否已被占用、验证飞机配置完整性
-- =====================================================
CREATE INDEX idx_install_aircraft_position_active ON InstallationRecord(aircraft_id, position_id, uninstall_time);

-- =====================================================
-- 索引：组件唯一有效安装记录
-- 表名：InstallationRecord
-- 索引类型：唯一索引
-- 索引字段：active_component_id
-- 用途：确保同一组件最多只有一个有效安装记录
-- 说明：此索引需要配合触发器或应用逻辑，将active_component_id设置为
--      组件ID（仅当uninstall_time IS NULL时），否则为NULL
-- =====================================================
CREATE UNIQUE INDEX uq_install_active_component ON InstallationRecord(active_component_id);

-- =====================================================
-- 索引：位置唯一有效安装记录
-- 表名：InstallationRecord
-- 索引类型：唯一索引
-- 索引字段：active_aircraft_id, active_position_id
-- 用途：确保同一飞机同一位置最多只有一个有效安装
-- 说明：此索引需要配合触发器或应用逻辑，将active_aircraft_id和
--      active_position_id设置为有效值（仅当uninstall_time IS NULL时），否则为NULL
-- =====================================================
CREATE UNIQUE INDEX uq_install_active_position ON InstallationRecord(active_aircraft_id, active_position_id);

-- =====================================================
-- 索引：安装时间范围查询
-- 表名：InstallationRecord
-- 索引字段：install_time, uninstall_time
-- 用途：加速按时间段查询安装记录的效率
-- 典型查询：查找某时间点的有效安装、计算组件使用小时数
-- =====================================================
CREATE INDEX idx_install_time_range ON InstallationRecord(install_time, uninstall_time);

-- =====================================================
-- 索引：飞行日志按飞机和时间查询
-- 表名：FlightLog
-- 索引字段：aircraft_id, takeoff_time, landing_time
-- 用途：加速按飞机和时间范围查询飞行日志
-- 典型查询：计算组件飞行小时数（JOIN条件）、查询飞机飞行记录、
--          检查飞行时间重叠
-- =====================================================
CREATE INDEX idx_flight_aircraft_time ON FlightLog(aircraft_id, takeoff_time, landing_time);

-- =====================================================
-- 索引：维修记录按组件和时间查询
-- 表名：MaintenanceRecord
-- 索引字段：component_id, start_time, end_time
-- 用途：加速查询组件的维修历史和时间范围
-- 典型查询：获取组件最近一次通过维修的时间、计算维修间隔、
--          统计某时间段内的维修活动
-- =====================================================
CREATE INDEX idx_maintenance_component_time ON MaintenanceRecord(component_id, start_time, end_time);

-- =====================================================
-- 索引：维修计划按状态和时间查询
-- 表名：MaintenancePlan
-- 索引字段：status, planned_time
-- 用途：加速查询特定状态（如pending）的维修计划并按计划时间排序
-- 典型查询：v_pending_maintenance_plan视图、获取待执行计划列表
-- =====================================================
CREATE INDEX idx_plan_status_time ON MaintenancePlan(status, planned_time);

-- =====================================================
-- 索引：维修计划按组件和状态查询
-- 表名：MaintenancePlan
-- 索引字段：component_id, status
-- 用途：加速查询某组件的维修计划状态
-- 典型查询：检查组件是否已有待处理计划、获取组件所有计划
-- =====================================================
CREATE INDEX idx_plan_component_status ON MaintenancePlan(component_id, status);

-- =====================================================
-- 索引：维修计划关联维修记录唯一性
-- 表名：MaintenancePlan
-- 索引类型：唯一索引
-- 索引字段：related_maintenance_id
-- 用途：确保一个维修记录最多只能关联一个维修计划
-- 业务含义：一个维修记录不能同时被多个计划引用
-- =====================================================
CREATE UNIQUE INDEX uq_plan_related_maintenance ON MaintenancePlan(related_maintenance_id);

-- =====================================================
-- 索引：退役记录按组件和时间查询
-- 表名：RetirementRecord
-- 索引字段：component_id, retirement_time
-- 用途：加速查询组件的退役记录和时间线
-- 典型查询：获取组件的退役时间、按时间排序退役记录
-- =====================================================
CREATE INDEX idx_retirement_component_time ON RetirementRecord(component_id, retirement_time);

-- =====================================================
-- 索引：审计日志按时间和类型查询
-- 表名：AuditLog
-- 索引字段：operation_time, operation_type
-- 用途：加速审计日志的查询和报表生成
-- 典型查询：按时间范围查看审计日志、按操作类型统计活动
-- =====================================================
CREATE INDEX idx_audit_operation_time ON AuditLog(operation_time, operation_type);

-- =====================================================
-- 查询：显示Component表的所有索引
-- 用途：验证索引创建结果
-- =====================================================
SHOW INDEX FROM Component;

-- =====================================================
-- 查询：显示InstallationRecord表的所有索引
-- 用途：验证索引创建结果
-- =====================================================
SHOW INDEX FROM InstallationRecord;

-- =====================================================
-- 查询：显示FlightLog表的所有索引
-- 用途：验证索引创建结果
-- =====================================================
SHOW INDEX FROM FlightLog;

-- =====================================================
-- 查询：显示MaintenanceRecord表的所有索引
-- 用途：验证索引创建结果
-- =====================================================
SHOW INDEX FROM MaintenanceRecord;

-- =====================================================
-- 查询：显示MaintenancePlan表的所有索引
-- 用途：验证索引创建结果
-- =====================================================
SHOW INDEX FROM MaintenancePlan;

-- =====================================================
-- 查询：显示AuditLog表的所有索引
-- 用途：验证索引创建结果
-- =====================================================
SHOW INDEX FROM AuditLog;