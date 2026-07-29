import { flushPromises } from '@vue/test-utils'

import { useSavedAnalyses } from '../useSavedAnalyses'

describe('useSavedAnalyses', () => {
  it('loads and normalizes visible analyses for one surface', async () => {
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue({
      ok: true,
      json: async () => ({
        data: [{
          id: 7,
          name: 'RHP comparison',
          analysis_type: 'player_comparison',
          visibility: 'organization',
          state: { leftPlayerId: 1, rightPlayerId: 2 },
          reproducible_url: '/compare?left=1&right=2',
          share_url: '/saved/7',
          owner: { id: 3, name: 'Scout' },
          editable: false,
        }],
      }),
    }))

    const api = useSavedAnalyses('player_comparison')
    await api.load()

    expect(fetch).toHaveBeenCalledWith(
      '/api/saved_analyses?analysis_type=player_comparison',
      expect.objectContaining({ headers: { Accept: 'application/json' } }),
    )
    expect(api.items.value[0]).toMatchObject({
      id: 7,
      analysisType: 'player_comparison',
      visibility: 'organization',
      reproducibleUrl: '/compare?left=1&right=2',
    })
  })

  it('creates a named view with state, sharing, and a reproducible URL', async () => {
    const fetchMock = vi.fn().mockResolvedValue({
      ok: true,
      json: async () => ({
        data: {
          id: 8,
          name: 'Custom Skubal range',
          analysis_type: 'player_date_range',
          visibility: 'private',
          state: { playerId: 42, range: 'custom' },
          reproducible_url: '/players/42?range=custom&start_date=2026-07-01&end_date=2026-07-28',
          editable: true,
        },
      }),
    })
    vi.stubGlobal('fetch', fetchMock)
    const api = useSavedAnalyses('player_date_range')

    await api.create({
      name: 'Custom Skubal range',
      visibility: 'private',
      state: { playerId: 42, range: 'custom' },
      reproducibleUrl: '/players/42?range=custom&start_date=2026-07-01&end_date=2026-07-28',
    })
    await flushPromises()

    expect(JSON.parse(fetchMock.mock.calls[0][1].body)).toMatchObject({
      name: 'Custom Skubal range',
      analysis_type: 'player_date_range',
      visibility: 'private',
      state: { playerId: 42, range: 'custom' },
    })
    expect(api.items.value[0].editable).toBe(true)
  })
})
