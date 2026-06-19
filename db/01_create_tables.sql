-- =====================================================
-- 项目1：航空部件生命周期与维修管理系统
-- 文件：01_create_tables.sql
-- 作用：建库 + 建 11 张核心表 + 基础约束
-- 数据库：MySQL 8.0
-- 增强点：统一字符集；InstallationRecord 增加拆卸责任人；保留历史时间区间
-- =====================================================

DROP DATABASE IF EXISTS aviation_maintenance;
CREATE DATABASE aviation_maintenance
DEFAULT CHARACTER SET utf8mb4
DEFAULT COLLATE utf8mb4_0900_ai_ci;

USE aviation_maintenance;

CREATE TABLE Operator (
    operator_id INT PRIMARY KEY AUTO_INCREMENT COMMENT '操作人员ID',
    operator_name VARCHAR(50) NOT NULL COMMENT '操作人员姓名',
    role VARCHAR(30) NOT NULL COMMENT '角色：installer/technician/approver/admin',
    phone VARCHAR(30) COMMENT '联系电话',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    CONSTRAINT chk_operator_role CHECK (role IN ('installer', 'technician', 'approver', 'admin'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='操作人员表';

CREATE TABLE Aircraft (
    aircraft_id INT PRIMARY KEY AUTO_INCREMENT COMMENT '飞机ID',
    aircraft_no VARCHAR(50) NOT NULL UNIQUE COMMENT '飞机编号',
    aircraft_model VARCHAR(50) NOT NULL COMMENT '飞机型号',
    service_status VARCHAR(30) NOT NULL DEFAULT 'active' COMMENT '服役状态：active/maintenance/retired',
    start_date DATE COMMENT '启用日期',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    CONSTRAINT chk_aircraft_status CHECK (service_status IN ('active', 'maintenance', 'retired'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='飞机表';

CREATE TABLE ComponentModel (
    model_id INT PRIMARY KEY AUTO_INCREMENT COMMENT '部件型号ID',
    model_code VARCHAR(50) NOT NULL UNIQUE COMMENT '部件型号编码',
    category VARCHAR(50) NOT NULL COMMENT '部件类别',
    design_life_hours INT NOT NULL COMMENT '设计寿命小时',
    maintenance_cycle_hours INT NOT NULL COMMENT '维修周期小时',
    applicable_aircraft_model VARCHAR(50) COMMENT '适用飞机型号',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    CONSTRAINT chk_design_life CHECK (design_life_hours > 0),
    CONSTRAINT chk_maintenance_cycle CHECK (maintenance_cycle_hours > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='部件型号表';

CREATE TABLE Component (
    component_id INT PRIMARY KEY AUTO_INCREMENT COMMENT '部件ID',
    component_no VARCHAR(50) NOT NULL UNIQUE COMMENT '部件唯一编号',
    model_id INT NOT NULL COMMENT '所属部件型号ID',
    batch_no VARCHAR(50) COMMENT '批次号',
    production_date DATE COMMENT '生产日期',
    status VARCHAR(30) NOT NULL DEFAULT 'in_stock' COMMENT '当前状态',
    total_flight_hours DECIMAL(10,2) NOT NULL DEFAULT 0 COMMENT '累计飞行小时，准确统计以飞行日志关联视图为准',
    is_retired BOOLEAN NOT NULL DEFAULT FALSE COMMENT '是否退役',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT '入库时间',
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    CONSTRAINT fk_component_model FOREIGN KEY (model_id) REFERENCES ComponentModel(model_id),
    CONSTRAINT chk_component_status CHECK (status IN ('in_stock','installed','removed','under_maintenance','available','retired')),
    CONSTRAINT chk_total_flight_hours CHECK (total_flight_hours >= 0),
    CONSTRAINT chk_retired_status_consistency CHECK ((status = 'retired' AND is_retired = TRUE) OR (status <> 'retired' AND is_retired = FALSE))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='部件实例表';

CREATE TABLE ComponentStatusTransitionRule (
    from_status VARCHAR(30) NOT NULL COMMENT '原状态',
    to_status VARCHAR(30) NOT NULL COMMENT '目标状态',
    description VARCHAR(255) COMMENT '流转说明',
    PRIMARY KEY (from_status, to_status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='部件状态合法流转规则表';

CREATE TABLE InstallationRecord (
    installation_id INT PRIMARY KEY AUTO_INCREMENT COMMENT '安装记录ID',
    component_id INT NOT NULL COMMENT '部件ID',
    aircraft_id INT NOT NULL COMMENT '飞机ID',
    install_position VARCHAR(100) NOT NULL COMMENT '安装位置',
    install_time DATETIME NOT NULL COMMENT '安装时间',
    uninstall_time DATETIME NULL COMMENT '拆卸时间，NULL表示当前仍在安装中',
    install_reason VARCHAR(255) COMMENT '安装原因',
    uninstall_reason VARCHAR(255) COMMENT '拆卸原因',
    operator_id INT COMMENT '安装操作人员ID',
    uninstall_operator_id INT NULL COMMENT '拆卸操作人员ID',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    CONSTRAINT fk_install_component FOREIGN KEY (component_id) REFERENCES Component(component_id),
    CONSTRAINT fk_install_aircraft FOREIGN KEY (aircraft_id) REFERENCES Aircraft(aircraft_id),
    CONSTRAINT fk_install_operator FOREIGN KEY (operator_id) REFERENCES Operator(operator_id),
    CONSTRAINT fk_uninstall_operator FOREIGN KEY (uninstall_operator_id) REFERENCES Operator(operator_id),
    CONSTRAINT chk_install_time CHECK (uninstall_time IS NULL OR uninstall_time >= install_time)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='安装拆卸历史记录表';

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
    CONSTRAINT chk_pending_end_time CHECK ((result = 'pending' AND end_time IS NULL) OR (result <> 'pending' AND end_time IS NOT NULL))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='维修记录表';

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
    CONSTRAINT chk_plan_completed_time CHECK (
        (status = 'pending' AND completed_at IS NULL)
        OR (status IN ('completed', 'cancelled') AND completed_at IS NOT NULL)
    )
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='维修计划表';

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

SHOW TABLES;
