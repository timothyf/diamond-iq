<script setup>
import { nextTick, ref, watch } from 'vue'
import { formatBytes, formatCount, formatTimestamp } from '../../utils/adminFormatting'

const props = defineProps({
  open: { type: Boolean, default: false },
  metrics: { type: Object, required: true },
  loading: { type: Boolean, default: false },
})
const emit = defineEmits(['close'])

const views = ['storage', 'usage']
const activeView = ref('storage')
const dialog = ref(null)

watch(
  () => props.open,
  async (open) => {
    if (!open) return
    await nextTick()
    dialog.value?.focus()
  },
)

function handleViewKeydown(event, currentIndex) {
  let nextIndex = currentIndex
  if (event.key === 'ArrowRight') nextIndex = (currentIndex + 1) % views.length
  else if (event.key === 'ArrowLeft') nextIndex = (currentIndex - 1 + views.length) % views.length
  else if (event.key === 'Home') nextIndex = 0
  else if (event.key === 'End') nextIndex = views.length - 1
  else return

  event.preventDefault()
  activeView.value = views[nextIndex]
  nextTick(() => dialog.value?.querySelectorAll('[role="tab"]')?.[nextIndex]?.focus())
}

</script>

<template>
  <div
    v-if="open"
    class="database-modal"
    data-test="database-details-modal"
    @click.self="emit('close')"
    @keydown.esc="emit('close')"
  >
    <section
      ref="dialog"
      class="database-insights"
      data-test="database-details"
      role="dialog"
      aria-modal="true"
      aria-labelledby="database-details-title"
      tabindex="-1"
    >
      <header class="database-insights__heading">
        <div><p class="eyebrow">Storage health</p><h2 id="database-details-title">Database footprint</h2></div>
        <div class="database-insights__heading-actions">
          <p>
            {{ metrics.databaseName || 'Current database' }}
            <span v-if="metrics.serverVersion">· PostgreSQL {{ metrics.serverVersion }}</span>
            <span v-if="metrics.measuredAt">· Measured {{ formatTimestamp(metrics.measuredAt) }}</span>
          </p>
          <button type="button" data-test="database-details-close" aria-label="Close database details" @click="emit('close')">×</button>
        </div>
      </header>

      <div class="database-summary-grid">
        <article><span>Total database</span><strong>{{ loading ? 'Measuring…' : formatBytes(metrics.sizeBytes) }}</strong><small>Entire PostgreSQL database</small></article>
        <article><span>Application tables</span><strong>{{ formatBytes(metrics.userTableSizeBytes) }}</strong><small>Table data, TOAST, and indexes</small></article>
        <article><span>Tables</span><strong>{{ formatCount(metrics.tableCount) }}</strong><small>DiamondIQ application tables</small></article>
        <article><span>Estimated rows</span><strong>{{ formatCount(metrics.estimatedRowCount) }}</strong><small>{{ formatCount(metrics.estimatedDeadRowCount) }} dead rows awaiting cleanup</small></article>
      </div>

      <div class="database-view-tabs" role="tablist" aria-label="Database details views">
        <button
          v-for="(view, index) in views"
          :id="`database-view-${view}-tab`"
          :key="view"
          type="button"
          role="tab"
          :class="{ 'database-view-tabs__active': activeView === view }"
          :aria-selected="activeView === view"
          :tabindex="activeView === view ? 0 : -1"
          :aria-controls="`database-view-${view}`"
          :data-test="`database-view-${view}-tab`"
          @click="activeView = view"
          @keydown="handleViewKeydown($event, index)"
        >
          {{ view === 'storage' ? 'Storage' : 'Most Read' }}
        </button>
      </div>

      <div v-show="activeView === 'storage'" id="database-view-storage" role="tabpanel" aria-labelledby="database-view-storage-tab">
        <div v-if="metrics.largestTables.length" class="database-table-wrap">
          <table class="database-table">
            <thead><tr><th>Largest tables</th><th>Est. rows</th><th>Dead rows</th><th>Data</th><th>Indexes</th><th>Total</th><th>% of DB</th></tr></thead>
            <tbody>
              <tr v-for="table in metrics.largestTables" :key="table.tableName">
                <th><code>{{ table.tableName }}</code><span class="database-table__bar" aria-hidden="true"><i :style="{ width: `${Math.min(table.databasePercentage, 100)}%` }"></i></span></th>
                <td>{{ formatCount(table.estimatedRowCount) }}</td><td>{{ formatCount(table.estimatedDeadRowCount) }}</td>
                <td>{{ formatBytes(table.dataSizeBytes) }}</td><td>{{ formatBytes(table.indexSizeBytes) }}</td>
                <td><strong>{{ formatBytes(table.totalSizeBytes) }}</strong></td><td>{{ table.databasePercentage.toFixed(2) }}%</td>
              </tr>
            </tbody>
          </table>
        </div>
        <p v-else class="database-insights__empty">Per-table storage metrics are available when DiamondIQ uses PostgreSQL.</p>
      </div>

      <div v-show="activeView === 'usage'" id="database-view-usage" role="tabpanel" aria-labelledby="database-view-usage-tab" data-test="database-view-usage">
        <p class="database-usage-window">Statistics collected since <strong>{{ metrics.statisticsCollectedSince ? formatTimestamp(metrics.statisticsCollectedSince) : 'the last PostgreSQL statistics reset' }}</strong>.</p>
        <div v-if="metrics.mostReadTables.length" class="database-table-wrap">
          <table class="database-table database-table--usage">
            <thead><tr><th>Most-read tables</th><th>Total scans</th><th>Sequential scans</th><th>Index scans</th><th>Rows read/fetched</th><th>Last sequential scan</th><th>Last index scan</th></tr></thead>
            <tbody>
              <tr v-for="table in metrics.mostReadTables" :key="table.tableName">
                <th><code>{{ table.tableName }}</code></th><td><strong>{{ formatCount(table.totalScans) }}</strong></td>
                <td>{{ formatCount(table.sequentialScans) }}</td><td>{{ formatCount(table.indexScans) }}</td><td>{{ formatCount(table.rowsReadOrFetched) }}</td>
                <td>{{ table.lastSequentialScanAt ? formatTimestamp(table.lastSequentialScanAt) : 'Never recorded' }}</td>
                <td>{{ table.lastIndexScanAt ? formatTimestamp(table.lastIndexScanAt) : 'Never recorded' }}</td>
              </tr>
            </tbody>
          </table>
        </div>
        <p v-else class="database-insights__empty">Per-table usage metrics are available when DiamondIQ uses PostgreSQL.</p>
      </div>
      <footer v-if="activeView === 'storage'">Row counts come from PostgreSQL statistics and are approximate. Run <code>ANALYZE</code> to refresh estimates after a large import.</footer>
      <footer v-else>These cumulative counters include cached reads and reset when PostgreSQL statistics are reset. A sequential scan is not necessarily inefficient for a small table.</footer>
    </section>
  </div>
</template>
