import { computed, nextTick } from 'vue'
import { flushPromises } from '@vue/test-utils'

import { usePlayerSeasonStats } from '../usePlayerSeasonStats'

describe('usePlayerSeasonStats', () => {
  it('fetches rows and normalizes metadata from the API', async () => {
    const fetchMock = vi.fn().mockResolvedValue({
      ok: true,
      json: async () => ({
        data: [
          {
            id: 1,
            value: '3.2',
          },
        ],
        meta: {
          page: 2,
          per_page: 12,
          total_count: 45,
          total_pages: 4,
          sort: '-homeRuns',
          filters: { category: 'batting' },
          category: 'batting',
          data_range: { type: 'season', start: 1970, end: 2026 },
          available_seasons: [2026, 2025, 2024],
          available_teams: [{ id: 1, abbreviation: 'DET', short_name: 'Tigers' }],
          columns: [{ key: 'homeRuns', label: 'HR', align: 'numeric' }],
        },
      }),
    })

    vi.stubGlobal('fetch', fetchMock)

    const query = computed(() => ({
      view: 'leaderboard',
      page: 2,
      perPage: 12,
      sort: '-homeRuns',
      filters: {
        category: 'batting',
        player_name: 'miguel',
      },
    }))

    const { rows, meta, loading, error } = usePlayerSeasonStats(query)

    await flushPromises()

    expect(fetchMock).toHaveBeenCalledWith(
      '/api/player_season_stats?view=leaderboard&page=2&per_page=12&sort=-homeRuns&filter%5Bcategory%5D=batting&filter%5Bplayer_name%5D=miguel',
      {
        headers: {
          Accept: 'application/json',
        },
      },
    )
    expect(rows.value).toEqual([{ id: 1, value: '3.2' }])
    expect(meta.value).toEqual({
      page: 2,
      perPage: 12,
      totalCount: 45,
      totalPages: 4,
      sort: '-homeRuns',
      filters: { category: 'batting' },
      category: 'batting',
      dataRange: { type: 'season', start: 1970, end: 2026 },
      availableSeasons: [2026, 2025, 2024],
      availableTeams: [{ id: 1, abbreviation: 'DET', short_name: 'Tigers' }],
      columns: [{ key: 'homeRuns', label: 'HR', align: 'numeric' }],
    })
    expect(loading.value).toBe(false)
    expect(error.value).toBe('')
  })

  it('exposes a friendly error when the request fails', async () => {
    vi.stubGlobal(
      'fetch',
      vi.fn().mockResolvedValue({
        ok: false,
        status: 500,
      }),
    )
    const query = computed(() => ({
      view: 'leaderboard',
      page: 1,
      perPage: 12,
      sort: 'season',
      filters: {},
    }))

    const { rows, meta, error } = usePlayerSeasonStats(query)

    await flushPromises()
    await nextTick()

    expect(rows.value).toEqual([])
    expect(meta.value.totalCount).toBe(0)
    expect(error.value).toContain('Unable to load player season stats')
  })
})
