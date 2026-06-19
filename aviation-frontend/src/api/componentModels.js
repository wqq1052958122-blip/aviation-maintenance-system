import request from '../utils/request'

// 获取部件型号列表
export function getComponentModels() {
  return request.get('/component-models')
}