<script setup>
import { computed, onMounted, ref } from 'vue'

import { adminRequestHeaders } from '../composables/apiAuth'
import { usePlayerSuggestions } from '../composables/usePlayerSuggestions'

const API_BASE_URL = import.meta.env.VITE_API_BASE_URL || ''
const watchlists = ref([])
const selectedId = ref(null)
const loading = ref(false)
const error = ref('')
const newWatchlistName = ref('')
const newWatchlistDescription = ref('')
const playerQuery = ref('')
const savingEntryId = ref(null)
const searchQuery = computed(() => ({ name: playerQuery.value, perPage: 6 }))
const { suggestions, loading: searching } = usePlayerSuggestions(searchQuery)
const selectedWatchlist = computed(() => watchlists.value.find((watchlist) => watchlist.id === selectedId.value) || null)

async function request(path, options = {}) {
  const response = await fetch(`${API_BASE_URL}${path}`, options)
  const payload = response.status === 204 ? null : await response.json().catch(() => ({}))
  if (!response.ok) throw new Error(payload?.message || 'The request could not be completed.')
  return payload?.data
}

async function load() {
  loading.value = true
  error.value = ''
  try {
    watchlists.value = await request('/api/watchlists', { headers: { Accept: 'application/json' } }) || []
    if (!selectedId.value && watchlists.value[0]) selectedId.value = watchlists.value[0].id
  } catch (requestError) {
    error.value = requestError.message
  } finally {
    loading.value = false
  }
}

async function createWatchlist() {
  if (!newWatchlistName.value.trim()) return
  try {
    const watchlist = await request('/api/watchlists', {
      method: 'POST',
      headers: adminRequestHeaders({ Accept: 'application/json', 'Content-Type': 'application/json' }),
      body: JSON.stringify({ name: newWatchlistName.value.trim(), description: newWatchlistDescription.value.trim() }),
    })
    watchlists.value.push(watchlist)
    selectedId.value = watchlist.id
    newWatchlistName.value = ''
    newWatchlistDescription.value = ''
  } catch (requestError) {
    error.value = requestError.message
  }
}

async function addPlayer(player) {
  if (!selectedWatchlist.value) return
  try {
    const entry = await request(`/api/watchlists/${selectedWatchlist.value.id}/watchlist_entries`, {
      method: 'POST',
      headers: adminRequestHeaders({ Accept: 'application/json', 'Content-Type': 'application/json' }),
      body: JSON.stringify({ player_id: player.id }),
    })
    selectedWatchlist.value.entries.push(entry)
    playerQuery.value = ''
  } catch (requestError) {
    error.value = requestError.message
  }
}

async function saveEvaluation(entry) {
  savingEntryId.value = entry.id
  try {
    const tags = String(entry.tagsText || '').split(',').map((tag) => tag.trim()).filter(Boolean)
    const updated = await request(`/api/watchlist_entries/${entry.id}`, {
      method: 'PATCH',
      headers: adminRequestHeaders({ Accept: 'application/json', 'Content-Type': 'application/json' }),
      body: JSON.stringify({
        priority: entry.priority,
        status: entry.status,
        recommendation: entry.recommendation,
        fit_score: score(entry.fit_score),
        need_score: score(entry.need_score),
        cost_score: score(entry.cost_score),
        risk_score: score(entry.risk_score),
        tags,
        notes: entry.notes || '',
      }),
    })
    const index = selectedWatchlist.value.entries.findIndex((item) => item.id === entry.id)
    selectedWatchlist.value.entries[index] = normalizeEntry(updated)
  } catch (requestError) {
    error.value = requestError.message
  } finally {
    savingEntryId.value = null
  }
}

async function removeEntry(entry) {
  try {
    await request(`/api/watchlist_entries/${entry.id}`, { method: 'DELETE', headers: adminRequestHeaders({ Accept: 'application/json' }) })
    selectedWatchlist.value.entries = selectedWatchlist.value.entries.filter((item) => item.id !== entry.id)
  } catch (requestError) {
    error.value = requestError.message
  }
}

function score(value) {
  return value === '' || value === null || value === undefined ? null : Number(value)
}

function normalizeEntry(entry) {
  return { ...entry, tagsText: (entry.tags || []).join(', ') }
}

function chooseWatchlist(watchlist) {
  selectedId.value = watchlist.id
  watchlist.entries = (watchlist.entries || []).map(normalizeEntry)
}

onMounted(load)
</script>

<template>
  <main class="watchlists-shell">
    <header class="watchlists-hero">
      <div><p>Front office</p><h1>Watchlists & acquisition evaluations</h1><span>Track targets and make the case for action in one place.</span></div>
    </header>
    <p v-if="error" class="watchlist-error" role="alert">{{ error }}</p>
    <div class="watchlists-layout">
      <aside class="watchlist-sidebar">
        <h2>Watchlists</h2>
        <button v-for="watchlist in watchlists" :key="watchlist.id" type="button" :class="{ selected: watchlist.id === selectedId }" @click="chooseWatchlist(watchlist)">
          <strong>{{ watchlist.name }}</strong><span>{{ watchlist.entries?.length || 0 }} players</span>
        </button>
        <form @submit.prevent="createWatchlist">
          <input v-model="newWatchlistName" required placeholder="New watchlist name" />
          <input v-model="newWatchlistDescription" placeholder="Optional description" />
          <button type="submit">Create watchlist</button>
        </form>
      </aside>
      <section v-if="selectedWatchlist" class="watchlist-main">
        <header><div><p>Active watchlist</p><h2>{{ selectedWatchlist.name }}</h2><span>{{ selectedWatchlist.description }}</span></div><span>{{ selectedWatchlist.entries.length }} targets</span></header>
        <section class="target-search">
          <label>Add player<input v-model="playerQuery" type="search" placeholder="Search MLB players…" /></label>
          <p v-if="searching">Searching…</p>
          <div v-else-if="suggestions.length" class="target-search__results">
            <button v-for="player in suggestions" :key="player.id" type="button" @click="addPlayer(player)">
              <strong>{{ player.fullName }}</strong><span>{{ player.team?.abbreviation || 'FA' }} · MLB {{ player.mlbId }}</span><em>Add →</em>
            </button>
          </div>
        </section>
        <div v-if="selectedWatchlist.entries.length" class="evaluation-list">
          <article v-for="entry in selectedWatchlist.entries" :key="entry.id" class="evaluation-card">
            <header><div><RouterLink :to="{ name: 'player-profile', params: { id: entry.player.id } }">{{ entry.player.full_name }}</RouterLink><span>{{ entry.player.team?.name || 'No current team' }}</span></div><button type="button" @click="removeEntry(entry)">Remove</button></header>
            <div class="evaluation-selects">
              <label>Priority<select v-model="entry.priority"><option>high</option><option>medium</option><option>low</option></select></label>
              <label>Stage<select v-model="entry.status"><option>scouting</option><option>active</option><option>paused</option><option>closed</option></select></label>
              <label>Recommendation<select v-model="entry.recommendation"><option>pursue</option><option>monitor</option><option>pass</option></select></label>
            </div>
            <div class="evaluation-scores">
              <label>Team fit<input v-model="entry.fit_score" min="1" max="5" type="number" /></label>
              <label>Need<input v-model="entry.need_score" min="1" max="5" type="number" /></label>
              <label>Cost<input v-model="entry.cost_score" min="1" max="5" type="number" /></label>
              <label>Risk<input v-model="entry.risk_score" min="1" max="5" type="number" /></label>
            </div>
            <label class="evaluation-notes">Tags<input v-model="entry.tagsText" placeholder="e.g. power, platoon, trade target" /></label>
            <label class="evaluation-notes">Evaluation notes<textarea v-model="entry.notes" placeholder="Why this player fits, what acquisition would require, and open questions…"></textarea></label>
            <footer><small>Scores: 1 low · 5 high</small><button type="button" :disabled="savingEntryId === entry.id" @click="saveEvaluation(entry)">{{ savingEntryId === entry.id ? 'Saving…' : 'Save evaluation' }}</button></footer>
          </article>
        </div>
        <p v-else class="watchlist-empty">Search for a player to begin evaluating acquisition targets.</p>
      </section>
      <section v-else class="watchlist-empty">{{ loading ? 'Loading watchlists…' : 'Create a watchlist to begin.' }}</section>
    </div>
  </main>
</template>

<style scoped>
.watchlists-shell { min-height: calc(100vh - 74px); padding: 2.5rem max(1rem,calc((100vw - 1400px)/2)) 5rem; background: radial-gradient(circle at 90% 0,rgba(32,84,60,.17),transparent 30%),linear-gradient(180deg,#f7f1e3,#ead8b6); color: #10263d; }
.watchlists-hero { padding: 1.8rem 2rem; border-radius: 28px; color: #fffaf0; background: #10263d; }
.watchlists-hero p,.watchlist-main header p { margin: 0; color: #b79569; font-size: .7rem; font-weight: 900; letter-spacing: .11em; text-transform: uppercase; }
.watchlists-hero h1 { margin: .35rem 0; font-family: 'Avenir Next Condensed',sans-serif; font-size: clamp(2.3rem,5vw,4.8rem); line-height: .9; text-transform: uppercase; }
.watchlists-hero span { color: #d2dce2; }
.watchlist-error { margin: .8rem 0; padding: .8rem; border-radius: 12px; color: #7d291f; background: #f5ddd5; font-weight: 800; }
.watchlists-layout { display: grid; grid-template-columns: 260px minmax(0,1fr); gap: 1rem; margin-top: 1rem; }
.watchlist-sidebar,.watchlist-main,.watchlist-empty { border: 1px solid rgba(16,38,61,.13); border-radius: 22px; background: rgba(255,252,244,.9); box-shadow: 0 16px 40px rgba(64,43,20,.08); }
.watchlist-sidebar { padding: 1rem; align-self: start; }
.watchlist-sidebar h2 { margin-bottom: .7rem; font-size: .82rem; letter-spacing: .08em; text-transform: uppercase; }
.watchlist-sidebar > button { display: grid; width: 100%; gap: .15rem; padding: .7rem; border: 0; border-radius: 10px; color: #173652; background: transparent; text-align: left; cursor: pointer; }
.watchlist-sidebar > button.selected { color: #fffaf0; background: #173652; }
.watchlist-sidebar > button span { font-size: .68rem; opacity: .72; }
.watchlist-sidebar form { display: grid; gap: .45rem; margin-top: 1rem; padding-top: 1rem; border-top: 1px solid rgba(16,38,61,.1); }
input,select,textarea { width: 100%; padding: .55rem .6rem; border: 1px solid rgba(16,38,61,.16); border-radius: 9px; color: #173652; background: #fffdf7; font: inherit; }
button { font: inherit; cursor: pointer; }
.watchlist-sidebar form button,.evaluation-card footer button { padding: .55rem .7rem; border: 0; border-radius: 9px; color: #fffaf0; background: #20543c; font-size: .75rem; font-weight: 900; }
.watchlist-main { padding: 1.4rem; }
.watchlist-main > header,.evaluation-card header,.evaluation-card footer { display: flex; justify-content: space-between; gap: 1rem; align-items: start; }
.watchlist-main h2 { margin: .25rem 0; font-family: 'Avenir Next Condensed',sans-serif; font-size: 2.2rem; text-transform: uppercase; }
.watchlist-main header > span,.watchlist-main header span { color: #71808c; font-size: .8rem; }
.target-search { position: relative; margin-top: 1rem; }
.target-search label { display: grid; gap: .3rem; color: #697784; font-size: .68rem; font-weight: 900; letter-spacing: .07em; text-transform: uppercase; }
.target-search__results { position: absolute; z-index: 2; top: calc(100% + .25rem); width: 100%; overflow: hidden; border: 1px solid rgba(16,38,61,.16); border-radius: 12px; background: #fffdf7; box-shadow: 0 12px 28px rgba(16,38,61,.14); }
.target-search__results button { display: grid; grid-template-columns: 1fr auto; width: 100%; padding: .7rem; border: 0; border-bottom: 1px solid rgba(16,38,61,.08); color: #173652; background: transparent; text-align: left; }
.target-search__results span { color: #71808c; font-size: .72rem; }
.target-search__results em { grid-column: 2; grid-row: 1 / span 2; align-self: center; color: #20543c; font-size: .72rem; font-style: normal; font-weight: 900; }
.evaluation-list { display: grid; gap: .8rem; margin-top: 1rem; }
.evaluation-card { padding: 1rem; border: 1px solid rgba(16,38,61,.11); border-radius: 16px; background: rgba(16,38,61,.035); }
.evaluation-card header a { color: #173652; font-family: 'Avenir Next Condensed',sans-serif; font-size: 1.45rem; font-weight: 900; text-decoration-color: #b79569; text-transform: uppercase; }
.evaluation-card header span { display: block; color: #71808c; font-size: .72rem; }
.evaluation-card header button { padding: 0; border: 0; color: #9b3328; background: transparent; font-size: .72rem; font-weight: 900; }
.evaluation-selects,.evaluation-scores { display: grid; grid-template-columns: repeat(3,1fr); gap: .55rem; margin-top: .8rem; }
.evaluation-scores { grid-template-columns: repeat(4,1fr); }
.evaluation-selects label,.evaluation-scores label,.evaluation-notes { display: grid; gap: .25rem; color: #697784; font-size: .65rem; font-weight: 900; letter-spacing: .06em; text-transform: uppercase; }
.evaluation-notes { margin-top: .65rem; }
textarea { min-height: 74px; resize: vertical; }
.evaluation-card footer { align-items: center; margin-top: .75rem; }.evaluation-card footer small { color: #71808c; font-size: .68rem; }
.watchlist-empty { display: grid; min-height: 240px; place-items: center; padding: 2rem; color: #71808c; text-align: center; }
@media (max-width: 760px) { .watchlists-layout { grid-template-columns: 1fr; }.evaluation-selects,.evaluation-scores { grid-template-columns: 1fr 1fr; } }
</style>
