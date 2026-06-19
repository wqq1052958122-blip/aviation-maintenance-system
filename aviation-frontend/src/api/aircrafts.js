import request from '../utils/request'

// 获取飞机大盘列表
export function getAircrafts() {
  return request.get('/aircrafts')
}

// 录入新飞机
export function createAircraft(data) {
  return request.post('/aircrafts', data)
}

// 更新飞机状态
export function updateAircraftStatus(aircraft_no, service_status) {
  return request.put(`/aircrafts/${aircraft_no}/status`, { service_status })
}