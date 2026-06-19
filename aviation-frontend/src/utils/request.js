import axios from 'axios'
import { ElMessage } from 'element-plus'

const service = axios.create({
  baseURL: '/api',
  timeout: 10000
})

// 响应拦截器：统一处理后端的 { success, data, message } 格式
service.interceptors.response.use(
  response => {
    const res = response.data
    if (res.success) {
      return res.data
    } else {
      const message = res.message || '请求失败'
      ElMessage.error(`操作失败：${message}`)
      return Promise.reject(new Error(message))
    }
  },
  error => {
    const message = error.response?.data?.message || error.message || '网络错误'
    ElMessage.error(`操作失败：${message}`)
    return Promise.reject(error)
  }
)

export default service