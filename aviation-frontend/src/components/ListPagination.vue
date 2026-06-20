<template>
  <div v-if="total > 0" class="list-pagination">
    <el-pagination
      background
      layout="total, sizes, prev, pager, next, jumper"
      :total="total"
      :current-page="page"
      :page-size="pageSize"
      :page-sizes="pageSizes"
      @update:current-page="$emit('update:page', $event)"
      @update:page-size="handlePageSizeChange"
    />
  </div>
</template>

<script setup>
const props = defineProps({
  total: { type: Number, default: 0 },
  page: { type: Number, default: 1 },
  pageSize: { type: Number, default: 10 },
  pageSizes: { type: Array, default: () => [10, 20, 50] }
})

const emit = defineEmits(['update:page', 'update:pageSize'])
const handlePageSizeChange = (value) => {
  emit('update:pageSize', value)
  emit('update:page', 1)
}
</script>

<style scoped>
.list-pagination {
  display: flex;
  justify-content: flex-end;
  padding: 18px 0 4px;
  overflow-x: auto;
}
</style>
