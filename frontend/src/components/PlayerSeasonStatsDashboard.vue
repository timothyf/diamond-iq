<script setup>
import { computed, reactive, ref, watch } from 'vue'

import CsvImportPicker from './CsvImportPicker.vue'
import PlayerSeasonStatsTable from './PlayerSeasonStatsTable.vue'
import { usePlayerSeasonStats } from '../composables/usePlayerSeasonStats'
import { usePlayerSeasonStatsImport } from '../composables/usePlayerSeasonStatsImport'

const filters = reactive({
  playerName: '',
  teamName: '',
  season: '',
  category: '',
  statTypeName: '',
})

const pagination = reactive({
  page: 1,
  perPage: 12,
})

const sort = reactive({
  value: '-value',
})

const selectedImportFile = ref(null)
const importPickerKey = ref(0)
const stagedImportMessage = ref('Choose a CSV file to import player season stats into the app.')

const query = computed(() => ({
  page: pagination.page,
  perPage: pagination.perPage,
  sort: sort.value,
  filters: {
    player_name: filters.playerName,
    team_name: filters.teamName,
    season: filters.season,
    category: filters.category,
    stat_type_name: filters.statTypeName,
  },
}))

const { rows, meta, loading, error, refresh } = usePlayerSeasonStats(query)
const { uploading, error: importError, summary: importSummary, importFile } = usePlayerSeasonStatsImport()

watch(
  () => [filters.playerName, filters.teamName, filters.season, filters.category, filters.statTypeName, pagination.perPage, sort.value],
  () => {
    pagination.page = 1
  },
)

const filterSummary = computed(() => {
  const activeFilters = [
    filters.playerName && `Player: ${filters.playerName}`,
    filters.teamName && `Team: ${filters.teamName}`,
    filters.season && `Season: ${filters.season}`,
    filters.category && `Category: ${filters.category}`,
    filters.statTypeName && `Stat: ${filters.statTypeName}`,
  ].filter(Boolean)

  return activeFilters.length ? activeFilters.join(' · ') : 'Showing the full player season stat board.'
})

function updateSort(nextSort) {
  sort.value = nextSort
}

function updatePage(nextPage) {
  pagination.page = nextPage
}

function updatePerPage(event) {
  pagination.perPage = Number(event.target.value)
}

function resetFilters() {
  filters.playerName = ''
  filters.teamName = ''
  filters.season = ''
  filters.category = ''
  filters.statTypeName = ''
  pagination.page = 1
  sort.value = '-value'
}

function handleFileSelected(file) {
  selectedImportFile.value = file
  stagedImportMessage.value = `${file.name} is selected and ready to import.`
}

async function handleImportRequest(file) {
  selectedImportFile.value = file
  const result = await importFile(file)
  if (!result) return

  await refresh()
  selectedImportFile.value = null
  stagedImportMessage.value = `Latest import file: ${file.name}.`
  importPickerKey.value += 1
}
</script>

<template>
  <main class="dashboard-shell">
    <section class="hero-panel">
      <div class="hero-copy">
        <p class="eyebrow">Front Office Dashboard</p>
        <h1>Player Season Stat Board</h1>
        <p class="lede">
          A single scouting-style command center for searching, sorting, and comparing imported player season stats.
        </p>
      </div>

      <div class="hero-metrics">
        <article class="metric-card">
          <span class="metric-label">Rows In View</span>
          <strong class="metric-value">{{ rows.length }}</strong>
        </article>
        <article class="metric-card">
          <span class="metric-label">Total Matches</span>
          <strong class="metric-value">{{ meta.totalCount }}</strong>
        </article>
        <article class="metric-card">
          <span class="metric-label">Current Sort</span>
          <strong class="metric-value metric-sort">{{ meta.sort || sort.value }}</strong>
        </article>
      </div>
    </section>

    <CsvImportPicker
      :key="importPickerKey"
      :busy="uploading"
      :status-message="importSummary || stagedImportMessage"
      :upload-error="importError"
      @file-selected="handleFileSelected"
      @import-request="handleImportRequest"
    />

    <section class="control-deck">
      <div class="control-deck__header">
        <div>
          <h2>Table Controls</h2>
          <p>{{ filterSummary }}</p>
        </div>
        <button class="ghost-button" type="button" @click="resetFilters">Reset Filters</button>
      </div>

      <div class="filter-grid">
        <label class="field">
          <span>Player</span>
          <input v-model="filters.playerName" type="text" placeholder="Ohtani, Cabrera, Trout..." />
        </label>

        <label class="field">
          <span>Team</span>
          <input v-model="filters.teamName" type="text" placeholder="Dodgers, Tigers..." />
        </label>

        <label class="field">
          <span>Season</span>
          <input v-model="filters.season" type="number" min="1800" max="2100" placeholder="2024" />
        </label>

        <label class="field">
          <span>Category</span>
          <select v-model="filters.category">
            <option value="">All categories</option>
            <option value="batting">Batting</option>
            <option value="pitching">Pitching</option>
            <option value="pitchStats">Pitch Stats</option>
          </select>
        </label>

        <label class="field">
          <span>Stat Type</span>
          <input v-model="filters.statTypeName" type="text" placeholder="OPS, WAR, ERA..." />
        </label>

        <label class="field">
          <span>Rows per page</span>
          <select :value="pagination.perPage" @change="updatePerPage">
            <option :value="12">12</option>
            <option :value="24">24</option>
            <option :value="50">50</option>
            <option :value="100">100</option>
          </select>
        </label>
      </div>
    </section>

    <section class="table-stage">
      <header class="table-stage__header">
        <div>
          <h2>Season Stats</h2>
          <p>Built for rapid slicing by player, club, season, and stat family.</p>
        </div>

        <div class="table-actions">
          <button class="ghost-button" type="button" :disabled="loading" @click="refresh">
            {{ loading ? 'Refreshing…' : 'Refresh Data' }}
          </button>
        </div>
      </header>

      <p v-if="error" class="error-banner">
        {{ error }}
      </p>

      <PlayerSeasonStatsTable
        :rows="rows"
        :meta="meta"
        :loading="loading"
        :sort="sort.value"
        @sort-change="updateSort"
        @page-change="updatePage"
      />
    </section>
  </main>
</template>
