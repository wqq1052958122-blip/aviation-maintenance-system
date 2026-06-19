<template>
  <div class="app-container">
    <div class="header-action">
      <h2>航空维修人员名册</h2>
      <el-button type="primary" @click="createVisible = true">
        <el-icon><Plus /></el-icon> 录入新员工
      </el-button>
    </div>

    <el-table :data="operatorList" border style="width: 100%" v-loading="loading">
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
    </el-table>

    <el-dialog title="录入新员工" v-model="createVisible" width="400px">
      <el-form :model="form" label-width="80px">
        <el-form-item label="姓名" required>
          <el-input v-model="form.operator_name" placeholder="如：张三" />
        </el-form-item>
        <el-form-item label="角色" required>
          <el-select v-model="form.role" style="width: 100%">
            <el-option label="安装专员 (Installer)" value="installer" />
            <el-option label="维修技师 (Technician)" value="technician" />
            <el-option label="审批主管 (Approver)" value="approver" />
            <el-option label="系统管理员 (Admin)" value="admin" />
          </el-select>
        </el-form-item>
        <el-form-item label="电话">
          <el-input v-model="form.phone" placeholder="选填" />
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="createVisible = false">取消</el-button>
        <el-button type="primary" @click="submitCreate">确认录入</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { getOperators, createOperator } from '../api/operators'
import { ElMessage } from 'element-plus'

const operatorList = ref([])
const loading = ref(false)
const createVisible = ref(false)
const form = ref({ operator_name: '', role: 'installer', phone: '' })

const fetchList = async () => {
  loading.value = true
  try {
    const res = await getOperators()
    operatorList.value = res.data || res || []
  } catch (e) {
    console.error(e)
  } finally {
    loading.value = false
  }
}

const submitCreate = async () => {
  if (!form.value.operator_name) return ElMessage.warning('姓名不能为空')
  try {
    await createOperator(form.value)
    ElMessage.success('新员工录入成功！')
    createVisible.value = false
    form.value = { operator_name: '', role: 'installer', phone: '' }
    fetchList()
  } catch (e) {
    ElMessage.error('录入失败')
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
