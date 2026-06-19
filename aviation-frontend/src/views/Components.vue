<template>
  <div class="app-container">
    <div class="header-action">
      <h2>零部件库存与生命周期管理</h2>
      <el-button type="primary" @click="openCreateDialog">登记新部件入库</el-button>
    </div>

    <el-table :data="componentList" border style="width: 100%" v-loading="loading">
      <el-table-column prop="component_id" label="ID" width="60" />
      <el-table-column prop="component_no" label="部件编号" width="150" />
      <el-table-column prop="model_id" label="型号ID" width="80" />
      <el-table-column prop="batch_no" label="生产批次" />
      <el-table-column prop="total_flight_hours" label="总飞行小时" width="120" />
      
      <el-table-column label="当前状态" width="120">
        <template #default="scope">
          <el-tag v-if="scope.row.status === 'in_stock'" type="info">在库</el-tag>
          <el-tag v-else-if="scope.row.status === 'available'" type="success">可用</el-tag>
          <el-tag v-else-if="scope.row.status === 'installed'" type="primary">已安装</el-tag>
          <el-tag v-else-if="scope.row.status === 'removed'" type="warning">已拆卸/待修</el-tag>
          <el-tag v-else-if="scope.row.status === 'retired'" type="danger">已退役</el-tag>
          <el-tag v-else>{{ scope.row.status }}</el-tag>
        </template>
      </el-table-column>

      <el-table-column label="操作" width="220">
        <template #default="scope">
          <el-button type="info" size="small" @click="openProfileDrawer(scope.row.component_no)">
            生命周期溯源
          </el-button>
          <el-button 
            v-if="!scope.row.is_retired && scope.row.status !== 'installed'" 
            type="danger" 
            size="small" 
            @click="openRetireDialog(scope.row)">
            退役
          </el-button>
        </template>
      </el-table-column>
    </el-table>

    <el-drawer v-model="drawerVisible" :title="`部件档案溯源: ${currentComponentNo}`" size="40%">
      <div v-loading="drawerLoading">
        <el-descriptions title="基础档案信息" :column="2" border style="margin-bottom: 20px;">
          <el-descriptions-item label="部件编号">{{ profileData.component_no }}</el-descriptions-item>
          <el-descriptions-item label="所属类别">{{ profileData.category }}</el-descriptions-item>
          <el-descriptions-item label="生产批次">{{ profileData.batch_no }}</el-descriptions-item>
          <el-descriptions-item label="总飞行时长">{{ profileData.stored_total_flight_hours }} 小时</el-descriptions-item>
        </el-descriptions>

        <h3>历史轨迹 (Timeline)</h3>
        <el-timeline style="margin-top: 15px;">
          <el-timeline-item
  v-for="(event, index) in lifecycleData"
  :key="index"
  :timestamp="formatTime(event.event_time)"
  :type="getTimelineType(event.event_type)"
  placement="top"
>
  <el-card shadow="hover">
    <h4>{{ translateEventType(event.event_type) }}</h4>
    <p>{{ event.event_detail }}</p>
  </el-card>
</el-timeline-item>
          <el-empty v-if="lifecycleData.length === 0" description="暂无历史记录" />
        </el-timeline>
      </div>
    </el-drawer>

    <el-dialog title="新部件入库登记" v-model="createVisible" width="500px">
      <el-form :model="createForm" label-width="100px">
        <el-form-item label="部件编号" required>
          <el-input v-model="createForm.component_no" placeholder="如 ENG-004" />
        </el-form-item>
        <el-form-item label="型号ID" required>
          <el-input-number v-model="createForm.model_id" :min="1" />
        </el-form-item>
        <el-form-item label="生产批次">
          <el-input v-model="createForm.batch_no" />
        </el-form-item>
        <el-form-item label="生产日期" required>
          <el-date-picker v-model="createForm.production_date" type="date" value-format="YYYY-MM-DD" style="width: 100%" />
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="createVisible = false">取消</el-button>
        <el-button type="primary" @click="submitCreate">确认入库</el-button>
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
        <el-form-item label="备注说明">
          <el-input v-model="retireForm.remark" type="textarea" />
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="retireVisible = false">取消</el-button>
        <el-button type="danger" @click="submitRetire">确认退役</el-button>
      </template>
    </el-dialog>

  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { getComponents, createComponent, getComponentProfile, getComponentLifecycle, retireComponent, getComponentModels } from '../api/components'
import { ElMessage } from 'element-plus'

// 2. 定义变量
const componentList = ref([])
const modelList = ref([]) // 用于存放型号数据
const loading = ref(false)
const modelLoading = ref(false)

// 3. 定义获取型号的函数
const fetchModels = async () => {
  modelLoading.value = true
  try {
    const res = await getComponentModels()
    // 根据实际情况取 data，有些后端直接返回数组
    modelList.value = res.data || res || []
  } catch (error) {
    console.error("获取型号字典失败:", error)
    ElMessage.error('型号字典加载失败')
  } finally {
    modelLoading.value = false
  }
}

// 4. 在组件挂载时同时调用两个获取函数
onMounted(() => {
  fetchList()    // 原有的部件实例获取
  fetchModels()  // 新增的型号字典获取
})

const fetchList = async () => {
  loading.value = true
  try {
    const res = await getComponents()
    componentList.value = res.data || res || []
    // 关键调试：看一眼数据结构
    console.log("部件实例数据:", componentList.value[0]) 
  } catch (error) {
    console.error(error)
  } finally {
    loading.value = false
  }
}

// --- 生命周期溯源逻辑 (抽屉) ---
const drawerVisible = ref(false)
const drawerLoading = ref(false)
const currentComponentNo = ref('')
const profileData = ref({})
const lifecycleData = ref([])

const openProfileDrawer = async (component_no) => {
  currentComponentNo.value = component_no
  drawerVisible.value = true
  drawerLoading.value = true
  
  try {
    const profileRes = await getComponentProfile(component_no)
    const lifecycleRes = await getComponentLifecycle(component_no)
    
    // 1. 档案数据提取
    profileData.value = profileRes.data || profileRes || {}
    
    // 2. 【关键修正】：这里 lifecycleRes 本身是一个对象 { component_no: '...', timeline: [...] }
    // 你需要取它的 .timeline 属性！
    const rawLifecycle = lifecycleRes.data || lifecycleRes;
    lifecycleData.value = rawLifecycle.timeline || []; // 从 timeline 字段取数组
    
  } catch (error) {
    console.error(error)
    const errorDetail = error.response?.data?.detail || error.message || String(error)
ElMessage.error(translateErrorMsg(errorDetail))
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
    'RETIRE': 'danger'
  }
  // 如果数据库的事件类型名字不一样，它会默认返回灰色
  return map[eventType] || ''
}

// --- 入库逻辑 ---
const createVisible = ref(false)
const createForm = ref({})

const openCreateDialog = () => {
  createForm.value = {
    component_no: '',
    model_id: 1,
    batch_no: '',
    production_date: ''
  }
  createVisible.value = true
}

const submitCreate = async () => {
  if (!createForm.value.component_no) return ElMessage.warning('请填写部件编号')
  try {
    await createComponent(createForm.value)
    ElMessage.success('新部件入库成功')
    createVisible.value = false
    fetchList()
  } catch (error) {
    console.error(error)
  }
}

// --- 退役逻辑 ---
const retireVisible = ref(false)
const retireForm = ref({})
const retireTarget = ref('')

const openRetireDialog = (row) => {
  retireTarget.value = row.component_no
  retireForm.value = {
    retirement_time: new Date().toISOString().slice(0, 19).replace('T', ' '),
    retirement_reason: '',
    approved_by: 1, // 模拟审批人ID
    remark: ''
  }
  retireVisible.value = true
}

const submitRetire = async () => {
  if (!retireForm.value.retirement_reason) return ElMessage.warning('退役原因必填')
  try {
    await retireComponent(retireTarget.value, retireForm.value)
    ElMessage.success('退役处理成功')
    retireVisible.value = false
    fetchList() // 刷新列表，状态将变为 retired
  } catch (error) {
    console.error(error)
  }
}

onMounted(() => {
  fetchList()
})

// 1. 时间格式化：把 T 替换掉，只保留年月日时分
const formatTime = (timeStr) => {
  if (!timeStr) return '';
  return timeStr.replace('T', ' ').substring(0, 16);
}

// 2. 事件类型翻译
const translateEventType = (type) => {
  const map = {
    'STOCK_IN': '入库登记',
    'INSTALL': '安装上机',
    'UNINSTALL': '下机拆卸',
    'MAINTENANCE': '维修维护',
    'RETIRE': '报废退役',
    'installed': '安装上机',
    'removed': '下机拆卸',
    'maintenance_start': '维修开始',
    'maintenance_end': '维修结束',
    'in_stock': '入库登记',
    'left engine position': '左侧发动机',
  'right engine position': '右侧发动机',
  'navigation bay': '导航舱',
  'main landing gear': '主起落架',
  'nose': '机头雷达罩',
  'tail': '尾翼'
  }
  return map[type] || type;
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
.header-action {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 20px;
}
</style>