import { flushPromises } from '@vue/test-utils'

import { usePlayerSeasonStatsImport } from '../usePlayerSeasonStatsImport'

describe('usePlayerSeasonStatsImport', () => {
  it('uploads a csv file and returns an import summary', async () => {
    const fetchMock = vi.fn().mockResolvedValue({
      ok: true,
      json: async () => ({
        message: 'Imported 10 player season stats',
        data: {
          created_player_count: 3,
          created_team_count: 2,
          skipped_count: 0,
        },
      }),
    })

    vi.stubGlobal('fetch', fetchMock)

    const { importFile, uploading, error, summary } = usePlayerSeasonStatsImport()
    const file = new File(['season,player'], 'season-stats.csv', { type: 'text/csv' })

    const payload = await importFile(file)
    await flushPromises()

    expect(fetchMock).toHaveBeenCalledTimes(1)
    expect(fetchMock.mock.calls[0][0]).toBe('/api/player_season_stats/import')
    expect(fetchMock.mock.calls[0][1]).toMatchObject({
      method: 'POST',
      headers: { Accept: 'application/json' },
    })
    expect(fetchMock.mock.calls[0][1].body).toBeInstanceOf(FormData)
    expect(payload.message).toBe('Imported 10 player season stats')
    expect(uploading.value).toBe(false)
    expect(error.value).toBe('')
    expect(summary.value).toBe('Imported 10 player season stats Created 3 players and 2 teams.')
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
