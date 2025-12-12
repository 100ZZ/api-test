import { createRouter, createWebHashHistory } from 'vue-router'
import type { RouteRecordRaw } from 'vue-router'

const routes: RouteRecordRaw[] = [
  {
    path: '/',
    redirect: '/api-test'
  },
  {
    path: '/api-test',
    name: 'ApiTest',
    component: () => import('@/views/ApiTest.vue')
  }
]

const router = createRouter({
  history: createWebHashHistory(),
  routes
})

export default router

