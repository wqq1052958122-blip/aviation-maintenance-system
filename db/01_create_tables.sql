-- =====================================================
-- 项目1：航空部件生命周期与维修管理系统
-- 文件：01_create_tables.sql
-- 作用：建库 + 建 13 张核心表 + 基础约束
-- 数据库：MySQL 8.0
-- 增强点：统一字符集；InstallationRecord 增加拆卸责任人；保留历史时间区间
-- =====================================================

-- 删除已存在的数据库（如果存在），确保从头开始创建
DROP DATABASE IF EXISTS aviation_maintenance;
-- 创建数据库，使用utf8mb4字符集以支持完整的Unicode（包括emoji）
CREATE DATABASE aviation_maintenance
DEFAULT CHARACTER SET utf8mb4
DEFAULT COLLATE utf8mb4_0900_ai_ci;

-- 切换到新创建的数据库
USE aviation_maintenance;

-- =====================================================
-- 表1：操作人员表（Operator）
-- 功能描述：存储系统所有操作人员信息
-- 角色说明：installer（安装员）- 负责组件安装/卸载
--           technician（技术员）- 负责执行维修
--           approver（审批人）- 负责审批退役/维修完成
--           admin（管理员）- 系统管理
-- =====================================================
CREATE TABLE Operator (
    operator_id INT PRIMARY KEY AUTO_INCREMENT COMMENT '操作人员ID',
    operator_name VARCHAR(50) NOT NULL COMMENT '操作人员姓名',
    role VARCHAR(30) NOT NULL COMMENT '角色：installer/technician/approver/admin',
    phone VARCHAR(30) COMMENT '联系电话',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    CONSTRAINT chk_operator_role CHECK (role IN ('installer', 'technician', 'approver', 'admin'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='操作人员表';

-- =====================================================
-- 表2：飞机表（Aircraft）
-- 功能描述：存储所有飞机的基本信息和当前服役状态
-- 状态说明：active（服役中）、maintenance（维护中）、retired（已退役）
-- =====================================================
CREATE TABLE Aircraft (
    aircraft_id INT PRIMARY KEY AUTO_INCREMENT COMMENT '飞机ID',
    aircraft_no VARCHAR(50) NOT NULL UNIQUE COMMENT '飞机编号',
    aircraft_model VARCHAR(50) NOT NULL COMMENT '飞机型号',
    service_status VARCHAR(30) NOT NULL DEFAULT 'active' COMMENT '服役状态：active/maintenance/retired',
    start_date DATE COMMENT '启用日期',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    CONSTRAINT chk_aircraft_status CHECK (service_status IN ('active', 'maintenance', 'retired'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='飞机表';

-- =====================================================
-- 表3：部件类别字典表（ComponentCategory）
-- 功能描述：定义部件类别的字典数据
-- 用途：标准化部件分类，便于管理和统计
-- =====================================================
CREATE TABLE ComponentCategory (
    category_code VARCHAR(50) PRIMARY KEY COMMENT '部件类别编码',
    category_name VARCHAR(100) NOT NULL COMMENT '部件类别名称',
    description VARCHAR(255) COMMENT '类别说明'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='部件类别字典表';

-- =====================================================
-- 表4：部件型号表（ComponentModel）
-- 功能描述：定义部件的型号规格和技术参数
-- 关键字段：design_life_hours（设计寿命）、maintenance_cycle_hours（维修周期）
-- 业务意义：design_life_hours - 组件到达此小时数必须退役
--           maintenance_cycle_hours - 组件每飞行此小时数需进行定期维修
-- =====================================================
CREATE TABLE ComponentModel (
    model_id INT PRIMARY KEY AUTO_INCREMENT COMMENT '部件型号ID',
    model_code VARCHAR(50) NOT NULL UNIQUE COMMENT '部件型号编码',
    category VARCHAR(50) NOT NULL COMMENT '部件类别',
    design_life_hours INT NOT NULL COMMENT '设计寿命小时',
    maintenance_cycle_hours INT NOT NULL COMMENT '维修周期小时',
    applicable_aircraft_model VARCHAR(50) COMMENT '适用飞机型号',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    CONSTRAINT fk_component_model_category FOREIGN KEY (category) REFERENCES ComponentCategory(category_code),
    CONSTRAINT chk_design_life CHECK (design_life_hours > 0),
    CONSTRAINT chk_maintenance_cycle CHECK (maintenance_cycle_hours > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='部件型号表';

-- =====================================================
-- 表5：部件实例表（Component）
-- 功能描述：存储每个具体部件的实例信息
-- 状态说明：in_stock（在库）、installed（已安装）、removed（已拆卸）、
--           under_maintenance（维修中）、available（可用）、retired（已退役）
-- 关键设计：total_flight_hours 是历史兼容字段，实际飞行小时通过
--           FlightLog和InstallationRecord关联实时计算，保证数据准确性
-- =====================================================
CREATE TABLE Component (
    component_id INT PRIMARY KEY AUTO_INCREMENT COMMENT '部件ID',
    component_no VARCHAR(50) NOT NULL UNIQUE COMMENT '部件唯一编号',
    model_id INT NOT NULL COMMENT '所属部件型号ID',
    batch_no VARCHAR(50) COMMENT '批次号',
    production_date DATE COMMENT '生产日期',
    status VARCHAR(30) NOT NULL DEFAULT 'in_stock' COMMENT '当前状态',
    total_flight_hours DECIMAL(10,2) NOT NULL DEFAULT 0 COMMENT '历史兼容字段；可保存迁移前累计小时，系统内飞行统计仍以 FlightLog 与 InstallationRecord 推导为准',
    is_retired BOOLEAN NOT NULL DEFAULT FALSE COMMENT '是否退役',
    stock_in_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '真实业务入库时间',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT '数据库记录创建时间',
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    CONSTRAINT fk_component_model FOREIGN KEY (model_id) REFERENCES ComponentModel(model_id),
    CONSTRAINT chk_component_status CHECK (status IN ('in_stock','installed','removed','under_maintenance','available','retired')),
    CONSTRAINT chk_total_flight_hours CHECK (total_flight_hours >= 0),
    -- 确保status和is_retired的一致性：status为retired时is_retired必须为TRUE，反之亦然
    CONSTRAINT chk_retired_status_consistency CHECK ((status = 'retired' AND is_retired = TRUE) OR (status <> 'retired' AND is_retired = FALSE))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='部件实例表';

-- =====================================================
-- 表6：部件状态合法流转规则表（ComponentStatusTransitionRule）
-- 功能描述：定义部件状态之间允许的转换规则
-- 用途：触发器trg_before_update_component_status使用此表验证状态变更合法性
-- 业务意义：防止非法状态跳转，保证业务流程合规
-- =====================================================
CREATE TABLE ComponentStatusTransitionRule (
    from_status VARCHAR(30) NOT NULL COMMENT '原状态',
    to_status VARCHAR(30) NOT NULL COMMENT '目标状态',
    description VARCHAR(255) COMMENT '流转说明',
    PRIMARY KEY (from_status, to_status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='部件状态合法流转规则表';

-- =====================================================
-- 表7：飞机安装位置与允许部件类别表（AircraftInstallPosition）
-- 功能描述：定义每架飞机上可用的安装位置及允许安装的部件类别
-- 业务意义：每架飞机有固定数量的安装位置（如左侧发动机、航电设备舱等），
--           每个位置只能安装特定类别的部件
-- =====================================================
CREATE TABLE AircraftInstallPosition (
    position_id INT PRIMARY KEY AUTO_INCREMENT COMMENT '安装位置ID',
    aircraft_id INT NOT NULL COMMENT '飞机ID',
    position_code VARCHAR(100) NOT NULL COMMENT '安装位置编码',
    position_name VARCHAR(100) NOT NULL COMMENT '安装位置名称',
    allowed_category VARCHAR(50) NOT NULL COMMENT '该位置允许安装的部件类别',
    is_active BOOLEAN NOT NULL DEFAULT TRUE COMMENT '是否启用',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    CONSTRAINT fk_position_aircraft FOREIGN KEY (aircraft_id) REFERENCES Aircraft(aircraft_id),
    CONSTRAINT fk_position_category FOREIGN KEY (allowed_category) REFERENCES ComponentCategory(category_code),
    CONSTRAINT uq_aircraft_position UNIQUE (aircraft_id, position_code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='飞机安装位置与允许部件类别表';

-- =====================================================
-- 表8：安装拆卸历史记录表（InstallationRecord）
-- 功能描述：记录每个部件在飞机上的完整安装/卸载历史
-- 核心设计：使用三个GENERATED ALWAYS列（active_component_id、active_aircraft_id、
--           active_position_id）实现条件唯一索引
-- 业务意义：当一个组件的uninstall_time为NULL时表示当前仍在安装中，
--           通过条件唯一索引确保同一组件或同一位置只有一个有效安装记录
-- 增强点：增加uninstall_operator_id（拆卸操作人员），完善责任追溯
-- =====================================================
CREATE TABLE InstallationRecord (
    installation_id INT PRIMARY KEY AUTO_INCREMENT COMMENT '安装记录ID',
    component_id INT NOT NULL COMMENT '部件ID',
    aircraft_id INT NOT NULL COMMENT '飞机ID',
    position_id INT NOT NULL COMMENT '规范安装位置ID',
    install_position VARCHAR(100) NOT NULL COMMENT '安装位置',
    install_time DATETIME NOT NULL COMMENT '安装时间',
    uninstall_time DATETIME NULL COMMENT '拆卸时间，NULL表示当前仍在安装中',
    install_reason VARCHAR(255) COMMENT '安装原因',
    uninstall_reason VARCHAR(255) COMMENT '拆卸原因',
    operator_id INT COMMENT '安装操作人员ID',
    uninstall_operator_id INT NULL COMMENT '拆卸操作人员ID',
    -- 以下三个是GENERATED列，仅当uninstall_time为NULL时有值
    active_component_id INT GENERATED ALWAYS AS (
        CASE WHEN uninstall_time IS NULL THEN component_id ELSE NULL END
    ) STORED COMMENT '仅当前安装保留部件ID，用于条件唯一索引',
    active_aircraft_id INT GENERATED ALWAYS AS (
        CASE WHEN uninstall_time IS NULL THEN aircraft_id ELSE NULL END
    ) STORED COMMENT '仅当前安装保留飞机ID，用于条件唯一索引',
    active_position_id INT GENERATED ALWAYS AS (
        CASE WHEN uninstall_time IS NULL THEN position_id ELSE NULL END
    ) STORED COMMENT '仅当前安装保留位置ID，用于条件唯一索引',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    CONSTRAINT fk_install_component FOREIGN KEY (component_id) REFERENCES Component(component_id),
    CONSTRAINT fk_install_aircraft FOREIGN KEY (aircraft_id) REFERENCES Aircraft(aircraft_id),
    CONSTRAINT fk_install_position FOREIGN KEY (position_id) REFERENCES AircraftInstallPosition(position_id),
    CONSTRAINT fk_install_operator FOREIGN KEY (operator_id) REFERENCES Operator(operator_id),
    CONSTRAINT fk_uninstall_operator FOREIGN KEY (uninstall_operator_id) REFERENCES Operator(operator_id),
    CONSTRAINT chk_install_time CHECK (uninstall_time IS NULL OR uninstall_time >= install_time)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='安装拆卸历史记录表';

-- =====================================================
-- 表9：维修记录表（MaintenanceRecord）
-- 功能描述：记录每次维修的详细信息
-- 状态说明：pending（待处理/进行中）、passed（通过）、failed（失败）、scrapped（报废）
-- 业务意义：维修结果直接影响部件状态：
--           passed → 部件恢复可用
--           failed → 需要返工或进一步处理
--           scrapped → 触发退役流程
-- =====================================================
CREATE TABLE MaintenanceRecord (
    maintenance_id INT PRIMARY KEY AUTO_INCREMENT COMMENT '维修记录ID',
    component_id INT NOT NULL COMMENT '部件ID',
    maintenance_type VARCHAR(50) NOT NULL COMMENT '维修类型',
    start_time DATETIME NOT NULL COMMENT '维修开始时间',
    end_time DATETIME NULL COMMENT '维修结束时间',
    result VARCHAR(30) DEFAULT 'pending' COMMENT '维修结果：pending/passed/failed/scrapped',
    description TEXT COMMENT '维修说明',
    technician_id INT COMMENT '维修人员ID',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    CONSTRAINT fk_maintenance_component FOREIGN KEY (component_id) REFERENCES Component(component_id),
    CONSTRAINT fk_maintenance_technician FOREIGN KEY (technician_id) REFERENCES Operator(operator_id),
    CONSTRAINT chk_maintenance_result CHECK (result IN ('pending', 'passed', 'failed', 'scrapped')),
    CONSTRAINT chk_maintenance_time CHECK (end_time IS NULL OR end_time >= start_time),
    -- pending状态时end_time必须为NULL，非pending状态时end_time必须非NULL
    CONSTRAINT chk_pending_end_time CHECK ((result = 'pending' AND end_time IS NULL) OR (result <> 'pending' AND end_time IS NOT NULL))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='维修记录表';

-- =====================================================
-- 表10：维修计划表（MaintenancePlan）
-- 功能描述：存储预定的维修计划
-- 状态说明：pending（待执行）、completed（已完成）、cancelled（已取消）
-- 业务意义：系统可以提前生成维修计划（如周期维修提醒），
--           计划开始执行时创建MaintenanceRecord并关联
-- =====================================================
CREATE TABLE MaintenancePlan (
    plan_id INT PRIMARY KEY AUTO_INCREMENT COMMENT '维修计划ID',
    component_id INT NOT NULL COMMENT '部件ID',
    planned_type VARCHAR(50) NOT NULL COMMENT '计划维修类型',
    planned_time DATETIME NOT NULL COMMENT '计划维修时间',
    planned_reason TEXT COMMENT '计划原因',
    status VARCHAR(30) NOT NULL DEFAULT 'pending' COMMENT '状态：pending/completed/cancelled',
    created_by INT NULL COMMENT '创建人ID',
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    completed_at DATETIME NULL COMMENT '完成或取消时间',
    related_maintenance_id INT NULL COMMENT '关联维修记录ID',
    CONSTRAINT fk_plan_component FOREIGN KEY (component_id) REFERENCES Component(component_id),
    CONSTRAINT fk_plan_creator FOREIGN KEY (created_by) REFERENCES Operator(operator_id),
    CONSTRAINT fk_plan_maintenance FOREIGN KEY (related_maintenance_id) REFERENCES MaintenanceRecord(maintenance_id),
    CONSTRAINT chk_plan_status CHECK (status IN ('pending', 'completed', 'cancelled')),
    -- pending状态时completed_at必须为NULL，非pending状态时completed_at必须非NULL
    CONSTRAINT chk_plan_completed_time CHECK (
        (status = 'pending' AND completed_at IS NULL)
        OR (status IN ('completed', 'cancelled') AND completed_at IS NOT NULL)
    ),
    CONSTRAINT chk_plan_completed_after_created CHECK (
        completed_at IS NULL OR completed_at >= created_at
    )
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='维修计划表';

-- =====================================================
-- 表11：飞行日志表（FlightLog）
-- 功能描述：记录每架飞机的每次飞行任务详情
-- 核心用途：飞行小时数是计算组件维修周期和设计寿命的基础数据
-- 业务意义：通过组件安装时间段关联飞行日志，准确计算每个组件的实际飞行小时
-- =====================================================
CREATE TABLE FlightLog (
    flight_id INT PRIMARY KEY AUTO_INCREMENT COMMENT '飞行记录ID',
    aircraft_id INT NOT NULL COMMENT '飞机ID',
    mission_no VARCHAR(50) NOT NULL UNIQUE COMMENT '飞行任务编号',
    takeoff_time DATETIME NOT NULL COMMENT '起飞时间',
    landing_time DATETIME NOT NULL COMMENT '降落时间',
    flight_hours DECIMAL(10,2) NOT NULL COMMENT '飞行时长',
    mission_type VARCHAR(50) COMMENT '任务类型',
    recorded_by INT COMMENT '记录人ID',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    CONSTRAINT fk_flight_aircraft FOREIGN KEY (aircraft_id) REFERENCES Aircraft(aircraft_id),
    CONSTRAINT fk_flight_operator FOREIGN KEY (recorded_by) REFERENCES Operator(operator_id),
    CONSTRAINT chk_flight_time CHECK (landing_time > takeoff_time),
    CONSTRAINT chk_flight_hours CHECK (flight_hours > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='飞行日志表';

-- =====================================================
-- 表12：退役记录表（RetirementRecord）
-- 功能描述：记录组件退役的信息
-- 业务意义：组件达到设计寿命或维修报废后退役
-- 特点：component_id具有UNIQUE约束，确保一个组件只能退役一次
-- =====================================================
CREATE TABLE RetirementRecord (
    retirement_id INT PRIMARY KEY AUTO_INCREMENT COMMENT '退役记录ID',
    component_id INT NOT NULL UNIQUE COMMENT '退役部件ID',
    retirement_time DATETIME NOT NULL COMMENT '退役时间',
    retirement_reason VARCHAR(255) NOT NULL COMMENT '退役原因',
    approved_by INT COMMENT '审批人员ID',
    remark TEXT COMMENT '备注',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    CONSTRAINT fk_retirement_component FOREIGN KEY (component_id) REFERENCES Component(component_id),
    CONSTRAINT fk_retirement_operator FOREIGN KEY (approved_by) REFERENCES Operator(operator_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='退役记录表';

-- =====================================================
-- 表13：业务操作审计日志表（AuditLog）
-- 功能描述：记录所有关键业务操作的审计信息
-- 用途：满足航空业合规要求，追溯所有数据变更和业务操作
-- 特点：operation_time默认为当前时间，支持按时间排序追溯
-- =====================================================
CREATE TABLE AuditLog (
    audit_id BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '审计日志ID',
    operator_id INT NULL COMMENT '操作人员ID',
    operation_type VARCHAR(50) NOT NULL COMMENT '操作类型',
    target_table VARCHAR(64) NOT NULL COMMENT '目标表',
    target_id INT NULL COMMENT '目标记录ID',
    operation_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '操作时间',
    operation_detail TEXT COMMENT '操作详情',
    CONSTRAINT fk_audit_operator FOREIGN KEY (operator_id) REFERENCES Operator(operator_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='业务操作审计日志表';

-- =====================================================
-- 查询：显示当前数据库中的所有表
-- 用途：验证建表结果
-- =====================================================
SHOW TABLES;