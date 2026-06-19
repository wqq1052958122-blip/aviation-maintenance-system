import request from '../utils/request'

export function getOperators() {
  return request.get('/operators')
}

export function createOperator(data) {
  return request.post('/operators', data)
}