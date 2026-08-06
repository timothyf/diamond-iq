<script setup>
import { computed, onBeforeUnmount, onMounted, ref, watch } from 'vue'
import { useRouter } from 'vue-router'
import { API_BASE_URL, frontendConfig } from '../config'

const MIN_QUERY_LENGTH = 2
const SEARCH_DELAY_MS = frontendConfig.searchDebounceMs
const PLAYER_RESULT_LIMIT = frontendConfig.playerSearchLimit
const TEAM_RESULT_LIMIT = frontendConfig.teamSearchLimit

const router = useRouter()
const root = ref(null)
const query = ref('')
const results = ref([])
const loading = ref(false)
const error = ref('')
const panelOpen = ref(false)
const activeIndex = ref(-1)
let debounceTimer
let requestSequence = 0
let abortController

const normalizedQuery = computed(() => normalizeQuery(query.value))
const canSearch = computed(() => normalizedQuery.value.length >= MIN_QUERY_LENGTH)
const activeDescendant = computed(() => (
  activeIndex.value >= 0 ? `global-search-result-${results.value[activeIndex.value]?.key}` : undefined
))

watch(normalizedQuery, (value) => {
  clearTimeout(debounceTimer)
  abortActiveRequest()
  error.value = ''
  activeIndex.value = -1

  if (value.length < MIN_QUERY_LENGTH) {
    results.value = []
    loading.value = false
    panelOpen.value = false
    return
  }

  panelOpen.value = true
  loading.value = true
  debounceTimer = setTimeout(() => search(value), SEARCH_DELAY_MS)
})

onMounted(() => document.addEventListener('pointerdown', handleDocumentPointerDown))

onBeforeUnmount(() => {
  clearTimeout(debounceTimer)
  abortActiveRequest()
  document.removeEventListener('pointerdown', handleDocumentPointerDown)
})

function normalizeQuery(value) {
  return String(value || '')
    .normalize('NFKC')
    .replaceAll('’', "'")
    .replace(/[^\p{L}\p{N}'-]+/gu, ' ')
    .replace(/\s+/g, ' ')
    .trim()
    .slice(0, 80)
}

async function search(value) {
  const requestId = requestSequence + 1
  requestSequence = requestId
  abortController = new AbortController()

  const playerParams = new URLSearchParams({ per_page: String(PLAYER_RESULT_LIMIT), sort: 'last_name' })
  playerParams.set('filter[name]', value)
  const teamParams = new URLSearchParams({ per_page: String(TEAM_RESULT_LIMIT) })
  teamParams.set('filter[name]', value)

  try {
    const [playerResponse, teamResponse] = await Promise.all([
      fetch(`${API_BASE_URL}/api/players?${playerParams}`, {
        headers: { Accept: 'application/json' },
        signal: abortController.signal,
      }),
      fetch(`${API_BASE_URL}/api/teams?${teamParams}`, {
        headers: { Accept: 'application/json' },
        signal: abortController.signal,
      }),
    ])
    if (!playerResponse.ok || !teamResponse.ok) throw new Error('Search request failed')

    const [playerPayload, teamPayload] = await Promise.all([playerResponse.json(), teamResponse.json()])
    if (requestId !== requestSequence || value !== normalizedQuery.value) return

    const seenPlayers = new Set()
    const players = (Array.isArray(playerPayload?.data) ? playerPayload.data : [])
      .filter((player) => player?.id && player?.full_name && !seenPlayers.has(player.id) && seenPlayers.add(player.id))
      .slice(0, PLAYER_RESULT_LIMIT)
      .map((player) => ({
        key: `player-${player.id}`,
        type: 'player',
        id: player.id,
        name: player.full_name,
        subtitle: `Player · MLB ${player.mlb_id}`,
        meta: player.team?.abbreviation || '—',
        metaLabel: player.team?.short_name || player.team?.team_name || player.team?.name || 'No current team',
      }))
    const seenTeams = new Set()
    const teams = (Array.isArray(teamPayload?.data) ? teamPayload.data : [])
      .filter((team) => team?.id && team?.name && !seenTeams.has(team.id) && seenTeams.add(team.id))
      .slice(0, TEAM_RESULT_LIMIT)
      .map((team) => ({
        key: `team-${team.id}`,
        type: 'team',
        id: team.id,
        name: team.name,
        subtitle: `Team · MLB ${team.mlb_id}`,
        meta: team.abbreviation || '—',
        metaLabel: team.location_name || team.short_name || team.team_name || '',
      }))
    results.value = [...players, ...teams]
    activeIndex.value = results.value.length ? 0 : -1
  } catch (searchError) {
    if (searchError.name === 'AbortError' || requestId !== requestSequence) return

    results.value = []
    error.value = 'Search is temporarily unavailable.'
  } finally {
    if (requestId === requestSequence) loading.value = false
  }
}

function abortActiveRequest() {
  requestSequence += 1
  abortController?.abort()
  abortController = undefined
}

function handleFocus() {
  if (canSearch.value) panelOpen.value = true
}

function handleDocumentPointerDown(event) {
  if (!root.value?.contains(event.target)) panelOpen.value = false
}

function moveActive(direction) {
  if (!results.value.length) return

  panelOpen.value = true
  activeIndex.value = (activeIndex.value + direction + results.value.length) % results.value.length
}

function selectActive() {
  const result = results.value[activeIndex.value]
  if (result) selectResult(result)
}

async function selectResult(result) {
  panelOpen.value = false
  query.value = ''
  results.value = []
  await router.push({
    name: result.type === 'team' ? 'team-profile' : 'player-profile',
    params: { id: String(result.id) },
  })
}

function closePanel() {
  panelOpen.value = false
  activeIndex.value = -1
}
</script>

<template>
  <div ref="root" class="player-search">
    <label class="visually-hidden" for="global-player-search">Find a player or team</label>
    <div class="player-search__control">
      <span aria-hidden="true">⌕</span>
      <input
        id="global-player-search"
        v-model="query"
        type="search"
        inputmode="search"
        autocomplete="off"
        maxlength="100"
        placeholder="Find a player or team…"
        role="combobox"
        aria-autocomplete="list"
        aria-controls="player-search-results"
        :aria-expanded="panelOpen"
        :aria-activedescendant="activeDescendant"
        @focus="handleFocus"
        @keydown.down.prevent="moveActive(1)"
        @keydown.up.prevent="moveActive(-1)"
        @keydown.enter.prevent="selectActive"
        @keydown.esc="closePanel"
      />
      <span v-if="loading" class="player-search__spinner" aria-label="Searching"></span>
    </div>

    <div v-if="panelOpen" id="player-search-results" class="player-search__panel">
      <p v-if="error" class="player-search__message player-search__message--error">{{ error }}</p>
      <p v-else-if="loading && !results.length" class="player-search__message">Searching players and teams…</p>
      <p v-else-if="!results.length" class="player-search__message">
        No players or teams found for “{{ normalizedQuery }}”.
      </p>
      <ul v-else role="listbox" aria-label="Player and team search results">
        <li
          v-for="(result, index) in results"
          :id="`global-search-result-${result.key}`"
          :key="result.key"
          role="option"
          :aria-selected="index === activeIndex"
        >
          <button
            type="button"
            :class="{ 'is-active': index === activeIndex }"
            @mouseenter="activeIndex = index"
            @mousedown.prevent
            @click="selectResult(result)"
          >
            <span>
              <strong>{{ result.name }}</strong>
              <small>{{ result.subtitle }}</small>
            </span>
            <span class="player-search__team">
              {{ result.meta }}
              <small>{{ result.metaLabel }}</small>
            </span>
          </button>
        </li>
      </ul>
    </div>
  </div>
</template>
