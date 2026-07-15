import { computed, ref } from 'vue'

import { adminRequestHeaders } from './apiAuth'

const API_BASE_URL = import.meta.env.VITE_API_BASE_URL || ''

export function useAdminTask() {
  const runningTask = ref('')
  const error = ref('')
  const lastResult = ref(null)

  async function runTask(taskName, parameters = {}) {
    runningTask.value = taskName
    error.value = ''

    try {
      const response = await fetch(`${API_BASE_URL}/api/admin/tasks/${encodeURIComponent(taskName)}/run`, {
        method: 'POST',
        headers: adminRequestHeaders({
          Accept: 'application/json',
          'Content-Type': 'application/json',
        }),
        body: JSON.stringify(parameters),
      })
      const payload = await response.json()

      if (!response.ok) {
        throw new Error(payload?.message || `Admin task failed with status ${response.status}.`)
      }

      lastResult.value = {
        ...payload,
        finishedAt: new Date().toISOString(),
      }
      return payload
    } catch (taskError) {
      error.value = taskError.message || 'Unable to run the admin task.'
      return null
    } finally {
      runningTask.value = ''
    }
  }

  return {
    runningTask: computed(() => runningTask.value),
    error: computed(() => error.value),
    lastResult: computed(() => lastResult.value),
    runTask,
  }
}
