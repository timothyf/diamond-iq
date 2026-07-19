<script setup>
import { ref } from 'vue'

import AdminTaskCard from './AdminTaskCard.vue'

defineProps({
  options: { type: Object, required: true },
  metrics: { type: Object, required: true },
  task: { type: Object, default: null },
  active: { type: Boolean, default: false },
  starting: { type: Boolean, default: false },
  anyActionRunning: { type: Boolean, default: false },
  error: { type: String, default: '' },
})
const emit = defineEmits(['submit', 'cancel-active'])
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
</script>

<template>
  <AdminTaskCard
    number="02"
    source="Baseball Savant"
    title="Statcast pitch data"
    chip="Download + import"
    description="Downloads pitch-by-pitch Statcast data from Baseball Savant for the selected games and date range."
    data-test="pitch-download-form"
    @submit.prevent="emit('submit')"
  >
    <div class="data-coverage" data-test="pitch-data-coverage">
      <span>Currently stored</span>
      <dl v-if="metrics.earliestGameDate && metrics.latestGameDate">
        <div><dt>Earliest game</dt><dd>{{ formatDate(metrics.earliestGameDate) }}</dd></div>
        <div><dt>Latest game</dt><dd>{{ formatDate(metrics.latestGameDate) }}</dd></div>
      </dl>
      <p v-else>No Statcast pitch data is currently stored.</p>
      <small>Approximately {{ formatCount(metrics.approximateRowCount) }} pitch rows</small>
    </div>

    <div class="admin-fields admin-fields--four">
      <label><span>Start date</span><input v-model="options.startDate" type="date" required /></label>
      <label><span>End date</span><input v-model="options.endDate" type="date" required /></label>
      <label><span>Game types</span><input v-model="options.gameTypes" type="text" placeholder="R" required /></label>
      <label><span>Chunk days</span><input v-model.number="options.chunkDays" type="number" min="1" max="31" required /></label>
    </div>

    <button ref="syncButton" class="admin-button" type="submit" :disabled="anyActionRunning">
      {{ starting ? 'Starting synchronization…' : active ? 'Synchronization in progress…' : 'Retrieve Statcast pitches' }}
    </button>

    <section v-if="task" class="sync-progress" data-test="pitch-data-progress" aria-live="polite">
      <header><div><span>{{ statusLabel(task.status) }}</span><strong>{{ formatCount(task.processedItems) }} of {{ formatCount(task.totalItems) }} games</strong></div><b>{{ task.progressPercentage.toFixed(1) }}%</b></header>
      <div class="sync-progress__track" role="progressbar" :aria-valuenow="task.progressPercentage" aria-valuemin="0" aria-valuemax="100" :aria-label="`Statcast pitch synchronization ${task.progressPercentage}% complete`"><i :style="{ width: `${task.progressPercentage}%` }"></i></div>
      <dl>
        <div><dt>Completed</dt><dd>{{ formatCount(task.completedItems) }}</dd></div>
        <div><dt>Failed</dt><dd>{{ formatCount(task.failedItems) }}</dd></div>
        <div><dt>Elapsed</dt><dd>{{ formatElapsed(task.elapsedSeconds) }}</dd></div>
        <div><dt>Remaining</dt><dd>{{ active ? formatElapsed(task.estimatedRemainingSeconds) : '—' }}</dd></div>
      </dl>
      <p v-if="task.currentItemLabel" class="sync-progress__current"><span>Current game</span>{{ task.currentItemLabel }}</p>
      <p v-if="task.cancelRequested && active" class="sync-progress__notice">Cancellation requested. The current game will finish safely before the task stops.</p>
      <p v-else-if="task.errorMessage" class="sync-progress__error">{{ task.errorMessage }}</p>
      <button v-if="active" type="button" class="admin-button admin-button--danger" data-test="pitch-data-cancel-active" :disabled="task.cancelRequested" @click="emit('cancel-active')">
        {{ task.cancelRequested ? 'Cancellation requested…' : 'Cancel after current game' }}
      </button>
    </section>
    <p v-if="error" class="admin-message admin-message--error">{{ error }}</p>
  </AdminTaskCard>
</template>
