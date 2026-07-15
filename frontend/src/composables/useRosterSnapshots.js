import { computed, ref } from 'vue'

const API_BASE_URL = import.meta.env.VITE_API_BASE_URL || ''

export function useRosterSnapshots() {
  const snapshots = ref([])
  const loading = ref(false)
  const error = ref('')

  async function loadSnapshots({ teamMlbId, on }) {
    loading.value = true
    error.value = ''

    try {
      const query = new URLSearchParams({ team_mlb_id: String(teamMlbId), on })
      const response = await fetch(`${API_BASE_URL}/api/roster_snapshots?${query}`)
      const payload = await response.json()

      if (!response.ok) {
        throw new Error(payload?.message || `Roster snapshot lookup failed with status ${response.status}.`)
      }

      snapshots.value = payload?.data || []
      return payload
    } catch (loadError) {
      snapshots.value = []
      error.value = loadError.message || 'Unable to load roster snapshots.'
      return null
    } finally {
      loading.value = false
    }
  }

  return {
    snapshots: computed(() => snapshots.value),
    loading: computed(() => loading.value),
    error: computed(() => error.value),
    loadSnapshots,
  }
}
