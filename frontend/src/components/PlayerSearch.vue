<script setup>
import { computed, onBeforeUnmount, onMounted, ref, watch } from 'vue'
import { useRouter } from 'vue-router'

const API_BASE_URL = import.meta.env.VITE_API_BASE_URL || ''
const MIN_QUERY_LENGTH = 2
const SEARCH_DELAY_MS = 250
const RESULT_LIMIT = 8

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
  activeIndex.value >= 0 ? `player-search-result-${results.value[activeIndex.value]?.id}` : undefined
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

  const params = new URLSearchParams({ per_page: String(RESULT_LIMIT), sort: 'last_name' })
  params.set('filter[name]', value)

  try {
    const response = await fetch(`${API_BASE_URL}/api/players?${params}`, {
      headers: { Accept: 'application/json' },
      signal: abortController.signal,
    })
    if (!response.ok) throw new Error(`Request failed with status ${response.status}`)

    const payload = await response.json()
    if (requestId !== requestSequence || value !== normalizedQuery.value) return

    const seen = new Set()
    results.value = (Array.isArray(payload?.data) ? payload.data : [])
      .filter((player) => player?.id && player?.full_name && !seen.has(player.id) && seen.add(player.id))
      .slice(0, RESULT_LIMIT)
    activeIndex.value = results.value.length ? 0 : -1
  } catch (searchError) {
    if (searchError.name === 'AbortError' || requestId !== requestSequence) return

    results.value = []
    error.value = 'Player search is temporarily unavailable.'
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
  const player = results.value[activeIndex.value]
  if (player) selectPlayer(player)
}

async function selectPlayer(player) {
  panelOpen.value = false
  query.value = ''
  results.value = []
  await router.push({ name: 'player-profile', params: { id: String(player.id) } })
}

function closePanel() {
  panelOpen.value = false
  activeIndex.value = -1
}
</script>

<template>
  <div ref="root" class="player-search">
    <label class="visually-hidden" for="global-player-search">Find a player profile</label>
    <div class="player-search__control">
      <span aria-hidden="true">⌕</span>
      <input
        id="global-player-search"
        v-model="query"
        type="search"
        inputmode="search"
        autocomplete="off"
        maxlength="100"
        placeholder="Find a player…"
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
      <p v-else-if="loading && !results.length" class="player-search__message">Searching players…</p>
      <p v-else-if="!results.length" class="player-search__message">
        No players found for “{{ normalizedQuery }}”.
      </p>
      <ul v-else role="listbox" aria-label="Player search results">
        <li
          v-for="(player, index) in results"
          :id="`player-search-result-${player.id}`"
          :key="player.id"
          role="option"
          :aria-selected="index === activeIndex"
        >
          <button
            type="button"
            :class="{ 'is-active': index === activeIndex }"
            @mouseenter="activeIndex = index"
            @mousedown.prevent
            @click="selectPlayer(player)"
          >
            <span>
              <strong>{{ player.full_name }}</strong>
              <small>MLB {{ player.mlb_id }}</small>
            </span>
            <span class="player-search__team">
              {{ player.team?.abbreviation || '—' }}
              <small>{{ player.team?.short_name || player.team?.team_name || player.team?.name || 'No current team' }}</small>
            </span>
          </button>
        </li>
      </ul>
    </div>
  </div>
</template>
