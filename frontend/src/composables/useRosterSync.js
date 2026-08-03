import { computed, onBeforeUnmount, ref } from 'vue'
import { adminRequestHeaders } from './apiAuth'
import { API_BASE_URL, frontendConfig } from '../config'

const TASK_NAME = 'mlb_roster_sync'
const ACTIVE_STATUSES = ['queued', 'running']
const POLL_INTERVAL_MS = frontendConfig.pollingIntervalMs

export function useRosterSync() {
  const task = ref(null)
  const starting = ref(false)
  const estimating = ref(false)
  const error = ref('')
  let pollTimer = null

  const numericOrNull = (value) => value === null || value === undefined ? null : Number(value)
  function normalizeTask(data) {
    if (!data) return null
    return {
      id: data.id, taskName: data.task_name, status: data.status, taskParameters: data.task_parameters || {},
      totalItems: Number(data.total_items || 0), completedItems: Number(data.completed_items || 0),
      failedItems: Number(data.failed_items || 0), processedItems: Number(data.processed_items || 0),
      progressPercentage: Number(data.progress_percentage || 0), currentItemLabel: data.current_item_label,
      cancelRequested: data.cancel_requested === true, errorMessage: data.error_message,
      resultData: data.result_data || {}, elapsedSeconds: numericOrNull(data.elapsed_seconds),
      estimatedRemainingSeconds: numericOrNull(data.estimated_remaining_seconds),
    }
  }
  function clearPoll() { if (pollTimer) window.clearTimeout(pollTimer); pollTimer = null }
  function schedulePoll() { clearPoll(); if (task.value && ACTIVE_STATUSES.includes(task.value.status)) pollTimer = window.setTimeout(poll, POLL_INTERVAL_MS) }
  function replaceTask(data) { task.value = normalizeTask(data); schedulePoll(); return task.value }

  async function request(path, options = {}) {
    const response = await fetch(`${API_BASE_URL}${path}`, options)
    const payload = await response.json()
    if (!response.ok) throw new Error(payload?.message || `Roster synchronization request failed (${response.status}).`)
    return payload
  }

  async function start(parameters) {
    starting.value = true; error.value = ''; clearPoll()
    try {
      const payload = await request('/api/admin/task_runs', {
        method: 'POST', headers: adminRequestHeaders({ Accept: 'application/json', 'Content-Type': 'application/json' }),
        body: JSON.stringify({ task_name: TASK_NAME, ...parameters }),
      })
      return replaceTask(payload.data)
    } catch (caught) { error.value = caught.message || 'Unable to start roster synchronization.'; return null }
    finally { starting.value = false }
  }

  async function estimate(parameters) {
    estimating.value = true; error.value = ''
    try {
      const query = new URLSearchParams(Object.entries({ task_name: TASK_NAME, ...parameters }).filter(([, value]) => value !== null && value !== undefined && value !== ''))
      const payload = await request(`/api/admin/task_runs/estimate?${query}`, { headers: adminRequestHeaders({ Accept: 'application/json' }) })
      const data = payload.data
      return {
        taskParameters: data.task_parameters || {}, teamCount: Number(data.team_count || 0),
        estimatedSeconds: Number(data.estimated_seconds || 0), lowEstimatedSeconds: Number(data.low_estimated_seconds || 0),
        highEstimatedSeconds: Number(data.high_estimated_seconds || 0), secondsPerTeam: Number(data.seconds_per_team || 0),
        timingSampleTeamCount: Number(data.timing_sample_team_count || 0), timingSampleRunCount: Number(data.timing_sample_run_count || 0),
        estimateSource: data.estimate_source,
      }
    } catch (caught) { error.value = caught.message || 'Unable to estimate roster synchronization.'; return null }
    finally { estimating.value = false }
  }

  async function poll() {
    if (!task.value?.id) return
    try { const payload = await request(`/api/admin/task_runs/${encodeURIComponent(task.value.id)}`, { headers: adminRequestHeaders({ Accept: 'application/json' }) }); error.value = ''; replaceTask(payload.data) }
    catch (caught) { error.value = caught.message || 'Unable to refresh roster synchronization progress.'; schedulePoll() }
  }
  async function loadActiveTask() {
    error.value = ''
    try {
      const query = new URLSearchParams({ task_name: TASK_NAME, active: 'true' })
      const payload = await request(`/api/admin/task_runs?${query}`, { headers: adminRequestHeaders({ Accept: 'application/json' }) })
      return payload?.data?.[0] ? replaceTask(payload.data[0]) : null
    } catch (caught) { error.value = caught.message || 'Unable to recover roster synchronization progress.'; return null }
  }
  async function cancel() {
    if (!task.value?.id || !ACTIVE_STATUSES.includes(task.value.status)) return null
    error.value = ''
    try {
      const payload = await request(`/api/admin/task_runs/${encodeURIComponent(task.value.id)}/cancel`, { method: 'POST', headers: adminRequestHeaders({ Accept: 'application/json' }) })
      return replaceTask(payload.data)
    } catch (caught) { error.value = caught.message || 'Unable to request roster synchronization cancellation.'; return null }
    finally { schedulePoll() }
  }

  onBeforeUnmount(clearPoll)
  return { task: computed(() => task.value), active: computed(() => Boolean(task.value && ACTIVE_STATUSES.includes(task.value.status))), starting: computed(() => starting.value), estimating: computed(() => estimating.value), error: computed(() => error.value), start, estimate, cancel, poll, loadActiveTask }
}
