<script setup>
import { computed } from 'vue'

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
  sort: {
    type: String,
    required: true,
  },
})

const emit = defineEmits(['sort-change', 'page-change'])

const columns = [
  { key: 'player_name', label: 'Player' },
  { key: 'team_name', label: 'Team' },
  { key: 'season', label: 'Season' },
  { key: 'category', label: 'Category' },
  { key: 'stat_type_name', label: 'Stat' },
  { key: 'value', label: 'Value', align: 'numeric' },
]

const totalPages = computed(() => props.meta.totalPages || 0)
const canGoBackward = computed(() => (props.meta.page || 1) > 1)
const canGoForward = computed(() => (props.meta.page || 1) < totalPages.value)

function toggleSort(columnKey) {
  if (props.sort === columnKey) {
    emit('sort-change', `-${columnKey}`)
    return
  }

  if (props.sort === `-${columnKey}`) {
    emit('sort-change', columnKey)
    return
  }

  emit('sort-change', columnKey)
}

function sortIndicator(columnKey) {
  if (props.sort === columnKey) return '↑'
  if (props.sort === `-${columnKey}`) return '↓'
  return ''
}

function goToPreviousPage() {
  if (canGoBackward.value) {
    emit('page-change', props.meta.page - 1)
  }
}

function goToNextPage() {
  if (canGoForward.value) {
    emit('page-change', props.meta.page + 1)
  }
}
</script>

<template>
  <div class="data-grid-shell">
    <div class="table-meta">
      <span>Page {{ meta.page || 1 }} of {{ totalPages || 1 }}</span>
      <span>{{ meta.totalCount || 0 }} total matching rows</span>
    </div>

    <div class="data-grid">
      <table>
        <thead>
          <tr>
            <th
              v-for="column in columns"
              :key="column.key"
              :class="{ 'is-numeric': column.align === 'numeric' }"
            >
              <button type="button" class="sort-button" @click="toggleSort(column.key)">
                <span>{{ column.label }}</span>
                <span class="sort-indicator">{{ sortIndicator(column.key) }}</span>
              </button>
            </th>
          </tr>
        </thead>

        <tbody v-if="rows.length">
          <tr v-for="row in rows" :key="row.id">
            <td>
              <div class="primary-cell">
                <strong>{{ row.player.full_name }}</strong>
                <span>MLB {{ row.player.mlb_id }}</span>
              </div>
            </td>
            <td>
              <div class="primary-cell">
                <strong>{{ row.team.abbreviation }}</strong>
                <span>{{ row.team.name }}</span>
              </div>
            </td>
            <td>{{ row.season }}</td>
            <td>
              <span class="pill">{{ row.stat_type.category }}</span>
            </td>
            <td>
              <div class="primary-cell">
                <strong>{{ row.stat_type.label }}</strong>
                <span>{{ row.stat_type.name }}</span>
              </div>
            </td>
            <td class="is-numeric value-cell">{{ row.value }}</td>
          </tr>
        </tbody>

        <tbody v-else>
          <tr>
            <td class="empty-state" :colspan="columns.length">
              <span v-if="loading">Loading player season stats…</span>
              <span v-else>No rows match the current filters.</span>
            </td>
          </tr>
        </tbody>
      </table>
    </div>

    <footer class="pagination-bar">
      <button type="button" class="ghost-button" :disabled="!canGoBackward || loading" @click="goToPreviousPage">
        Previous
      </button>
      <button type="button" class="ghost-button" :disabled="!canGoForward || loading" @click="goToNextPage">
        Next
      </button>
    </footer>
  </div>
</template>
