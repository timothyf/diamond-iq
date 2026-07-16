import { computed, onBeforeUnmount, ref } from 'vue'

import { adminRequestHeaders } from './apiAuth'

const API_BASE_URL = import.meta.env.VITE_API_BASE_URL || ''
const POLL_INTERVAL_MS = 1500
const ACTIVE_STATUSES = ['queued', 'running']

export function useGameDetailsSync() {
  const task = ref(null)
  const starting = ref(false)
  const estimating = ref(false)
  const error = ref('')
  let pollTimer = null

  function normalizeTask(data) {
    if (!data) return null
    return {
      id: data.id,
      taskName: data.task_name,
      status: data.status,
      taskParameters: data.task_parameters || {},
      totalItems: Number(data.total_items || 0),
      completedItems: Number(data.completed_items || 0),
      failedItems: Number(data.failed_items || 0),
      processedItems: Number(data.processed_items || 0),
      progressPercentage: Number(data.progress_percentage || 0),
      currentItemMlbId: data.current_item_mlb_id,
      currentItemLabel: data.current_item_label,
      cancelRequested: data.cancel_requested === true,
      errorMessage: data.error_message,
      resultData: data.result_data || {},
      elapsedSeconds: numericOrNull(data.elapsed_seconds),
      estimatedRemainingSeconds: numericOrNull(data.estimated_remaining_seconds),
      startedAt: data.started_at,
      finishedAt: data.finished_at,
      lastHeartbeatAt: data.last_heartbeat_at,
    }
  }

  function numericOrNull(value) {
    return value === null || value === undefined ? null : Number(value)
  }

  function replaceTask(data) {
    task.value = normalizeTask(data)
    schedulePoll()
    return task.value
  }

  function clearPoll() {
    if (pollTimer) window.clearTimeout(pollTimer)
    pollTimer = null
  }

  function schedulePoll() {
    clearPoll()
    if (task.value && ACTIVE_STATUSES.includes(task.value.status)) {
      pollTimer = window.setTimeout(poll, POLL_INTERVAL_MS)
    }
  }

  async function start(parameters) {
    starting.value = true
    error.value = ''
    clearPoll()
    try {
      const response = await fetch(`${API_BASE_URL}/api/admin/task_runs`, {
        method: 'POST',
        headers: adminRequestHeaders({ Accept: 'application/json', 'Content-Type': 'application/json' }),
        body: JSON.stringify({ task_name: 'mlb_game_details_sync', ...parameters }),
      })
      const payload = await response.json()
      if (!response.ok) throw new Error(payload?.message || `Unable to start game synchronization (${response.status}).`)

      return replaceTask(payload.data)
    } catch (startError) {
      error.value = startError.message || 'Unable to start game synchronization.'
      return null
    } finally {
      starting.value = false
    }
  }

  async function estimate(parameters) {
    estimating.value = true
    error.value = ''
    try {
      const query = new URLSearchParams(
        Object.entries(parameters).filter(([, value]) => value !== null && value !== undefined && value !== ''),
      )
      const response = await fetch(`${API_BASE_URL}/api/admin/task_runs/estimate?${query}`, {
        headers: { Accept: 'application/json' },
      })
      const payload = await response.json()
      if (!response.ok) throw new Error(payload?.message || `Unable to estimate game synchronization (${response.status}).`)

      return normalizeEstimate(payload.data)
    } catch (estimateError) {
      error.value = estimateError.message || 'Unable to estimate game synchronization.'
      return null
    } finally {
      estimating.value = false
    }
  }

  function normalizeEstimate(data) {
    if (!data) return null
    return {
      taskParameters: data.task_parameters || {},
      gameCount: Number(data.game_count || 0),
      estimatedSeconds: Number(data.estimated_seconds || 0),
      lowEstimatedSeconds: Number(data.low_estimated_seconds || 0),
      highEstimatedSeconds: Number(data.high_estimated_seconds || 0),
      secondsPerGame: Number(data.seconds_per_game || 0),
      timingSampleGameCount: Number(data.timing_sample_game_count || 0),
      timingSampleRunCount: Number(data.timing_sample_run_count || 0),
      estimateSource: data.estimate_source,
    }
  }

  async function poll() {
    if (!task.value?.id) return
    try {
      const response = await fetch(`${API_BASE_URL}/api/admin/task_runs/${encodeURIComponent(task.value.id)}`, {
        headers: { Accept: 'application/json' },
      })
      const payload = await response.json()
      if (!response.ok) throw new Error(payload?.message || `Unable to load synchronization progress (${response.status}).`)

      error.value = ''
      replaceTask(payload.data)
    } catch (pollError) {
      error.value = pollError.message || 'Unable to refresh synchronization progress.'
      schedulePoll()
    }
  }

  async function loadActiveTask() {
    error.value = ''
    try {
      const query = new URLSearchParams({ task_name: 'mlb_game_details_sync', active: 'true' })
      const response = await fetch(`${API_BASE_URL}/api/admin/task_runs?${query}`, {
        headers: { Accept: 'application/json' },
      })
      const payload = await response.json()
      if (!response.ok) throw new Error(payload?.message || `Unable to recover synchronization progress (${response.status}).`)

      const activeTask = payload?.data?.[0]
      return activeTask ? replaceTask(activeTask) : null
    } catch (loadError) {
      error.value = loadError.message || 'Unable to recover synchronization progress.'
      return null
    }
  }

  async function cancel() {
    if (!task.value?.id || !ACTIVE_STATUSES.includes(task.value.status)) return null
    error.value = ''
    try {
      const response = await fetch(`${API_BASE_URL}/api/admin/task_runs/${encodeURIComponent(task.value.id)}/cancel`, {
        method: 'POST',
        headers: adminRequestHeaders({ Accept: 'application/json' }),
      })
      const payload = await response.json()
      if (!response.ok) throw new Error(payload?.message || `Unable to cancel synchronization (${response.status}).`)

      return replaceTask(payload.data)
    } catch (cancelError) {
      error.value = cancelError.message || 'Unable to request cancellation.'
      return null
    }
  }

  onBeforeUnmount(clearPoll)

  return {
    task: computed(() => task.value),
    active: computed(() => Boolean(task.value && ACTIVE_STATUSES.includes(task.value.status))),
    starting: computed(() => starting.value),
    estimating: computed(() => estimating.value),
    error: computed(() => error.value),
    start,
    estimate,
    cancel,
    poll,
    loadActiveTask,
  }
}
