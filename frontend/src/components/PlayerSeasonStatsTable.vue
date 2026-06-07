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
const BATTING_INTEGER_STAT_KEYS = new Set([
  'gamesPlayed',
  'atBats',
  'runs',
  'hits',
  'doubles',
  'triples',
  'homeRuns',
  'rbi',
  'baseOnBalls',
  'strikeOuts',
  'stolenBases',
  'caughtStealing',
])
const PITCHING_INTEGER_STAT_KEYS = new Set(['W', 'L', 'G', 'GS', 'CG', 'ShO', 'SV', 'SVO', 'hits', 'runs', 'ER', 'homeRuns', 'hitByPitch', 'baseOnBalls', 'strikeOuts'])

const fixedColumns = [
  { key: 'rank', label: '#', align: 'numeric', sortable: false },
  { key: 'player_name', label: 'Player' },
  { key: 'team_name', label: 'Team' },
]

const columns = computed(() => [...fixedColumns, ...(props.meta.columns || [])])

const totalPages = computed(() => props.meta.totalPages || 0)
const canGoBackward = computed(() => (props.meta.page || 1) > 1)
const canGoForward = computed(() => (props.meta.page || 1) < totalPages.value)

function toggleSort(columnKey) {
  if (columnKey === 'rank') return

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
  if (columnKey === 'rank') return ''
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

function formatStatValue(columnKey, value) {
  if (value === null || value === undefined || value === '') return '—'
  if (props.meta.category === 'pitching' && PITCHING_INTEGER_STAT_KEYS.has(columnKey)) {
    const numericValue = Number(value)
    return Number.isFinite(numericValue) ? String(Math.trunc(numericValue)) : value
  }

  if (props.meta.category === 'batting' && BATTING_INTEGER_STAT_KEYS.has(columnKey)) {
    const numericValue = Number(value)
    return Number.isFinite(numericValue) ? String(Math.trunc(numericValue)) : value
  }

  return value
}
</script>

<template>
  <div class="data-grid-shell">
    <div class="table-meta">
      <span>Page {{ meta.page || 1 }} of {{ totalPages || 1 }}</span>
      <span>{{ meta.totalCount || 0 }} total matching players</span>
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
              <button
                type="button"
                class="sort-button"
                :class="{ 'sort-button--static': column.sortable === false }"
                @click="toggleSort(column.key)"
              >
                <span>{{ column.label }}</span>
                <span class="sort-indicator">{{ sortIndicator(column.key) }}</span>
              </button>
            </th>
          </tr>
        </thead>

        <tbody v-if="rows.length">
          <tr v-for="row in rows" :key="row.id">
            <td class="row-rank is-numeric">{{ row.rank }}</td>
            <td class="player-cell">
              <div class="primary-cell">
                <strong>{{ row.player.full_name }}</strong>
                <span>{{ row.season }} Season</span>
              </div>
            </td>
            <td class="team-cell">
              <div class="primary-cell">
                <strong>{{ row.team.abbreviation }}</strong>
                <span>{{ row.team.short_name || row.team.team_name || row.team.name }}</span>
              </div>
            </td>
            <td
              v-for="column in meta.columns || []"
              :key="`${row.id}-${column.key}`"
              class="is-numeric value-cell"
            >
              {{ formatStatValue(column.key, row.stats[column.key]) }}
            </td>
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
