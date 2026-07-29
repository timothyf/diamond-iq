import { computed, ref } from 'vue'

import { authRequestHeaders } from './apiAuth'

const API_BASE_URL = import.meta.env.VITE_API_BASE_URL || ''

function normalize(item = {}) {
  return {
    id: item.id,
    name: item.name || '',
    analysisType: item.analysis_type || '',
    visibility: item.visibility || 'private',
    state: item.state || {},
    reproducibleUrl: item.reproducible_url || '',
    shareUrl: item.share_url || '',
    owner: item.owner || null,
    editable: Boolean(item.editable),
    createdAt: item.created_at || null,
    updatedAt: item.updated_at || null,
  }
}

export function useSavedAnalyses(analysisType) {
  const items = ref([])
  const loading = ref(false)
  const saving = ref(false)
  const error = ref('')

  async function request(path, options = {}) {
    const response = await fetch(`${API_BASE_URL}${path}`, options)
    const payload = response.status === 204 ? null : await response.json().catch(() => ({}))
    if (!response.ok) throw new Error(payload?.message || `Saved analysis request failed with status ${response.status}.`)
    return payload?.data
  }

  async function load() {
    loading.value = true
    error.value = ''
    try {
      const query = new URLSearchParams({ analysis_type: analysisType })
      const data = await request(`/api/saved_analyses?${query}`, {
        headers: authRequestHeaders({ Accept: 'application/json' }),
      })
      items.value = (data || []).map(normalize)
      return items.value
    } catch (loadError) {
      error.value = loadError.message
      return []
    } finally {
      loading.value = false
    }
  }

  async function create({ name, visibility, state, reproducibleUrl }) {
    saving.value = true
    error.value = ''
    try {
      const data = await request('/api/saved_analyses', {
        method: 'POST',
        headers: authRequestHeaders({ Accept: 'application/json', 'Content-Type': 'application/json' }),
        body: JSON.stringify({
          name,
          visibility,
          analysis_type: analysisType,
          state,
          reproducible_url: reproducibleUrl,
        }),
      })
      const item = normalize(data)
      items.value = [item, ...items.value]
      return item
    } catch (saveError) {
      error.value = saveError.message
      return null
    } finally {
      saving.value = false
    }
  }

  async function update(item, attributes) {
    error.value = ''
    try {
      const data = await request(`/api/saved_analyses/${item.id}`, {
        method: 'PATCH',
        headers: authRequestHeaders({ Accept: 'application/json', 'Content-Type': 'application/json' }),
        body: JSON.stringify(attributes),
      })
      const updated = normalize(data)
      items.value = items.value.map((entry) => (entry.id === updated.id ? updated : entry))
      return updated
    } catch (updateError) {
      error.value = updateError.message
      return null
    }
  }

  async function remove(item) {
    error.value = ''
    try {
      await request(`/api/saved_analyses/${item.id}`, {
        method: 'DELETE',
        headers: authRequestHeaders({ Accept: 'application/json' }),
      })
      items.value = items.value.filter((entry) => entry.id !== item.id)
      return true
    } catch (deleteError) {
      error.value = deleteError.message
      return false
    }
  }

  return {
    items: computed(() => items.value),
    loading: computed(() => loading.value),
    saving: computed(() => saving.value),
    error: computed(() => error.value),
    load,
    create,
    update,
    remove,
  }
}
