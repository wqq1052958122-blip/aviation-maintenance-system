<template>
  <div id="app">
    <router-view />
  </div>
</template>

<script setup>
// 根组件暂时不需要写任何逻辑
</script>

<style>
/* 重置一下基础样式，让页面撑满浏览器 */
html, body, #app {
  margin: 0;
  padding: 0;
  min-height: 100%;
  width: 100%;
}
</style>
