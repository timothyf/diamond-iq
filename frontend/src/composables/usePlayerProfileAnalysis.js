import { computed, ref } from 'vue'
import { formatBaseballStatValue } from '../utils/baseballStatFormatting'

const batterSplitMetrics = [
  ['plate_appearances', 'PA', 'count'],
  ['batting_average', 'AVG', 'rate'],
  ['hits', 'H', 'count'],
  ['home_runs', 'HR', 'count'],
  ['walks', 'BB', 'count'],
  ['strikeouts', 'K', 'count'],
  ['swing_percentage', 'Swing%', 'percent'],
  ['whiff_percentage', 'Whiff%', 'percent'],
  ['chase_percentage', 'Chase%', 'percent'],
  ['hard_hit_percentage', 'Hard-hit%', 'percent'],
  ['average_exit_velocity', 'Exit velo', 'mph'],
]

const pitcherSplitMetrics = [
  ['batters_faced', 'BF', 'count'],
  ['pitch_count', 'Pitches', 'count'],
  ['strikeouts', 'K', 'count'],
  ['walks', 'BB', 'count'],
  ['zone_percentage', 'Zone%', 'percent'],
  ['whiff_percentage', 'Whiff%', 'percent'],
  ['chase_percentage', 'Chase%', 'percent'],
  ['average_velocity', 'Avg velo', 'mph'],
  ['maximum_velocity', 'Max velo', 'mph'],
  ['average_spin_rate', 'Avg spin', 'rpm'],
  ['delta_run_expectancy_per_100', 'Run value/100', 'runs'],
]

const trendEventLabels = {
  velocity_loss: 'Velocity loss',
  pitch_mix_change: 'Pitch-mix change',
  chase_rate_movement: 'Chase-rate movement',
}

const percentileColorStops = [
  [0, '#315da8'],
  [20, '#6f8ec0'],
  [40, '#aec7cf'],
  [60, '#d5b6a9'],
  [80, '#de7261'],
  [100, '#df4037'],
]

export function usePlayerProfileAnalysis(player, formatDate) {
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

  const careerTableRows = computed(() => player.value?.careerOverview?.seasons?.flatMap((seasonRow) => {
    if (seasonRow.teamRows.length > 1) {
      return [
        ...seasonRow.teamRows.map((teamRow) => ({
          season: seasonRow.season,
          teamLabel: teamRow.team?.abbreviation || '—',
          statValues: teamRow.statValues,
        })),
        {
          season: seasonRow.season,
          teamLabel: 'Total',
          statValues: seasonRow.totalStatValues,
          isSeasonTotal: true,
        },
      ]
    }

    return [{
      season: seasonRow.season,
      teamLabel: seasonTeamLabel(seasonRow),
      statValues: seasonRow.statValues,
    }]
  }) || [])

  const advancedTableRows = computed(() => player.value?.advancedStats?.seasons?.flatMap((seasonRow) => {
    if (seasonRow.teamRows.length > 1) {
      return [
        ...seasonRow.teamRows.map((teamRow) => ({
          season: seasonRow.season,
          teamLabel: teamRow.team?.abbreviation || '—',
          values: teamRow.values,
        })),
        {
          season: seasonRow.season,
          teamLabel: 'Total',
          values: seasonRow.totalValues,
          isSeasonTotal: true,
        },
      ]
    }

    return [{
      season: seasonRow.season,
      teamLabel: seasonTeamLabel(seasonRow),
      values: seasonRow.values,
    }]
  }) || [])

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

  const selectedBatterSplit = ref('pitcher_hand')
  const batterSplitDimension = computed(() => {
    const dimensions = player.value?.batterSplits?.dimensions || []
    return dimensions.find((dimension) => dimension.key === selectedBatterSplit.value) || dimensions[0] || null
  })

  const selectedPitcherSplit = ref('batter_hand')
  const pitcherSplitDimension = computed(() => {
    const dimensions = player.value?.pitcherSplits?.dimensions || []
    return dimensions.find((dimension) => dimension.key === selectedPitcherSplit.value) || dimensions[0] || null
  })

  const benchmarkPeriodLabel = computed(() => {
    const context = player.value?.contextualBenchmarks
    if (!context?.sourceStartDate || !context?.sourceEndDate) return 'No benchmark period calculated'
    return `${formatDate(context.sourceStartDate)} — ${formatDate(context.sourceEndDate)}`
  })

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
      '--percentile-foreground': percentile <= 35 || percentile >= 65 ? '#f9fafb' : '#1f2937',
      '--percentile-position': `${percentile}%`,
    }
  }

  function peerAverage(metric) {
    return metric.positionAverage ?? metric.pitcherRoleAverage
  }

  function peerLabel(metric) {
    if (metric.positionAverage !== null && metric.positionAverage !== undefined) return metric.positionKey || 'Position'
    if (metric.pitcherRoleAverage !== null && metric.pitcherRoleAverage !== undefined) return titleize(metric.pitcherRoleKey || 'Role')
    return 'Peer group unavailable'
  }

  function batterSplitValue(value, unit) {
    if (value === null || value === undefined || value === '') return '—'
    if (unit === 'percent') return `${Number(value).toFixed(1)}%`
    if (unit === 'rate') return Number(value).toFixed(3)
    if (unit === 'mph') return `${Number(value).toFixed(1)} mph`
    return Number(value).toLocaleString()
  }

  function pitcherSplitValue(value, unit) {
    if (value === null || value === undefined || value === '') return '—'
    if (unit === 'percent') return `${Number(value).toFixed(1)}%`
    if (unit === 'mph') return `${Number(value).toFixed(1)} mph`
    if (unit === 'rpm') return `${Math.round(Number(value)).toLocaleString()} rpm`
    if (unit === 'runs') return Number(value).toFixed(1)
    return Number(value).toLocaleString()
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

  function similarityValue(metric, value) {
    if (value === null || value === undefined) return '—'
    if (metric.key.endsWith('_rate')) return `${Number(value).toFixed(1)}%`
    return formatBaseballStatValue(metric.key, value)
  }

  return {
    careerTableRows,
    advancedTableRows,
    trendCharts,
    comparisonMetrics,
    selectedBatterSplit,
    batterSplitDimension,
    batterSplitMetrics,
    selectedPitcherSplit,
    pitcherSplitDimension,
    pitcherSplitMetrics,
    showBattingIndicators,
    showPitchingIndicators,
    trendEventTone,
    trendEventLabel,
    trendEventTitle,
    trendEventValue,
    benchmarkPeriodLabel,
    contextualMetricLabel,
    contextualValue,
    peerAverage,
    peerLabel,
    percentileStyle,
    signedContextualValue,
    batterSplitValue,
    pitcherSplitValue,
    advancedStatValue,
    similarityValue,
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

function seasonTeamLabel(seasonRow) {
  const abbreviations = (seasonRow.teams || []).map((team) => team?.abbreviation).filter(Boolean)
  return abbreviations.length ? [...new Set(abbreviations)].join(' / ') : '—'
}

function titleize(value) {
  return String(value || '')
    .replaceAll('_', ' ')
    .replace(/\b\w/g, (letter) => letter.toUpperCase())
}
