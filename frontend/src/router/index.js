import { createRouter, createWebHistory } from 'vue-router'

import PlayerSeasonStatsDashboard from '../components/PlayerSeasonStatsDashboard.vue'
import AdminView from '../views/AdminView.vue'
import PlayerProfileView from '../views/PlayerProfileView.vue'
import TeamDirectoryView from '../views/TeamDirectoryView.vue'
import TeamProfileView from '../views/TeamProfileView.vue'

const router = createRouter({
  history: createWebHistory(import.meta.env.BASE_URL),
  routes: [
    {
      path: '/',
      name: 'stat-board',
      component: PlayerSeasonStatsDashboard,
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
