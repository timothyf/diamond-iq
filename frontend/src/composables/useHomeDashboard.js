import { computed, onMounted, ref } from 'vue'
import { API_BASE_URL } from '../config'

const emptyDashboard = () => ({
  as_of: null,
  season: null,
  games: [],
  leaders: [],
  team_pulse: {
    best_records: [],
    run_differential: [],
    recent_form: [],
  },
  freshness: {},
})

export function useHomeDashboard() {
  const dashboard = ref(emptyDashboard())
  const loading = ref(true)
  const error = ref('')

  async function load() {
    loading.value = true
    error.value = ''

    try {
      const response = await fetch(`${API_BASE_URL}/api/home`, { headers: { Accept: 'application/json' } })
      if (!response.ok) throw new Error(`Request failed with status ${response.status}`)

      const payload = await response.json()
      dashboard.value = { ...emptyDashboard(), ...(payload.data || {}) }
    } catch (fetchError) {
      dashboard.value = emptyDashboard()
      error.value = 'Unable to load today’s DiamondIQ briefing. Confirm the Rails API is running and reachable.'
      console.error(fetchError)
    } finally {
      loading.value = false
    }
  }

  onMounted(load)

  return {
    dashboard: computed(() => dashboard.value),
    loading: computed(() => loading.value),
    error: computed(() => error.value),
    refresh: load,
  }
}
