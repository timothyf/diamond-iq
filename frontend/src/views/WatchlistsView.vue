<script setup>
import { computed, inject, onMounted, ref, watch } from 'vue'
import { routeLocationKey, routerKey } from 'vue-router'

import { authRequestHeaders } from '../composables/apiAuth'
import { usePlayerSuggestions } from '../composables/usePlayerSuggestions'
import SavedAnalysisControls from '../components/SavedAnalysisControls.vue'

const API_BASE_URL = import.meta.env.VITE_API_BASE_URL || ''
const route = inject(routeLocationKey, { query: {}, fullPath: '/watchlists' })
const router = inject(routerKey, { replace: () => {}, push: () => {} })
const watchlists = ref([])
const needProfiles = ref([])
const teams = ref([])
const selectedId = ref(route.query.watchlist ? Number(route.query.watchlist) : null)
const loading = ref(false)
const error = ref('')
const newWatchlistName = ref('')
const newWatchlistDescription = ref('')
const playerQuery = ref('')
const savingEntryId = ref(null)
const discovering = ref(false)
const discoveryResults = ref([])
const alternativesByEntry = ref({})
const loadingAlternativesId = ref(null)
const auditHistory = ref([])
const loadingAuditHistory = ref(false)
const discoveryFilters = ref({
  name: route.query.name || '',
  positionType: route.query.position_type || '',
  bats: route.query.bats || '',
  ageMin: route.query.age_min || '',
  ageMax: route.query.age_max || '',
  minFit: route.query.min_fit ?? 60,
})
const savedAnalysisState = computed(() => ({
  watchlistId: selectedId.value,
  filters: { ...discoveryFilters.value },
}))
const savedAnalysisUrl = computed(() => {
  const filters = discoveryFilters.value
  const query = new URLSearchParams()
  if (selectedId.value) query.set('watchlist', String(selectedId.value))
  if (filters.name) query.set('name', filters.name)
  if (filters.positionType) query.set('position_type', filters.positionType)
  if (filters.bats) query.set('bats', filters.bats)
  if (filters.ageMin !== '') query.set('age_min', String(filters.ageMin))
  if (filters.ageMax !== '') query.set('age_max', String(filters.ageMax))
  if (filters.minFit !== '' && Number(filters.minFit) !== 60) query.set('min_fit', String(filters.minFit))
  return `/watchlists${query.size ? `?${query}` : ''}`
})
const newNeed = ref({
  name: '',
  teamId: '',
  description: '',
  positionType: 'outfielder',
  bats: '',
  ageMin: '',
  ageMax: '',
  statKey: 'ops',
  statDirection: 'higher',
  statTarget: '',
  positionWeight: 30,
  handednessWeight: 15,
  ageWeight: 15,
  performanceWeight: 40,
})
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
    const [loadedWatchlists, loadedProfiles, loadedTeams] = await Promise.all([
      request('/api/watchlists', { headers: authRequestHeaders({ Accept: 'application/json' }) }),
      request('/api/need_profiles', { headers: authRequestHeaders({ Accept: 'application/json' }) }),
      request('/api/teams', { headers: { Accept: 'application/json' } }),
    ])
    watchlists.value = (loadedWatchlists || []).map((watchlist) => ({
      ...watchlist,
      entries: (watchlist.entries || []).map(normalizeEntry),
    }))
    needProfiles.value = loadedProfiles || []
    teams.value = loadedTeams || []
    if (!watchlists.value.some((watchlist) => watchlist.id === selectedId.value)) {
      selectedId.value = watchlists.value[0]?.id || null
    }
  } catch (requestError) {
    error.value = requestError.message
  } finally {
    loading.value = false
  }
}

async function createNeedProfile() {
  const form = newNeed.value
  if (!form.name.trim() || !form.teamId) return
  const performance = form.statKey.trim() && form.statTarget !== ''
    ? [{ stat_key: form.statKey.trim(), direction: form.statDirection, target: Number(form.statTarget) }]
    : []
  try {
    const profile = await request('/api/need_profiles', {
      method: 'POST',
      headers: authRequestHeaders({ Accept: 'application/json', 'Content-Type': 'application/json' }),
      body: JSON.stringify({
        team_id: Number(form.teamId),
        name: form.name.trim(),
        description: form.description.trim(),
        criteria: {
          position_types: form.positionType ? [form.positionType] : [],
          bats: form.bats ? [form.bats] : [],
          age: {
            min: form.ageMin === '' ? null : Number(form.ageMin),
            max: form.ageMax === '' ? null : Number(form.ageMax),
          },
          performance,
        },
        weights: {
          position: Number(form.positionWeight),
          handedness: Number(form.handednessWeight),
          age: Number(form.ageWeight),
          performance: Number(form.performanceWeight),
        },
      }),
    })
    needProfiles.value.push(profile)
    form.name = ''
    form.description = ''
    if (selectedWatchlist.value) await attachNeedProfile(profile.id)
  } catch (requestError) {
    error.value = requestError.message
  }
}

async function attachNeedProfile(profileId) {
  if (!selectedWatchlist.value) return
  try {
    const updated = await request(`/api/watchlists/${selectedWatchlist.value.id}`, {
      method: 'PATCH',
      headers: authRequestHeaders({ Accept: 'application/json', 'Content-Type': 'application/json' }),
      body: JSON.stringify({ need_profile_id: profileId || null }),
    })
    const index = watchlists.value.findIndex((watchlist) => watchlist.id === updated.id)
    watchlists.value[index] = { ...updated, entries: (updated.entries || []).map(normalizeEntry) }
    discoveryResults.value = []
    alternativesByEntry.value = {}
  } catch (requestError) {
    error.value = requestError.message
  }
}

async function discoverCandidates() {
  if (!selectedWatchlist.value?.need_profile) return
  discovering.value = true
  error.value = ''
  try {
    const query = new URLSearchParams()
    if (discoveryFilters.value.name.trim()) query.set('name', discoveryFilters.value.name.trim())
    if (discoveryFilters.value.positionType) query.set('position_type', discoveryFilters.value.positionType)
    if (discoveryFilters.value.bats) query.set('bats', discoveryFilters.value.bats)
    if (discoveryFilters.value.ageMin !== '') query.set('age_min', discoveryFilters.value.ageMin)
    if (discoveryFilters.value.ageMax !== '') query.set('age_max', discoveryFilters.value.ageMax)
    if (discoveryFilters.value.minFit !== '') query.set('min_fit', discoveryFilters.value.minFit)
    discoveryResults.value = await request(
      `/api/watchlists/${selectedWatchlist.value.id}/discovery?${query.toString()}`,
      { headers: authRequestHeaders({ Accept: 'application/json' }) },
    ) || []
  } catch (requestError) {
    error.value = requestError.message
  } finally {
    discovering.value = false
  }
}

async function addDiscoveredCandidate(candidate) {
  await addPlayer({ id: candidate.player.id })
  discoveryResults.value = discoveryResults.value.filter((result) => result.player.id !== candidate.player.id)
}

async function loadAlternatives(entry) {
  loadingAlternativesId.value = entry.id
  try {
    alternativesByEntry.value[entry.id] = await request(`/api/watchlist_entries/${entry.id}/alternatives`, {
      headers: authRequestHeaders({ Accept: 'application/json' }),
    }) || []
  } catch (requestError) {
    error.value = requestError.message
  } finally {
    loadingAlternativesId.value = null
  }
}

async function loadAuditHistory() {
  if (!selectedWatchlist.value) return
  loadingAuditHistory.value = true
  try {
    auditHistory.value = await request(`/api/watchlists/${selectedWatchlist.value.id}/audit_history`, {
      headers: authRequestHeaders({ Accept: 'application/json' }),
    }) || []
  } catch (requestError) {
    error.value = requestError.message
  } finally {
    loadingAuditHistory.value = false
  }
}

async function createWatchlist() {
  if (!newWatchlistName.value.trim()) return
  try {
    const watchlist = await request('/api/watchlists', {
      method: 'POST',
      headers: authRequestHeaders({ Accept: 'application/json', 'Content-Type': 'application/json' }),
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
      headers: authRequestHeaders({ Accept: 'application/json', 'Content-Type': 'application/json' }),
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
      headers: authRequestHeaders({ Accept: 'application/json', 'Content-Type': 'application/json' }),
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
    await request(`/api/watchlist_entries/${entry.id}`, { method: 'DELETE', headers: authRequestHeaders({ Accept: 'application/json' }) })
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
  discoveryResults.value = []
  alternativesByEntry.value = {}
  auditHistory.value = []
}

function openSavedAnalysis(item) {
  const state = item.state || {}
  if (state.watchlistId) selectedId.value = Number(state.watchlistId)
  if (state.filters) discoveryFilters.value = { ...discoveryFilters.value, ...state.filters }
  router.push(item.reproducibleUrl)
}

function componentScore(entry, key) {
  return entry.fit_breakdown?.components?.[key]?.score
}

function formatFit(value) {
  return value === null || value === undefined ? '—' : Number(value).toFixed(1)
}

onMounted(load)

watch(
  [selectedId, discoveryFilters],
  ([watchlistId, filters]) => {
    const query = {}
    if (watchlistId) query.watchlist = String(watchlistId)
    if (filters.name) query.name = filters.name
    if (filters.positionType) query.position_type = filters.positionType
    if (filters.bats) query.bats = filters.bats
    if (filters.ageMin !== '') query.age_min = String(filters.ageMin)
    if (filters.ageMax !== '') query.age_max = String(filters.ageMax)
    if (filters.minFit !== '' && Number(filters.minFit) !== 60) query.min_fit = String(filters.minFit)
    router.replace({ name: 'watchlists', query })
  },
  { deep: true },
)
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
        <div class="watchlist-audit-bar">
          <button type="button" class="audit-action" :disabled="loadingAuditHistory" @click="loadAuditHistory">
            {{ loadingAuditHistory ? 'Loading history…' : 'View audit history' }}
          </button>
        </div>
        <section v-if="auditHistory.length" class="audit-history" data-test="audit-history">
          <h3>Change history</h3>
          <article v-for="event in auditHistory" :key="event.id">
            <div><strong>{{ event.action.replaceAll('_', ' ') }}</strong><span>{{ event.user?.name || event.user?.email || 'System' }}</span></div>
            <time :datetime="event.created_at">{{ new Date(event.created_at).toLocaleString() }}</time>
          </article>
        </section>

        <section class="need-workspace" data-test="need-workspace">
          <header>
            <div><p>Organizational need</p><h3>Calculated acquisition fit</h3></div>
            <label>
              Need profile
              <select :value="selectedWatchlist.need_profile?.id || ''" @change="attachNeedProfile($event.target.value)">
                <option value="">Manual evaluation only</option>
                <option v-for="profile in needProfiles" :key="profile.id" :value="profile.id">
                  {{ profile.team?.abbreviation || 'ORG' }} · {{ profile.name }}
                </option>
              </select>
            </label>
          </header>
          <p v-if="selectedWatchlist.need_profile" class="need-summary">
            <strong>{{ selectedWatchlist.need_profile.name }}</strong>
            {{ selectedWatchlist.need_profile.description || 'Reusable weighted need profile' }}
          </p>

          <details class="need-builder">
            <summary>Create a reusable need profile</summary>
            <form @submit.prevent="createNeedProfile">
              <label>Name<input v-model="newNeed.name" required placeholder="e.g. Left-handed impact outfielder" /></label>
              <label>Organization<select v-model="newNeed.teamId" required><option value="">Choose team</option><option v-for="team in teams" :key="team.id" :value="team.id">{{ team.abbreviation }} · {{ team.name }}</option></select></label>
              <label class="need-builder__wide">Description<input v-model="newNeed.description" placeholder="What roster problem does this solve?" /></label>
              <label>Position<select v-model="newNeed.positionType"><option value="">Any</option><option>pitcher</option><option>catcher</option><option>infielder</option><option>outfielder</option><option>designated_hitter</option><option>two_way</option></select></label>
              <label>Bats<select v-model="newNeed.bats"><option value="">Any</option><option>L</option><option>R</option><option>S</option></select></label>
              <label>Minimum age<input v-model="newNeed.ageMin" min="16" max="50" type="number" /></label>
              <label>Maximum age<input v-model="newNeed.ageMax" min="16" max="50" type="number" /></label>
              <label>Performance stat<input v-model="newNeed.statKey" placeholder="ops, ERA, homeRuns…" /></label>
              <label>Direction<select v-model="newNeed.statDirection"><option value="higher">Higher is better</option><option value="lower">Lower is better</option></select></label>
              <label>Target<input v-model="newNeed.statTarget" step="any" type="number" /></label>
              <div class="need-weights need-builder__wide">
                <span>Weights</span>
                <label>Position<input v-model="newNeed.positionWeight" min="0" type="number" /></label>
                <label>Handedness<input v-model="newNeed.handednessWeight" min="0" type="number" /></label>
                <label>Age<input v-model="newNeed.ageWeight" min="0" type="number" /></label>
                <label>Performance<input v-model="newNeed.performanceWeight" min="0" type="number" /></label>
              </div>
              <button type="submit">Create and attach profile</button>
            </form>
          </details>
        </section>

        <section v-if="selectedWatchlist.need_profile" class="discovery-workspace" data-test="candidate-discovery">
          <header><div><p>Candidate discovery</p><h3>Players matching this need</h3></div></header>
          <SavedAnalysisControls
            analysis-type="acquisition_search"
            :state="savedAnalysisState"
            :reproducible-url="savedAnalysisUrl"
            compact
            @apply="openSavedAnalysis"
          />
          <form class="discovery-filters" @submit.prevent="discoverCandidates">
            <label>Name<input v-model="discoveryFilters.name" type="search" placeholder="Optional player filter" /></label>
            <label>Position<select v-model="discoveryFilters.positionType"><option value="">Profile default</option><option>pitcher</option><option>catcher</option><option>infielder</option><option>outfielder</option><option>designated_hitter</option><option>two_way</option></select></label>
            <label>Bats<select v-model="discoveryFilters.bats"><option value="">Any</option><option>L</option><option>R</option><option>S</option></select></label>
            <label>Age from<input v-model="discoveryFilters.ageMin" min="16" max="50" type="number" /></label>
            <label>Age through<input v-model="discoveryFilters.ageMax" min="16" max="50" type="number" /></label>
            <label>Minimum fit<input v-model="discoveryFilters.minFit" min="0" max="100" type="number" /></label>
            <button type="submit" :disabled="discovering">{{ discovering ? 'Ranking…' : 'Discover candidates' }}</button>
          </form>
          <div v-if="discoveryResults.length" class="discovery-results">
            <article v-for="candidate in discoveryResults" :key="candidate.player.id">
              <div>
                <strong>{{ candidate.player.full_name }}</strong>
                <span>{{ candidate.player.position?.abbreviation || '—' }} · {{ candidate.player.team?.abbreviation || 'FA' }} · age {{ candidate.player.age || '—' }}</span>
              </div>
              <b>{{ formatFit(candidate.calculated_fit_score) }}</b>
              <small>Position {{ formatFit(candidate.fit_breakdown.components.position.score) }} · Performance {{ formatFit(candidate.fit_breakdown.components.performance.score) }}</small>
              <button type="button" @click="addDiscoveredCandidate(candidate)">Add target</button>
            </article>
          </div>
          <p v-else-if="!discovering" class="discovery-empty">Run discovery to rank external candidates using the attached profile.</p>
        </section>

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
            <section v-if="entry.calculated_fit_score !== null && entry.calculated_fit_score !== undefined" class="calculated-fit" data-test="calculated-fit">
              <div><span>Calculated fit</span><strong>{{ formatFit(entry.calculated_fit_score) }}</strong><small>out of 100</small></div>
              <dl>
                <div><dt>Position</dt><dd>{{ formatFit(componentScore(entry, 'position')) }}</dd></div>
                <div><dt>Handedness</dt><dd>{{ formatFit(componentScore(entry, 'handedness')) }}</dd></div>
                <div><dt>Age</dt><dd>{{ formatFit(componentScore(entry, 'age')) }}</dd></div>
                <div><dt>Performance</dt><dd>{{ formatFit(componentScore(entry, 'performance')) }}</dd></div>
              </dl>
            </section>
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
            <footer>
              <small>Manual scouting scores: 1 low · 5 high</small>
              <div>
                <button v-if="selectedWatchlist.need_profile" class="secondary-action" type="button" :disabled="loadingAlternativesId === entry.id" @click="loadAlternatives(entry)">
                  {{ loadingAlternativesId === entry.id ? 'Finding…' : 'Similar alternatives' }}
                </button>
                <button type="button" :disabled="savingEntryId === entry.id" @click="saveEvaluation(entry)">{{ savingEntryId === entry.id ? 'Saving…' : 'Save evaluation' }}</button>
              </div>
            </footer>
            <section v-if="alternativesByEntry[entry.id]" class="alternative-list" data-test="similar-alternatives">
              <h4>Similar alternatives</h4>
              <p v-if="!alternativesByEntry[entry.id].length">No unwatched alternatives currently match this need.</p>
              <article v-for="alternative in alternativesByEntry[entry.id]" :key="alternative.player.id">
                <div><strong>{{ alternative.player.full_name }}</strong><span>{{ alternative.player.team?.abbreviation || 'FA' }} · fit {{ formatFit(alternative.calculated_fit_score) }} · similarity {{ formatFit(alternative.similarity_score) }}</span></div>
                <button type="button" @click="addDiscoveredCandidate(alternative)">Add</button>
              </article>
            </section>
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
.watchlist-audit-bar { display: flex; justify-content: flex-end; margin-top: .7rem; }
.audit-action,.secondary-action { padding: .5rem .7rem; border: 1px solid rgba(32,84,60,.28); border-radius: 9px; color: #20543c; background: transparent; font-size: .7rem; font-weight: 900; }
.audit-action:disabled,.secondary-action:disabled { opacity: .6; cursor: wait; }
.audit-history { margin-top: .7rem; padding: .8rem; border-radius: 12px; background: rgba(16,38,61,.045); }
.audit-history h3 { margin: 0 0 .5rem; color: #173652; font-size: .75rem; letter-spacing: .06em; text-transform: uppercase; }
.audit-history article { display: flex; justify-content: space-between; gap: 1rem; padding: .45rem 0; border-top: 1px solid rgba(16,38,61,.09); font-size: .7rem; }
.audit-history article div span { display: block; color: #71808c; font-size: .65rem; }
.audit-history time { color: #71808c; white-space: nowrap; }
.watchlist-main h2 { margin: .25rem 0; font-family: 'Avenir Next Condensed',sans-serif; font-size: 2.2rem; text-transform: uppercase; }
.watchlist-main header > span,.watchlist-main header span { color: #71808c; font-size: .8rem; }
.need-workspace,.discovery-workspace { margin-top: 1rem; padding: 1rem; border: 1px solid rgba(32,84,60,.18); border-radius: 16px; background: rgba(32,84,60,.055); }
.need-workspace > header,.discovery-workspace > header { display: flex; justify-content: space-between; gap: 1rem; align-items: end; }
.need-workspace h3,.discovery-workspace h3 { margin: .15rem 0 0; font-family: 'Avenir Next Condensed',sans-serif; font-size: 1.55rem; text-transform: uppercase; }
.need-workspace > header label { min-width: min(320px,50%); color: #697784; font-size: .67rem; font-weight: 900; text-transform: uppercase; }
.need-summary { display: flex; gap: .55rem; margin: .7rem 0 0; color: #667782; font-size: .75rem; }.need-summary strong { color: #20543c; }
.need-builder { margin-top: .8rem; border-top: 1px solid rgba(32,84,60,.14); padding-top: .7rem; }
.need-builder summary { color: #20543c; font-size: .72rem; font-weight: 900; cursor: pointer; }
.need-builder form { display: grid; grid-template-columns: repeat(4,1fr); gap: .55rem; margin-top: .7rem; }
.need-builder label,.discovery-filters label { display: grid; gap: .22rem; color: #697784; font-size: .62rem; font-weight: 900; letter-spacing: .05em; text-transform: uppercase; }
.need-builder__wide { grid-column: span 2; }
.need-weights { display: grid; grid-template-columns: repeat(4,1fr); gap: .4rem; }.need-weights > span { grid-column: 1 / -1; color: #20543c; font-size: .65rem; font-weight: 900; text-transform: uppercase; }
.need-builder form > button,.discovery-filters button,.discovery-results button,.alternative-list button { align-self: end; padding: .58rem .7rem; border: 0; border-radius: 9px; color: #fffaf0; background: #20543c; font-size: .7rem; font-weight: 900; }
.discovery-filters { display: grid; grid-template-columns: repeat(6,minmax(90px,1fr)) auto; gap: .55rem; margin-top: .7rem; align-items: end; }
.discovery-results { display: grid; gap: .5rem; margin-top: .75rem; }
.discovery-results article { display: grid; grid-template-columns: 1fr auto auto; gap: .3rem .8rem; align-items: center; padding: .7rem; border-radius: 11px; background: rgba(255,253,247,.8); }
.discovery-results strong,.discovery-results span { display: block; }.discovery-results strong { color: #173652; }.discovery-results span,.discovery-results small { color: #71808c; font-size: .68rem; }
.discovery-results b { grid-row: span 2; color: #20543c; font-size: 1.35rem; }.discovery-results small { grid-column: 1; }
.discovery-results button { grid-column: 3; grid-row: 1 / span 2; }
.discovery-empty { margin: .7rem 0 0; color: #71808c; font-size: .72rem; }
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
.calculated-fit { display: grid; grid-template-columns: 140px 1fr; gap: .8rem; margin-top: .8rem; padding: .75rem; border-radius: 12px; color: #fffaf0; background: linear-gradient(120deg,#173652,#20543c); }
.calculated-fit > div span,.calculated-fit > div small,.calculated-fit > div strong { display: block; }.calculated-fit > div span { color: #b8cfc3; font-size: .62rem; font-weight: 900; text-transform: uppercase; }.calculated-fit > div strong { font-family: 'Avenir Next Condensed',sans-serif; font-size: 2.2rem; line-height: 1; }.calculated-fit > div small { color: #b8cfc3; font-size: .62rem; }
.calculated-fit dl { display: grid; grid-template-columns: repeat(4,1fr); gap: .4rem; margin: 0; }.calculated-fit dl div { padding: .45rem; border-radius: 8px; background: rgba(255,255,255,.08); }.calculated-fit dt { color: #b8cfc3; font-size: .58rem; text-transform: uppercase; }.calculated-fit dd { margin: .15rem 0 0; font-weight: 900; }
.evaluation-selects,.evaluation-scores { display: grid; grid-template-columns: repeat(3,1fr); gap: .55rem; margin-top: .8rem; }
.evaluation-scores { grid-template-columns: repeat(4,1fr); }
.evaluation-selects label,.evaluation-scores label,.evaluation-notes { display: grid; gap: .25rem; color: #697784; font-size: .65rem; font-weight: 900; letter-spacing: .06em; text-transform: uppercase; }
.evaluation-notes { margin-top: .65rem; }
textarea { min-height: 74px; resize: vertical; }
.evaluation-card footer { align-items: center; margin-top: .75rem; }.evaluation-card footer small { color: #71808c; font-size: .68rem; }.evaluation-card footer > div { display: flex; gap: .45rem; }.evaluation-card footer button.secondary-action { color: #20543c; background: transparent; border: 1px solid rgba(32,84,60,.3); }
.alternative-list { margin-top: .75rem; padding-top: .7rem; border-top: 1px solid rgba(16,38,61,.1); }.alternative-list h4 { margin: 0 0 .45rem; color: #173652; font-size: .72rem; text-transform: uppercase; }.alternative-list > p { color: #71808c; font-size: .7rem; }.alternative-list article { display: flex; justify-content: space-between; gap: .7rem; align-items: center; padding: .5rem; border-radius: 9px; background: rgba(32,84,60,.06); }.alternative-list article + article { margin-top: .35rem; }.alternative-list article strong,.alternative-list article span { display: block; }.alternative-list article span { color: #71808c; font-size: .66rem; }
.watchlist-empty { display: grid; min-height: 240px; place-items: center; padding: 2rem; color: #71808c; text-align: center; }
@media (max-width: 760px) { .watchlists-layout { grid-template-columns: 1fr; }.evaluation-selects,.evaluation-scores,.need-builder form,.discovery-filters { grid-template-columns: 1fr 1fr; }.need-workspace > header { align-items: stretch; flex-direction: column; }.need-workspace > header label { min-width: 0; }.calculated-fit { grid-template-columns: 1fr; }.need-builder__wide { grid-column: span 2; } }
</style>
