import { computed, getCurrentInstance, onBeforeUnmount, ref } from 'vue'

import { adminRequestHeaders } from './apiAuth'
import { API_BASE_URL, frontendConfig } from '../config'

const ACTIVE_STATUSES = ['queued', 'running']
const POLL_INTERVAL_MS = frontendConfig.pollingIntervalMs

export function normalizeAdminTaskRun(data = {}) {
  return {
    id: data.id,
    taskName: data.task_name || '',
    status: data.status || 'queued',
    taskParameters: data.task_parameters || {},
    initiatedBy: data.initiated_by
      ? {
          id: data.initiated_by.id,
          name: data.initiated_by.name,
          email: data.initiated_by.email,
          role: data.initiated_by.role,
        }
      : null,
    totalItems: Number(data.total_items || 0),
    completedItems: Number(data.completed_items || 0),
    failedItems: Number(data.failed_items || 0),
    processedItems: Number(data.processed_items || 0),
    progressPercentage: Number(data.progress_percentage || 0),
    currentItemLabel: data.current_item_label || '',
    cancelRequested: Boolean(data.cancel_requested),
    errorMessage: data.error_message || '',
    resultData: data.result_data || {},
    elapsedSeconds: data.elapsed_seconds === null ? null : Number(data.elapsed_seconds || 0),
    estimatedRemainingSeconds:
      data.estimated_remaining_seconds === null ? null : Number(data.estimated_remaining_seconds || 0),
    startedAt: data.started_at || null,
    finishedAt: data.finished_at || null,
    createdAt: data.created_at || null,
  }
}

export function taskRunStatusMessage(task) {
  if (!task) return ''
  const initiator = task.initiatedBy?.name || task.initiatedBy?.email
  const attribution = initiator ? ` by ${initiator}` : ''

  if (task.status === 'queued') return `Queued${attribution} · waiting for a background worker.`
  if (task.status === 'running') {
    return `Running${attribution} · ${task.progressPercentage.toFixed(1)}% complete.`
  }
  if (task.status === 'cancelled') return `Cancelled${attribution}.`
  if (task.status === 'failed') return task.errorMessage || task.resultData?.message || 'Background task failed.'
  return task.resultData?.message || `Completed${attribution}.`
}

export function useBackgroundTaskRun(taskName) {
  const task = ref(null)
  const starting = ref(false)
  const requestError = ref('')
  let pollTimer = null

  const active = computed(() => ACTIVE_STATUSES.includes(task.value?.status))
  const error = computed(() => requestError.value || task.value?.errorMessage || '')
  const summary = computed(() => taskRunStatusMessage(task.value))

  function stopPolling() {
    if (pollTimer) window.clearTimeout(pollTimer)
    pollTimer = null
  }

  function schedulePoll() {
    stopPolling()
    if (!active.value || !task.value?.id) return
    pollTimer = window.setTimeout(refresh, POLL_INTERVAL_MS)
  }

  function replaceTask(data) {
    task.value = normalizeAdminTaskRun(data)
    schedulePoll()
    return task.value
  }

  async function request(url, options = {}) {
    const response = await fetch(`${API_BASE_URL}${url}`, options)
    const payload = await response.json()
    if (!response.ok) throw new Error(payload?.message || `Background task request failed with status ${response.status}.`)
    return replaceTask(payload?.data || {})
  }

  async function start(url, options = {}) {
    starting.value = true
    requestError.value = ''
    try {
      return await request(url, options)
    } catch (startError) {
      requestError.value = startError.message || 'Unable to start the background task.'
      return null
    } finally {
      starting.value = false
    }
  }

  async function refresh() {
    if (!task.value?.id) return null
    try {
      return await request(`/api/admin/task_runs/${task.value.id}`, {
        headers: adminRequestHeaders({ Accept: 'application/json' }),
      })
    } catch (pollError) {
      requestError.value = pollError.message || 'Unable to refresh background task status.'
      stopPolling()
      return null
    }
  }

  async function cancel() {
    if (!task.value?.id || !active.value) return null
    try {
      return await request(`/api/admin/task_runs/${task.value.id}/cancel`, {
        method: 'POST',
        headers: adminRequestHeaders({ Accept: 'application/json' }),
      })
    } catch (cancelError) {
      requestError.value = cancelError.message || 'Unable to cancel the background task.'
      return null
    }
  }

  async function loadLatest() {
    requestError.value = ''
    try {
      const query = new URLSearchParams()
      if (Array.isArray(taskName)) {
        taskName.forEach((name) => query.append('task_names[]', name))
      } else if (taskName) {
        query.set('task_name', taskName)
      }
      const response = await fetch(`${API_BASE_URL}/api/admin/task_runs?${query}`, {
        headers: adminRequestHeaders({ Accept: 'application/json' }),
      })
      const payload = await response.json()
      if (!response.ok) throw new Error(payload?.message || `Task status failed with status ${response.status}.`)
      const latest = payload?.data?.[0]
      return latest ? replaceTask(latest) : null
    } catch (loadError) {
      requestError.value = loadError.message || 'Unable to load background task status.'
      return null
    }
  }

  if (getCurrentInstance()) onBeforeUnmount(stopPolling)

  return {
    task: computed(() => task.value),
    active,
    starting: computed(() => starting.value),
    error,
    summary,
    start,
    refresh,
    cancel,
    loadLatest,
    stopPolling,
  }
}

export function taskRunAttribution(task) {
  const initiator = task?.initiatedBy?.name || task?.initiatedBy?.email
  return initiator ? ` Started by ${initiator}.` : ''
}
