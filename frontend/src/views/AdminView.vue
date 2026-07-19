<script setup>
import { computed, nextTick, onMounted, reactive, ref, watch } from 'vue'

import CsvImportPicker from '../components/CsvImportPicker.vue'
import AdminDataHealthPanel from '../components/admin/AdminDataHealthPanel.vue'
import AdminDatabaseDetailsDialog from '../components/admin/AdminDatabaseDetailsDialog.vue'
import AdminGameDetailsSyncCard from '../components/admin/AdminGameDetailsSyncCard.vue'
import AdminPitchDataSyncCard from '../components/admin/AdminPitchDataSyncCard.vue'
import AdminRosterSnapshotWorkspace from '../components/admin/AdminRosterSnapshotWorkspace.vue'
import AdminScheduleSyncCard from '../components/admin/AdminScheduleSyncCard.vue'
import AdminSyncConfirmationDialog from '../components/admin/AdminSyncConfirmationDialog.vue'
import AdminTaskCard from '../components/admin/AdminTaskCard.vue'
import { useAdminTask } from '../composables/useAdminTask'
import { useGameDetailsSync } from '../composables/useGameDetailsSync'
import { usePitchDataSync } from '../composables/usePitchDataSync'
import { usePitchDataImport } from '../composables/usePitchDataImport'
import { usePlayerSeasonStatsDownload } from '../composables/usePlayerSeasonStatsDownload'
import { usePlayerSeasonStatsImport } from '../composables/usePlayerSeasonStatsImport'
import { useRosterSnapshots } from '../composables/useRosterSnapshots'

const now = new Date()
const today = [
  now.getFullYear(),
  String(now.getMonth() + 1).padStart(2, '0'),
  String(now.getDate()).padStart(2, '0'),
].join('-')
const currentSeason = new Date().getFullYear()
const databaseDetailsOpen = ref(false)
const databaseDetailsButton = ref(null)
const gameDetailsConfirmationOpen = ref(false)
const gameDetailsSyncCard = ref(null)
const pendingGameDetailsParameters = ref(null)
const pendingGameDetailsEstimate = ref(null)
const pitchDataConfirmationOpen = ref(false)
const pitchDataSyncCard = ref(null)
const pendingPitchDataParameters = ref(null)
const pendingPitchDataEstimate = ref(null)
const adminTabs = [
  { id: 'download', label: 'Download & Import' },
  { id: 'operations', label: 'Operational Tasks' },
  { id: 'local-imports', label: 'Local File Imports' },
]
const activeAdminTab = ref(adminTabs[0].id)

const statsOptions = reactive({
  category: 'batting',
  startYear: currentSeason,
  endYear: currentSeason,
  replaceSeason: true,
})

const pitchOptions = reactive({
  startDate: today,
  endDate: today,
  gameTypes: 'R',
  chunkDays: 7,
})

const scheduleOptions = reactive({
  startDate: today,
  endDate: today,
  gameTypes: 'R',
  sportId: 1,
})

const gameDetailsOptions = reactive({
  startDate: today,
  endDate: today,
  mlbGameId: '',
})

const profileOptions = reactive({
  onlyMissing: true,
  batchSize: 50,
  limit: '',
  mlbIds: '',
})

const teamHistoryOptions = reactive({
  limit: '',
  mlbIds: '',
})

const rosterOptions = reactive({
  teamScope: 'team',
  teamMlbId: '',
  season: currentSeason,
})

const rosterSnapshotOptions = reactive({
  teamMlbId: '',
  snapshotOn: today,
})

const contextualBenchmarkOptions = reactive({
  startDate: today,
  endDate: today,
})

const {
  runningTask,
  error: taskError,
  lastResult,
  overviewLoading,
  overviewError,
  dataHealth,
  dataHealthLoading,
  dataHealthError,
  scheduleImportRange,
  scheduleDateRange,
  rosterCoverage,
  mlbTeams,
  databaseMetrics,
  playerSeasonStatsMetrics,
  pitchDataMetrics,
  gameDetailsMetrics,
  loadOverview,
  loadDataHealth,
  runTask,
} = useAdminTask()
const {
  task: gameDetailsTask,
  active: gameDetailsSyncActive,
  starting: gameDetailsSyncStarting,
  estimating: gameDetailsSyncEstimating,
  error: gameDetailsSyncError,
  start: startGameDetailsSync,
  estimate: estimateGameDetailsSync,
  cancel: cancelActiveGameDetailsSync,
  loadActiveTask: loadActiveGameDetailsSync,
} = useGameDetailsSync()
const {
  downloading: statsDownloading,
  error: statsDownloadError,
  summary: statsDownloadSummary,
  downloadStats,
} = usePlayerSeasonStatsDownload()
const {
  task: pitchDataTask,
  active: pitchDataSyncActive,
  starting: pitchDataSyncStarting,
  estimating: pitchDataSyncEstimating,
  error: pitchDataSyncError,
  start: startPitchDataSync,
  estimate: estimatePitchDataSync,
  cancel: cancelActivePitchDataSync,
  loadActiveTask: loadActivePitchDataSync,
} = usePitchDataSync()
const {
  uploading: statsUploading,
  error: statsImportError,
  summary: statsImportSummary,
  importFile: importStatsFile,
} = usePlayerSeasonStatsImport()
const {
  snapshots: rosterSnapshots,
  loading: rosterSnapshotsLoading,
  error: rosterSnapshotsError,
  loadSnapshots,
} = useRosterSnapshots()
const {
  uploading: pitchUploading,
  error: pitchImportError,
  summary: pitchImportSummary,
  importFile: importPitchFile,
} = usePitchDataImport()

const anyActionRunning = computed(
  () =>
    Boolean(runningTask.value) ||
    gameDetailsSyncActive.value ||
    gameDetailsSyncStarting.value ||
    gameDetailsSyncEstimating.value ||
    pitchDataSyncActive.value ||
    pitchDataSyncStarting.value ||
    pitchDataSyncEstimating.value ||
    statsDownloading.value ||
    statsUploading.value ||
    pitchUploading.value ||
    dataHealthLoading.value ||
    rosterSnapshotsLoading.value,
)

const resultEntries = computed(() => {
  const data = lastResult.value?.data || {}
  return Object.entries(data)
    .filter(([, value]) => value !== null && value !== undefined && !Array.isArray(value) && typeof value !== 'object')
    .slice(0, 8)
})

const gameDetailsEstimate = computed(() => {
  const parameters = pendingGameDetailsParameters.value
  const estimate = pendingGameDetailsEstimate.value
  if (!parameters) return null

  const spanDays = parameters.mlb_game_id ? null : inclusiveDayCount(parameters.start_date, parameters.end_date)
  const historicalTiming = estimate?.estimateSource === 'historical'
  return {
    scope: parameters.mlb_game_id
      ? `MLB game ${parameters.mlb_game_id}`
      : `${spanDays} calendar ${spanDays === 1 ? 'day' : 'days'} · ${formatDate(parameters.start_date)}–${formatDate(parameters.end_date)}`,
    estimatedGames: estimate?.gameCount ?? 0,
    duration: `about ${formatDurationSeconds(estimate?.estimatedSeconds ?? 0)}`,
    range: formatDurationRangeSeconds(estimate?.lowEstimatedSeconds ?? 0, estimate?.highEstimatedSeconds ?? 0),
    assumption: historicalTiming
      ? `Based on ${formatCount(estimate.timingSampleGameCount)} completed game${estimate.timingSampleGameCount === 1 ? '' : 's'} across ${estimate.timingSampleRunCount} prior sync ${estimate.timingSampleRunCount === 1 ? 'run' : 'runs'} (${formatDurationSeconds(estimate.secondsPerGame)} per game).`
      : `Conservative starting estimate: ${formatDurationSeconds(estimate?.secondsPerGame ?? 50)} per stored game. It will improve as completed sync timings are recorded.`,
  }
})

const pitchDataEstimate = computed(() => {
  const parameters = pendingPitchDataParameters.value
  const estimate = pendingPitchDataEstimate.value
  if (!parameters) return null

  const spanDays = inclusiveDayCount(parameters.start_date, parameters.end_date)
  const historicalTiming = estimate?.estimateSource === 'historical'
  return {
    scope: `${spanDays} calendar ${spanDays === 1 ? 'day' : 'days'} · ${formatDate(parameters.start_date)}–${formatDate(parameters.end_date)}`,
    estimatedGames: estimate?.gameCount ?? 0,
    duration: `about ${formatDurationSeconds(estimate?.estimatedSeconds ?? 0)}`,
    range: formatDurationRangeSeconds(estimate?.lowEstimatedSeconds ?? 0, estimate?.highEstimatedSeconds ?? 0),
    assumption: historicalTiming
      ? `Based on ${formatCount(estimate.timingSampleGameCount)} completed game${estimate.timingSampleGameCount === 1 ? '' : 's'} across ${estimate.timingSampleRunCount} prior sync ${estimate.timingSampleRunCount === 1 ? 'run' : 'runs'} (${formatDurationSeconds(estimate.secondsPerGame)} per game).`
      : `Conservative starting estimate: ${formatDurationSeconds(estimate?.secondsPerGame ?? 45)} per stored game. It will improve as completed sync timings are recorded.`,
  }
})

onMounted(() => Promise.all([loadOverview(), loadActiveGameDetailsSync(), loadActivePitchDataSync()]))

watch(
  () => gameDetailsTask.value?.status,
  (status, previousStatus) => {
    if (['completed', 'failed', 'cancelled'].includes(status) && ['queued', 'running'].includes(previousStatus)) {
      loadOverview()
    }
  },
)

watch(
  () => pitchDataTask.value?.status,
  (status, previousStatus) => {
    if (['completed', 'failed', 'cancelled'].includes(status) && ['queued', 'running'].includes(previousStatus)) {
      loadOverview()
    }
  },
)

function normalizeYearRange(options) {
  if (Number(options.startYear) > Number(options.endYear)) options.endYear = options.startYear
}

function normalizeDateRange(options) {
  if (options.startDate && options.endDate && options.startDate > options.endDate) options.endDate = options.startDate
}

function handleAdminTabKeydown(event, currentIndex) {
  let nextIndex

  if (event.key === 'ArrowRight') nextIndex = (currentIndex + 1) % adminTabs.length
  if (event.key === 'ArrowLeft') nextIndex = (currentIndex - 1 + adminTabs.length) % adminTabs.length
  if (event.key === 'Home') nextIndex = 0
  if (event.key === 'End') nextIndex = adminTabs.length - 1
  if (nextIndex === undefined) return

  event.preventDefault()
  const tabButtons = event.currentTarget.closest('[role="tablist"]')?.querySelectorAll('[role="tab"]')
  activeAdminTab.value = adminTabs[nextIndex].id
  nextTick(() => tabButtons?.[nextIndex]?.focus())
}

async function handleStatsDownload() {
  normalizeYearRange(statsOptions)
  const result = await downloadStats(statsOptions)
  if (result) await loadOverview()
}

async function requestPitchDataSync() {
  normalizeDateRange(pitchOptions)
  const parameters = {
    start_date: pitchOptions.startDate,
    end_date: pitchOptions.endDate,
    game_types: pitchOptions.gameTypes,
    chunk_days: pitchOptions.chunkDays,
  }
  const estimate = await estimatePitchDataSync(parameters)
  if (!estimate) return

  pendingPitchDataParameters.value = parameters
  pendingPitchDataEstimate.value = estimate
  pitchDataConfirmationOpen.value = true
}

async function cancelPitchDataSync() {
  pitchDataConfirmationOpen.value = false
  pendingPitchDataParameters.value = null
  pendingPitchDataEstimate.value = null
  await nextTick()
  pitchDataSyncCard.value?.focusSyncButton()
}

async function confirmPitchDataSync() {
  const parameters = pendingPitchDataParameters.value
  if (!parameters) return

  pitchDataConfirmationOpen.value = false
  pendingPitchDataParameters.value = null
  pendingPitchDataEstimate.value = null
  await startPitchDataSync(parameters)
}

async function handleScheduleSync() {
  normalizeDateRange(scheduleOptions)
  const result = await runTask('mlb_schedule_sync', {
    start_date: scheduleOptions.startDate,
    end_date: scheduleOptions.endDate,
    game_types: scheduleOptions.gameTypes,
    sport_id: scheduleOptions.sportId,
  })
  if (result) await loadOverview()
}

async function requestGameDetailsSync() {
  normalizeDateRange(gameDetailsOptions)
  const parameters = {
    start_date: gameDetailsOptions.mlbGameId ? null : gameDetailsOptions.startDate,
    end_date: gameDetailsOptions.mlbGameId ? null : gameDetailsOptions.endDate,
    mlb_game_id: gameDetailsOptions.mlbGameId || null,
  }
  const estimate = await estimateGameDetailsSync(parameters)
  if (!estimate) return

  pendingGameDetailsParameters.value = parameters
  pendingGameDetailsEstimate.value = estimate
  gameDetailsConfirmationOpen.value = true
}

async function cancelGameDetailsSync() {
  gameDetailsConfirmationOpen.value = false
  pendingGameDetailsParameters.value = null
  pendingGameDetailsEstimate.value = null
  await nextTick()
  gameDetailsSyncCard.value?.focusSyncButton()
}

async function confirmGameDetailsSync() {
  const parameters = pendingGameDetailsParameters.value
  if (!parameters) return

  gameDetailsConfirmationOpen.value = false
  pendingGameDetailsParameters.value = null
  pendingGameDetailsEstimate.value = null
  await startGameDetailsSync(parameters)
}

async function handleProfileSync() {
  await runTask('mlb_player_profiles_sync', {
    only_missing: profileOptions.onlyMissing,
    batch_size: profileOptions.batchSize,
    limit: profileOptions.limit || null,
    mlb_ids: profileOptions.mlbIds || null,
  })
}

async function handleTeamHistorySync() {
  await runTask('mlb_player_team_histories_sync', {
    limit: teamHistoryOptions.limit || null,
    mlb_ids: teamHistoryOptions.mlbIds || null,
  })
}

async function handleRosterSync() {
  await runTask('mlb_roster_sync', {
    team_scope: rosterOptions.teamScope,
    team_mlb_id: rosterOptions.teamScope === 'team' ? rosterOptions.teamMlbId : null,
    season: rosterOptions.season,
  })
}

async function handleRosterSnapshotSync() {
  const result = await runTask('mlb_roster_snapshots_sync', {
    team_mlb_id: rosterSnapshotOptions.teamMlbId,
    snapshot_on: rosterSnapshotOptions.snapshotOn,
  })
  if (result) await handleRosterSnapshotLoad()
}

async function handleRosterSnapshotLoad() {
  await loadSnapshots({
    teamMlbId: rosterSnapshotOptions.teamMlbId,
    on: rosterSnapshotOptions.snapshotOn,
  })
}

async function handleContextualBenchmarksRefresh() {
  normalizeDateRange(contextualBenchmarkOptions)
  const result = await runTask('contextual_benchmarks_refresh', {
    start_date: contextualBenchmarkOptions.startDate,
    end_date: contextualBenchmarkOptions.endDate,
  })
  if (result) await loadOverview()
}

async function handleGameDetailsDeferredAnalyticsRefresh() {
  const parameters = gameDetailsRefreshParameters(gameDetailsTask.value)
  if (!parameters) return

  const result = await runTask('daily_analytics_refresh', parameters)
  if (result) {
    await loadOverview()
    await loadActiveGameDetailsSync()
  }
}

async function handleStatsImport({ file, replaceSeason }) {
  const result = await importStatsFile(file, { replaceSeason })
  if (result) await loadOverview()
}

async function handlePitchImport({ file }) {
  const result = await importPitchFile(file)
  if (result) await loadOverview()
}

function humanize(value) {
  return String(value).replaceAll('_', ' ').replace(/\b\w/g, (letter) => letter.toUpperCase())
}

function formatTimestamp(value) {
  if (!value) return ''
  return new Intl.DateTimeFormat('en-US', {
    month: 'short',
    day: 'numeric',
    hour: 'numeric',
    minute: '2-digit',
  }).format(new Date(value))
}

function formatDate(value) {
  if (!value) return '—'
  return new Intl.DateTimeFormat('en-US', {
    month: 'short',
    day: 'numeric',
    year: 'numeric',
  }).format(new Date(`${value}T12:00:00`))
}

function formatBytes(value) {
  if (!Number.isFinite(value) || value < 0) return 'Unavailable'

  const units = ['B', 'KB', 'MB', 'GB', 'TB']
  let amount = value
  let unitIndex = 0
  while (amount >= 1024 && unitIndex < units.length - 1) {
    amount /= 1024
    unitIndex += 1
  }

  const precision = unitIndex < 2 || amount >= 100 ? 0 : amount >= 10 ? 1 : 2
  return `${amount.toFixed(precision)} ${units[unitIndex]}`
}

function formatCount(value) {
  if (!Number.isFinite(value)) return 'Unavailable'
  return new Intl.NumberFormat('en-US').format(value)
}

function inclusiveDayCount(startDate, endDate) {
  const start = new Date(`${startDate}T12:00:00Z`)
  const end = new Date(`${endDate}T12:00:00Z`)
  return Math.max(1, Math.round((end - start) / 86_400_000) + 1)
}

function formatDuration(minutes) {
  if (minutes < 60) return `${minutes} ${minutes === 1 ? 'minute' : 'minutes'}`

  const hours = Math.floor(minutes / 60)
  const remainingMinutes = minutes % 60
  return `${hours} hr${remainingMinutes ? ` ${remainingMinutes} min` : ''}`
}

function formatDurationRange(lowMinutes, highMinutes) {
  if (highMinutes < 60) return `${lowMinutes}–${highMinutes} minutes`
  return `${formatDuration(lowMinutes)}–${formatDuration(highMinutes)}`
}

function formatDurationSeconds(seconds) {
  const roundedMinutes = Math.max(1, Math.round(seconds / 60))
  return formatDuration(roundedMinutes)
}

function formatDurationRangeSeconds(lowSeconds, highSeconds) {
  const lowMinutes = Math.max(1, Math.round(lowSeconds / 60))
  const highMinutes = Math.max(lowMinutes, Math.round(highSeconds / 60))
  return formatDurationRange(lowMinutes, highMinutes)
}

function gameDetailsRefreshParameters(task) {
  if (!task?.taskParameters) return null
  const startDate = task.taskParameters.start_date
  const endDate = task.taskParameters.end_date || startDate
  if (!startDate || !endDate) return null

  return {
    start_date: startDate,
    end_date: endDate,
  }
}

async function openDatabaseDetails() {
  databaseDetailsOpen.value = true
}

async function closeDatabaseDetails() {
  databaseDetailsOpen.value = false
  await nextTick()
  databaseDetailsButton.value?.focus()
}

</script>

<template>
  <main class="admin-shell">
    <section class="admin-hero">
      <div>
        <p class="eyebrow">DiamondIQ operations</p>
        <h1>Data administration</h1>
        <p>
          Import local datasets, retrieve source data, and run MLB synchronization tasks from one operational workspace.
        </p>
      </div>
      <div class="admin-hero__aside">
        <div class="database-footprint" data-test="database-size">
          <span>{{ humanize(databaseMetrics.environment || 'current') }} database</span>
          <strong>{{ overviewLoading ? 'Measuring…' : formatBytes(databaseMetrics.sizeBytes) }}</strong>
          <small>{{ databaseMetrics.adapter || 'Database' }} footprint</small>
          <button ref="databaseDetailsButton" type="button" data-test="database-details-button" @click="openDatabaseDetails">
            View details
          </button>
        </div>
        <AdminDataHealthPanel
          :report="dataHealth"
          :loading="dataHealthLoading"
          :error="dataHealthError"
          @refresh="loadDataHealth"
        />
        <div class="admin-hero__status" :class="{ 'admin-hero__status--busy': anyActionRunning }">
          <span aria-hidden="true"></span>
          {{ anyActionRunning ? 'Data operation in progress' : 'Admin tools ready' }}
        </div>
      </div>
    </section>

    <AdminDatabaseDetailsDialog
      :open="databaseDetailsOpen"
      :metrics="databaseMetrics"
      :loading="overviewLoading"
      @close="closeDatabaseDetails"
    />

    <AdminSyncConfirmationDialog
      :open="pitchDataConfirmationOpen"
      test-prefix="pitch-data"
      title="Statcast pitch synchronization may take a while"
      :estimate="pitchDataEstimate"
      note="Baseball Savant response times and local CSV import work can make the actual duration shorter or longer. Keep the Rails server running until the task finishes."
      @cancel="cancelPitchDataSync"
      @confirm="confirmPitchDataSync"
    />

    <AdminSyncConfirmationDialog
      :open="gameDetailsConfirmationOpen"
      test-prefix="game-details"
      title="Game detail synchronization may take a while"
      :estimate="gameDetailsEstimate"
      note="MLB response times and local analytics work can make the actual duration shorter or longer. Keep the Rails server running until the task finishes."
      @cancel="cancelGameDetailsSync"
      @confirm="confirmGameDetailsSync"
    />

    <nav class="admin-tabs" role="tablist" aria-label="Administration tools">
      <button
        v-for="(tab, index) in adminTabs"
        :id="`admin-tab-${tab.id}`"
        :key="tab.id"
        type="button"
        role="tab"
        :class="['admin-tabs__tab', { 'admin-tabs__tab--active': activeAdminTab === tab.id }]"
        :aria-controls="`admin-panel-${tab.id}`"
        :aria-selected="activeAdminTab === tab.id"
        :tabindex="activeAdminTab === tab.id ? 0 : -1"
        :data-test="`admin-tab-${tab.id}`"
        @click="activeAdminTab = tab.id"
        @keydown="handleAdminTabKeydown($event, index)"
      >
        {{ tab.label }}
      </button>
    </nav>

    <section
      v-show="activeAdminTab === 'download'"
      id="admin-panel-download"
      class="admin-section admin-tab-panel"
      role="tabpanel"
      aria-labelledby="admin-tab-download"
      tabindex="0"
      data-test="admin-panel-download"
    >
      <header class="admin-section__heading">
        <div>
          <p class="eyebrow">Source retrieval</p>
          <h2>Download & import</h2>
        </div>
        <p>Fetch fresh source data and immediately upsert it into DiamondIQ.</p>
      </header>

      <div class="admin-grid admin-grid--two">
        <AdminTaskCard
          number="01"
          source="MLB Stats API"
          title="Player season statistics"
          chip="Download + import"
          description="Downloads and imports season-level batting or pitching statistics for the selected year range."
          data-test="stats-download-form"
          @submit.prevent="handleStatsDownload"
        >
          <div class="data-coverage" data-test="player-season-stats-coverage">
            <span>Currently stored</span>
            <dl v-if="playerSeasonStatsMetrics.earliestSeason && playerSeasonStatsMetrics.latestSeason">
              <div>
                <dt>From season</dt>
                <dd>{{ playerSeasonStatsMetrics.earliestSeason }}</dd>
              </div>
              <div>
                <dt>Through season</dt>
                <dd>{{ playerSeasonStatsMetrics.latestSeason }}</dd>
              </div>
            </dl>
            <p v-else>No player season statistics are currently stored.</p>
            <small>Approximately {{ formatCount(playerSeasonStatsMetrics.approximateRowCount) }} stat rows</small>
          </div>
          <div class="admin-fields admin-fields--four">
            <label>
              <span>Category</span>
              <select v-model="statsOptions.category">
                <option value="batting">Batting</option>
                <option value="pitching">Pitching</option>
              </select>
            </label>
            <label>
              <span>Start year</span>
              <input v-model.number="statsOptions.startYear" type="number" min="1876" :max="currentSeason + 1" required />
            </label>
            <label>
              <span>End year</span>
              <input v-model.number="statsOptions.endYear" type="number" min="1876" :max="currentSeason + 1" required />
            </label>
            <label class="admin-check">
              <input v-model="statsOptions.replaceSeason" type="checkbox" />
              <span>Replace season</span>
            </label>
          </div>
          <button class="admin-button" type="submit" :disabled="anyActionRunning">
            {{ statsDownloading ? 'Downloading statistics…' : 'Retrieve player statistics' }}
          </button>
          <p v-if="statsDownloadError" class="admin-message admin-message--error">{{ statsDownloadError }}</p>
          <p v-else-if="statsDownloadSummary" class="admin-message admin-message--success">{{ statsDownloadSummary }}</p>
        </AdminTaskCard>

        <AdminPitchDataSyncCard
          ref="pitchDataSyncCard"
          :options="pitchOptions"
          :metrics="pitchDataMetrics"
          :task="pitchDataTask"
          :active="pitchDataSyncActive"
          :starting="pitchDataSyncStarting"
          :any-action-running="anyActionRunning"
          :error="pitchDataSyncError"
          @submit="requestPitchDataSync"
          @cancel-active="cancelActivePitchDataSync"
        />
      </div>
    </section>

    <section
      v-show="activeAdminTab === 'local-imports'"
      id="admin-panel-local-imports"
      class="admin-section admin-tab-panel"
      role="tabpanel"
      aria-labelledby="admin-tab-local-imports"
      tabindex="0"
      data-test="admin-panel-local-imports"
    >
      <header class="admin-section__heading">
        <div>
          <p class="eyebrow">CSV intake</p>
          <h2>Local file imports</h2>
        </div>
        <p>Upload prepared CSV files when the source data is already available locally.</p>
      </header>

      <div class="admin-grid admin-grid--two admin-imports">
        <CsvImportPicker
          variant="drawer"
          headline="Player season stats"
          description="Import batting or pitching season-stat CSV data."
          file-input-id="admin-player-season-stats-csv"
          :busy="statsUploading"
          :status-message="statsImportSummary"
          :upload-error="statsImportError"
          :default-replace-season="true"
          @import-request="handleStatsImport"
        />
        <CsvImportPicker
          variant="drawer"
          headline="Statcast pitch data"
          description="Import pitch-by-pitch Baseball Savant CSV data."
          status-noun="pitch data"
          file-input-id="admin-pitch-data-csv"
          :busy="pitchUploading"
          :status-message="pitchImportSummary"
          :upload-error="pitchImportError"
          :show-replace-season-toggle="false"
          @import-request="handlePitchImport"
        />
      </div>
    </section>

    <section
      v-show="activeAdminTab === 'operations'"
      id="admin-panel-operations"
      class="admin-section admin-tab-panel"
      role="tabpanel"
      aria-labelledby="admin-tab-operations"
      tabindex="0"
      data-test="admin-panel-operations"
    >
      <header class="admin-section__heading">
        <div>
          <p class="eyebrow">MLB synchronization</p>
          <h2>Operational tasks</h2>
        </div>
        <p>These actions use the same services as their corresponding Rails tasks.</p>
      </header>

      <div class="admin-grid admin-grid--two">
        <AdminScheduleSyncCard
          :options="scheduleOptions"
          :import-range="scheduleImportRange"
          :date-range="scheduleDateRange"
          :overview-loading="overviewLoading"
          :overview-error="overviewError"
          :any-action-running="anyActionRunning"
          :running-task="runningTask"
          @submit="handleScheduleSync"
        />

        <AdminGameDetailsSyncCard
          ref="gameDetailsSyncCard"
          :options="gameDetailsOptions"
          :metrics="gameDetailsMetrics"
          :task="gameDetailsTask"
          :active="gameDetailsSyncActive"
          :starting="gameDetailsSyncStarting"
          :any-action-running="anyActionRunning"
          :running-task="runningTask"
          :error="gameDetailsSyncError"
          @submit="requestGameDetailsSync"
          @cancel-active="cancelActiveGameDetailsSync"
          @refresh-analytics="handleGameDetailsDeferredAnalyticsRefresh"
        />

        <AdminTaskCard
          data-test="profile-sync-form"
          source="Player identity"
          title="MLB profile synchronization"
          command="mlb_player_profiles:sync"
          description="Downloads MLB biographical, handedness, position, and headshot information for players already stored in DiamondIQ."
          @submit.prevent="handleProfileSync"
        >
          <div class="admin-fields admin-fields--four">
            <label><span>Batch size</span><input v-model.number="profileOptions.batchSize" type="number" min="1" max="100" required /></label>
            <label><span>Limit (optional)</span><input v-model="profileOptions.limit" type="number" min="1" /></label>
            <label class="admin-field--wide"><span>MLB IDs (optional)</span><input v-model="profileOptions.mlbIds" type="text" placeholder="700270, 669360" /></label>
            <label class="admin-check"><input v-model="profileOptions.onlyMissing" type="checkbox" /><span>Only missing</span></label>
          </div>
          <button class="admin-button" type="submit" :disabled="anyActionRunning">
            {{ runningTask === 'mlb_player_profiles_sync' ? 'Synchronizing profiles…' : 'Synchronize player profiles' }}
          </button>
        </AdminTaskCard>

        <AdminTaskCard
          data-test="team-history-sync-form"
          source="Player organization trail"
          title="MLB transaction history synchronization"
          command="mlb_player_team_histories:sync"
          description="Downloads official MLB transactions and rebuilds dated major-league organization tenures for Player Profile Team History cards."
          @submit.prevent="handleTeamHistorySync"
        >
          <div class="admin-fields admin-fields--two">
            <label><span>Limit (optional)</span><input v-model="teamHistoryOptions.limit" type="number" min="1" /></label>
            <label><span>MLB IDs (optional)</span><input v-model="teamHistoryOptions.mlbIds" type="text" placeholder="656427, 669360" /></label>
          </div>
          <button class="admin-button" type="submit" :disabled="anyActionRunning">
            {{ runningTask === 'mlb_player_team_histories_sync' ? 'Synchronizing team histories…' : 'Synchronize team histories' }}
          </button>
        </AdminTaskCard>

        <AdminTaskCard
          data-test="roster-sync-form"
          source="Current roster state"
          title="MLB 40-man roster synchronization"
          command="mlb_roster:sync"
          description="Downloads MLB 40-man rosters and updates player profiles, roster status, and dated team memberships for the selected season."
          @submit.prevent="handleRosterSync"
        >
          <p class="admin-card__coverage" data-test="roster-database-coverage">
            <strong>Database coverage:</strong>
            <template v-if="rosterCoverage.earliestDate && rosterCoverage.latestDate">
              {{ formatDate(rosterCoverage.earliestDate) }}–{{ formatDate(rosterCoverage.latestDate) }}
            </template>
            <template v-else>No dated roster memberships stored</template>
          </p>
          <div class="admin-fields admin-fields--three">
            <label>
              <span>Team selection</span>
              <select v-model="rosterOptions.teamScope" data-test="roster-team-scope">
                <option value="all">All MLB teams</option>
                <option value="american">American League</option>
                <option value="national">National League</option>
                <option value="team">Specific team</option>
              </select>
            </label>
            <label v-if="rosterOptions.teamScope === 'team'" class="admin-field--wide">
              <span>MLB team</span>
              <select v-model="rosterOptions.teamMlbId" data-test="roster-team" required>
                <option value="" disabled>Select a team</option>
                <option v-for="team in mlbTeams" :key="team.mlbId" :value="String(team.mlbId)">
                  {{ team.abbreviation }} · {{ team.name }} ({{ team.league === 'american' ? 'AL' : 'NL' }})
                </option>
              </select>
            </label>
            <label><span>Season</span><input v-model.number="rosterOptions.season" type="number" min="1876" :max="currentSeason" required /></label>
          </div>
          <p class="admin-card__hint" data-test="roster-coverage-policy">
            Synchronizes MLB's 40-man roster only. Completed seasons use the final stored regular-season game date; the current season uses today.
            Historical roster construction will be handled as a separate transaction-based workflow.
          </p>
          <button class="admin-button" type="submit" :disabled="anyActionRunning">
            {{ runningTask === 'mlb_roster_sync' ? 'Synchronizing roster…' : 'Synchronize team roster' }}
          </button>
        </AdminTaskCard>

        <AdminTaskCard
          as="article"
          source="Data maintenance"
          title="Rebuild current player positions"
          command="player_positions:backfill"
          maintenance
        >
          <p>Reconcile current position assignments from the latest active team membership for every player.</p>
          <button
            class="admin-button"
            type="button"
            :disabled="anyActionRunning"
            @click="runTask('player_positions_backfill')"
          >
            {{ runningTask === 'player_positions_backfill' ? 'Rebuilding positions…' : 'Rebuild player positions' }}
          </button>
        </AdminTaskCard>

        <AdminTaskCard
          data-test="contextual-benchmarks-refresh-form"
          source="Advanced analytics"
          title="Refresh contextual benchmarks"
          command="contextual_benchmarks:refresh"
          description="Rebuild MLB, position, and player-percentile benchmark context for a selected date range."
          maintenance
          @submit.prevent="handleContextualBenchmarksRefresh"
        >
          <div class="admin-fields admin-fields--two">
            <label><span>Start date</span><input v-model="contextualBenchmarkOptions.startDate" type="date" required /></label>
            <label><span>End date</span><input v-model="contextualBenchmarkOptions.endDate" type="date" required /></label>
          </div>
          <button class="admin-button" type="submit" :disabled="anyActionRunning">
            {{ runningTask === 'contextual_benchmarks_refresh' ? 'Refreshing contextual benchmarks…' : 'Refresh contextual benchmarks' }}
          </button>
        </AdminTaskCard>
      </div>

      <AdminRosterSnapshotWorkspace
        :options="rosterSnapshotOptions"
        :teams="mlbTeams"
        :snapshots="rosterSnapshots"
        :loading="rosterSnapshotsLoading"
        :error="rosterSnapshotsError"
        :any-action-running="anyActionRunning"
        :running-task="runningTask"
        :max-date="today"
        @sync="handleRosterSnapshotSync"
        @load="handleRosterSnapshotLoad"
      />

      <div v-if="taskError" class="admin-result admin-result--error" role="alert">
        <strong>Task could not be completed</strong>
        <p>{{ taskError }}</p>
      </div>
      <div v-else-if="lastResult" class="admin-result" data-test="task-result">
        <div>
          <p class="eyebrow">Latest task result</p>
          <h3>{{ lastResult.message }}</h3>
          <small>{{ humanize(lastResult.task) }} · {{ formatTimestamp(lastResult.finishedAt) }}</small>
        </div>
        <dl v-if="resultEntries.length">
          <div v-for="([key, value]) in resultEntries" :key="key">
            <dt>{{ humanize(key) }}</dt>
            <dd>{{ value }}</dd>
          </div>
        </dl>
      </div>
    </section>
  </main>
</template>

<style>
.admin-shell {
  min-height: 100vh;
  padding: 2.5rem 1.25rem 5rem;
  background:
    radial-gradient(circle at 10% 0%, rgba(143, 45, 36, 0.14), transparent 28%),
    radial-gradient(circle at 92% 16%, rgba(37, 90, 131, 0.16), transparent 30%),
    linear-gradient(180deg, #f7f1e3 0%, #ecdfc5 100%);
}

.admin-hero,
.admin-section,
.admin-tabs {
  width: min(1440px, calc(100vw - 2.5rem));
  margin: 0 auto;
}

.admin-hero {
  display: flex;
  justify-content: space-between;
  gap: 2rem;
  align-items: flex-end;
  padding: 2rem;
  border: 1px solid rgba(16, 38, 61, 0.12);
  border-radius: 28px;
  background: rgba(255, 252, 244, 0.9);
  box-shadow: 0 22px 60px rgba(73, 52, 24, 0.1);
}

.admin-hero h1 {
  color: #10263d;
  font-family: 'Avenir Next Condensed', sans-serif;
  font-size: clamp(2.8rem, 5vw, 5rem);
  line-height: 0.95;
  text-transform: uppercase;
}

.admin-hero p:not(.eyebrow) {
  max-width: 53rem;
  margin-top: 0.9rem;
  color: #4b5964;
  font-size: 1.04rem;
}

.admin-hero__aside {
  display: flex;
  flex: 0 0 auto;
  flex-direction: column;
  gap: 0.7rem;
  align-items: flex-end;
}

.database-footprint,
.data-health-summary {
  display: grid;
  min-width: 190px;
  padding: 0.8rem 0.95rem;
  border: 1px solid rgba(16, 38, 61, 0.12);
  border-radius: 16px;
  background: rgba(231, 237, 241, 0.78);
  text-align: right;
}

.database-footprint span,
.database-footprint small,
.data-health-summary span,
.data-health-summary small {
  color: #61707b;
  font-size: 0.65rem;
  font-weight: 800;
  letter-spacing: 0.06em;
  text-transform: uppercase;
}

.database-footprint button,
.data-health-summary button {
  justify-self: end;
  margin-top: 0.55rem;
  padding: 0;
  border: 0;
  color: #8f2d24;
  background: transparent;
  font: inherit;
  font-size: 0.66rem;
  font-weight: 900;
  letter-spacing: 0.04em;
  text-decoration: underline;
  text-underline-offset: 0.2em;
  text-transform: uppercase;
  cursor: pointer;
}

.database-footprint button:hover,
.database-footprint button:focus-visible,
.data-health-summary button:hover,
.data-health-summary button:focus-visible {
  color: #10263d;
}

.data-health-summary--healthy {
  border-color: rgba(45, 112, 71, 0.35);
  background: rgba(224, 240, 228, 0.82);
}

.data-health-summary--warning {
  border-color: rgba(177, 116, 22, 0.38);
  background: rgba(249, 235, 202, 0.86);
}

.data-health-summary--critical {
  border-color: rgba(143, 45, 36, 0.36);
  background: rgba(247, 225, 220, 0.88);
}

.database-modal {
  position: fixed;
  z-index: 100;
  inset: 0;
  display: grid;
  place-items: center;
  padding: 1rem;
  background: rgba(8, 22, 35, 0.7);
  backdrop-filter: blur(5px);
}

.database-insights {
  width: min(1200px, calc(100vw - 2rem));
  max-height: min(88vh, 900px);
  padding: 1.5rem;
  overflow: auto;
  outline: none;
  border: 1px solid rgba(16, 38, 61, 0.12);
  border-radius: 28px;
  background: rgba(255, 252, 245, 0.86);
  box-shadow: 0 16px 44px rgba(73, 52, 24, 0.07);
}

.database-insights__heading {
  display: flex;
  justify-content: space-between;
  gap: 1rem;
  align-items: flex-end;
}

.database-insights__heading h2 {
  color: #10263d;
  font-family: 'Avenir Next Condensed', sans-serif;
  font-size: 2rem;
  text-transform: uppercase;
}

.database-insights__heading-actions {
  display: flex;
  gap: 0.8rem;
  align-items: center;
}

.database-insights__heading-actions p {
  color: #61707b;
  font-size: 0.72rem;
  text-align: right;
}

.database-insights__heading-actions button {
  display: grid;
  flex: 0 0 auto;
  place-items: center;
  width: 34px;
  height: 34px;
  padding: 0;
  border: 1px solid rgba(16, 38, 61, 0.14);
  border-radius: 50%;
  color: #10263d;
  background: rgba(255, 255, 255, 0.72);
  font-size: 1.3rem;
  line-height: 1;
  cursor: pointer;
}

.database-insights__heading-actions button:hover,
.database-insights__heading-actions button:focus-visible {
  color: #fff;
  background: #8f2d24;
}

.database-summary-grid {
  display: grid;
  grid-template-columns: repeat(4, minmax(0, 1fr));
  gap: 0.75rem;
  margin-top: 1rem;
}

.database-summary-grid article {
  padding: 0.9rem;
  border: 1px solid rgba(16, 38, 61, 0.09);
  border-radius: 14px;
  background: rgba(231, 237, 241, 0.58);
}

.database-summary-grid span,
.database-summary-grid strong,
.database-summary-grid small {
  display: block;
}

.database-view-tabs {
  display: inline-flex;
  gap: 0.25rem;
  margin-top: 1rem;
  padding: 0.25rem;
  border: 1px solid rgba(16, 38, 61, 0.1);
  border-radius: 12px;
  background: rgba(231, 237, 241, 0.58);
}

.database-view-tabs button {
  padding: 0.5rem 0.8rem;
  border: 0;
  border-radius: 9px;
  color: #61707b;
  background: transparent;
  font-size: 0.68rem;
  font-weight: 800;
  letter-spacing: 0.04em;
  text-transform: uppercase;
  cursor: pointer;
}

.database-view-tabs button:hover,
.database-view-tabs button:focus-visible,
.database-view-tabs__active {
  color: #fff !important;
  background: #173652 !important;
}

.database-usage-window {
  margin-top: 0.75rem;
  color: #69747c;
  font-size: 0.72rem;
}

.database-usage-window strong {
  color: #173652;
}

.database-summary-grid span {
  color: #61707b;
  font-size: 0.62rem;
  font-weight: 800;
  letter-spacing: 0.07em;
  text-transform: uppercase;
}

.database-summary-grid strong {
  margin: 0.2rem 0;
  color: #10263d;
  font-family: 'Avenir Next Condensed', sans-serif;
  font-size: 1.65rem;
}

.database-summary-grid small {
  color: #6d787f;
  font-size: 0.65rem;
}

.database-table-wrap {
  margin-top: 1rem;
  overflow-x: auto;
  border: 1px solid rgba(16, 38, 61, 0.1);
  border-radius: 16px;
}

.database-table {
  width: 100%;
  min-width: 850px;
  border-collapse: collapse;
  background: rgba(255, 255, 255, 0.62);
}

.database-table--usage {
  min-width: 1120px;
}

.data-health-insights {
  width: min(1050px, calc(100vw - 2rem));
}

.data-health-loading {
  margin-top: 1rem;
  padding: 1.25rem;
  border-radius: 14px;
  color: #53616b;
  background: rgba(231, 237, 241, 0.58);
  text-align: center;
}

.data-health-text--healthy {
  color: #2d7047 !important;
}

.data-health-text--warning {
  color: #a26812 !important;
}

.data-health-text--critical {
  color: #8f2d24 !important;
}

.data-health-toolbar {
  display: flex;
  justify-content: space-between;
  gap: 1rem;
  align-items: center;
  margin-top: 1rem;
}

.data-health-toolbar p {
  color: #61707b;
  font-size: 0.75rem;
}

.data-health-toolbar button {
  padding: 0.55rem 0.8rem;
  border: 1px solid rgba(16, 38, 61, 0.16);
  border-radius: 10px;
  color: #fff;
  background: #173652;
  font-size: 0.68rem;
  font-weight: 800;
  cursor: pointer;
}

.data-health-toolbar button:disabled,
.data-health-summary button:disabled {
  opacity: 0.55;
  cursor: wait;
}

.data-health-checks {
  display: grid;
  gap: 0.75rem;
  margin-top: 1rem;
}

.data-health-check {
  padding: 1rem;
  border: 1px solid rgba(16, 38, 61, 0.1);
  border-left-width: 5px;
  border-radius: 14px;
  background: rgba(255, 255, 255, 0.62);
}

.data-health-check--healthy {
  border-left-color: #4e8b64;
}

.data-health-check--warning {
  border-left-color: #c1842a;
}

.data-health-check--critical {
  border-left-color: #a93627;
}

.data-health-check > header {
  display: flex;
  justify-content: space-between;
  gap: 1rem;
  align-items: flex-start;
}

.data-health-check header span,
.data-health-check footer span {
  display: block;
  color: #71808a;
  font-size: 0.6rem;
  font-weight: 800;
  letter-spacing: 0.07em;
  text-transform: uppercase;
}

.data-health-check h3 {
  margin-top: 0.15rem;
  color: #173652;
  font-size: 1rem;
}

.data-health-check header > strong {
  color: #53616b;
  font-size: 0.72rem;
  white-space: nowrap;
}

.data-health-check > p,
.data-health-check > footer {
  margin-top: 0.5rem;
  color: #5d6972;
  font-size: 0.74rem;
}

.data-health-check ul {
  display: grid;
  gap: 0.25rem;
  margin: 0.6rem 0 0;
  padding: 0;
  list-style: none;
}

.data-health-check li code {
  color: #53616b;
  font-size: 0.67rem;
}

.data-health-check > footer {
  padding-top: 0.55rem;
  border-top: 1px solid rgba(16, 38, 61, 0.08);
  color: #173652;
}

.database-table th,
.database-table td {
  padding: 0.7rem 0.8rem;
  border-bottom: 1px solid rgba(16, 38, 61, 0.08);
  text-align: right;
  white-space: nowrap;
}

.database-table thead th {
  color: #64717b;
  background: rgba(16, 38, 61, 0.04);
  font-size: 0.62rem;
  letter-spacing: 0.06em;
  text-transform: uppercase;
}

.database-table th:first-child {
  width: 30%;
  min-width: 220px;
  text-align: left;
}

.database-table tbody th code {
  color: #173652;
  font-size: 0.72rem;
}

.database-table td {
  color: #53616b;
  font-family: 'SFMono-Regular', Menlo, monospace;
  font-size: 0.7rem;
}

.database-table td strong {
  color: #10263d;
}

.database-table tbody tr:last-child th,
.database-table tbody tr:last-child td {
  border-bottom: 0;
}

.database-table__bar {
  display: block;
  width: 100%;
  height: 3px;
  margin-top: 0.38rem;
  overflow: hidden;
  border-radius: 999px;
  background: rgba(16, 38, 61, 0.1);
}

.database-table__bar i {
  display: block;
  height: 100%;
  min-width: 2px;
  border-radius: inherit;
  background: linear-gradient(90deg, #a93627, #d09a55);
}

.database-insights > footer,
.database-insights__empty {
  margin-top: 0.75rem;
  color: #69747c;
  font-size: 0.68rem;
}

.database-footprint strong,
.data-health-summary strong {
  color: #10263d;
  font-family: 'Avenir Next Condensed', sans-serif;
  font-size: 1.55rem;
  line-height: 1.1;
}

.database-footprint small,
.data-health-summary small {
  font-size: 0.58rem;
  font-weight: 700;
}

.admin-hero__status {
  display: flex;
  flex: 0 0 auto;
  gap: 0.6rem;
  align-items: center;
  padding: 0.65rem 0.9rem;
  border-radius: 999px;
  color: #315943;
  background: #e5f0e7;
  font-size: 0.78rem;
  font-weight: 800;
  letter-spacing: 0.04em;
  text-transform: uppercase;
}

.admin-hero__status span {
  width: 8px;
  height: 8px;
  border-radius: 50%;
  background: #43815d;
}

.admin-hero__status--busy {
  color: #7a5019;
  background: #f5e7c8;
}

.admin-hero__status--busy span {
  background: #b77826;
  animation: admin-pulse 1s infinite alternate;
}

.admin-tabs {
  display: flex;
  gap: 0.45rem;
  margin-top: 1.4rem;
  padding: 0.45rem;
  overflow-x: auto;
  border: 1px solid rgba(16, 38, 61, 0.1);
  border-radius: 18px;
  background: rgba(255, 252, 245, 0.68);
  box-shadow: 0 10px 28px rgba(73, 52, 24, 0.06);
}

.admin-tabs__tab {
  flex: 1 0 auto;
  min-height: 46px;
  padding: 0.7rem 1.15rem;
  border: 1px solid transparent;
  border-radius: 13px;
  color: #53616b;
  background: transparent;
  font: inherit;
  font-size: 0.78rem;
  font-weight: 900;
  letter-spacing: 0.055em;
  text-transform: uppercase;
  white-space: nowrap;
  cursor: pointer;
}

.admin-tabs__tab:hover {
  color: #10263d;
  background: rgba(231, 237, 241, 0.7);
}

.admin-tabs__tab:focus-visible {
  outline: 3px solid rgba(143, 45, 36, 0.25);
  outline-offset: 2px;
}

.admin-tabs__tab--active {
  color: #fffaf0;
  border-color: #10263d;
  background: #10263d;
  box-shadow: 0 7px 18px rgba(16, 38, 61, 0.18);
}

.admin-tabs__tab--active:hover {
  color: #fffaf0;
  background: #8f2d24;
}

.admin-section {
  margin-top: 1.4rem;
  padding: 1.6rem;
  border: 1px solid rgba(16, 38, 61, 0.1);
  border-radius: 28px;
  background: rgba(255, 252, 245, 0.82);
  box-shadow: 0 16px 44px rgba(73, 52, 24, 0.07);
}

.admin-tab-panel {
  margin-top: 0.75rem;
}

.admin-section__heading {
  display: flex;
  justify-content: space-between;
  gap: 1.5rem;
  align-items: flex-end;
  margin-bottom: 1.25rem;
}

.admin-section__heading h2 {
  color: #10263d;
  font-family: 'Avenir Next Condensed', sans-serif;
  font-size: clamp(1.8rem, 3vw, 2.5rem);
  line-height: 1;
  text-transform: uppercase;
}

.admin-section__heading > p {
  max-width: 38rem;
  color: #53616b;
  text-align: right;
}

.admin-grid {
  display: grid;
  gap: 1rem;
}

.admin-grid--two {
  grid-template-columns: repeat(2, minmax(0, 1fr));
}

.admin-card,
.admin-imports > section {
  position: relative;
  min-width: 0;
  padding: 1.25rem;
  overflow: hidden;
  border: 1px solid rgba(16, 38, 61, 0.12);
  border-radius: 22px;
  background: rgba(255, 255, 255, 0.76);
}

.admin-card__number {
  position: absolute;
  right: 1rem;
  bottom: -1.3rem;
  color: rgba(16, 38, 61, 0.045);
  font-family: 'Avenir Next Condensed', sans-serif;
  font-size: 7.5rem;
  font-weight: 900;
  line-height: 1;
  pointer-events: none;
}

.admin-card__title {
  position: relative;
  display: flex;
  justify-content: space-between;
  gap: 1rem;
  align-items: flex-start;
}

.admin-card__title p {
  color: #8f2d24;
  font-size: 0.72rem;
  font-weight: 800;
  letter-spacing: 0.12em;
  text-transform: uppercase;
}

.admin-card__title h3,
.admin-result h3 {
  color: #10263d;
  font-family: 'Avenir Next Condensed', sans-serif;
  font-size: 1.45rem;
  line-height: 1.1;
}

.admin-card__title code,
.admin-chip {
  padding: 0.3rem 0.55rem;
  border-radius: 8px;
  color: #37506a;
  background: #e7edf1;
  font-size: 0.68rem;
  font-weight: 700;
  white-space: nowrap;
}

.data-coverage {
  margin-top: 1rem;
  padding: 0.8rem 0.9rem;
  border: 1px solid rgba(16, 38, 61, 0.1);
  border-radius: 14px;
  background: rgba(231, 237, 241, 0.7);
}

.data-coverage > span,
.data-coverage dt {
  color: #61707b;
  font-size: 0.66rem;
  font-weight: 800;
  letter-spacing: 0.06em;
  text-transform: uppercase;
}

.data-coverage dl {
  display: grid;
  gap: 0.75rem;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  margin-top: 0.45rem;
}

.data-coverage dd {
  color: #10263d;
  font-size: 0.98rem;
  font-weight: 850;
}

.data-coverage p,
.data-coverage small {
  display: block;
  margin-top: 0.35rem;
  color: #53616b;
  font-size: 0.78rem;
}

.data-coverage small {
  color: #6b7780;
}

.admin-fields {
  position: relative;
  display: grid;
  gap: 0.75rem;
  margin: 1.2rem 0;
}

.admin-fields--four {
  grid-template-columns: repeat(4, minmax(0, 1fr));
}

.admin-fields--three {
  grid-template-columns: repeat(3, minmax(0, 1fr));
}

.admin-fields label:not(.admin-check) {
  display: flex;
  flex-direction: column;
  gap: 0.35rem;
}

.admin-fields label > span {
  color: #465662;
  font-size: 0.72rem;
  font-weight: 800;
  letter-spacing: 0.04em;
  text-transform: uppercase;
}

.admin-fields input,
.admin-fields select {
  width: 100%;
  min-height: 42px;
  padding: 0.55rem 0.65rem;
  border: 1px solid rgba(16, 38, 61, 0.18);
  border-radius: 10px;
  color: #10263d;
  background: rgba(255, 255, 255, 0.94);
}

.admin-check {
  display: flex;
  gap: 0.5rem;
  align-items: center;
  align-self: end;
  min-height: 42px;
}

.admin-check input {
  width: 18px;
  min-height: auto;
  height: 18px;
}

.admin-field--wide {
  grid-column: span 2;
}

.admin-card__hint {
  margin: -0.45rem 0 1rem;
  color: #61707b;
  font-size: 0.78rem;
}

.admin-card__description {
  margin-top: 0.7rem;
  color: #61707b;
  font-size: 0.82rem;
  line-height: 1.45;
}

.admin-card__coverage {
  margin: 0.75rem 0 1rem;
  color: #33495d;
  font-size: 0.82rem;
}

.admin-button--secondary {
  color: #10263d;
  background: #dce6eb;
}

.admin-button {
  position: relative;
  padding: 0.66rem 0.95rem;
  border: 0;
  border-radius: 11px;
  color: #fff8ea;
  background: #10263d;
  font-weight: 800;
  cursor: pointer;
}

.admin-button:hover:not(:disabled) {
  background: #8f2d24;
}

.admin-button:disabled {
  cursor: wait;
  opacity: 0.55;
}

.admin-message {
  position: relative;
  margin-top: 0.75rem;
  font-size: 0.83rem;
}

.admin-message--success {
  color: #315943;
}

.admin-message--error {
  color: #992e26;
}

.admin-imports > section {
  margin: 0;
}

.admin-card--maintenance {
  display: flex;
  flex-direction: column;
  align-items: flex-start;
}

.admin-card--maintenance > p {
  flex: 1;
  margin: 1rem 0;
  color: #53616b;
}

.admin-result {
  display: grid;
  gap: 1.25rem;
  grid-template-columns: minmax(240px, 0.8fr) minmax(0, 1.2fr);
  margin-top: 1rem;
  padding: 1.25rem;
  border: 1px solid rgba(49, 89, 67, 0.18);
  border-radius: 20px;
  background: #edf4ed;
}

.admin-result small {
  color: #66736b;
}

.admin-result dl {
  display: grid;
  gap: 0.55rem;
  grid-template-columns: repeat(4, minmax(0, 1fr));
}

.admin-result dl div {
  padding: 0.65rem;
  border-radius: 10px;
  background: rgba(255, 255, 255, 0.68);
}

.admin-result dt {
  color: #68756d;
  font-size: 0.62rem;
  font-weight: 800;
  letter-spacing: 0.05em;
  text-transform: uppercase;
}

.admin-result dd {
  color: #244531;
  font-size: 1.08rem;
  font-weight: 900;
}

.admin-result--error {
  display: block;
  color: #8f2d24;
  border-color: rgba(143, 45, 36, 0.2);
  background: #f7e7e3;
}

@keyframes admin-pulse {
  to { opacity: 0.35; }
}

@media (max-width: 1000px) {
  .admin-grid--two,
  .admin-result {
    grid-template-columns: 1fr;
  }

  .admin-fields--four,
  .admin-fields--three {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }

  .database-summary-grid {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }

}

@media (max-width: 680px) {
  .admin-shell {
    padding: 1rem 0.7rem 3rem;
  }

  .admin-hero,
  .admin-section,
  .admin-tabs {
    width: 100%;
    border-radius: 20px;
  }

  .admin-tabs {
    padding: 0.35rem;
    border-radius: 15px;
  }

  .admin-tabs__tab {
    min-height: 42px;
    padding: 0.6rem 0.8rem;
    font-size: 0.7rem;
  }

  .admin-hero,
  .admin-section__heading {
    align-items: flex-start;
    flex-direction: column;
  }

  .admin-hero__aside {
    width: 100%;
    align-items: stretch;
  }

  .database-footprint,
  .data-health-summary {
    text-align: left;
  }

  .database-footprint button,
  .data-health-summary button {
    justify-self: start;
  }

  .database-insights__heading {
    align-items: flex-start;
    flex-direction: column;
  }

  .database-insights__heading-actions {
    width: 100%;
    justify-content: space-between;
  }

  .database-insights__heading-actions p {
    text-align: left;
  }

  .database-summary-grid {
    grid-template-columns: 1fr;
  }

  .admin-section__heading > p {
    text-align: left;
  }

  .admin-fields--four,
  .admin-fields--three,
  .admin-result dl {
    grid-template-columns: 1fr;
  }

  .admin-field--wide {
    grid-column: auto;
  }

  .admin-card__title {
    flex-direction: column;
  }
}
</style>
