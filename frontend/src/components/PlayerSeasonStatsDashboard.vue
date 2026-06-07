<script setup>
import { computed, reactive, ref, watch } from 'vue'

import CsvImportPicker from './CsvImportPicker.vue'
import PlayerSeasonStatsTable from './PlayerSeasonStatsTable.vue'
import { usePlayerSeasonStats } from '../composables/usePlayerSeasonStats'
import { usePlayerSeasonStatsImport } from '../composables/usePlayerSeasonStatsImport'

const DEFAULT_SORT_BY_CATEGORY = {
  batting: '-homeRuns',
  pitching: '-strikeOuts',
  pitchStats: '-pitch_usage',
}

const filters = reactive({
  playerName: '',
  teamId: '',
  season: '',
  category: 'batting',
})

const pagination = reactive({
  page: 1,
  perPage: 15,
})

const sort = reactive({
  value: DEFAULT_SORT_BY_CATEGORY.batting,
})

const selectedImportFile = ref(null)
const importPickerKey = ref(0)
const stagedImportMessage = ref('Choose a CSV file to import player season stats into the app.')

const query = computed(() => ({
  view: 'leaderboard',
  page: pagination.page,
  perPage: pagination.perPage,
  sort: sort.value,
  filters: {
    player_name: filters.playerName,
    team_id: filters.teamId,
    season: filters.season,
    category: filters.category,
  },
}))

const { rows, meta, loading, error, refresh } = usePlayerSeasonStats(query)
const { uploading, error: importError, summary: importSummary, importFile } = usePlayerSeasonStatsImport()

watch(
  () => [filters.playerName, filters.teamId, filters.season, filters.category, pagination.perPage, sort.value],
  () => {
    pagination.page = 1
  },
)

watch(
  () => filters.category,
  (category) => {
    sort.value = DEFAULT_SORT_BY_CATEGORY[category] || DEFAULT_SORT_BY_CATEGORY.batting
  },
)

watch(
  () => meta.value.availableTeams,
  (availableTeams) => {
    if (!filters.teamId) return

    const teamStillAvailable = availableTeams.some((team) => String(team.id) === String(filters.teamId))
    if (!teamStillAvailable) {
      filters.teamId = ''
    }
  },
  { deep: true },
)

const selectedTeam = computed(() =>
  meta.value.availableTeams.find((team) => String(team.id) === String(filters.teamId)) || null,
)

const filterSummary = computed(() => {
  const activeFilters = [
    filters.playerName && `Player: ${filters.playerName}`,
    selectedTeam.value &&
      `Team: ${selectedTeam.value.abbreviation || selectedTeam.value.short_name || selectedTeam.value.team_name || selectedTeam.value.name}`,
    filters.season && `Season: ${filters.season}`,
    filters.category && `Category: ${filters.category}`,
  ].filter(Boolean)

  return activeFilters.length ? activeFilters.join(' · ') : 'Showing the full player season leaderboard.'
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
  filters.teamId = ''
  filters.season = ''
  filters.category = 'batting'
  pagination.page = 1
  sort.value = DEFAULT_SORT_BY_CATEGORY.batting
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
          <span class="metric-label">Players In View</span>
          <strong class="metric-value">{{ rows.length }}</strong>
        </article>
        <article class="metric-card">
          <span class="metric-label">Matching Players</span>
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
          <select v-model="filters.teamId" data-test="team-filter">
            <option value="">All teams</option>
            <option v-for="teamOption in meta.availableTeams" :key="teamOption.id" :value="String(teamOption.id)">
              {{ teamOption.abbreviation }} · {{ teamOption.short_name || teamOption.team_name || teamOption.name }}
            </option>
          </select>
        </label>

        <label class="field">
          <span>Season</span>
          <select v-model="filters.season" data-test="season-filter">
            <option value="">All seasons</option>
            <option v-for="seasonOption in meta.availableSeasons" :key="seasonOption" :value="seasonOption">
              {{ seasonOption }}
            </option>
          </select>
        </label>

        <label class="field">
          <span>Category</span>
          <select v-model="filters.category">
            <option value="batting">Batting</option>
            <option value="pitching">Pitching</option>
            <option value="pitchStats">Pitch Stats</option>
          </select>
        </label>

        <label class="field">
          <span>Rows per page</span>
          <select :value="pagination.perPage" @change="updatePerPage">
            <option :value="15">15</option>
            <option :value="30">30</option>
            <option :value="50">50</option>
            <option :value="100">100</option>
          </select>
        </label>
      </div>
    </section>

    <section class="table-stage">
      <header class="table-stage__header">
        <div>
          <h2>Season Leaderboard</h2>
          <p>Traditional player rows with the selected stat line running straight across the board.</p>
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
