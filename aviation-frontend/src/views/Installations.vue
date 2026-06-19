<template>
  <div class="app-container">
    <div class="header-action">
      <h2>机载部件安装与管理</h2>
      <el-button type="primary" @click="openInstallDialog">
        <el-icon><Plus /></el-icon> 新增安装
      </el-button>
    </div>
    
    <el-table :data="installations" border style="width: 100%" v-loading="loading">
      <el-table-column prop="aircraft_no" label="飞机编号" />
      <el-table-column prop="install_position" label="安装位置">
  <template #default="scope">
    {{ translatePosition(scope.row.install_position) }}
  </template>
</el-table-column>
      <el-table-column prop="component_no" label="当前部件" />
      <el-table-column label="部件状态">
        <template #default="scope">
          <el-tag :type="getComponentStatusType(scope.row.component_status)">
            {{ translateComponentStatus(scope.row.component_status) }}
          </el-tag>
        </template>
      </el-table-column>
      <el-table-column prop="install_time" label="安装时间" width="180" />
      <el-table-column label="操作" width="220" fixed="right">
        <template #default="scope">
          <el-button type="warning" size="small" @click="openUninstallDialog(scope.row)">拆卸</el-button>
          <el-button type="primary" size="small" @click="openReplaceDialog(scope.row)">更换</el-button>
        </template>
      </el-table-column>
    </el-table>

    <!-- 新增安装弹窗 -->
    <el-dialog title="新增部件安装" v-model="installDialogVisible" width="500px">
      <el-form :model="installForm" label-width="120px">
        <el-form-item label="部件编号" required>
          <el-input v-model="installForm.component_no" placeholder="输入部件编号" @change="loadInstallPositions" />
        </el-form-item>
        <el-form-item label="飞机编号" required>
          <el-input v-model="installForm.aircraft_no" placeholder="输入飞机编号" @change="loadInstallPositions" />
        </el-form-item>
        <el-form-item label="安装位置" required>
          <el-select
            v-model="installForm.install_position"
            placeholder="请先输入飞机编号和部件编号"
            style="width: 100%"
            :disabled="!installForm.aircraft_no || !installForm.component_no"
            @visible-change="visible => visible && loadInstallPositions(false)"
          >
            <el-option
              v-for="pos in installPositionOptions"
              :key="pos.position_id"
              :label="`${pos.position_name}（${translateCategory(pos.allowed_category)}）${pos.is_occupied ? ' - 已占用' : ''}`"
              :value="pos.position_code"
              :disabled="Boolean(pos.is_occupied)"
            />
          </el-select>
        </el-form-item>
        <el-form-item label="安装时间" required>
          <el-date-picker 
            v-model="installForm.install_time" 
            type="datetime" 
            value-format="YYYY-MM-DD HH:mm:ss" 
            style="width: 100%"
          />
        </el-form-item>
        <el-form-item label="安装原因">
          <el-input v-model="installForm.install_reason" type="textarea" />
        </el-form-item>
        <el-form-item label="操作人员" required>
  <el-select v-model="installForm.operator_id" placeholder="请选择操作人" style="width: 100%">
    <el-option 
      v-for="op in operatorList.filter(o => o.role === 'installer')" 
      :key="op.operator_id" 
      :label="op.operator_name + '（' + translateRole(op.role) + '）'" 
      :value="op.operator_id" 
    />
  </el-select>
</el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="installDialogVisible = false">取消</el-button>
        <el-button type="primary" @click="handleInstall">确认安装</el-button>
      </template>
    </el-dialog>

    <!-- 拆卸弹窗 -->
    <el-dialog title="部件拆卸" v-model="uninstallDialogVisible" width="500px">
      <el-form :model="uninstallForm" label-width="120px">
        <el-form-item label="当前部件"> {{ uninstallForm.component_no }} </el-form-item>
        <el-form-item label="所属飞机"> {{ uninstallForm.aircraft_no }} </el-form-item>
        <el-form-item label="拆卸时间" required>
          <el-date-picker 
            v-model="uninstallForm.uninstall_time" 
            type="datetime" 
            value-format="YYYY-MM-DD HH:mm:ss" 
            style="width: 100%"
          />
        </el-form-item>
        <el-form-item label="拆卸原因" required>
          <el-input v-model="uninstallForm.uninstall_reason" type="textarea" />
        </el-form-item>
        <el-form-item label="操作人员" required>
          <el-select v-model="uninstallForm.uninstall_operator_id" placeholder="请选择拆卸人员" style="width: 100%">
            <el-option
              v-for="op in operatorList.filter(o => o.role === 'installer')"
              :key="op.operator_id"
              :label="op.operator_name + '（' + translateRole(op.role) + '）'"
              :value="op.operator_id"
            />
          </el-select>
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="uninstallDialogVisible = false">取消</el-button>
        <el-button type="warning" @click="handleUninstall">确认拆卸</el-button>
      </template>
    </el-dialog>

    <!-- 更换弹窗 -->
    <el-dialog title="部件更换" v-model="replaceDialogVisible" width="500px">
      <el-form :model="replaceForm" label-width="120px">
        <el-form-item label="当前飞机"> {{ replaceForm.aircraft_no }} </el-form-item>
        <el-form-item label="旧部件"> {{ replaceForm.old_component_no }} </el-form-item>
        <el-form-item label="新部件编号" required>
          <el-input v-model="replaceForm.new_component_no" placeholder="输入待装部件" />
        </el-form-item>
        <el-form-item label="拆卸原因" required>
          <el-input v-model="replaceForm.uninstall_reason" type="textarea" />
        </el-form-item>
        <el-form-item label="安装原因">
          <el-input v-model="replaceForm.install_reason" type="textarea" />
        </el-form-item>
        <el-form-item label="操作人员" required>
          <el-select v-model="replaceForm.operator_id" placeholder="请选择更换操作人员" style="width: 100%">
            <el-option
              v-for="op in operatorList.filter(o => o.role === 'installer')"
              :key="op.operator_id"
              :label="op.operator_name + '（' + translateRole(op.role) + '）'"
              :value="op.operator_id"
            />
          </el-select>
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="replaceDialogVisible = false">取消</el-button>
        <el-button type="primary" @click="handleReplace">确认更换</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { Plus } from '@element-plus/icons-vue'
import { getActiveInstallations, getInstallPositions, installComponent, uninstallComponent, replaceComponent } from '../api/installations'
import { ElMessage } from 'element-plus'
import { getOperators } from '../api/operators' // 引入接口

const operatorList = ref([]) // 存下拉框的数据
const installPositionOptions = ref([])

const translateRole = (role) => ({
  installer: '安装人员',
  technician: '维修技师',
  approver: '审批主管',
  admin: '系统管理员'
}[role] || role)

const translateCategory = (category) => ({
  engine: '发动机类',
  navigation: '导航类',
  hydraulic: '液压类',
  battery: '电池类',
  avionics: '航电类',
  landing_gear: '起落架类'
}[category] || category)

const getDefaultOperatorId = (role) => {
  return operatorList.value.find(op => op.role === role)?.operator_id || null
}

// 在 onMounted 里调用它：
onMounted(async () => {
  fetchData() // 之前的加载列表
  // 顺便把系统所有人员查出来
  const res = await getOperators()
  operatorList.value = res.data || res || []
})

const componentStatusMap = {
  in_stock: { label: '在库', type: 'info' },
  available: { label: '可用', type: 'success' },
  installed: { label: '已安装', type: 'primary' },
  removed: { label: '已拆卸', type: 'warning' },
  under_maintenance: { label: '维修中', type: 'warning' },
  retired: { label: '已退役', type: 'danger' }
}

const translateComponentStatus = (status) => componentStatusMap[status]?.label || status
const getComponentStatusType = (status) => componentStatusMap[status]?.type || 'info'

// 翻译安装位置（用于表格展示）
const translatePosition = (pos) => {
  const map = {
    'left engine position': '左侧发动机',
    'right engine position': '右侧发动机',
    'navigation bay': '导航舱',
    'hydraulic system bay': '液压系统舱',
    'main landing gear': '主起落架',
    'nose': '机头雷达罩',
    'tail': '尾翼'
  }
  return map[pos] || pos;
}

const installations = ref([])
const loading = ref(false)

const installDialogVisible = ref(false)
const installForm = ref({
  component_no: '',
  aircraft_no: '',
  install_position: '',
  install_time: '',
  install_reason: '',
  operator_id: null
})

const uninstallDialogVisible = ref(false)
const uninstallForm = ref({
  installation_id: null,
  component_no: '',
  aircraft_no: '',
  uninstall_time: '',
  uninstall_reason: '',
  uninstall_operator_id: null
})

const replaceDialogVisible = ref(false)
const replaceForm = ref({})

const fetchData = async () => {
  loading.value = true
  installations.value = await getActiveInstallations()
  loading.value = false
}

const loadInstallPositions = async (resetSelected = true) => {
  if (resetSelected) installForm.value.install_position = ''
  installPositionOptions.value = []
  if (!installForm.value.aircraft_no || !installForm.value.component_no) return
  try {
    installPositionOptions.value = await getInstallPositions({
      aircraft_no: installForm.value.aircraft_no,
      component_no: installForm.value.component_no
    })
  } catch {}
}

const openInstallDialog = () => {
  const now = new Date()
  installForm.value = {
    component_no: '',
    aircraft_no: '',
    install_position: '',
    install_time: formatDateTime(now),
    install_reason: '正常安装',
    operator_id: getDefaultOperatorId('installer')
  }
  installPositionOptions.value = []
  installDialogVisible.value = true
}

const handleInstall = async () => {
  if (!installForm.value.component_no || !installForm.value.aircraft_no || !installForm.value.install_position || !installForm.value.install_time) {
    ElMessage.warning('请填写必填项')
    return
  }
  if (!installForm.value.operator_id) {
    ElMessage.warning('请选择安装人员')
    return
  }
  try {
    await installComponent(installForm.value)
    ElMessage.success('安装成功！')
    installDialogVisible.value = false
    fetchData()
  } catch {}
}

const openUninstallDialog = (row) => {
  const now = new Date()
  uninstallForm.value = {
    installation_id: row.installation_id,
    component_no: row.component_no,
    aircraft_no: row.aircraft_no,
    uninstall_time: formatDateTime(now),
    uninstall_reason: '',
    uninstall_operator_id: getDefaultOperatorId('installer')
  }
  uninstallDialogVisible.value = true
}

const handleUninstall = async () => {
  if (!uninstallForm.value.uninstall_time || !uninstallForm.value.uninstall_reason) {
    ElMessage.warning('请填写拆卸时间和原因')
    return
  }
  if (!uninstallForm.value.uninstall_operator_id) {
    ElMessage.warning('请选择拆卸人员')
    return
  }
  try {
    await uninstallComponent(uninstallForm.value.installation_id, {
      uninstall_time: uninstallForm.value.uninstall_time,
      uninstall_reason: uninstallForm.value.uninstall_reason,
      uninstall_operator_id: uninstallForm.value.uninstall_operator_id
    })
    ElMessage.success('拆卸成功')
    uninstallDialogVisible.value = false
    fetchData()
  } catch {}
}

const openReplaceDialog = (row) => {
  const now = new Date()
  replaceForm.value = {
    aircraft_no: row.aircraft_no,
    old_component_no: row.component_no,
    new_component_no: '',
    install_position: row.install_position,
    replace_time: formatDateTime(now),
    operator_id: getDefaultOperatorId('installer'),
    install_reason: '常规更换',
    uninstall_reason: '部件磨损更换'
  }
  replaceDialogVisible.value = true
}

const handleReplace = async () => {
  if (!replaceForm.value.new_component_no || !replaceForm.value.operator_id) {
    ElMessage.warning('请填写新部件编号并选择更换操作人员')
    return
  }
  try {
    await replaceComponent(replaceForm.value);
    ElMessage.success('更换成功！');
    replaceDialogVisible.value = false;
    fetchData();
  } catch {}
}

const formatDateTime = (date) => {
  return date.getFullYear() + '-' + 
    String(date.getMonth() + 1).padStart(2, '0') + '-' + 
    String(date.getDate()).padStart(2, '0') + ' ' + 
    String(date.getHours()).padStart(2, '0') + ':' + 
    String(date.getMinutes()).padStart(2, '0') + ':' + 
    String(date.getSeconds()).padStart(2, '0')
}

</script>

<style scoped>
.header-action {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 20px;
}
</style>

