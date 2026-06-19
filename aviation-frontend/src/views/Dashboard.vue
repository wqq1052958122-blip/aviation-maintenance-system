<template>
  <div class="dashboard-container">
    <h2>系统数据看板</h2>

    <el-row :gutter="20" class="panel-group">
      <el-col :span="8">
        <el-card shadow="hover" class="card-panel">
          <div class="card-panel-text">在役飞机总数</div>
          <div class="card-panel-num">{{ summaryData.aircraftCount }}</div>
        </el-card>
      </el-col>
      <el-col :span="8">
        <el-card shadow="hover" class="card-panel">
          <div class="card-panel-text">库存部件总数</div>
          <div class="card-panel-num">{{ summaryData.stockCount }}</div>
        </el-card>
      </el-col>
      <el-col :span="8">
        <el-card shadow="hover" class="card-panel">
          <div class="card-panel-text">总维修工单数</div>
          <div class="card-panel-num">{{ summaryData.maintenanceCount }}</div>
        </el-card>
      </el-col>
    </el-row>

    <el-row style="margin-top: 20px;">
      <el-col :span="24">
        <el-card shadow="always">
          <div ref="chartRef" style="height: 400px; width: 100%;"></div>
        </el-card>
      </el-col>
    </el-row>
  </div>
</template>

<script setup>
import { ref, onMounted, onUnmounted } from 'vue'
import * as echarts from 'echarts'
// 【修改点1】：把 getSummaryStats 一起导入进来
import { getDashboardStats, getSummaryStats } from '../api/stats' 

// 【修改点2】：定义用于存放面板数据的响应式变量
const summaryData = ref({
  aircraftCount: 0,
  stockCount: 0,
  maintenanceCount: 0
})




const chartRef = ref(null)
let myChart = null

const initChart = (data) => {
  if (!chartRef.value) return
  if (!myChart) {
    myChart = echarts.init(chartRef.value)
  }
  
  const option = {
    title: { text: '各部件型号维修次数统计 (Top)', left: 'center' },
    tooltip: { trigger: 'axis' },
    xAxis: {
      type: 'category',
      data: data.models,
      axisLabel: { interval: 0, rotate: 30 }
    },
    yAxis: { type: 'value', name: '维修次数' },
    series: [
      {
        data: data.counts,
        type: 'bar',
        barWidth: '40%',
        itemStyle: { color: '#409EFF', borderRadius: [4, 4, 0, 0] },
        label: { show: true, position: 'top' }
      }
    ]
  }
  myChart.setOption(option)
}

const fetchAndRenderChart = async () => {
  try {
    const res = await getDashboardStats()
    
    // 【教学时间】直接打印 res，请在 F12 控制台点开它左边的小三角！
    console.log("👉 1. 后端返回的完整数据 res 是：", res)

    // 智能寻找真正的数组
    let listData = []
    if (Array.isArray(res)) {
      listData = res // 如果 axios 拦截器已经脱壳，直接用 res
    } else if (res && Array.isArray(res.data)) {
      listData = res.data // 如果包在 data 里
    } else if (res && res.data && Array.isArray(res.data.data)) {
      listData = res.data.data // 如果包了两层
    } else {
      console.error("❌ 2. 找不到数组！请点开上面的 res，看看数组(包含 [{...}]) 藏在哪个英文单词下面！")
      return
    }

    console.log("✅ 3. 成功找到的数组：", listData)

    // 安全提取数据
    const models = listData.map(item => {
      if (!item) return '未知'
      // 【修改点】：这里换成你数据库真实的字段名 item.model_code ！！！
      return item.model_code || '未知型号'
    })
    
    const counts = listData.map(item => {
      if (!item) return 0
      // 这个字段咱们之前碰巧蒙对了，就是 item.maintenance_count
      return item.maintenance_count || 0
    })

    initChart({ models, counts })
    
  } catch (error) {
    console.error("获取图表数据失败详情:", error)
  }
}

onMounted(() => {
  // 注意：这里只调用真实的 API 接口，千万不要再放 initChart(假数据) 了！
  fetchAndRenderChart()

  window.addEventListener('resize', () => {
    if (myChart) myChart.resize()
  })
})

onUnmounted(() => {
  window.removeEventListener('resize', () => {})
  if (myChart) myChart.dispose()
})


// 【修改点3】：增加获取顶部面板数据的函数
const fetchSummaryData = async () => {
  try {
    const res = await getSummaryStats()
    // 防御性脱壳，适配 axios 拦截器
    const data = res.data || res 
    
    // 将后端返回的数据赋值给前端变量
    summaryData.value.aircraftCount = data.aircraft_count || 0
    summaryData.value.stockCount = data.stock_count || 0
    summaryData.value.maintenanceCount = data.maintenance_count || 0
  } catch (error) {
    console.error("获取统计面板数据失败:", error)
  }
}

onMounted(() => {
  // 原有的图表渲染
  fetchAndRenderChart()
  
  // 【修改点4】：页面加载时，顺便把顶部面板的数据也请求回来！
  fetchSummaryData()

  window.addEventListener('resize', () => {
    if (myChart) myChart.resize()
  })
})
</script>

<style scoped>
.dashboard-container {
  padding: 20px;
}
.card-panel {
  text-align: center;
  padding: 10px 0;
}
.card-panel-text {
  color: #909399;
  font-size: 16px;
  margin-bottom: 10px;
}
.card-panel-num {
  color: #303133;
  font-size: 32px;
  font-weight: bold;
}
</style>