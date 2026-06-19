import request from '../utils/request'

// 1. 获取飞行日志列表
export function getFlightLogs() {
  return request.get('/flights')
}

// 2. 创建飞行日志
export function createFlightLog(data) {
  // 注意：前端不要传 flight_hours，后端会自动计算
  return request.post('/flights', data)
}