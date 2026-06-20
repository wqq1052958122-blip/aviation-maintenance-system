<template>
  <div class="dashboard-container">
    <section class="welcome-banner">
      <div>
        <span class="welcome-kicker">OPERATIONS OVERVIEW</span>
        <h2>航空维修运行总览</h2>
        <p>实时查看部件寿命风险、维修计划、审计日志与数据库健康状态</p>
      </div>
      <div class="welcome-summary">
        <div><strong>{{ summaryData.aircraftCount }}</strong><span>在役飞机</span></div>
        <div><strong>{{ summaryData.stockCount }}</strong><span>库存部件</span></div>
        <div><strong>{{ summaryData.maintenanceCount }}</strong><span>维修工单</span></div>
      </div>
    </section>

    <section class="risk-overview">
      <article v-for="item in riskCards" :key="item.key" class="risk-card" :class="item.tone">
        <div class="risk-symbol">{{ item.symbol }}</div>
        <div><span>{{ item.label }}</span><strong>{{ item.loaded ? item.value : '未加载' }}</strong><small>{{ item.description }}</small></div>
      </article>
    </section>

    <el-card class="dashboard-section" shadow="never">
      <template #header>
        <div class="card-title"><span>重点寿命预警</span><small>按使用比例展示风险最高的 5 个部件</small></div>
      </template>
      <el-table :data="priorityLifeWarnings" border style="width: 100%" v-loading="lifeWarningLoading" element-loading-text="正在加载数据...">
        <el-table-column prop="component_no" label="部件编号" min-width="110" />
        <el-table-column prop="model_code" label="型号" min-width="110" />
        <el-table-column label="类别" min-width="100">
          <template #default="scope">{{ formatComponentCategory(scope.row.category) }}</template>
        </el-table-column>
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
        <template #empty><el-empty :description="lifeWarningLoaded ? '暂无数据' : '加载失败'" /></template>
      </el-table>
    </el-card>

    <section class="dashboard-grid dashboard-section">
      <el-card shadow="never"><div ref="maintenanceChartRef" class="chart compact-chart"></div></el-card>
      <el-card shadow="never">
        <template #header><span>数据库规则健康检查</span></template>
        <div class="integrity-list">
          <div v-for="item in integrityItems" :key="item.key" class="integrity-card" :class="{ abnormal: integrityLoaded && getIntegrityCount(item.key) > 0 }">
            <div><div class="integrity-title">{{ item.label }}</div><el-tag size="small" :type="!integrityLoaded ? 'info' : getIntegrityCount(item.key) === 0 ? 'success' : 'danger'">{{ !integrityLoaded ? '未加载' : getIntegrityCount(item.key) === 0 ? '正常' : '异常' }}</el-tag></div>
            <div class="integrity-value">{{ integrityLoaded ? getIntegrityCount(item.key) : '--' }}</div>
          </div>
        </div>
      </el-card>
    </section>

    <section class="dashboard-grid dashboard-section">
      <el-card shadow="never"><div ref="retirementChartRef" class="chart compact-chart"></div></el-card>
      <el-card class="audit-card" shadow="never">
        <template #header><span>最近关键操作</span></template>
        <div class="audit-toolbar">
          <el-select v-model="auditFilters.operationType" clearable placeholder="全部操作类型"><el-option label="部件更换" value="replace_component" /><el-option label="部件退役" value="retire_component" /><el-option label="完成维修" value="complete_maintenance" /><el-option label="创建维修计划" value="create_maintenance_plan" /><el-option label="完成维修计划" value="complete_maintenance_plan" /><el-option label="取消维修计划" value="cancel_maintenance_plan" /></el-select>
          <el-input v-model="auditFilters.operator" clearable placeholder="操作人员关键词" />
          <el-button @click="resetAuditFilters">重置</el-button><el-button type="primary" @click="fetchRecentAuditLogs">刷新</el-button>
        </div>
        <el-alert v-if="auditLoadFailed" title="审计日志未加载" type="warning" :closable="false" show-icon />
        <el-table v-else-if="filteredAuditLogs.length" :data="filteredAuditLogs" size="small" height="300" style="width: 100%">
          <el-table-column label="时间" min-width="145"><template #default="scope">{{ formatTime(scope.row.operation_time) }}</template></el-table-column>
          <el-table-column label="操作" min-width="120"><template #default="scope"><el-tag size="small" type="info">{{ formatAuditOperationType(scope.row.operation_type) }}</el-tag></template></el-table-column>
          <el-table-column label="人员" min-width="105"><template #default="scope">{{ scope.row.operator_name || '系统/未记录' }}</template></el-table-column>
          <el-table-column label="详情" min-width="220" show-overflow-tooltip><template #default="scope">{{ formatAuditDetail(scope.row.operation_detail) }}</template></el-table-column>
        </el-table>
        <el-empty v-else description="暂无审计日志" :image-size="70" />
      </el-card>
    </section>
  </div>
</template>

<script setup>
import { computed, onMounted, onUnmounted, reactive, ref } from 'vue'
import * as echarts from 'echarts'
import { getRecentAuditLogs } from '../api/auditLogs'
import {
  formatAuditDetail,
  formatAuditOperationType,
  formatComponentCategory,
  formatRetirementReason,
  formatWarningLevel,
  getWarningStatusType
} from '../utils/businessFormatters'
import { getComponents } from '../api/components'
import { getMaintenancePlans } from '../api/maintenances'
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
const priorityLifeWarnings = computed(() => [...lifeWarningData.value]
  .sort((a, b) => Number(b.life_usage_ratio || 0) - Number(a.life_usage_ratio || 0))
  .slice(0, 5))
const lifeWarningLoaded = ref(false)
const lifeWarningLoading = ref(false)
const componentRiskLoaded = ref(false)
const maintenancePlanLoaded = ref(false)
const maintenanceComponentCount = ref(0)
const pendingPlanCount = ref(0)
const recentAuditLogs = ref([])
const auditFilters = reactive({ operationType: '', operator: '' })
const filteredAuditLogs = computed(() => recentAuditLogs.value.filter(item =>
  (!auditFilters.operationType || item.operation_type === auditFilters.operationType)
  && String(item.operator_name || '').toLowerCase().includes(auditFilters.operator.trim().toLowerCase())
).slice(0, 5))
const resetAuditFilters = () => Object.assign(auditFilters, { operationType: '', operator: '' })
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
const riskCards = computed(() => {
  const databaseIssueCount = Object.values(integrityChecks.value).reduce((sum, value) => sum + (Number(value) || 0), 0)
  return [
    { key: 'critical', label: '严重寿命风险', value: lifeWarningData.value.filter(item => item.warning_level === 'critical').length, loaded: lifeWarningLoaded.value, tone: 'danger', symbol: '!' , description: '使用比例达到严重阈值' },
    { key: 'warning', label: '预警部件', value: lifeWarningData.value.filter(item => item.warning_level === 'warning').length, loaded: lifeWarningLoaded.value, tone: 'warning', symbol: '△', description: '需要关注剩余寿命' },
    { key: 'maintenance', label: '维修中部件', value: maintenanceComponentCount.value, loaded: componentRiskLoaded.value, tone: 'primary', symbol: 'M', description: '当前处于维修状态' },
    { key: 'plans', label: '待执行维修计划', value: pendingPlanCount.value, loaded: maintenancePlanLoaded.value, tone: 'warning', symbol: 'P', description: '等待安排执行' },
    { key: 'database', label: '数据库异常数', value: databaseIssueCount, loaded: integrityLoaded.value, tone: databaseIssueCount > 0 ? 'danger' : 'success', symbol: 'DB', description: '一致性规则检查汇总' }
  ]
})

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
  lifeWarningLoading.value = true
  try {
    const rows = await getComponentLifeWarning()
    lifeWarningData.value = Array.isArray(rows) ? rows : []
    lifeWarningLoaded.value = true
  } finally {
    lifeWarningLoading.value = false
  }
}

const fetchOperationalRisks = async () => {
  const [componentsResult, plansResult] = await Promise.allSettled([getComponents(), getMaintenancePlans()])
  if (componentsResult.status === 'fulfilled') {
    const rows = componentsResult.value?.data || componentsResult.value || []
    maintenanceComponentCount.value = (Array.isArray(rows) ? rows : []).filter(item => item.status === 'under_maintenance').length
    componentRiskLoaded.value = true
  }
  if (plansResult.status === 'fulfilled') {
    const rows = plansResult.value?.data || plansResult.value || []
    pendingPlanCount.value = (Array.isArray(rows) ? rows : []).filter(item => item.status === 'pending').length
    maintenancePlanLoaded.value = true
  }
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
    recentAuditLogs.value = Array.isArray(rows) ? rows : []
  } catch {
    recentAuditLogs.value = []
    auditLoadFailed.value = true
  }
}

const getIntegrityCount = (key) => Number(integrityChecks.value[key]) || 0
const formatHours = (value) => Number(value || 0).toFixed(2)
const toPercentage = (ratio) => Math.min(100, Math.max(0, Number((Number(ratio || 0) * 100).toFixed(1))))

const translateWarningLevel = formatWarningLevel
const getWarningTagType = getWarningStatusType

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
    fetchRecentAuditLogs(),
    fetchOperationalRisks()
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
  padding: 0;
}
.welcome-banner {
  position: relative;
  min-height: 150px;
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 28px 36px;
  overflow: hidden;
  color: #fff;
  border-radius: 14px;
  background:
    radial-gradient(circle at 84% 20%, rgba(97, 202, 247, 0.3), transparent 25%),
    linear-gradient(120deg, #07365f, #0d6dab 70%, #2194cf);
  box-shadow: 0 14px 32px rgba(8, 78, 126, 0.18);
}
.welcome-banner::after {
  content: "";
  position: absolute;
  right: 90px;
  bottom: -90px;
  width: 230px;
  height: 230px;
  border: 1px solid rgba(255, 255, 255, 0.15);
  border-radius: 50%;
}
.welcome-banner h2 {
  margin: 8px 0 10px;
  font-size: 28px;
  letter-spacing: 0.5px;
}
.welcome-banner p {
  margin: 0;
  color: rgba(232, 247, 255, 0.78);
}
.welcome-kicker {
  color: #8ed8f7;
  font-size: 10px;
  font-weight: 700;
  letter-spacing: 2px;
}
.welcome-summary {
  z-index: 1;
  display: flex;
  align-items: stretch;
  border: 1px solid rgba(255, 255, 255, 0.22);
  border-radius: 14px;
  background: rgba(255, 255, 255, 0.1);
  backdrop-filter: blur(6px);
}
.welcome-summary div { min-width: 108px; padding: 15px 18px; text-align: center; }
.welcome-summary div + div { border-left: 1px solid rgba(255, 255, 255, .16); }
.welcome-summary strong, .welcome-summary span { display: block; }
.welcome-summary strong { font-size: 24px; }
.welcome-summary span { margin-top: 4px; color: rgba(232, 247, 255, .72); font-size: 11px; }
.card-title { display: flex; align-items: center; justify-content: space-between; gap: 20px; }
.card-title small { color: #8a9ba8; font-weight: 400; }
.dashboard-grid {
  display: grid;
  grid-template-columns: minmax(0, 1.05fr) minmax(0, .95fr);
  gap: 20px;
}
.dashboard-section {
  margin-top: 20px;
}
.integrity-title {
  color: #909399;
  font-size: 13px;
}
.integrity-value {
  color: #303133;
  font-size: 26px;
  font-weight: bold;
}
.integrity-list { display: grid; gap: 12px; }
.integrity-card {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 16px;
  padding: 16px 18px;
  border: 1px solid #dcdfe6;
  border-radius: 10px;
  background: #f0f9eb;
}
.integrity-card.abnormal {
  background: #fef0f0;
  border-color: #fab6b6;
}
.integrity-value {
  flex: 0 0 auto;
}
.chart {
  width: 100%;
  height: 400px;
}
.compact-chart { height: 360px; }
.audit-card :deep(.el-card__body) {
  padding-top: 10px;
}
.risk-overview { display: grid; grid-template-columns: repeat(5, 1fr); gap: 14px; margin: 20px 0; }
.risk-card { min-height: 112px; display: flex; align-items: center; gap: 13px; padding: 18px; border: 1px solid #e2ebf2; border-radius: 12px; background: #fff; box-shadow: 0 6px 20px rgba(14, 70, 111, .06); transition: transform .2s ease, box-shadow .2s ease; }
.risk-card:hover { transform: translateY(-3px); box-shadow: 0 12px 28px rgba(14, 70, 111, .11); }
.risk-symbol { flex: 0 0 38px; height: 38px; display: grid; place-items: center; border-radius: 10px; background: #edf5fb; color: #1677c8; font-size: 13px; font-weight: 700; }
.risk-card span, .risk-card strong, .risk-card small { display: block; }
.risk-card span { color: #60798d; font-size: 13px; }
.risk-card strong { margin: 5px 0 3px; color: #193e5a; font-size: 24px; }
.risk-card small { color: #93a4b1; font-size: 10px; }
.risk-card.danger .risk-symbol { color: #d94b4b; background: #fff0f0; }
.risk-card.warning .risk-symbol { color: #c98218; background: #fff6e8; }
.risk-card.success .risk-symbol { color: #399a66; background: #edf9f2; }
@media (max-width: 1280px) { .risk-overview { grid-template-columns: repeat(3, 1fr); } }
.audit-toolbar { display: grid; grid-template-columns: 1fr 1fr auto auto; gap: 8px; margin-bottom: 12px; }
@media (max-width: 1200px) {
  .dashboard-grid { grid-template-columns: 1fr; }
  .welcome-summary div { min-width: 92px; padding: 13px; }
}
</style>
