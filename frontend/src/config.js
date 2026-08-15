const env = import.meta.env

function numberSetting(name, fallback) {
  const value = Number(env[name])
  return Number.isFinite(value) && value >= 0 ? value : fallback
}

export const frontendConfig = Object.freeze({
  apiBaseUrl: env.VITE_API_BASE_URL || '',
  adminApiToken: env.VITE_ADMIN_API_TOKEN || '',
  pollingIntervalMs: numberSetting('VITE_POLL_INTERVAL_MS', 1500),
  searchDebounceMs: numberSetting('VITE_SEARCH_DEBOUNCE_MS', 250),
  playerSuggestionDebounceMs: numberSetting('VITE_PLAYER_SUGGESTION_DEBOUNCE_MS', 180),
  playerSearchLimit: numberSetting('VITE_PLAYER_SEARCH_LIMIT', 8),
  teamSearchLimit: numberSetting('VITE_TEAM_SEARCH_LIMIT', 8),
  playerSuggestionLimit: numberSetting('VITE_PLAYER_SUGGESTION_LIMIT', 8),
  comparisonPlayerLimit: numberSetting('VITE_COMPARISON_PLAYER_LIMIT', 6),
  adminProfileBatchSize: numberSetting('VITE_ADMIN_PROFILE_BATCH_SIZE', 50),
  defaultPitchDataPerPage: numberSetting('VITE_DEFAULT_PITCH_DATA_PER_PAGE', 20),
  defaultStatsPerPage: numberSetting('VITE_DEFAULT_STATS_PER_PAGE', 15),
  externalUrls: Object.freeze({
    mlbStaticBaseUrl: env.VITE_MLB_STATIC_BASE_URL || 'https://www.mlbstatic.com',
    mlbHeadshotBaseUrl: env.VITE_MLB_HEADSHOT_BASE_URL || 'https://img.mlbstatic.com',
    mlbPlayerBaseUrl: env.VITE_MLB_PLAYER_BASE_URL || 'https://www.mlb.com/player',
    mlbTeamBaseUrl: env.VITE_MLB_TEAM_BASE_URL || 'https://www.mlb.com',
    fangraphsBaseUrl: env.VITE_FANGRAPHS_BASE_URL || 'https://www.fangraphs.com/players',
    fangraphsLegacyUrl: env.VITE_FANGRAPHS_LEGACY_URL || 'https://www.fangraphs.com/players.aspx',
    baseballReferenceBaseUrl: env.VITE_BASEBALL_REFERENCE_BASE_URL || 'https://www.baseball-reference.com/players',
    baseballReferenceSearchUrl: env.VITE_BASEBALL_REFERENCE_SEARCH_URL || 'https://www.baseball-reference.com/search/search.fcgi',
    baseballSavantPlayerBaseUrl: env.VITE_BASEBALL_SAVANT_PLAYER_BASE_URL || 'https://baseballsavant.mlb.com/savant-player',
    baseballSavantTeamBaseUrl: env.VITE_BASEBALL_SAVANT_TEAM_BASE_URL || 'https://baseballsavant.mlb.com/team',
    baseballReferenceTeamBaseUrl: env.VITE_BASEBALL_REFERENCE_TEAM_BASE_URL || 'https://www.baseball-reference.com/teams',
    fangraphsTeamBaseUrl: env.VITE_FANGRAPHS_TEAM_BASE_URL || 'https://www.fangraphs.com/teams',
  }),
})

export const API_BASE_URL = frontendConfig.apiBaseUrl

export function teamLogoUrl(mlbId) {
  return `${frontendConfig.externalUrls.mlbStaticBaseUrl}/team-logos/${mlbId}.svg`
}
