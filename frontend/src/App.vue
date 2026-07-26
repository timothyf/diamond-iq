<script setup>
import PlayerSearch from './components/PlayerSearch.vue'
import diamondIqLogo from './assets/diamondiq_logo.png'
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
    <nav aria-label="Primary navigation">
      <RouterLink to="/">Home</RouterLink>
      <RouterLink to="/schedule">Schedule</RouterLink>
      <RouterLink to="/standings">Standings</RouterLink>
      <RouterLink to="/explore">Stat Explorer</RouterLink>
      <RouterLink to="/compare">Compare</RouterLink>
      <RouterLink to="/teams">Teams</RouterLink>
      <RouterLink to="/watchlists">Watchlists</RouterLink>
      <RouterLink to="/admin">Admin</RouterLink>
    </nav>
  </header>
  <RouterView />
</template>
