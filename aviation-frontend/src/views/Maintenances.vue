<template>
  <div class="app-container">
    <h2>维修工单管理</h2>

    <div style="margin-bottom: 20px; display: flex; gap: 10px;">
      <el-input
        v-model="searchComponentNo"
        placeholder="请输入部件编号 (如 ENG-001) 查询维修历史"
        style="width: 300px"
        @keyup.enter="handleSearch"
      />
      <el-button type="primary" @click="handleSearch">搜索历史</el-button>
      <el-button type="success" @click="openCreateDialog">新增维修工单</el-button>
    </div>

    <el-table :data="records" border style="width: 100%" v-loading="loading">
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
    </el-table>

    <el-divider />

    <div class="section-header">
      <h3>维修计划</h3>
      <el-button type="primary" @click="openPlanDialog">新增维修计划</el-button>
    </div>

    <el-alert
      v-if="planLoadFailed"
      title="维修计划加载失败"
      type="error"
      :closable="false"
      show-icon
      style="margin-bottom: 12px;"
    />
    <el-table v-else :data="planList" border style="width: 100%" v-loading="planLoading">
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
          <el-tag :type="getPlanStatusType(scope.row.status)">
            {{ formatPlanStatus(scope.row.status) }}
          </el-tag>
        </template>
      </el-table-column>
      <el-table-column label="创建人" min-width="110">
        <template #default="scope">{{ scope.row.created_by_name || '未记录' }}</template>
      </el-table-column>
      <el-table-column label="创建时间" min-width="160">
        <template #default="scope">{{ formatTime(scope.row.created_at) }}</template>
      </el-table-column>
      <el-table-column label="操作" width="150" fixed="right">
        <template #default="scope">
          <template v-if="scope.row.status === 'pending'">
            <el-button type="success" link @click="handleCompletePlan(scope.row)">完成</el-button>
            <el-button type="danger" link @click="handleCancelPlan(scope.row)">取消</el-button>
          </template>
          <span v-else>-</span>
        </template>
      </el-table-column>
      <template #empty>
        <el-empty description="暂无维修计划" />
      </template>
    </el-table>


    <el-dialog title="新增维修计划" v-model="planDialogVisible" width="520px">
      <el-form :model="planForm" label-width="130px">
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
        <el-form-item label="创建人">
          <el-select v-model="planForm.created_by" clearable placeholder="请选择创建人" style="width: 100%">
            <el-option
              v-for="op in operatorList"
              :key="op.operator_id"
              :label="op.operator_name + '（' + translateRole(op.role) + '）'"
              :value="op.operator_id"
            />
          </el-select>
        </el-form-item>
        <el-form-item label="关联维修记录 ID">
          <el-input-number
            v-model="planForm.related_maintenance_id"
            :min="1"
            :controls="false"
            placeholder="可选"
            style="width: 100%"
          />
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="planDialogVisible = false">取消</el-button>
        <el-button type="primary" @click="submitPlan">提交</el-button>
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
              v-for="op in operatorList.filter(o => o.role === 'technician' || o.role === 'admin')"
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
        <el-button type="primary" @click="submitCreate">提交</el-button>
      </template>
    </el-dialog>

    <el-dialog title="提报维修结果" v-model="completeVisible" width="500px">
      <el-form :model="completeForm" label-width="100px">
        <el-form-item label="检验结果" required>
          <el-select v-model="completeForm.result" style="width: 100%">
            <el-option label="检验通过（恢复可用）" value="passed" />
            <el-option label="检验未通过（继续拆卸状态）" value="failed" />
            <el-option label="彻底报废（退役）" value="scrapped" />
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
              v-for="op in operatorList.filter(o => o.role === 'approver' || o.role === 'admin')"
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
        <el-button type="primary" @click="submitComplete">提交</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
// 确保你引入了下面这两个接口
import {
  getAllMaintenances,
  getComponentMaintenances,
  createMaintenance,
  completeMaintenance,
  getMaintenancePlans,
  createMaintenancePlan,
  completeMaintenancePlan,
  cancelMaintenancePlan
} from '../api/maintenances'
import { getOperators } from '../api/operators' // 引入获取人员的接口
import { ElMessage } from 'element-plus'
import {
  formatBusinessText,
  formatMaintenanceResult,
  formatMaintenanceType,
  formatPlanStatus,
  formatPlanType
} from '../utils/businessFormatters'

const operatorList = ref([]) // 存储从后端拉取的人员名单
const records = ref([])
const searchComponentNo = ref('')
const loading = ref(false)
const planList = ref([])
const planLoading = ref(false)
const planLoadFailed = ref(false)

const translateRole = (role) => ({
  technician: '维修技师',
  approver: '审批主管',
  admin: '系统管理员'
}[role] || role)

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

const openPlanDialog = () => {
  planForm.value = {
    component_no: searchComponentNo.value,
    planned_type: 'scheduled inspection',
    planned_time: new Date().toISOString().slice(0, 19).replace('T', ' '),
    planned_reason: '',
    created_by: null,
    related_maintenance_id: null
  }
  planDialogVisible.value = true
}

const submitPlan = async () => {
  if (!planForm.value.component_no || !planForm.value.planned_type || !planForm.value.planned_time) {
    return ElMessage.warning('请填写完整的维修计划信息')
  }
  try {
    await createMaintenancePlan(planForm.value)
    ElMessage.success('维修计划创建成功')
    planDialogVisible.value = false
    fetchPlanList()
  } catch {}
}

const handleCompletePlan = async (row) => {
  try {
    await completeMaintenancePlan(row.plan_id, { operator_id: row.created_by || null })
    ElMessage.success('维修计划已完成')
    fetchPlanList()
  } catch {}
}

const handleCancelPlan = async (row) => {
  try {
    await cancelMaintenancePlan(row.plan_id, { operator_id: row.created_by || null })
    ElMessage.success('维修计划已取消')
    fetchPlanList()
  } catch {}
}

const getPlanStatusType = (status) => ({
  pending: 'warning',
  completed: 'success',
  cancelled: 'info'
}[status] || 'info')

const getMaintenanceResultType = (result) => ({
  pending: 'warning',
  passed: 'success',
  failed: 'danger',
  scrapped: 'info'
}[result] || 'info')

const formatTime = (value) => value ? String(value).replace('T', ' ').slice(0, 19) : '-'


// === 创建工单逻辑 ===
const createVisible = ref(false)
const createForm = ref({})

const openCreateDialog = () => {
  createForm.value = {
    component_no: searchComponentNo.value, // 默认带入当前搜索的部件
    maintenance_type: 'routine',
    start_time: new Date().toISOString().slice(0, 19).replace('T', ' '),
    description: '',
    technician_id: 1 // 模拟当前操作的维修人员ID
  }
  createVisible.value = true
}

const submitCreate = async () => {
  if (!createForm.value.component_no) return ElMessage.error('部件编号必填')
  try {
    await createMaintenance(createForm.value)
    ElMessage.success('工单创建成功！')
    createVisible.value = false
    // 创建成功后自动查询该部件的记录
    searchComponentNo.value = createForm.value.component_no
    handleSearch()
  } catch {}
}

// === 完成维修逻辑 ===
const completeVisible = ref(false)
const completeForm = ref({})

const openCompleteDialog = (row) => {
  completeForm.value = {
    maintenance_id: row.maintenance_id,
    component_no: searchComponentNo.value, // 用于刷新列表
    end_time: new Date().toISOString().slice(0, 19).replace('T', ' '),
    result: 'passed',
    description: '',
    approved_by: 1, // 模拟审批人ID
    retirement_reason: ''
  }
  completeVisible.value = true
}

const submitComplete = async () => {
  if (completeForm.value.result === 'scrapped' && !completeForm.value.retirement_reason) {
    return ElMessage.error('选择报废时必须填写退役原因！')
  }
  try {
    await completeMaintenance(completeForm.value.maintenance_id, completeForm.value)
    ElMessage.success('维修结果提报成功！部件状态已同步流转。')
    completeVisible.value = false
    handleSearch() // 刷新列表，看到状态变成 passed/failed
  } catch {}
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
</style>
