import { computed, ref, watch } from 'vue'
import { API_BASE_URL, frontendConfig } from '../config'
const MIN_QUERY_LENGTH = 2
const DEBOUNCE_MS = frontendConfig.playerSuggestionDebounceMs

function buildSearchParams(query) {
  const searchParams = new URLSearchParams()
  searchParams.set('per_page', String(query.perPage || frontendConfig.playerSuggestionLimit))
  searchParams.set('sort', query.sort || 'last_name')

  if (query.name) {
    searchParams.set('filter[name]', query.name)
  }

  if (query.teamId) {
    searchParams.set('filter[team_id]', String(query.teamId))
  }

  return searchParams
}

function normalizePlayers(players = []) {
  return players.map((player) => ({
    id: player.id,
    mlbId: player.mlb_id,
    firstName: player.first_name,
    lastName: player.last_name,
    fullName: [player.first_name, player.last_name].filter(Boolean).join(' '),
    team: player.team || {},
  }))
}

export function usePlayerSuggestions(queryRef) {
  const suggestions = ref([])
  const loading = ref(false)
  const error = ref('')
  let debounceTimer = null
  let requestCounter = 0

  async function load() {
    const query = queryRef.value || {}
    const name = query.name?.trim() || ''

    if (name.length < MIN_QUERY_LENGTH) {
      suggestions.value = []
      loading.value = false
      error.value = ''
      return
    }

    const requestId = requestCounter + 1
    requestCounter = requestId
    loading.value = true
    error.value = ''

    try {
      const searchParams = buildSearchParams(query)
      const response = await fetch(`${API_BASE_URL}/api/players?${searchParams.toString()}`, {
        headers: {
          Accept: 'application/json',
        },
      })

      if (!response.ok) {
        throw new Error(`Request failed with status ${response.status}`)
      }

      const payload = await response.json()
      if (requestId !== requestCounter) return

      suggestions.value = normalizePlayers(payload.data)
    } catch (fetchError) {
      if (requestId !== requestCounter) return

      suggestions.value = []
      error.value = 'Unable to load player suggestions.'
      console.error(fetchError)
    } finally {
      if (requestId === requestCounter) {
        loading.value = false
      }
    }
  }

  watch(
    queryRef,
    () => {
      if (debounceTimer) {
        window.clearTimeout(debounceTimer)
      }

      debounceTimer = window.setTimeout(() => {
        load()
      }, DEBOUNCE_MS)
    },
    { deep: true, immediate: true },
  )

  return {
    suggestions: computed(() => suggestions.value),
    loading: computed(() => loading.value),
    error: computed(() => error.value),
  }
}
