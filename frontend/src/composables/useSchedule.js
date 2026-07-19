import { computed, ref, watch } from 'vue'

const API_BASE_URL = import.meta.env.VITE_API_BASE_URL || ''

export function useSchedule(date) {
  const games = ref([])
  const loading = ref(false)
  const error = ref('')
  let requestSequence = 0

  async function load() {
    const requestId = ++requestSequence
    loading.value = true
    error.value = ''

    try {
      const query = new URLSearchParams({
        start_date: date.value,
        end_date: date.value,
        per_page: '100',
      })
      const response = await fetch(`${API_BASE_URL}/api/games?${query}`, { headers: { Accept: 'application/json' } })
      if (!response.ok) throw new Error(`Request failed with status ${response.status}`)
      const payload = await response.json()
      if (requestId === requestSequence) games.value = payload.data || []
    } catch (fetchError) {
      if (requestId !== requestSequence) return
      games.value = []
      error.value = 'Unable to load the schedule for this date. Confirm the Rails API is running and reachable.'
      console.error(fetchError)
    } finally {
      if (requestId === requestSequence) loading.value = false
    }
  }

  watch(date, load, { immediate: true })

  return {
    games: computed(() => games.value),
    loading: computed(() => loading.value),
    error: computed(() => error.value),
    refresh: load,
  }
}
