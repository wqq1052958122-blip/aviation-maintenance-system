import request from '../utils/request'

// 获取所有部件列表
export function getComponents() {
  return request.get('/components')
}

// 新部件入库
export function createComponent(data) {
  return request.post('/components', data)
}

// 获取部件详细档案 (Profile视图)
export function getComponentProfile(component_no) {
  return request.get(`/components/${component_no}/profile`)
}

// 获取部件生命周期轨迹 (Lifecycle视图)
export function getComponentLifecycle(component_no) {
  return request.get(`/components/${component_no}/lifecycle`)
}

// 获取部件飞行使用统计
export function getComponentFlightUsage(component_no) {
  return request.get(`/components/${component_no}/flight-usage`)
}

// 退役部件
export function retireComponent(component_no, data) {
  return request.post(`/components/${component_no}/retire`, data)
}

// src/api/components.js
export function getComponentModels() {
  return request.get('/component-models') // 对应后端的路由地址
}