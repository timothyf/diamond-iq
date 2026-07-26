<script setup>
import { computed, onMounted, reactive, ref, watch } from 'vue'

import { useTeamProfile } from '../composables/useTeamProfile'
import { adminRequestHeaders } from '../composables/apiAuth'
import { formatTwoDecimalPitchingRate } from '../utils/baseballStatFormatting'
import TeamLeadersCard from '../components/TeamLeadersCard.vue'

const props = defineProps({
  teamId: { type: [String, Number], required: true },
})

const teamId = computed(() => props.teamId)
const selectedSeason = ref(null)
const selectedProfileTab = ref('overview')
const selectedRosterView = ref('active')
const profileTabs = [
  { id: 'overview', label: 'Overview' },
  { id: 'roster', label: 'Roster' },
  { id: 'opponent', label: 'Opponent Preparation' },
  { id: 'lineup', label: 'Lineup Planner' },
]
const { team, loading, error, refresh } = useTeamProfile(teamId, selectedSeason)
const savingReport = ref(false)
const reportSaveError = ref('')
const savingLineup = ref(false)
const lineupError = ref('')
const lineupName = ref('')
const lineupNotes = ref('')
const lineupEvaluation = reactive({
  opponent: '',
  opponentStrength: 50,
  parkFactor: 100,
  pitcherHand: 'R',
  recentPerformance: 50,
  reliability: 50,
})
const availableTeams = ref([])
const lineupRows = ref(Array.from({ length: 9 }, (_, index) => ({ battingSlot: index + 1, playerId: '', defensivePosition: '' })))
const lineupPositions = ['C', '1B', '2B', '3B', 'SS', 'LF', 'CF', 'RF', 'DH']
const opponentTeamOptions = computed(() => availableTeams.value.filter((teamOption) => teamOption.id !== team.value?.id))

watch(
  () => team.value?.season,
  (season) => {
    if (season && selectedSeason.value === null) selectedSeason.value = season
  },
)

watch(teamId, () => {
  selectedSeason.value = null
  selectedProfileTab.value = 'overview'
  selectedRosterView.value = 'active'
  reportSaveError.value = ''
  lineupError.value = ''
})

async function loadAvailableTeams() {
  try {
    const response = await fetch('/api/teams', { headers: { Accept: 'application/json' } })
    if (!response.ok) return
    const payload = await response.json()
    availableTeams.value = (payload.data || []).map((team) => ({
      id: team.id,
      name: team.name,
      abbreviation: team.abbreviation,
    }))
  } catch {
    availableTeams.value = []
  }
}

onMounted(loadAvailableTeams)

const injuredRoster = computed(() => team.value?.rosters?.fortyMan?.filter((membership) => membership.injured) || [])

const displayedRoster = computed(() => {
  if (selectedRosterView.value === 'injured') return injuredRoster.value
  return team.value?.rosters?.[selectedRosterView.value] || []
})

const rosterViewLabel = computed(() => ({
  active: 'Active roster',
  injured: 'Injured list',
  fortyMan: '40-man roster',
})[selectedRosterView.value])

const recordLabel = computed(() => {
  const record = team.value?.record
  if (!record?.games_played) return 'No completed games'
  return [record.wins, record.losses, ...(record.ties ? [record.ties] : [])].join('–')
})

const dashboard = computed(() => team.value?.performanceDashboard || {})
const nextSeriesGames = computed(() => {
  const upcoming = team.value?.upcomingGames || []
  if (!upcoming.length) return []

  const opponentId = opponent(upcoming[0])?.id
  const series = []
  for (const game of upcoming) {
    if (opponent(game)?.id !== opponentId) break
    series.push(game)
  }
  return series
})
const nextOpponent = computed(() => nextSeriesGames.value.length ? opponent(nextSeriesGames.value[0]) : null)
const opponentPrep = computed(() => team.value?.opponentPreparation || {})
const lineupPlayers = computed(() => team.value?.rosters?.active || [])
watch(nextOpponent, (opponent) => {
  if (!lineupEvaluation.opponent && opponent?.name) lineupEvaluation.opponent = opponent.name
})
const nextSeriesDateLabel = computed(() => {
  const games = nextSeriesGames.value
  if (!games.length) return 'No upcoming series'

  const first = formatDate(games[0].officialDate, true)
  const last = formatDate(games.at(-1).officialDate, true)
  return first === last ? first : `${first} – ${last}`
})
const rankingGroups = computed(() => [
  {
    key: 'offense',
    title: 'Offensive rankings',
    metrics: [
      { key: 'ops', label: 'OPS', entry: dashboard.value.rankings?.offense?.ops, value: formatDecimal(dashboard.value.rankings?.offense?.ops?.value) },
      { key: 'runs-per-game', label: 'Runs / G', entry: dashboard.value.rankings?.offense?.runs_per_game, value: formatDecimal(dashboard.value.rankings?.offense?.runs_per_game?.value, 2) },
      { key: 'home-runs', label: 'Home Runs', entry: dashboard.value.rankings?.offense?.home_runs, value: formatInteger(dashboard.value.rankings?.offense?.home_runs?.value) },
      { key: 'batting-average', label: 'AVG', entry: dashboard.value.rankings?.offense?.batting_average, value: formatDecimal(dashboard.value.rankings?.offense?.batting_average?.value) },
      { key: 'stolen-bases', label: 'Stolen Bases', entry: dashboard.value.rankings?.offense?.stolen_bases, value: formatInteger(dashboard.value.rankings?.offense?.stolen_bases?.value) },
      { key: 'strikeout-rate', label: 'K Rate', entry: dashboard.value.rankings?.offense?.strikeout_rate, value: formatPercent(dashboard.value.rankings?.offense?.strikeout_rate?.value) },
      { key: 'walk-rate', label: 'BB Rate', entry: dashboard.value.rankings?.offense?.walk_rate, value: formatPercent(dashboard.value.rankings?.offense?.walk_rate?.value) },
    ],
  },
  {
    key: 'pitching',
    title: 'Pitching rankings',
    metrics: [
      { key: 'era', label: 'ERA', entry: dashboard.value.rankings?.pitching?.era, value: formatTwoDecimalPitchingRate(dashboard.value.rankings?.pitching?.era?.value) },
      { key: 'whip', label: 'WHIP', entry: dashboard.value.rankings?.pitching?.whip, value: formatTwoDecimalPitchingRate(dashboard.value.rankings?.pitching?.whip?.value) },
      { key: 'saves', label: 'Saves', entry: dashboard.value.rankings?.pitching?.saves, value: formatInteger(dashboard.value.rankings?.pitching?.saves?.value) },
      { key: 'strikeouts', label: 'Strikeouts', entry: dashboard.value.rankings?.pitching?.strikeouts, value: formatInteger(dashboard.value.rankings?.pitching?.strikeouts?.value) },
      { key: 'quality-starts', label: 'Quality Starts', entry: dashboard.value.rankings?.pitching?.quality_starts, value: formatInteger(dashboard.value.rankings?.pitching?.quality_starts?.value) },
      { key: 'strikeout-rate', label: 'K Rate', entry: dashboard.value.rankings?.pitching?.strikeout_rate, value: formatPercent(dashboard.value.rankings?.pitching?.strikeout_rate?.value) },
      { key: 'walk-rate', label: 'BB Rate', entry: dashboard.value.rankings?.pitching?.walk_rate, value: formatPercent(dashboard.value.rankings?.pitching?.walk_rate?.value) },
    ],
  },
])

function formatDate(value, includeYear = false) {
  if (!value) return '—'
  return new Intl.DateTimeFormat('en-US', {
    month: 'short',
    day: 'numeric',
    ...(includeYear ? { year: 'numeric' } : {}),
  }).format(new Date(`${value}T12:00:00`))
}

function formatTimestamp(value) {
  if (!value) return 'Unavailable'
  return new Intl.DateTimeFormat('en-US', {
    month: 'short', day: 'numeric', year: 'numeric', hour: 'numeric', minute: '2-digit',
  }).format(new Date(value))
}

function titleize(value) {
  return String(value || 'Status unavailable').replaceAll('_', ' ').replace(/\b\w/g, (letter) => letter.toUpperCase())
}

function opponent(game) {
  return game.homeTeam.id === team.value.id ? game.awayTeam : game.homeTeam
}

function isHome(game) {
  return game.homeTeam.id === team.value.id
}

function teamScore(game) {
  return isHome(game) ? game.homeScore : game.awayScore
}

function opponentScore(game) {
  return isHome(game) ? game.awayScore : game.homeScore
}

function resultLabel(game) {
  if (teamScore(game) === null || teamScore(game) === undefined) return '—'
  if (teamScore(game) === opponentScore(game)) return 'T'
  return teamScore(game) > opponentScore(game) ? 'W' : 'L'
}

function probablePitcher(game) {
  return isHome(game) ? game.homeProbablePitcher : game.awayProbablePitcher
}

function opponentProbablePitcher(game) {
  return isHome(game) ? game.awayProbablePitcher : game.homeProbablePitcher
}

function seriesLocation(game) {
  return isHome(game) ? `vs ${nextOpponent.value?.abbreviation}` : `at ${nextOpponent.value?.abbreviation}`
}

function formatDecimal(value, digits = 3) {
  if (value === null || value === undefined || value === '') return '—'
  const number = Number(value)
  if (!Number.isFinite(number)) return '—'
  return number.toFixed(digits)
}

function formatInteger(value) {
  if (value === null || value === undefined || value === '') return '—'
  const number = Number(value)
  if (!Number.isFinite(number)) return '—'
  return Math.round(number).toLocaleString('en-US')
}

function formatPercent(value, digits = 1) {
  if (value === null || value === undefined || value === '') return '—'
  const number = Number(value)
  if (!Number.isFinite(number)) return '—'
  return `${(number * 100).toFixed(digits)}%`
}

function signedChange(value, unit) {
  if (value === null || value === undefined) return '—'
  const number = Number(value)
  const formatted = `${number > 0 ? '+' : ''}${number.toFixed(1)}`
  return unit === 'mph' ? `${formatted} mph` : `${formatted} pts`
}

function evidenceLabel(item) {
  const velocity = Number(item.velocity)
  return [item.pitch_name, Number.isFinite(velocity) ? `${velocity.toFixed(1)} mph` : null].filter(Boolean).join(' · ')
}

function formatRank(entry) {
  if (!entry || !entry.rank) return '—'
  return `#${entry.rank}`
}

function rankingBarPercent(entry) {
  const rank = Number(entry?.rank || 0)
  const totalTeams = Number(dashboard.value.rankings?.context?.total_teams || 30)
  if (!Number.isFinite(rank) || rank <= 0 || !Number.isFinite(totalTeams) || totalTeams <= 0) return 0
  if (rank === 1) return 100

  return Math.round(Math.max(0, Math.min(100, ((totalTeams - rank) / totalTeams) * 100)) * 10) / 10
}

function handleProfileTabKeydown(event, currentIndex) {
  let nextIndex
  if (event.key === 'ArrowRight') nextIndex = (currentIndex + 1) % profileTabs.length
  if (event.key === 'ArrowLeft') nextIndex = (currentIndex - 1 + profileTabs.length) % profileTabs.length
  if (event.key === 'Home') nextIndex = 0
  if (event.key === 'End') nextIndex = profileTabs.length - 1
  if (nextIndex === undefined) return

  event.preventDefault()
  selectedProfileTab.value = profileTabs[nextIndex].id
  event.currentTarget.closest('[role="tablist"]')?.querySelectorAll('[role="tab"]')?.[nextIndex]?.focus()
}

async function saveOpponentReport() {
  if (!team.value?.id || !nextOpponent.value || savingReport.value) return

  savingReport.value = true
  reportSaveError.value = ''
  try {
    const response = await fetch(`/api/teams/${encodeURIComponent(team.value.id)}/opponent_reports`, {
      method: 'POST',
      headers: adminRequestHeaders({ Accept: 'application/json', 'Content-Type': 'application/json' }),
      body: JSON.stringify({ season: team.value.season }),
    })
    const payload = await response.json().catch(() => ({}))
    if (!response.ok) throw new Error(payload.message || 'Unable to generate opponent report.')
    await refresh()
  } catch (requestError) {
    reportSaveError.value = requestError.message
  } finally {
    savingReport.value = false
  }
}

function suggestedPosition(membership) {
  const position = String(membership?.primaryPosition || '').toUpperCase()
  return lineupPositions.includes(position) ? position : ''
}

function populateLineup() {
  lineupRows.value = Array.from({ length: 9 }, (_, index) => {
    const membership = lineupPlayers.value[index]
    return {
      battingSlot: index + 1,
      playerId: membership?.player?.id ? String(membership.player.id) : '',
      defensivePosition: suggestedPosition(membership),
    }
  })
}

async function saveLineupScenario() {
  if (!team.value?.id || savingLineup.value) return

  savingLineup.value = true
  lineupError.value = ''
  try {
    const response = await fetch(`/api/teams/${encodeURIComponent(team.value.id)}/lineup_scenarios`, {
      method: 'POST',
      headers: adminRequestHeaders({ Accept: 'application/json', 'Content-Type': 'application/json' }),
      body: JSON.stringify({
        season: team.value.season,
        scenario_date: new Date().toISOString().slice(0, 10),
        name: lineupName.value.trim() || `${team.value.abbreviation} lineup scenario`,
        notes: lineupNotes.value.trim(),
        evaluation_inputs: {
          opponent: lineupEvaluation.opponent.trim(),
          opponent_strength: Number(lineupEvaluation.opponentStrength),
          park_factor: Number(lineupEvaluation.parkFactor),
          pitcher_hand: lineupEvaluation.pitcherHand,
          recent_performance: Number(lineupEvaluation.recentPerformance),
          reliability: Number(lineupEvaluation.reliability),
        },
        entries: lineupRows.value.map((row) => ({
          player_id: row.playerId,
          batting_slot: row.battingSlot,
          defensive_position: row.defensivePosition,
        })),
      }),
    })
    const payload = await response.json().catch(() => ({}))
    if (!response.ok) throw new Error((payload.violations || [payload.message || 'Unable to save lineup scenario.']).join(' '))
    lineupName.value = ''
    lineupNotes.value = ''
    await refresh()
  } catch (requestError) {
    lineupError.value = requestError.message
  } finally {
    savingLineup.value = false
  }
}
</script>

<template>
  <main class="team-profile-shell" :aria-busy="loading">
    <div v-if="loading && !team" class="team-state" data-test="team-loading">Building team profile…</div>
    <div v-else-if="error" class="team-state team-state--error" data-test="team-error">
      <p>{{ error }}</p>
      <button type="button" @click="refresh">Try again</button>
    </div>

    <template v-else-if="team">
      <RouterLink class="team-back" :to="{ name: 'teams' }">← All MLB teams</RouterLink>

      <section class="team-hero">
        <div class="team-logo"><img :src="team.logoUrl" :alt="`${team.name} logo`" /></div>
        <div class="team-identity">
          <p>Unified team profile · MLB {{ team.mlbId }}</p>
          <h1>{{ team.name }}</h1>
          <span>{{ team.abbreviation }} · {{ team.locationName }}</span>
        </div>
        <label class="season-picker">
          <span class="season-picker__label">Profile season</span>
          <select v-model.number="selectedSeason" :disabled="loading" data-test="team-season-select">
            <option v-for="season in team.availableSeasons" :key="season" :value="season">{{ season }}</option>
          </select>
          <span v-if="loading" class="season-loading" role="status" aria-live="polite" data-test="season-loading">
            <i aria-hidden="true"></i>
            Loading {{ selectedSeason }} season…
          </span>
        </label>
      </section>

      <section class="team-summary" aria-label="Season summary">
        <article><span>{{ team.season }} record</span><strong>{{ recordLabel }}</strong><small>{{ team.record.games_played || 0 }} games</small></article>
        <article><span>Run differential</span><strong>{{ (team.record.runs_scored || 0) - (team.record.runs_allowed || 0) }}</strong><small>{{ team.record.runs_scored || 0 }} RS · {{ team.record.runs_allowed || 0 }} RA</small></article>
        <article><span>{{ team.season }} roster</span><strong>{{ team.rosterSummary.total || 0 }}</strong><small>{{ team.rosterSummary.active || 0 }} active · {{ team.rosterSummary.injured || 0 }} injured</small></article>
        <article><span>Last updated</span><strong class="summary-date">{{ formatTimestamp(team.sourceMetadata.lastUpdatedAt) }}</strong><small>{{ team.sourceMetadata.sources.join(', ') || 'DiamondIQ' }}</small></article>
      </section>

      <nav class="team-profile-tabs" role="tablist" aria-label="Team profile sections">
        <button
          v-for="(tab, index) in profileTabs"
          :id="`team-profile-tab-${tab.id}`"
          :key="tab.id"
          type="button"
          role="tab"
          :aria-controls="`team-profile-panel-${tab.id}`"
          :aria-selected="selectedProfileTab === tab.id"
          :tabindex="selectedProfileTab === tab.id ? 0 : -1"
          :class="{ 'is-selected': selectedProfileTab === tab.id }"
          :data-test="`team-profile-tab-${tab.id}`"
          @click="selectedProfileTab = tab.id"
          @keydown="handleProfileTabKeydown($event, index)"
        >
          {{ tab.label }}
          <span v-if="tab.id === 'roster'">{{ team.rosters.active.length }}</span>
        </button>
      </nav>

      <div
        v-show="selectedProfileTab === 'opponent'"
        id="team-profile-panel-opponent"
        class="team-profile-tab-panel"
        role="tabpanel"
        aria-labelledby="team-profile-tab-opponent"
        data-test="team-profile-panel-opponent"
      >

      <section class="team-panel opponent-prep" data-test="opponent-preparation">
        <header>
          <div><p>Opponent preparation</p><h2>Next series</h2></div>
          <div class="opponent-report-actions">
            <span>{{ nextSeriesGames.length }} {{ nextSeriesGames.length === 1 ? 'game' : 'games' }}</span>
            <button
              type="button"
              :disabled="!nextOpponent || savingReport"
              data-test="save-opponent-report"
              @click="saveOpponentReport"
            >
              {{ savingReport ? 'Generating…' : 'Save opponent report' }}
            </button>
          </div>
        </header>
        <p v-if="reportSaveError" class="opponent-report-error" role="alert">{{ reportSaveError }}</p>

        <div v-if="nextOpponent" class="opponent-prep__overview">
          <div class="opponent-prep__identity">
            <span class="opponent-prep__logo">
              <img :src="`https://www.mlbstatic.com/team-logos/${nextOpponent.mlb_id}.svg`" :alt="`${nextOpponent.name} logo`" />
            </span>
            <div>
              <small>Next opponent</small>
              <RouterLink :to="{ name: 'team-profile', params: { id: nextOpponent.id } }">
                {{ nextOpponent.name }}
              </RouterLink>
              <p>{{ nextSeriesDateLabel }} · {{ seriesLocation(nextSeriesGames[0]) }}</p>
            </div>
          </div>
          <div class="opponent-prep__venue">
            <small>Series venue</small>
            <strong>{{ nextSeriesGames[0].venueName || 'Venue TBD' }}</strong>
          </div>
        </div>

        <div v-if="nextSeriesGames.length" class="probable-starters" aria-label="Probable starters">
          <article v-for="game in nextSeriesGames" :key="game.id" :data-test="`opponent-series-game-${game.id}`">
            <header>
              <div><strong>{{ formatDate(game.officialDate, true) }}</strong><span>{{ seriesLocation(game) }}</span></div>
              <RouterLink :to="{ name: 'game-summary', params: { id: game.id } }">Game preview →</RouterLink>
            </header>
            <div class="starter-matchup">
              <div>
                <small>{{ team.abbreviation }} probable</small>
                <RouterLink
                  v-if="probablePitcher(game)?.id"
                  :to="{ name: 'player-profile', params: { id: probablePitcher(game).id } }"
                  :data-test="`team-probable-${game.id}`"
                >
                  {{ probablePitcher(game).full_name }}
                </RouterLink>
                <strong v-else>{{ probablePitcher(game)?.full_name || 'TBD' }}</strong>
              </div>
              <span aria-hidden="true">vs</span>
              <div>
                <small>{{ nextOpponent.abbreviation }} probable</small>
                <RouterLink
                  v-if="opponentProbablePitcher(game)?.id"
                  :to="{ name: 'player-profile', params: { id: opponentProbablePitcher(game).id } }"
                  :data-test="`opponent-probable-${game.id}`"
                >
                  {{ opponentProbablePitcher(game).full_name }}
                </RouterLink>
                <strong v-else>{{ opponentProbablePitcher(game)?.full_name || 'TBD' }}</strong>
              </div>
            </div>
          </article>
        </div>
        <p v-else class="team-empty">No upcoming opponent is stored for this season.</p>

        <section v-if="nextOpponent && opponentPrep.recentPerformance" class="opponent-recent" data-test="opponent-recent-performance">
          <header><div><small>Recent opponent performance</small><strong>Last {{ opponentPrep.recentPerformance.games }} games</strong></div></header>
          <dl>
            <div><dt>Record</dt><dd>{{ opponentPrep.recentPerformance.wins }}–{{ opponentPrep.recentPerformance.losses }}</dd></div>
            <div><dt>Runs / G</dt><dd>{{ formatDecimal(opponentPrep.recentPerformance.runs_per_game, 2) }}</dd></div>
            <div><dt>OPS</dt><dd>{{ formatDecimal(opponentPrep.recentPerformance.ops) }}</dd></div>
            <div><dt>ERA</dt><dd>{{ formatTwoDecimalPitchingRate(opponentPrep.recentPerformance.era) }}</dd></div>
          </dl>
        </section>

        <section
          v-for="starter in opponentPrep.probableStarters || []"
          :key="starter.player.id"
          class="starter-scouting"
          :data-test="`starter-scouting-${starter.player.id}`"
        >
          <header>
            <div>
              <small>Probable starter scouting</small>
              <RouterLink :to="{ name: 'player-profile', params: { id: starter.player.id } }">{{ starter.player.full_name }}</RouterLink>
            </div>
            <span>{{ starter.throws || '—' }}HP · {{ starter.sampleSize }} tracked pitches</span>
          </header>

          <div class="scouting-layout">
            <div class="scouting-table-wrap">
              <h4>Repertoire</h4>
              <table>
                <thead><tr><th>Pitch</th><th>Usage</th><th>Velo</th><th>H-break</th><th>V-break</th><th>Evidence</th></tr></thead>
                <tbody>
                  <tr v-for="pitch in starter.repertoire" :key="pitch.pitch_type">
                    <th>{{ pitch.pitch_name }} <small>{{ pitch.pitch_type }}</small></th>
                    <td>{{ formatDecimal(pitch.usage_percentage, 1) }}%</td>
                    <td>{{ formatDecimal(pitch.average_velocity, 1) }} mph</td>
                    <td>{{ formatDecimal(pitch.horizontal_break, 1) }} in</td>
                    <td>{{ formatDecimal(pitch.vertical_break, 1) }} in</td>
                    <td>
                      <RouterLink
                        v-for="item in pitch.evidence"
                        :key="item.pitch_id"
                        class="evidence-link"
                        :to="{ name: 'game-summary', params: { id: item.game_id }, hash: `#pitch-${item.pitch_id}` }"
                      >{{ evidenceLabel(item) }}</RouterLink>
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>

            <div class="scouting-side">
              <article>
                <h4>Handedness splits</h4>
                <dl>
                  <div v-for="split in starter.handednessSplits" :key="split.batter_hand">
                    <dt>vs {{ split.batter_hand }}HB</dt>
                    <dd>{{ split.plate_appearances }} PA · K {{ formatDecimal(split.strikeout_rate, 1) }}% · Whiff {{ formatDecimal(split.whiff_rate, 1) }}%</dd>
                    <RouterLink
                      v-if="split.evidence[0]"
                      class="evidence-link"
                      :to="{ name: 'game-summary', params: { id: split.evidence[0].game_id }, hash: `#plate-appearance-${split.evidence[0].plate_appearance_id}` }"
                    >View supporting PA →</RouterLink>
                  </div>
                </dl>
              </article>
              <article>
                <h4>Recent changes</h4>
                <ul v-if="starter.recentChanges.length">
                  <li v-for="change in starter.recentChanges" :key="change.key">
                    <span>{{ change.label }}</span><strong :class="{ 'is-up': change.change > 0, 'is-down': change.change < 0 }">{{ signedChange(change.change, change.unit) }}</strong>
                    <RouterLink
                      v-if="change.evidence[0]"
                      class="evidence-link"
                      :to="{ name: 'game-summary', params: { id: change.evidence[0].game_id }, hash: `#pitch-${change.evidence[0].pitch_id}` }"
                    >Supporting pitch →</RouterLink>
                  </li>
                </ul>
                <p v-else>At least 200 tracked pitches are needed for recent-change comparisons.</p>
              </article>
            </div>
          </div>
        </section>

        <section class="opponent-report-history" data-test="opponent-report-history">
          <header>
            <div><small>Saved intelligence</small><strong>Opponent reports</strong></div>
            <span>{{ team.opponentReports.length }} saved</span>
          </header>
          <div v-if="team.opponentReports.length" class="opponent-report-list">
            <RouterLink
              v-for="report in team.opponentReports"
              :key="report.id"
              :to="{ name: 'opponent-report', params: { id: report.id } }"
              :data-test="`opponent-report-${report.id}`"
            >
              <span>
                <strong>{{ report.title }}</strong>
                <small>Generated {{ formatTimestamp(report.generatedAt) }}</small>
              </span>
              <em>{{ report.probableStarterCount }} {{ report.probableStarterCount === 1 ? 'starter' : 'starters' }} →</em>
            </RouterLink>
          </div>
          <p v-else>No reports saved for {{ team.season }} yet.</p>
        </section>
      </section>

      </div>

      <div
        v-show="selectedProfileTab === 'lineup'"
        id="team-profile-panel-lineup"
        class="team-profile-tab-panel"
        role="tabpanel"
        aria-labelledby="team-profile-tab-lineup"
        data-test="team-profile-panel-lineup"
      >
      <section class="team-panel lineup-scenarios" data-test="lineup-scenarios">
        <header>
          <div><p>Lineup planner</p><h2>Lineup scenarios</h2></div>
          <span>9 hitters · defensive coverage required</span>
        </header>
        <div class="lineup-scenarios__intro">
          <p>Build a DH lineup from the active roster. Saving checks batting order, duplicate players, position coverage, and roster availability.</p>
          <button type="button" data-test="populate-lineup" @click="populateLineup">Start with active roster</button>
        </div>
        <div class="lineup-scenarios__fields">
          <label>Scenario name<input v-model="lineupName" type="text" placeholder="e.g. vs RHP — series opener" /></label>
          <label>Notes<input v-model="lineupNotes" type="text" placeholder="Optional game-plan notes" /></label>
        </div>
        <fieldset class="lineup-evaluation" data-test="lineup-evaluation-inputs">
          <legend>Evaluation context</legend>
          <label>Opponent<select v-model="lineupEvaluation.opponent" data-test="lineup-opponent-select">
            <option value="">Choose team</option>
            <option v-for="teamOption in opponentTeamOptions" :key="teamOption.id" :value="teamOption.name">
              {{ teamOption.abbreviation }} · {{ teamOption.name }}
            </option>
          </select></label>
          <label>Opponent strength (0–100)<input v-model.number="lineupEvaluation.opponentStrength" type="number" min="0" max="100" /></label>
          <label>Park factor<input v-model.number="lineupEvaluation.parkFactor" type="number" min="80" max="120" /></label>
          <label>Pitcher hand<select v-model="lineupEvaluation.pitcherHand"><option value="R">RHP</option><option value="L">LHP</option></select></label>
          <label>Recent performance (0–100)<input v-model.number="lineupEvaluation.recentPerformance" type="number" min="0" max="100" /></label>
          <label>Reliability (0–100)<input v-model.number="lineupEvaluation.reliability" type="number" min="0" max="100" /></label>
        </fieldset>
        <div class="lineup-grid" role="table" aria-label="Lineup scenario editor">
          <div class="lineup-grid__header" role="row"><span>Order</span><span>Player</span><span>Defense</span></div>
          <label v-for="row in lineupRows" :key="row.battingSlot" class="lineup-row" :data-test="`lineup-row-${row.battingSlot}`">
            <strong>{{ row.battingSlot }}</strong>
            <select v-model="row.playerId" :aria-label="`Batting slot ${row.battingSlot} player`">
              <option value="">Choose player</option>
              <option v-for="membership in lineupPlayers" :key="membership.player.id" :value="String(membership.player.id)">
                {{ membership.player.fullName }} · {{ membership.primaryPosition || '—' }}
              </option>
            </select>
            <select v-model="row.defensivePosition" :aria-label="`Batting slot ${row.battingSlot} defensive position`">
              <option value="">Position</option>
              <option v-for="position in lineupPositions" :key="position" :value="position">{{ position }}</option>
            </select>
          </label>
        </div>
        <p v-if="lineupError" class="lineup-scenarios__error" role="alert">{{ lineupError }}</p>
        <footer class="lineup-scenarios__footer">
          <span>{{ lineupPlayers.length }} active players available</span>
          <button type="button" :disabled="savingLineup" data-test="save-lineup-scenario" @click="saveLineupScenario">
            {{ savingLineup ? 'Checking constraints…' : 'Save lineup scenario' }}
          </button>
        </footer>
        <div v-if="team.lineupScenarios.length" class="lineup-scenario-history">
          <strong>Saved scenarios · score comparison</strong>
          <div class="lineup-score-comparison" data-test="lineup-score-comparison">
            <article v-for="scenario in team.lineupScenarios" :key="scenario.id">
              <div><strong>{{ scenario.name }}</strong><span>{{ scenario.totalScore ?? '—' }}/100</span></div>
              <small>
                Opponent {{ scenario.scoreBreakdown?.opponent ?? '—' }} ·
                Park {{ scenario.scoreBreakdown?.park ?? '—' }} ·
                Platoon {{ scenario.scoreBreakdown?.platoon ?? '—' }} ·
                Recent {{ scenario.scoreBreakdown?.recent_performance ?? '—' }} ·
                Reliability {{ scenario.scoreBreakdown?.reliability ?? '—' }}
              </small>
              <small>Weights: 20% opponent · 15% park · 25% platoon · 20% recent · 20% reliability</small>
              <RouterLink :to="{ name: 'lineup-scenario', params: { id: scenario.id } }">Open scenario →</RouterLink>
            </article>
          </div>
          <ul>
            <li v-for="scenario in team.lineupScenarios" :key="scenario.id">
              <RouterLink :to="{ name: 'lineup-scenario', params: { id: scenario.id } }">{{ scenario.name }}</RouterLink>
              <span>{{ formatDate(scenario.scenarioDate, true) }} · {{ scenario.entryCount }} players</span>
            </li>
          </ul>
        </div>
      </section>

      </div>

      <div
        v-show="selectedProfileTab === 'overview'"
        id="team-profile-panel-overview"
        class="team-profile-tab-panel"
        role="tabpanel"
        aria-labelledby="team-profile-tab-overview"
        data-test="team-profile-panel-overview"
      >
      <TeamLeadersCard :leaders="team.teamLeaders" :season="team.season" />

      <section class="team-panel performance-panel" data-test="team-performance-dashboard">
        <header>
          <div><p>Daily analytics</p><h2>Team performance dashboard</h2></div>
          <span>Built from precomputed daily tables</span>
        </header>

        <div v-if="dashboard.analyticsCoverage?.complete === false" class="analytics-coverage-warning" data-test="analytics-coverage-warning">
          <strong>Incomplete pitching coverage</strong>
          <span>
            {{ dashboard.analyticsCoverage.missing_game_count }} of {{ dashboard.analyticsCoverage.completed_game_count }} completed games
            {{ dashboard.analyticsCoverage.missing_game_count === 1 ? 'is' : 'are' }} missing pitching details. Season rankings may be incomplete.
          </span>
        </div>

        <p class="ranking-scale-note"><i aria-hidden="true"></i> Longer bars indicate a stronger league rank; the #1 team fills the scale.</p>

        <div class="ranking-grid" data-test="team-ranking-cards">
          <article v-for="group in rankingGroups" :key="group.key" class="ranking-card" :data-test="`${group.key}-ranking-card`">
            <header class="ranking-card__heading">
              <h3>{{ group.title }}</h3>
              <span>Rank</span>
            </header>
            <div class="ranking-card__metrics">
              <div v-for="metric in group.metrics" :key="metric.key" class="ranking-row" :data-test="`${group.key}-ranking-${metric.key}`">
                <strong class="ranking-row__label">{{ metric.label }}</strong>
                <div
                  class="ranking-bar"
                  role="progressbar"
                  :aria-label="`${group.title}: ${metric.label} ${formatRank(metric.entry)} of ${dashboard.rankings?.context?.total_teams || 30}`"
                  :aria-valuenow="rankingBarPercent(metric.entry)"
                  aria-valuemin="0"
                  aria-valuemax="100"
                >
                  <i class="ranking-bar__fill" :style="{ width: `${rankingBarPercent(metric.entry)}%` }"></i>
                  <span
                    class="ranking-bar__value"
                    :class="{ 'ranking-bar__value--outside': rankingBarPercent(metric.entry) < 24 }"
                    :style="{ left: `${rankingBarPercent(metric.entry)}%` }"
                  >
                    {{ metric.value }}
                  </span>
                </div>
                <b class="ranking-row__rank">{{ formatRank(metric.entry) }}</b>
              </div>
            </div>
          </article>
        </div>

        <div class="performance-grid performance-grid--details">

          <article>
            <h3>Recent form</h3>
            <dl>
              <div v-for="window in ['7', '15', '30']" :key="window">
                <dt>Last {{ window }} games</dt>
                <dd>
                  {{ dashboard.recentForm?.[window]?.wins || 0 }}-{{ dashboard.recentForm?.[window]?.losses || 0 }} ·
                  OPS {{ formatDecimal(dashboard.recentForm?.[window]?.ops) }} ·
                  ERA {{ formatTwoDecimalPitchingRate(dashboard.recentForm?.[window]?.era) }}
                </dd>
              </div>
            </dl>
          </article>

          <article>
            <h3>Home / road</h3>
            <dl>
              <div><dt>Home</dt><dd>{{ dashboard.homeRoadSplits?.home?.wins || 0 }}-{{ dashboard.homeRoadSplits?.home?.losses || 0 }} · RD {{ dashboard.homeRoadSplits?.home?.run_differential || 0 }}</dd></div>
              <div><dt>Road</dt><dd>{{ dashboard.homeRoadSplits?.road?.wins || 0 }}-{{ dashboard.homeRoadSplits?.road?.losses || 0 }} · RD {{ dashboard.homeRoadSplits?.road?.run_differential || 0 }}</dd></div>
            </dl>
          </article>

          <article>
            <h3>Platoon splits</h3>
            <dl>
              <div><dt>Offense vs LHP</dt><dd>K {{ formatPercent(dashboard.platoonSplits?.offense?.vs_left?.strikeout_rate) }} · EV {{ formatDecimal(dashboard.platoonSplits?.offense?.vs_left?.average_exit_velocity, 1) }}</dd></div>
              <div><dt>Offense vs RHP</dt><dd>K {{ formatPercent(dashboard.platoonSplits?.offense?.vs_right?.strikeout_rate) }} · EV {{ formatDecimal(dashboard.platoonSplits?.offense?.vs_right?.average_exit_velocity, 1) }}</dd></div>
              <div><dt>Pitching vs LHB</dt><dd>K {{ formatPercent(dashboard.platoonSplits?.pitching?.vs_left?.strikeout_rate) }} · Velo {{ formatDecimal(dashboard.platoonSplits?.pitching?.vs_left?.average_velocity, 1) }}</dd></div>
              <div><dt>Pitching vs RHB</dt><dd>K {{ formatPercent(dashboard.platoonSplits?.pitching?.vs_right?.strikeout_rate) }} · Velo {{ formatDecimal(dashboard.platoonSplits?.pitching?.vs_right?.average_velocity, 1) }}</dd></div>
            </dl>
          </article>

          <article>
            <h3>Starter / bullpen</h3>
            <dl>
              <div><dt>Starters</dt><dd>{{ formatDecimal(dashboard.starterBullpen?.starters?.innings_pitched, 1) }} IP · ERA {{ formatTwoDecimalPitchingRate(dashboard.starterBullpen?.starters?.era) }} · WHIP {{ formatTwoDecimalPitchingRate(dashboard.starterBullpen?.starters?.whip) }}</dd></div>
              <div><dt>Bullpen</dt><dd>{{ formatDecimal(dashboard.starterBullpen?.bullpen?.innings_pitched, 1) }} IP · ERA {{ formatTwoDecimalPitchingRate(dashboard.starterBullpen?.bullpen?.era) }} · WHIP {{ formatTwoDecimalPitchingRate(dashboard.starterBullpen?.bullpen?.whip) }}</dd></div>
            </dl>
          </article>

          <article>
            <h3>One-run games</h3>
            <dl>
              <div><dt>Record</dt><dd>{{ dashboard.oneRunPerformance?.wins || 0 }}-{{ dashboard.oneRunPerformance?.losses || 0 }}</dd></div>
              <div><dt>Win rate</dt><dd>{{ formatPercent(dashboard.oneRunPerformance?.winning_percentage) }}</dd></div>
              <div><dt>Games</dt><dd>{{ dashboard.oneRunPerformance?.games || 0 }}</dd></div>
            </dl>
          </article>
        </div>

        <div class="signals-grid">
          <article>
            <h3>Current strengths</h3>
            <ul>
              <li v-for="entry in dashboard.strengths || []" :key="entry">{{ entry }}</li>
            </ul>
          </article>
          <article>
            <h3>Areas of concern</h3>
            <ul>
              <li v-for="entry in dashboard.concerns || []" :key="entry">{{ entry }}</li>
            </ul>
          </article>
        </div>

        <div class="drilldown-grid">
          <article>
            <h3>Drill-down: games</h3>
            <ul>
              <li v-for="game in dashboard.drillDown?.games || []" :key="game.id">
                <RouterLink :to="{ name: 'game-summary', params: { id: game.id } }">
                  {{ formatDate(game.official_date, true) }} · {{ game.result }} · {{ game.score?.team }}-{{ game.score?.opponent }} vs {{ game.opponent }}
                </RouterLink>
              </li>
            </ul>
          </article>
          <article>
            <h3>Drill-down: players</h3>
            <ul>
              <li v-for="playerEntry in dashboard.drillDown?.players?.hitters || []" :key="`h-${playerEntry.player?.id}`">
                <RouterLink v-if="playerEntry.player?.id" :to="{ name: 'player-profile', params: { id: playerEntry.player.id } }">
                  {{ playerEntry.player?.full_name }}
                </RouterLink>
                <template v-else>{{ playerEntry.player?.full_name || 'Unknown player' }}</template>
                · OPS {{ formatDecimal(playerEntry.ops) }}
              </li>
            </ul>
          </article>
          <article>
            <h3>Drill-down: plate appearances</h3>
            <p>Total tracked PA: {{ dashboard.drillDown?.plateAppearances?.teamTotal || 0 }}</p>
            <ul>
              <li v-for="entry in dashboard.drillDown?.plateAppearances?.leaders || []" :key="`pa-${entry.player?.id}`">
                <RouterLink
                  v-if="entry.player?.id"
                  :to="{ name: 'player-profile', params: { id: entry.player.id } }"
                  :data-test="`plate-appearance-player-${entry.player.id}`"
                >
                  {{ entry.player.full_name }}
                </RouterLink>
                <template v-else>{{ entry.player?.full_name || 'Unknown player' }}</template>
                · {{ entry.plate_appearances }} PA
              </li>
            </ul>
          </article>
          <article>
            <h3>Drill-down: pitches</h3>
            <p>Total tracked pitches: {{ dashboard.drillDown?.pitches?.teamTotal || 0 }}</p>
            <ul>
              <li v-for="entry in dashboard.drillDown?.pitches?.leaders || []" :key="`pi-${entry.player?.id}`">
                <RouterLink
                  v-if="entry.player?.id"
                  :to="{ name: 'player-profile', params: { id: entry.player.id } }"
                  :data-test="`pitch-player-${entry.player.id}`"
                >
                  {{ entry.player.full_name }}
                </RouterLink>
                <template v-else>{{ entry.player?.full_name || 'Unknown player' }}</template>
                · {{ entry.pitches }} pitches
              </li>
            </ul>
          </article>
        </div>
      </section>

      <div class="team-schedule-grid">
        <section class="team-panel">
          <header><div><p>Next on the calendar</p><h2>Upcoming games</h2></div><span>{{ team.upcomingGames.length }} shown</span></header>
          <ol v-if="team.upcomingGames.length" class="game-list" data-test="upcoming-games">
            <li v-for="game in team.upcomingGames" :key="game.id">
              <time>{{ formatDate(game.officialDate) }}</time>
              <div><strong>{{ isHome(game) ? 'vs' : '@' }} {{ opponent(game).abbreviation }}</strong><span>{{ game.venueName || game.detailedStatus || 'Venue TBD' }}</span></div>
              <small>{{ probablePitcher(game)?.full_name || 'Probable TBD' }}</small>
            </li>
          </ol>
          <p v-else class="team-empty">No upcoming games are stored for this season.</p>
        </section>

        <section class="team-panel">
          <header><div><p>Latest finals</p><h2>Recent results</h2></div><span>{{ team.recentGames.length }} shown</span></header>
          <ol v-if="team.recentGames.length" class="game-list" data-test="recent-games">
            <li v-for="game in team.recentGames" :key="game.id" class="game-list__linked">
              <RouterLink class="game-result-link" :to="{ name: 'game-summary', params: { id: game.id } }">
                <time>{{ formatDate(game.officialDate) }}</time>
                <div><strong>{{ isHome(game) ? 'vs' : '@' }} {{ opponent(game).abbreviation }}</strong><span>{{ teamScore(game) }}–{{ opponentScore(game) }}</span></div>
                <b :class="`result result--${resultLabel(game).toLowerCase()}`">{{ resultLabel(game) }}</b>
              </RouterLink>
            </li>
          </ol>
          <p v-else class="team-empty">No completed games are stored for this season.</p>
        </section>
      </div>

      </div>

      <section
        v-show="selectedProfileTab === 'roster'"
        id="team-profile-panel-roster"
        class="team-panel roster-panel team-profile-tab-panel"
        role="tabpanel"
        aria-labelledby="team-profile-tab-roster"
        data-test="team-profile-panel-roster"
      >
        <header>
          <div><p>Dated roster state</p><h2>{{ team.season }} roster</h2></div>
          <div class="roster-view-controls">
            <div role="group" aria-label="Roster view">
              <button
                type="button"
                data-test="roster-view-active"
                :class="{ 'is-selected': selectedRosterView === 'active' }"
                :aria-pressed="selectedRosterView === 'active'"
                @click="selectedRosterView = 'active'"
              >
                Active <span>{{ team.rosters.active.length }}</span>
              </button>
              <button
                type="button"
                data-test="roster-view-injured"
                :class="{ 'is-selected': selectedRosterView === 'injured' }"
                :aria-pressed="selectedRosterView === 'injured'"
                @click="selectedRosterView = 'injured'"
              >
                IL <span>{{ injuredRoster.length }}</span>
              </button>
              <button
                type="button"
                data-test="roster-view-40man"
                :class="{ 'is-selected': selectedRosterView === 'fortyMan' }"
                :aria-pressed="selectedRosterView === 'fortyMan'"
                @click="selectedRosterView = 'fortyMan'"
              >
                40-man <span>{{ team.rosters.fortyMan.length }}</span>
              </button>
            </div>
            <small>As of {{ formatDate(team.rosterAsOf, true) }}</small>
          </div>
        </header>
        <div v-if="displayedRoster.length" class="roster-table-wrap" data-test="team-roster">
          <table>
            <thead><tr><th>Player</th><th>#</th><th>Pos</th><th>Status</th><th>Member since</th></tr></thead>
            <tbody>
              <tr v-for="membership in displayedRoster" :key="membership.id">
                <td>
                  <RouterLink class="roster-player" :to="{ name: 'player-profile', params: { id: membership.player.id } }">
                    <span class="roster-headshot">
                      <img v-if="membership.player.headshotUrl" :src="membership.player.headshotUrl" :alt="`${membership.player.fullName} headshot`" />
                      <b v-else>{{ membership.player.firstName?.[0] }}{{ membership.player.lastName?.[0] }}</b>
                    </span>
                    <strong>{{ membership.player.fullName }}</strong>
                  </RouterLink>
                </td>
                <td>{{ membership.jerseyNumber || '—' }}</td>
                <td>{{ membership.primaryPosition || '—' }}</td>
                <td><span class="roster-status" :class="{ 'roster-status--injured': membership.injured }">{{ membership.statusDescription || titleize(membership.rosterStatus) }}</span></td>
                <td>{{ formatDate(membership.startsOn, true) }}</td>
              </tr>
            </tbody>
          </table>
        </div>
        <p v-else class="team-empty">No players are stored for this team's {{ rosterViewLabel.toLowerCase() }}.</p>
      </section>

      <footer class="team-freshness">
        <span>Schedule synced {{ formatTimestamp(team.sourceMetadata.scheduleLastSyncedAt) }}</span>
        <span>Roster synced {{ formatTimestamp(team.sourceMetadata.rosterLastSyncedAt) }}</span>
      </footer>
    </template>
  </main>
</template>

<style scoped>
.team-profile-shell { width: min(1500px, calc(100% - 2rem)); margin: 0 auto; padding: 2.2rem 0 5rem; color: #10263d; }
.team-back { color: #8d392e; font-size: .82rem; font-weight: 800; text-decoration: none; }
.team-hero { display: grid; grid-template-columns: 180px 1fr auto; gap: 2rem; align-items: center; margin-top: 1rem; padding: 2rem; border: 1px solid #d9d7ce; border-radius: 36px; background: rgba(255,250,240,.8); }
.team-logo { display: grid; place-items: center; width: 160px; height: 160px; border-radius: 50%; background: white; box-shadow: inset 0 0 0 1px #dedbd2; }
.team-logo img { width: 118px; height: 118px; object-fit: contain; }
.team-identity p, .team-panel header p { margin: 0; color: #a93627; font-size: .72rem; font-weight: 800; letter-spacing: .16em; text-transform: uppercase; }
.team-identity h1 { margin: .2rem 0; font-family: 'Avenir Next Condensed', sans-serif; font-size: clamp(3.5rem, 7vw, 7rem); line-height: .9; text-transform: uppercase; }
.team-identity span { color: #53616c; font-size: 1.05rem; }
.season-picker__label { display: block; margin-bottom: .35rem; color: #68737b; font-size: .72rem; font-weight: 800; text-transform: uppercase; }
.season-picker select { min-width: 120px; padding: .7rem .9rem; border: 1px solid #c9c8c0; border-radius: 12px; color: #10263d; background: white; font: inherit; font-weight: 800; }
.season-picker select:disabled { cursor: wait; opacity: .65; }
.season-loading { display: flex; gap: .45rem; align-items: center; margin-top: .55rem; color: #435767; font-size: .72rem; font-weight: 750; white-space: nowrap; }
.season-loading i { display: block; width: 14px; height: 14px; border: 2px solid rgba(16,38,61,.2); border-top-color: #a93627; border-radius: 50%; animation: team-season-spin .7s linear infinite; }
@keyframes team-season-spin { to { transform: rotate(360deg); } }
@media (prefers-reduced-motion: reduce) { .season-loading i { animation-duration: 1.6s; } }
.team-summary { display: grid; grid-template-columns: repeat(4, 1fr); gap: 1rem; margin: 1rem 0; }
.team-summary article, .team-panel { border: 1px solid #d9d7ce; border-radius: 24px; background: rgba(255,255,255,.72); }
.team-summary article { padding: 1.2rem; }
.team-summary span, .team-summary small, .team-summary strong { display: block; }
.team-summary span { color: #69747c; font-size: .7rem; font-weight: 800; letter-spacing: .1em; text-transform: uppercase; }
.team-summary strong { margin: .25rem 0; font-family: 'Avenir Next Condensed', sans-serif; font-size: 2.3rem; }
.team-summary .summary-date { font-family: inherit; font-size: .92rem; line-height: 2.6rem; }
.team-summary small { color: #788188; }
.team-profile-tabs { display: flex; gap: .45rem; margin: 0 0 1rem; padding: .3rem; border: 1px solid #d9d7ce; border-radius: 16px; background: rgba(255,250,240,.72); }
.team-profile-tabs button { display: inline-flex; gap: .45rem; align-items: center; justify-content: center; min-width: 130px; padding: .72rem 1rem; border: 0; border-radius: 12px; color: #5b6871; background: transparent; font: inherit; font-size: .78rem; font-weight: 900; letter-spacing: .06em; text-transform: uppercase; cursor: pointer; }
.team-profile-tabs button span { display: grid; min-width: 22px; height: 22px; padding: 0 .35rem; place-items: center; border-radius: 999px; color: inherit; background: rgba(16,38,61,.09); font-size: .65rem; }
.team-profile-tabs button.is-selected { color: #fffaf0; background: #10263d; box-shadow: 0 5px 14px rgba(16,38,61,.18); }
.team-profile-tabs button.is-selected span { background: rgba(255,255,255,.16); }
.team-profile-tab-panel:focus { outline: none; }
.team-schedule-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 1rem; }
.team-panel { padding: 1.35rem; }
.opponent-prep { overflow: hidden; background: linear-gradient(135deg, rgba(255,250,240,.95), rgba(232,239,243,.88)); }
.lineup-scenarios { background: linear-gradient(135deg, rgba(237,247,240,.92), rgba(255,252,244,.96)); }
.lineup-scenarios__intro,.lineup-scenarios__footer { display: flex; justify-content: space-between; gap: 1rem; align-items: center; }
.lineup-scenarios__intro p { max-width: 700px; margin: 0; color: #526572; font-size: .84rem; }
.lineup-scenarios button { padding: .55rem .8rem; border: 1px solid rgba(16,38,61,.18); border-radius: 999px; color: #173652; background: #fffdf7; font-size: .72rem; font-weight: 900; cursor: pointer; }
.lineup-scenarios__footer button { border: 0; color: #fffaf0; background: #20543c; }
.lineup-scenarios button:disabled { opacity: .5; cursor: not-allowed; }
.lineup-scenarios__fields { display: grid; grid-template-columns: 1fr 1fr; gap: .7rem; margin-top: .9rem; }
.lineup-scenarios__fields label { display: grid; gap: .3rem; color: #697784; font-size: .68rem; font-weight: 900; letter-spacing: .06em; text-transform: uppercase; }
.lineup-evaluation { display: grid; grid-template-columns: repeat(3,minmax(0,1fr)); gap: .7rem; margin: .9rem 0 0; padding: .8rem; border: 1px solid rgba(16,38,61,.12); border-radius: 14px; }
.lineup-evaluation legend { grid-column: 1 / -1; padding: 0 .3rem; color: #173652; font-size: .72rem; font-weight: 900; letter-spacing: .08em; text-transform: uppercase; }
.lineup-evaluation label { display: grid; gap: .3rem; color: #697784; font-size: .65rem; font-weight: 900; letter-spacing: .05em; text-transform: uppercase; }
.lineup-evaluation input,.lineup-evaluation select { min-width: 0; padding: .55rem .65rem; border: 1px solid rgba(16,38,61,.16); border-radius: 9px; color: #173652; background: #fffdf7; font: inherit; }
.lineup-scenarios input,.lineup-row select { min-width: 0; padding: .55rem .65rem; border: 1px solid rgba(16,38,61,.16); border-radius: 9px; color: #173652; background: #fffdf7; font: inherit; }
.lineup-grid { display: grid; gap: .35rem; margin-top: .9rem; }
.lineup-grid__header,.lineup-row { display: grid; grid-template-columns: 64px minmax(0,1fr) 120px; gap: .55rem; align-items: center; }
.lineup-grid__header { padding: 0 .4rem; color: #71808c; font-size: .65rem; font-weight: 900; letter-spacing: .07em; text-transform: uppercase; }
.lineup-row { padding: .38rem; border-radius: 10px; background: rgba(255,255,255,.74); }
.lineup-row > strong { display: grid; width: 28px; height: 28px; place-items: center; border-radius: 50%; color: #fffaf0; background: #173652; font-size: .78rem; }
.lineup-scenarios__error { margin: .8rem 0 0; padding: .65rem .8rem; border-radius: 10px; color: #7d291f; background: #f5ddd5; font-size: .78rem; font-weight: 800; }
.lineup-scenarios__footer { margin-top: .9rem; color: #667680; font-size: .75rem; }
.lineup-scenario-history { margin-top: 1rem; padding-top: .8rem; border-top: 1px solid rgba(16,38,61,.1); }
.lineup-scenario-history strong { color: #173652; font-size: .78rem; text-transform: uppercase; }
.lineup-scenario-history ul { display: grid; gap: .35rem; margin: .5rem 0 0; padding: 0; list-style: none; }
.lineup-score-comparison { display: grid; grid-template-columns: repeat(auto-fit,minmax(220px,1fr)); gap: .55rem; margin-top: .55rem; }
.lineup-score-comparison article { display: grid; gap: .25rem; padding: .7rem; border-radius: 12px; background: rgba(32,84,60,.08); }
.lineup-score-comparison article > div { display: flex; justify-content: space-between; gap: .5rem; }
.lineup-score-comparison article > div span { color: #20543c; font-weight: 900; }
.lineup-score-comparison small { color: #526572; font-size: .67rem; line-height: 1.4; }
.lineup-score-comparison a { color: #20543c; font-size: .7rem; font-weight: 900; }
.lineup-scenario-history li { display: flex; justify-content: space-between; gap: 1rem; }
.lineup-scenario-history a { color: #20543c; font-size: .8rem; font-weight: 900; }
.lineup-scenario-history span { color: #71808c; font-size: .72rem; }
.opponent-report-actions { display: flex; gap: .75rem; align-items: center; }
.opponent-report-actions button { padding: .55rem .8rem; border: 0; border-radius: 999px; color: #fffaf0; background: #8d392e; font-size: .72rem; font-weight: 900; cursor: pointer; }
.opponent-report-actions button:disabled { opacity: .5; cursor: not-allowed; }
.opponent-report-error { margin-top: .7rem; padding: .65rem .8rem; border-radius: 10px; color: #7d291f; background: #f5ddd5; font-size: .78rem; font-weight: 800; }
.opponent-report-history { margin-top: .9rem; padding: 1rem; border: 1px solid rgba(16,38,61,.12); border-radius: 18px; background: rgba(16,38,61,.04); }
.opponent-report-history > header { display: flex; justify-content: space-between; gap: 1rem; align-items: end; }
.opponent-report-history > header small,.opponent-report-history > header strong { display: block; }
.opponent-report-history > header small { color: #a93627; font-size: .64rem; font-weight: 900; letter-spacing: .1em; text-transform: uppercase; }
.opponent-report-history > header span,.opponent-report-history > p { color: #667680; font-size: .75rem; }
.opponent-report-list { display: grid; gap: .5rem; margin-top: .7rem; }
.opponent-report-list > a { display: flex; justify-content: space-between; gap: 1rem; align-items: center; padding: .7rem .8rem; border-radius: 12px; color: #173652; background: rgba(255,255,255,.78); text-decoration: none; }
.opponent-report-list strong,.opponent-report-list small { display: block; }
.opponent-report-list small { margin-top: .15rem; color: #71808c; font-size: .68rem; }
.opponent-report-list em { color: #8d392e; font-size: .7rem; font-style: normal; font-weight: 900; white-space: nowrap; }
.opponent-prep__overview { display: flex; justify-content: space-between; gap: 1rem; align-items: center; margin-top: 1rem; padding: 1rem; border-radius: 18px; color: #fffaf0; background: #10263d; }
.opponent-prep__identity { display: flex; min-width: 0; gap: .9rem; align-items: center; }
.opponent-prep__logo { display: grid; flex: 0 0 auto; width: 66px; height: 66px; place-items: center; border-radius: 50%; background: #fff; }
.opponent-prep__logo img { width: 48px; height: 48px; object-fit: contain; }
.opponent-prep__identity small,.opponent-prep__identity a,.opponent-prep__identity p,.opponent-prep__venue small,.opponent-prep__venue strong { display: block; }
.opponent-prep__identity small,.opponent-prep__venue small { color: #9fb0bc; font-size: .66rem; font-weight: 900; letter-spacing: .1em; text-transform: uppercase; }
.opponent-prep__identity a { margin: .15rem 0; color: #fffaf0; font-family: 'Avenir Next Condensed',sans-serif; font-size: 1.7rem; font-weight: 900; line-height: 1; text-decoration-color: rgba(255,250,240,.35); text-underline-offset: .14em; text-transform: uppercase; }
.opponent-prep__identity p { margin: .3rem 0 0; color: #d2dce2; font-size: .78rem; }
.opponent-prep__venue { flex: 0 0 auto; max-width: 240px; text-align: right; }
.opponent-prep__venue strong { margin-top: .25rem; }
.probable-starters { display: grid; grid-template-columns: repeat(auto-fit,minmax(280px,1fr)); gap: .75rem; margin-top: .75rem; }
.probable-starters > article { padding: .9rem; border: 1px solid rgba(16,38,61,.11); border-radius: 16px; background: rgba(255,255,255,.76); }
.probable-starters > article > header { display: flex; justify-content: space-between; gap: .7rem; align-items: start; padding-bottom: .7rem; border-bottom: 1px solid rgba(16,38,61,.09); }
.probable-starters > article > header strong,.probable-starters > article > header span { display: block; }
.probable-starters > article > header span { margin-top: .15rem; color: #6d7b85; font-size: .7rem; font-weight: 800; text-transform: uppercase; }
.probable-starters > article > header a { color: #8d392e; font-size: .68rem; font-weight: 850; text-decoration: none; }
.starter-matchup { display: grid; grid-template-columns: minmax(0,1fr) auto minmax(0,1fr); gap: .6rem; align-items: center; padding-top: .75rem; }
.starter-matchup > span { color: #a93627; font-size: .65rem; font-weight: 900; text-transform: uppercase; }
.starter-matchup > div:last-child { text-align: right; }
.starter-matchup small,.starter-matchup a,.starter-matchup strong { display: block; }
.starter-matchup small { margin-bottom: .25rem; color: #71808c; font-size: .61rem; font-weight: 850; letter-spacing: .06em; text-transform: uppercase; }
.starter-matchup a,.starter-matchup strong { overflow: hidden; color: #173652; font-size: .84rem; font-weight: 850; text-overflow: ellipsis; white-space: nowrap; }
.opponent-recent { margin-top: .85rem; padding: 1rem; border: 1px solid rgba(16,38,61,.11); border-radius: 16px; background: rgba(255,255,255,.76); }
.opponent-recent > header small,.opponent-recent > header strong { display: block; }
.opponent-recent > header small,.starter-scouting > header small { color: #a93627; font-size: .64rem; font-weight: 900; letter-spacing: .1em; text-transform: uppercase; }
.opponent-recent > header strong { margin-top: .2rem; }
.opponent-recent dl { display: grid; grid-template-columns: repeat(4,minmax(0,1fr)); gap: .6rem; margin: .8rem 0 0; }
.opponent-recent dl div { padding: .7rem; border-radius: 12px; background: rgba(16,38,61,.055); }
.opponent-recent dt { color: #71808c; font-size: .62rem; font-weight: 850; text-transform: uppercase; }
.opponent-recent dd { margin: .2rem 0 0; font-family: 'Avenir Next Condensed',sans-serif; font-size: 1.35rem; font-weight: 900; }
.starter-scouting { margin-top: .85rem; padding: 1rem; border: 1px solid rgba(16,38,61,.14); border-radius: 18px; background: rgba(255,255,255,.82); }
.starter-scouting > header { display: flex; justify-content: space-between; gap: 1rem; align-items: end; padding-bottom: .8rem; border-bottom: 1px solid rgba(16,38,61,.1); }
.starter-scouting > header small,.starter-scouting > header a { display: block; }
.starter-scouting > header a { margin-top: .2rem; color: #173652; font-family: 'Avenir Next Condensed',sans-serif; font-size: 1.55rem; font-weight: 900; text-transform: uppercase; }
.starter-scouting > header > span { color: #667680; font-size: .7rem; font-weight: 850; }
.scouting-layout { display: grid; grid-template-columns: minmax(0,1.7fr) minmax(270px,.8fr); gap: .8rem; margin-top: .8rem; }
.scouting-table-wrap { overflow-x: auto; }
.scouting-layout h4 { margin: 0 0 .55rem; color: #173652; font-size: .72rem; letter-spacing: .08em; text-transform: uppercase; }
.scouting-table-wrap table { width: 100%; border-collapse: collapse; font-size: .72rem; }
.scouting-table-wrap th,.scouting-table-wrap td { padding: .55rem .45rem; border-top: 1px solid rgba(16,38,61,.09); text-align: right; white-space: nowrap; }
.scouting-table-wrap th:first-child { text-align: left; }
.scouting-table-wrap tbody th small { display: block; color: #7a858d; font-size: .58rem; }
.scouting-table-wrap td:last-child { max-width: 170px; white-space: normal; }
.evidence-link { display: block; margin-top: .2rem; color: #8d392e; font-size: .62rem; font-weight: 800; text-decoration: none; }
.evidence-link:hover { text-decoration: underline; }
.scouting-side { display: grid; gap: .7rem; }
.scouting-side > article { padding: .8rem; border-radius: 13px; background: rgba(16,38,61,.05); }
.scouting-side dl { margin: 0; }
.scouting-side dl > div + div { margin-top: .65rem; padding-top: .65rem; border-top: 1px solid rgba(16,38,61,.09); }
.scouting-side dt { font-size: .68rem; font-weight: 900; }
.scouting-side dd { margin: .15rem 0 0; color: #526573; font-size: .68rem; line-height: 1.4; }
.scouting-side ul { margin: 0; padding: 0; list-style: none; }
.scouting-side li { display: grid; grid-template-columns: minmax(0,1fr) auto; gap: .3rem .6rem; padding: .45rem 0; border-top: 1px solid rgba(16,38,61,.08); font-size: .68rem; }
.scouting-side li:first-child { border-top: 0; }
.scouting-side li .evidence-link { grid-column: 1 / -1; }
.scouting-side .is-up { color: #1b6d45; }
.scouting-side .is-down { color: #9b3328; }
.scouting-side article > p { margin: 0; color: #6f7d86; font-size: .68rem; line-height: 1.45; }
.performance-panel h3 { margin: 0 0 .55rem; font-size: .9rem; letter-spacing: .05em; text-transform: uppercase; color: #5f6c76; }
.analytics-coverage-warning { display: flex; gap: .35rem; flex-direction: column; margin-top: 1rem; padding: .75rem .9rem; border: 1px solid #d89a32; border-radius: 12px; color: #68420d; background: #fff4d8; }
.analytics-coverage-warning span { font-size: .86rem; }
.ranking-scale-note { display: flex; gap: .45rem; align-items: center; margin: 1rem 0 0; color: #69757e; font-size: .72rem; }
.ranking-scale-note i { display: block; width: 34px; height: 7px; border-radius: 999px; background: linear-gradient(90deg, #10263d, #1d4d73); }
.ranking-grid { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 1rem; margin-top: 1rem; }
.ranking-card { min-width: 0; padding: 1.1rem; border: 1px solid #d9d7ce; border-radius: 20px; background: rgba(255,255,255,.78); box-shadow: 0 10px 28px rgba(16,38,61,.055); }
.ranking-card__heading { display: flex; justify-content: space-between; gap: 1rem; align-items: end; padding: 0 .15rem .85rem; border-bottom: 1px solid #e4e1d9; }
.performance-panel .ranking-card__heading h3 { margin: 0; color: #10263d; font-family: 'Avenir Next Condensed', sans-serif; font-size: 1.35rem; letter-spacing: .065em; }
.ranking-card__heading span { width: 52px; color: #68747e; font-size: .66rem; font-weight: 900; letter-spacing: .08em; text-align: center; text-transform: uppercase; }
.ranking-card__metrics { display: grid; gap: .9rem; padding-top: 1rem; }
.ranking-row { display: grid; grid-template-columns: 82px minmax(0, 1fr) 52px; gap: .7rem; align-items: center; }
.ranking-row__label { color: #253d51; font-size: .83rem; }
.ranking-bar { position: relative; height: 42px; overflow: hidden; border: 1px solid rgba(16,38,61,.07); border-radius: 10px; background: linear-gradient(180deg, #edf0f2, #e3e7e9); box-shadow: inset 0 1px 4px rgba(16,38,61,.08); }
.ranking-bar__fill { position: absolute; inset: 0 auto 0 0; display: block; border-radius: 9px; background: linear-gradient(90deg, #10263d, #1d4d73); box-shadow: inset 0 0 0 1px rgba(255,255,255,.08); transition: width .35s ease; }
.ranking-bar__value { position: absolute; z-index: 1; top: 50%; padding: .18rem .42rem; border-radius: 7px; color: #fff; background: rgba(8,25,42,.28); font-family: 'Avenir Next Condensed', sans-serif; font-size: 1rem; font-weight: 900; line-height: 1; white-space: nowrap; transform: translate(-100%, -50%); }
.ranking-bar__value--outside { color: #10263d; background: transparent; transform: translate(.35rem, -50%); }
.ranking-row__rank { color: #10263d; font-family: 'Avenir Next Condensed', sans-serif; font-size: 1.35rem; text-align: center; }
.performance-grid { display: grid; gap: .75rem; grid-template-columns: repeat(3, minmax(0, 1fr)); margin-top: 1rem; }
.performance-grid article, .signals-grid article, .drilldown-grid article { padding: .75rem; border: 1px solid #e3dfd7; border-radius: 14px; background: rgba(255,255,255,.66); }
.performance-grid dl { margin: 0; display: grid; gap: .35rem; }
.performance-grid dt { color: #6f7981; font-size: .72rem; font-weight: 700; }
.performance-grid dd { margin: 0; color: #1d3448; font-weight: 700; }
.signals-grid, .drilldown-grid { display: grid; gap: .75rem; margin-top: .85rem; grid-template-columns: repeat(2, minmax(0, 1fr)); }
.signals-grid ul, .drilldown-grid ul { margin: 0; padding-left: 1rem; color: #445767; }
.signals-grid li, .drilldown-grid li { margin: .22rem 0; }
.drilldown-grid a { color: #173652; font-weight: 750; text-decoration-color: rgba(23,54,82,.3); text-underline-offset: .15em; }
.team-panel > header { display: flex; justify-content: space-between; align-items: end; gap: 1rem; padding-bottom: 1rem; border-bottom: 1px solid #e2e0d8; }
.team-panel h2 { margin: .12rem 0 0; font-family: 'Avenir Next Condensed', sans-serif; font-size: 2rem; text-transform: uppercase; }
.team-panel header > span { color: #778087; font-size: .75rem; }
.game-list { margin: 0; padding: 0; list-style: none; }
.game-list li { display: grid; grid-template-columns: 82px 1fr auto; gap: .9rem; align-items: center; padding: .85rem 0; border-bottom: 1px solid #ece9e1; }
.game-list li:last-child { border-bottom: 0; }
.game-list li.game-list__linked { display: block; padding: 0; }
.game-result-link { display: grid; grid-template-columns: 82px 1fr auto; gap: .9rem; align-items: center; padding: .85rem 0; color: inherit; text-decoration: none; }
.game-result-link:hover strong,.game-result-link:focus-visible strong { color: #a93627; }
.game-list time, .game-list small { color: #69747c; font-size: .76rem; }
.game-list strong, .game-list span { display: block; }
.game-list span { margin-top: .15rem; color: #758088; font-size: .75rem; }
.result { display: grid; place-items: center; width: 30px; height: 30px; border-radius: 50%; color: white; font-size: .75rem; }
.result--w { background: #176044; } .result--l { background: #9c382c; } .result--t { background: #69747c; }
.roster-panel { margin-top: 0; }
.roster-view-controls { display: flex; gap: .8rem; align-items: center; }
.roster-view-controls > div { display: inline-flex; padding: .2rem; border-radius: 999px; background: #e9e6dd; }
.roster-view-controls button { display: inline-flex; gap: .35rem; align-items: center; padding: .42rem .7rem; border: 0; border-radius: 999px; color: #5c6871; background: transparent; font: inherit; font-size: .72rem; font-weight: 800; cursor: pointer; }
.roster-view-controls button span { display: grid; place-items: center; min-width: 20px; height: 20px; padding: 0 .3rem; border-radius: 999px; color: inherit; background: rgba(16,38,61,.09); font-size: .64rem; }
.roster-view-controls button.is-selected { color: #fffaf0; background: #10263d; box-shadow: 0 3px 10px rgba(16,38,61,.18); }
.roster-view-controls button.is-selected span { background: rgba(255,255,255,.16); }
.roster-view-controls > small { color: #778087; font-size: .7rem; white-space: nowrap; }
.roster-table-wrap { overflow-x: auto; }
table { width: 100%; border-collapse: collapse; }
th, td { padding: .75rem .8rem; border-bottom: 1px solid #e8e5dd; text-align: left; }
th { color: #69747c; font-size: .68rem; letter-spacing: .08em; text-transform: uppercase; }
.roster-player { display: inline-flex; align-items: center; gap: .7rem; color: #10263d; text-decoration: none; }
.roster-player:hover strong { color: #a93627; }
.roster-headshot { display: grid; place-items: center; width: 42px; height: 42px; overflow: hidden; border-radius: 50%; color: white; background: #10263d; }
.roster-headshot img { width: 100%; height: 100%; object-fit: cover; object-position: center 16%; }
.roster-headshot b { font-size: .72rem; }
.roster-status { display: inline-block; padding: .3rem .55rem; border-radius: 999px; color: #176044; background: #dcefe5; font-size: .7rem; font-weight: 800; }
.roster-status--injured { color: #8d392e; background: #f3dfd8; }
.team-empty { padding: 1rem 0 0; color: #758088; }
.team-freshness { display: flex; justify-content: flex-end; gap: 1.5rem; padding: 1rem; color: #727c83; font-size: .72rem; }
.team-state { margin-top: 2rem; padding: 2rem; border-radius: 20px; background: #fffaf0; }
.team-state--error { color: #8f2e23; }
.team-state button { padding: .65rem 1rem; border: 0; border-radius: 999px; color: white; background: #10263d; font-weight: 800; }
@media (max-width: 900px) { .team-hero { grid-template-columns: 100px 1fr; } .team-logo { width: 90px; height: 90px; } .team-logo img { width: 68px; height: 68px; } .season-picker { grid-column: 1 / -1; } .team-summary { grid-template-columns: 1fr 1fr; } .team-schedule-grid { grid-template-columns: 1fr; } .ranking-grid { grid-template-columns: 1fr; } .performance-grid { grid-template-columns: 1fr 1fr; } .signals-grid, .drilldown-grid { grid-template-columns: 1fr; } .roster-panel > header { align-items: flex-start; flex-direction: column; } }
@media (max-width: 900px) { .scouting-layout { grid-template-columns: 1fr; } }
@media (max-width: 560px) { .team-hero { grid-template-columns: 1fr; padding: 1.25rem; } .team-summary { grid-template-columns: 1fr; } .team-profile-tabs button { flex: 1; min-width: 0; } .team-identity h1 { font-size: 3.4rem; } .ranking-card { padding: .85rem; } .ranking-row { grid-template-columns: 68px minmax(0, 1fr) 42px; gap: .45rem; } .ranking-bar { height: 38px; } .ranking-row__label { font-size: .75rem; } .ranking-card__heading span { width: 42px; } .performance-grid { grid-template-columns: 1fr; } .game-list li,.game-result-link { grid-template-columns: 68px 1fr auto; } .roster-view-controls { width: 100%; align-items: flex-start; flex-direction: column; } }
@media (max-width: 560px) { .opponent-prep__overview,.starter-scouting > header { align-items: flex-start; flex-direction: column; } .opponent-prep__venue { max-width: none; text-align: left; } .opponent-recent dl { grid-template-columns: 1fr 1fr; } }
@media (max-width: 560px) { .lineup-evaluation { grid-template-columns: 1fr; } }
</style>
