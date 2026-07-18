import { computed, ref, watch } from 'vue'

const API_BASE_URL = import.meta.env.VITE_API_BASE_URL || ''

function normalizeLine(line) {
  return {
    ...line,
    player: line.player || null,
    team: line.team || null,
  }
}

function normalizeGame(data) {
  const details = data.details || {}
  const lineScore = details.line_score || {}

  return {
    id: data.id,
    mlbId: data.mlb_id,
    officialDate: data.official_date,
    scheduledAt: data.scheduled_at,
    status: data.status,
    detailedStatus: data.detailed_status,
    venueName: data.venue_name,
    gameNumber: data.game_number,
    homeScore: data.home_score,
    awayScore: data.away_score,
    homeTeam: data.home_team,
    awayTeam: data.away_team,
    homeProbablePitcher: data.home_probable_pitcher,
    awayProbablePitcher: data.away_probable_pitcher,
    details: {
      synchronized: Boolean(details.synchronized),
      lastSyncedAt: details.last_synced_at || null,
      insights: details.insights || {
        decisions: { winning_pitcher: null, losing_pitcher: null, save: null },
        teams: { away: {}, home: {} },
      },
      lineScore: {
        currentInning: lineScore.current_inning ?? null,
        currentInningOrdinal: lineScore.current_inning_ordinal || null,
        inningState: lineScore.inning_state || null,
        innings: lineScore.innings || [],
        totals: lineScore.totals || {
          away: { runs: data.away_score, hits: null, errors: null },
          home: { runs: data.home_score, hits: null, errors: null },
        },
      },
      battingLines: (details.batting_lines || []).map(normalizeLine),
      pitchingLines: (details.pitching_lines || []).map(normalizeLine),
    },
  }
}

export function useGameSummary(gameIdRef) {
  const game = ref(null)
  const loading = ref(false)
  const error = ref('')
  let requestCounter = 0

  async function load() {
    const gameId = gameIdRef.value
    const requestId = ++requestCounter
    if (!gameId) {
      game.value = null
      error.value = 'A game id is required.'
      return
    }

    loading.value = true
    error.value = ''

    try {
      const response = await fetch(`${API_BASE_URL}/api/games/${encodeURIComponent(gameId)}`, {
        headers: { Accept: 'application/json' },
      })
      if (!response.ok) throw new Error(`Request failed with status ${response.status}`)

      const payload = await response.json()
      if (requestId === requestCounter) game.value = normalizeGame(payload.data || {})
    } catch (fetchError) {
      if (requestId !== requestCounter) return
      game.value = null
      error.value = fetchError.message.includes('404')
        ? 'That game could not be found.'
        : 'Unable to load the game summary. Confirm the Rails API is running and reachable.'
    } finally {
      if (requestId === requestCounter) loading.value = false
    }
  }

  watch(gameIdRef, load, { immediate: true })

  return {
    game: computed(() => game.value),
    loading: computed(() => loading.value),
    error: computed(() => error.value),
    refresh: load,
  }
}
