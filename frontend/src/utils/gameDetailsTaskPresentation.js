import { humanize } from './adminFormatting'

export function taskStatusLabel(status) {
  return {
    queued: 'Queued',
    running: 'Synchronizing',
    completed: 'Completed',
    failed: 'Completed with an error',
    cancelled: 'Cancelled',
  }[status] || humanize(status)
}

export function analyticsRefresh(task) {
  return task?.resultData?.analytics_refresh || null
}

export function analyticsRefreshMessage(task) {
  const refresh = analyticsRefresh(task)
  if (!refresh) return ''
  if (refresh.skipped) return refresh.message || 'Daily analytics refresh was skipped.'
  if (refresh.success) return refresh.message || 'Daily analytics refresh completed.'
  return refresh.message || 'Daily analytics refresh failed.'
}

export function analyticsRefreshClass(task) {
  const refresh = analyticsRefresh(task)
  if (!refresh) return ''
  return refresh.success || refresh.skipped ? 'sync-progress__notice' : 'sync-progress__error'
}

export function workerPoolSummary(task) {
  return task?.resultData?.worker_pool_summary || null
}

export function workerPoolMessage(task) {
  const summary = workerPoolSummary(task)
  if (!summary) return ''
  return [
    `Worker pool: ${summary.active_workers || 0}/${summary.configured_workers || 0}`,
    `dequeued ${summary.games_dequeued || 0}`,
    `finalized ${summary.games_finalized || 0}`,
    `errors ${summary.worker_error_count || 0}`,
  ].join(' · ')
}

export function failureRows(task) {
  if (!task?.resultData) return []
  const normalized = []
  const pushFailure = (failure) => {
    if (!failure || typeof failure !== 'object') return
    const message = String(failure.message || '').trim()
    if (!message) return
    const mlbId = failure.mlb_id ?? failure.mlbId ?? null
    const errors = Array.isArray(failure.errors) ? failure.errors.filter(Boolean).map(String) : []
    normalized.push({ mlbId, message, errors })
  }
  Array.isArray(task.resultData.errors) && task.resultData.errors.forEach(pushFailure)
  Array.isArray(task.resultData.failures) && task.resultData.failures.forEach(pushFailure)
  const seen = new Set()
  return normalized.filter((entry) => {
    const key = `${entry.mlbId || 'none'}|${entry.message}|${entry.errors.join(',')}`
    if (seen.has(key)) return false
    seen.add(key)
    return true
  })
}

export function failureText(entry) {
  const gameLabel = entry.mlbId ? `Game ${entry.mlbId}` : 'Worker pool'
  const errorSuffix = entry.errors.length ? ` (${entry.errors.join(', ')})` : ''
  return `${gameLabel}: ${entry.message}${errorSuffix}`
}

export function workerErrorRows(task) {
  const summary = workerPoolSummary(task)
  return Array.isArray(summary?.worker_errors)
    ? summary.worker_errors.filter(Boolean).map((message) => String(message))
    : []
}

export function analyticsRefreshProcessing(task) {
  if (!task) return false
  const allGamesProcessed = Number(task.processedItems || 0) >= Number(task.totalItems || 0)
  return task.status === 'running' && allGamesProcessed && !analyticsRefresh(task)
}

export function deferredAnalyticsRefreshAvailable(task) {
  const refresh = analyticsRefresh(task)
  return Boolean(refresh?.deferred && task?.taskParameters?.start_date)
}

export function gameDetailsRefreshParameters(task) {
  if (!task?.taskParameters) return null
  const startDate = task.taskParameters.start_date
  const endDate = task.taskParameters.end_date || startDate
  if (!startDate || !endDate) return null

  return {
    start_date: startDate,
    end_date: endDate,
  }
}
