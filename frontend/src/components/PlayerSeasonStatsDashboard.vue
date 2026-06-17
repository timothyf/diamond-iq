<script setup>
import { computed, reactive, ref, watch } from 'vue'

import CsvImportPicker from './CsvImportPicker.vue'
import PitchDataTable from './PitchDataTable.vue'
import PlayerSeasonStatsTable from './PlayerSeasonStatsTable.vue'
import { usePlayerSuggestions } from '../composables/usePlayerSuggestions'
import { usePitchData } from '../composables/usePitchData'
import { usePitchDataDownload } from '../composables/usePitchDataDownload'
import { usePlayerSeasonStats } from '../composables/usePlayerSeasonStats'
import { usePlayerSeasonStatsDownload } from '../composables/usePlayerSeasonStatsDownload'
import { usePlayerSeasonStatsImport } from '../composables/usePlayerSeasonStatsImport'
import { usePitchDataImport } from '../composables/usePitchDataImport'

const DEFAULT_SORT_BY_CATEGORY = {
  batting: '-homeRuns',
  pitching: '-strikeOuts',
  pitchStats: '-pitch_usage',
}

const filters = reactive({
  playerName: '',
  teamId: '',
  seasonStart: '',
  seasonEnd: '',
  category: 'batting',
})

const pagination = reactive({
  page: 1,
  perPage: 15,
})

const pitchDataOptions = reactive({
  page: 1,
  perPage: 50,
})

const pitchDataFilters = reactive({
  gameDateStart: '',
  gameDateEnd: '',
  gamePk: '',
  pitcher: '',
  batter: '',
  pitchType: '',
  events: '',
})

const currentSeason = new Date().getFullYear()
const currentDateIso = new Date().toISOString().slice(0, 10)
const mlbDownloadOptions = reactive({
  category: 'batting',
  startYear: String(currentSeason),
  endYear: String(currentSeason),
  startDate: currentDateIso,
  endDate: currentDateIso,
  gameTypes: 'R',
  chunkDays: 7,
  replaceSeason: true,
})

const sort = reactive({
  value: DEFAULT_SORT_BY_CATEGORY.batting,
})

const playerInputFocused = ref(false)
const pitcherInputFocused = ref(false)
const batterInputFocused = ref(false)
const pitcherNameInput = ref('')
const batterNameInput = ref('')
const selectedImportFile = ref(null)
const importPanelOpen = ref(false)
const importTarget = ref('season')
const importPickerKey = ref(0)
const stagedImportMessage = ref('Choose a CSV file to import into the app.')
const selectedPitchImportFile = ref(null)
const pitchImportPickerKey = ref(0)
const stagedPitchImportMessage = ref('Choose a CSV file to import pitch-by-pitch data into the app.')
let playerSuggestionBlurTimer = null
let pitcherSuggestionBlurTimer = null
let batterSuggestionBlurTimer = null

const PITCH_REQUIRED_HEADERS = ['game_pk', 'at_bat_number', 'pitch_number']
const SEASON_REQUIRED_HEADERS = ['season', 'stat_type', 'playerid']

const query = computed(() => ({
  view: 'leaderboard',
  page: pagination.page,
  perPage: pagination.perPage,
  sort: sort.value,
  filters: {
    player_name: filters.playerName,
    team_id: filters.teamId,
    season_start: filters.seasonStart,
    season_end: filters.seasonEnd,
    category: filters.category,
  },
}))

const playerSuggestionQuery = computed(() => ({
  name: filters.playerName,
  teamId: filters.teamId,
  perPage: 8,
}))

const pitcherSuggestionQuery = computed(() => ({
  name: pitcherNameInput.value,
  perPage: 8,
}))

const batterSuggestionQuery = computed(() => ({
  name: batterNameInput.value,
  perPage: 8,
}))

const pitchDataQuery = computed(() => ({
  page: pitchDataOptions.page,
  perPage: pitchDataOptions.perPage,
  gameDateStart: pitchDataFilters.gameDateStart,
  gameDateEnd: pitchDataFilters.gameDateEnd,
  gamePk: pitchDataFilters.gamePk,
  pitcher: pitchDataFilters.pitcher,
  batter: pitchDataFilters.batter,
  pitchType: pitchDataFilters.pitchType,
  events: pitchDataFilters.events,
}))

const { rows, meta, loading, error, refresh } = usePlayerSeasonStats(query)
const {
  rows: pitchRows,
  meta: pitchMeta,
  loading: pitchLoading,
  error: pitchError,
  refresh: refreshPitchData,
} = usePitchData(pitchDataQuery)
const { suggestions: playerSuggestions, loading: playerSuggestionsLoading } = usePlayerSuggestions(playerSuggestionQuery)
const { suggestions: pitcherSuggestions, loading: pitcherSuggestionsLoading } = usePlayerSuggestions(pitcherSuggestionQuery)
const { suggestions: batterSuggestions, loading: batterSuggestionsLoading } = usePlayerSuggestions(batterSuggestionQuery)
const { uploading, error: importError, summary: importSummary, importFile } = usePlayerSeasonStatsImport()
const {
  downloading: mlbDownloading,
  error: mlbDownloadError,
  summary: mlbDownloadSummary,
  downloadStats: downloadMlbStats,
} = usePlayerSeasonStatsDownload()
const {
  downloading: pitchDataDownloading,
  error: pitchDataDownloadError,
  summary: pitchDataDownloadSummary,
  downloadPitchData,
} = usePitchDataDownload()
const {
  uploading: pitchUploading,
  error: pitchImportError,
  summary: pitchImportSummary,
  importFile: importPitchDataFile,
} = usePitchDataImport()

watch(
  () => [filters.playerName, filters.teamId, filters.seasonStart, filters.seasonEnd, filters.category, pagination.perPage, sort.value],
  () => {
    pagination.page = 1
  },
)

watch(
  () => [filters.seasonStart, filters.seasonEnd],
  ([seasonStart, seasonEnd]) => {
    const startYear = Number(seasonStart)
    const endYear = Number(seasonEnd)
    if (startYear && endYear && startYear > endYear) {
      filters.seasonEnd = filters.seasonStart
    }
  },
)

watch(
  () => [mlbDownloadOptions.startYear, mlbDownloadOptions.endYear],
  () => {
    normalizeDownloadYearRange()
  },
)

watch(
  () => [mlbDownloadOptions.startDate, mlbDownloadOptions.endDate],
  () => {
    normalizePitchDownloadDateRange()
  },
)

watch(
  () => [pitchDataFilters.gameDateStart, pitchDataFilters.gameDateEnd],
  ([gameDateStart, gameDateEnd]) => {
    if (gameDateStart && gameDateEnd && gameDateStart > gameDateEnd) {
      pitchDataFilters.gameDateEnd = pitchDataFilters.gameDateStart
    }
  },
)

watch(
  () => [
    pitchDataFilters.gameDateStart,
    pitchDataFilters.gameDateEnd,
    pitchDataFilters.gamePk,
    pitchDataFilters.pitcher,
    pitchDataFilters.batter,
    pitchDataFilters.pitchType,
    pitchDataFilters.events,
    pitchDataOptions.perPage,
  ],
  () => {
    pitchDataOptions.page = 1
  },
)

watch(
  () => filters.category,
  (category) => {
    sort.value = DEFAULT_SORT_BY_CATEGORY[category] || DEFAULT_SORT_BY_CATEGORY.batting
    if (category === 'pitchData') {
      pitchDataOptions.page = 1
    }
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

const pitchTypeOptions = computed(() => {
  const values = new Set(
    (pitchMeta.value.availablePitchTypes || [])
      .concat(
        pitchRows.value
          .map((row) => String(row.pitchType || '').trim())
          .filter(Boolean),
      ),
  )

  if (pitchDataFilters.pitchType) values.add(pitchDataFilters.pitchType)

  return Array.from(values).sort((left, right) => left.localeCompare(right))
})

const pitchEventOptions = computed(() => {
  const values = new Set(
    (pitchMeta.value.availableEvents || [])
      .concat(
        pitchRows.value
          .map((row) => String(row.events || '').trim())
          .filter(Boolean),
      ),
  )

  if (pitchDataFilters.events) values.add(pitchDataFilters.events)

  return Array.from(values).sort((left, right) => left.localeCompare(right))
})

const showPlayerSuggestions = computed(
  () =>
    playerInputFocused.value &&
    filters.playerName.trim().length >= 2 &&
    (playerSuggestionsLoading.value || playerSuggestions.value.length > 0),
)

const showPitcherSuggestions = computed(
  () =>
    pitcherInputFocused.value &&
    pitcherNameInput.value.trim().length >= 2 &&
    (pitcherSuggestionsLoading.value || pitcherSuggestions.value.length > 0),
)

const showBatterSuggestions = computed(
  () =>
    batterInputFocused.value &&
    batterNameInput.value.trim().length >= 2 &&
    (batterSuggestionsLoading.value || batterSuggestions.value.length > 0),
)

const importBusy = computed(() => uploading.value || pitchUploading.value)
const dataActionBusy = computed(() => importBusy.value || mlbDownloading.value || pitchDataDownloading.value)

const importStatusTone = computed(() => {
  if (dataActionBusy.value) return 'live'
  if (importError.value || pitchImportError.value || mlbDownloadError.value || pitchDataDownloadError.value) return 'error'
  if (selectedImportFile.value || selectedPitchImportFile.value) return 'staged'
  if (importSummary.value || pitchImportSummary.value || mlbDownloadSummary.value || pitchDataDownloadSummary.value) return 'success'
  return 'idle'
})

const importStatusLabel = computed(() => {
  if (pitchDataDownloading.value) return 'Pitch data download in progress'
  if (mlbDownloading.value) return 'MLB download in progress'
  if (importBusy.value) return 'Import in progress'
  if (importError.value || pitchImportError.value || mlbDownloadError.value || pitchDataDownloadError.value) return 'Data issue'
  if (selectedImportFile.value || selectedPitchImportFile.value) return 'File staged'
  if (importSummary.value || pitchImportSummary.value || mlbDownloadSummary.value || pitchDataDownloadSummary.value) return 'Latest data action'
  return 'Data imports'
})

const importStatusDetail = computed(() => {
  if (importError.value || pitchImportError.value || mlbDownloadError.value || pitchDataDownloadError.value) {
    return importError.value || pitchImportError.value || mlbDownloadError.value || pitchDataDownloadError.value
  }

  if (selectedImportFile.value) return stagedImportMessage.value
  if (selectedPitchImportFile.value) return stagedPitchImportMessage.value

  if (pitchDataDownloadSummary.value) return pitchDataDownloadSummary.value
  if (mlbDownloadSummary.value) return mlbDownloadSummary.value

  if (importSummary.value && pitchImportSummary.value) {
    return `Season: ${importSummary.value} | Pitch: ${pitchImportSummary.value}`
  }

  return importSummary.value || pitchImportSummary.value || stagedImportMessage.value
})

const importDrawerTitle = computed(() => (importTarget.value === 'season' ? 'Import CSV Data' : 'Import Pitch Data CSV'))
const tableTitle = computed(() => {
  if (filters.category === 'pitchData') {
    return 'Pitch Data Feed'
  }

  if (filters.category === 'pitching' || filters.category === 'pitchStats') {
    return 'Pitching Leaderboard'
  }

  return 'Batting Leaderboard'
})

const filterSummary = computed(() => {
  if (filters.category === 'pitchData') {
    const gameDateRangeLabel =
      pitchDataFilters.gameDateStart && pitchDataFilters.gameDateEnd
        ? `Game Dates: ${pitchDataFilters.gameDateStart} to ${pitchDataFilters.gameDateEnd}`
        : pitchDataFilters.gameDateStart
          ? `Game Date from: ${pitchDataFilters.gameDateStart}`
          : pitchDataFilters.gameDateEnd
            ? `Game Date through: ${pitchDataFilters.gameDateEnd}`
            : null

    const pitchFilters = [
      gameDateRangeLabel,
      pitchDataFilters.gamePk && `Game PK: ${pitchDataFilters.gamePk}`,
      (pitcherNameInput.value || pitchDataFilters.pitcher) && `Pitcher: ${pitcherNameInput.value || pitchDataFilters.pitcher}`,
      (batterNameInput.value || pitchDataFilters.batter) && `Batter: ${batterNameInput.value || pitchDataFilters.batter}`,
      pitchDataFilters.pitchType && `Pitch Type: ${pitchDataFilters.pitchType}`,
      pitchDataFilters.events && `Events: ${pitchDataFilters.events}`,
    ].filter(Boolean)

    return pitchFilters.length
      ? `${pitchFilters.join(' · ')} · Showing latest imported pitch rows (${pitchDataOptions.perPage} per page).`
      : `Showing latest imported pitch rows (${pitchDataOptions.perPage} per page).`
  }

  const seasonRangeLabel =
    filters.seasonStart && filters.seasonEnd
      ? `Seasons: ${filters.seasonStart}-${filters.seasonEnd}`
      : filters.seasonStart
        ? `Season from: ${filters.seasonStart}`
        : filters.seasonEnd
          ? `Season through: ${filters.seasonEnd}`
          : null

  const activeFilters = [
    filters.playerName && `Player: ${filters.playerName}`,
    selectedTeam.value &&
      `Team: ${selectedTeam.value.abbreviation || selectedTeam.value.short_name || selectedTeam.value.team_name || selectedTeam.value.name}`,
    seasonRangeLabel,
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

function updatePitchPerPage(event) {
  pitchDataOptions.perPage = Number(event.target.value)
}

function updatePitchPage(nextPage) {
  pitchDataOptions.page = nextPage
}

function normalizeDownloadYearRange() {
  if (mlbDownloadOptions.category === 'pitchData') return

  const startYear = Number(mlbDownloadOptions.startYear)
  const endYear = Number(mlbDownloadOptions.endYear)

  if (startYear && endYear && startYear > endYear) {
    mlbDownloadOptions.endYear = mlbDownloadOptions.startYear
  }
}

function normalizePitchDownloadDateRange() {
  if (mlbDownloadOptions.category !== 'pitchData') return

  if (mlbDownloadOptions.startDate && mlbDownloadOptions.endDate && mlbDownloadOptions.startDate > mlbDownloadOptions.endDate) {
    mlbDownloadOptions.endDate = mlbDownloadOptions.startDate
  }
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

function handlePitcherInputFocus() {
  if (pitcherSuggestionBlurTimer) {
    window.clearTimeout(pitcherSuggestionBlurTimer)
    pitcherSuggestionBlurTimer = null
  }

  // Start a fresh search when users return to this field after a prior selection.
  if (pitchDataFilters.pitcher) {
    pitchDataFilters.pitcher = ''
    pitcherNameInput.value = ''
  }

  pitcherInputFocused.value = true
}

function handlePitcherInputBlur() {
  pitcherSuggestionBlurTimer = window.setTimeout(() => {
    pitcherInputFocused.value = false
    pitcherSuggestionBlurTimer = null
  }, 120)
}

function applyPitcherSuggestion(player) {
  if (pitcherSuggestionBlurTimer) {
    window.clearTimeout(pitcherSuggestionBlurTimer)
    pitcherSuggestionBlurTimer = null
  }
  pitcherNameInput.value = player.fullName
  pitchDataFilters.pitcher = String(player.mlbId || player.id)
  pitcherInputFocused.value = false
}

function handlePitcherNameInput() {
  pitchDataFilters.pitcher = ''
}

function handleBatterInputFocus() {
  if (batterSuggestionBlurTimer) {
    window.clearTimeout(batterSuggestionBlurTimer)
    batterSuggestionBlurTimer = null
  }

  // Start a fresh search when users return to this field after a prior selection.
  if (pitchDataFilters.batter) {
    pitchDataFilters.batter = ''
    batterNameInput.value = ''
  }

  batterInputFocused.value = true
}

function handleBatterInputBlur() {
  batterSuggestionBlurTimer = window.setTimeout(() => {
    batterInputFocused.value = false
    batterSuggestionBlurTimer = null
  }, 120)
}

function applyBatterSuggestion(player) {
  if (batterSuggestionBlurTimer) {
    window.clearTimeout(batterSuggestionBlurTimer)
    batterSuggestionBlurTimer = null
  }
  batterNameInput.value = player.fullName
  pitchDataFilters.batter = String(player.mlbId || player.id)
  batterInputFocused.value = false
}

function handleBatterNameInput() {
  pitchDataFilters.batter = ''
}

function openImportPanel(target = 'season') {
  importTarget.value = target
  importPanelOpen.value = true
}

function closeImportPanel() {
  if (importBusy.value) return

  importPanelOpen.value = false
}

async function handleMlbDownload() {
  if (mlbDownloadOptions.category === 'pitchData') {
    normalizePitchDownloadDateRange()

    const result = await downloadPitchData({
      startDate: mlbDownloadOptions.startDate,
      endDate: mlbDownloadOptions.endDate,
      gameTypes: mlbDownloadOptions.gameTypes,
      chunkDays: mlbDownloadOptions.chunkDays,
    })

    if (!result) return

    filters.category = 'pitchData'
    pitchDataFilters.gameDateStart = mlbDownloadOptions.startDate
    pitchDataFilters.gameDateEnd = mlbDownloadOptions.endDate
    pitchDataOptions.page = 1
    await refreshPitchData()
    return
  }

  normalizeDownloadYearRange()

  const result = await downloadMlbStats({
    category: mlbDownloadOptions.category,
    startYear: mlbDownloadOptions.startYear,
    endYear: mlbDownloadOptions.endYear,
    replaceSeason: mlbDownloadOptions.replaceSeason,
  })

  if (!result) return

  filters.category = mlbDownloadOptions.category
  filters.seasonStart = mlbDownloadOptions.startYear
  filters.seasonEnd = mlbDownloadOptions.endYear
  sort.value = DEFAULT_SORT_BY_CATEGORY[filters.category] || DEFAULT_SORT_BY_CATEGORY.batting
  await refresh()
}

function resetFilters() {
  const activeCategory = filters.category

  filters.playerName = ''
  filters.teamId = ''
  filters.seasonStart = ''
  filters.seasonEnd = ''
  pagination.page = 1
  pitchDataOptions.page = 1
  pitchDataOptions.perPage = 50
  pitchDataFilters.gameDateStart = ''
  pitchDataFilters.gameDateEnd = ''
  pitchDataFilters.gamePk = ''
  pitchDataFilters.pitcher = ''
  pitchDataFilters.batter = ''
  pitcherNameInput.value = ''
  batterNameInput.value = ''
  pitchDataFilters.pitchType = ''
  pitchDataFilters.events = ''
  sort.value = DEFAULT_SORT_BY_CATEGORY[activeCategory] || DEFAULT_SORT_BY_CATEGORY.batting
}

function handleFileSelected(file) {
  selectedImportFile.value = file
  stagedImportMessage.value = `${file.name} is selected and ready to import.`
  importTarget.value = 'season'
  importPanelOpen.value = true
}

async function handleImportRequest(request) {
  await processImportRequest(request, 'season')
}

async function processImportRequest(request, fallbackTarget) {
  const importFilePayload = request?.file || request
  const replaceSeason = Boolean(request?.replaceSeason)
  const detectedTarget = await detectImportTargetFromCsv(importFilePayload)
  const target = detectedTarget || fallbackTarget

  if (target === 'pitch') {
    importTarget.value = 'pitch'
    selectedPitchImportFile.value = importFilePayload
    selectedImportFile.value = null
    importPanelOpen.value = true

    const result = await importPitchDataFile(importFilePayload)
    if (!result) return

    selectedPitchImportFile.value = null
    stagedPitchImportMessage.value = `Latest pitch data file: ${importFilePayload.name}.`
    pitchImportPickerKey.value += 1
    await refreshPitchData()
    importPanelOpen.value = false
    return
  }

  importTarget.value = 'season'
  selectedImportFile.value = importFilePayload
  selectedPitchImportFile.value = null
  importPanelOpen.value = true
  const result = await importFile(importFilePayload, { replaceSeason })
  if (!result) return

  await refresh()
  selectedImportFile.value = null
  stagedImportMessage.value = `Latest import file: ${importFilePayload.name}.`
  importPickerKey.value += 1
  importPanelOpen.value = false
}

function handlePitchFileSelected(file) {
  selectedPitchImportFile.value = file
  stagedPitchImportMessage.value = `${file.name} is selected and ready for pitch data import.`
  importTarget.value = 'pitch'
  importPanelOpen.value = true
}

async function handlePitchImportRequest(request) {
  await processImportRequest(request, 'pitch')
}

async function detectImportTargetFromCsv(file) {
  if (!file || typeof file.text !== 'function') return null

  try {
    const csvSnippet = await file.slice(0, 64 * 1024).text()
    const [rawHeaderLine] = csvSnippet.split(/\r?\n/, 1)
    if (!rawHeaderLine) return null

    const normalizedHeaders = parseCsvHeader(rawHeaderLine)
    const hasPitchHeaders = PITCH_REQUIRED_HEADERS.every((header) => normalizedHeaders.includes(header))
    if (hasPitchHeaders) return 'pitch'

    const hasSeasonHeaders = SEASON_REQUIRED_HEADERS.every((header) => normalizedHeaders.includes(header))
    if (hasSeasonHeaders) return 'season'
  } catch (error) {
    console.error('Unable to inspect CSV header for import target detection', error)
  }

  return null
}

function parseCsvHeader(headerLine) {
  const columns = []
  let current = ''
  let insideQuotes = false

  for (let index = 0; index < headerLine.length; index += 1) {
    const character = headerLine[index]
    const nextCharacter = headerLine[index + 1]

    if (character === '"') {
      if (insideQuotes && nextCharacter === '"') {
        current += '"'
        index += 1
      } else {
        insideQuotes = !insideQuotes
      }
      continue
    }

    if (character === ',' && !insideQuotes) {
      columns.push(normalizeHeaderKey(current))
      current = ''
      continue
    }

    current += character
  }

  columns.push(normalizeHeaderKey(current))
  return columns
}

function normalizeHeaderKey(value) {
  return value.toString().trim().replace(/^\uFEFF/, '').toLowerCase()
}
</script>

<template>
  <main class="dashboard-shell">
    <section class="hero-panel">
      <div class="hero-copy">
        <p class="eyebrow">Front Office Dashboard</p>
        <h1>Player Season Stat Board</h1>
        <p class="lede">
          Command center for searching, sorting, and comparing imported player season stats.
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
          <span>Category</span>
          <select v-model="filters.category">
            <option value="batting">Batting</option>
            <option value="pitching">Pitching</option>
            <option value="pitchData">Pitch Data</option>
          </select>
        </label>

        <label v-if="filters.category !== 'pitchData'" class="field">
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

        <label v-if="filters.category !== 'pitchData'" class="field">
          <span>Team</span>
          <select v-model="filters.teamId" data-test="team-filter">
            <option value="">All teams</option>
            <option v-for="teamOption in meta.availableTeams" :key="teamOption.id" :value="String(teamOption.id)">
              {{ teamOption.abbreviation }} · {{ teamOption.short_name || teamOption.team_name || teamOption.name }}
            </option>
          </select>
        </label>

        <label v-if="filters.category !== 'pitchData'" class="field">
          <span>Season Start</span>
          <select v-model="filters.seasonStart" data-test="season-start-filter">
            <option value="">Any</option>
            <option v-for="seasonOption in meta.availableSeasons" :key="`start-${seasonOption}`" :value="seasonOption">
              {{ seasonOption }}
            </option>
          </select>
        </label>

        <label v-if="filters.category !== 'pitchData'" class="field">
          <span>Season End</span>
          <select v-model="filters.seasonEnd" data-test="season-end-filter">
            <option value="">Any</option>
            <option v-for="seasonOption in meta.availableSeasons" :key="seasonOption" :value="seasonOption">
              {{ seasonOption }}
            </option>
          </select>
        </label>

        <label v-if="filters.category !== 'pitchData'" class="field">
          <span>Rows per page</span>
          <select :value="pagination.perPage" @change="updatePerPage">
            <option :value="10">10</option>
            <option :value="15">15</option>
            <option :value="30">30</option>
            <option :value="50">50</option>
            <option :value="100">100</option>
          </select>
        </label>

        <label v-else class="field">
          <span>Pitch rows per page</span>
          <select :value="pitchDataOptions.perPage" @change="updatePitchPerPage">
            <option :value="25">25</option>
            <option :value="50">50</option>
            <option :value="100">100</option>
            <option :value="250">250</option>
            <option :value="500">500</option>
          </select>
        </label>

        <label v-if="filters.category === 'pitchData'" class="field">
          <span>Game Date Start</span>
          <input v-model="pitchDataFilters.gameDateStart" type="date" data-test="pitch-game-date-start-filter" />
        </label>

        <label v-if="filters.category === 'pitchData'" class="field">
          <span>Game Date End</span>
          <input v-model="pitchDataFilters.gameDateEnd" type="date" data-test="pitch-game-date-end-filter" />
        </label>

        <label v-if="filters.category === 'pitchData'" class="field">
          <span>Game PK</span>
          <input v-model="pitchDataFilters.gamePk" type="text" inputmode="numeric" data-test="pitch-game-pk-filter" />
        </label>

        <label v-if="filters.category === 'pitchData'" class="field">
          <span>Pitcher</span>
          <div class="typeahead-field">
            <input
              v-model="pitcherNameInput"
              type="text"
              placeholder="Boyd, Glasnow, Ohtani…"
              autocomplete="off"
              data-test="pitch-pitcher-filter"
              @input="handlePitcherNameInput"
              @focus="handlePitcherInputFocus"
              @blur="handlePitcherInputBlur"
            />

            <div v-if="showPitcherSuggestions" class="typeahead-menu" role="listbox" aria-label="Pitcher suggestions">
              <p v-if="pitcherSuggestionsLoading" class="typeahead-status">
                Looking up players…
              </p>

              <button
                v-for="player in pitcherSuggestions"
                v-else
                :key="player.id"
                type="button"
                class="typeahead-option"
                @mousedown.prevent="applyPitcherSuggestion(player)"
              >
                <span class="typeahead-option__name">{{ player.fullName }}</span>
                <span class="typeahead-option__meta">
                  {{ player.team.abbreviation || player.team.team_name || player.team.name }}
                </span>
              </button>
            </div>
          </div>
        </label>

        <label v-if="filters.category === 'pitchData'" class="field">
          <span>Batter</span>
          <div class="typeahead-field">
            <input
              v-model="batterNameInput"
              type="text"
              placeholder="Cabrera, Trout, Ohtani…"
              autocomplete="off"
              data-test="pitch-batter-filter"
              @input="handleBatterNameInput"
              @focus="handleBatterInputFocus"
              @blur="handleBatterInputBlur"
            />

            <div v-if="showBatterSuggestions" class="typeahead-menu" role="listbox" aria-label="Batter suggestions">
              <p v-if="batterSuggestionsLoading" class="typeahead-status">
                Looking up players…
              </p>

              <button
                v-for="player in batterSuggestions"
                v-else
                :key="player.id"
                type="button"
                class="typeahead-option"
                @mousedown.prevent="applyBatterSuggestion(player)"
              >
                <span class="typeahead-option__name">{{ player.fullName }}</span>
                <span class="typeahead-option__meta">
                  {{ player.team.abbreviation || player.team.team_name || player.team.name }}
                </span>
              </button>
            </div>
          </div>
        </label>

        <label v-if="filters.category === 'pitchData'" class="field">
          <span>Pitch Type</span>
          <select v-model="pitchDataFilters.pitchType" data-test="pitch-type-filter">
            <option value="">Any</option>
            <option v-for="pitchTypeOption in pitchTypeOptions" :key="pitchTypeOption" :value="pitchTypeOption">
              {{ pitchTypeOption }}
            </option>
          </select>
        </label>

        <label v-if="filters.category === 'pitchData'" class="field">
          <span>Events</span>
          <select v-model="pitchDataFilters.events" data-test="pitch-events-filter">
            <option value="">Any</option>
            <option v-for="pitchEventOption in pitchEventOptions" :key="pitchEventOption" :value="pitchEventOption">
              {{ pitchEventOption }}
            </option>
          </select>
        </label>
      </div>

      <form class="mlb-download-panel" data-test="mlb-download-panel" @submit.prevent="handleMlbDownload">
        <div>
          <p class="eyebrow">MLB Direct</p>
          <h3>{{ mlbDownloadOptions.category === 'pitchData' ? 'Download Pitch Data' : 'Download Season Stats' }}</h3>
        </div>

        <label class="field">
          <span>Stat Set</span>
          <select v-model="mlbDownloadOptions.category" data-test="mlb-download-category">
            <option value="batting">Batting</option>
            <option value="pitching">Pitching</option>
            <option value="pitchData">Pitch Data</option>
          </select>
        </label>

        <label v-if="mlbDownloadOptions.category !== 'pitchData'" class="field">
          <span>Start Year</span>
          <input
            v-model="mlbDownloadOptions.startYear"
            type="number"
            min="1876"
            :max="currentSeason"
            required
            data-test="mlb-download-start-year"
          />
        </label>

        <label v-if="mlbDownloadOptions.category !== 'pitchData'" class="field">
          <span>End Year</span>
          <input
            v-model="mlbDownloadOptions.endYear"
            type="number"
            min="1876"
            :max="currentSeason"
            required
            data-test="mlb-download-end-year"
          />
        </label>

        <label v-if="mlbDownloadOptions.category === 'pitchData'" class="field">
          <span>Start Date</span>
          <input
            v-model="mlbDownloadOptions.startDate"
            type="date"
            min="2008-01-01"
            required
            data-test="mlb-download-start-date"
          />
        </label>

        <label v-if="mlbDownloadOptions.category === 'pitchData'" class="field">
          <span>End Date</span>
          <input
            v-model="mlbDownloadOptions.endDate"
            type="date"
            min="2008-01-01"
            required
            data-test="mlb-download-end-date"
          />
        </label>

        <label v-if="mlbDownloadOptions.category === 'pitchData'" class="field">
          <span>Game Types</span>
          <input
            v-model="mlbDownloadOptions.gameTypes"
            type="text"
            inputmode="text"
            required
            data-test="mlb-download-game-types"
          />
        </label>

        <label v-if="mlbDownloadOptions.category === 'pitchData'" class="field">
          <span>Chunk Days</span>
          <input
            v-model.number="mlbDownloadOptions.chunkDays"
            type="number"
            min="1"
            max="14"
            required
            data-test="mlb-download-chunk-days"
          />
        </label>

        <label v-if="mlbDownloadOptions.category !== 'pitchData'" class="import-toggle mlb-download-panel__toggle">
          <input v-model="mlbDownloadOptions.replaceSeason" type="checkbox" :disabled="dataActionBusy" />
          <span>Replace matching season rows</span>
        </label>

        <button class="ghost-button" type="submit" :disabled="dataActionBusy" data-test="execute-mlb-download">
          {{ dataActionBusy && (mlbDownloading || pitchDataDownloading) ? 'Downloading...' : 'Download MLB Data' }}
        </button>
      </form>
    </section>

    <section class="table-stage">
      <header class="table-stage__header">
        <div>
          <h2>{{ tableTitle }}</h2>
          <p></p>
        </div>

        <div class="table-actions">
          <div :class="['import-utility', `import-utility--${importStatusTone}`]">
            <div class="import-chip">
              <span class="import-chip__label">{{ importStatusLabel }}</span>
              <span class="import-chip__detail">{{ importStatusDetail }}</span>
            </div>
            <button class="ghost-button import-utility__button" type="button" data-test="open-import-panel" :disabled="dataActionBusy" @click="openImportPanel(filters.category === 'pitchData' ? 'pitch' : 'season')">
              {{ importBusy ? 'Importing…' : 'Import CSV' }}
            </button>
          </div>

          <button class="ghost-button" type="button" :disabled="filters.category === 'pitchData' ? pitchLoading : loading" @click="filters.category === 'pitchData' ? refreshPitchData() : refresh()">
            {{ (filters.category === 'pitchData' ? pitchLoading : loading) ? 'Refreshing…' : 'Refresh Data' }}
          </button>
        </div>
      </header>

      <div v-if="importPanelOpen || importBusy" class="import-drawer-backdrop" @click.self="closeImportPanel">
        <section class="import-drawer" aria-label="CSV import panel">
          <header class="import-drawer__header">
            <div>
              <p class="eyebrow">Data Import</p>
              <h3>{{ importDrawerTitle }}</h3>
            </div>
            <button class="ghost-button" type="button" :disabled="importBusy" @click="closeImportPanel">
              Close
            </button>
          </header>

          <CsvImportPicker
            v-if="importTarget === 'season'"
            :key="importPickerKey"
            variant="drawer"
            :busy="uploading"
            :status-message="importSummary || stagedImportMessage"
            :upload-error="importError"
            @file-selected="handleFileSelected"
            @import-request="handleImportRequest"
          />

          <CsvImportPicker
            v-else
            :key="pitchImportPickerKey"
            variant="drawer"
            :busy="pitchUploading"
            :status-message="pitchImportSummary || stagedPitchImportMessage"
            :upload-error="pitchImportError"
            headline="Pitch Data Import"
            description="Select a pitch-level CSV export to refresh the pitch data dataset used for downstream analysis."
            status-noun="pitch data"
            :show-replace-season-toggle="false"
            file-input-id="pitch-data-csv"
            @file-selected="handlePitchFileSelected"
            @import-request="handlePitchImportRequest"
          />
        </section>
      </div>

      <p v-if="filters.category === 'pitchData' ? pitchError : error" class="error-banner">
        {{ filters.category === 'pitchData' ? pitchError : error }}
      </p>

      <PitchDataTable
        v-if="filters.category === 'pitchData'"
        :rows="pitchRows"
        :meta="pitchMeta"
        :loading="pitchLoading"
        @page-change="updatePitchPage"
      />

      <PlayerSeasonStatsTable
        v-else
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
