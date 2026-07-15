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
              size_bytes: 536870912,
            },
          },
        }),
      }),
    )
    const { loadOverview, scheduleImportRange, scheduleDateRange, mlbTeams, databaseMetrics, overviewError } = useAdminTask()

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
      sizeBytes: 536870912,
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
