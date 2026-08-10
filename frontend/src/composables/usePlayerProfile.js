import { computed, ref, watch } from 'vue'
import { API_BASE_URL } from '../config'

function normalizeTeam(team) {
  if (!team) return null

  return {
    id: team.id,
    mlbId: team.mlb_id,
    name: team.name,
    abbreviation: team.abbreviation,
    teamName: team.team_name,
    locationName: team.location_name,
    shortName: team.short_name,
  }
}

function normalizeMembership(membership) {
  if (!membership) return null

  return {
    id: membership.id,
    team: normalizeTeam(membership.team),
    startsOn: membership.starts_on,
    endsOn: membership.ends_on,
    current: membership.current,
    rosterStatus: membership.roster_status,
    injured: membership.injured,
    jerseyNumber: membership.jersey_number,
    primaryPosition: membership.primary_position,
    secondaryPositions: membership.secondary_positions || [],
    sourceName: membership.source_name,
    sourceStatusCode: membership.source_status_code,
    sourceStatusDescription: membership.source_status_description,
    lastSyncedAt: membership.last_synced_at,
  }
}

function normalizeProfile(data = {}) {
  const profile = data.profile
    ? {
        ...data.profile,
        birthDate: data.profile.birth_date,
        formattedHeight: data.profile.formatted_height,
        weightPounds: data.profile.weight_pounds,
        mlbDebutDate: data.profile.mlb_debut_date,
        headshotUrl: data.profile.headshot_url,
        sourceName: data.profile.source_name,
        lastSyncedAt: data.profile.last_synced_at,
      }
    : null
  const season = data.season_overview || {}
  const career = data.career_overview || {}
  const advancedStats = data.advanced_stats || {}
  const indicators = data.recent_pitch_indicators || {}
  const benchmarks = data.contextual_benchmarks || {}
  const battedBallProfile = data.batted_ball_profile || {}
  const analysis = data.analysis || {}
  const trendEvents = data.trend_events || {}
  const similarPlayers = data.similar_players || {}
  const analysisRange = analysis.range || {}
  const source = data.source_metadata || {}

  return {
    id: data.id,
    mlbId: data.mlb_id,
    firstName: data.first_name,
    lastName: data.last_name,
    fullName: data.full_name,
    team: normalizeTeam(data.team),
    displayTeam: normalizeTeam(data.display_team),
    externalIds: {
      baseballReference: data.external_ids?.baseball_reference,
      fangraphs: data.external_ids?.fangraphs,
    },
    profile,
    positions: data.positions || { primary: null, secondary: [], assignments: [] },
    seasonOverview: {
      season: season.season,
      category: season.category,
      preferredCategory: season.preferred_category,
      stats: season.stats || [],
    },
    careerOverview: {
      category: career.category,
      preferredCategory: career.preferred_category,
      firstSeason: career.first_season,
      lastSeason: career.last_season,
      seasonCount: career.season_count || 0,
      columns: career.columns || [],
      seasons: (career.seasons || []).map((seasonRow) => ({
        season: seasonRow.season,
        teams: (seasonRow.teams || []).map(normalizeTeam),
        stats: seasonRow.stats || [],
        statValues: Object.fromEntries((seasonRow.stats || []).map((stat) => [stat.key, stat.value])),
        teamRows: (seasonRow.team_rows || []).map((teamRow) => ({
          team: normalizeTeam(teamRow.team),
          stats: teamRow.stats || [],
          statValues: Object.fromEntries((teamRow.stats || []).map((stat) => [stat.key, stat.value])),
        })),
        totalStats: seasonRow.total_stats || seasonRow.stats || [],
        totalStatValues: Object.fromEntries((seasonRow.total_stats || seasonRow.stats || []).map((stat) => [stat.key, stat.value])),
      })),
      stats: career.stats || [],
      statValues: Object.fromEntries((career.stats || []).map((stat) => [stat.key, stat.value])),
    },
    advancedStats: {
      category: advancedStats.category,
      groups: advancedStats.groups || [],
      seasons: (advancedStats.seasons || []).map((seasonRow) => ({
        season: seasonRow.season,
        teams: (seasonRow.teams || []).map(normalizeTeam),
        values: seasonRow.values || {},
        teamRows: (seasonRow.team_rows || []).map((teamRow) => ({
          team: normalizeTeam(teamRow.team),
          values: teamRow.values || {},
        })),
        totalValues: seasonRow.total_values || seasonRow.values || {},
      })),
      career: advancedStats.career || { values: {} },
    },
    similarPlayers: {
      season: similarPlayers.season,
      category: similarPlayers.category,
      methodology: similarPlayers.methodology,
      matches: (similarPlayers.matches || []).map((match) => ({
        player: {
          id: match.player?.id,
          mlbId: match.player?.mlb_id,
          fullName: match.player?.full_name,
          headshotUrl: match.player?.headshot_url,
        },
        team: normalizeTeam(match.team),
        position: match.position,
        similarityScore: match.similarity_score,
        sharedMetricCount: match.shared_metric_count,
        samePositionType: match.same_position_type,
        closestMetrics: (match.closest_metrics || []).map((metric) => ({
          key: metric.key,
          label: metric.label,
          targetValue: metric.target_value,
          candidateValue: metric.candidate_value,
        })),
      })),
    },
    currentMembership: normalizeMembership(data.current_membership),
    teamHistory: (data.team_history || []).map(normalizeMembership),
    pitchIndicators: {
      sampleSize: indicators.sample_size || 100,
      primaryRole: indicators.primary_role || 'batter',
      pitching: indicators.pitching || {},
      batting: indicators.batting || {},
    },
    battedBallProfile: {
      available: battedBallProfile.available === true,
      contactCount: battedBallProfile.contact_count || 0,
      sprayPoints: (battedBallProfile.spray_points || []).map((point) => ({
        x: point.x,
        y: point.y,
        event: point.event,
        battedBallType: point.batted_ball_type,
        exitVelocity: point.exit_velocity,
        launchAngle: point.launch_angle,
        gameDate: point.game_date,
      })),
      hitPoints: (battedBallProfile.hit_points || []).map((point) => ({
        x: point.x,
        y: point.y,
        event: point.event,
        battedBallType: point.batted_ball_type,
        exitVelocity: point.exit_velocity,
        launchAngle: point.launch_angle,
        gameDate: point.game_date,
      })),
    },
    batterSplits: {
      available: data.batter_splits?.available === true,
      dimensions: (data.batter_splits?.dimensions || []).map((dimension) => ({
        key: dimension.key,
        label: dimension.label,
        options: (dimension.options || []).map((option) => ({
          value: option.value,
          label: option.label,
          metrics: option.metrics || {},
        })),
      })),
    },
    pitcherSplits: {
      available: data.pitcher_splits?.available === true,
      dimensions: (data.pitcher_splits?.dimensions || []).map((dimension) => ({
        key: dimension.key,
        label: dimension.label,
        options: (dimension.options || []).map((option) => ({
          value: option.value,
          label: option.label,
          metrics: option.metrics || {},
        })),
      })),
    },
    contextualBenchmarks: {
      available: benchmarks.available === true,
      sourceStartDate: benchmarks.source_start_date,
      sourceEndDate: benchmarks.source_end_date,
      calculationVersion: benchmarks.calculation_version,
      calculatedAt: benchmarks.calculated_at,
      metrics: (benchmarks.metrics || []).map((metric) => ({
        metricKey: metric.metric_key,
        metricGroup: metric.metric_group,
        displayName: metric.display_name,
        unit: metric.unit,
        directionality: metric.directionality,
        dimensionType: metric.dimension_type,
        dimensionValue: metric.dimension_value,
        rawValue: metric.raw_value,
        mlbAverage: metric.mlb_average,
        positionAverage: metric.position_average,
        positionKey: metric.position_key,
        pitcherRoleAverage: metric.pitcher_role_average,
        pitcherRoleKey: metric.pitcher_role_key,
        percentile: metric.percentile,
        positionPercentile: metric.position_percentile,
        pitcherRolePercentile: metric.pitcher_role_percentile,
        sampleSize: metric.sample_size,
        mlbSampleSize: metric.mlb_sample_size,
        mlbPlayerCount: metric.mlb_player_count,
        positionPlayerCount: metric.position_player_count,
        pitcherRolePlayerCount: metric.pitcher_role_player_count,
      })),
    },
    analysis: {
      range: {
        preset: analysisRange.preset || 'season',
        startDate: analysisRange.start_date,
        endDate: analysisRange.end_date,
        previousStartDate: analysisRange.previous_start_date,
        previousEndDate: analysisRange.previous_end_date,
        plateAppearanceWindow: analysisRange.plate_appearance_window || 50,
        pitchWindow: analysisRange.pitch_window || 100,
      },
      summary: analysis.summary || { current: { batting: {}, pitching: {} }, previous: { batting: {}, pitching: {} }, changes: {} },
      batting: normalizeTrendGroup(analysis.batting),
      pitching: normalizeTrendGroup(analysis.pitching),
    },
    trendEvents: {
      activeCount: trendEvents.active_count || 0,
      events: (trendEvents.events || []).map((event) => ({
        id: event.id,
        eventType: event.event_type,
        role: event.role,
        metricKey: event.metric_key,
        pitchType: event.pitch_type,
        direction: event.direction,
        severity: event.severity,
        status: event.status,
        unit: event.unit,
        baselineValue: event.baseline_value,
        currentValue: event.current_value,
        changeValue: event.change_value,
        thresholdValue: event.threshold_value,
        thresholds: event.thresholds || {},
        baselineSampleSize: event.baseline_sample_size,
        sampleSize: event.sample_size,
        baselineStartDate: event.baseline_start_date,
        baselineEndDate: event.baseline_end_date,
        currentStartDate: event.current_start_date,
        currentEndDate: event.current_end_date,
        onsetDate: event.onset_date,
        detectedAt: event.detected_at,
        lastObservedAt: event.last_observed_at,
        resolvedAt: event.resolved_at,
        supportingPitches: event.supporting_pitches || [],
        metadata: event.metadata || {},
      })),
    },
    sourceMetadata: {
      lastUpdatedAt: source.last_updated_at,
      sources: source.sources || [],
      datasets: (source.datasets || []).map((dataset) => ({
        name: dataset.name,
        sourceName: dataset.source_name,
        lastUpdatedAt: dataset.last_updated_at,
      })),
    },
  }
}

function normalizeTrendGroup(group = {}) {
  return {
    windowType: group.window_type,
    windowSize: group.window_size,
    totalObservations: group.total_observations || 0,
    charts: (group.charts || []).map((chart) => ({
      key: chart.key,
      title: chart.title,
      unit: chart.unit,
      series: (chart.series || []).map((series) => ({
        key: series.key,
        label: series.label,
        points: (series.points || []).map((point) => ({
          date: point.date,
          sequence: point.sequence,
          value: point.value,
          sampleSize: point.sample_size,
        })),
      })),
    })),
  }
}

export function usePlayerProfile(playerIdRef, analysisOptionsRef = null, { includeCoreSection = true } = {}) {
  const player = ref(null)
  const loading = ref(false)
  const error = ref('')
  const loadingSections = ref({})
  const loadedSections = new Set()
  const requestedSections = new Set()
  let requestCounter = 0

  async function load() {
    const playerId = playerIdRef.value
    const requestId = requestCounter + 1
    requestCounter = requestId

    if (!playerId) {
      player.value = null
      error.value = 'A player id is required.'
      return
    }

    loading.value = true
    error.value = ''
    loadedSections.clear()
    requestedSections.clear()
    loadingSections.value = {}

    try {
      const query = analysisQuery(analysisOptionsRef?.value, includeCoreSection ? 'core' : null)
      const response = await fetch(`${API_BASE_URL}/api/players/${encodeURIComponent(playerId)}${query}`, {
        headers: { Accept: 'application/json' },
      })

      if (!response.ok) {
        const errorPayload = typeof response.json === 'function' ? await response.json().catch(() => ({})) : {}
        const requestError = new Error(errorPayload?.message || `Request failed with status ${response.status}`)
        requestError.status = response.status
        throw requestError
      }

      const payload = await response.json()
      if (requestId !== requestCounter) return

      player.value = normalizeProfile(payload.data)
      window.setTimeout(() => {
        if (requestId !== requestCounter) return

        void loadSection('similar_players', requestId)
        void loadSection('analytics', requestId)
      }, 0)
    } catch (fetchError) {
      if (requestId !== requestCounter) return

      player.value = null
      error.value = responseMessage(fetchError)
      console.error(fetchError)
    } finally {
      if (requestId === requestCounter) loading.value = false
    }
  }

  async function loadSection(section, requestId = requestCounter) {
    const playerId = playerIdRef.value
    if (!playerId || requestId !== requestCounter || loadedSections.has(section) || requestedSections.has(section)) return

    requestedSections.add(section)
    loadingSections.value = { ...loadingSections.value, [section]: true }

    try {
      const query = analysisQuery(analysisOptionsRef?.value, section)
      const response = await fetch(`${API_BASE_URL}/api/players/${encodeURIComponent(playerId)}${query}`, {
        headers: { Accept: 'application/json' },
      })
      if (!response.ok) throw new Error(`Request failed with status ${response.status}`)

      const payload = await response.json()
      if (requestId !== requestCounter || !player.value) return

      player.value = { ...player.value, ...normalizedSection(payload.data, section) }
      loadedSections.add(section)
    } catch (fetchError) {
      if (requestId === requestCounter) console.error(fetchError)
    } finally {
      requestedSections.delete(section)
      if (requestId === requestCounter) {
        loadingSections.value = { ...loadingSections.value, [section]: false }
      }
    }
  }

  analysisOptionsRef
    ? watch([playerIdRef, analysisOptionsRef], load, { immediate: true, deep: true })
    : watch(playerIdRef, load, { immediate: true })

  return {
    player: computed(() => player.value),
    loading: computed(() => loading.value),
    error: computed(() => error.value),
    sectionLoading: (section) => computed(() => loadingSections.value[section] === true),
    loadSection,
    refresh: load,
  }
}

function normalizedSection(data, section) {
  const normalized = normalizeProfile(data)
  if (section === 'advanced_stats') return { advancedStats: normalized.advancedStats }
  if (section === 'splits') return { batterSplits: normalized.batterSplits, pitcherSplits: normalized.pitcherSplits }
  if (section === 'similar_players') return { similarPlayers: normalized.similarPlayers }
  if (section === 'analytics') {
    return {
      pitchIndicators: normalized.pitchIndicators,
      battedBallProfile: normalized.battedBallProfile,
      contextualBenchmarks: normalized.contextualBenchmarks,
      trendEvents: normalized.trendEvents,
      analysis: normalized.analysis,
    }
  }

  return {}
}

function analysisQuery(options, sections = null) {
  const params = new URLSearchParams()
  if (options?.range) params.set('range', options.range)
  if (options?.startDate) params.set('start_date', options.startDate)
  if (options?.endDate) params.set('end_date', options.endDate)
  if (options?.paWindow) params.set('pa_window', options.paWindow)
  if (options?.pitchWindow) params.set('pitch_window', options.pitchWindow)
  if (sections) params.set('sections', sections)
  const query = params.toString()
  return query ? `?${query}` : ''
}

function responseMessage(error) {
  if (error.status === 404 || error.message.includes('404')) return 'That player could not be found.'
  if (error.status === 422) return error.message
  return 'Unable to load this player profile. Confirm the Rails API is running and reachable.'
}
