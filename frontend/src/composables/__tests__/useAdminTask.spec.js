import { flushPromises } from '@vue/test-utils'
import { vi } from 'vitest'

import { useAdminTask } from '../useAdminTask'

describe('useAdminTask', () => {
  it('loads the stored schedule date range from the admin overview', async () => {
    vi.stubGlobal(
      'fetch',
      vi.fn().mockResolvedValue({
        ok: true,
        json: async () => ({
          data: [],
          meta: {
            schedule_import_range: {
              earliest_import_date: '2026-03-26',
              latest_import_date: '2026-05-31',
            },
            schedule_date_range: {
              earliest_game_date: '2026-03-26',
              latest_game_date: '2026-09-22',
            },
            mlb_teams: [
              {
                id: 1,
                mlb_id: 116,
                name: 'Detroit Tigers',
                abbreviation: 'DET',
                league: 'american',
              },
            ],
            database: {
              environment: 'development',
              adapter: 'PostgreSQL',
              database_name: 'diamond_iq_development',
              server_version: '16.3',
              size_bytes: 536870912,
              user_table_size_bytes: 402653184,
              table_count: 20,
              estimated_row_count: 4779000,
              estimated_dead_row_count: 1250,
              statistics_collected_since: '2026-07-01T12:00:00Z',
              measured_at: '2026-07-15T22:00:00Z',
              largest_tables: [
                {
                  table_name: 'pitch_data',
                  total_size_bytes: 314572800,
                  data_size_bytes: 251658240,
                  index_size_bytes: 62914560,
                  estimated_row_count: 4649481,
                  estimated_dead_row_count: 1200,
                  database_percentage: 58.59,
                },
              ],
              most_read_tables: [
                {
                  table_name: 'games',
                  total_scans: 19000,
                  sequential_scans: 4000,
                  index_scans: 15000,
                  rows_read_or_fetched: 250000,
                  last_sequential_scan_at: '2026-07-15T20:00:00Z',
                  last_index_scan_at: '2026-07-15T21:59:00Z',
                },
              ],
            },
            player_season_stats: {
              earliest_season: 1876,
              latest_season: 2026,
              approximate_row_count: 4649481,
            },
            pitch_data: {
              earliest_game_date: '2026-04-01',
              latest_game_date: '2026-05-31',
              approximate_row_count: 125000,
            },
            game_details: {
              synchronized_game_count: 72,
              earliest_game_date: '2026-03-26',
              latest_game_date: '2026-05-31',
              batting_line_count: 2100,
              pitching_line_count: 720,
              plate_appearance_count: 5400,
              linked_pitch_count: 18000,
            },
          },
        }),
      }),
    )
    const {
      loadOverview,
      scheduleImportRange,
      scheduleDateRange,
      mlbTeams,
      databaseMetrics,
      playerSeasonStatsMetrics,
      pitchDataMetrics,
      gameDetailsMetrics,
      overviewError,
    } = useAdminTask()

    await loadOverview()

    expect(scheduleImportRange.value).toEqual({
      earliestImportDate: '2026-03-26',
      latestImportDate: '2026-05-31',
    })
    expect(scheduleDateRange.value).toEqual({
      earliestGameDate: '2026-03-26',
      latestGameDate: '2026-09-22',
    })
    expect(mlbTeams.value).toEqual([
      {
        id: 1,
        mlbId: 116,
        name: 'Detroit Tigers',
        abbreviation: 'DET',
        league: 'american',
      },
    ])
    expect(databaseMetrics.value).toEqual({
      environment: 'development',
      adapter: 'PostgreSQL',
      databaseName: 'diamond_iq_development',
      serverVersion: '16.3',
      sizeBytes: 536870912,
      userTableSizeBytes: 402653184,
      tableCount: 20,
      estimatedRowCount: 4779000,
      estimatedDeadRowCount: 1250,
      statisticsCollectedSince: '2026-07-01T12:00:00Z',
      measuredAt: '2026-07-15T22:00:00Z',
      largestTables: [
        {
          tableName: 'pitch_data',
          totalSizeBytes: 314572800,
          dataSizeBytes: 251658240,
          indexSizeBytes: 62914560,
          estimatedRowCount: 4649481,
          estimatedDeadRowCount: 1200,
          databasePercentage: 58.59,
        },
      ],
      mostReadTables: [
        {
          tableName: 'games',
          totalScans: 19000,
          sequentialScans: 4000,
          indexScans: 15000,
          rowsReadOrFetched: 250000,
          lastSequentialScanAt: '2026-07-15T20:00:00Z',
          lastIndexScanAt: '2026-07-15T21:59:00Z',
        },
      ],
    })
    expect(playerSeasonStatsMetrics.value).toEqual({
      earliestSeason: 1876,
      latestSeason: 2026,
      approximateRowCount: 4649481,
    })
    expect(pitchDataMetrics.value).toEqual({
      earliestGameDate: '2026-04-01',
      latestGameDate: '2026-05-31',
      approximateRowCount: 125000,
    })
    expect(gameDetailsMetrics.value).toEqual({
      synchronizedGameCount: 72,
      earliestGameDate: '2026-03-26',
      latestGameDate: '2026-05-31',
      battingLineCount: 2100,
      pitchingLineCount: 720,
      plateAppearanceCount: 5400,
      linkedPitchCount: 18000,
    })
    expect(overviewError.value).toBe('')
  })

  it('runs an allowlisted backend task and stores its result', async () => {
    const fetchMock = vi.fn().mockResolvedValue({
      ok: true,
      json: async () => ({
        task: 'mlb_schedule_sync',
        success: true,
        message: 'Synchronized 12 MLB games',
        data: { created_game_count: 12 },
      }),
    })
    vi.stubGlobal('fetch', fetchMock)
    const { runTask, lastResult, error } = useAdminTask()

    const response = await runTask('mlb_schedule_sync', {
      start_date: '2026-07-15',
      end_date: '2026-07-17',
    })
    await flushPromises()

    expect(response.success).toBe(true)
    expect(fetchMock).toHaveBeenCalledWith(
      '/api/admin/tasks/mlb_schedule_sync/run',
      expect.objectContaining({
        method: 'POST',
        body: JSON.stringify({ start_date: '2026-07-15', end_date: '2026-07-17' }),
      }),
    )
    expect(lastResult.value.message).toBe('Synchronized 12 MLB games')
    expect(lastResult.value.finishedAt).toBeTruthy()
    expect(error.value).toBe('')
  })

  it('loads and maps the data health report', async () => {
    vi.stubGlobal(
      'fetch',
      vi.fn().mockResolvedValue({
        ok: true,
        json: async () => ({
          data: {
            status: 'warning',
            checked_at: '2026-07-17T18:00:00Z',
            calculation_version: '1.0.0',
            summary: {
              check_count: 11,
              healthy_count: 9,
              warning_count: 2,
              critical_count: 0,
              affected_record_count: 12,
            },
            checks: [
              {
                id: 'players_missing_profiles',
                category: 'Players',
                name: 'Players have profiles',
                status: 'warning',
                affected_count: 12,
                description: 'Players are missing profiles.',
                recommendation: 'Synchronize player profiles.',
                examples: ['Test Player · MLB 123'],
              },
            ],
          },
        }),
      }),
    )
    const { loadDataHealth, dataHealth, dataHealthLoading, dataHealthError } = useAdminTask()

    await loadDataHealth()

    expect(dataHealth.value).toEqual({
      status: 'warning',
      checkedAt: '2026-07-17T18:00:00Z',
      calculationVersion: '1.0.0',
      summary: {
        checkCount: 11,
        healthyCount: 9,
        warningCount: 2,
        criticalCount: 0,
        affectedRecordCount: 12,
      },
      checks: [
        {
          id: 'players_missing_profiles',
          category: 'Players',
          name: 'Players have profiles',
          status: 'warning',
          affectedCount: 12,
          description: 'Players are missing profiles.',
          recommendation: 'Synchronize player profiles.',
          examples: ['Test Player · MLB 123'],
        },
      ],
    })
    expect(dataHealthLoading.value).toBe(false)
    expect(dataHealthError.value).toBe('')
  })

  it('exposes backend validation errors', async () => {
    vi.stubGlobal(
      'fetch',
      vi.fn().mockResolvedValue({
        ok: false,
        status: 422,
        json: async () => ({ message: 'Start date is required' }),
      }),
    )
    const { runTask, error, lastResult } = useAdminTask()

    expect(await runTask('mlb_schedule_sync')).toBeNull()
    expect(error.value).toBe('Start date is required')
    expect(lastResult.value).toBeNull()
  })
})
