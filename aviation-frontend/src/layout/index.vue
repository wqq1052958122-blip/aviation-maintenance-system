<template>
  <router-view v-if="$route.meta.landing" />
  <el-container v-else class="layout-container">
    <el-aside width="200px" class="aside">
      <div class="logo">航空维修管理系统</div>
      <el-menu
        active-text-color="#ffffff"
        background-color="transparent"
        text-color="#fff"
        :default-active="$route.path"
        router
      >
       <el-menu-item index="/dashboard">
  <el-icon><Odometer /></el-icon>
  <template #title>系统仪表盘</template>
</el-menu-item>

<el-menu-item index="/components">
  <el-icon><Box /></el-icon>
  <template #title>部件档案管理</template>
</el-menu-item>

<el-menu-item index="/installations">
  <el-icon><Connection /></el-icon>
  <template #title>安装与拆卸</template>
</el-menu-item>

<el-menu-item index="/maintenances">
  <el-icon><Tools /></el-icon>
  <template #title>维修管理</template>
</el-menu-item>

<el-menu-item index="/flights">
  <el-icon><VideoPlay /></el-icon>
  <template #title>飞行日志</template>
</el-menu-item>

<el-menu-item index="/operators">
  <el-icon><User /></el-icon>
  <template #title>人员管理</template>
</el-menu-item>

<el-menu-item index="/aircrafts">
  <el-icon><Position /></el-icon>
  <template #title>机队管理</template>
</el-menu-item>
      </el-menu>
    </el-aside>
    <el-container>
      <el-header class="header">
  <div class="header-left" style="display: flex; align-items: center; gap: 10px;">
    <el-icon size="20" color="#409EFF"><Guide /></el-icon>
    <strong style="font-size: 18px; color: #303133;">
      航空部件生命周期与维修管理系统
    </strong>
  </div>
  <router-link to="/" class="home-link">
    <el-icon><House /></el-icon>
    系统首页
  </router-link>
</el-header>
      <el-main class="main">
        <router-view />
      </el-main>
    </el-container>
  </el-container>
</template>


<style scoped>
.layout-container {
  height: 100vh;
}
.aside {
  background: linear-gradient(180deg, #062b52 0%, #074b82 58%, #06365f 100%);
  box-shadow: 4px 0 18px rgba(5, 42, 75, 0.16);
}
.logo {
  height: 60px;
  line-height: 60px;
  text-align: center;
  color: #fff;
  font-size: 16px;
  font-weight: bold;
  border-bottom: 1px solid rgba(255, 255, 255, 0.14);
  letter-spacing: 1px;
  background: rgba(255, 255, 255, 0.04);
}
.aside :deep(.el-menu) {
  border-right: 0;
  padding: 12px 10px;
}
.aside :deep(.el-menu-item) {
  margin-bottom: 6px;
  border-radius: 9px;
}
.aside :deep(.el-menu-item:hover) {
  background: rgba(255, 255, 255, 0.1) !important;
}
.aside :deep(.el-menu-item.is-active) {
  background: linear-gradient(90deg, #1677c8, #2f9be8) !important;
  box-shadow: 0 6px 16px rgba(0, 94, 171, 0.28);
}
.header {
  background-color: #fff;
  border-bottom: 1px solid #e3edf6;
  display: flex;
  align-items: center;
  padding: 0 24px;
  justify-content: space-between;
  box-shadow: 0 3px 14px rgba(15, 70, 112, 0.06);
}
.main {
  background: #f3f7fb;
  padding: 24px;
}
.home-link {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  color: #1769aa;
  text-decoration: none;
  font-size: 14px;
  font-weight: 600;
}
</style>
