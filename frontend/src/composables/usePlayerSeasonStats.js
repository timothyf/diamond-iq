import { computed, ref, watch } from 'vue'

const API_BASE_URL = import.meta.env.VITE_API_BASE_URL || ''

function buildSearchParams(query) {
  const searchParams = new URLSearchParams()

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
    sort: meta.sort || 'season',
    filters: meta.filters || {},
  }
}

export function usePlayerSeasonStats(queryRef) {
  const rows = ref([])
  const meta = ref(normalizeMeta())
  const loading = ref(false)
  const error = ref('')

  async function load() {
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
      rows.value = payload.data || []
      meta.value = normalizeMeta(payload.meta)
    } catch (fetchError) {
      rows.value = []
      meta.value = normalizeMeta()
      error.value = 'Unable to load player season stats. Confirm the Rails API is running and reachable from the frontend.'
      console.error(fetchError)
    } finally {
      loading.value = false
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
