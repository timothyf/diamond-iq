<script setup>
import { computed } from 'vue'

const emit = defineEmits(['page-change'])

const props = defineProps({
  rows: {
    type: Array,
    required: true,
  },
  meta: {
    type: Object,
    required: true,
  },
  loading: {
    type: Boolean,
    default: false,
  },
})

const currentPage = computed(() => Number(props.meta.page || 1))
const totalPages = computed(() => Number(props.meta.totalPages || 1))

function goToPreviousPage() {
  if (currentPage.value <= 1 || props.loading) return

  emit('page-change', currentPage.value - 1)
}

function goToNextPage() {
  if (currentPage.value >= totalPages.value || props.loading) return

  emit('page-change', currentPage.value + 1)
}
</script>

<template>
  <div class="data-grid-shell">
    <div class="table-meta">
      <span>Showing {{ meta.count || 0 }} of {{ meta.totalCount || meta.count || 0 }} pitch rows</span>
      <span>Page {{ meta.page || 1 }} of {{ meta.totalPages || 1 }} · {{ meta.perPage || meta.limit || 50 }} per page</span>
    </div>

    <div class="table-meta">
      <button class="ghost-button" type="button" :disabled="loading || (meta.page || 1) <= 1" @click="goToPreviousPage">
        Previous
      </button>
      <button class="ghost-button" type="button" :disabled="loading || (meta.page || 1) >= (meta.totalPages || 1)" @click="goToNextPage">
        Next
      </button>
    </div>

    <div class="data-grid">
      <table>
        <thead>
          <tr>
            <th>Game Date</th>
            <th>Pitch</th>
            <th>Velo (MPH)</th>
            <th>Spin Rate</th>
            <th>Pitcher</th>
            <th>Batter</th>
            <th>EV (MPH)</th>
            <th>LA (°dd)</th>
            <th>Dist (ft)</th>
            <th>Zone</th>
            <th>Inning</th>
            <th>Description</th>
            <th>Events</th>
          </tr>
        </thead>

        <tbody v-if="rows.length">
          <tr v-for="row in rows" :key="row.id">
            <td class="value-cell">{{ row.gameDate }}</td>
            <td class="value-cell">{{ row.pitchType }}</td>
            <td class="value-cell">{{ row.releaseSpeed }}</td>
            <td class="value-cell">{{ row.releaseSpinRate }}</td>
            <td class="value-cell">{{ row.pitcherName || row.pitcher || '—' }}</td>
            <td class="value-cell">{{ row.batterName || row.batter || '—' }}</td>
            <td class="value-cell">{{ row.launchSpeed }}</td>
            <td class="value-cell">{{ row.launchAngle }}</td>
            <td class="value-cell">{{ row.hitDistanceSc }}</td>
            <td class="value-cell">{{ row.zone }}</td>
            <td class="value-cell">{{ row.inning }}</td>
            <td class="value-cell">{{ row.description }}</td>
            <td class="value-cell">{{ row.events }}</td>
          </tr>
        </tbody>

        <tbody v-else>
          <tr>
            <td class="empty-state" colspan="13">
              <span v-if="loading">Loading pitch data…</span>
              <span v-else>No pitch rows have been imported yet.</span>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
</template>