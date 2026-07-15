import { computed, ref, watch } from 'vue'

const API_BASE_URL = import.meta.env.VITE_API_BASE_URL || ''

function normalizeGame(game) {
  return {
    id: game.id,
    mlbId: game.mlb_id,
    officialDate: game.official_date,
    scheduledAt: game.scheduled_at,
    status: game.status,
    detailedStatus: game.detailed_status,
    venueName: game.venue_name,
    homeScore: game.home_score,
    awayScore: game.away_score,
    homeTeam: game.home_team,
    awayTeam: game.away_team,
    homeProbablePitcher: game.home_probable_pitcher,
    awayProbablePitcher: game.away_probable_pitcher,
  }
}

function normalizeProfile(data) {
  return {
    id: data.id,
    mlbId: data.mlb_id,
    name: data.name,
    abbreviation: data.abbreviation,
    teamName: data.team_name,
    locationName: data.location_name,
    shortName: data.short_name,
    logoUrl: data.logo_url,
    season: data.season,
    availableSeasons: data.available_seasons || [],
    record: data.record || {},
    roster: (data.roster || []).map((membership) => ({
      id: membership.id,
      rosterStatus: membership.roster_status,
      statusDescription: membership.status_description,
      injured: membership.injured,
      jerseyNumber: membership.jersey_number,
      primaryPosition: membership.primary_position,
      startsOn: membership.starts_on,
      lastSyncedAt: membership.last_synced_at,
      player: {
        id: membership.player.id,
        mlbId: membership.player.mlb_id,
        fullName: membership.player.full_name,
        firstName: membership.player.first_name,
        lastName: membership.player.last_name,
        headshotUrl: membership.player.headshot_url,
      },
    })),
    rosterSummary: data.roster_summary || {},
    recentGames: (data.recent_games || []).map(normalizeGame),
    upcomingGames: (data.upcoming_games || []).map(normalizeGame),
    sourceMetadata: {
      lastUpdatedAt: data.source_metadata?.last_updated_at,
      scheduleLastSyncedAt: data.source_metadata?.schedule_last_synced_at,
      rosterLastSyncedAt: data.source_metadata?.roster_last_synced_at,
      sources: data.source_metadata?.sources || [],
    },
  }
}

export function useTeamProfile(teamIdRef, seasonRef) {
  const team = ref(null)
  const loading = ref(false)
  const error = ref('')
  let requestCounter = 0

  async function load() {
    const teamId = teamIdRef.value
    const requestId = ++requestCounter
    if (!teamId) {
      error.value = 'A team id is required.'
      team.value = null
      return
    }

    loading.value = true
    error.value = ''
    const season = seasonRef?.value
    const query = season ? `?season=${encodeURIComponent(season)}` : ''

    try {
      const response = await fetch(`${API_BASE_URL}/api/teams/${encodeURIComponent(teamId)}${query}`, {
        headers: { Accept: 'application/json' },
      })
      if (!response.ok) throw new Error(`Request failed with status ${response.status}`)

      const payload = await response.json()
      if (requestId === requestCounter) team.value = normalizeProfile(payload.data)
    } catch (fetchError) {
      if (requestId !== requestCounter) return
      team.value = null
      error.value = fetchError.message.includes('404')
        ? 'That team could not be found.'
        : 'Unable to load this team profile. Confirm the Rails API is running and reachable.'
      console.error(fetchError)
    } finally {
      if (requestId === requestCounter) loading.value = false
    }
  }

  watch([teamIdRef, ...(seasonRef ? [seasonRef] : [])], load, { immediate: true })

  return {
    team: computed(() => team.value),
    loading: computed(() => loading.value),
    error: computed(() => error.value),
    refresh: load,
  }
}
