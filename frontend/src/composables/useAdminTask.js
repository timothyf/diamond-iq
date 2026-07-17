import { computed, ref } from 'vue'

import { adminRequestHeaders } from './apiAuth'

const API_BASE_URL = import.meta.env.VITE_API_BASE_URL || ''

export function useAdminTask() {
  const runningTask = ref('')
  const error = ref('')
  const lastResult = ref(null)
  const overviewLoading = ref(false)
  const overviewError = ref('')
  const scheduleImportRange = ref({ earliestImportDate: null, latestImportDate: null })
  const scheduleDateRange = ref({ earliestGameDate: null, latestGameDate: null })
  const mlbTeams = ref([])
  const databaseMetrics = ref({
    environment: '',
    adapter: '',
    databaseName: '',
    serverVersion: '',
    sizeBytes: null,
    userTableSizeBytes: null,
    tableCount: 0,
    estimatedRowCount: 0,
    estimatedDeadRowCount: 0,
    statisticsCollectedSince: null,
    largestTables: [],
    mostReadTables: [],
    measuredAt: null,
  })
  const playerSeasonStatsMetrics = ref({ earliestSeason: null, latestSeason: null, approximateRowCount: 0 })
  const pitchDataMetrics = ref({ earliestGameDate: null, latestGameDate: null, approximateRowCount: 0 })
  const gameDetailsMetrics = ref({
    synchronizedGameCount: 0,
    earliestGameDate: null,
    latestGameDate: null,
    battingLineCount: 0,
    pitchingLineCount: 0,
    plateAppearanceCount: 0,
    linkedPitchCount: 0,
  })

  async function loadOverview() {
    overviewLoading.value = true
    overviewError.value = ''

    try {
      const response = await fetch(`${API_BASE_URL}/api/admin/tasks`, {
        headers: { Accept: 'application/json' },
      })
      const payload = await response.json()

      if (!response.ok) {
        throw new Error(payload?.message || `Admin overview failed with status ${response.status}.`)
      }

      const range = payload?.meta?.schedule_date_range || {}
      const importRange = payload?.meta?.schedule_import_range || {}
      scheduleImportRange.value = {
        earliestImportDate: importRange.earliest_import_date || null,
        latestImportDate: importRange.latest_import_date || null,
      }
      scheduleDateRange.value = {
        earliestGameDate: range.earliest_game_date || null,
        latestGameDate: range.latest_game_date || null,
      }
      mlbTeams.value = (payload?.meta?.mlb_teams || []).map((team) => ({
        id: team.id,
        mlbId: team.mlb_id,
        name: team.name,
        abbreviation: team.abbreviation,
        league: team.league,
      }))
      const database = payload?.meta?.database || {}
      databaseMetrics.value = {
        environment: database.environment || '',
        adapter: database.adapter || '',
        databaseName: database.database_name || '',
        serverVersion: database.server_version || '',
        sizeBytes:
          database.size_bytes !== null &&
          database.size_bytes !== undefined &&
          Number.isFinite(Number(database.size_bytes))
            ? Number(database.size_bytes)
            : null,
        userTableSizeBytes:
          database.user_table_size_bytes !== null && database.user_table_size_bytes !== undefined
            ? Number(database.user_table_size_bytes)
            : null,
        tableCount: Number(database.table_count || 0),
        estimatedRowCount: Number(database.estimated_row_count || 0),
        estimatedDeadRowCount: Number(database.estimated_dead_row_count || 0),
        statisticsCollectedSince: database.statistics_collected_since || null,
        largestTables: (database.largest_tables || []).map((table) => ({
          tableName: table.table_name,
          totalSizeBytes: Number(table.total_size_bytes || 0),
          dataSizeBytes: Number(table.data_size_bytes || 0),
          indexSizeBytes: Number(table.index_size_bytes || 0),
          estimatedRowCount: Number(table.estimated_row_count || 0),
          estimatedDeadRowCount: Number(table.estimated_dead_row_count || 0),
          databasePercentage: Number(table.database_percentage || 0),
        })),
        mostReadTables: (database.most_read_tables || []).map((table) => ({
          tableName: table.table_name,
          totalScans: Number(table.total_scans || 0),
          sequentialScans: Number(table.sequential_scans || 0),
          indexScans: Number(table.index_scans || 0),
          rowsReadOrFetched: Number(table.rows_read_or_fetched || 0),
          lastSequentialScanAt: table.last_sequential_scan_at || null,
          lastIndexScanAt: table.last_index_scan_at || null,
        })),
        measuredAt: database.measured_at || null,
      }
      const playerSeasonStats = payload?.meta?.player_season_stats || {}
      playerSeasonStatsMetrics.value = {
        earliestSeason: playerSeasonStats.earliest_season ?? null,
        latestSeason: playerSeasonStats.latest_season ?? null,
        approximateRowCount: Number(playerSeasonStats.approximate_row_count || 0),
      }
      const pitchData = payload?.meta?.pitch_data || {}
      pitchDataMetrics.value = {
        earliestGameDate: pitchData.earliest_game_date || null,
        latestGameDate: pitchData.latest_game_date || null,
        approximateRowCount: Number(pitchData.approximate_row_count || 0),
      }
      const gameDetails = payload?.meta?.game_details || {}
      gameDetailsMetrics.value = {
        synchronizedGameCount: Number(gameDetails.synchronized_game_count || 0),
        earliestGameDate: gameDetails.earliest_game_date || null,
        latestGameDate: gameDetails.latest_game_date || null,
        battingLineCount: Number(gameDetails.batting_line_count || 0),
        pitchingLineCount: Number(gameDetails.pitching_line_count || 0),
        plateAppearanceCount: Number(gameDetails.plate_appearance_count || 0),
        linkedPitchCount: Number(gameDetails.linked_pitch_count || 0),
      }
      return payload
    } catch (overviewLoadError) {
      overviewError.value = overviewLoadError.message || 'Unable to load the admin overview.'
      return null
    } finally {
      overviewLoading.value = false
    }
  }

  async function runTask(taskName, parameters = {}) {
    runningTask.value = taskName
    error.value = ''

    try {
      const response = await fetch(`${API_BASE_URL}/api/admin/tasks/${encodeURIComponent(taskName)}/run`, {
        method: 'POST',
        headers: adminRequestHeaders({
          Accept: 'application/json',
          'Content-Type': 'application/json',
        }),
        body: JSON.stringify(parameters),
      })
      const payload = await response.json()

      if (!response.ok) {
        throw new Error(payload?.message || `Admin task failed with status ${response.status}.`)
      }

      lastResult.value = {
        ...payload,
        finishedAt: new Date().toISOString(),
      }
      return payload
    } catch (taskError) {
      error.value = taskError.message || 'Unable to run the admin task.'
      return null
    } finally {
      runningTask.value = ''
    }
  }

  return {
    runningTask: computed(() => runningTask.value),
    error: computed(() => error.value),
    lastResult: computed(() => lastResult.value),
    overviewLoading: computed(() => overviewLoading.value),
    overviewError: computed(() => overviewError.value),
    scheduleImportRange: computed(() => scheduleImportRange.value),
    scheduleDateRange: computed(() => scheduleDateRange.value),
    mlbTeams: computed(() => mlbTeams.value),
    databaseMetrics: computed(() => databaseMetrics.value),
    playerSeasonStatsMetrics: computed(() => playerSeasonStatsMetrics.value),
    pitchDataMetrics: computed(() => pitchDataMetrics.value),
    gameDetailsMetrics: computed(() => gameDetailsMetrics.value),
    loadOverview,
    runTask,
  }
}
