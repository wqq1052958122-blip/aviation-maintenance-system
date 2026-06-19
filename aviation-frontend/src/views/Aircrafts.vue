<template>
  <div class="app-container">
    <div class="header-action">
      <h2>机队管理</h2>
      <el-button type="primary" @click="createVisible = true">
        <el-icon><Plus /></el-icon> 新增飞机
      </el-button>
    </div>

    <el-row :gutter="20" v-loading="loading">
      <el-col :span="8" v-for="ac in aircraftList" :key="ac.aircraft_no" style="margin-bottom: 20px;">
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

          <div style="margin-top: 20px; display: flex; gap: 10px; justify-content: flex-end;">
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
        <el-button type="primary" @click="submitCreate">提交</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { getAircrafts, createAircraft, updateAircraftStatus } from '../api/aircrafts'
import { ElMessage, ElMessageBox } from 'element-plus'
// 引入 Element Plus 的图标
import { Plus, Position } from '@element-plus/icons-vue'

const aircraftList = ref([])
const loading = ref(false)
const createVisible = ref(false)
const createForm = ref({
  aircraft_no: '',
  aircraft_model: '',
  start_date: new Date().toISOString().split('T')[0]
})

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
  try {
    await createAircraft(createForm.value)
    ElMessage.success('飞机新增成功')
    createVisible.value = false
    // 清空表单
    createForm.value.aircraft_no = ''
    fetchList()
  } catch {
  }
}

// 更改飞机状态
const changeStatus = (aircraft_no, newStatus) => {
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

// 飞机状态显示
const translateStatus = (status) => {
  const map = {
    'active': '服役中',
    'maintenance': '维修中',
    'retired': '已退役'
  }
  return map[status] || status
}

const getStatusType = (status) => {
  const map = {
    'active': 'success',
    'maintenance': 'warning',
    'retired': 'info'
  }
  return map[status] || 'primary'
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
</style>