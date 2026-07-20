import { createRouter, createWebHistory } from 'vue-router'

import PlayerSeasonStatsDashboard from '../components/PlayerSeasonStatsDashboard.vue'
import AdminView from '../views/AdminView.vue'
import GameSummaryView from '../views/GameSummaryView.vue'
import HomeView from '../views/HomeView.vue'
import PlayerProfileView from '../views/PlayerProfileView.vue'
import ScheduleView from '../views/ScheduleView.vue'
import StandingsView from '../views/StandingsView.vue'
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
      path: '/schedule',
      name: 'schedule',
      component: ScheduleView,
    },
    {
      path: '/standings',
      name: 'standings',
      component: StandingsView,
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
      path: '/games/:id',
      name: 'game-summary',
      component: GameSummaryView,
      props: (route) => ({ gameId: route.params.id }),
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
