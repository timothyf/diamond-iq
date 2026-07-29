import { flushPromises } from '@vue/test-utils'

import { usePlayerSeasonStatsImport } from '../usePlayerSeasonStatsImport'

describe('usePlayerSeasonStatsImport', () => {
  it('uploads a csv file and returns an import summary', async () => {
    const fetchMock = vi.fn().mockResolvedValue({
      ok: true,
      json: async () => ({
        data: {
          id: 15,
          task_name: 'player_season_stats_import',
          status: 'queued',
          total_items: 1,
          completed_items: 0,
          failed_items: 0,
          processed_items: 0,
          progress_percentage: 0,
          initiated_by: { id: 1, name: 'Admin User', email: 'admin@example.com', role: 'administrator' },
          result_data: {},
        },
      }),
    })

    vi.stubGlobal('fetch', fetchMock)

    const { importFile, uploading, error, summary } = usePlayerSeasonStatsImport()
    const file = new File(['season,player'], 'season-stats.csv', { type: 'text/csv' })

    const payload = await importFile(file, { replaceSeason: true })
    await flushPromises()

    expect(fetchMock).toHaveBeenCalledTimes(1)
    expect(fetchMock.mock.calls[0][0]).toBe('/api/player_season_stats/import')
    expect(fetchMock.mock.calls[0][1]).toMatchObject({
      method: 'POST',
      headers: { Accept: 'application/json' },
    })
    expect(fetchMock.mock.calls[0][1].body).toBeInstanceOf(FormData)
    expect(fetchMock.mock.calls[0][1].body.get('replace_season')).toBe('1')
    expect(payload).toMatchObject({ id: 15, status: 'queued' })
    expect(uploading.value).toBe(true)
    expect(error.value).toBe('')
    expect(summary.value).toBe('Queued by Admin User · waiting for a background worker.')
  })

  it('surfaces an import error when the request fails', async () => {
    vi.stubGlobal(
      'fetch',
      vi.fn().mockResolvedValue({
        ok: false,
        status: 422,
        json: async () => ({
          message: 'Missing required stat columns: ops',
        }),
      }),
    )

    const { importFile, error, summary } = usePlayerSeasonStatsImport()
    const file = new File(['season,player'], 'season-stats.csv', { type: 'text/csv' })

    const payload = await importFile(file)
    await flushPromises()

    expect(payload).toBeNull()
    expect(summary.value).toBe('')
    expect(error.value).toBe('Missing required stat columns: ops')
  })
})
