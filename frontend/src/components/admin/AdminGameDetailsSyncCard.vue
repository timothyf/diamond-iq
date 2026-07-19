<script setup>
import { ref } from 'vue'

import { formatCount, formatDate } from '../../utils/adminFormatting'
import {
  analyticsRefreshClass,
  analyticsRefreshMessage,
  analyticsRefreshProcessing,
  deferredAnalyticsRefreshAvailable,
  failureRows,
  failureText,
  workerErrorRows,
  workerPoolMessage,
} from '../../utils/gameDetailsTaskPresentation'
import AdminSyncProgress from './AdminSyncProgress.vue'
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

    <AdminSyncProgress
      v-if="task"
      :task="task"
      :active="active"
      test-id="game-details-progress"
      aria-label="Game detail synchronization"
      @cancel="emit('cancel-active')"
    >
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
    </AdminSyncProgress>
    <p v-if="error" class="admin-message admin-message--error" role="alert">{{ error }}</p>
  </AdminTaskCard>
</template>
