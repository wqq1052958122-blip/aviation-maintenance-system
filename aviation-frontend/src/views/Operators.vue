<template>
  <div class="app-container">
    <div class="page-header">
      <div><h2>操作人员</h2><p>管理维修、安装、退役等关键业务操作人员</p></div>
      <el-button type="primary" @click="createVisible = true">
        <el-icon><Plus /></el-icon> 新增员工
      </el-button>
    </div>

    <div class="filter-panel">
      <el-form class="filter-form" inline>
        <el-form-item label="人员姓名"><el-input v-model="filters.name" clearable placeholder="输入姓名" style="width: 180px" /></el-form-item>
        <el-form-item label="角色"><el-select v-model="filters.role" clearable placeholder="全部角色" style="width: 150px"><el-option label="安装专员" value="installer" /><el-option label="维修技师" value="technician" /><el-option label="审批主管" value="approver" /><el-option label="系统管理员" value="admin" /></el-select></el-form-item>
        <el-form-item><div class="filter-actions"><el-button type="primary" @click="applyFilters">搜索</el-button><el-button @click="resetFilters">重置</el-button><el-button @click="fetchList">刷新</el-button></div></el-form-item>
      </el-form>
    </div>

    <el-table :data="pagedOperators" border style="width: 100%" v-loading="loading" element-loading-text="正在加载数据...">
      <el-table-column prop="operator_id" label="工号" width="80" align="center" />
      <el-table-column prop="operator_name" label="姓名" width="150" />
      
      <el-table-column label="系统角色" width="180">
        <template #default="scope">
          <el-tag v-if="scope.row.role === 'installer'" type="primary">安装专员</el-tag>
          <el-tag v-else-if="scope.row.role === 'technician'" type="warning">维修技师</el-tag>
          <el-tag v-else-if="scope.row.role === 'approver'" type="success">审批主管</el-tag>
          <el-tag v-else-if="scope.row.role === 'admin'" type="danger">系统管理员</el-tag>
          <el-tag v-else>{{ scope.row.role }}</el-tag>
        </template>
      </el-table-column>

      <el-table-column prop="phone" label="联系电话" />
      <el-table-column prop="created_at" label="入职时间" width="180">
  <template #default="scope">
    {{ scope.row.created_at ? scope.row.created_at.replace('T', ' ').substring(0, 16) : '未知' }}
  </template>
</el-table-column>
      <template #empty><el-empty description="暂无数据" /></template>
    </el-table>
    <ListPagination v-model:page="currentPage" v-model:page-size="pageSize" :total="filteredOperators.length" />

    <el-dialog title="新增员工" v-model="createVisible" width="400px">
      <el-form :model="form" label-width="80px">
        <el-form-item label="姓名" required>
          <el-input v-model="form.operator_name" placeholder="如：张三" />
        </el-form-item>
        <el-form-item label="角色" required>
          <el-select v-model="form.role" style="width: 100%">
            <el-option label="安装专员" value="installer" />
            <el-option label="维修技师" value="technician" />
            <el-option label="审批主管" value="approver" />
            <el-option label="系统管理员" value="admin" />
          </el-select>
        </el-form-item>
        <el-form-item label="电话">
          <el-input v-model="form.phone" placeholder="选填" />
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="createVisible = false">取消</el-button>
        <el-button type="primary" :loading="submitting" @click="submitCreate">提交</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<script setup>
import { computed, reactive, ref, onMounted, watch } from 'vue'
import { getOperators, createOperator } from '../api/operators'
import { ElMessage } from 'element-plus'
import ListPagination from '../components/ListPagination.vue'

const operatorList = ref([])
const loading = ref(false)
const createVisible = ref(false)
const submitting = ref(false)
const form = ref({ operator_name: '', role: 'installer', phone: '' })
const filters = reactive({ name: '', role: '' })
const appliedFilters = reactive({ ...filters })
const currentPage = ref(1)
const pageSize = ref(10)
const filteredOperators = computed(() => operatorList.value.filter(item =>
  String(item.operator_name || '').toLowerCase().includes(appliedFilters.name.trim().toLowerCase())
  && (!appliedFilters.role || item.role === appliedFilters.role)
))
const pagedOperators = computed(() => {
  const start = (currentPage.value - 1) * pageSize.value
  return filteredOperators.value.slice(start, start + pageSize.value)
})
watch(() => filteredOperators.value.length, total => {
  currentPage.value = Math.min(currentPage.value, Math.max(1, Math.ceil(total / pageSize.value)))
})
const applyFilters = () => {
  Object.assign(appliedFilters, filters)
  currentPage.value = 1
}
const resetFilters = () => {
  Object.assign(filters, { name: '', role: '' })
  applyFilters()
}

const fetchList = async () => {
  loading.value = true
  try {
    const res = await getOperators()
    operatorList.value = res.data || res || []
  } catch {} finally {
    loading.value = false
  }
}

const submitCreate = async () => {
  if (!form.value.operator_name) return ElMessage.warning('姓名不能为空')
  if (submitting.value) return
  submitting.value = true
  try {
    await createOperator(form.value)
    ElMessage.success('员工新增成功')
    createVisible.value = false
    form.value = { operator_name: '', role: 'installer', phone: '' }
    fetchList()
  } catch {} finally {
    submitting.value = false
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
