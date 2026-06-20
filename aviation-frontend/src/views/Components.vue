<template>
  <div class="app-container">
    <div class="page-header">
      <div><h2>部件管理</h2><p>管理航空部件基础信息、状态、寿命与完整生命周期轨迹</p></div>
      <el-button type="primary" @click="openCreateDialog">新增部件</el-button>
    </div>

    <div class="filter-panel">
      <el-form class="filter-form" inline>
        <el-form-item label="部件编号"><el-input v-model="filters.componentNo" clearable placeholder="输入部件编号" style="width: 160px" /></el-form-item>
        <el-form-item label="型号"><el-input v-model="filters.modelCode" clearable placeholder="输入型号" style="width: 140px" /></el-form-item>
        <el-form-item label="类别"><el-input v-model="filters.category" clearable placeholder="输入类别" style="width: 140px" /></el-form-item>
        <el-form-item label="状态"><el-select v-model="filters.status" clearable placeholder="全部状态" style="width: 140px"><el-option label="在库" value="in_stock" /><el-option label="可用" value="available" /><el-option label="已安装" value="installed" /><el-option label="已拆卸" value="removed" /><el-option label="维修中" value="under_maintenance" /><el-option label="已退役" value="retired" /></el-select></el-form-item>
        <el-form-item label="是否退役"><el-select v-model="filters.retired" clearable placeholder="全部" style="width: 120px"><el-option label="未退役" :value="false" /><el-option label="已退役" :value="true" /></el-select></el-form-item>
        <el-form-item><div class="filter-actions"><el-button type="primary" @click="applyFilters">搜索</el-button><el-button @click="resetFilters">重置</el-button><el-button @click="refreshList">刷新</el-button></div></el-form-item>
      </el-form>
    </div>

    <el-table :data="pagedComponents" border style="width: 100%" v-loading="loading" element-loading-text="正在加载数据...">
      <el-table-column prop="component_no" label="部件编号" width="150" />
      <el-table-column label="部件类型" width="120">
        <template #default="scope">
          {{ formatComponentCategory(getComponentModel(scope.row.model_id)?.category) }}
        </template>
      </el-table-column>
      <el-table-column label="型号代码" width="130">
        <template #default="scope">
          {{ getComponentModel(scope.row.model_id)?.model_code || '-' }}
        </template>
      </el-table-column>
      <el-table-column prop="batch_no" label="生产批次" />
      <el-table-column prop="total_flight_hours" label="总飞行小时" width="120" />
      
      <el-table-column label="当前状态" width="120">
        <template #default="scope">
          <el-tag :type="getComponentStatusType(scope.row.status)">{{ formatComponentStatus(scope.row.status) }}</el-tag>
        </template>
      </el-table-column>

      <el-table-column label="操作" width="220">
        <template #default="scope">
          <el-button type="info" size="small" @click="openProfileDrawer(scope.row.component_no)">
            查看生命周期
          </el-button>
          <el-button 
            v-if="!scope.row.is_retired && ['available', 'removed', 'under_maintenance'].includes(scope.row.status)"
            type="danger" 
            size="small" 
            @click="openRetireDialog(scope.row)">
            退役
          </el-button>
        </template>
      </el-table-column>
      <template #empty><el-empty :description="listLoadFailed ? '加载失败' : '暂无数据'" /></template>
    </el-table>
    <ListPagination v-model:page="currentPage" v-model:page-size="pageSize" :total="filteredComponents.length" />

    <el-drawer v-model="drawerVisible" size="46%">
      <template #header>
        <div class="drawer-heading"><div><small>COMPONENT LIFECYCLE</small><h2>{{ currentComponentNo }}</h2></div><el-tag :type="getComponentStatusType(drawerComponentStatus)" effect="dark">{{ formatComponentStatus(drawerComponentStatus) }}</el-tag></div>
      </template>
      <div v-loading="drawerLoading" element-loading-text="正在加载数据...">
        <section class="detail-block"><h3>基础信息</h3>
        <el-alert v-if="profileLoadFailed" title="部件基础信息加载失败" type="warning" :closable="false" show-icon />
        <el-descriptions v-else :column="2" border>
          <el-descriptions-item label="部件编号">{{ profileData.component_no }}</el-descriptions-item>
          <el-descriptions-item label="所属类别">{{ formatComponentCategory(profileData.category) }}</el-descriptions-item>
          <el-descriptions-item label="生产批次">{{ profileData.batch_no }}</el-descriptions-item>
          <el-descriptions-item label="累计飞行时长">{{ calculatedFlightHours }} 小时</el-descriptions-item>
        </el-descriptions></section>

        <section class="detail-block"><h3>飞行使用统计</h3>
        <el-alert v-if="flightUsageLoadFailed" title="飞行使用统计加载失败" type="warning" :closable="false" show-icon />
        <el-table v-else :data="flightUsageData" border style="width: 100%; margin-bottom: 20px;">
          <el-table-column prop="aircraft_no" label="飞机编号" min-width="110" />
          <el-table-column prop="flight_count" label="飞行次数" min-width="90" />
          <el-table-column prop="calculated_total_flight_hours" label="总飞行小时" min-width="110" />
          <el-table-column label="首次飞行时间" min-width="150">
            <template #default="scope">{{ formatTime(scope.row.first_flight_time) || '-' }}</template>
          </el-table-column>
          <el-table-column label="最后飞行时间" min-width="150">
            <template #default="scope">{{ formatTime(scope.row.last_flight_time) || '-' }}</template>
          </el-table-column>
          <template #empty>
            <el-empty description="暂无飞行使用记录" />
          </template>
        </el-table></section>

        <section class="detail-block"><h3>完整生命周期时间轴</h3>
        <el-alert
          v-if="fullTimelineLoadFailed"
          title="完整时间轴未加载"
          type="warning"
          :closable="false"
          show-icon
          style="margin-bottom: 16px;"
        />
        <el-timeline v-else-if="fullTimelineData.length" style="margin-top: 15px;">
          <el-timeline-item
            v-for="event in fullTimelineData"
            :key="`${event.source_table}-${event.source_id}-${event.event_type}`"
            :timestamp="formatTime(event.event_time)"
            :type="getTimelineType(event.event_type)"
            placement="top"
          >
            <el-card shadow="hover">
              <div class="timeline-title-row">
                <el-tag :type="getTimelineType(event.event_type)" size="small">
                  {{ formatLifecycleEventType(event.event_type) }}
                </el-tag>
                <strong>{{ formatLifecycleTitle(event.event_title, event.event_type) }}</strong>
              </div>
              <p>{{ formatLifecycleDetail(event.event_detail, event.event_type) }}</p>
            </el-card>
          </el-timeline-item>
        </el-timeline>
        <el-empty v-else description="暂无生命周期事件" /></section>

      </div>
    </el-drawer>

    <el-dialog title="新增部件" v-model="createVisible" width="500px">
      <el-form :model="createForm" label-width="100px">
        <el-form-item label="部件编号" required>
          <el-input v-model="createForm.component_no" placeholder="如 ENG-004" />
        </el-form-item>
        <el-form-item label="部件型号" required>
          <el-select
            v-model="createForm.model_id"
            placeholder="请选择部件型号"
            style="width: 100%"
            :loading="modelLoading"
          >
            <el-option
              v-for="model in modelList"
              :key="model.model_id"
              :label="formatComponentModelOption(model)"
              :value="model.model_id"
            />
          </el-select>
        </el-form-item>
        <el-form-item label="生产批次" required>
          <el-input v-model="createForm.batch_no" placeholder="请输入生产批次" />
        </el-form-item>
        <el-form-item label="生产日期" required>
          <el-date-picker v-model="createForm.production_date" type="date" value-format="YYYY-MM-DD" style="width: 100%" />
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="createVisible = false">取消</el-button>
        <el-button type="primary" :loading="createSubmitting" @click="submitCreate">提交</el-button>
      </template>
    </el-dialog>

    <el-dialog title="部件退役处理" v-model="retireVisible" width="500px">
      <el-form :model="retireForm" label-width="100px">
        <el-form-item label="退役时间" required>
          <el-date-picker v-model="retireForm.retirement_time" type="datetime" value-format="YYYY-MM-DD HH:mm:ss" style="width: 100%" />
        </el-form-item>
        <el-form-item label="退役原因" required>
          <el-input v-model="retireForm.retirement_reason" type="textarea" placeholder="请填写退役原因，如：达到设计寿命、无法修复等" />
        </el-form-item>
        <el-form-item label="审批人员" required>
          <el-select v-model="retireForm.approved_by" placeholder="请选择退役审批人" style="width: 100%">
            <el-option
              v-for="op in operatorList.filter(o => o.role === 'approver')"
              :key="op.operator_id"
              :label="op.operator_name + '（' + translateRole(op.role) + '）'"
              :value="op.operator_id"
            />
          </el-select>
        </el-form-item>
        <el-form-item label="备注说明">
          <el-input v-model="retireForm.remark" type="textarea" />
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="retireVisible = false">取消</el-button>
        <el-button type="danger" :loading="retireSubmitting" @click="submitRetire">确认退役</el-button>
      </template>
    </el-dialog>

  </div>
</template>

<script setup>
import { computed, reactive, ref, onMounted, watch } from 'vue'
import { getComponents, createComponent, getComponentProfile, getComponentFullTimeline, getComponentFlightUsage, retireComponent, getComponentModels } from '../api/components'
import { getOperators } from '../api/operators'
import { ElMessage } from 'element-plus'
import {
  formatComponentCategory,
  formatComponentStatus,
  getComponentStatusType,
  formatLifecycleDetail,
  formatLifecycleEventType,
  formatLifecycleTitle
} from '../utils/businessFormatters'
import { formatLocalDateTime } from '../utils/dateTime'
import ListPagination from '../components/ListPagination.vue'

// 2. 定义变量
const componentList = ref([])
const modelList = ref([]) // 用于存放型号数据
const operatorList = ref([])
const loading = ref(false)
const listLoadFailed = ref(false)
const createSubmitting = ref(false)
const retireSubmitting = ref(false)
const modelLoading = ref(false)
const filters = reactive({ componentNo: '', modelCode: '', category: '', status: '', retired: '' })
const appliedFilters = reactive({ ...filters })
const currentPage = ref(1)
const pageSize = ref(10)

// 3. 定义获取型号的函数
const fetchModels = async () => {
  modelLoading.value = true
  try {
    const res = await getComponentModels()
    // 根据实际情况取 data，有些后端直接返回数组
    modelList.value = res.data || res || []
  } catch {} finally {
    modelLoading.value = false
  }
}

// 4. 在组件挂载时同时调用两个获取函数
onMounted(() => {
  fetchList()    // 原有的部件实例获取
  fetchModels()  // 新增的型号字典获取
  fetchOperators()
})

const fetchOperators = async () => {
  try {
    const res = await getOperators()
    operatorList.value = res.data || res || []
  } catch {}
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

const getComponentModel = (modelId) => {
  return modelList.value.find(model => Number(model.model_id) === Number(modelId))
}

const includesText = (value, keyword) => String(value || '').toLowerCase().includes(String(keyword || '').trim().toLowerCase())
const filteredComponents = computed(() => componentList.value.filter(item => {
  const model = getComponentModel(item.model_id) || {}
  return includesText(item.component_no, appliedFilters.componentNo)
    && includesText(model.model_code, appliedFilters.modelCode)
    && includesText(`${model.category || ''} ${formatComponentCategory(model.category)}`, appliedFilters.category)
    && (!appliedFilters.status || item.status === appliedFilters.status)
    && (appliedFilters.retired === '' || Boolean(item.is_retired) === appliedFilters.retired)
}))
const pagedComponents = computed(() => {
  const start = (currentPage.value - 1) * pageSize.value
  return filteredComponents.value.slice(start, start + pageSize.value)
})
watch(() => filteredComponents.value.length, total => {
  currentPage.value = Math.min(currentPage.value, Math.max(1, Math.ceil(total / pageSize.value)))
})
const applyFilters = () => {
  Object.assign(appliedFilters, filters)
  currentPage.value = 1
}
const resetFilters = () => {
  Object.assign(filters, { componentNo: '', modelCode: '', category: '', status: '', retired: '' })
  applyFilters()
}
const refreshList = () => Promise.all([fetchList(), fetchModels()])

const formatComponentModelOption = (model) => {
  return `${formatComponentCategory(model.category)} / ${model.model_code}`
}

const fetchList = async () => {
  loading.value = true
  listLoadFailed.value = false
  try {
    const res = await getComponents()
    componentList.value = res.data || res || []
  } catch {
    componentList.value = []
    listLoadFailed.value = true
  } finally {
    loading.value = false
  }
}

// --- 查看生命周期逻辑 (抽屉) ---
const drawerVisible = ref(false)
const drawerLoading = ref(false)
const currentComponentNo = ref('')
const profileData = ref({})
const fullTimelineData = ref([])
const fullTimelineLoadFailed = ref(false)
const profileLoadFailed = ref(false)
const flightUsageLoadFailed = ref(false)
const flightUsageData = ref([])
const calculatedFlightHours = computed(() => flightUsageData.value
  .reduce((total, item) => total + Number(item.calculated_total_flight_hours || 0), 0)
  .toFixed(2))
const drawerComponentStatus = computed(() => profileData.value.status
  || profileData.value.current_status
  || componentList.value.find(item => item.component_no === currentComponentNo.value)?.status)

const openProfileDrawer = async (component_no) => {
  currentComponentNo.value = component_no
  drawerVisible.value = true
  drawerLoading.value = true
  profileData.value = {}
  fullTimelineData.value = []
  flightUsageData.value = []
  fullTimelineLoadFailed.value = false
  profileLoadFailed.value = false
  flightUsageLoadFailed.value = false

  try {
    const [profileResult, flightUsageResult, fullTimelineResult] = await Promise.allSettled([
      getComponentProfile(component_no),
      getComponentFlightUsage(component_no),
      getComponentFullTimeline(component_no)
    ])

    if (profileResult.status === 'fulfilled') {
      profileData.value = profileResult.value?.data || profileResult.value || {}
    } else {
      profileLoadFailed.value = true
    }
    if (flightUsageResult.status === 'fulfilled') {
      flightUsageData.value = flightUsageResult.value?.data || flightUsageResult.value || []
    } else {
      flightUsageLoadFailed.value = true
    }
    if (fullTimelineResult.status === 'fulfilled') {
      const rawTimeline = fullTimelineResult.value?.data || fullTimelineResult.value || {}
      fullTimelineData.value = [...(rawTimeline.timeline || [])].sort(
        (a, b) => new Date(a.event_time) - new Date(b.event_time)
      )
    } else {
      fullTimelineLoadFailed.value = true
    }
  } finally {
    drawerLoading.value = false
  }
}

// 为时间轴事件匹配不同颜色的节点
const getTimelineType = (eventType) => {
  const map = {
    'STOCK_IN': 'info',
    'INSTALL': 'primary',
    'UNINSTALL': 'warning',
    'MAINTENANCE': 'success',
    'RETIRE': 'danger',
    created: 'info',
    stock_in: 'info',
    in_stock: 'info',
    installed: 'primary',
    installation: 'primary',
    uninstalled: 'warning',
    uninstallation: 'warning',
    removed: 'warning',
    maintenance_started: 'primary',
    maintenance_start: 'primary',
    maintenance_completed: 'success',
    maintenance_complete: 'success',
    maintenance_end: 'success',
    retired: 'danger',
    retirement: 'danger',
    maintenance_plan_created: 'info',
    maintenance_plan_completed: 'success',
    maintenance_plan_cancelled: 'warning'
  }
  return map[eventType] || ''
}

// --- 入库逻辑 ---
const createVisible = ref(false)
const createForm = ref({})

const openCreateDialog = async () => {
  if (!modelList.value.length) {
    await fetchModels()
  }
  createForm.value = {
    component_no: '',
    model_id: modelList.value[0]?.model_id || null,
    batch_no: '',
    production_date: ''
  }
  createVisible.value = true
}

const submitCreate = async () => {
  if (!createForm.value.component_no) return ElMessage.warning('请填写部件编号')
  if (!createForm.value.model_id) return ElMessage.warning('请选择部件型号')
  if (!createForm.value.batch_no?.trim()) return ElMessage.warning('请输入生产批次')
  if (createSubmitting.value) return
  createSubmitting.value = true
  try {
    await createComponent({
      ...createForm.value,
      batch_no: createForm.value.batch_no.trim()
    })
    ElMessage.success('新部件入库成功')
    createVisible.value = false
    fetchList()
  } catch {} finally {
    createSubmitting.value = false
  }
}

// --- 退役逻辑 ---
const retireVisible = ref(false)
const retireForm = ref({})
const retireTarget = ref('')

const openRetireDialog = (row) => {
  retireTarget.value = row.component_no
  retireForm.value = {
    retirement_time: formatLocalDateTime(),
    retirement_reason: '',
    approved_by: getDefaultOperatorId('approver'),
    remark: ''
  }
  retireVisible.value = true
}

const submitRetire = async () => {
  if (!retireForm.value.retirement_reason) return ElMessage.warning('退役原因必填')
  if (!retireForm.value.approved_by) return ElMessage.warning('请选择退役审批人')
  if (retireSubmitting.value) return
  retireSubmitting.value = true
  try {
    await retireComponent(retireTarget.value, retireForm.value)
    ElMessage.success('退役处理成功')
    retireVisible.value = false
    fetchList() // 刷新列表，状态将变为 retired
  } catch {} finally {
    retireSubmitting.value = false
  }
}

// 时间格式化：把 T 替换掉，只保留年月日时分
const formatTime = (timeStr) => {
  if (!timeStr) return '';
  return timeStr.replace('T', ' ').substring(0, 16);
}

</script>

<style scoped>
/* 让时间轴里的卡片更加紧凑美观 */
:deep(.el-timeline-item__content h4) {
  margin: 0 0 5px 0;
  font-size: 14px;
}
:deep(.el-timeline-item__content p) {
  margin: 0;
  color: #606266;
  font-size: 13px;
}
.timeline-title-row {
  display: flex;
  align-items: center;
  gap: 8px;
  margin-bottom: 8px;
}
.drawer-heading { width: 100%; display: flex; align-items: center; justify-content: space-between; padding-right: 10px; }
.drawer-heading small { color: #7d93a5; font-size: 10px; letter-spacing: 1.4px; }
.drawer-heading h2 { margin: 5px 0 0; color: #123f63; }
.detail-block { margin-bottom: 18px; padding: 18px; border: 1px solid #e2ecf3; border-radius: 12px; background: #fbfdff; transition: box-shadow .2s ease, transform .2s ease; }
.detail-block:hover { box-shadow: 0 8px 22px rgba(21, 91, 139, .08); transform: translateY(-1px); }
.detail-block h3 { margin: 0 0 14px; color: #17496d; font-size: 16px; }
.header-action {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 20px;
}
</style>
