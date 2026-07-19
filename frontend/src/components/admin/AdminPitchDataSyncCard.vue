<script setup>
import { ref } from 'vue'

import AdminSyncProgress from './AdminSyncProgress.vue'
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

function formatCount(value) {
  if (!Number.isFinite(value)) return 'Unavailable'
  return new Intl.NumberFormat('en-US').format(value)
}

function formatDate(value) {
  if (!value) return 'Unavailable'
  return new Intl.DateTimeFormat('en-US', { month: 'short', day: 'numeric', year: 'numeric' })
    .format(new Date(`${value}T12:00:00`))
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

    <AdminSyncProgress
      v-if="task"
      :task="task"
      :active="active"
      test-id="pitch-data-progress"
      aria-label="Statcast pitch synchronization"
      @cancel="emit('cancel-active')"
    />
    <p v-if="error" class="admin-message admin-message--error">{{ error }}</p>
  </AdminTaskCard>
</template>
