import { computed, ref } from 'vue'

import { adminRequestHeaders } from './apiAuth'

const API_BASE_URL = import.meta.env.VITE_API_BASE_URL || ''

async function request(path, options = {}) {
  const response = await fetch(`${API_BASE_URL}${path}`, options)
  const payload = await response.json().catch(() => ({}))
  if (!response.ok) throw new Error(payload?.message || 'The user access request could not be completed.')
  return payload
}

export function useAdminUsers() {
  const users = ref([])
  const roles = ref([])
  const summary = ref({ activeCount: 0, disabledCount: 0, administratorCount: 0 })
  const loading = ref(false)
  const error = ref('')
  const actionUserId = ref(null)
  const creating = ref(false)
  const temporaryAccess = ref(null)

  async function loadUsers() {
    loading.value = true
    error.value = ''
    try {
      const payload = await request('/api/admin/users', {
        headers: adminRequestHeaders({ Accept: 'application/json' }),
      })
      users.value = payload.data || []
      roles.value = payload.meta?.roles || []
      summary.value = {
        activeCount: Number(payload.meta?.active_count || 0),
        disabledCount: Number(payload.meta?.disabled_count || 0),
        administratorCount: Number(payload.meta?.administrator_count || 0),
      }
      return users.value
    } catch (requestError) {
      error.value = requestError.message
      return null
    } finally {
      loading.value = false
    }
  }

  async function updateUser(userId, changes) {
    actionUserId.value = userId
    error.value = ''
    temporaryAccess.value = null
    try {
      const payload = await request(`/api/admin/users/${encodeURIComponent(userId)}`, {
        method: 'PATCH',
        headers: adminRequestHeaders({ Accept: 'application/json', 'Content-Type': 'application/json' }),
        body: JSON.stringify(changes),
      })
      replaceUser(payload.data)
      await loadUsers()
      return payload.data
    } catch (requestError) {
      error.value = requestError.message
      return null
    } finally {
      actionUserId.value = null
    }
  }

  async function createUser(attributes) {
    creating.value = true
    error.value = ''
    temporaryAccess.value = null
    try {
      const payload = await request('/api/admin/users', {
        method: 'POST',
        headers: adminRequestHeaders({ Accept: 'application/json', 'Content-Type': 'application/json' }),
        body: JSON.stringify(attributes),
      })
      temporaryAccess.value = {
        userName: payload.data.name,
        email: payload.data.email,
        password: payload.data.temporary_password,
        message: payload.meta?.message || '',
      }
      await loadUsers()
      return payload.data
    } catch (requestError) {
      error.value = requestError.message
      return null
    } finally {
      creating.value = false
    }
  }

  async function resetAccess(user) {
    actionUserId.value = user.id
    error.value = ''
    temporaryAccess.value = null
    try {
      const payload = await request(`/api/admin/users/${encodeURIComponent(user.id)}/reset_access`, {
        method: 'POST',
        headers: adminRequestHeaders({ Accept: 'application/json' }),
      })
      replaceUser(payload.data)
      temporaryAccess.value = {
        userName: payload.data.name,
        email: payload.data.email,
        password: payload.data.temporary_password,
        message: payload.meta?.message || '',
      }
      return payload.data
    } catch (requestError) {
      error.value = requestError.message
      return null
    } finally {
      actionUserId.value = null
    }
  }

  function replaceUser(updated) {
    const index = users.value.findIndex((user) => user.id === updated.id)
    if (index >= 0) users.value[index] = { ...users.value[index], ...updated }
  }

  function clearTemporaryAccess() {
    temporaryAccess.value = null
  }

  return {
    users: computed(() => users.value),
    roles: computed(() => roles.value),
    summary: computed(() => summary.value),
    loading: computed(() => loading.value),
    error: computed(() => error.value),
    actionUserId: computed(() => actionUserId.value),
    creating: computed(() => creating.value),
    temporaryAccess: computed(() => temporaryAccess.value),
    loadUsers,
    createUser,
    updateUser,
    resetAccess,
    clearTemporaryAccess,
  }
}
