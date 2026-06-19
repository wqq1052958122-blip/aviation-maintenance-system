import request from '../utils/request'

// 获取部件型号的维修统计数据
export function getDashboardStats() {
  return request.get('/stats/model-maintenance')
}

// 【新增】：获取顶部面板的汇总统计数据
export function getSummaryStats() {
  return request.get('/stats/summary')
}