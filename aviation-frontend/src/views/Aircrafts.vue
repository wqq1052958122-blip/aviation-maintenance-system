<template>
  <div class="app-container">
    <div class="page-header">
      <div><h2>机队管理</h2><p>查看飞机基础信息与当前安装部件配置</p></div>
      <el-button type="primary" @click="createVisible = true">
        <el-icon><Plus /></el-icon> 新增飞机
      </el-button>
    </div>

    <div class="filter-panel">
      <el-form class="filter-form" inline>
        <el-form-item label="飞机编号"><el-input v-model="filters.aircraftNo" clearable placeholder="输入飞机编号" style="width: 170px" /></el-form-item>
        <el-form-item label="机型"><el-input v-model="filters.model" clearable placeholder="输入机型" style="width: 160px" /></el-form-item>
        <el-form-item label="状态"><el-select v-model="filters.status" clearable placeholder="全部状态" style="width: 140px"><el-option label="服役中" value="active" /><el-option label="维修中" value="maintenance" /><el-option label="已退役" value="retired" /></el-select></el-form-item>
        <el-form-item><div class="filter-actions"><el-button type="primary" @click="applyFilters">搜索</el-button><el-button @click="resetFilters">重置</el-button><el-button @click="fetchList">刷新</el-button></div></el-form-item>
      </el-form>
    </div>

    <el-row :gutter="20" v-loading="loading" element-loading-text="正在加载数据...">
      <el-col :span="8" v-for="ac in pagedAircrafts" :key="ac.aircraft_no" style="margin-bottom: 20px;">
        <el-card shadow="hover" :class="{'is-retired': ac.service_status === 'retired'}">
          <template #header>
            <div style="display: flex; justify-content: space-between; align-items: center;">
              <span style="font-size: 20px; font-weight: bold; color: #303133;">
                <el-icon><Position /></el-icon> {{ ac.aircraft_no }}
              </span>
              <el-tag :type="getStatusType(ac.service_status)" effect="dark">
                {{ translateStatus(ac.service_status) }}
              </el-tag>
            </div>
          </template>
          
          <div style="line-height: 1.8; color: #606266;">
            <p><strong>机型型号：</strong>{{ ac.aircraft_model }}</p>
            <p><strong>服役日期：</strong>{{ ac.start_date || '未登记' }}</p>
          </div>

          <div style="margin-top: 20px; display: flex; gap: 10px; justify-content: flex-end; flex-wrap: wrap;">
             <el-button size="small" type="primary" plain @click="openDetail(ac)">
                详情
             </el-button>
             <el-button 
                size="small" 
                v-if="ac.service_status !== 'maintenance' && ac.service_status !== 'retired'" 
                @click="changeStatus(ac.aircraft_no, 'maintenance')">
                转入定检
             </el-button>
             <el-button 
                size="small" type="success" 
                v-if="ac.service_status !== 'active' && ac.service_status !== 'retired'" 
                @click="changeStatus(ac.aircraft_no, 'active')">
                恢复服役
             </el-button>
             <el-button 
                size="small" type="danger" 
                v-if="ac.service_status !== 'retired'" 
                @click="changeStatus(ac.aircraft_no, 'retired')">
                退役
             </el-button>
          </div>
        </el-card>
      </el-col>
    </el-row>
    <el-empty v-if="!loading && !filteredAircrafts.length" description="暂无数据" />
    <ListPagination v-model:page="currentPage" v-model:page-size="pageSize" :total="filteredAircrafts.length" :page-sizes="[6, 12, 24]" />

    <el-drawer
      v-model="detailVisible"
      size="60%"
    >
      <template #header>
        <div class="drawer-heading"><div><small>AIRCRAFT CONFIGURATION</small><h2>{{ selectedAircraft.aircraft_no || '飞机详情' }}</h2></div><el-tag :type="getAircraftStatusType(selectedAircraft.service_status)" effect="dark">{{ formatAircraftStatus(selectedAircraft.service_status) }}</el-tag></div>
      </template>
      <div v-loading="detailLoading" element-loading-text="正在加载数据...">
        <section class="detail-block">
        <div class="detail-section-header">
          <h3>飞机基础信息</h3>
          <el-button type="primary" plain size="small" @click="loadAircraftInstallations">
            刷新
          </el-button>
        </div>

        <el-descriptions :column="2" border>
          <el-descriptions-item label="飞机编号">
            {{ selectedAircraft.aircraft_no || '-' }}
          </el-descriptions-item>
          <el-descriptions-item label="飞机型号">
            {{ selectedAircraft.aircraft_model || '-' }}
          </el-descriptions-item>
          <el-descriptions-item label="当前状态">
            <el-tag :type="getAircraftStatusType(selectedAircraft.service_status)">
              {{ formatAircraftStatus(selectedAircraft.service_status) }}
            </el-tag>
          </el-descriptions-item>
          <el-descriptions-item label="投入使用日期">
            {{ formatDate(selectedAircraft.start_date) }}
          </el-descriptions-item>
          <el-descriptions-item v-if="selectedAircraft.created_at" label="创建时间">
            {{ formatDateTime(selectedAircraft.created_at) }}
          </el-descriptions-item>
          <el-descriptions-item v-if="selectedAircraft.remark" label="备注" :span="2">
            {{ selectedAircraft.remark }}
          </el-descriptions-item>
        </el-descriptions></section>

        <section class="detail-block"><h3 class="installation-title">当前安装部件</h3>
        <el-alert
          v-if="detailLoadFailed"
          title="飞机部件详情加载失败"
          type="error"
          :closable="false"
          show-icon
        />
        <el-table v-else :data="currentAircraftInstallations" border style="width: 100%">
          <el-table-column label="安装位置" min-width="140">
            <template #default="scope">
              {{ scope.row.position_name || formatInstallPosition(scope.row.install_position) }}
            </template>
          </el-table-column>
          <el-table-column prop="component_no" label="部件编号" min-width="110" />
          <el-table-column prop="model_code" label="部件型号" min-width="110" />
          <el-table-column label="部件类别" min-width="100">
            <template #default="scope">{{ formatComponentCategory(scope.row.category) }}</template>
          </el-table-column>
          <el-table-column label="部件状态" min-width="100">
            <template #default="scope">
              <el-tag :type="getComponentStatusType(scope.row.component_status)">
                {{ formatComponentStatus(scope.row.component_status) }}
              </el-tag>
            </template>
          </el-table-column>
          <el-table-column label="安装时间" min-width="160">
            <template #default="scope">{{ formatDateTime(scope.row.install_time) }}</template>
          </el-table-column>
          <el-table-column label="当前有效" width="90" align="center">
            <template #default><el-tag type="primary">是</el-tag></template>
          </el-table-column>
          <template #empty>
            <el-empty description="暂无当前安装部件" />
          </template>
        </el-table></section>
      </div>
    </el-drawer>

    <el-dialog title="新增飞机" v-model="createVisible" width="450px">
      <el-form :model="createForm" label-width="100px">
        <el-form-item label="飞机编号" required>
          <el-input v-model="createForm.aircraft_no" placeholder="如 AC-1008" />
        </el-form-item>
        <el-form-item label="机型型号" required>
          <el-input v-model="createForm.aircraft_model" placeholder="如 A320, B737, C919" />
        </el-form-item>
        <el-form-item label="入列日期">
          <el-date-picker v-model="createForm.start_date" type="date" value-format="YYYY-MM-DD" style="width: 100%" />
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="createVisible = false">取消</el-button>
        <el-button type="primary" :loading="createSubmitting" @click="submitCreate">提交</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<script setup>
import { computed, reactive, ref, onMounted, watch } from 'vue'
import { getAircrafts, createAircraft, updateAircraftStatus } from '../api/aircrafts'
import { getActiveInstallations } from '../api/installations'
import { ElMessage, ElMessageBox } from 'element-plus'
import {
  formatAircraftStatus,
  formatComponentCategory,
  formatComponentStatus,
  formatInstallPosition,
  getAircraftStatusType,
  getComponentStatusType
} from '../utils/businessFormatters'
import { formatLocalDate } from '../utils/dateTime'
// 引入 Element Plus 的图标
import { Plus, Position } from '@element-plus/icons-vue'
import ListPagination from '../components/ListPagination.vue'

const aircraftList = ref([])
const loading = ref(false)
const createSubmitting = ref(false)
const detailVisible = ref(false)
const detailLoading = ref(false)
const detailLoadFailed = ref(false)
const selectedAircraft = ref({})
const currentAircraftInstallations = ref([])
const createVisible = ref(false)
const createForm = ref({
  aircraft_no: '',
  aircraft_model: '',
  start_date: formatLocalDate()
})
const filters = reactive({ aircraftNo: '', model: '', status: '' })
const appliedFilters = reactive({ ...filters })
const currentPage = ref(1)
const pageSize = ref(6)
const includesText = (value, keyword) => String(value || '').toLowerCase().includes(String(keyword || '').trim().toLowerCase())
const filteredAircrafts = computed(() => aircraftList.value.filter(item =>
  includesText(item.aircraft_no, appliedFilters.aircraftNo)
  && includesText(item.aircraft_model, appliedFilters.model)
  && (!appliedFilters.status || item.service_status === appliedFilters.status)
))
const pagedAircrafts = computed(() => {
  const start = (currentPage.value - 1) * pageSize.value
  return filteredAircrafts.value.slice(start, start + pageSize.value)
})
watch(() => filteredAircrafts.value.length, total => {
  currentPage.value = Math.min(currentPage.value, Math.max(1, Math.ceil(total / pageSize.value)))
})
const applyFilters = () => {
  Object.assign(appliedFilters, filters)
  currentPage.value = 1
}
const resetFilters = () => {
  Object.assign(filters, { aircraftNo: '', model: '', status: '' })
  applyFilters()
}

// 查询机队
const fetchList = async () => {
  loading.value = true
  try {
    const res = await getAircrafts()
    aircraftList.value = res.data || res || []
  } catch {} finally {
    loading.value = false
  }
}

// 新增飞机
const submitCreate = async () => {
  if (!createForm.value.aircraft_no || !createForm.value.aircraft_model) {
    return ElMessage.warning('请完整填写飞机编号和机型！')
  }
  if (createSubmitting.value) return
  createSubmitting.value = true
  try {
    await createAircraft(createForm.value)
    ElMessage.success('飞机新增成功')
    createVisible.value = false
    // 清空表单
    createForm.value.aircraft_no = ''
    fetchList()
  } catch {} finally {
    createSubmitting.value = false
  }
}

// 更改飞机状态
const changeStatus = async (aircraft_no, newStatus) => {
  if (newStatus === 'retired') {
    try {
      const rows = await getActiveInstallations()
      const activeCount = (Array.isArray(rows) ? rows : []).filter(item => item.aircraft_no === aircraft_no).length
      if (activeCount > 0) {
        ElMessage.warning(`该飞机仍有 ${activeCount} 个当前安装部件，请先完成拆卸或更换处理`)
        return
      }
    } catch {
      ElMessage.error('无法确认当前安装状态，暂不能执行退役')
      return
    }
  }
  const statusName = translateStatus(newStatus)
  ElMessageBox.confirm(`确定将 ${aircraft_no} 的状态更改为【${statusName}】吗？`, '状态流转确认', {
    confirmButtonText: '确定',
    cancelButtonText: '取消',
    type: 'warning',
  }).then(async () => {
    try {
      await updateAircraftStatus(aircraft_no, newStatus)
      ElMessage.success('状态更新成功')
      fetchList()
    } catch {
    }
  }).catch(() => {})
}

const openDetail = (aircraft) => {
  selectedAircraft.value = { ...aircraft }
  currentAircraftInstallations.value = []
  detailLoadFailed.value = false
  detailVisible.value = true
  loadAircraftInstallations()
}

const loadAircraftInstallations = async () => {
  if (!selectedAircraft.value.aircraft_no) return
  detailLoading.value = true
  detailLoadFailed.value = false
  try {
    const rows = await getActiveInstallations()
    currentAircraftInstallations.value = (Array.isArray(rows) ? rows : []).filter(
      item => item.aircraft_no === selectedAircraft.value.aircraft_no
    )
  } catch {
    currentAircraftInstallations.value = []
    detailLoadFailed.value = true
  } finally {
    detailLoading.value = false
  }
}

// 飞机状态显示
const translateStatus = (status) => {
  return formatAircraftStatus(status)
}

const formatDate = (value) => value ? String(value).slice(0, 10) : '未登记'
const formatDateTime = (value) => value ? String(value).replace('T', ' ').slice(0, 19) : '未登记'

const getStatusType = (status) => {
  return getAircraftStatusType(status)
}

onMounted(() => {
  fetchList()
})
</script>

<style scoped>
/* 让退役的飞机卡片变灰，视觉效果更好 */
.is-retired {
  opacity: 0.6;
  background-color: #f5f7fa;
}
.header-action {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 20px;
}
.detail-section-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 14px;
}
.detail-section-header h3,
.installation-title {
  margin: 0;
}
.installation-title {
  margin-bottom: 14px;
}
.drawer-heading { width: 100%; display: flex; align-items: center; justify-content: space-between; padding-right: 10px; }
.drawer-heading small { color: #7d93a5; font-size: 10px; letter-spacing: 1.4px; }
.drawer-heading h2 { margin: 5px 0 0; color: #123f63; }
.detail-block { margin-bottom: 18px; padding: 18px; border: 1px solid #e2ecf3; border-radius: 12px; background: #fbfdff; transition: box-shadow .2s ease, transform .2s ease; }
.detail-block:hover { box-shadow: 0 8px 22px rgba(21, 91, 139, .08); transform: translateY(-1px); }
</style>
