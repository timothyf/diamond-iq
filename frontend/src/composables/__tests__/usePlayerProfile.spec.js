import { computed } from 'vue'
import { flushPromises } from '@vue/test-utils'
import { vi } from 'vitest'

import { usePlayerProfile } from '../usePlayerProfile'

describe('usePlayerProfile', () => {
  it('fetches and normalizes the unified player profile', async () => {
    const fetchMock = vi.fn().mockResolvedValue({
      ok: true,
      json: async () => ({
        data: {
          id: 42,
          mlb_id: 680776,
          first_name: 'Riley',
          last_name: 'Greene',
          full_name: 'Riley Greene',
          team: { id: 1, mlb_id: 116, name: 'Detroit Tigers', abbreviation: 'DET' },
          profile: {
            bats: 'L',
            throws: 'L',
            formatted_height: `6' 3"`,
            weight_pounds: 200,
            source_name: 'MLB Stats API',
          },
          positions: { primary: { abbreviation: 'CF', name: 'Outfielder' }, secondary: [], assignments: [] },
          season_overview: {
            season: 2026,
            category: 'batting',
            preferred_category: 'batting',
            stats: [{ key: 'homeRuns', label: 'HR', value: '18.0' }],
          },
          career_overview: {
            category: 'batting',
            preferred_category: 'batting',
            first_season: 2022,
            last_season: 2026,
            season_count: 5,
            stats: [{ key: 'homeRuns', label: 'HR', value: '82' }],
          },
          current_membership: {
            id: 8,
            team: { id: 1, mlb_id: 116, name: 'Detroit Tigers', abbreviation: 'DET' },
            roster_status: 'active',
            starts_on: '2026-03-26',
          },
          team_history: [],
          recent_pitch_indicators: {
            sample_size: 100,
            primary_role: 'batter',
            batting: { pitches_seen: 100, average_exit_velocity: 91.2 },
            pitching: { pitch_count: 0 },
          },
          contextual_benchmarks: {
            available: true,
            source_start_date: '2026-03-26',
            source_end_date: '2026-07-14',
            calculation_version: '1.0.0',
            metrics: [
              {
                metric_key: 'ops',
                metric_group: 'batting',
                display_name: 'OPS',
                unit: 'rate',
                raw_value: 0.842,
                mlb_average: 0.72,
                percentile: 82.5,
                sample_size: 480,
              },
            ],
          },
          source_metadata: {
            last_updated_at: '2026-07-14T12:00:00Z',
            sources: ['MLB Stats API'],
            datasets: [
              { name: 'profile', source_name: 'MLB Stats API', last_updated_at: '2026-07-14T12:00:00Z' },
            ],
          },
        },
      }),
    })
    vi.stubGlobal('fetch', fetchMock)

    const { player, loading, error } = usePlayerProfile(computed(() => '42'))
    await flushPromises()

    expect(fetchMock).toHaveBeenCalledWith('/api/players/42', {
      headers: { Accept: 'application/json' },
    })
    expect(player.value).toMatchObject({
      id: 42,
      mlbId: 680776,
      fullName: 'Riley Greene',
      team: { abbreviation: 'DET' },
      currentMembership: { rosterStatus: 'active' },
      seasonOverview: { season: 2026, category: 'batting' },
      careerOverview: { category: 'batting', firstSeason: 2022, lastSeason: 2026, seasonCount: 5 },
      pitchIndicators: { primaryRole: 'batter' },
      contextualBenchmarks: {
        available: true,
        sourceStartDate: '2026-03-26',
        sourceEndDate: '2026-07-14',
        metrics: [
          expect.objectContaining({ metricKey: 'ops', rawValue: 0.842, mlbAverage: 0.72, percentile: 82.5 }),
        ],
      },
    })
    expect(player.value.sourceMetadata.datasets[0]).toEqual({
      name: 'profile',
      sourceName: 'MLB Stats API',
      lastUpdatedAt: '2026-07-14T12:00:00Z',
    })
    expect(loading.value).toBe(false)
    expect(error.value).toBe('')
  })

  it('exposes a useful not-found message', async () => {
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue({ ok: false, status: 404 }))

    const { player, error } = usePlayerProfile(computed(() => '404'))
    await flushPromises()

    expect(player.value).toBeNull()
    expect(error.value).toBe('That player could not be found.')
  })
})
