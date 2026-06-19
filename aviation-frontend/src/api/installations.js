import request from '../utils/request'

// 获取当前所有在机部件
export function getActiveInstallations() {
  return request.get('/current-installations')
}

// 安装部件
export function installComponent(data) {
  return request.post('/installations', data)
}

// 拆卸部件
export function uninstallComponent(installation_id, data) {
  return request.post(`/installations/${installation_id}/uninstall`, data)
}

// 更换部件
export function replaceComponent(data) {
  return request.post('/components/replace', data)
}