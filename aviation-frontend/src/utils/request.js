// import axios from 'axios'
// import { ElMessage } from 'element-plus'

// // 创建 axios 实例
// const service = axios.create({
//   baseURL: '/api', // 结合 vite.config.js 的代理
//   timeout: 5000 // 请求超时时间
// })

// // 响应拦截器
// service.interceptors.response.use(
//   response => {
//     const res = response.data
//     // 如果后端返回 success: true，直接把 data 剥离出来给组件用
//     if (res.success) {
//       return res.data
//     } else {
//       // 如果后端校验失败（如触发器报错），自动弹出后端写的 message
//       ElMessage.error(res.message || '业务操作失败')
//       return Promise.reject(new Error(res.message || 'Error'))
//     }
//   },
//   error => {
//     // 处理 HTTP 状态码层面的错误 (比如 400, 500)
//     const msg = error.response?.data?.message || error.message
//     ElMessage.error(msg || '网络连接异常')
//     return Promise.reject(error)
//   }
// )

// export default service

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
      ElMessage.error(res.message || '请求失败')
      return Promise.reject(new Error(res.message || '请求失败'))
    }
  },
  error => {
    const message = error.response?.data?.message || error.message || '网络错误'
    ElMessage.error(message)
    return Promise.reject(error)
  }
)

export default service