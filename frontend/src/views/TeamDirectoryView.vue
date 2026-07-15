<script setup>
import { onMounted, ref } from 'vue'

const API_BASE_URL = import.meta.env.VITE_API_BASE_URL || ''
const teams = ref([])
const loading = ref(true)
const error = ref('')

async function loadTeams() {
  loading.value = true
  error.value = ''
  try {
    const response = await fetch(`${API_BASE_URL}/api/teams`, { headers: { Accept: 'application/json' } })
    if (!response.ok) throw new Error(`Request failed with status ${response.status}`)
    const payload = await response.json()
    teams.value = payload.data || []
  } catch (fetchError) {
    error.value = 'Unable to load MLB teams. Confirm the Rails API is running and reachable.'
    console.error(fetchError)
  } finally {
    loading.value = false
  }
}

onMounted(loadTeams)
</script>

<template>
  <main class="teams-shell">
    <header class="teams-heading">
      <p>League directory</p>
      <h1>MLB teams</h1>
      <span>Select a club to view its roster, record, and schedule.</span>
    </header>

    <div v-if="loading" class="teams-state">Loading teams…</div>
    <div v-else-if="error" class="teams-state teams-state--error">
      <p>{{ error }}</p>
      <button type="button" @click="loadTeams">Try again</button>
    </div>
    <section v-else class="team-grid" data-test="team-directory">
      <RouterLink v-for="team in teams" :key="team.id" class="team-tile" :to="{ name: 'team-profile', params: { id: team.id } }">
        <img :src="team.logo_url" :alt="`${team.name} logo`" />
        <div>
          <strong>{{ team.name }}</strong>
          <span>{{ team.abbreviation }} · MLB {{ team.mlb_id }}</span>
        </div>
        <b aria-hidden="true">→</b>
      </RouterLink>
    </section>
  </main>
</template>

<style scoped>
.teams-shell { width: min(1380px, calc(100% - 2rem)); margin: 0 auto; padding: 3.5rem 0 5rem; }
.teams-heading p { margin: 0; color: #a93627; font-size: .75rem; font-weight: 800; letter-spacing: .18em; text-transform: uppercase; }
.teams-heading h1 { margin: .25rem 0; color: #10263d; font-family: 'Avenir Next Condensed', sans-serif; font-size: clamp(3rem, 7vw, 6rem); line-height: .95; text-transform: uppercase; }
.teams-heading span { color: #61707b; }
.team-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(285px, 1fr)); gap: 1rem; margin-top: 2rem; }
.team-tile { display: grid; grid-template-columns: 68px 1fr auto; gap: 1rem; align-items: center; min-height: 104px; padding: 1rem; border: 1px solid #d7d6ce; border-radius: 22px; color: #10263d; background: rgba(255,255,255,.72); text-decoration: none; transition: transform .18s ease, box-shadow .18s ease; }
.team-tile:hover { transform: translateY(-2px); box-shadow: 0 14px 32px rgba(16,38,61,.1); }
.team-tile img { width: 64px; height: 64px; object-fit: contain; }
.team-tile strong, .team-tile span { display: block; }
.team-tile strong { font-size: 1.05rem; }
.team-tile span { margin-top: .25rem; color: #6d7780; font-size: .78rem; }
.team-tile b { color: #a93627; font-size: 1.4rem; }
.teams-state { margin-top: 2rem; padding: 2rem; border-radius: 20px; background: #fffaf0; }
.teams-state--error { color: #8f2e23; }
.teams-state button { padding: .65rem 1rem; border: 0; border-radius: 999px; color: white; background: #10263d; font-weight: 800; }
</style>
