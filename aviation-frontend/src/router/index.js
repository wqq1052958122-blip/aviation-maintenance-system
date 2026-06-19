import { createRouter, createWebHistory } from 'vue-router'
import Layout from '../layout/index.vue'

const routes = [
  {
    path: '/',
    component: Layout,
    redirect: '/dashboard',
    children: [
      {
        path: 'dashboard',
        name: 'Dashboard',
        component: () => import('../views/Dashboard.vue')
      },
      {
        path: 'components',
        name: 'Components',
        component: () => import('../views/Components.vue')
      },
      {
        path: 'installations',
        name: 'Installations',
        component: () => import('../views/Installations.vue')
      },
      {
        path: 'maintenances',
        name: 'Maintenances',
        component: () => import('../views/Maintenances.vue')
      },
      {
        path: 'flights',
        name: 'Flights',
        component: () => import('../views/Flights.vue')
      },
{
  path: '/aircrafts',
  name: 'Aircrafts',
  component: () => import('../views/Aircrafts.vue'),
  meta: { title: '机队管理', icon: 'Position' } // 如果你的框架支持动态菜单，一般写在这里
},{
  path: '/operators',
  name: 'Operators',
  component: () => import('../views/Operators.vue'),
  meta: { title: '人员管理', icon: 'User' } // 如果你的框架支持动态菜单，一般写在这里
}
    ]
  }
]

const router = createRouter({
  history: createWebHistory(),
  routes
})

export default router