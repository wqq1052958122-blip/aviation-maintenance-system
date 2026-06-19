<template>
  <div class="app-container">
    <div class="header-action">
      <h2>飞行任务日志管理</h2>
      <el-button type="primary" @click="createVisible = true">
        <el-icon><Plus /></el-icon> 新增飞行记录
      </el-button>
    </div>

    <el-table :data="flightList" border style="width: 100%" v-loading="loading">
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
      <el-table-column prop="flight_hours" label="飞行时长(H)" />
      <el-table-column prop="mission_type" label="任务类型" />
      <el-table-column prop="recorder_name" label="记录人" />
    </el-table>

    <el-dialog title="录入飞行日志" v-model="createVisible" width="500px">
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
        <el-button type="primary" @click="submitFlight">确认录入</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { getFlightLogs, createFlightLog } from '../api/flights'
import { ElMessage } from 'element-plus'

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

const fetchList = async () => {
  loading.value = true
  try {
    const res = await getFlightLogs()
    flightList.value = res.data || res || []
  } catch (e) {
    console.error(e)
  } finally {
    loading.value = false
  }
}

const submitFlight = async () => {
  try {
    await createFlightLog(form.value)
    ElMessage.success('飞行日志录入成功，部件飞行时长已自动更新！')
    createVisible.value = false
    fetchList()
  } catch (e) {
    console.error(e)
  }
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