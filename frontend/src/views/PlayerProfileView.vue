<script setup>
import { computed, ref, watch } from 'vue'

import PlayerTrendChart from '../components/PlayerTrendChart.vue'
import { usePlayerProfile } from '../composables/usePlayerProfile'
import { formatBaseballStatValue } from '../utils/baseballStatFormatting'

const props = defineProps({
  playerId: {
    type: [String, Number],
    required: true,
  },
})

const playerId = computed(() => props.playerId)
const analysisOptions = ref({ range: 'season', paWindow: 50, pitchWindow: 100 })
const customStartDate = ref('')
const customEndDate = ref('')
const { player, loading, error, refresh } = usePlayerProfile(playerId, analysisOptions)
const headshotFailed = ref(false)

watch(
  () => player.value?.profile?.headshotUrl,
  () => {
    headshotFailed.value = false
  },
)

const initials = computed(() =>
  [player.value?.firstName, player.value?.lastName]
    .filter(Boolean)
    .map((name) => name.charAt(0))
    .join(''),
)

const rosterLabel = computed(() => {
  const membership = player.value?.currentMembership
  if (!membership) return 'Roster status unavailable'
  return membership.sourceStatusDescription || titleize(membership.rosterStatus)
})

const positionLabel = computed(() => {
  const position = player.value?.positions?.primary
  return position ? `${position.abbreviation} · ${position.name}` : 'Position unavailable'
})

const careerRangeLabel = computed(() => {
  const career = player.value?.careerOverview
  if (!career?.firstSeason) return 'No seasons stored'

  const range = career.firstSeason === career.lastSeason
    ? String(career.firstSeason)
    : `${career.firstSeason}–${career.lastSeason}`
  const seasonLabel = career.seasonCount === 1 ? 'season' : 'seasons'
  return `${range} · ${career.seasonCount} ${seasonLabel}`
})

const pitchingMetrics = computed(() => [
  ['Pitches', player.value?.pitchIndicators.pitching.pitch_count],
  ['Games', player.value?.pitchIndicators.pitching.game_count],
  ['Avg velo', withUnit(player.value?.pitchIndicators.pitching.average_velocity, ' mph')],
  ['Max velo', withUnit(player.value?.pitchIndicators.pitching.max_velocity, ' mph')],
  ['Avg spin', withUnit(player.value?.pitchIndicators.pitching.average_spin_rate, ' rpm')],
  ['Strike rate', withUnit(player.value?.pitchIndicators.pitching.strike_percentage, '%')],
])

const battingMetrics = computed(() => [
  ['Pitches seen', player.value?.pitchIndicators.batting.pitches_seen],
  ['Games', player.value?.pitchIndicators.batting.game_count],
  ['Batted balls', player.value?.pitchIndicators.batting.batted_ball_count],
  ['Avg exit velo', withUnit(player.value?.pitchIndicators.batting.average_exit_velocity, ' mph')],
  ['Max exit velo', withUnit(player.value?.pitchIndicators.batting.max_exit_velocity, ' mph')],
  ['Hard-hit rate', withUnit(player.value?.pitchIndicators.batting.hard_hit_percentage, '%')],
])

const benchmarkPeriodLabel = computed(() => {
  const context = player.value?.contextualBenchmarks
  if (!context?.sourceStartDate || !context?.sourceEndDate) return 'No benchmark period calculated'
  return `${formatDate(context.sourceStartDate)} — ${formatDate(context.sourceEndDate)}`
})

const rangePresets = [
  { value: 'season', label: 'Full season' },
  { value: '7', label: 'Last 7 days' },
  { value: '14', label: 'Last 14 days' },
  { value: '30', label: 'Last 30 days' },
]

const comparisonMetrics = computed(() => {
  const current = player.value?.analysis?.summary?.current || {}
  const previous = player.value?.analysis?.summary?.previous || {}
  const definitions = [
    ['batting', 'average_exit_velocity', 'Exit velocity', 'mph'],
    ['batting', 'hard_hit_percentage', 'Hard-hit rate', 'percent'],
    ['batting', 'whiff_percentage', 'Batter whiff', 'percent'],
    ['batting', 'chase_percentage', 'Batter chase', 'percent'],
    ['pitching', 'average_velocity', 'Pitch velocity', 'mph'],
    ['pitching', 'whiff_percentage', 'Pitcher whiff', 'percent'],
    ['pitching', 'chase_percentage', 'Pitcher chase', 'percent'],
  ]
  return definitions
    .filter(([group]) => visibleTrendGroups.value.includes(group))
    .map(([group, key, label, unit]) => {
    const currentValue = current[group]?.[key]
    const previousValue = previous[group]?.[key]
    return {
      key: `${group}-${key}`,
      label,
      unit,
      current: currentValue,
      previous: previousValue,
      change: currentValue === null || currentValue === undefined || previousValue === null || previousValue === undefined
        ? null
        : Number(currentValue) - Number(previousValue),
    }
  })
})

const visibleTrendGroups = computed(() => {
  if (!player.value) return []

  if (isTwoWayPlayer(player.value)) return ['batting', 'pitching']

  const primaryPositionType = player.value?.positions?.primary?.position_type
  if (primaryPositionType === 'pitcher') return ['pitching']
  if (primaryPositionType) return ['batting']

  return player.value?.pitchIndicators?.primaryRole === 'pitcher' ? ['pitching'] : ['batting']
})

const showBattingIndicators = computed(() => visibleTrendGroups.value.includes('batting'))
const showPitchingIndicators = computed(() => visibleTrendGroups.value.includes('pitching'))

const trendCharts = computed(() => {
  const analysis = player.value?.analysis
  if (!analysis) return []
  const charts = []

  if (visibleTrendGroups.value.includes('batting')) {
    charts.push(
      ...(analysis.batting?.charts || []).map((chart) => ({
        ...chart,
        subtitle: `Rolling ${analysis.batting.windowSize} plate appearances`,
        group: 'Batting',
      })),
    )
  }

  if (visibleTrendGroups.value.includes('pitching')) {
    charts.push(
      ...(analysis.pitching?.charts || []).map((chart) => ({
        ...chart,
        subtitle: `Rolling ${analysis.pitching.windowSize} pitches`,
        group: 'Pitching',
      })),
    )
  }

  return charts
})

function isTwoWayPlayer(playerData) {
  const primaryPositionType = playerData?.positions?.primary?.position_type
  if (primaryPositionType === 'two_way') return true

  const currentAssignments = (playerData?.positions?.assignments || []).filter((assignment) => assignment.current)
  const hasPitchingAssignment = currentAssignments.some((assignment) => assignment.position?.position_type === 'pitcher')
  const hasNonPitchingAssignment = currentAssignments.some((assignment) => {
    const type = assignment.position?.position_type
    return type && type !== 'pitcher'
  })

  return hasPitchingAssignment && hasNonPitchingAssignment
}

function selectPreset(range) {
  analysisOptions.value = { ...analysisOptions.value, range, startDate: null, endDate: null }
}

function applyCustomRange() {
  if (!customStartDate.value || !customEndDate.value) return
  analysisOptions.value = {
    ...analysisOptions.value,
    range: 'custom',
    startDate: customStartDate.value,
    endDate: customEndDate.value,
  }
}

function updateWindow(key, value) {
  analysisOptions.value = { ...analysisOptions.value, [key]: Number(value) }
}

function titleize(value) {
  return String(value || '')
    .replaceAll('_', ' ')
    .replace(/\b\w/g, (letter) => letter.toUpperCase())
}

function withUnit(value, unit) {
  return value === null || value === undefined ? null : `${value}${unit}`
}

function displayValue(value) {
  return value === null || value === undefined || value === '' ? '—' : value
}

function contextualMetricLabel(metric) {
  return metric.dimensionValue ? `${metric.displayName} · ${metric.dimensionValue}` : metric.displayName
}

function contextualValue(value, unit) {
  if (value === null || value === undefined) return '—'
  if (unit === 'percent') return `${Number(value).toFixed(1)}%`
  if (unit === 'mph') return `${Number(value).toFixed(1)} mph`
  if (unit === 'rpm') return `${Math.round(Number(value)).toLocaleString()} rpm`
  return Number(value).toFixed(3)
}

function signedContextualValue(value, unit) {
  if (value === null || value === undefined) return '—'
  const prefix = Number(value) > 0 ? '+' : ''
  return `${prefix}${contextualValue(value, unit)}`
}

function peerAverage(metric) {
  return metric.positionAverage ?? metric.pitcherRoleAverage
}

function peerLabel(metric) {
  if (metric.positionAverage !== null && metric.positionAverage !== undefined) return metric.positionKey || 'Position'
  if (metric.pitcherRoleAverage !== null && metric.pitcherRoleAverage !== undefined) return titleize(metric.pitcherRoleKey || 'Role')
  return 'Peer group unavailable'
}

function seasonTeamLabel(seasonRow) {
  const abbreviations = (seasonRow.teams || []).map((team) => team?.abbreviation).filter(Boolean)
  return abbreviations.length ? [...new Set(abbreviations)].join(' / ') : '—'
}

function formatDate(value) {
  if (!value) return '—'
  return new Intl.DateTimeFormat('en-US', { month: 'short', day: 'numeric', year: 'numeric' }).format(
    new Date(`${value}T12:00:00`),
  )
}

function formatTimestamp(value) {
  if (!value) return 'Unavailable'
  return new Intl.DateTimeFormat('en-US', {
    month: 'short',
    day: 'numeric',
    year: 'numeric',
    hour: 'numeric',
    minute: '2-digit',
  }).format(new Date(value))
}
</script>

<template>
  <main class="profile-shell">
    <div v-if="loading" class="profile-state" data-test="profile-loading">
      <span class="loading-ball" aria-hidden="true"></span>
      <strong>Building player profile…</strong>
    </div>

    <div v-else-if="error" class="profile-state profile-state--error" data-test="profile-error">
      <p>{{ error }}</p>
      <button type="button" class="profile-button" @click="refresh">Try again</button>
    </div>

    <template v-else-if="player">
      <RouterLink class="profile-back" :to="{ name: 'stat-explorer' }">← Back to Stat Explorer</RouterLink>

      <section class="profile-hero">
        <div
          class="profile-portrait"
          :class="{ 'profile-portrait--photo': player.profile?.headshotUrl && !headshotFailed }"
        >
          <img
            v-if="player.profile?.headshotUrl && !headshotFailed"
            :src="player.profile.headshotUrl"
            :alt="`${player.fullName} headshot`"
            @error="headshotFailed = true"
          />
          <span v-else>{{ initials }}</span>
        </div>

        <div class="profile-identity">
          <p class="eyebrow">Unified player profile · MLB {{ player.mlbId }}</p>
          <h1>{{ player.fullName }}</h1>
          <p class="profile-teamline">
            <strong>
              <RouterLink
                v-if="player.currentMembership?.team?.id || player.team?.id"
                :to="{ name: 'team-profile', params: { id: player.currentMembership?.team?.id || player.team?.id } }"
              >
                {{ player.currentMembership?.team?.name || player.team?.name }}
              </RouterLink>
              <template v-else>Team unavailable</template>
            </strong>
            <span>{{ positionLabel }}</span>
            <span v-if="player.currentMembership?.jerseyNumber">#{{ player.currentMembership.jerseyNumber }}</span>
          </p>
          <div class="profile-status" :class="{ 'profile-status--injured': player.currentMembership?.injured }">
            <span class="profile-status__dot"></span>
            {{ rosterLabel }}
          </div>
        </div>

        <dl class="profile-bio">
          <div>
            <dt>Bats / Throws</dt>
            <dd>{{ displayValue(player.profile?.bats) }} / {{ displayValue(player.profile?.throws) }}</dd>
          </div>
          <div>
            <dt>Size</dt>
            <dd>{{ displayValue(player.profile?.formattedHeight) }} · {{ displayValue(player.profile?.weightPounds) }} lb</dd>
          </div>
          <div>
            <dt>Born</dt>
            <dd>{{ formatDate(player.profile?.birthDate) }}<span v-if="player.profile?.age"> · Age {{ player.profile.age }}</span></dd>
          </div>
          <div>
            <dt>MLB debut</dt>
            <dd>{{ formatDate(player.profile?.mlbDebutDate) }}</dd>
          </div>
        </dl>
      </section>

      <section class="profile-panel profile-career-table">
        <header class="profile-section-heading">
          <div>
            <p class="eyebrow">Career ledger</p>
            <h2>{{ titleize(player.careerOverview.category) }} by season</h2>
          </div>
          <span>{{ careerRangeLabel }}</span>
        </header>

        <div v-if="player.careerOverview.seasons.length" class="career-table-wrap" data-test="career-season-table">
          <table class="career-table">
            <thead>
              <tr>
                <th class="career-table__season">Season</th>
                <th class="career-table__team">Team</th>
                <th v-for="column in player.careerOverview.columns" :key="column.key" class="career-table__stat">
                  {{ column.label }}
                </th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="seasonRow in player.careerOverview.seasons" :key="seasonRow.season">
                <th class="career-table__season">{{ seasonRow.season }}</th>
                <td class="career-table__team">{{ seasonTeamLabel(seasonRow) }}</td>
                <td v-for="column in player.careerOverview.columns" :key="column.key" class="career-table__stat">
                  {{ formatBaseballStatValue(column.key, seasonRow.statValues[column.key]) }}
                </td>
              </tr>
            </tbody>
            <tfoot>
              <tr>
                <th class="career-table__season">Career</th>
                <td class="career-table__team">Total</td>
                <td v-for="column in player.careerOverview.columns" :key="column.key" class="career-table__stat">
                  {{ formatBaseballStatValue(column.key, player.careerOverview.statValues[column.key]) }}
                </td>
              </tr>
            </tfoot>
          </table>
        </div>
        <p v-else class="profile-empty">No season statistics have been imported for this player yet.</p>
      </section>

      <section class="profile-panel analysis-controls" data-test="player-date-range-controls">
        <div>
          <p class="eyebrow">Analysis period</p>
          <div class="range-presets" role="group" aria-label="Player analysis range">
            <button v-for="preset in rangePresets" :key="preset.value" type="button"
              :class="{ 'is-active': analysisOptions.range === preset.value }" @click="selectPreset(preset.value)">
              {{ preset.label }}
            </button>
          </div>
        </div>
        <div class="custom-range">
          <label>From <input v-model="customStartDate" type="date" /></label>
          <label>Through <input v-model="customEndDate" type="date" /></label>
          <button type="button" :disabled="!customStartDate || !customEndDate" @click="applyCustomRange">Apply custom</button>
        </div>
        <div class="rolling-window-controls">
          <label>
            Batting window
            <select :value="analysisOptions.paWindow" @change="updateWindow('paWindow', $event.target.value)">
              <option :value="25">25 PA</option>
              <option :value="50">50 PA</option>
              <option :value="100">100 PA</option>
            </select>
          </label>
          <label>
            Pitching window
            <select :value="analysisOptions.pitchWindow" @change="updateWindow('pitchWindow', $event.target.value)">
              <option :value="50">50 pitches</option>
              <option :value="100">100 pitches</option>
              <option :value="250">250 pitches</option>
            </select>
          </label>
        </div>
      </section>

      <section class="profile-panel trend-panel" data-test="player-trends">
        <header class="profile-section-heading">
          <div>
            <p class="eyebrow">Rolling intelligence</p>
            <h2>Performance trends</h2>
          </div>
          <span v-if="player.analysis?.range?.startDate">
            {{ formatDate(player.analysis.range.startDate) }} — {{ formatDate(player.analysis.range.endDate) }}
          </span>
        </header>

        <div class="period-comparison">
          <article v-for="metric in comparisonMetrics" :key="metric.key">
            <span>{{ metric.label }}</span>
            <strong>{{ contextualValue(metric.current, metric.unit) }}</strong>
            <small>
              Previous {{ contextualValue(metric.previous, metric.unit) }} ·
              {{ signedContextualValue(metric.change, metric.unit) }}
            </small>
          </article>
        </div>

        <div v-if="trendCharts.length" class="trend-grid">
          <PlayerTrendChart v-for="chart in trendCharts" :key="`${chart.group}-${chart.key}`"
            :title="`${chart.group} · ${chart.title}`" :subtitle="chart.subtitle" :unit="chart.unit" :series="chart.series" />
        </div>
        <p v-else class="profile-empty">No pitch-level trend data is available for this period.</p>
      </section>

      <section class="profile-panel contextual-panel" data-test="contextual-benchmarks">
        <header class="profile-section-heading">
          <div>
            <p class="eyebrow">P1.5 context</p>
            <h2>Benchmarks & percentiles</h2>
          </div>
          <span>{{ benchmarkPeriodLabel }}</span>
        </header>

        <div v-if="player.contextualBenchmarks.metrics.length" class="context-table-wrap">
          <table class="context-table">
            <thead>
              <tr>
                <th>Metric</th>
                <th>Player</th>
                <th>MLB average</th>
                <th>Position / role</th>
                <th>Percentile</th>
                <th>Previous-period change</th>
                <th>Sample</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="metric in player.contextualBenchmarks.metrics" :key="`${metric.metricKey}-${metric.dimensionValue || 'all'}`">
                <th>
                  <strong>{{ contextualMetricLabel(metric) }}</strong>
                  <small>{{ titleize(metric.metricGroup) }}</small>
                </th>
                <td><strong>{{ contextualValue(metric.rawValue, metric.unit) }}</strong></td>
                <td>
                  {{ contextualValue(metric.mlbAverage, metric.unit) }}
                  <small>{{ metric.mlbPlayerCount }} players</small>
                </td>
                <td>
                  {{ contextualValue(peerAverage(metric), metric.unit) }}
                  <small>{{ peerLabel(metric) }}</small>
                </td>
                <td>
                  <span class="percentile-pill">P{{ Math.round(metric.percentile) }}</span>
                </td>
                <td>
                  {{ signedContextualValue(metric.changeValue, metric.unit) }}
                  <small v-if="metric.previousValue !== null && metric.previousValue !== undefined">
                    from {{ contextualValue(metric.previousValue, metric.unit) }}
                  </small>
                </td>
                <td>{{ Number(metric.sampleSize || 0).toLocaleString() }}</td>
              </tr>
            </tbody>
          </table>
        </div>
        <p v-else class="profile-empty">
          Benchmark context will appear after daily analytics have been calculated for multiple players.
        </p>
      </section>

      <div class="profile-two-column">
        <section class="profile-panel">
          <header class="profile-section-heading">
            <div>
              <p class="eyebrow">Statcast pulse</p>
              <h2>Recent pitch indicators</h2>
            </div>
            <span>Latest {{ player.pitchIndicators.sampleSize }} per role</span>
          </header>

          <div class="indicator-groups">
            <article
              v-if="showBattingIndicators"
              class="indicator-card"
              data-test="indicator-card-batting"
              :class="{ 'indicator-card--primary': player.pitchIndicators.primaryRole === 'batter' }"
            >
              <h3>As batter</h3>
              <dl>
                <div v-for="metric in battingMetrics" :key="metric[0]">
                  <dt>{{ metric[0] }}</dt>
                  <dd>{{ displayValue(metric[1]) }}</dd>
                </div>
              </dl>
            </article>
            <article
              v-if="showPitchingIndicators"
              class="indicator-card"
              data-test="indicator-card-pitching"
              :class="{ 'indicator-card--primary': player.pitchIndicators.primaryRole === 'pitcher' }"
            >
              <h3>As pitcher</h3>
              <dl>
                <div v-for="metric in pitchingMetrics" :key="metric[0]">
                  <dt>{{ metric[0] }}</dt>
                  <dd>{{ displayValue(metric[1]) }}</dd>
                </div>
              </dl>
            </article>
          </div>
        </section>

        <section class="profile-panel">
          <header class="profile-section-heading">
            <div>
              <p class="eyebrow">Organization trail</p>
              <h2>Team history</h2>
            </div>
            <span>{{ player.teamHistory.length }} membership windows</span>
          </header>

          <ol v-if="player.teamHistory.length" class="team-timeline">
            <li v-for="membership in player.teamHistory" :key="membership.id">
              <span class="team-timeline__mark"></span>
              <div>
                <strong>
                  <RouterLink v-if="membership.team?.id" :to="{ name: 'team-profile', params: { id: membership.team.id } }">
                    {{ membership.team.name }}
                  </RouterLink>
                </strong>
                <span>{{ formatDate(membership.startsOn) }} — {{ membership.endsOn ? formatDate(membership.endsOn) : 'Present' }}</span>
              </div>
              <small>{{ membership.sourceStatusDescription || titleize(membership.rosterStatus) }}</small>
            </li>
          </ol>
          <p v-else class="profile-empty">No dated team history has been synchronized.</p>
        </section>
      </div>

      <section class="profile-panel profile-sources">
        <header class="profile-section-heading">
          <div>
            <p class="eyebrow">Data provenance</p>
            <h2>Sources & freshness</h2>
          </div>
          <span>Profile updated {{ formatTimestamp(player.sourceMetadata.lastUpdatedAt) }}</span>
        </header>
        <div class="source-grid">
          <article v-for="dataset in player.sourceMetadata.datasets" :key="dataset.name">
            <strong>{{ titleize(dataset.name) }}</strong>
            <span>{{ dataset.sourceName || 'DiamondIQ' }}</span>
            <small>{{ formatTimestamp(dataset.lastUpdatedAt) }}</small>
          </article>
        </div>
      </section>
    </template>
  </main>
</template>

<style scoped>
.profile-shell {
  min-height: calc(100vh - 74px);
  padding: 2.5rem 1.25rem 5rem;
  background:
    radial-gradient(circle at 12% 0%, rgba(151, 38, 31, 0.18), transparent 27%),
    radial-gradient(circle at 92% 10%, rgba(24, 77, 116, 0.2), transparent 28%),
    linear-gradient(180deg, #f7f1e3, #ead8b6);
}

.profile-shell > * {
  width: min(1420px, calc(100vw - 2.5rem));
  margin-inline: auto;
}

.profile-back {
  display: inline-flex;
  width: auto;
  margin-bottom: 1rem;
  color: #6d2a25;
  font-weight: 700;
  text-decoration: none;
}

.profile-hero,
.profile-panel {
  border: 1px solid rgba(16, 38, 61, 0.13);
  border-radius: 28px;
  background: rgba(255, 252, 244, 0.91);
  box-shadow: 0 20px 58px rgba(64, 43, 20, 0.11);
}

.analysis-controls {
  display: grid;
  grid-template-columns: minmax(320px, 1fr) auto auto;
  gap: 1.25rem;
  align-items: end;
}

.range-presets {
  display: flex;
  flex-wrap: wrap;
  gap: 0.45rem;
  margin-top: 0.45rem;
}

.range-presets button,
.custom-range button {
  padding: 0.55rem 0.8rem;
  border: 1px solid rgba(16, 38, 61, 0.16);
  border-radius: 999px;
  color: #405362;
  background: #fffdf7;
  font-weight: 800;
  cursor: pointer;
}

.range-presets button.is-active {
  border-color: #8f2d24;
  color: #fffaf0;
  background: #8f2d24;
}

.custom-range,
.rolling-window-controls {
  display: flex;
  gap: 0.6rem;
  align-items: end;
}

.custom-range label,
.rolling-window-controls label {
  display: grid;
  gap: 0.25rem;
  color: #697784;
  font-size: 0.7rem;
  font-weight: 800;
  letter-spacing: 0.04em;
  text-transform: uppercase;
}

.custom-range input,
.rolling-window-controls select {
  min-height: 38px;
  padding: 0.4rem 0.55rem;
  border: 1px solid rgba(16, 38, 61, 0.16);
  border-radius: 10px;
  color: #10263d;
  background: #fffdf7;
  font: inherit;
}

.custom-range button:disabled {
  opacity: 0.45;
  cursor: not-allowed;
}

.period-comparison {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(145px, 1fr));
  gap: 0.65rem;
  margin-bottom: 1rem;
}

.period-comparison article {
  display: flex;
  min-height: 100px;
  flex-direction: column;
  padding: 0.8rem;
  border-radius: 15px;
  background: rgba(16, 38, 61, 0.045);
}

.period-comparison span,
.period-comparison small {
  color: #71808c;
  font-size: 0.68rem;
}

.period-comparison span {
  font-weight: 900;
  letter-spacing: 0.05em;
  text-transform: uppercase;
}

.period-comparison strong {
  margin-block: auto;
  color: #10263d;
  font-size: 1.25rem;
}

.trend-grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 0.85rem;
}

.profile-hero {
  display: grid;
  grid-template-columns: 170px minmax(0, 1.2fr) minmax(280px, 0.7fr);
  gap: 2rem;
  align-items: center;
  padding: 2rem;
}

.profile-portrait {
  position: relative;
  display: grid;
  place-items: center;
  overflow: hidden;
  aspect-ratio: 1;
  border: 5px solid rgba(255, 255, 255, 0.85);
  border-radius: 50%;
  color: #fff7e7;
  background: linear-gradient(145deg, #153a59, #8f2d24);
  box-shadow: 0 12px 28px rgba(16, 38, 61, 0.2);
  font-family: 'Avenir Next Condensed', sans-serif;
  font-size: 3rem;
  font-weight: 800;
}

.profile-portrait img {
  position: absolute;
  inset: 0;
  width: 100%;
  height: 100%;
  object-fit: cover;
  object-position: center;
}

.profile-portrait--photo {
  background: #c9c9c9;
}

.profile-identity h1 {
  color: #10263d;
  font-family: 'Avenir Next Condensed', 'DIN Condensed', sans-serif;
  font-size: clamp(2.8rem, 5vw, 5.8rem);
  line-height: 0.9;
  letter-spacing: -0.025em;
  text-transform: uppercase;
}

.profile-teamline {
  display: flex;
  flex-wrap: wrap;
  gap: 0.45rem 0.8rem;
  margin-top: 1rem;
  color: #455563;
}

.profile-teamline a,
.team-timeline a {
  color: inherit;
  text-decoration-color: #b79569;
  text-underline-offset: 0.18em;
}

.profile-teamline a:hover,
.team-timeline a:hover {
  color: #8f2d24;
}

.profile-teamline span::before {
  margin-right: 0.8rem;
  color: #b79569;
  content: '•';
}

.profile-status {
  display: inline-flex;
  align-items: center;
  gap: 0.5rem;
  margin-top: 1rem;
  padding: 0.4rem 0.8rem;
  border-radius: 999px;
  color: #20543c;
  background: #e1f0e5;
  font-size: 0.84rem;
  font-weight: 800;
  text-transform: uppercase;
}

.profile-status--injured {
  color: #7d291f;
  background: #f5ddd5;
}

.profile-status__dot {
  width: 0.55rem;
  height: 0.55rem;
  border-radius: 50%;
  background: currentColor;
}

.profile-bio {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 1rem;
  padding: 1.2rem;
  border-radius: 20px;
  background: rgba(16, 38, 61, 0.055);
}

.profile-bio dt,
.indicator-card dt {
  color: #71808c;
  font-size: 0.72rem;
  font-weight: 800;
  letter-spacing: 0.08em;
  text-transform: uppercase;
}

.profile-bio dd {
  color: #10263d;
  font-weight: 700;
}

.profile-panel {
  margin-top: 1.25rem;
  padding: 1.5rem;
}

.profile-section-heading {
  display: flex;
  justify-content: space-between;
  gap: 1rem;
  align-items: flex-start;
  margin-bottom: 1.3rem;
}

.profile-section-heading h2 {
  color: #10263d;
  font-family: 'Avenir Next Condensed', sans-serif;
  font-size: clamp(1.7rem, 2.4vw, 2.5rem);
  line-height: 1;
  text-transform: uppercase;
}

.profile-section-heading > span {
  color: #697784;
  font-size: 0.85rem;
}

.profile-stat-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(110px, 1fr));
  gap: 0.7rem;
}

.profile-stat {
  display: flex;
  flex-direction: column;
  min-height: 116px;
  padding: 0.9rem;
  border: 1px solid rgba(16, 38, 61, 0.08);
  border-radius: 16px;
  background: #fffdf7;
}

.profile-stat span,
.profile-stat small {
  color: #71808c;
  font-size: 0.72rem;
  font-weight: 800;
  text-transform: uppercase;
}

.profile-stat strong {
  margin-block: auto;
  color: #8f2d24;
  font-family: 'Avenir Next Condensed', sans-serif;
  font-size: 2rem;
}

.career-table-wrap {
  overflow-x: auto;
  border: 1px solid rgba(16, 38, 61, 0.1);
  border-radius: 16px;
  background: #fffdf7;
}

.career-table {
  width: 100%;
  min-width: 1120px;
  border-collapse: separate;
  border-spacing: 0;
  color: #243b50;
  font-variant-numeric: tabular-nums;
}

.career-table th,
.career-table td {
  padding: 0.72rem 0.78rem;
  border-bottom: 1px solid rgba(16, 38, 61, 0.08);
  text-align: right;
  white-space: nowrap;
}

.career-table thead th {
  color: #697784;
  background: #e7edf1;
  font-size: 0.68rem;
  font-weight: 900;
  letter-spacing: 0.06em;
  text-transform: uppercase;
}

.career-table tbody tr:nth-child(even) td,
.career-table tbody tr:nth-child(even) th {
  background: #faf5ea;
}

.career-table tbody th {
  color: #10263d;
  font-weight: 900;
}

.career-table__season,
.career-table__team {
  position: sticky;
  z-index: 1;
  text-align: left !important;
  background: #fffdf7;
}

.career-table__season {
  left: 0;
  width: 82px;
  min-width: 82px;
}

.career-table__team {
  left: 82px;
  width: 100px;
  min-width: 100px;
  border-right: 1px solid rgba(16, 38, 61, 0.1);
}

.career-table thead .career-table__season,
.career-table thead .career-table__team {
  z-index: 2;
  background: #e7edf1;
}

.career-table tfoot th,
.career-table tfoot td {
  border-bottom: 0;
  color: #fffaf0;
  background: #10263d;
  font-weight: 900;
}

.career-table tfoot .career-table__season,
.career-table tfoot .career-table__team {
  z-index: 2;
  background: #10263d;
}

.context-table-wrap {
  overflow-x: auto;
  border: 1px solid rgba(16, 38, 61, 0.1);
  border-radius: 16px;
  background: #fffdf7;
}

.context-table {
  width: 100%;
  min-width: 1040px;
  border-collapse: collapse;
  color: #243b50;
  font-variant-numeric: tabular-nums;
}

.context-table th,
.context-table td {
  padding: 0.8rem;
  border-bottom: 1px solid rgba(16, 38, 61, 0.08);
  text-align: right;
  vertical-align: middle;
  white-space: nowrap;
}

.context-table thead th {
  color: #697784;
  background: #e7edf1;
  font-size: 0.68rem;
  letter-spacing: 0.06em;
  text-transform: uppercase;
}

.context-table th:first-child {
  text-align: left;
}

.context-table tbody th strong,
.context-table tbody th small,
.context-table td small {
  display: block;
}

.context-table tbody th small,
.context-table td small {
  margin-top: 0.15rem;
  color: #71808c;
  font-size: 0.7rem;
}

.context-table tbody tr:last-child th,
.context-table tbody tr:last-child td {
  border-bottom: 0;
}

.percentile-pill {
  display: inline-flex;
  min-width: 3.25rem;
  justify-content: center;
  padding: 0.32rem 0.55rem;
  border-radius: 999px;
  color: #fffaf0;
  background: #8f2d24;
  font-weight: 900;
}

.profile-two-column {
  display: grid;
  grid-template-columns: 1.2fr 0.8fr;
  gap: 1.25rem;
}

.indicator-groups {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 0.85rem;
}

.indicator-card {
  padding: 1rem;
  border: 1px solid rgba(16, 38, 61, 0.1);
  border-radius: 18px;
  background: rgba(16, 38, 61, 0.035);
}

.indicator-card--primary {
  border-color: rgba(143, 45, 36, 0.28);
  background: rgba(143, 45, 36, 0.055);
}

.indicator-card h3 {
  margin-bottom: 0.75rem;
  color: #10263d;
  font-family: 'Avenir Next Condensed', sans-serif;
  font-size: 1.25rem;
  text-transform: uppercase;
}

.indicator-card dl {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 0.75rem;
}

.indicator-card dd {
  color: #10263d;
  font-size: 1.1rem;
  font-weight: 800;
}

.team-timeline {
  display: grid;
  gap: 0;
  list-style: none;
}

.team-timeline li {
  position: relative;
  display: grid;
  grid-template-columns: 18px minmax(0, 1fr) auto;
  gap: 0.75rem;
  padding-bottom: 1.25rem;
}

.team-timeline li:not(:last-child)::before {
  position: absolute;
  top: 14px;
  bottom: 0;
  left: 6px;
  width: 2px;
  background: #d5c09e;
  content: '';
}

.team-timeline__mark {
  z-index: 1;
  width: 14px;
  height: 14px;
  margin-top: 5px;
  border: 3px solid #fffaf0;
  border-radius: 50%;
  background: #8f2d24;
  box-shadow: 0 0 0 1px #8f2d24;
}

.team-timeline div,
.team-timeline strong,
.team-timeline span {
  display: block;
}

.team-timeline span,
.team-timeline small {
  color: #697784;
  font-size: 0.8rem;
}

.source-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(190px, 1fr));
  gap: 0.75rem;
}

.source-grid article {
  display: flex;
  flex-direction: column;
  padding: 0.9rem;
  border-radius: 15px;
  background: rgba(16, 38, 61, 0.045);
}

.source-grid span,
.source-grid small {
  color: #697784;
}

.profile-state {
  display: grid;
  place-items: center;
  gap: 1rem;
  min-height: 50vh;
  text-align: center;
}

.loading-ball {
  width: 42px;
  height: 42px;
  border: 2px solid #8f2d24;
  border-radius: 50%;
  background: linear-gradient(90deg, transparent 48%, #8f2d24 49%, #8f2d24 51%, transparent 52%);
  animation: spin 900ms linear infinite;
}

.profile-button {
  padding: 0.7rem 1rem;
  border: 0;
  border-radius: 999px;
  color: white;
  background: #8f2d24;
  cursor: pointer;
}

.profile-empty {
  padding: 1.25rem;
  border-radius: 16px;
  color: #697784;
  background: rgba(16, 38, 61, 0.04);
}

@keyframes spin {
  to { transform: rotate(360deg); }
}

@media (max-width: 980px) {
  .profile-hero {
    grid-template-columns: 130px 1fr;
  }

  .profile-bio {
    grid-column: 1 / -1;
  }

  .profile-two-column {
    grid-template-columns: 1fr;
  }

  .analysis-controls {
    grid-template-columns: 1fr;
    align-items: start;
  }

  .trend-grid {
    grid-template-columns: 1fr;
  }
}

@media (max-width: 640px) {
  .profile-shell {
    padding-inline: 0.75rem;
  }

  .custom-range,
  .rolling-window-controls {
    flex-wrap: wrap;
    align-items: stretch;
  }

  .profile-shell > * {
    width: min(100%, calc(100vw - 1.5rem));
  }

  .profile-hero {
    grid-template-columns: 1fr;
    text-align: center;
  }

  .profile-portrait {
    width: 120px;
    margin-inline: auto;
  }

  .profile-teamline,
  .profile-status {
    justify-content: center;
  }

  .indicator-groups,
  .profile-bio {
    grid-template-columns: 1fr;
  }

  .profile-section-heading {
    flex-direction: column;
  }
}
</style>
