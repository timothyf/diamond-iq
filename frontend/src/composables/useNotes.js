import { computed, ref, toValue } from 'vue'

import { authRequestHeaders } from './apiAuth'

const API_BASE_URL = import.meta.env.VITE_API_BASE_URL || ''

function normalizeUser(user) {
  return user ? { id: user.id, name: user.name || '', role: user.role || '' } : null
}

function normalizeNote(note = {}) {
  return {
    id: note.id,
    targetType: note.target_type || '',
    targetId: note.target_id || '',
    targetMetadata: note.target_metadata || {},
    body: note.body || '',
    noteDate: note.note_date || '',
    tags: note.tags || [],
    author: normalizeUser(note.author),
    lastEditedBy: normalizeUser(note.last_edited_by),
    editable: Boolean(note.editable),
    historyCount: Number(note.history_count || 0),
    createdAt: note.created_at || null,
    updatedAt: note.updated_at || null,
  }
}

export function useNotes(targetType, targetId) {
  const notes = ref([])
  const availableTags = ref([])
  const loading = ref(false)
  const saving = ref(false)
  const error = ref('')

  async function request(path, options = {}) {
    const response = await fetch(`${API_BASE_URL}${path}`, options)
    const payload = response.status === 204 ? null : await response.json().catch(() => ({}))
    if (!response.ok) throw new Error(payload?.message || `Notes request failed with status ${response.status}.`)
    return payload?.data
  }

  function targetQuery() {
    return new URLSearchParams({
      target_type: toValue(targetType),
      target_id: String(toValue(targetId)),
    })
  }

  async function load() {
    if (!toValue(targetId)) return []
    loading.value = true
    error.value = ''
    try {
      const loadedNotes = await request(`/api/notes?${targetQuery()}`, {
        headers: authRequestHeaders({ Accept: 'application/json' }),
      })
      notes.value = (loadedNotes || []).map(normalizeNote)
      await loadTags().catch(() => {})
      return notes.value
    } catch (loadError) {
      error.value = loadError.message
      return []
    } finally {
      loading.value = false
    }
  }

  async function create({ body, noteDate, tags }) {
    saving.value = true
    error.value = ''
    try {
      const data = await request('/api/notes', {
        method: 'POST',
        headers: authRequestHeaders({ Accept: 'application/json', 'Content-Type': 'application/json' }),
        body: JSON.stringify({
          target_type: toValue(targetType),
          target_id: String(toValue(targetId)),
          body,
          note_date: noteDate,
          tags,
        }),
      })
      const note = normalizeNote(data)
      notes.value = [note, ...notes.value]
      await loadTags().catch(() => {})
      return note
    } catch (saveError) {
      error.value = saveError.message
      return null
    } finally {
      saving.value = false
    }
  }

  async function update(note, attributes) {
    saving.value = true
    error.value = ''
    try {
      const data = await request(`/api/notes/${note.id}`, {
        method: 'PATCH',
        headers: authRequestHeaders({ Accept: 'application/json', 'Content-Type': 'application/json' }),
        body: JSON.stringify(attributes),
      })
      const updated = normalizeNote(data)
      notes.value = notes.value.map((entry) => (entry.id === updated.id ? updated : entry))
      await loadTags().catch(() => {})
      return updated
    } catch (saveError) {
      error.value = saveError.message
      return null
    } finally {
      saving.value = false
    }
  }

  async function remove(note) {
    error.value = ''
    try {
      await request(`/api/notes/${note.id}`, {
        method: 'DELETE',
        headers: authRequestHeaders({ Accept: 'application/json' }),
      })
      notes.value = notes.value.filter((entry) => entry.id !== note.id)
      return true
    } catch (deleteError) {
      error.value = deleteError.message
      return false
    }
  }

  async function history(note) {
    error.value = ''
    try {
      return await request(`/api/notes/${note.id}/history`, {
        headers: authRequestHeaders({ Accept: 'application/json' }),
      }) || []
    } catch (historyError) {
      error.value = historyError.message
      return []
    }
  }

  async function loadTags() {
    const data = await request('/api/tags', {
      headers: authRequestHeaders({ Accept: 'application/json' }),
    })
    availableTags.value = data || []
  }

  function clear() {
    notes.value = []
    error.value = ''
  }

  return {
    notes: computed(() => notes.value),
    availableTags: computed(() => availableTags.value),
    loading: computed(() => loading.value),
    saving: computed(() => saving.value),
    error: computed(() => error.value),
    load,
    create,
    update,
    remove,
    history,
    clear,
  }
}
