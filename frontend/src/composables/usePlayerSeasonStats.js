import { computed, ref, watch } from 'vue'

const API_BASE_URL = import.meta.env.VITE_API_BASE_URL || ''

function buildSearchParams(query) {
  const searchParams = new URLSearchParams()

  if (query.view) searchParams.set('view', String(query.view))
  if (query.page) searchParams.set('page', String(query.page))
  if (query.perPage) searchParams.set('per_page', String(query.perPage))
  if (query.sort) searchParams.set('sort', query.sort)

  Object.entries(query.filters || {}).forEach(([key, value]) => {
    if (value === '' || value === null || value === undefined) return
    searchParams.set(`filter[${key}]`, String(value))
  })

  return searchParams
}

function normalizeMeta(meta = {}) {
  return {
    page: meta.page || 1,
    perPage: meta.per_page || 25,
    totalCount: meta.total_count || 0,
    totalPages: meta.total_pages || 0,
    sort: meta.sort || 'player_name',
    filters: meta.filters || {},
    category: meta.category || 'batting',
    dataRange: meta.data_range || null,
    availableSeasons: meta.available_seasons || [],
    availableTeams: meta.available_teams || [],
    columns: meta.columns || [],
  }
}

export function usePlayerSeasonStats(queryRef) {
  const rows = ref([])
  const meta = ref(normalizeMeta())
  const loading = ref(false)
  const error = ref('')
  let requestCounter = 0

  async function load() {
    const requestId = requestCounter + 1
    requestCounter = requestId
    loading.value = true
    error.value = ''

    try {
      const searchParams = buildSearchParams(queryRef.value)
      const response = await fetch(`${API_BASE_URL}/api/player_season_stats?${searchParams.toString()}`, {
        headers: {
          Accept: 'application/json',
        },
      })

      if (!response.ok) {
        throw new Error(`Request failed with status ${response.status}`)
      }

      const payload = await response.json()
      if (requestId !== requestCounter) return

      rows.value = payload.data || []
      meta.value = normalizeMeta(payload.meta)
    } catch (fetchError) {
      if (requestId !== requestCounter) return

      rows.value = []
      meta.value = normalizeMeta()
      error.value = 'Unable to load player season stats. Confirm the Rails API is running and reachable from the frontend.'
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
      load()
    },
    { deep: true, immediate: true },
  )

  return {
    rows: computed(() => rows.value),
    meta: computed(() => meta.value),
    loading: computed(() => loading.value),
    error: computed(() => error.value),
    refresh: load,
  }
}
