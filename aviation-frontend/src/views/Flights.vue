<template>
  <div class="app-container">
    <div class="page-header">
      <div><h2>飞行记录</h2><p>记录飞行任务并支撑部件飞行小时统计</p></div>
      <el-button type="primary" @click="createVisible = true">
        <el-icon><Plus /></el-icon> 新增飞行记录
      </el-button>
    </div>

    <div class="filter-panel">
      <el-form class="filter-form" inline>
        <el-form-item label="飞机编号"><el-input v-model="filters.aircraftNo" clearable placeholder="输入飞机编号" style="width: 180px" /></el-form-item>
        <el-form-item label="日期范围"><el-date-picker v-model="filters.dateRange" type="daterange" value-format="YYYY-MM-DD" start-placeholder="开始日期" end-placeholder="结束日期" /></el-form-item>
        <el-form-item><div class="filter-actions"><el-button type="primary" @click="applyFilters">搜索</el-button><el-button @click="resetFilters">重置</el-button><el-button @click="fetchList">刷新</el-button></div></el-form-item>
      </el-form>
    </div>

    <el-table :data="pagedFlights" border style="width: 100%" v-loading="loading" element-loading-text="正在加载数据...">
      <el-table-column prop="mission_no" label="任务编号" />
      <el-table-column prop="aircraft_no" label="飞机编号" />
      <el-table-column prop="takeoff_time" label="起飞时间" width="160">
  <template #default="scope">
    {{ formatTime(scope.row.takeoff_time) }}
  </template>
</el-table-column>
<el-table-column prop="landing_time" label="降落时间" width="160">
  <template #default="scope">
    {{ formatTime(scope.row.landing_time) }}
  </template>
</el-table-column>
      <el-table-column prop="flight_hours" label="飞行时长（小时）" />
      <el-table-column label="任务类型"><template #default="scope">{{ formatFlightMissionType(scope.row.mission_type) }}</template></el-table-column>
      <el-table-column prop="recorder_name" label="记录人" />
      <template #empty><el-empty description="暂无数据" /></template>
    </el-table>
    <ListPagination v-model:page="currentPage" v-model:page-size="pageSize" :total="filteredFlights.length" />

    <el-dialog title="新增飞行记录" v-model="createVisible" width="500px">
      <el-form :model="form" label-width="100px">
        <el-form-item label="飞机编号" required>
          <el-input v-model="form.aircraft_no" placeholder="如 AC-1001" />
        </el-form-item>
        <el-form-item label="任务编号" required>
          <el-input v-model="form.mission_no" />
        </el-form-item>
        <el-form-item label="起飞时间" required>
          <el-date-picker v-model="form.takeoff_time" type="datetime" value-format="YYYY-MM-DD HH:mm:ss" style="width: 100%" />
        </el-form-item>
        <el-form-item label="降落时间" required>
          <el-date-picker v-model="form.landing_time" type="datetime" value-format="YYYY-MM-DD HH:mm:ss" style="width: 100%" />
        </el-form-item>
        <el-form-item label="任务类型">
          <el-select v-model="form.mission_type" style="width: 100%">
            <el-option label="训练任务" value="training" />
            <el-option label="巡逻任务" value="patrol" />
            <el-option label="运输任务" value="transport" />
          </el-select>
        </el-form-item>
        <el-form-item label="记录人员" required>
          <el-select v-model="form.recorded_by" placeholder="请选择记录人员" style="width: 100%">
            <el-option v-for="op in operatorList" :key="op.operator_id" :label="op.operator_name" :value="op.operator_id" />
          </el-select>
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="createVisible = false">取消</el-button>
        <el-button type="primary" :loading="submitting" @click="submitFlight">提交</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<script setup>
import { computed, reactive, ref, onMounted, watch } from 'vue'
import { getFlightLogs, createFlightLog } from '../api/flights'
import { ElMessage } from 'element-plus'
import { formatFlightMissionType } from '../utils/businessFormatters'
import { getOperators } from '../api/operators'
import ListPagination from '../components/ListPagination.vue'

const flightList = ref([])
const loading = ref(false)
const createVisible = ref(false)
const operatorList = ref([])
const submitting = ref(false)
const form = ref({
  aircraft_no: '',
  mission_no: '',
  takeoff_time: '',
  landing_time: '',
  mission_type: 'training',
  recorded_by: null
})
const filters = reactive({ aircraftNo: '', dateRange: [] })
const appliedFilters = reactive({ ...filters })
const currentPage = ref(1)
const pageSize = ref(10)
const filteredFlights = computed(() => flightList.value.filter(item => {
  const aircraftMatched = String(item.aircraft_no || '').toLowerCase().includes(appliedFilters.aircraftNo.trim().toLowerCase())
  const date = String(item.takeoff_time || '').slice(0, 10)
  const dateMatched = !appliedFilters.dateRange?.length || (date >= appliedFilters.dateRange[0] && date <= appliedFilters.dateRange[1])
  return aircraftMatched && dateMatched
}))
const pagedFlights = computed(() => {
  const start = (currentPage.value - 1) * pageSize.value
  return filteredFlights.value.slice(start, start + pageSize.value)
})
watch(() => filteredFlights.value.length, total => {
  currentPage.value = Math.min(currentPage.value, Math.max(1, Math.ceil(total / pageSize.value)))
})
const applyFilters = () => {
  Object.assign(appliedFilters, { ...filters, dateRange: [...(filters.dateRange || [])] })
  currentPage.value = 1
}
const resetFilters = () => {
  Object.assign(filters, { aircraftNo: '', dateRange: [] })
  applyFilters()
}
const formatTime = (value) => value ? String(value).replace('T', ' ') : '-'

const fetchList = async () => {
  loading.value = true
  try {
    const res = await getFlightLogs()
    flightList.value = res.data || res || []
  } catch {} finally {
    loading.value = false
  }
}

const submitFlight = async () => {
  if (!form.value.aircraft_no || !form.value.mission_no || !form.value.takeoff_time || !form.value.landing_time) {
    return ElMessage.warning('请填写完整的飞行记录信息')
  }
  if (new Date(form.value.landing_time) <= new Date(form.value.takeoff_time)) {
    return ElMessage.warning('降落时间必须晚于起飞时间')
  }
  if (!form.value.recorded_by) return ElMessage.warning('请选择记录人员')
  if (submitting.value) return
  submitting.value = true
  try {
    const result = await createFlightLog(form.value)
    if (result?.aircraft_status === 'maintenance') {
      ElMessage.warning('飞行记录已保存；检测到安装部件达到寿命上限，飞机已转入维修状态')
    } else {
      ElMessage.success('飞行记录新增成功，部件飞行时长已自动更新')
    }
    createVisible.value = false
    form.value = { aircraft_no: '', mission_no: '', takeoff_time: '', landing_time: '', mission_type: 'training', recorded_by: null }
    fetchList()
  } catch {} finally {
    submitting.value = false
  }
}

onMounted(async () => {
  await Promise.allSettled([
    fetchList(),
    getOperators().then(rows => { operatorList.value = rows?.data || rows || [] })
  ])
})
</script>

<style scoped>
.header-action {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 20px;
}
</style>
