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
        <el-form-item><div class="filter-actions"><el-button type="primary">搜索</el-button><el-button @click="resetFilters">重置</el-button><el-button @click="fetchList">刷新</el-button></div></el-form-item>
      </el-form>
    </div>

    <el-table :data="filteredFlights" border style="width: 100%" v-loading="loading" element-loading-text="正在加载数据...">
      <el-table-column prop="mission_no" label="任务编号" />
      <el-table-column prop="aircraft_no" label="飞机编号" />
      <el-table-column prop="takeoff_time" label="起飞时间" width="160">
  <template #default="scope">
    {{ scope.row.takeoff_time.replace('T', ' ') }}
  </template>
</el-table-column>
<el-table-column prop="landing_time" label="降落时间" width="160">
  <template #default="scope">
    {{ scope.row.landing_time.replace('T', ' ') }}
  </template>
</el-table-column>
      <el-table-column prop="flight_hours" label="飞行时长（小时）" />
      <el-table-column label="任务类型"><template #default="scope">{{ formatFlightMissionType(scope.row.mission_type) }}</template></el-table-column>
      <el-table-column prop="recorder_name" label="记录人" />
      <template #empty><el-empty description="暂无数据" /></template>
    </el-table>

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
      </el-form>
      <template #footer>
        <el-button @click="createVisible = false">取消</el-button>
        <el-button type="primary" @click="submitFlight">提交</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<script setup>
import { computed, reactive, ref, onMounted } from 'vue'
import { getFlightLogs, createFlightLog } from '../api/flights'
import { ElMessage } from 'element-plus'
import { formatFlightMissionType } from '../utils/businessFormatters'

const flightList = ref([])
const loading = ref(false)
const createVisible = ref(false)
const form = ref({
  aircraft_no: '',
  mission_no: '',
  takeoff_time: '',
  landing_time: '',
  mission_type: 'training',
  recorded_by: 1 // 模拟当前用户ID
})
const filters = reactive({ aircraftNo: '', dateRange: [] })
const filteredFlights = computed(() => flightList.value.filter(item => {
  const aircraftMatched = String(item.aircraft_no || '').toLowerCase().includes(filters.aircraftNo.trim().toLowerCase())
  const date = String(item.takeoff_time || '').slice(0, 10)
  const dateMatched = !filters.dateRange?.length || (date >= filters.dateRange[0] && date <= filters.dateRange[1])
  return aircraftMatched && dateMatched
}))
const resetFilters = () => Object.assign(filters, { aircraftNo: '', dateRange: [] })

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
  try {
    await createFlightLog(form.value)
    ElMessage.success('飞行记录新增成功，部件飞行时长已自动更新')
    createVisible.value = false
    fetchList()
  } catch {}
}

onMounted(fetchList)
</script>

<style scoped>
.header-action {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 20px;
}
</style>
