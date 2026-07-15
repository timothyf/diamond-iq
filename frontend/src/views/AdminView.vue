<script setup>
import { computed, onMounted, reactive } from 'vue'

import CsvImportPicker from '../components/CsvImportPicker.vue'
import { useAdminTask } from '../composables/useAdminTask'
import { usePitchDataDownload } from '../composables/usePitchDataDownload'
import { usePitchDataImport } from '../composables/usePitchDataImport'
import { usePlayerSeasonStatsDownload } from '../composables/usePlayerSeasonStatsDownload'
import { usePlayerSeasonStatsImport } from '../composables/usePlayerSeasonStatsImport'

const today = new Date().toISOString().slice(0, 10)
const currentSeason = new Date().getFullYear()

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
  rosterType: '40Man',
  asOf: today,
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
    pitchUploading.value,
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

onMounted(loadOverview)

function normalizeYearRange(options) {
  if (Number(options.startYear) > Number(options.endYear)) options.endYear = options.startYear
}

function normalizeDateRange(options) {
  if (options.startDate && options.endDate && options.startDate > options.endDate) options.endDate = options.startDate
}

async function handleStatsDownload() {
  normalizeYearRange(statsOptions)
  await downloadStats(statsOptions)
}

async function handlePitchDownload() {
  normalizeDateRange(pitchOptions)
  await downloadPitchData(pitchOptions)
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
    roster_type: rosterOptions.rosterType,
    as_of: rosterOptions.asOf,
  })
}

async function handleStatsImport({ file, replaceSeason }) {
  await importStatsFile(file, { replaceSeason })
}

async function handlePitchImport({ file }) {
  await importPitchFile(file)
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
        </div>
        <div class="admin-hero__status" :class="{ 'admin-hero__status--busy': anyActionRunning }">
          <span aria-hidden="true"></span>
          {{ anyActionRunning ? 'Data operation in progress' : 'Admin tools ready' }}
        </div>
      </div>
    </section>

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

        <form class="admin-card" data-test="profile-sync-form" @submit.prevent="handleProfileSync">
          <div class="admin-card__title">
            <div>
              <p>Player identity</p>
              <h3>MLB profile synchronization</h3>
            </div>
            <code>mlb_player_profiles:sync</code>
          </div>
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
              <p>Membership history</p>
              <h3>MLB team roster synchronization</h3>
            </div>
            <code>mlb_roster:sync</code>
          </div>
          <div class="admin-fields admin-fields--four">
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
            <label><span>Season</span><input v-model.number="rosterOptions.season" type="number" min="1876" required /></label>
            <label>
              <span>Roster type</span>
              <select v-model="rosterOptions.rosterType">
                <option value="40Man">40-man</option>
                <option value="active">Active</option>
                <option value="fullSeason">Full season</option>
              </select>
            </label>
            <label><span>As of</span><input v-model="rosterOptions.asOf" type="date" required /></label>
          </div>
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

  .admin-fields--four {
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

  .admin-section__heading > p {
    text-align: left;
  }

  .admin-fields--four,
  .admin-result dl {
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
