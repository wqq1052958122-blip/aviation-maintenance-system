import request from '../utils/request'

// 查询最近 20 条审计日志
export function getRecentAuditLogs() {
  return request.get('/audit-logs/recent')
}
