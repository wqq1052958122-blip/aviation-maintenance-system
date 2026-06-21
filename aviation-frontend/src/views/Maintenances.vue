<template>
  <div class="app-container">
    <div class="page-header">
      <div><h2>维修管理</h2><p>管理维修记录、维修计划与执行状态</p></div>
      <el-button type="primary" @click="openCreateDialog">新增维修工单</el-button>
    </div>

    <div class="section-header">
      <div>
        <h3>维修工单与执行记录</h3>
        <p>记录已经开始或完成的实际维修过程与维修结论</p>
      </div>
    </div>

    <div class="filter-panel">
      <el-form class="filter-form" inline>
        <el-form-item label="部件编号"><el-input v-model="searchComponentNo" clearable placeholder="输入部件编号" style="width: 170px" @keyup.enter="handleSearch" /></el-form-item>
        <el-form-item label="维修类型"><el-select v-model="maintenanceFilters.type" clearable placeholder="全部类型" style="width: 150px"><el-option label="常规检查" value="routine" /><el-option label="故障维修" value="fault repair" /><el-option label="维修" value="repair" /><el-option label="深度大修" value="overhaul" /><el-option label="在线检查" value="online inspection" /><el-option label="计划检查" value="scheduled inspection" /><el-option label="更换检查" value="replacement check" /></el-select></el-form-item>
        <el-form-item label="维修结果"><el-select v-model="maintenanceFilters.result" clearable placeholder="全部结果" style="width: 140px"><el-option label="待处理" value="pending" /><el-option label="通过" value="passed" /><el-option label="未通过" value="failed" /><el-option label="报废" value="scrapped" /></el-select></el-form-item>
        <el-form-item label="日期范围"><el-date-picker v-model="maintenanceFilters.dateRange" type="daterange" value-format="YYYY-MM-DD" start-placeholder="开始日期" end-placeholder="结束日期" /></el-form-item>
        <el-form-item><div class="filter-actions"><el-button type="primary" @click="handleSearch">搜索</el-button><el-button @click="resetMaintenanceFilters">重置</el-button><el-button @click="fetchAllList">刷新</el-button></div></el-form-item>
      </el-form>
    </div>

    <el-table :data="pagedRecords" border style="width: 100%" v-loading="loading" element-loading-text="正在加载数据...">
      <el-table-column prop="maintenance_id" label="工单号" width="80" />

  <el-table-column prop="component_no" label="维修部件编号" width="150" />
      <el-table-column label="维修类型">
        <template #default="scope">{{ formatMaintenanceType(scope.row.maintenance_type) }}</template>
      </el-table-column>
      <el-table-column prop="start_time" label="开始时间" width="160">
        <template #default="scope">
          {{ scope.row.start_time ? scope.row.start_time.replace('T', ' ') : '' }}
        </template>
      </el-table-column>

      <el-table-column prop="end_time" label="结束时间" width="160">
        <template #default="scope">
          {{ scope.row.end_time ? scope.row.end_time.replace('T', ' ') : '正在维修中...' }}
        </template>
      </el-table-column>
      <el-table-column prop="technician_name" label="维修人员" />

      <el-table-column label="状态" width="100">
        <template #default="scope">
          <el-tag :type="getMaintenanceResultType(scope.row.result)">
            {{ formatMaintenanceResult(scope.row.result) }}
          </el-tag>
        </template>
      </el-table-column>
      <el-table-column label="操作" width="150">
        <template #default="scope">
          <el-button
            v-if="scope.row.result === 'pending'"
            type="primary"
            size="small"
            @click="openCompleteDialog(scope.row)">
            完成维修
          </el-button>
        </template>
      </el-table-column>
      <template #empty><el-empty description="暂无数据" /></template>
    </el-table>
    <ListPagination v-model:page="maintenancePage" v-model:page-size="maintenancePageSize" :total="filteredRecords.length" />

    <el-divider />

    <div class="section-header">
      <div>
        <h3>维修计划与待办</h3>
        <p>安排未来维修任务，计划完成不等同于维修工单完成</p>
      </div>
      <div class="section-actions">
        <el-select v-model="planActionOperatorId" clearable placeholder="取消操作人员" style="width: 180px">
          <el-option v-for="op in operatorList" :key="op.operator_id" :label="op.operator_name" :value="op.operator_id" />
        </el-select>
        <el-button type="primary" @click="openPlanDialog">新增维修计划</el-button>
      </div>
    </div>

    <div class="filter-panel">
      <el-form class="filter-form" inline>
        <el-form-item label="部件编号"><el-input v-model="planFilters.componentNo" clearable placeholder="输入部件编号" style="width: 170px" /></el-form-item>
        <el-form-item label="计划状态"><el-select v-model="planFilters.status" clearable placeholder="全部状态" style="width: 140px"><el-option label="待执行" value="pending" /><el-option label="已完成" value="completed" /><el-option label="已取消" value="cancelled" /></el-select></el-form-item>
        <el-form-item label="计划类型"><el-select v-model="planFilters.type" clearable placeholder="全部类型" style="width: 160px"><el-option label="计划检查" value="scheduled_inspection" /><el-option label="预防性维修" value="preventive_maintenance" /><el-option label="寿命限制检查" value="life_limit_check" /><el-option label="更换后检查" value="post_replacement_check" /><el-option label="在线检查" value="online inspection" /><el-option label="例行检查" value="routine inspection" /><el-option label="计划维修" value="scheduled maintenance" /><el-option label="维修" value="repair" /><el-option label="更换检查" value="replacement check" /><el-option label="寿命预警检查" value="life warning inspection" /></el-select></el-form-item>
        <el-form-item label="计划时间"><el-date-picker v-model="planFilters.dateRange" type="daterange" value-format="YYYY-MM-DD" start-placeholder="开始日期" end-placeholder="结束日期" /></el-form-item>
        <el-form-item><div class="filter-actions"><el-button type="primary" @click="applyPlanFilters">搜索</el-button><el-button @click="resetPlanFilters">重置</el-button><el-button @click="fetchPlanList">刷新</el-button></div></el-form-item>
      </el-form>
    </div>

    <el-alert
      v-if="planLoadFailed"
      title="维修计划加载失败"
      type="error"
      :closable="false"
      show-icon
      style="margin-bottom: 12px;"
    />
    <el-table v-else :data="pagedPlans" border style="width: 100%" v-loading="planLoading" element-loading-text="正在加载数据...">
      <el-table-column prop="component_no" label="部件编号" min-width="110" />
      <el-table-column label="计划类型" min-width="120">
        <template #default="scope">{{ formatPlanType(scope.row.planned_type) }}</template>
      </el-table-column>
      <el-table-column label="计划时间" min-width="160">
        <template #default="scope">{{ formatTime(scope.row.planned_time) }}</template>
      </el-table-column>
      <el-table-column label="计划原因" min-width="180" show-overflow-tooltip>
        <template #default="scope">{{ formatBusinessText(scope.row.planned_reason) }}</template>
      </el-table-column>
      <el-table-column label="状态" min-width="90">
        <template #default="scope">
          <el-tag :type="scope.row.status === 'pending' && scope.row.related_maintenance_id ? 'primary' : getPlanStatusType(scope.row.status)">
            {{ scope.row.status === 'pending' && scope.row.related_maintenance_id ? '执行中' : formatPlanStatus(scope.row.status) }}
          </el-tag>
        </template>
      </el-table-column>
      <el-table-column label="关联工单" min-width="105">
        <template #default="scope">
          {{ scope.row.related_maintenance_id ? `#${scope.row.related_maintenance_id}` : '尚未开始' }}
        </template>
      </el-table-column>
      <el-table-column label="创建人" min-width="110">
        <template #default="scope">{{ scope.row.created_by_name || '未记录' }}</template>
      </el-table-column>
      <el-table-column label="创建时间" min-width="160">
        <template #default="scope">{{ formatTime(scope.row.created_at) }}</template>
      </el-table-column>
      <el-table-column label="操作" width="190" fixed="right">
        <template #default="scope">
          <template v-if="scope.row.status === 'pending' && !scope.row.related_maintenance_id">
            <el-button type="primary" link @click="openStartPlanDialog(scope.row)">开始执行</el-button>
            <el-button type="danger" link @click="handleCancelPlan(scope.row)">取消</el-button>
          </template>
          <span v-else-if="scope.row.status === 'pending'">等待工单完成</span>
          <span v-else>-</span>
        </template>
      </el-table-column>
      <template #empty>
        <el-empty description="暂无维修计划" />
      </template>
    </el-table>
    <ListPagination v-if="!planLoadFailed" v-model:page="planPage" v-model:page-size="planPageSize" :total="filteredPlans.length" />


    <el-dialog title="开始执行维修计划" v-model="startPlanVisible" width="500px">
      <el-form :model="startPlanForm" label-width="110px">
        <div class="form-section-title">计划执行信息</div>
        <el-form-item label="部件编号">
          <el-input :model-value="startPlanForm.component_no" disabled />
        </el-form-item>
        <el-form-item label="维修类型">
          <el-input :model-value="formatPlanType(startPlanForm.planned_type)" disabled />
        </el-form-item>
        <el-form-item label="维修技师" required>
          <el-select v-model="startPlanForm.technician_id" placeholder="请选择维修技师" style="width: 100%">
            <el-option
              v-for="op in operatorList.filter(o => o.role === 'technician')"
              :key="op.operator_id"
              :label="op.operator_name + '（' + translateRole(op.role) + '）'"
              :value="op.operator_id"
            />
          </el-select>
        </el-form-item>
        <el-form-item label="开始时间" required>
          <el-date-picker
            v-model="startPlanForm.start_time"
            type="datetime"
            value-format="YYYY-MM-DD HH:mm:ss"
            placeholder="请选择实际开始时间"
            style="width: 100%"
          />
        </el-form-item>
        <el-form-item label="执行说明">
          <el-input v-model="startPlanForm.description" type="textarea" placeholder="填写本次执行说明" />
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="startPlanVisible = false">取消</el-button>
        <el-button type="primary" :loading="planSubmitting" @click="submitStartPlan">创建维修工单</el-button>
      </template>
    </el-dialog>


    <el-dialog title="新增维修计划" v-model="planDialogVisible" width="520px">
      <el-form :model="planForm" label-width="130px">
        <div class="form-section-title">计划对象与类型</div>
        <el-form-item label="部件编号" required>
          <el-input v-model="planForm.component_no" placeholder="如 ENG-003" />
        </el-form-item>
        <el-form-item label="计划类型" required>
          <el-select v-model="planForm.planned_type" placeholder="请选择计划类型" style="width: 100%">
            <el-option label="在线检查" value="online inspection" />
            <el-option label="例行检查" value="routine inspection" />
            <el-option label="计划检查" value="scheduled inspection" />
            <el-option label="计划维修" value="scheduled maintenance" />
            <el-option label="维修" value="repair" />
            <el-option label="更换检查" value="replacement check" />
            <el-option label="寿命预警检查" value="life warning inspection" />
          </el-select>
        </el-form-item>
        <div class="form-section-title">执行安排</div>
        <el-form-item label="计划时间" required>
          <el-date-picker
            v-model="planForm.planned_time"
            type="datetime"
            value-format="YYYY-MM-DD HH:mm:ss"
            placeholder="请选择计划执行时间"
            style="width: 100%"
          />
        </el-form-item>
        <el-form-item label="计划原因">
          <el-input v-model="planForm.planned_reason" type="textarea" placeholder="填写计划原因" />
        </el-form-item>
        <div class="form-section-title">责任信息</div>
        <el-form-item label="创建人" required>
          <el-select v-model="planForm.created_by" clearable placeholder="请选择创建人" style="width: 100%">
            <el-option
              v-for="op in operatorList"
              :key="op.operator_id"
              :label="op.operator_name + '（' + translateRole(op.role) + '）'"
              :value="op.operator_id"
            />
          </el-select>
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="planDialogVisible = false">取消</el-button>
        <el-button type="primary" :loading="planSubmitting" @click="submitPlan">提交</el-button>
      </template>
    </el-dialog>


    <el-dialog title="新增维修工单" v-model="createVisible" width="500px">
      <el-form :model="createForm" label-width="100px">
        <el-form-item label="部件编号" required>
          <el-input v-model="createForm.component_no" placeholder="输入需要维修的部件编号" />
        </el-form-item>
        <el-form-item label="维修类型" required>
          <el-select v-model="createForm.maintenance_type" style="width: 100%">
            <el-option label="常规检查" value="routine" />
            <el-option label="故障维修" value="repair" />
            <el-option label="深度大修" value="overhaul" />
          </el-select>
        </el-form-item>
        <el-form-item label="负责人员" required>
          <el-select v-model="createForm.technician_id" placeholder="请选择维修人员" style="width: 100%">
            <el-option
              v-for="op in operatorList.filter(o => o.role === 'technician')"
              :key="op.operator_id"
              :label="op.operator_name + '（' + translateRole(op.role) + '）'"
              :value="op.operator_id"
            />
          </el-select>
        </el-form-item>

        <el-form-item label="开始时间" required>
          <el-date-picker
            v-model="createForm.start_time"
            type="datetime"
            value-format="YYYY-MM-DD HH:mm:ss"
            placeholder="请确认维修开始时间"
            style="width: 100%"
          />
        </el-form-item>
        <el-form-item label="问题描述">
          <el-input v-model="createForm.description" type="textarea" />
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="createVisible = false">取消</el-button>
        <el-button type="primary" :loading="maintenanceSubmitting" @click="submitCreate">提交</el-button>
      </template>
    </el-dialog>

    <el-dialog title="提报维修结果" v-model="completeVisible" width="500px">
      <el-form :model="completeForm" label-width="100px">
        <el-form-item label="检验结果" required>
          <el-select v-model="completeForm.result" style="width: 100%">
            <el-option label="检验通过" value="passed" />
            <el-option label="检验未通过（进入返修流程）" value="failed" />
            <el-option label="确认报废（安装中部件须先拆卸）" value="scrapped" />
          </el-select>
        </el-form-item>
        <el-form-item label="维修总结">
          <el-input v-model="completeForm.description" type="textarea" />
        </el-form-item>
        <el-form-item v-if="completeForm.result === 'scrapped'" label="退役原因" required>
          <el-input v-model="completeForm.retirement_reason" type="textarea" placeholder="请填写报废退役原因" />
        </el-form-item>
        <el-form-item label="审批人员" required>
          <el-select v-model="completeForm.approved_by" placeholder="请选择验收审批人" style="width: 100%">
            <el-option
              v-for="op in operatorList.filter(o => o.role === 'approver')"
              :key="op.operator_id"
              :label="op.operator_name + '（' + translateRole(op.role) + '）'"
              :value="op.operator_id"
            />
          </el-select>
        </el-form-item>

        <el-form-item label="结束时间" required>
          <el-date-picker
            v-model="completeForm.end_time"
            type="datetime"
            value-format="YYYY-MM-DD HH:mm:ss"
            placeholder="请确认维修结束时间"
            style="width: 100%"
          />
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="completeVisible = false">取消</el-button>
        <el-button type="primary" :loading="maintenanceSubmitting" @click="submitComplete">提交</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<script setup>
import { computed, reactive, ref, onMounted, watch } from 'vue'
// 确保你引入了下面这两个接口
import {
  getAllMaintenances,
  getComponentMaintenances,
  createMaintenance,
  completeMaintenance,
  getMaintenancePlans,
  createMaintenancePlan,
  startMaintenancePlan,
  cancelMaintenancePlan
} from '../api/maintenances'
import { getOperators } from '../api/operators' // 引入获取人员的接口
import { ElMessage, ElMessageBox } from 'element-plus'
import {
  formatBusinessText,
  formatMaintenanceResult,
  formatMaintenanceType,
  getMaintenanceResultType,
  getPlanStatusType,
  formatPlanStatus,
  formatPlanType
} from '../utils/businessFormatters'
import { formatLocalDateTime } from '../utils/dateTime'
import ListPagination from '../components/ListPagination.vue'

const operatorList = ref([]) // 存储从后端拉取的人员名单
const records = ref([])
const searchComponentNo = ref('')
const loading = ref(false)
const maintenanceSubmitting = ref(false)
const planList = ref([])
const planActionOperatorId = ref(null)
const planLoading = ref(false)
const planLoadFailed = ref(false)
const planSubmitting = ref(false)
const maintenanceFilters = reactive({ type: '', result: '', dateRange: [] })
const planFilters = reactive({ componentNo: '', status: '', type: '', dateRange: [] })
const appliedPlanFilters = reactive({ ...planFilters })
const maintenancePage = ref(1)
const maintenancePageSize = ref(10)
const planPage = ref(1)
const planPageSize = ref(10)
const inDateRange = (value, range) => {
  if (!range?.length) return true
  const date = String(value || '').slice(0, 10)
  return date >= range[0] && date <= range[1]
}
const filteredRecords = computed(() => records.value.filter(item =>
  String(item.component_no || '').toLowerCase().includes(searchComponentNo.value.trim().toLowerCase())
  && (!maintenanceFilters.type || item.maintenance_type === maintenanceFilters.type)
  && (!maintenanceFilters.result || item.result === maintenanceFilters.result)
  && inDateRange(item.start_time, maintenanceFilters.dateRange)
))
const pagedRecords = computed(() => {
  const start = (maintenancePage.value - 1) * maintenancePageSize.value
  return filteredRecords.value.slice(start, start + maintenancePageSize.value)
})
watch(() => filteredRecords.value.length, total => {
  maintenancePage.value = Math.min(maintenancePage.value, Math.max(1, Math.ceil(total / maintenancePageSize.value)))
})
const filteredPlans = computed(() => planList.value.filter(item =>
  String(item.component_no || '').toLowerCase().includes(appliedPlanFilters.componentNo.trim().toLowerCase())
  && (!appliedPlanFilters.status || item.status === appliedPlanFilters.status)
  && (!appliedPlanFilters.type || normalizePlanType(item.planned_type) === normalizePlanType(appliedPlanFilters.type))
  && inDateRange(item.planned_time, appliedPlanFilters.dateRange)
))
const pagedPlans = computed(() => {
  const start = (planPage.value - 1) * planPageSize.value
  return filteredPlans.value.slice(start, start + planPageSize.value)
})
watch(() => filteredPlans.value.length, total => {
  planPage.value = Math.min(planPage.value, Math.max(1, Math.ceil(total / planPageSize.value)))
})
watch([
  () => maintenanceFilters.type,
  () => maintenanceFilters.result,
  () => maintenanceFilters.dateRange
], () => { maintenancePage.value = 1 }, { deep: true })
const normalizePlanType = (value) => String(value || '').trim().toLowerCase().replace(/[\s-]+/g, '_')
const resetMaintenanceFilters = () => {
  searchComponentNo.value = ''
  Object.assign(maintenanceFilters, { type: '', result: '', dateRange: [] })
  maintenancePage.value = 1
  fetchAllList()
}
const applyPlanFilters = () => {
  Object.assign(appliedPlanFilters, { ...planFilters, dateRange: [...(planFilters.dateRange || [])] })
  planPage.value = 1
}
const resetPlanFilters = () => {
  Object.assign(planFilters, { componentNo: '', status: '', type: '', dateRange: [] })
  applyPlanFilters()
}

const translateRole = (role) => ({
  installer: '安装人员',
  technician: '维修技师',
  approver: '审批主管',
  admin: '系统管理员'
}[role] || role)

const getDefaultOperatorId = (role) => {
  return operatorList.value.find(op => op.role === role)?.operator_id || null
}

// 新增：加载所有维修单大盘
const fetchAllList = async () => {
  loading.value = true
  try {
    const res = await getAllMaintenances()
    records.value = res.data || res || []
  } catch {} finally {
    loading.value = false
  }
}

const fetchPlanList = async () => {
  planLoading.value = true
  planLoadFailed.value = false
  try {
    const res = await getMaintenancePlans()
    planList.value = res?.data || res || []
  } catch {
    planList.value = []
    planLoadFailed.value = true
  } finally {
    planLoading.value = false
  }
}


const handleSearch = async () => {
  maintenancePage.value = 1
  if (!searchComponentNo.value) {
    return fetchAllList() // 如果搜索框为空，直接看大盘
  }
  loading.value = true
  try {
    const res = await getComponentMaintenances(searchComponentNo.value)
    const data = res.data || res || []

    // 【关键修复点】：遍历后端返回的数据，如果后端没传 component_no，我们强制给它补上当前搜索的编号！
    records.value = data.map(item => ({
      ...item,
      component_no: item.component_no || searchComponentNo.value
    }))

  } catch {} finally {
    loading.value = false
  }
}

// 改造：组件挂载时，不仅拉取维修记录，还要拉取全体员工名单！
onMounted(async () => {
  fetchAllList() // 刷新页面立刻显示数据
  fetchPlanList()
  try {
    const res = await getOperators()
    operatorList.value = res.data || res || []
  } catch {}
})

// === 维修计划逻辑 ===
const planDialogVisible = ref(false)
const planForm = ref({})
const startPlanVisible = ref(false)
const startPlanForm = ref({})

const openPlanDialog = () => {
  planForm.value = {
    component_no: searchComponentNo.value,
    planned_type: 'scheduled inspection',
    planned_time: formatLocalDateTime(),
    planned_reason: '',
    created_by: null
  }
  planDialogVisible.value = true
}

const submitPlan = async () => {
  if (!planForm.value.component_no || !planForm.value.planned_type || !planForm.value.planned_time || !planForm.value.created_by) {
    return ElMessage.warning('请填写完整的维修计划信息')
  }
  if (planSubmitting.value) return
  planSubmitting.value = true
  try {
    await createMaintenancePlan(planForm.value)
    ElMessage.success('维修计划创建成功')
    planDialogVisible.value = false
    fetchPlanList()
  } catch {} finally {
    planSubmitting.value = false
  }
}

const openStartPlanDialog = (row) => {
  startPlanForm.value = {
    plan_id: row.plan_id,
    component_no: row.component_no,
    planned_type: row.planned_type,
    start_time: formatLocalDateTime(),
    technician_id: getDefaultOperatorId('technician'),
    description: row.planned_reason || ''
  }
  startPlanVisible.value = true
}

const submitStartPlan = async () => {
  if (!startPlanForm.value.technician_id) return ElMessage.warning('请选择维修技师')
  if (!startPlanForm.value.start_time) return ElMessage.warning('请选择实际开始时间')
  if (planSubmitting.value) return
  planSubmitting.value = true
  try {
    await startMaintenancePlan(startPlanForm.value.plan_id, {
      start_time: startPlanForm.value.start_time,
      technician_id: startPlanForm.value.technician_id,
      description: startPlanForm.value.description
    })
    ElMessage.success('维修计划已开始执行，关联维修工单已创建')
    startPlanVisible.value = false
    await Promise.all([fetchPlanList(), fetchAllList()])
  } catch {} finally {
    planSubmitting.value = false
  }
}

const handleCancelPlan = async (row) => {
  if (!planActionOperatorId.value) return ElMessage.warning('请选择本次计划操作人员')
  try {
    await ElMessageBox.confirm(`确定取消部件 ${row.component_no} 的维修计划吗？`, '取消计划确认', { type: 'warning' })
    await cancelMaintenancePlan(row.plan_id, { operator_id: planActionOperatorId.value })
    ElMessage.success('维修计划已取消')
    fetchPlanList()
  } catch {}
}

const formatTime = (value) => value ? String(value).replace('T', ' ').slice(0, 19) : '-'


// === 创建工单逻辑 ===
const createVisible = ref(false)
const createForm = ref({})

const openCreateDialog = () => {
  createForm.value = {
    component_no: searchComponentNo.value, // 默认带入当前搜索的部件
    maintenance_type: 'routine',
    start_time: formatLocalDateTime(),
    description: '',
    technician_id: getDefaultOperatorId('technician')
  }
  createVisible.value = true
}

const submitCreate = async () => {
  if (!createForm.value.component_no) return ElMessage.error('部件编号必填')
  if (!createForm.value.technician_id) return ElMessage.error('请选择维修技师')
  if (maintenanceSubmitting.value) return
  maintenanceSubmitting.value = true
  try {
    await createMaintenance(createForm.value)
    ElMessage.success('工单创建成功！')
    createVisible.value = false
    // 创建成功后自动查询该部件的记录
    searchComponentNo.value = createForm.value.component_no
    handleSearch()
  } catch {} finally {
    maintenanceSubmitting.value = false
  }
}

// === 完成维修逻辑 ===
const completeVisible = ref(false)
const completeForm = ref({})

const openCompleteDialog = (row) => {
  completeForm.value = {
    maintenance_id: row.maintenance_id,
    component_no: searchComponentNo.value, // 用于刷新列表
    end_time: formatLocalDateTime(),
    result: 'passed',
    description: '',
    approved_by: getDefaultOperatorId('approver'),
    retirement_reason: ''
  }
  completeVisible.value = true
}

const submitComplete = async () => {
  if (completeForm.value.result === 'scrapped' && !completeForm.value.retirement_reason) {
    return ElMessage.error('选择报废时必须填写退役原因！')
  }
  if (!completeForm.value.approved_by) return ElMessage.error('请选择审批主管')
  if (maintenanceSubmitting.value) return
  maintenanceSubmitting.value = true
  try {
    await completeMaintenance(completeForm.value.maintenance_id, completeForm.value)
    ElMessage.success('维修结果提报成功！部件状态已同步流转。')
    completeVisible.value = false
    await Promise.all([handleSearch(), fetchPlanList()])
  } catch {} finally {
    maintenanceSubmitting.value = false
  }
}
</script>

<style scoped>
.section-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 14px;
}
.section-header h3 {
  margin: 0;
}
.section-actions {
  display: flex;
  align-items: center;
  gap: 10px;
}
.form-section-title {
  margin: 4px 0 16px;
  padding: 8px 12px;
  color: #1a5a86;
  border-left: 3px solid #2f91d0;
  background: #f1f8fd;
  font-size: 13px;
  font-weight: 600;
}
</style>
