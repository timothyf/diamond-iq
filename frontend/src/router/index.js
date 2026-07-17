import { createRouter, createWebHistory } from 'vue-router'

import PlayerSeasonStatsDashboard from '../components/PlayerSeasonStatsDashboard.vue'
import AdminView from '../views/AdminView.vue'
import HomeView from '../views/HomeView.vue'
import PlayerProfileView from '../views/PlayerProfileView.vue'
import TeamDirectoryView from '../views/TeamDirectoryView.vue'
import TeamProfileView from '../views/TeamProfileView.vue'

const router = createRouter({
  history: createWebHistory(import.meta.env.BASE_URL),
  routes: [
    {
      path: '/',
      name: 'home',
      component: HomeView,
    },
    {
      path: '/explore',
      name: 'stat-explorer',
      component: PlayerSeasonStatsDashboard,
    },
    {
      path: '/stat-board',
      redirect: { name: 'stat-explorer' },
    },
    {
      path: '/players/:id',
      name: 'player-profile',
      component: PlayerProfileView,
      props: (route) => ({ playerId: route.params.id }),
    },
    {
      path: '/teams',
      name: 'teams',
      component: TeamDirectoryView,
    },
    {
      path: '/teams/:id',
      name: 'team-profile',
      component: TeamProfileView,
      props: (route) => ({ teamId: route.params.id }),
    },
    {
      path: '/admin',
      name: 'admin',
      component: AdminView,
    },
  ],
  scrollBehavior: () => ({ top: 0 }),
})

export default router
