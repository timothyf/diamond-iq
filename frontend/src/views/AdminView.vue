<script setup>
import { computed, nextTick, onMounted, reactive, ref } from 'vue'

import CsvImportPicker from '../components/CsvImportPicker.vue'
import { useAdminTask } from '../composables/useAdminTask'
import { usePitchDataDownload } from '../composables/usePitchDataDownload'
import { usePitchDataImport } from '../composables/usePitchDataImport'
import { usePlayerSeasonStatsDownload } from '../composables/usePlayerSeasonStatsDownload'
import { usePlayerSeasonStatsImport } from '../composables/usePlayerSeasonStatsImport'
import { useRosterSnapshots } from '../composables/useRosterSnapshots'

const today = new Date().toISOString().slice(0, 10)
const currentSeason = new Date().getFullYear()
const databaseDetailsOpen = ref(false)
const databaseDetailsDialog = ref(null)
const databaseDetailsButton = ref(null)
const gameDetailsConfirmationOpen = ref(false)
const gameDetailsConfirmationDialog = ref(null)
const gameDetailsSyncButton = ref(null)
const pendingGameDetailsParameters = ref(null)

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

const rosterOptions = reactive({
  teamScope: 'team',
  teamMlbId: '',
  season: currentSeason,
})

const rosterSnapshotOptions = reactive({
  teamMlbId: '',
  snapshotOn: today,
})

const {
  runningTask,
  error: taskError,
  lastResult,
  overviewLoading,
  overviewError,
  scheduleImportRange,
  scheduleDateRange,
  mlbTeams,
  databaseMetrics,
  playerSeasonStatsMetrics,
  pitchDataMetrics,
  gameDetailsMetrics,
  loadOverview,
  runTask,
} = useAdminTask()
const {
  downloading: statsDownloading,
  error: statsDownloadError,
  summary: statsDownloadSummary,
  downloadStats,
} = usePlayerSeasonStatsDownload()
const {
  downloading: pitchDownloading,
  error: pitchDownloadError,
  summary: pitchDownloadSummary,
  downloadPitchData,
} = usePitchDataDownload()
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
    statsDownloading.value ||
    pitchDownloading.value ||
    statsUploading.value ||
    pitchUploading.value ||
    rosterSnapshotsLoading.value,
)

const activeRosterSnapshot = computed(
  () => rosterSnapshots.value.find((snapshot) => snapshot.roster_type === 'active') || null,
)
const fortyManRosterSnapshot = computed(
  () => rosterSnapshots.value.find((snapshot) => snapshot.roster_type === '40Man') || null,
)

const resultEntries = computed(() => {
  const data = lastResult.value?.data || {}
  return Object.entries(data)
    .filter(([, value]) => value !== null && value !== undefined && !Array.isArray(value) && typeof value !== 'object')
    .slice(0, 8)
})

const hasStoredGames = computed(
  () => Boolean(scheduleDateRange.value.earliestGameDate && scheduleDateRange.value.latestGameDate),
)
const hasImportedSchedule = computed(
  () => Boolean(scheduleImportRange.value.earliestImportDate && scheduleImportRange.value.latestImportDate),
)

const gameDetailsEstimate = computed(() => {
  const parameters = pendingGameDetailsParameters.value
  if (!parameters) return null

  if (parameters.mlb_game_id) {
    return {
      scope: `MLB game ${parameters.mlb_game_id}`,
      estimatedGames: 1,
      duration: 'about 1 minute',
      assumption: 'A single stored game will be downloaded and its daily analytics will be refreshed.',
    }
  }

  const spanDays = inclusiveDayCount(parameters.start_date, parameters.end_date)
  const estimatedGames = spanDays * 15
  const lowMinutes = Math.max(1, Math.ceil((estimatedGames * 3) / 60))
  const highMinutes = Math.max(lowMinutes + 1, Math.ceil((estimatedGames * 6) / 60))
  return {
    scope: `${spanDays} calendar ${spanDays === 1 ? 'day' : 'days'} · ${formatDate(parameters.start_date)}–${formatDate(parameters.end_date)}`,
    estimatedGames,
    duration: `about ${formatDurationRange(lowMinutes, highMinutes)}`,
    assumption: 'Estimate assumes approximately 15 stored MLB games per day and 3–6 seconds per game.',
  }
})

onMounted(loadOverview)

function normalizeYearRange(options) {
  if (Number(options.startYear) > Number(options.endYear)) options.endYear = options.startYear
}

function normalizeDateRange(options) {
  if (options.startDate && options.endDate && options.startDate > options.endDate) options.endDate = options.startDate
}

async function handleStatsDownload() {
  normalizeYearRange(statsOptions)
  const result = await downloadStats(statsOptions)
  if (result) await loadOverview()
}

async function handlePitchDownload() {
  normalizeDateRange(pitchOptions)
  const result = await downloadPitchData(pitchOptions)
  if (result) await loadOverview()
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
  pendingGameDetailsParameters.value = {
    start_date: gameDetailsOptions.mlbGameId ? null : gameDetailsOptions.startDate,
    end_date: gameDetailsOptions.mlbGameId ? null : gameDetailsOptions.endDate,
    mlb_game_id: gameDetailsOptions.mlbGameId || null,
  }
  gameDetailsConfirmationOpen.value = true
  await nextTick()
  gameDetailsConfirmationDialog.value?.focus()
}

async function cancelGameDetailsSync() {
  gameDetailsConfirmationOpen.value = false
  pendingGameDetailsParameters.value = null
  await nextTick()
  gameDetailsSyncButton.value?.focus()
}

async function confirmGameDetailsSync() {
  const parameters = pendingGameDetailsParameters.value
  if (!parameters) return

  gameDetailsConfirmationOpen.value = false
  pendingGameDetailsParameters.value = null
  const result = await runTask('mlb_game_details_sync', parameters)
  if (result) await loadOverview()
}

async function handleProfileSync() {
  await runTask('mlb_player_profiles_sync', {
    only_missing: profileOptions.onlyMissing,
    batch_size: profileOptions.batchSize,
    limit: profileOptions.limit || null,
    mlb_ids: profileOptions.mlbIds || null,
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

async function openDatabaseDetails() {
  databaseDetailsOpen.value = true
  await nextTick()
  databaseDetailsDialog.value?.focus()
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
        <div class="admin-hero__status" :class="{ 'admin-hero__status--busy': anyActionRunning }">
          <span aria-hidden="true"></span>
          {{ anyActionRunning ? 'Data operation in progress' : 'Admin tools ready' }}
        </div>
      </div>
    </section>

    <div
      v-if="databaseDetailsOpen"
      class="database-modal"
      data-test="database-details-modal"
      @click.self="closeDatabaseDetails"
      @keydown.esc="closeDatabaseDetails"
    >
      <section
        ref="databaseDetailsDialog"
        class="database-insights"
        data-test="database-details"
        role="dialog"
        aria-modal="true"
        aria-labelledby="database-details-title"
        tabindex="-1"
      >
      <header class="database-insights__heading">
        <div>
          <p class="eyebrow">Storage health</p>
          <h2 id="database-details-title">Database footprint</h2>
        </div>
        <div class="database-insights__heading-actions">
          <p>
            {{ databaseMetrics.databaseName || 'Current database' }}
            <span v-if="databaseMetrics.serverVersion">· PostgreSQL {{ databaseMetrics.serverVersion }}</span>
            <span v-if="databaseMetrics.measuredAt">· Measured {{ formatTimestamp(databaseMetrics.measuredAt) }}</span>
          </p>
          <button type="button" data-test="database-details-close" aria-label="Close database details" @click="closeDatabaseDetails">×</button>
        </div>
      </header>

      <div class="database-summary-grid">
        <article>
          <span>Total database</span>
          <strong>{{ overviewLoading ? 'Measuring…' : formatBytes(databaseMetrics.sizeBytes) }}</strong>
          <small>Entire PostgreSQL database</small>
        </article>
        <article>
          <span>Application tables</span>
          <strong>{{ formatBytes(databaseMetrics.userTableSizeBytes) }}</strong>
          <small>Table data, TOAST, and indexes</small>
        </article>
        <article>
          <span>Tables</span>
          <strong>{{ formatCount(databaseMetrics.tableCount) }}</strong>
          <small>DiamondIQ application tables</small>
        </article>
        <article>
          <span>Estimated rows</span>
          <strong>{{ formatCount(databaseMetrics.estimatedRowCount) }}</strong>
          <small>{{ formatCount(databaseMetrics.estimatedDeadRowCount) }} dead rows awaiting cleanup</small>
        </article>
      </div>

      <div v-if="databaseMetrics.largestTables.length" class="database-table-wrap">
        <table class="database-table">
          <thead>
            <tr>
              <th>Largest tables</th>
              <th>Est. rows</th>
              <th>Dead rows</th>
              <th>Data</th>
              <th>Indexes</th>
              <th>Total</th>
              <th>% of DB</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="table in databaseMetrics.largestTables" :key="table.tableName">
              <th>
                <code>{{ table.tableName }}</code>
                <span class="database-table__bar" aria-hidden="true">
                  <i :style="{ width: `${Math.min(table.databasePercentage, 100)}%` }"></i>
                </span>
              </th>
              <td>{{ formatCount(table.estimatedRowCount) }}</td>
              <td>{{ formatCount(table.estimatedDeadRowCount) }}</td>
              <td>{{ formatBytes(table.dataSizeBytes) }}</td>
              <td>{{ formatBytes(table.indexSizeBytes) }}</td>
              <td><strong>{{ formatBytes(table.totalSizeBytes) }}</strong></td>
              <td>{{ table.databasePercentage.toFixed(2) }}%</td>
            </tr>
          </tbody>
        </table>
      </div>
      <p v-else class="database-insights__empty">
        Per-table storage metrics are available when DiamondIQ uses PostgreSQL.
      </p>
      <footer>
        Row counts come from PostgreSQL statistics and are approximate. Run <code>ANALYZE</code> to refresh estimates after a large import.
      </footer>
      </section>
    </div>

    <div
      v-if="gameDetailsConfirmationOpen"
      class="confirmation-modal"
      data-test="game-details-confirmation-modal"
      @click.self="cancelGameDetailsSync"
      @keydown.esc="cancelGameDetailsSync"
    >
      <section
        ref="gameDetailsConfirmationDialog"
        class="confirmation-dialog"
        data-test="game-details-confirmation"
        role="dialog"
        aria-modal="true"
        aria-labelledby="game-details-confirmation-title"
        aria-describedby="game-details-confirmation-description"
        tabindex="-1"
      >
        <div class="confirmation-dialog__icon" aria-hidden="true">!</div>
        <p class="eyebrow">Before you continue</p>
        <h2 id="game-details-confirmation-title">Game detail synchronization may take a while</h2>
        <p id="game-details-confirmation-description">
          DiamondIQ will process <strong>{{ gameDetailsEstimate.scope }}</strong>. Based on this selection, the operation should take
          <strong>{{ gameDetailsEstimate.duration }}</strong>.
        </p>
        <dl>
          <div>
            <dt>Estimated workload</dt>
            <dd>
              {{ gameDetailsEstimate.estimatedGames === 1
                ? '1 game'
                : `up to approximately ${formatCount(gameDetailsEstimate.estimatedGames)} games` }}
            </dd>
          </div>
          <div>
            <dt>How this estimate works</dt>
            <dd>{{ gameDetailsEstimate.assumption }}</dd>
          </div>
        </dl>
        <p class="confirmation-dialog__note">
          MLB response times and local analytics work can make the actual duration shorter or longer. Keep the Rails server running until the task finishes.
        </p>
        <div class="confirmation-dialog__actions">
          <button type="button" class="admin-button admin-button--secondary" data-test="game-details-cancel" @click="cancelGameDetailsSync">
            Cancel
          </button>
          <button type="button" class="admin-button" data-test="game-details-continue" @click="confirmGameDetailsSync">
            Continue synchronization
          </button>
        </div>
      </section>
    </div>

    <section class="admin-section">
      <header class="admin-section__heading">
        <div>
          <p class="eyebrow">Source retrieval</p>
          <h2>Download & import</h2>
        </div>
        <p>Fetch fresh source data and immediately upsert it into DiamondIQ.</p>
      </header>

      <div class="admin-grid admin-grid--two">
        <form class="admin-card" data-test="stats-download-form" @submit.prevent="handleStatsDownload">
          <div class="admin-card__number">01</div>
          <div class="admin-card__title">
            <div>
              <p>MLB Stats API</p>
              <h3>Player season statistics</h3>
            </div>
            <span class="admin-chip">Download + import</span>
          </div>
          <p class="admin-card__description">
            Downloads and imports season-level batting or pitching statistics for the selected year range.
          </p>
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
        </form>

        <form class="admin-card" data-test="pitch-download-form" @submit.prevent="handlePitchDownload">
          <div class="admin-card__number">02</div>
          <div class="admin-card__title">
            <div>
              <p>Baseball Savant</p>
              <h3>Statcast pitch data</h3>
            </div>
            <span class="admin-chip">Download + import</span>
          </div>
          <p class="admin-card__description">
            Downloads pitch-by-pitch Statcast data from Baseball Savant for the selected games and date range.
          </p>
          <div class="data-coverage" data-test="pitch-data-coverage">
            <span>Currently stored</span>
            <dl v-if="pitchDataMetrics.earliestGameDate && pitchDataMetrics.latestGameDate">
              <div>
                <dt>Earliest game</dt>
                <dd>{{ formatDate(pitchDataMetrics.earliestGameDate) }}</dd>
              </div>
              <div>
                <dt>Latest game</dt>
                <dd>{{ formatDate(pitchDataMetrics.latestGameDate) }}</dd>
              </div>
            </dl>
            <p v-else>No Statcast pitch data is currently stored.</p>
            <small>Approximately {{ formatCount(pitchDataMetrics.approximateRowCount) }} pitch rows</small>
          </div>
          <div class="admin-fields admin-fields--four">
            <label>
              <span>Start date</span>
              <input v-model="pitchOptions.startDate" type="date" required />
            </label>
            <label>
              <span>End date</span>
              <input v-model="pitchOptions.endDate" type="date" required />
            </label>
            <label>
              <span>Game types</span>
              <input v-model="pitchOptions.gameTypes" type="text" placeholder="R" required />
            </label>
            <label>
              <span>Chunk days</span>
              <input v-model.number="pitchOptions.chunkDays" type="number" min="1" max="31" required />
            </label>
          </div>
          <button class="admin-button" type="submit" :disabled="anyActionRunning">
            {{ pitchDownloading ? 'Downloading pitches…' : 'Retrieve Statcast pitches' }}
          </button>
          <p v-if="pitchDownloadError" class="admin-message admin-message--error">{{ pitchDownloadError }}</p>
          <p v-else-if="pitchDownloadSummary" class="admin-message admin-message--success">{{ pitchDownloadSummary }}</p>
        </form>
      </div>
    </section>

    <section class="admin-section">
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

    <section class="admin-section">
      <header class="admin-section__heading">
        <div>
          <p class="eyebrow">MLB synchronization</p>
          <h2>Operational tasks</h2>
        </div>
        <p>These actions use the same services as their corresponding Rails tasks.</p>
      </header>

      <div class="admin-grid admin-grid--two">
        <form class="admin-card" data-test="schedule-sync-form" @submit.prevent="handleScheduleSync">
          <div class="admin-card__title">
            <div>
              <p>Games & schedules</p>
              <h3>MLB schedule synchronization</h3>
            </div>
            <code>mlb_schedule:sync</code>
          </div>
          <p class="admin-card__description">
            Downloads MLB schedules and updates games, teams, venues, statuses, and probable pitchers for the selected dates.
          </p>
          <div class="schedule-coverage" data-test="schedule-date-range">
            <p v-if="overviewLoading">Loading stored dates…</p>
            <p v-else-if="overviewError" class="schedule-coverage__error">{{ overviewError }}</p>
            <div v-else class="schedule-coverage__ranges">
              <section class="schedule-coverage__range">
                <span>Imported schedule coverage</span>
                <dl v-if="hasImportedSchedule">
                  <div>
                    <dt>From</dt>
                    <dd>{{ formatDate(scheduleImportRange.earliestImportDate) }}</dd>
                  </div>
                  <div>
                    <dt>Through</dt>
                    <dd>{{ formatDate(scheduleImportRange.latestImportDate) }}</dd>
                  </div>
                </dl>
                <p v-else>No schedule windows have been imported.</p>
              </section>
              <section class="schedule-coverage__range">
                <span>Stored game-date span</span>
                <dl v-if="hasStoredGames">
                  <div>
                    <dt>Earliest game</dt>
                    <dd>{{ formatDate(scheduleDateRange.earliestGameDate) }}</dd>
                  </div>
                  <div>
                    <dt>Latest game</dt>
                    <dd>{{ formatDate(scheduleDateRange.latestGameDate) }}</dd>
                  </div>
                </dl>
                <p v-else>No games are currently stored.</p>
              </section>
            </div>
          </div>
          <div class="admin-fields admin-fields--four">
            <label><span>Start date</span><input v-model="scheduleOptions.startDate" type="date" required /></label>
            <label><span>End date</span><input v-model="scheduleOptions.endDate" type="date" required /></label>
            <label><span>Game types</span><input v-model="scheduleOptions.gameTypes" type="text" required /></label>
            <label><span>Sport ID</span><input v-model.number="scheduleOptions.sportId" type="number" min="1" required /></label>
          </div>
          <button class="admin-button" type="submit" :disabled="anyActionRunning">
            {{ runningTask === 'mlb_schedule_sync' ? 'Synchronizing schedule…' : 'Synchronize schedule' }}
          </button>
        </form>

        <form class="admin-card" data-test="game-details-sync-form" @submit.prevent="requestGameDetailsSync">
          <div class="admin-card__title">
            <div>
              <p>Box scores & live feeds</p>
              <h3>MLB game detail synchronization</h3>
            </div>
            <code>mlb_game_details:sync</code>
          </div>
          <p class="admin-card__description">
            Downloads player game lines, batting orders, substitutions, plate appearances, and links matching Statcast pitches.
          </p>
          <div class="data-coverage" data-test="game-details-coverage">
            <span>Currently stored</span>
            <dl v-if="gameDetailsMetrics.synchronizedGameCount">
              <div>
                <dt>Games synchronized</dt>
                <dd>{{ formatCount(gameDetailsMetrics.synchronizedGameCount) }}</dd>
              </div>
              <div>
                <dt>Game-date span</dt>
                <dd>{{ formatDate(gameDetailsMetrics.earliestGameDate) }}–{{ formatDate(gameDetailsMetrics.latestGameDate) }}</dd>
              </div>
            </dl>
            <p v-else>No game box scores or live feeds have been synchronized.</p>
            <small>
              {{ formatCount(gameDetailsMetrics.plateAppearanceCount) }} plate appearances ·
              {{ formatCount(gameDetailsMetrics.linkedPitchCount) }} linked pitches
            </small>
          </div>
          <div class="admin-fields admin-fields--three">
            <label><span>Start date</span><input v-model="gameDetailsOptions.startDate" type="date" :disabled="Boolean(gameDetailsOptions.mlbGameId)" /></label>
            <label><span>End date</span><input v-model="gameDetailsOptions.endDate" type="date" :disabled="Boolean(gameDetailsOptions.mlbGameId)" /></label>
            <label><span>MLB game ID (optional)</span><input v-model="gameDetailsOptions.mlbGameId" type="number" min="1" placeholder="823443" /></label>
          </div>
          <button ref="gameDetailsSyncButton" class="admin-button" type="submit" :disabled="anyActionRunning">
            {{ runningTask === 'mlb_game_details_sync' ? 'Synchronizing game details…' : 'Synchronize game details' }}
          </button>
        </form>

        <form class="admin-card" data-test="profile-sync-form" @submit.prevent="handleProfileSync">
          <div class="admin-card__title">
            <div>
              <p>Player identity</p>
              <h3>MLB profile synchronization</h3>
            </div>
            <code>mlb_player_profiles:sync</code>
          </div>
          <p class="admin-card__description">
            Downloads MLB biographical, handedness, position, and headshot information for players already stored in DiamondIQ.
          </p>
          <div class="admin-fields admin-fields--four">
            <label><span>Batch size</span><input v-model.number="profileOptions.batchSize" type="number" min="1" max="100" required /></label>
            <label><span>Limit (optional)</span><input v-model="profileOptions.limit" type="number" min="1" /></label>
            <label class="admin-field--wide"><span>MLB IDs (optional)</span><input v-model="profileOptions.mlbIds" type="text" placeholder="700270, 669360" /></label>
            <label class="admin-check"><input v-model="profileOptions.onlyMissing" type="checkbox" /><span>Only missing</span></label>
          </div>
          <button class="admin-button" type="submit" :disabled="anyActionRunning">
            {{ runningTask === 'mlb_player_profiles_sync' ? 'Synchronizing profiles…' : 'Synchronize player profiles' }}
          </button>
        </form>

        <form class="admin-card" data-test="roster-sync-form" @submit.prevent="handleRosterSync">
          <div class="admin-card__title">
            <div>
              <p>Current roster state</p>
              <h3>MLB 40-man roster synchronization</h3>
            </div>
            <code>mlb_roster:sync</code>
          </div>
          <p class="admin-card__description">
            Downloads MLB 40-man rosters and updates player profiles, roster status, and dated team memberships for the selected season.
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
            Synchronizes MLB's 40-man roster only. Completed seasons use December 31; the current season uses today.
            Historical roster construction will be handled as a separate transaction-based workflow.
          </p>
          <button class="admin-button" type="submit" :disabled="anyActionRunning">
            {{ runningTask === 'mlb_roster_sync' ? 'Synchronizing roster…' : 'Synchronize team roster' }}
          </button>
        </form>

        <article class="admin-card admin-card--maintenance">
          <div class="admin-card__title">
            <div>
              <p>Data maintenance</p>
              <h3>Rebuild current player positions</h3>
            </div>
            <code>player_positions:backfill</code>
          </div>
          <p>Reconcile current position assignments from the latest active team membership for every player.</p>
          <button
            class="admin-button"
            type="button"
            :disabled="anyActionRunning"
            @click="runTask('player_positions_backfill')"
          >
            {{ runningTask === 'player_positions_backfill' ? 'Rebuilding positions…' : 'Rebuild player positions' }}
          </button>
        </article>
      </div>

      <section class="roster-snapshot-workspace" data-test="roster-snapshot-workspace">
        <div class="admin-card__title">
          <div>
            <p>Dated reference data</p>
            <h3>Active and 40-man roster snapshots</h3>
          </div>
          <span class="admin-chip">Independent snapshots</span>
        </div>
        <p class="admin-card__hint">
          Retrieve both MLB roster views for an exact date without changing historical team memberships.
        </p>
        <form class="roster-snapshot-controls" data-test="roster-snapshot-form" @submit.prevent="handleRosterSnapshotSync">
          <label>
            <span>MLB team</span>
            <select v-model="rosterSnapshotOptions.teamMlbId" data-test="snapshot-team" required>
              <option value="" disabled>Select a team</option>
              <option v-for="team in mlbTeams" :key="team.mlbId" :value="String(team.mlbId)">
                {{ team.abbreviation }} · {{ team.name }}
              </option>
            </select>
          </label>
          <label>
            <span>Snapshot date</span>
            <input v-model="rosterSnapshotOptions.snapshotOn" type="date" :max="today" required />
          </label>
          <button class="admin-button" type="submit" :disabled="anyActionRunning || !rosterSnapshotOptions.teamMlbId || !rosterSnapshotOptions.snapshotOn">
            {{ runningTask === 'mlb_roster_snapshots_sync' ? 'Retrieving snapshots…' : 'Retrieve and store snapshots' }}
          </button>
          <button class="admin-button admin-button--secondary" type="button" :disabled="anyActionRunning || !rosterSnapshotOptions.teamMlbId || !rosterSnapshotOptions.snapshotOn" @click="handleRosterSnapshotLoad">
            {{ rosterSnapshotsLoading ? 'Loading snapshots…' : 'View stored snapshots' }}
          </button>
        </form>

        <p v-if="rosterSnapshotsError" class="admin-message admin-message--error" role="alert">{{ rosterSnapshotsError }}</p>
        <p v-else-if="!rosterSnapshotsLoading && !rosterSnapshots.length" class="roster-snapshot-empty">
          Select a team and date to retrieve new snapshots or view snapshots already stored.
        </p>
        <div v-else class="roster-snapshot-grid">
          <article v-for="snapshot in [activeRosterSnapshot, fortyManRosterSnapshot]" :key="snapshot?.roster_type || 'missing'" class="roster-snapshot-panel">
            <template v-if="snapshot">
              <header>
                <div>
                  <span>{{ snapshot.roster_type === 'active' ? 'Active roster' : '40-man roster' }}</span>
                  <small>{{ formatDate(snapshot.snapshot_on) }}</small>
                </div>
                <strong>{{ snapshot.players.length }} players</strong>
              </header>
              <div class="roster-snapshot-table-wrap">
                <table>
                  <thead><tr><th>#</th><th>Player</th><th>Pos</th><th>Status</th></tr></thead>
                  <tbody>
                    <tr v-for="player in snapshot.players" :key="player.mlb_id">
                      <td>{{ player.jersey_number || '—' }}</td>
                      <td>
                        <RouterLink v-if="player.player_id" :to="{ name: 'player-profile', params: { id: player.player_id } }">
                          {{ player.full_name }}
                        </RouterLink>
                        <span v-else>{{ player.full_name }}</span>
                      </td>
                      <td>{{ player.position_code || '—' }}</td>
                      <td>{{ player.status_description || 'Unknown' }}</td>
                    </tr>
                  </tbody>
                </table>
              </div>
              <footer>Synced {{ formatTimestamp(snapshot.last_synced_at) }} · {{ snapshot.source_name }}</footer>
            </template>
            <p v-else>No snapshot is stored for this roster view.</p>
          </article>
        </div>
      </section>

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

<style scoped>
.admin-shell {
  min-height: 100vh;
  padding: 2.5rem 1.25rem 5rem;
  background:
    radial-gradient(circle at 10% 0%, rgba(143, 45, 36, 0.14), transparent 28%),
    radial-gradient(circle at 92% 16%, rgba(37, 90, 131, 0.16), transparent 30%),
    linear-gradient(180deg, #f7f1e3 0%, #ecdfc5 100%);
}

.admin-hero,
.admin-section {
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

.database-footprint {
  display: grid;
  min-width: 190px;
  padding: 0.8rem 0.95rem;
  border: 1px solid rgba(16, 38, 61, 0.12);
  border-radius: 16px;
  background: rgba(231, 237, 241, 0.78);
  text-align: right;
}

.database-footprint span,
.database-footprint small {
  color: #61707b;
  font-size: 0.65rem;
  font-weight: 800;
  letter-spacing: 0.06em;
  text-transform: uppercase;
}

.database-footprint button {
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
.database-footprint button:focus-visible {
  color: #10263d;
}

.database-modal,
.confirmation-modal {
  position: fixed;
  z-index: 100;
  inset: 0;
  display: grid;
  place-items: center;
  padding: 1rem;
  background: rgba(8, 22, 35, 0.7);
  backdrop-filter: blur(5px);
}

.confirmation-dialog {
  width: min(620px, calc(100vw - 2rem));
  padding: clamp(1.35rem, 4vw, 2rem);
  outline: none;
  border: 1px solid rgba(143, 45, 36, 0.2);
  border-radius: 24px;
  background: #fffaf0;
  box-shadow: 0 24px 70px rgba(8, 22, 35, 0.28);
}

.confirmation-dialog__icon {
  display: grid;
  width: 46px;
  height: 46px;
  margin-bottom: 1rem;
  place-items: center;
  border-radius: 50%;
  color: #fffaf0;
  background: #8f2d24;
  font-family: 'Avenir Next Condensed', sans-serif;
  font-size: 1.7rem;
  font-weight: 900;
}

.confirmation-dialog h2 {
  margin-top: 0.25rem;
  color: #10263d;
  font-family: 'Avenir Next Condensed', sans-serif;
  font-size: clamp(1.7rem, 5vw, 2.4rem);
  line-height: 1;
  text-transform: uppercase;
}

.confirmation-dialog > p:not(.eyebrow) {
  margin-top: 0.85rem;
  color: #53616b;
  line-height: 1.55;
}

.confirmation-dialog > p strong {
  color: #10263d;
}

.confirmation-dialog dl {
  display: grid;
  gap: 0.65rem;
  margin-top: 1rem;
}

.confirmation-dialog dl div {
  padding: 0.75rem 0.85rem;
  border-radius: 12px;
  background: rgba(143, 45, 36, 0.055);
}

.confirmation-dialog dt {
  color: #8f2d24;
  font-size: 0.65rem;
  font-weight: 900;
  letter-spacing: 0.07em;
  text-transform: uppercase;
}

.confirmation-dialog dd {
  margin-top: 0.2rem;
  color: #263e52;
  font-size: 0.84rem;
}

.confirmation-dialog .confirmation-dialog__note {
  font-size: 0.78rem;
}

.confirmation-dialog__actions {
  display: flex;
  justify-content: flex-end;
  gap: 0.65rem;
  margin-top: 1.25rem;
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

.database-footprint strong {
  color: #10263d;
  font-family: 'Avenir Next Condensed', sans-serif;
  font-size: 1.55rem;
  line-height: 1.1;
}

.database-footprint small {
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

.admin-section {
  margin-top: 1.4rem;
  padding: 1.6rem;
  border: 1px solid rgba(16, 38, 61, 0.1);
  border-radius: 28px;
  background: rgba(255, 252, 245, 0.82);
  box-shadow: 0 16px 44px rgba(73, 52, 24, 0.07);
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
.admin-imports > :deep(section) {
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

.schedule-coverage {
  margin-top: 1rem;
  padding: 0.8rem 0.9rem;
  border: 1px solid rgba(16, 38, 61, 0.1);
  border-radius: 14px;
  background: rgba(231, 237, 241, 0.7);
}

.schedule-coverage__ranges {
  display: grid;
  gap: 0.9rem;
  grid-template-columns: repeat(2, minmax(0, 1fr));
}

.schedule-coverage__range {
  min-width: 0;
}

.schedule-coverage__range + .schedule-coverage__range {
  padding-left: 0.9rem;
  border-left: 1px solid rgba(16, 38, 61, 0.1);
}

.schedule-coverage__range > span,
.schedule-coverage dt {
  color: #61707b;
  font-size: 0.66rem;
  font-weight: 800;
  letter-spacing: 0.06em;
  text-transform: uppercase;
}

.schedule-coverage > p,
.schedule-coverage__range > p {
  margin-top: 0.35rem;
  color: #53616b;
  font-size: 0.84rem;
}

.schedule-coverage dl {
  display: grid;
  gap: 0.75rem;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  margin-top: 0.45rem;
}

.schedule-coverage dl div {
  min-width: 0;
}

.schedule-coverage dd {
  color: #10263d;
  font-size: 0.98rem;
  font-weight: 850;
}

.schedule-coverage .schedule-coverage__error {
  color: #992e26;
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

.roster-snapshot-workspace {
  margin-top: 1.25rem;
  padding: 1.35rem;
  border: 1px solid rgba(16, 38, 61, 0.12);
  border-radius: 20px;
  background: rgba(255, 252, 244, 0.86);
}

.roster-snapshot-workspace > .admin-card__hint {
  margin: 0.6rem 0 1rem;
}

.roster-snapshot-controls {
  display: grid;
  gap: 0.75rem;
  grid-template-columns: minmax(220px, 1.4fr) minmax(170px, 0.8fr) auto auto;
  align-items: end;
}

.roster-snapshot-controls label {
  display: flex;
  flex-direction: column;
  gap: 0.35rem;
}

.roster-snapshot-controls label > span {
  color: #465662;
  font-size: 0.72rem;
  font-weight: 800;
  letter-spacing: 0.04em;
  text-transform: uppercase;
}

.roster-snapshot-controls input,
.roster-snapshot-controls select {
  width: 100%;
  min-height: 42px;
  color: #8f2d24;
  border-color: rgba(143, 45, 36, 0.2);
  background: #f7e7e3;
}

.admin-button--secondary {
  color: #10263d;
  background: #dce6eb;
}

.roster-snapshot-empty {
  margin-top: 1rem;
  padding: 1rem;
  border-radius: 12px;
  color: #61707b;
  background: rgba(231, 237, 241, 0.7);
}

.roster-snapshot-grid {
  display: grid;
  gap: 1rem;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  margin-top: 1.25rem;
}

.roster-snapshot-panel {
  min-width: 0;
  overflow: hidden;
  border: 1px solid rgba(16, 38, 61, 0.12);
  border-radius: 16px;
  background: #fffdf7;
}

.roster-snapshot-panel > header {
  display: flex;
  justify-content: space-between;
  gap: 1rem;
  align-items: center;
  padding: 0.85rem 1rem;
  color: #10263d;
  background: #e7edf1;
}

.roster-snapshot-panel > header div {
  display: flex;
  flex-direction: column;
}

.roster-snapshot-panel > header span {
  font-weight: 900;
}

.roster-snapshot-panel > header small,
.roster-snapshot-panel > footer {
  color: #61707b;
  font-size: 0.72rem;
}

.roster-snapshot-table-wrap {
  max-height: 430px;
  overflow: auto;
}

.roster-snapshot-panel table {
  width: 100%;
  border-collapse: collapse;
  font-size: 0.82rem;
}

.roster-snapshot-panel th,
.roster-snapshot-panel td {
  padding: 0.62rem 0.7rem;
  border-bottom: 1px solid rgba(16, 38, 61, 0.08);
  text-align: left;
}

.roster-snapshot-panel th {
  position: sticky;
  top: 0;
  color: #61707b;
  background: #fffdf7;
  font-size: 0.66rem;
  letter-spacing: 0.05em;
  text-transform: uppercase;
}

.roster-snapshot-panel a {
  color: #8f2d24;
  font-weight: 800;
}

.roster-snapshot-panel > footer,
.roster-snapshot-panel > p {
  padding: 0.75rem 1rem;
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

.admin-imports > :deep(section) {
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

  .roster-snapshot-controls {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }
}

@media (max-width: 680px) {
  .admin-shell {
    padding: 1rem 0.7rem 3rem;
  }

  .admin-hero,
  .admin-section {
    width: 100%;
    border-radius: 20px;
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

  .database-footprint {
    text-align: left;
  }

  .database-footprint button {
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

  .roster-snapshot-controls,
  .roster-snapshot-grid {
    grid-template-columns: 1fr;
  }

  .admin-field--wide {
    grid-column: auto;
  }

  .schedule-coverage__ranges {
    grid-template-columns: 1fr;
  }

  .schedule-coverage__range + .schedule-coverage__range {
    padding-top: 0.9rem;
    padding-left: 0;
    border-top: 1px solid rgba(16, 38, 61, 0.1);
    border-left: 0;
  }

  .admin-card__title {
    flex-direction: column;
  }
}
</style>
