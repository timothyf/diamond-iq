<script setup>
import { ref } from 'vue'

import AdminTaskCard from './AdminTaskCard.vue'

const props = defineProps({
  options: { type: Object, required: true },
  metrics: { type: Object, required: true },
  task: { type: Object, default: null },
  active: { type: Boolean, default: false },
  starting: { type: Boolean, default: false },
  anyActionRunning: { type: Boolean, default: false },
  runningTask: { type: String, default: '' },
  error: { type: String, default: '' },
})
const emit = defineEmits(['submit', 'cancel-active', 'refresh-analytics'])
const syncButton = ref(null)

defineExpose({
  focusSyncButton: () => syncButton.value?.focus(),
})

function humanize(value) {
  return String(value || '').replaceAll('_', ' ').replace(/\b\w/g, (letter) => letter.toUpperCase())
}

function formatCount(value) {
  if (!Number.isFinite(value)) return 'Unavailable'
  return new Intl.NumberFormat('en-US').format(value)
}

function formatDate(value) {
  if (!value) return 'Unavailable'
  return new Intl.DateTimeFormat('en-US', { month: 'short', day: 'numeric', year: 'numeric' })
    .format(new Date(`${value}T12:00:00`))
}

function formatElapsed(seconds) {
  if (!Number.isFinite(seconds)) return 'Calculating…'
  if (seconds < 60) return `${seconds}s`
  const minutes = Math.floor(seconds / 60)
  const remainingSeconds = seconds % 60
  return `${minutes}m${remainingSeconds ? ` ${remainingSeconds}s` : ''}`
}

function statusLabel(status) {
  return {
    queued: 'Queued',
    running: 'Synchronizing',
    completed: 'Completed',
    failed: 'Completed with an error',
    cancelled: 'Cancelled',
  }[status] || humanize(status)
}

function analyticsRefresh(task) {
  return task?.resultData?.analytics_refresh || null
}

function analyticsRefreshMessage(task) {
  const refresh = analyticsRefresh(task)
  if (!refresh) return ''
  if (refresh.skipped) return refresh.message || 'Daily analytics refresh was skipped.'
  if (refresh.success) return refresh.message || 'Daily analytics refresh completed.'
  return refresh.message || 'Daily analytics refresh failed.'
}

function analyticsRefreshClass(task) {
  const refresh = analyticsRefresh(task)
  if (!refresh) return ''
  return refresh.success || refresh.skipped ? 'sync-progress__notice' : 'sync-progress__error'
}

function workerPoolSummary(task) {
  return task?.resultData?.worker_pool_summary || null
}

function workerPoolMessage(task) {
  const summary = workerPoolSummary(task)
  if (!summary) return ''
  return [
    `Worker pool: ${summary.active_workers || 0}/${summary.configured_workers || 0}`,
    `dequeued ${summary.games_dequeued || 0}`,
    `finalized ${summary.games_finalized || 0}`,
    `errors ${summary.worker_error_count || 0}`,
  ].join(' · ')
}

function failureRows(task) {
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

function failureText(entry) {
  const gameLabel = entry.mlbId ? `Game ${entry.mlbId}` : 'Worker pool'
  const errorSuffix = entry.errors.length ? ` (${entry.errors.join(', ')})` : ''
  return `${gameLabel}: ${entry.message}${errorSuffix}`
}

function workerErrorRows(task) {
  const summary = workerPoolSummary(task)
  return Array.isArray(summary?.worker_errors)
    ? summary.worker_errors.filter(Boolean).map((message) => String(message))
    : []
}

function analyticsRefreshProcessing(task) {
  if (!task) return false
  const allGamesProcessed = Number(task.processedItems || 0) >= Number(task.totalItems || 0)
  return task.status === 'running' && allGamesProcessed && !analyticsRefresh(task)
}

function deferredAnalyticsRefreshAvailable(task) {
  const refresh = analyticsRefresh(task)
  return Boolean(refresh?.deferred && task?.taskParameters?.start_date)
}
</script>

<template>
  <AdminTaskCard
    source="Box scores & live feeds"
    title="MLB game detail synchronization"
    command="mlb_game_details:sync"
    description="Downloads player game lines, batting orders, substitutions, plate appearances, and links matching Statcast pitches."
    data-test="game-details-sync-form"
    @submit.prevent="emit('submit')"
  >
    <div class="data-coverage" data-test="game-details-coverage">
      <span>Currently stored</span>
      <dl v-if="metrics.synchronizedGameCount">
        <div><dt>Games synchronized</dt><dd>{{ formatCount(metrics.synchronizedGameCount) }}</dd></div>
        <div><dt>Game-date span</dt><dd>{{ formatDate(metrics.earliestGameDate) }}–{{ formatDate(metrics.latestGameDate) }}</dd></div>
      </dl>
      <p v-else>No game box scores or live feeds have been synchronized.</p>
      <small>{{ formatCount(metrics.plateAppearanceCount) }} plate appearances · {{ formatCount(metrics.linkedPitchCount) }} linked pitches</small>
    </div>
    <div class="admin-fields admin-fields--three">
      <label><span>Start date</span><input v-model="options.startDate" type="date" :disabled="Boolean(options.mlbGameId)" /></label>
      <label><span>End date</span><input v-model="options.endDate" type="date" :disabled="Boolean(options.mlbGameId)" /></label>
      <label><span>MLB game ID (optional)</span><input v-model="options.mlbGameId" type="number" min="1" placeholder="823443" /></label>
    </div>
    <button ref="syncButton" class="admin-button" type="submit" :disabled="anyActionRunning">
      {{ starting ? 'Starting synchronization…' : active ? 'Synchronization in progress…' : 'Synchronize game details' }}
    </button>

    <section v-if="task" class="sync-progress" data-test="game-details-progress" aria-live="polite">
      <header><div><span>{{ statusLabel(task.status) }}</span><strong>{{ formatCount(task.processedItems) }} of {{ formatCount(task.totalItems) }} games</strong></div><b>{{ task.progressPercentage.toFixed(1) }}%</b></header>
      <div class="sync-progress__track" role="progressbar" :aria-valuenow="task.progressPercentage" aria-valuemin="0" aria-valuemax="100" :aria-label="`Game detail synchronization ${task.progressPercentage}% complete`"><i :style="{ width: `${task.progressPercentage}%` }"></i></div>
      <dl>
        <div><dt>Completed</dt><dd>{{ formatCount(task.completedItems) }}</dd></div>
        <div><dt>Failed</dt><dd>{{ formatCount(task.failedItems) }}</dd></div>
        <div><dt>Elapsed</dt><dd>{{ formatElapsed(task.elapsedSeconds) }}</dd></div>
        <div><dt>Remaining</dt><dd>{{ active ? formatElapsed(task.estimatedRemainingSeconds) : '—' }}</dd></div>
      </dl>
      <p v-if="task.currentItemLabel" class="sync-progress__current"><span>Current game</span>{{ task.currentItemLabel }}</p>
      <p v-if="task.cancelRequested && active" class="sync-progress__notice">Cancellation requested. The current game will finish safely before the task stops.</p>
      <p v-else-if="task.errorMessage" class="sync-progress__error">{{ task.errorMessage }}</p>
      <p v-if="analyticsRefreshProcessing(task)" class="sync-progress__notice" data-test="game-details-analytics-refresh-processing">Game detail synchronization is complete. Daily analytics refresh is now processing.</p>
      <p v-if="analyticsRefreshMessage(task)" :class="analyticsRefreshClass(task)" data-test="game-details-analytics-refresh">{{ analyticsRefreshMessage(task) }}</p>
      <button v-if="deferredAnalyticsRefreshAvailable(task)" type="button" class="admin-button admin-button--secondary" data-test="game-details-run-deferred-analytics-refresh" :disabled="anyActionRunning" @click="emit('refresh-analytics')">
        {{ runningTask === 'daily_analytics_refresh' ? 'Refreshing daily analytics…' : 'Run daily analytics refresh for this range' }}
      </button>
      <p v-if="workerPoolMessage(task)" class="sync-progress__notice" data-test="game-details-worker-pool-summary">{{ workerPoolMessage(task) }}</p>
      <div v-if="failureRows(task).length" class="sync-progress__failure-block" data-test="game-details-failure-details">
        <p class="sync-progress__error">Failure details</p>
        <ul class="sync-progress__failure-list"><li v-for="(entry, index) in failureRows(task)" :key="`${entry.mlbId || 'worker'}-${index}`">{{ failureText(entry) }}</li></ul>
      </div>
      <div v-if="workerErrorRows(task).length" class="sync-progress__failure-block" data-test="game-details-worker-errors">
        <p class="sync-progress__error">Worker errors</p>
        <ul class="sync-progress__failure-list"><li v-for="(message, index) in workerErrorRows(task)" :key="`worker-error-${index}`">{{ message }}</li></ul>
      </div>
      <button v-if="active" type="button" class="admin-button admin-button--danger" data-test="game-details-cancel-active" :disabled="task.cancelRequested" @click="emit('cancel-active')">
        {{ task.cancelRequested ? 'Cancellation requested…' : 'Cancel after current game' }}
      </button>
    </section>
    <p v-if="error" class="admin-message admin-message--error" role="alert">{{ error }}</p>
  </AdminTaskCard>
</template>
