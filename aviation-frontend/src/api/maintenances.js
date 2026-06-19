import request from '../utils/request'

// 1. 查询指定部件的维修记录
export function getComponentMaintenances(component_no) {
  // 匹配后端: @router.get("/components/{component_no}/maintenances")
  return request.get(`/components/${component_no}/maintenances`)
}

// 2. 创建维修记录
export function createMaintenance(data) {
  // 匹配后端: @router.post("/maintenances")
  return request.post('/maintenances', data)
}

// 3. 完成维修
export function completeMaintenance(maintenance_id, data) {
  // 匹配后端: @router.post("/maintenances/{maintenance_id}/complete")
  return request.post(`/maintenances/${maintenance_id}/complete`, data)
}

// 在原来的文件里加上这个：
export function getAllMaintenances() {
  return request.get('/maintenances')
}

// 查询待执行维修计划
export function getMaintenancePlans() {
  return request.get('/maintenance-plans')
}

// 创建维修计划
export function createMaintenancePlan(data) {
  return request.post('/maintenance-plans', data)
}

// 完成维修计划
export function completeMaintenancePlan(plan_id, data = {}) {
  return request.post(`/maintenance-plans/${plan_id}/complete`, data)
}

// 取消维修计划
export function cancelMaintenancePlan(plan_id, data = {}) {
  return request.post(`/maintenance-plans/${plan_id}/cancel`, data)
}
