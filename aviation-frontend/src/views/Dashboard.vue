<template>
  <div class="dashboard-container">
    <section class="welcome-banner">
      <div>
        <span class="welcome-kicker">OPERATIONS OVERVIEW</span>
        <h2>航空维修运行总览</h2>
        <p>实时查看部件寿命风险、维修计划、审计日志与数据库健康状态</p>
      </div>
      <div class="welcome-summary">
        <div><strong>{{ summaryLoaded ? summaryData.aircraftCount : '--' }}</strong><span>在役飞机</span></div>
        <div><strong>{{ summaryLoaded ? summaryData.stockCount : '--' }}</strong><span>库存部件</span></div>
        <div><strong>{{ summaryLoaded ? summaryData.maintenanceCount : '--' }}</strong><span>维修工单</span></div>
      </div>
    </section>

    <section class="risk-overview">
      <article v-for="item in riskCards" :key="item.key" class="risk-card" :class="item.tone">
        <div class="risk-symbol">{{ item.symbol }}</div>
        <div><span>{{ item.label }}</span><strong>{{ item.loaded ? item.value : '未加载' }}</strong><small>{{ item.description }}</small></div>
      </article>
    </section>

    <el-card class="dashboard-section analysis-overview" shadow="never">
      <template #header><div class="card-title"><div><span>数据库深度分析</span><small>由三类统计视图提供</small></div><el-button type="primary" link @click="openAnalysis">查看分析详情 →</el-button></div></template>
      <div class="analysis-cards">
        <article class="analysis-card"><span>维修周期关注部件</span><strong>{{ analysisLoaded.due ? maintenanceDueCount : '--' }}</strong><small>维修预警、即将到期及已逾期</small></article>
        <article class="analysis-card"><span>最高位置更换次数</span><strong>{{ analysisLoaded.replacement ? topReplacementCount : '--' }}</strong><small>{{ analysisLoaded.replacement ? topReplacementLabel : '按飞机与安装位置汇总' }}</small></article>
        <article class="analysis-card"><span>平均维修间隔</span><strong>{{ analysisLoaded.interval ? `${averageMaintenanceInterval}h` : '--' }}</strong><small>相邻维修之间的自然时间</small></article>
      </div>
    </el-card>

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
          <el-select v-model="auditFilters.operationType" clearable placeholder="全部操作类型"><el-option label="部件更换" value="replace_component" /><el-option label="部件退役" value="retire_component" /><el-option label="完成维修" value="complete_maintenance" /><el-option label="创建维修计划" value="create_maintenance_plan" /><el-option label="开始执行维修计划" value="start_maintenance_plan" /><el-option label="完成维修计划" value="complete_maintenance_plan" /><el-option label="取消维修计划" value="cancel_maintenance_plan" /><el-option label="寿命到限停场" value="life_limit_grounding" /><el-option label="维修到期停场" value="maintenance_cycle_grounding" /><el-option label="维修放行" value="maintenance_cycle_release" /></el-select>
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

    <el-drawer v-model="analysisDialogVisible" title="数据库分析详情" size="72%" v-loading="analysisRefreshing" element-loading-text="正在同步最新分析数据...">
      <el-tabs v-model="analysisTab">
        <el-tab-pane label="维修周期预警" name="due">
          <el-alert class="metric-note" title="这里判断的是定期维修是否到期，不是部件设计寿命到期。维修后飞行小时从最近一次通过维修后重新累计；部件档案中的已用小时是全生命周期累计值。" type="info" :closable="false" show-icon />
          <el-table :data="maintenanceDueData" border max-height="520">
            <el-table-column prop="component_no" label="部件编号" /><el-table-column prop="model_code" label="型号" />
            <el-table-column prop="maintenance_cycle_hours" label="维修周期(h)" /><el-table-column prop="hours_since_last_maintenance" label="维修后飞行(h)" />
            <el-table-column label="周期余量" min-width="125"><template #default="scope"><span :class="{ 'overdue-text': Number(scope.row.hours_since_last_maintenance) > Number(scope.row.maintenance_cycle_hours) }">{{ formatMaintenanceBalance(scope.row) }}</span></template></el-table-column>
            <el-table-column label="周期使用率" min-width="165"><template #default="scope"><el-progress :percentage="toPercentage(scope.row.maintenance_usage_ratio)" :status="scope.row.maintenance_due_level === 'overdue' ? 'exception' : undefined" :format="() => formatUsageRatio(scope.row.maintenance_usage_ratio)" /></template></el-table-column>
            <el-table-column label="维修周期状态" min-width="115"><template #default="scope"><el-tag :type="getDueType(scope.row.maintenance_due_level)">{{ formatDueLevel(scope.row.maintenance_due_level) }}</el-tag></template></el-table-column>
            <template #empty><el-empty description="暂无周期维修分析数据" /></template>
          </el-table>
        </el-tab-pane>
        <el-tab-pane label="飞机部件更换频率" name="replacement">
          <el-alert class="metric-note" title="统计口径：按飞机与安装位置汇总历史安装、拆卸和更换次数，不代表单个部件的生命周期事件数。" type="info" :closable="false" show-icon />
          <div ref="replacementAnalysisChartRef" class="analysis-chart"></div>
          <el-table :data="replacementStats" border max-height="520">
            <el-table-column prop="aircraft_no" label="飞机编号" /><el-table-column prop="aircraft_model" label="机型" /><el-table-column label="安装位置" min-width="150"><template #default="scope">{{ formatInstallPosition(scope.row.install_position) }}</template></el-table-column>
            <el-table-column prop="installation_count" label="累计安装" /><el-table-column prop="removal_count" label="拆卸次数" /><el-table-column prop="replacement_count" label="更换次数" />
            <template #empty><el-empty description="暂无更换频率数据" /></template>
          </el-table>
        </el-tab-pane>
        <el-tab-pane label="部件维修间隔" name="interval">
          <el-alert class="metric-note" title="统计口径：维修间隔是上一次维修结束到下一次维修开始之间的自然时间，不是部件飞行小时。" type="info" :closable="false" show-icon />
          <div class="analysis-summary">总体平均维修间隔：<strong>{{ averageMaintenanceInterval }} 小时</strong></div>
          <div ref="intervalAnalysisChartRef" class="analysis-chart"></div>
          <el-table :data="maintenanceIntervals" border max-height="520">
            <el-table-column prop="component_no" label="部件编号" /><el-table-column prop="model_code" label="型号" /><el-table-column label="维修类型"><template #default="scope">{{ formatMaintenanceType(scope.row.maintenance_type) }}</template></el-table-column>
            <el-table-column label="本次结束"><template #default="scope">{{ formatTime(scope.row.end_time) }}</template></el-table-column><el-table-column prop="maintenance_interval_hours" label="间隔(h)" />
            <template #empty><el-empty description="暂无可计算的维修间隔" /></template>
          </el-table>
        </el-tab-pane>
      </el-tabs>
    </el-drawer>
  </div>
</template>

<script setup>
import { computed, nextTick, onMounted, onUnmounted, reactive, ref, watch } from 'vue'
import * as echarts from 'echarts'
import { getRecentAuditLogs } from '../api/auditLogs'
import {
  formatAuditDetail,
  formatAuditOperationType,
  formatComponentCategory,
  formatInstallPosition,
  formatMaintenanceType,
  formatRetirementReason,
  formatWarningLevel,
  getWarningStatusType
} from '../utils/businessFormatters'
import { getAllMaintenances, getMaintenancePlans } from '../api/maintenances'
import {
  getAircraftComponentReplacements,
  getComponentLifeWarning,
  getComponentMaintenanceDue,
  getComponentMaintenanceInterval,
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
const normalizeAuditOperationType = (value) => ({
  component_replacement: 'replace_component',
  component_retirement: 'retire_component',
  maintenance_completion: 'complete_maintenance',
  maintenance_plan_created: 'create_maintenance_plan',
  create_maintenance_plan: 'create_maintenance_plan',
  maintenance_plan_started: 'start_maintenance_plan',
  maintenance_plan_completed: 'complete_maintenance_plan',
  maintenance_plan_cancelled: 'cancel_maintenance_plan'
}[value] || value)
const filteredAuditLogs = computed(() => recentAuditLogs.value.filter(item =>
  (!auditFilters.operationType || normalizeAuditOperationType(item.operation_type) === auditFilters.operationType)
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
    { key: 'critical', label: '严重寿命风险', value: lifeWarningData.value.filter(item => ['critical', 'expired'].includes(item.warning_level)).length, loaded: lifeWarningLoaded.value, tone: 'danger', symbol: '!' , description: '严重预警或已经达到寿命上限' },
    { key: 'warning', label: '预警部件', value: lifeWarningData.value.filter(item => item.warning_level === 'warning').length, loaded: lifeWarningLoaded.value, tone: 'warning', symbol: '△', description: '需要关注剩余寿命' },
    { key: 'maintenance', label: '维修中部件', value: maintenanceComponentCount.value, loaded: componentRiskLoaded.value, tone: 'primary', symbol: 'M', description: '存在待完成维修工单' },
    { key: 'plans', label: '待执行维修计划', value: pendingPlanCount.value, loaded: maintenancePlanLoaded.value, tone: 'warning', symbol: 'P', description: '等待安排执行' },
    { key: 'database', label: '数据库异常数', value: databaseIssueCount, loaded: integrityLoaded.value, tone: databaseIssueCount > 0 ? 'danger' : 'success', symbol: 'DB', description: '一致性规则检查汇总' }
  ]
})
const summaryLoaded = ref(false)
const maintenanceDueData = ref([])
const replacementStats = ref([])
const maintenanceIntervals = ref([])
const analysisLoaded = reactive({ due: false, replacement: false, interval: false })
const analysisDialogVisible = ref(false)
const analysisTab = ref('due')
const analysisRefreshing = ref(false)
const maintenanceDueCount = computed(() => maintenanceDueData.value.filter(item => ['warning', 'due', 'overdue'].includes(item.maintenance_due_level)).length)
const topReplacementCount = computed(() => Math.max(0, ...replacementStats.value.map(item => Number(item.replacement_count) || 0)))
const topReplacementLabel = computed(() => {
  const row = [...replacementStats.value].sort((a, b) => Number(b.replacement_count) - Number(a.replacement_count))[0]
  return row ? `${row.aircraft_no} · ${formatInstallPosition(row.install_position)}` : '暂无更换记录'
})
const averageMaintenanceInterval = computed(() => {
  const values = maintenanceIntervals.value.map(item => Number(item.maintenance_interval_hours)).filter(Number.isFinite)
  return values.length ? Math.round(values.reduce((sum, value) => sum + value, 0) / values.length) : 0
})

const maintenanceChartRef = ref(null)
const retirementChartRef = ref(null)
const replacementAnalysisChartRef = ref(null)
const intervalAnalysisChartRef = ref(null)
let maintenanceChart = null
let retirementChart = null
let replacementAnalysisChart = null
let intervalAnalysisChart = null

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

const initReplacementAnalysisChart = () => {
  if (!replacementAnalysisChartRef.value) return
  replacementAnalysisChart ||= echarts.init(replacementAnalysisChartRef.value)
  const rows = [...replacementStats.value].sort((a, b) => Number(b.replacement_count) - Number(a.replacement_count)).slice(0, 8).reverse()
  replacementAnalysisChart.setOption({
    title: { text: '高频更换位置 Top 8', left: 'center' },
    tooltip: { trigger: 'axis' },
    grid: { left: 170, right: 35, top: 50, bottom: 25 },
    xAxis: { type: 'value', name: '更换次数', minInterval: 1 },
    yAxis: { type: 'category', data: rows.map(item => `${item.aircraft_no} · ${formatInstallPosition(item.install_position)}`) },
    series: [{ type: 'bar', data: rows.map(item => Number(item.replacement_count) || 0), itemStyle: { color: '#2587c8', borderRadius: [0, 5, 5, 0] }, label: { show: true, position: 'right' } }]
  }, true)
}

const initIntervalAnalysisChart = () => {
  if (!intervalAnalysisChartRef.value) return
  intervalAnalysisChart ||= echarts.init(intervalAnalysisChartRef.value)
  const groups = new Map()
  maintenanceIntervals.value.forEach(item => {
    const value = Number(item.maintenance_interval_hours)
    if (!Number.isFinite(value)) return
    const values = groups.get(item.model_code) || []
    values.push(value)
    groups.set(item.model_code, values)
  })
  const rows = [...groups.entries()].map(([model, values]) => ({ model, average: Math.round(values.reduce((sum, value) => sum + value, 0) / values.length) }))
  intervalAnalysisChart.setOption({
    title: { text: '各型号平均维修间隔', left: 'center' },
    tooltip: { trigger: 'axis' },
    grid: { left: 55, right: 25, top: 50, bottom: 55 },
    xAxis: { type: 'category', data: rows.map(item => item.model), axisLabel: { rotate: 25 } },
    yAxis: { type: 'value', name: '小时' },
    series: [{ type: 'bar', data: rows.map(item => item.average), itemStyle: { color: '#45a879', borderRadius: [5, 5, 0, 0] }, label: { show: true, position: 'top' } }]
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
  summaryLoaded.value = true
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
  const [maintenancesResult, plansResult] = await Promise.allSettled([getAllMaintenances(), getMaintenancePlans()])
  if (maintenancesResult.status === 'fulfilled') {
    const rows = maintenancesResult.value?.data || maintenancesResult.value || []
    const componentNos = (Array.isArray(rows) ? rows : [])
      .filter(item => item.result === 'pending')
      .map(item => item.component_no)
      .filter(Boolean)
    maintenanceComponentCount.value = new Set(componentNos).size
    componentRiskLoaded.value = true
  }
  if (plansResult.status === 'fulfilled') {
    const rows = plansResult.value?.data || plansResult.value || []
    pendingPlanCount.value = (Array.isArray(rows) ? rows : [])
      .filter(item => item.status === 'pending' && !item.related_maintenance_id).length
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

const fetchDatabaseAnalytics = async () => {
  const results = await Promise.allSettled([
    getComponentMaintenanceDue(),
    getAircraftComponentReplacements(),
    getComponentMaintenanceInterval()
  ])
  const targets = [maintenanceDueData, replacementStats, maintenanceIntervals]
  const keys = ['due', 'replacement', 'interval']
  results.forEach((result, index) => {
    if (result.status === 'fulfilled') {
      targets[index].value = Array.isArray(result.value) ? result.value : []
      analysisLoaded[keys[index]] = true
    } else {
      targets[index].value = []
      analysisLoaded[keys[index]] = false
    }
  })
}

const openAnalysis = async () => {
  analysisTab.value = 'due'
  analysisDialogVisible.value = true
  analysisRefreshing.value = true
  try {
    await fetchDatabaseAnalytics()
  } finally {
    analysisRefreshing.value = false
  }
}

watch([analysisDialogVisible, analysisTab], async ([visible, tab]) => {
  if (!visible) return
  await nextTick()
  if (tab === 'replacement') initReplacementAnalysisChart()
  if (tab === 'interval') initIntervalAnalysisChart()
})

const getIntegrityCount = (key) => Number(integrityChecks.value[key]) || 0
const formatHours = (value) => Number(value || 0).toFixed(2)
const toPercentage = (ratio) => Math.min(100, Math.max(0, Number((Number(ratio || 0) * 100).toFixed(1))))

const translateWarningLevel = formatWarningLevel
const getWarningTagType = getWarningStatusType

const getWarningColor = (level) => ({
  normal: '#67C23A',
  warning: '#E6A23C',
    critical: '#F56C6C',
    expired: '#C45656'
}[level] || '#909399')

const formatTime = (value) => value ? String(value).replace('T', ' ').slice(0, 19) : '-'
const formatUsageRatio = (ratio) => `${Math.max(0, Number(ratio || 0) * 100).toFixed(1)}%`
const formatMaintenanceBalance = (row) => {
  const cycle = Number(row.maintenance_cycle_hours) || 0
  const used = Number(row.hours_since_last_maintenance) || 0
  const difference = cycle - used
  return difference >= 0 ? `剩余 ${difference.toFixed(2)} h` : `已超期 ${Math.abs(difference).toFixed(2)} h`
}
const formatDueLevel = (value) => ({ normal: '维修正常', warning: '维修预警', due: '维修即将到期', overdue: '维修已逾期' }[value] || value)
const getDueType = (value) => ({ normal: 'success', warning: 'warning', due: 'warning', overdue: 'danger' }[value] || 'info')

const handleResize = () => {
  maintenanceChart?.resize()
  retirementChart?.resize()
  replacementAnalysisChart?.resize()
  intervalAnalysisChart?.resize()
}

onMounted(() => {
  Promise.allSettled([
    fetchSummaryData(),
    fetchMaintenanceStats(),
    fetchLifeWarnings(),
    fetchRetirementReasons(),
    fetchIntegrityChecks(),
    fetchRecentAuditLogs(),
    fetchOperationalRisks(),
    fetchDatabaseAnalytics()
  ])
  window.addEventListener('resize', handleResize)
})

onUnmounted(() => {
  window.removeEventListener('resize', handleResize)
  maintenanceChart?.dispose()
  retirementChart?.dispose()
  replacementAnalysisChart?.dispose()
  intervalAnalysisChart?.dispose()
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
.analysis-cards { display: grid; grid-template-columns: repeat(3, 1fr); gap: 14px; }
.analysis-card { padding: 16px 18px; border: 1px solid #dfeaf2; border-radius: 11px; background: linear-gradient(135deg, #f8fcff, #eef7fd); color: #34566d; text-align: left; }
.analysis-card span, .analysis-card strong, .analysis-card small { display: block; }
.analysis-card strong { margin: 7px 0 4px; color: #146fa9; font-size: 24px; }
.analysis-card small { color: #879aa8; }
.analysis-chart { width: 100%; height: 300px; margin-bottom: 18px; }
.analysis-summary { margin-bottom: 12px; padding: 12px 16px; border-radius: 8px; background: #f0f7fc; color: #54748a; }
.metric-note { margin-bottom: 16px; }
.overdue-text { color: #f56c6c; font-weight: 600; }
.analysis-summary strong { color: #146fa9; }
.card-title > div span, .card-title > div small { display: block; }
@media (max-width: 1280px) { .risk-overview { grid-template-columns: repeat(3, 1fr); } }
.audit-toolbar { display: grid; grid-template-columns: 1fr 1fr auto auto; gap: 8px; margin-bottom: 12px; }
@media (max-width: 1200px) {
  .dashboard-grid { grid-template-columns: 1fr; }
  .analysis-cards { grid-template-columns: 1fr; }
  .welcome-summary div { min-width: 92px; padding: 13px; }
}
</style>
