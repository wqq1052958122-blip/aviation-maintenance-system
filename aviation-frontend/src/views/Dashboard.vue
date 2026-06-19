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

    <el-row class="dashboard-section">
      <el-col :span="24">
        <el-card shadow="always">
          <div ref="maintenanceChartRef" class="chart"></div>
        </el-card>
      </el-col>
    </el-row>

    <el-card class="dashboard-section" shadow="never">
      <template #header>
        <span>数据库规则健康检查</span>
      </template>
      <el-row :gutter="16">
        <el-col v-for="item in integrityItems" :key="item.key" :span="8">
          <div class="integrity-card" :class="{ abnormal: integrityLoaded && getIntegrityCount(item.key) > 0 }">
            <div class="integrity-title">{{ item.label }}</div>
            <div class="integrity-value">{{ integrityLoaded ? getIntegrityCount(item.key) : '--' }}</div>
            <el-tag :type="!integrityLoaded ? 'info' : getIntegrityCount(item.key) === 0 ? 'success' : 'danger'">
              {{ !integrityLoaded ? '未加载' : getIntegrityCount(item.key) === 0 ? '正常' : '异常' }}
            </el-tag>
          </div>
        </el-col>
      </el-row>
    </el-card>

    <el-card class="dashboard-section audit-card" shadow="never">
      <template #header>
        <span>最近关键操作</span>
      </template>
      <el-alert
        v-if="auditLoadFailed"
        title="审计日志未加载"
        type="warning"
        :closable="false"
        show-icon
      />
      <el-table v-else-if="recentAuditLogs.length" :data="recentAuditLogs" size="small" style="width: 100%">
        <el-table-column label="操作时间" min-width="150">
          <template #default="scope">{{ formatTime(scope.row.operation_time) }}</template>
        </el-table-column>
        <el-table-column label="操作类型" min-width="120">
          <template #default="scope">
            <el-tag size="small" type="info">{{ formatAuditOperationType(scope.row.operation_type) }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column label="操作人员" min-width="110">
          <template #default="scope">{{ scope.row.operator_name || '系统/未记录' }}</template>
        </el-table-column>
        <el-table-column label="操作详情" min-width="320" show-overflow-tooltip>
          <template #default="scope">{{ formatAuditDetail(scope.row.operation_detail) }}</template>
        </el-table-column>
      </el-table>
      <el-empty v-else description="暂无审计日志" :image-size="70" />
    </el-card>

    <el-card class="dashboard-section" shadow="never">
      <template #header>
        <span>部件寿命预警</span>
      </template>
      <el-table :data="lifeWarningData" border style="width: 100%">
        <el-table-column prop="component_no" label="部件编号" min-width="110" />
        <el-table-column prop="model_code" label="型号" min-width="110" />
        <el-table-column prop="category" label="类别" min-width="100" />
        <el-table-column label="设计寿命" min-width="100">
          <template #default="scope">{{ formatHours(scope.row.design_life_hours) }}</template>
        </el-table-column>
        <el-table-column label="已用小时" min-width="100">
          <template #default="scope">{{ formatHours(scope.row.used_hours) }}</template>
        </el-table-column>
        <el-table-column label="剩余寿命" min-width="110">
          <template #default="scope">{{ formatHours(scope.row.remaining_life_hours) }}</template>
        </el-table-column>
        <el-table-column label="使用比例" min-width="180">
          <template #default="scope">
            <el-progress
              :percentage="toPercentage(scope.row.life_usage_ratio)"
              :color="getWarningColor(scope.row.warning_level)"
            />
          </template>
        </el-table-column>
        <el-table-column label="预警等级" min-width="90">
          <template #default="scope">
            <el-tag :type="getWarningTagType(scope.row.warning_level)">
              {{ translateWarningLevel(scope.row.warning_level) }}
            </el-tag>
          </template>
        </el-table-column>
      </el-table>
    </el-card>

    <el-row class="dashboard-section">
      <el-col :span="24">
        <el-card shadow="always">
          <div ref="retirementChartRef" class="chart"></div>
        </el-card>
      </el-col>
    </el-row>
  </div>
</template>

<script setup>
import { onMounted, onUnmounted, ref } from 'vue'
import * as echarts from 'echarts'
import { getRecentAuditLogs } from '../api/auditLogs'
import {
  formatAuditDetail,
  formatAuditOperationType,
  formatRetirementReason
} from '../utils/businessFormatters'
import {
  getComponentLifeWarning,
  getDashboardStats,
  getDbIntegrityChecks,
  getRetirementReasonStats,
  getSummaryStats
} from '../api/stats'

const summaryData = ref({
  aircraftCount: 0,
  stockCount: 0,
  maintenanceCount: 0
})
const lifeWarningData = ref([])
const recentAuditLogs = ref([])
const auditLoadFailed = ref(false)
const integrityLoaded = ref(false)
const integrityChecks = ref({
  retired_status_inconsistent_count: 0,
  incompatible_active_installation_count: 0,
  active_position_conflict_count: 0
})
const integrityItems = [
  { key: 'retired_status_inconsistent_count', label: '退役状态一致性异常数' },
  { key: 'incompatible_active_installation_count', label: '当前安装型号适配异常数' },
  { key: 'active_position_conflict_count', label: '当前安装位置冲突数' }
]

const maintenanceChartRef = ref(null)
const retirementChartRef = ref(null)
let maintenanceChart = null
let retirementChart = null

const initMaintenanceChart = (rows) => {
  if (!maintenanceChartRef.value) return
  maintenanceChart ||= echarts.init(maintenanceChartRef.value)
  maintenanceChart.setOption({
    title: { text: '各部件型号维修次数统计', left: 'center' },
    tooltip: { trigger: 'axis' },
    xAxis: {
      type: 'category',
      data: rows.map(item => item.model_code || '未知型号'),
      axisLabel: { interval: 0, rotate: 30 }
    },
    yAxis: { type: 'value', name: '维修次数', minInterval: 1 },
    series: [{
      data: rows.map(item => Number(item.maintenance_count) || 0),
      type: 'bar',
      barWidth: '40%',
      itemStyle: { color: '#409EFF', borderRadius: [4, 4, 0, 0] },
      label: { show: true, position: 'top' }
    }]
  }, true)
}

const initRetirementChart = (rows) => {
  if (!retirementChartRef.value) return
  retirementChart ||= echarts.init(retirementChartRef.value)
  retirementChart.setOption({
    title: { text: '退役原因统计', left: 'center' },
    tooltip: {
      trigger: 'item',
      formatter: params => `${params.marker}${params.name}：${params.value} 个（${params.percent}%）`
    },
    legend: { bottom: 0, type: 'scroll', formatter: name => name },
    series: [{
      name: '退役数量',
      type: 'pie',
      radius: ['35%', '65%'],
      center: ['50%', '48%'],
      data: rows.map(item => ({
        name: formatRetirementReason(item.retirement_reason),
        value: Number(item.retirement_count) || 0
      })),
      label: { formatter: '{b}：{c} 个' }
    }]
  }, true)
}

const fetchMaintenanceStats = async () => {
  const rows = await getDashboardStats()
  initMaintenanceChart(Array.isArray(rows) ? rows : [])
}

const fetchSummaryData = async () => {
  const data = await getSummaryStats()
  summaryData.value = {
    aircraftCount: Number(data?.aircraft_count) || 0,
    stockCount: Number(data?.stock_count) || 0,
    maintenanceCount: Number(data?.maintenance_count) || 0
  }
}

const fetchLifeWarnings = async () => {
  const rows = await getComponentLifeWarning()
  lifeWarningData.value = Array.isArray(rows) ? rows : []
}

const fetchRetirementReasons = async () => {
  const rows = await getRetirementReasonStats()
  initRetirementChart(Array.isArray(rows) ? rows : [])
}

const fetchIntegrityChecks = async () => {
  const data = await getDbIntegrityChecks()
  integrityChecks.value = { ...integrityChecks.value, ...(data || {}) }
  integrityLoaded.value = true
}

const fetchRecentAuditLogs = async () => {
  auditLoadFailed.value = false
  try {
    const rows = await getRecentAuditLogs()
    recentAuditLogs.value = (Array.isArray(rows) ? rows : []).slice(0, 5)
  } catch {
    recentAuditLogs.value = []
    auditLoadFailed.value = true
  }
}

const getIntegrityCount = (key) => Number(integrityChecks.value[key]) || 0
const formatHours = (value) => Number(value || 0).toFixed(2)
const toPercentage = (ratio) => Math.min(100, Math.max(0, Number((Number(ratio || 0) * 100).toFixed(1))))

const translateWarningLevel = (level) => ({
  normal: '正常',
  warning: '预警',
  critical: '严重'
}[level] || level)

const getWarningTagType = (level) => ({
  normal: 'success',
  warning: 'warning',
  critical: 'danger'
}[level] || 'info')

const getWarningColor = (level) => ({
  normal: '#67C23A',
  warning: '#E6A23C',
  critical: '#F56C6C'
}[level] || '#909399')

const formatTime = (value) => value ? String(value).replace('T', ' ').slice(0, 19) : '-'

const handleResize = () => {
  maintenanceChart?.resize()
  retirementChart?.resize()
}

onMounted(() => {
  Promise.allSettled([
    fetchSummaryData(),
    fetchMaintenanceStats(),
    fetchLifeWarnings(),
    fetchRetirementReasons(),
    fetchIntegrityChecks(),
    fetchRecentAuditLogs()
  ])
  window.addEventListener('resize', handleResize)
})

onUnmounted(() => {
  window.removeEventListener('resize', handleResize)
  maintenanceChart?.dispose()
  retirementChart?.dispose()
})
</script>

<style scoped>
.dashboard-container {
  padding: 20px;
}
.panel-group,
.dashboard-section {
  margin-top: 20px;
}
.panel-group {
  margin-top: 0;
}
.card-panel {
  text-align: center;
  padding: 10px 0;
}
.card-panel-text,
.integrity-title {
  color: #909399;
  font-size: 16px;
  margin-bottom: 10px;
}
.card-panel-num,
.integrity-value {
  color: #303133;
  font-size: 32px;
  font-weight: bold;
}
.integrity-card {
  padding: 18px;
  text-align: center;
  border: 1px solid #dcdfe6;
  border-radius: 6px;
  background: #f0f9eb;
}
.integrity-card.abnormal {
  background: #fef0f0;
  border-color: #fab6b6;
}
.integrity-value {
  margin-bottom: 10px;
}
.chart {
  width: 100%;
  height: 400px;
}
.audit-card :deep(.el-card__body) {
  padding-top: 10px;
}
</style>
