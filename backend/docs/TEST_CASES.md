# 后端答辩测试流程

以下流程适合使用 Swagger 或 Postman 演示。执行前请确认数据库已按推荐顺序初始化。

## 1. 查询部件列表

请求：`GET /components`

预期：返回初始化部件数据，例如 `ENG-001`、`ENG-002`、`HYD-002` 等。

## 2. 新部件入库

请求：`POST /components`

```json
{
  "component_no": "ENG-009",
  "model_id": 1,
  "batch_no": "BATCH-2025-01",
  "production_date": "2025-01-01"
}
```

预期：成功返回新部件编号，状态默认为 `in_stock`。

## 3. 正常安装部件

请求：`POST /installations`

```json
{
  "component_no": "ENG-003",
  "aircraft_no": "AC-1002",
  "install_position": "right engine position",
  "install_time": "2025-06-01 09:00:00",
  "install_reason": "normal installation",
  "operator_id": 1
}
```

预期：安装成功，部件状态由数据库触发器更新为 `installed`。

## 4. 重复安装同一部件

再次对刚安装的 `ENG-003` 调用 `POST /installations`。

预期：失败，返回类似：

```json
{
  "success": false,
  "message": "Only in_stock or available components can be installed."
}
```

或：

```json
{
  "success": false,
  "message": "Component already has an active installation record."
}
```

## 5. 拆卸部件

请求：`POST /installations/{installation_id}/uninstall`

```json
{
  "uninstall_time": "2025-06-01 12:00:00",
  "uninstall_reason": "regular inspection",
  "uninstall_operator_id": 1
}
```

预期：拆卸成功，部件状态由数据库触发器更新为 `removed`。

## 6. 更换部件

请求：`POST /components/replace`

```json
{
  "old_component_no": "ENG-001",
  "new_component_no": "ENG-002",
  "aircraft_no": "AC-1001",
  "install_position": "left engine position",
  "replace_time": "2025-06-01 09:00:00",
  "operator_id": 1,
  "uninstall_reason": "replacement test"
}
```

预期：调用存储过程成功，旧部件拆卸，新部件安装。

## 7. 创建维修记录

请求：`POST /maintenances`

```json
{
  "component_no": "HYD-001",
  "maintenance_type": "regular inspection",
  "start_time": "2025-06-02 09:00:00",
  "description": "start inspection",
  "technician_id": 2
}
```

预期：创建成功，结果为 `pending`。

## 8. 完成维修

请求：`POST /maintenances/{maintenance_id}/complete`

```json
{
  "end_time": "2025-06-03 10:00:00",
  "result": "passed",
  "description": "maintenance passed",
  "approved_by": null,
  "retirement_reason": null
}
```

预期：调用存储过程成功，部件状态变为 `available`。

## 9. 退役部件

请求：`POST /components/{component_no}/retire`

```json
{
  "retirement_time": "2025-06-05 10:00:00",
  "retirement_reason": "life limit reached",
  "approved_by": 3,
  "remark": "approved by maintenance department"
}
```

预期：调用存储过程成功，部件状态变为 `retired`。

## 10. 尝试安装退役部件

请求：`POST /installations`

```json
{
  "component_no": "HYD-002",
  "aircraft_no": "AC-1001",
  "install_position": "hydraulic system bay",
  "install_time": "2025-06-06 09:00:00",
  "install_reason": "illegal test",
  "operator_id": 1
}
```

预期：失败，返回：

```json
{
  "success": false,
  "message": "Retired component cannot be installed."
}
```

## 11. 查询生命周期时间线

请求：`GET /components/HYD-001/lifecycle`

预期：按时间顺序返回入库、安装、拆卸、维修等事件。

## 12. 查询部件飞行使用统计

请求：`GET /components/ENG-001/flight-usage`

预期：返回部件关联飞机、飞行次数、累计飞行小时等统计信息。
