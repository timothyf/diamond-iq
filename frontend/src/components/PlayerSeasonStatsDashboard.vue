<script setup>
import { computed, reactive, ref, watch } from 'vue'

import CsvImportPicker from './CsvImportPicker.vue'
import PlayerSeasonStatsTable from './PlayerSeasonStatsTable.vue'
import { usePlayerSuggestions } from '../composables/usePlayerSuggestions'
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

const playerInputFocused = ref(false)
const selectedImportFile = ref(null)
const importPanelOpen = ref(false)
const importPickerKey = ref(0)
const stagedImportMessage = ref('Choose a CSV file to import player season stats into the app.')
let playerSuggestionBlurTimer = null

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

const playerSuggestionQuery = computed(() => ({
  name: filters.playerName,
  teamId: filters.teamId,
  perPage: 8,
}))

const { rows, meta, loading, error, refresh } = usePlayerSeasonStats(query)
const { suggestions: playerSuggestions, loading: playerSuggestionsLoading } = usePlayerSuggestions(playerSuggestionQuery)
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

const showPlayerSuggestions = computed(
  () =>
    playerInputFocused.value &&
    filters.playerName.trim().length >= 2 &&
    (playerSuggestionsLoading.value || playerSuggestions.value.length > 0),
)

const importStatusTone = computed(() => {
  if (uploading.value) return 'live'
  if (importError.value) return 'error'
  if (selectedImportFile.value) return 'staged'
  if (importSummary.value) return 'success'
  return 'idle'
})

const importStatusLabel = computed(() => {
  if (uploading.value) return 'Import in progress'
  if (importError.value) return 'Import issue'
  if (selectedImportFile.value) return 'File staged'
  if (importSummary.value) return 'Latest import'
  return 'Data import'
})

const importStatusDetail = computed(() => importError.value || importSummary.value || stagedImportMessage.value)
const tableTitle = computed(() => {
  if (filters.category === 'pitching' || filters.category === 'pitchStats') {
    return 'Pitching Leaderboard'
  }

  return 'Batting Leaderboard'
})

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

function handlePlayerInputFocus() {
  if (playerSuggestionBlurTimer) {
    window.clearTimeout(playerSuggestionBlurTimer)
    playerSuggestionBlurTimer = null
  }

  playerInputFocused.value = true
}

function handlePlayerInputBlur() {
  playerSuggestionBlurTimer = window.setTimeout(() => {
    playerInputFocused.value = false
    playerSuggestionBlurTimer = null
  }, 120)
}

function applyPlayerSuggestion(player) {
  if (playerSuggestionBlurTimer) {
    window.clearTimeout(playerSuggestionBlurTimer)
    playerSuggestionBlurTimer = null
  }

  filters.playerName = player.fullName
  playerInputFocused.value = false
}

function openImportPanel() {
  importPanelOpen.value = true
}

function closeImportPanel() {
  if (uploading.value) return

  importPanelOpen.value = false
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
  importPanelOpen.value = true
}

async function handleImportRequest(file) {
  selectedImportFile.value = file
  importPanelOpen.value = true
  const result = await importFile(file)
  if (!result) return

  await refresh()
  selectedImportFile.value = null
  stagedImportMessage.value = `Latest import file: ${file.name}.`
  importPickerKey.value += 1
  importPanelOpen.value = false
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
    </section>

    <section class="control-deck">
      <div class="control-deck__header">
        <div>
          <h2>Filters</h2>
          <p>{{ filterSummary }}</p>
        </div>
        <button class="ghost-button" type="button" @click="resetFilters">Reset Filters</button>
      </div>

      <div class="filter-grid">
        <label class="field">
          <span>Player</span>
          <div class="typeahead-field">
            <input
              v-model="filters.playerName"
              type="text"
              placeholder="Ohtani, Cabrera, Trout..."
              autocomplete="off"
              @focus="handlePlayerInputFocus"
              @blur="handlePlayerInputBlur"
            />

            <div v-if="showPlayerSuggestions" class="typeahead-menu" role="listbox" aria-label="Player suggestions">
              <p v-if="playerSuggestionsLoading" class="typeahead-status">
                Looking up players…
              </p>

              <button
                v-for="player in playerSuggestions"
                v-else
                :key="player.id"
                type="button"
                class="typeahead-option"
                @mousedown.prevent="applyPlayerSuggestion(player)"
              >
                <span class="typeahead-option__name">{{ player.fullName }}</span>
                <span class="typeahead-option__meta">
                  {{ player.team.abbreviation || player.team.team_name || player.team.name }}
                </span>
              </button>
            </div>
          </div>
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
            <option :value="10">10</option>
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
          <h2>{{ tableTitle }}</h2>
          <p>Traditional player rows with the selected stat line running straight across the board.</p>
        </div>

        <div class="table-actions">
          <div class="import-utility">
            <div :class="['import-chip', `import-chip--${importStatusTone}`]">
              <span class="import-chip__label">{{ importStatusLabel }}</span>
              <span class="import-chip__detail">{{ importStatusDetail }}</span>
            </div>
            <button class="ghost-button" type="button" data-test="open-import-panel" :disabled="uploading" @click="openImportPanel">
              {{ uploading ? 'Importing…' : 'Import CSV' }}
            </button>
          </div>

          <button class="ghost-button" type="button" :disabled="loading" @click="refresh">
            {{ loading ? 'Refreshing…' : 'Refresh Data' }}
          </button>
        </div>
      </header>

      <div
        v-if="importPanelOpen || uploading"
        class="import-drawer-backdrop"
        @click.self="closeImportPanel"
      >
        <section class="import-drawer" aria-label="CSV import panel">
          <header class="import-drawer__header">
            <div>
              <p class="eyebrow">Data Import</p>
              <h3>Refresh Player Season Stats</h3>
            </div>
            <button class="ghost-button" type="button" :disabled="uploading" @click="closeImportPanel">
              Close
            </button>
          </header>

          <CsvImportPicker
            :key="importPickerKey"
            variant="drawer"
            :busy="uploading"
            :status-message="importSummary || stagedImportMessage"
            :upload-error="importError"
            @file-selected="handleFileSelected"
            @import-request="handleImportRequest"
          />
        </section>
      </div>

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
