<script setup>
import { onMounted } from 'vue'

import PlayerSearch from './components/PlayerSearch.vue'
import diamondIqLogo from './assets/diamondiq_logo.png'
import { useAuth } from './composables/useAuth'

const { user, loadCurrentUser, logout } = useAuth()
onMounted(loadCurrentUser)
</script>

<template>
  <header class="app-bar">
    <RouterLink class="app-brand" to="/">
      <span class="app-brand__mark" aria-hidden="true">
        <img :src="diamondIqLogo" alt="" />
      </span>
      <span>
        <strong>DiamondIQ</strong>
        <small>Baseball intelligence</small>
      </span>
    </RouterLink>
    <PlayerSearch />
    <nav class="app-primary-nav" aria-label="Primary navigation">
      <RouterLink to="/">Home</RouterLink>
      <RouterLink to="/schedule">Schedule</RouterLink>
      <RouterLink to="/standings">Standings</RouterLink>
      <RouterLink to="/explore">Stat Explorer</RouterLink>
      <RouterLink to="/compare">Compare</RouterLink>
      <RouterLink to="/teams">Teams</RouterLink>
      <RouterLink to="/watchlists">Watchlists</RouterLink>
      <RouterLink to="/admin">Admin</RouterLink>
    </nav>
    <div class="app-account">
      <RouterLink v-if="!user" to="/login">Sign in</RouterLink>
      <button v-else type="button" class="app-logout" @click="logout">{{ user.name }} · Sign out</button>
    </div>
  </header>
  <RouterView />
</template>
