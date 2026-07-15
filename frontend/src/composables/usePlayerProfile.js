import { computed, ref, watch } from 'vue'

const API_BASE_URL = import.meta.env.VITE_API_BASE_URL || ''

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
  const indicators = data.recent_pitch_indicators || {}
  const source = data.source_metadata || {}

  return {
    id: data.id,
    mlbId: data.mlb_id,
    firstName: data.first_name,
    lastName: data.last_name,
    fullName: data.full_name,
    team: normalizeTeam(data.team),
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
      stats: career.stats || [],
    },
    currentMembership: normalizeMembership(data.current_membership),
    teamHistory: (data.team_history || []).map(normalizeMembership),
    pitchIndicators: {
      sampleSize: indicators.sample_size || 100,
      primaryRole: indicators.primary_role || 'batter',
      pitching: indicators.pitching || {},
      batting: indicators.batting || {},
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

export function usePlayerProfile(playerIdRef) {
  const player = ref(null)
  const loading = ref(false)
  const error = ref('')
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

    try {
      const response = await fetch(`${API_BASE_URL}/api/players/${encodeURIComponent(playerId)}`, {
        headers: { Accept: 'application/json' },
      })

      if (!response.ok) {
        throw new Error(`Request failed with status ${response.status}`)
      }

      const payload = await response.json()
      if (requestId !== requestCounter) return

      player.value = normalizeProfile(payload.data)
    } catch (fetchError) {
      if (requestId !== requestCounter) return

      player.value = null
      error.value = responseMessage(fetchError)
      console.error(fetchError)
    } finally {
      if (requestId === requestCounter) loading.value = false
    }
  }

  watch(playerIdRef, load, { immediate: true })

  return {
    player: computed(() => player.value),
    loading: computed(() => loading.value),
    error: computed(() => error.value),
    refresh: load,
  }
}

function responseMessage(error) {
  if (error.message.includes('404')) return 'That player could not be found.'
  return 'Unable to load this player profile. Confirm the Rails API is running and reachable.'
}
