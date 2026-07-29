<script setup>
import { computed, onBeforeUnmount, onMounted, ref } from 'vue'
import { useRoute } from 'vue-router'

import PlayerSearch from './components/PlayerSearch.vue'
import diamondIqLogo from './assets/diamondiq_logo.png'
import { useAuth } from './composables/useAuth'

const { user, loadCurrentUser, logout } = useAuth()
const route = useRoute()
const accountMenuOpen = ref(false)
const isAdministrator = computed(() => ['admin', 'administrator'].includes(user.value?.role))
const signInTarget = computed(() => ({
  name: 'login',
  query: route.name === 'login' ? {} : { redirect: route.fullPath },
}))

function closeAccountMenu(event) {
  if (!event?.target?.closest?.('.app-account')) accountMenuOpen.value = false
}

async function signOut() {
  accountMenuOpen.value = false
  await logout()
}

onMounted(() => {
  loadCurrentUser()
  document.addEventListener('click', closeAccountMenu)
})
onBeforeUnmount(() => document.removeEventListener('click', closeAccountMenu))
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
      <RouterLink v-if="user" to="/watchlists">Watchlists</RouterLink>
      <RouterLink v-if="isAdministrator" to="/admin">Admin</RouterLink>
    </nav>
    <div class="app-account">
      <RouterLink v-if="!user" :to="signInTarget">Sign in</RouterLink>
      <template v-else>
        <button
          type="button"
          class="app-account__trigger"
          :aria-expanded="accountMenuOpen"
          aria-haspopup="menu"
          @click.stop="accountMenuOpen = !accountMenuOpen"
        >
          {{ user.name }} <span aria-hidden="true">⌄</span>
        </button>
        <div v-if="accountMenuOpen" class="app-account__menu" role="menu">
          <span class="app-account__email">{{ user.email }}</span>
          <button type="button" role="menuitem" @click="signOut">Sign out</button>
        </div>
      </template>
    </div>
  </header>
  <RouterView />
</template>
