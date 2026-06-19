<!-- <template>
  <el-container class="layout-container">
    <el-aside width="200px" class="aside">
      <div class="logo">航空维修管理系统</div>
      <el-menu
        active-text-color="#ffd04b"
        background-color="#304156"
        text-color="#fff"
        :default-active="$route.path"
        router
      >
        <el-menu-item index="/dashboard">
          <el-icon><DataBoard /></el-icon>
          <span>系统仪表盘</span>
        </el-menu-item>
        <el-menu-item index="/components">
          <el-icon><Box /></el-icon>
          <span>部件档案管理</span>
        </el-menu-item>
        <el-menu-item index="/installations">
          <el-icon><Setting /></el-icon>
          <span>安装与拆卸</span>
        </el-menu-item>
      </el-menu>
    </el-aside>

    <el-container>
      <el-header class="header">
        <div class="header-left">
          <strong>当前操作人: Admin</strong>
        </div>
      </el-header>

      <el-main class="main">
        <router-view />
      </el-main>
    </el-container>
  </el-container>
</template>

<script setup>
import { DataBoard, Box, Setting } from '@element-plus/icons-vue'
</script>

<style scoped>
.layout-container {
  height: 100vh;
}
.aside {
  background-color: #304156;
}
.logo {
  height: 60px;
  line-height: 60px;
  text-align: center;
  color: #fff;
  font-size: 16px;
  font-weight: bold;
  border-bottom: 1px solid #1f2d3d;
}
.header {
  background-color: #fff;
  border-bottom: 1px solid #e6e6e6;
  display: flex;
  align-items: center;
  padding: 0 20px;
}
.main {
  background-color: #f0f2f5;
  padding: 20px;
}
</style> -->

<template>
  <el-container class="layout-container">
    <el-aside width="200px" class="aside">
      <div class="logo">航空维修管理系统</div>
      <el-menu
        active-text-color="#ffd04b"
        background-color="#304156"
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
  
</el-header>
      <el-main class="main">
        <router-view />
      </el-main>
    </el-container>
  </el-container>
</template>

<script setup>
// 引入所有图标（也可以只引入你用到的）
import * as ElementPlusIconsVue from '@element-plus/icons-vue'

// 这里的代码会自动帮你把图标注册到 Vue 全局，这样你在模板里直接写 <el-icon><Connection /></el-icon> 就不会报错了
</script>

<style scoped>
.layout-container {
  height: 100vh;
}
.aside {
  background-color: #304156;
}
.logo {
  height: 60px;
  line-height: 60px;
  text-align: center;
  color: #fff;
  font-size: 16px;
  font-weight: bold;
  border-bottom: 1px solid #1f2d3d;
}
.header {
  background-color: #fff;
  border-bottom: 1px solid #e6e6e6;
  display: flex;
  align-items: center;
  padding: 0 20px;
}
.main {
  background-color: #f0f2f5;
  padding: 20px;
}
</style>