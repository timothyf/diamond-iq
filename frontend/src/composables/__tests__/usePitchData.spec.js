import { computed, nextTick } from 'vue'
import { flushPromises } from '@vue/test-utils'

import { usePitchData } from '../usePitchData'

describe('usePitchData', () => {
  it('fetches pitch rows and normalizes metadata from the API', async () => {
    const fetchMock = vi.fn().mockResolvedValue({
      ok: true,
      json: async () => ({
        data: [
          {
            id: 11,
            game_date: '2026-04-30',
            game_pk: 777,
            at_bat_number: 3,
            pitch_number: 2,
            pitcher: 9001,
            pitcher_name: 'Matthew Boyd',
            batter: 8001,
            batter_name: 'Shohei Ohtani',
            pitch_type: 'FF',
            release_speed: 97.8,
            release_spin_rate: 2350,
            launch_speed: 105.4,
            launch_angle: 17.2,
            hit_distance_sc: 398,
            balls: 2,
            strikes: 1,
            zone: 1,
            inning: 5,
            inning_topbot: 'bot',
            description: 'called_strike',
            events: 'strikeout',
            pitch_name: '4-Seam Fastball',
            player_name: 'Pitcher One',
          },
        ],
        meta: {
          count: 1,
          limit: 100,
          page: 2,
          per_page: 100,
          total_pages: 3,
          total_count: 250,
          data_range: { type: 'game_date', start: '2026-04-01', end: '2026-04-30' },
        },
      }),
    })

    vi.stubGlobal('fetch', fetchMock)

    const query = computed(() => ({ page: 2, perPage: 100 }))
    const { rows, meta, loading, error } = usePitchData(query)

    await flushPromises()

    expect(fetchMock).toHaveBeenCalledWith('/api/pitch_data?page=2&per_page=100', {
      headers: {
        Accept: 'application/json',
      },
    })
    expect(rows.value).toEqual([
      {
        id: 11,
        rank: 101,
        gameDate: '2026-04-30',
        gamePk: 777,
        atBatNumber: 3,
        pitchNumber: 2,
        pitcher: 9001,
        pitcherName: 'Matthew Boyd',
        playerName: 'Pitcher One',
        batter: 8001,
        batterName: 'Shohei Ohtani',
        pitchType: 'FF',
        releaseSpeed: 97.8,
        releaseSpinRate: 2350,
        launchSpeed: 105.4,
        launchAngle: 17.2,
        hitDistanceSc: 398,
        balls: 2,
        strikes: 1,
        count: '2-1',
        zone: 1,
        inning: 5,
        inningTopbot: 'bot',
        inningDisplay: 'Bot 5',
        description: 'called_strike',
        events: 'strikeout',
        pitchName: '4-Seam Fastball',
      },
    ])
    expect(meta.value).toEqual({
      count: 1,
      limit: 100,
      perPage: 100,
      page: 2,
      totalPages: 3,
      totalCount: 250,
      dataRange: { type: 'game_date', start: '2026-04-01', end: '2026-04-30' },
      availableEvents: [],
      availablePitchTypes: [],
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

    const query = computed(() => ({ page: 1, perPage: 50 }))
    const { rows, meta, error } = usePitchData(query)

    await flushPromises()
    await nextTick()

    expect(rows.value).toEqual([])
    expect(meta.value.count).toBe(0)
    expect(meta.value.perPage).toBe(50)
    expect(error.value).toContain('Unable to load pitch data')
  })

  it('serializes pitch filter params into the request URL', async () => {
    const fetchMock = vi.fn().mockResolvedValue({
      ok: true,
      json: async () => ({
        data: [],
        meta: { count: 0, limit: 50 },
      }),
    })

    vi.stubGlobal('fetch', fetchMock)

    const query = computed(() => ({
      page: 3,
      perPage: 50,
      gameDateStart: '2026-04-25',
      gameDateEnd: '2026-04-30',
      gamePk: '777',
      pitcher: '9001',
      batter: '8001',
      pitchType: 'FF',
      events: 'strikeout',
    }))

    usePitchData(query)

    await flushPromises()

    expect(fetchMock).toHaveBeenCalledWith(
      '/api/pitch_data?page=3&per_page=50&game_date_start=2026-04-25&game_date_end=2026-04-30&game_pk=777&pitcher=9001&batter=8001&pitch_type=FF&events=strikeout',
      {
        headers: {
          Accept: 'application/json',
        },
      },
    )
  })
})
