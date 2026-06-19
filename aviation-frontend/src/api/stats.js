import request from '../utils/request'

// 获取部件型号的维修统计数据
export function getDashboardStats() {
  return request.get('/stats/model-maintenance')
}

// 【新增】：获取顶部面板的汇总统计数据
export function getSummaryStats() {
  return request.get('/stats/summary')
}

// 获取部件寿命预警
export function getComponentLifeWarning() {
  return request.get('/stats/component-life-warning')
}

// 获取退役原因统计
export function getRetirementReasonStats() {
  return request.get('/stats/retirement-reasons')
}

// 获取数据库完整性健康检查
export function getDbIntegrityChecks() {
  return request.get('/stats/db-integrity-checks')
}
