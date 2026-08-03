<script setup>
import { computed, inject, ref, watch } from 'vue'
import { routeLocationKey, routerKey } from 'vue-router'

import PlayerTrendChart from '../components/PlayerTrendChart.vue'
import SavedAnalysisControls from '../components/SavedAnalysisControls.vue'
import NotesPanel from '../components/NotesPanel.vue'
import AddToWatchlistControl from '../components/AddToWatchlistControl.vue'
import { usePlayerProfile } from '../composables/usePlayerProfile'
import { formatBaseballStatValue } from '../utils/baseballStatFormatting'
import { frontendConfig } from '../config'

const props = defineProps({
  playerId: {
    type: [String, Number],
    required: true,
  },
})

const route = inject(routeLocationKey, { query: {}, fullPath: `/players/${props.playerId}` })
const router = inject(routerKey, { replace: () => {}, push: () => {} })
const playerId = computed(() => props.playerId)
const profileTabs = [
  { id: 'overview', label: 'Overview' },
  { id: 'advanced-stats', label: 'Advanced Stats' },
]
const selectedProfileTab = ref(profileTabs.some((tab) => tab.id === route.query.tab) ? route.query.tab : 'overview')
const analysisOptions = ref({
  range: ['season', '7', '14', '30', 'custom'].includes(route.query.range) ? route.query.range : 'season',
  paWindow: [25, 50, 100].includes(Number(route.query.pa_window)) ? Number(route.query.pa_window) : 50,
  pitchWindow: [50, 100, 250].includes(Number(route.query.pitch_window)) ? Number(route.query.pitch_window) : 100,
  startDate: route.query.start_date || null,
  endDate: route.query.end_date || null,
})
const customStartDate = ref(route.query.start_date || '')
const customEndDate = ref(route.query.end_date || '')
const savedAnalysisState = computed(() => ({ playerId: playerId.value, ...analysisOptions.value }))
const savedAnalysisUrl = computed(() => {
  const options = analysisOptions.value
  const query = new URLSearchParams()
  if (options.range !== 'season') query.set('range', options.range)
  if (options.paWindow !== 50) query.set('pa_window', String(options.paWindow))
  if (options.pitchWindow !== 100) query.set('pitch_window', String(options.pitchWindow))
  if (options.range === 'custom' && options.startDate && options.endDate) {
    query.set('start_date', options.startDate)
    query.set('end_date', options.endDate)
  }
  return `/players/${encodeURIComponent(playerId.value)}${query.size ? `?${query}` : ''}`
})
const { player, loading, error, refresh } = usePlayerProfile(playerId, analysisOptions)
const headshotFailed = ref(false)

watch(
  [analysisOptions, selectedProfileTab],
  ([options, tab]) => {
    const query = {}
    if (tab !== 'overview') query.tab = tab
    if (options.range !== 'season') query.range = options.range
    if (options.paWindow !== 50) query.pa_window = String(options.paWindow)
    if (options.pitchWindow !== 100) query.pitch_window = String(options.pitchWindow)
    if (options.range === 'custom' && options.startDate && options.endDate) {
      query.start_date = options.startDate
      query.end_date = options.endDate
    }
    router.replace({ name: 'player-profile', params: { id: playerId.value }, query })
  },
  { deep: true },
)

watch(
  () => [
    route.query.tab,
    route.query.range,
    route.query.pa_window,
    route.query.pitch_window,
    route.query.start_date,
    route.query.end_date,
  ],
  ([tab, range, paWindow, pitchWindow, startDate, endDate]) => {
    selectedProfileTab.value = profileTabs.some((entry) => entry.id === tab) ? tab : 'overview'
    const nextRange = ['season', '7', '14', '30', 'custom'].includes(range) ? range : 'season'
    const nextPaWindow = [25, 50, 100].includes(Number(paWindow)) ? Number(paWindow) : 50
    const nextPitchWindow = [50, 100, 250].includes(Number(pitchWindow)) ? Number(pitchWindow) : 100
    analysisOptions.value = {
      range: nextRange,
      paWindow: nextPaWindow,
      pitchWindow: nextPitchWindow,
      startDate: startDate || null,
      endDate: endDate || null,
    }
    customStartDate.value = startDate || ''
    customEndDate.value = endDate || ''
  },
)

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

function teamHistoryLabel(membership) {
  if (!membership.current) return 'Organization tenure'

  return membership.sourceStatusDescription || titleize(membership.rosterStatus)
}

const positionLabel = computed(() => {
  const position = player.value?.positions?.primary
  return position ? `${position.abbreviation} · ${position.name}` : 'Position unavailable'
})

const savantStatsMode = computed(() => {
  const positionType = player.value?.positions?.primary?.position_type
  const primaryRole = player.value?.pitchIndicators?.primaryRole
  return positionType === 'pitcher' || (!positionType && primaryRole === 'pitcher')
    ? 'statcast-r-pitching-mlb'
    : 'statcast-r-hitting-mlb'
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

const externalProfileLinks = computed(() => {
  const fullName = player.value?.fullName
  const mlbId = player.value?.mlbId
  if (!fullName || !mlbId) return []

  const slug = fullName
    .normalize('NFKD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-|-$/g, '')
  const encodedName = encodeURIComponent(fullName)
  const baseballReferenceId = player.value?.externalIds?.baseballReference
  const fangraphsId = player.value?.externalIds?.fangraphs

  return [
    { key: 'mlb', label: 'MLB.com', href: `${frontendConfig.externalUrls.mlbPlayerBaseUrl}/${slug}-${mlbId}` },
    {
      key: 'fangraphs',
      label: 'FanGraphs',
      href: fangraphsId
        ? `${frontendConfig.externalUrls.fangraphsBaseUrl}/${slug}/${fangraphsId}/stats`
        : `${frontendConfig.externalUrls.fangraphsLegacyUrl}?lastname=${encodedName}`,
    },
    {
      key: 'baseball-reference',
      label: 'Baseball Reference',
      href: baseballReferenceId
        ? `${frontendConfig.externalUrls.baseballReferenceBaseUrl}/${baseballReferenceId.charAt(0)}/${baseballReferenceId}.shtml`
        : `${frontendConfig.externalUrls.baseballReferenceSearchUrl}?search=${encodedName}`,
    },
    {
      key: 'baseball-savant',
      label: 'Baseball Savant',
      href: `${frontendConfig.externalUrls.baseballSavantPlayerBaseUrl}/${slug}-${mlbId}?stats=${savantStatsMode.value}`,
    },
  ]
})

const pitcherWalkRate = computed(() => {
  const stats = player.value?.seasonOverview?.stats || []
  const walks = Number(stats.find((stat) => ['baseOnBalls', 'BB'].includes(stat.key))?.value)
  const inningsText = stats.find((stat) => ['inningsPitched', 'IP'].includes(stat.key))?.value
  if (!Number.isFinite(walks) || inningsText === null || inningsText === undefined) return null

  const inningsParts = String(inningsText).split('.')
  const innings = Number(inningsParts[0]) + (Number(inningsParts[1] || 0) / 3)
  return innings > 0 ? `${((walks * 9) / innings).toFixed(2)} BB/9` : null
})

const pitchingMetrics = computed(() => [
  ['Pitches', player.value?.pitchIndicators.pitching.pitch_count],
  ['Games', player.value?.pitchIndicators.pitching.game_count],
  ['Walk rate', pitcherWalkRate.value],
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

const trendEventLabels = {
  velocity_loss: 'Velocity loss',
  pitch_mix_change: 'Pitch-mix change',
  chase_rate_movement: 'Chase-rate movement',
}

const percentileColorStops = [
  [0, '#b0000a'],
  [10, '#f25549'],
  [20, '#ff9a86'],
  [30, '#ffd0b3'],
  [40, '#fff0d6'],
  [50, '#f9fafb'],
  [60, '#f5f3b5'],
  [70, '#dce994'],
  [80, '#a8d66d'],
  [90, '#4eaa3f'],
  [100, '#006429'],
]

function trendEventValue(event, value) {
  const suffix = event.unit === 'mph' ? ' mph' : ' pts'
  return `${Number(value).toFixed(1)}${suffix}`
}

function trendEventTitle(event) {
  const pitch = event.pitchType ? ` · ${event.pitchType}` : ''
  return `${trendEventLabels[event.eventType] || event.eventType}${pitch}`
}

function trendEventIsFavorable(event) {
  if (event.eventType !== 'chase_rate_movement') return false

  return (event.role === 'pitcher' && event.direction === 'increase')
    || (event.role === 'batter' && event.direction === 'decrease')
}

function trendEventTone(event) {
  if (trendEventIsFavorable(event)) return 'favorable'
  if (event.eventType === 'pitch_mix_change') return 'neutral'
  return 'adverse'
}

function trendEventLabel(event) {
  if (trendEventIsFavorable(event)) return 'improvement'
  if (event.eventType === 'pitch_mix_change') return 'change'
  return event.severity
}

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

function selectAdjacentTab(event, index) {
  if (!['ArrowLeft', 'ArrowRight', 'Home', 'End'].includes(event.key)) return
  event.preventDefault()

  let nextIndex = index
  if (event.key === 'ArrowRight') nextIndex = (index + 1) % profileTabs.length
  if (event.key === 'ArrowLeft') nextIndex = (index - 1 + profileTabs.length) % profileTabs.length
  if (event.key === 'Home') nextIndex = 0
  if (event.key === 'End') nextIndex = profileTabs.length - 1
  selectedProfileTab.value = profileTabs[nextIndex].id
  event.currentTarget.closest('[role="tablist"]')?.querySelectorAll('[role="tab"]')?.[nextIndex]?.focus()
}

function openSavedAnalysis(item) {
  const state = item.state || {}
  analysisOptions.value = {
    range: state.range || 'season',
    paWindow: Number(state.paWindow || 50),
    pitchWindow: Number(state.pitchWindow || 100),
    startDate: state.startDate || null,
    endDate: state.endDate || null,
  }
  customStartDate.value = state.startDate || ''
  customEndDate.value = state.endDate || ''
  router.push(item.reproducibleUrl)
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

function percentileStyle(value) {
  const percentile = Math.round(Math.min(100, Math.max(0, Number(value) || 0)))
  const upperIndex = percentileColorStops.findIndex(([stop]) => stop >= percentile)
  const upper = percentileColorStops[upperIndex]
  const lower = percentileColorStops[Math.max(0, upperIndex - 1)]
  const progress = upper[0] === lower[0] ? 0 : (percentile - lower[0]) / (upper[0] - lower[0])

  return {
    '--percentile-background': interpolateHexColor(lower[1], upper[1], progress),
    '--percentile-foreground': percentile <= 31 || percentile >= 81 ? '#f9fafb' : '#1f2937',
  }
}

function interpolateHexColor(start, end, progress) {
  const channels = [1, 3, 5].map((offset) => {
    const startChannel = Number.parseInt(start.slice(offset, offset + 2), 16)
    const endChannel = Number.parseInt(end.slice(offset, offset + 2), 16)
    return Math.round(startChannel + ((endChannel - startChannel) * progress))
      .toString(16)
      .padStart(2, '0')
  })
  return `#${channels.join('')}`
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

function similarityValue(metric, value) {
  if (value === null || value === undefined) return '—'
  if (metric.key.endsWith('_rate')) return `${Number(value).toFixed(1)}%`
  return formatBaseballStatValue(metric.key, value)
}

function advancedStatValue(column, value) {
  if (value === null || value === undefined || value === '') return '—'
  const numericValue = Number(value)
  if (!Number.isFinite(numericValue)) return value
  if (column.unit === 'percent') return `${(numericValue * 100).toFixed(1)}%`
  if (column.unit === 'index') return numericValue.toFixed(0)
  if (column.unit === 'ratio') return numericValue.toFixed(2)
  if (column.unit === 'runs' || column.unit === 'war') return numericValue.toFixed(1)
  if (column.unit === 'pitching_rate') return numericValue.toFixed(2)
  if (column.unit === 'count') return Math.round(numericValue).toLocaleString()
  return numericValue.toFixed(3).replace(/^0(?=\.)/, '')
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
                v-if="player.displayTeam?.id || player.currentMembership?.team?.id || player.team?.id"
                :to="{ name: 'team-profile', params: { id: player.displayTeam?.id || player.currentMembership?.team?.id || player.team?.id } }"
              >
                {{ player.displayTeam?.name || player.currentMembership?.team?.name || player.team?.name }}
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
          <nav class="external-profile-links" aria-label="External player profiles">
            <AddToWatchlistControl :player-id="player.id" :player-name="player.fullName" />
            <RouterLink
              class="compare-player-link"
              :to="{ name: 'player-comparison', query: { left: player.id } }"
              data-test="compare-player-link"
            >
              Compare player
              <span aria-hidden="true">⇄</span>
            </RouterLink>
            <a
              v-for="link in externalProfileLinks"
              :key="link.key"
              :href="link.href"
              target="_blank"
              rel="noopener noreferrer"
              :data-test="`external-profile-${link.key}`"
            >
              {{ link.label }}
              <span aria-hidden="true">↗</span>
            </a>
          </nav>
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

      <NotesPanel target-type="player" :target-id="player.id" title="Player notes" />

      <nav class="profile-tabs" aria-label="Player profile sections">
        <div role="tablist">
          <button
            v-for="(tab, index) in profileTabs"
            :id="`player-profile-tab-${tab.id}`"
            :key="tab.id"
            type="button"
            role="tab"
            :aria-controls="`player-profile-panel-${tab.id}`"
            :aria-selected="selectedProfileTab === tab.id"
            :tabindex="selectedProfileTab === tab.id ? 0 : -1"
            :data-test="`player-profile-tab-${tab.id}`"
            @click="selectedProfileTab = tab.id"
            @keydown="selectAdjacentTab($event, index)"
          >
            {{ tab.label }}
          </button>
        </div>
      </nav>

      <section
        v-show="selectedProfileTab === 'overview'"
        id="player-profile-panel-overview"
        class="profile-panel profile-career-table"
        role="tabpanel"
        aria-labelledby="player-profile-tab-overview"
      >
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

      <section
        v-show="selectedProfileTab === 'advanced-stats'"
        id="player-profile-panel-advanced-stats"
        class="profile-panel advanced-stats-panel"
        role="tabpanel"
        aria-labelledby="player-profile-tab-advanced-stats"
        data-test="advanced-stats-panel"
      >
        <header class="profile-section-heading">
          <div>
            <p class="eyebrow">Plate-discipline & production</p>
            <h2>Advanced Stats</h2>
          </div>
          <span>{{ careerRangeLabel }}</span>
        </header>

        <div v-if="player.advancedStats.seasons.length" class="advanced-stat-groups">
          <article
            v-for="group in player.advancedStats.groups"
            :key="group.key"
            class="advanced-stat-group"
            :data-test="`advanced-stat-group-${group.key}`"
          >
            <h3>{{ group.label }}</h3>
            <p v-if="group.description" class="advanced-stat-group__description">{{ group.description }}</p>
            <div class="advanced-table-wrap">
              <table class="advanced-table">
                <thead>
                  <tr>
                    <th>Season</th>
                    <th>Team</th>
                    <th
                      v-for="column in group.columns"
                      :key="column.key"
                      class="advanced-table__metric-heading"
                    >
                      {{ column.label }}
                    </th>
                  </tr>
                </thead>
                <tbody>
                  <tr v-for="seasonRow in player.advancedStats.seasons" :key="seasonRow.season">
                    <th>{{ seasonRow.season }}</th>
                    <td>{{ seasonTeamLabel(seasonRow) }}</td>
                    <td v-for="column in group.columns" :key="column.key">
                      {{ advancedStatValue(column, seasonRow.values[column.key]) }}
                    </td>
                  </tr>
                </tbody>
                <tfoot>
                  <tr>
                    <th>Career</th>
                    <td>Total</td>
                    <td v-for="column in group.columns" :key="column.key">
                      {{ advancedStatValue(column, player.advancedStats.career.values[column.key]) }}
                    </td>
                  </tr>
                </tfoot>
              </table>
            </div>
          </article>
        </div>
        <p v-else class="profile-empty">No advanced statistics have been imported for this player yet.</p>
      </section>

      <section class="profile-panel similar-players-panel" data-test="similar-players">
        <header class="profile-section-heading">
          <div>
            <p class="eyebrow">Statistical neighbors</p>
            <h2>Similar players</h2>
          </div>
          <span v-if="player.similarPlayers.season">
            {{ player.similarPlayers.season }} {{ titleize(player.similarPlayers.category) }}
          </span>
        </header>

        <div v-if="player.similarPlayers.matches.length" class="similar-player-grid">
          <article
            v-for="match in player.similarPlayers.matches"
            :key="match.player.id"
            class="similar-player-card"
            :data-test="`similar-player-${match.player.id}`"
          >
            <div class="similar-player-card__heading">
              <img v-if="match.player.headshotUrl" :src="match.player.headshotUrl" :alt="`${match.player.fullName} headshot`" />
              <div>
                <RouterLink :to="{ name: 'player-profile', params: { id: match.player.id } }">
                  {{ match.player.fullName }}
                </RouterLink>
                <span>
                  {{ match.position?.abbreviation || '—' }}
                  <template v-if="match.team?.abbreviation"> · {{ match.team.abbreviation }}</template>
                </span>
              </div>
              <strong>{{ match.similarityScore }}%</strong>
            </div>

            <dl>
              <div v-for="metric in match.closestMetrics" :key="metric.key">
                <dt>{{ metric.label }}</dt>
                <dd>
                  {{ similarityValue(metric, metric.targetValue) }}
                  <span aria-hidden="true">↔</span>
                  {{ similarityValue(metric, metric.candidateValue) }}
                </dd>
              </div>
            </dl>

            <RouterLink
              class="similar-player-card__compare"
              :to="{ name: 'player-comparison', query: { left: player.id, right: match.player.id } }"
            >
              Compare side by side →
            </RouterLink>
          </article>
        </div>
        <p v-else class="profile-empty">
          Similar players will appear when at least three comparable same-season metrics are available.
        </p>
        <small v-if="player.similarPlayers.methodology" class="similar-player-methodology">
          {{ player.similarPlayers.methodology }}
        </small>
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

      <SavedAnalysisControls
        analysis-type="player_date_range"
        :state="savedAnalysisState"
        :reproducible-url="savedAnalysisUrl"
        compact
        @apply="openSavedAnalysis"
      />

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

        <div v-if="player.trendEvents?.events?.length" class="trend-events" data-test="trend-events">
          <article v-for="event in player.trendEvents.events" :key="event.id"
            :class="[
              `trend-event--${trendEventTone(event)}`,
              `trend-event--${event.severity}`,
              { 'trend-event--resolved': event.status === 'resolved' },
            ]">
            <header>
              <span>{{ trendEventLabel(event) }} · {{ event.status }}</span>
              <time :datetime="event.onsetDate">Onset {{ formatDate(event.onsetDate) }}</time>
            </header>
            <strong>{{ trendEventTitle(event) }}</strong>
            <p>
              {{ trendEventValue(event, event.baselineValue) }} → {{ trendEventValue(event, event.currentValue) }}
              ({{ signedContextualValue(event.changeValue, event.unit === 'mph' ? 'mph' : 'percent') }})
            </p>
            <small>
              Sample {{ event.sampleSize }} vs {{ event.baselineSampleSize }} baseline ·
              {{ event.supportingPitches.length }} supporting pitches
            </small>
          </article>
        </div>

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
                  <span class="percentile-pill" :style="percentileStyle(metric.percentile)">
                    P{{ Math.round(metric.percentile) }}
                  </span>
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
            <span>{{ player.teamHistory.length }} {{ player.teamHistory.length === 1 ? 'organization tenure' : 'organization tenures' }}</span>
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
              <small>{{ teamHistoryLabel(membership) }}</small>
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

.profile-tabs {
  position: sticky;
  z-index: 8;
  top: 0.5rem;
  margin-top: 1.25rem;
  padding: 0.35rem;
  border: 1px solid rgba(16, 38, 61, 0.1);
  border-radius: 15px;
  background: rgba(247, 246, 241, 0.94);
  box-shadow: 0 8px 24px rgba(16, 38, 61, 0.08);
  backdrop-filter: blur(10px);
}

.profile-tabs [role='tablist'] {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 0.35rem;
}

.profile-tabs button {
  min-height: 42px;
  padding: 0.65rem 0.85rem;
  border: 0;
  border-radius: 11px;
  color: #65747e;
  background: transparent;
  font-size: 0.72rem;
  font-weight: 900;
  letter-spacing: 0.06em;
  text-transform: uppercase;
  cursor: pointer;
}

.profile-tabs button[aria-selected='true'] {
  color: #fffaf0;
  background: #173652;
  box-shadow: 0 5px 14px rgba(16, 38, 61, 0.18);
}

.profile-tabs button:focus-visible {
  outline: 3px solid rgba(169, 54, 39, 0.32);
  outline-offset: 2px;
}

[role='tabpanel']:focus {
  outline: none;
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

.trend-events {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
  gap: .7rem;
  margin-bottom: 1rem;
}

.trend-events article {
  padding: .85rem;
  border: 1px solid rgba(169, 54, 39, .22);
  border-left: 4px solid #a93627;
  border-radius: 12px;
  background: rgba(255, 241, 238, .86);
}

.trend-events article.trend-event--favorable {
  border-color: rgba(23, 97, 61, .22);
  border-left-color: #17613d;
  background: rgba(235, 249, 240, .9);
}

.trend-events article.trend-event--neutral {
  border-color: rgba(195, 122, 40, .24);
  border-left-color: #c37a28;
  background: rgba(255, 248, 229, .86);
}

.trend-events article.trend-event--resolved { opacity: .64; }
.trend-events header { display: flex; justify-content: space-between; gap: .5rem; }
.trend-events header span { color: #a93627; font-size: .64rem; font-weight: 900; text-transform: uppercase; }
.trend-events .trend-event--favorable header span { color: #17613d; }
.trend-events .trend-event--neutral header span { color: #8a5a1f; }
.trend-events time, .trend-events small { color: #65747d; font-size: .68rem; }
.trend-events strong { display: block; margin-top: .4rem; font-family: 'Avenir Next Condensed', sans-serif; font-size: 1.2rem; text-transform: uppercase; }
.trend-events p { margin: .3rem 0; font-size: .78rem; }

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

.external-profile-links {
  display: flex;
  flex-wrap: wrap;
  gap: 0.45rem;
  margin-top: 0.75rem;
}

.external-profile-links a {
  display: inline-flex;
  align-items: center;
  gap: 0.3rem;
  padding: 0.34rem 0.58rem;
  border: 1px solid rgba(23, 54, 82, 0.2);
  border-radius: 999px;
  color: #173652;
  background: rgba(255, 255, 255, 0.72);
  font-size: 0.72rem;
  font-weight: 800;
  line-height: 1;
  text-decoration: none;
}

.external-profile-links .compare-player-link {
  display: inline-flex;
  align-items: center;
  gap: 0.3rem;
  padding: 0.34rem 0.58rem;
  border: 1px solid rgba(169, 54, 39, 0.35);
  border-radius: 999px;
  color: #8f2d24;
  background: rgba(255, 250, 240, 0.9);
  font-size: 0.72rem;
  font-weight: 800;
  line-height: 1;
  text-decoration: none;
}

.external-profile-links a:hover {
  border-color: rgba(23, 54, 82, 0.5);
  background: #fff;
  transform: translateY(-1px);
}

.external-profile-links a:focus-visible {
  outline: 3px solid rgba(31, 111, 235, 0.32);
  outline-offset: 2px;
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

.similar-player-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
  gap: 0.85rem;
}

.similar-player-card {
  padding: 1rem;
  border: 1px solid rgba(16, 38, 61, 0.1);
  border-radius: 18px;
  background: #fffdf7;
}

.similar-player-card__heading {
  display: grid;
  grid-template-columns: 48px minmax(0, 1fr) auto;
  gap: 0.7rem;
  align-items: center;
}

.similar-player-card__heading img {
  width: 48px;
  height: 48px;
  border-radius: 50%;
  object-fit: cover;
  background: #e7edf1;
}

.similar-player-card__heading a,
.similar-player-card__heading span {
  display: block;
}

.similar-player-card__heading a {
  color: #10263d;
  font-weight: 900;
  text-decoration-color: #b79569;
  text-underline-offset: 0.18em;
}

.similar-player-card__heading span {
  color: #71808c;
  font-size: 0.76rem;
}

.similar-player-card__heading > strong {
  color: #20543c;
  font-size: 1.15rem;
}

.similar-player-card dl {
  display: grid;
  gap: 0.45rem;
  margin-top: 0.9rem;
}

.similar-player-card dl div {
  display: flex;
  justify-content: space-between;
  gap: 1rem;
  padding-bottom: 0.4rem;
  border-bottom: 1px solid rgba(16, 38, 61, 0.07);
}

.similar-player-card dt {
  color: #71808c;
  font-size: 0.72rem;
  font-weight: 800;
}

.similar-player-card dd {
  color: #243b50;
  font-size: 0.78rem;
  font-weight: 800;
  font-variant-numeric: tabular-nums;
}

.similar-player-card dd span {
  margin-inline: 0.25rem;
  color: #b79569;
}

.similar-player-card__compare {
  display: inline-block;
  margin-top: 0.85rem;
  color: #8f2d24;
  font-size: 0.78rem;
  font-weight: 900;
  text-decoration: none;
}

.similar-player-methodology {
  display: block;
  margin-top: 0.85rem;
  color: #71808c;
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

.advanced-stat-groups {
  display: grid;
  gap: 1.25rem;
}

.advanced-stat-group h3 {
  margin-bottom: 0.65rem;
  color: #10263d;
  font-family: 'Avenir Next Condensed', sans-serif;
  font-size: 1.35rem;
  text-transform: uppercase;
}

.advanced-stat-group__description {
  margin: -0.35rem 0 0.75rem;
  color: #607184;
}

.advanced-table-wrap {
  overflow-x: auto;
  border: 1px solid rgba(16, 38, 61, 0.1);
  border-radius: 16px;
  background: #fffdf7;
}

.advanced-table {
  width: 100%;
  min-width: 680px;
  border-collapse: separate;
  border-spacing: 0;
  color: #243b50;
  font-variant-numeric: tabular-nums;
}

.advanced-table th,
.advanced-table td {
  padding: 0.78rem;
  border-bottom: 1px solid rgba(16, 38, 61, 0.08);
  text-align: right;
  white-space: nowrap;
}

.advanced-table th:first-child,
.advanced-table td:nth-child(2) {
  text-align: left;
}

.advanced-table thead th {
  color: #697784;
  background: #e7edf1;
  font-size: 0.68rem;
  font-weight: 900;
  letter-spacing: 0.06em;
  text-transform: uppercase;
}

.advanced-table thead .advanced-table__metric-heading {
  width: 6.5rem;
  max-width: 7.5rem;
  line-height: 1.15;
  overflow-wrap: break-word;
  white-space: normal;
}

.advanced-table tbody tr:nth-child(even) th,
.advanced-table tbody tr:nth-child(even) td {
  background: #faf5ea;
}

.advanced-table tfoot th,
.advanced-table tfoot td {
  border-bottom: 0;
  color: #fffaf0;
  background: #10263d;
  font-weight: 900;
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
  border: 1px solid rgba(16, 38, 61, 0.08);
  color: var(--percentile-foreground);
  background: var(--percentile-background);
  box-shadow: inset 0 1px 0 rgba(255, 255, 255, 0.24);
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
