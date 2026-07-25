import { flushPromises, mount } from '@vue/test-utils'
import { vi } from 'vitest'

import PlayerProfileView from '../PlayerProfileView.vue'

function apiPayload() {
  return {
    data: {
      id: 42,
      mlb_id: 680776,
      first_name: 'Riley',
      last_name: 'Greene',
      full_name: 'Riley Greene',
      team: { id: 1, mlb_id: 116, name: 'Detroit Tigers', abbreviation: 'DET' },
      display_team: { id: 1, mlb_id: 116, name: 'Detroit Tigers', abbreviation: 'DET' },
      external_ids: { baseball_reference: 'greenri03', fangraphs: '25976' },
      profile: {
        age: 25,
        birth_date: '2000-09-28',
        formatted_height: `6' 3"`,
        weight_pounds: 200,
        bats: 'L',
        throws: 'L',
        mlb_debut_date: '2022-06-18',
        headshot_url:
          'https://img.mlbstatic.com/mlb-photos/image/upload/ar_20:23,c_fill,g_north,w_260/c_pad,b_auto:border,w_300,h_300,q_auto:best/v1/people/680776/headshot/67/current',
      },
      positions: {
        primary: { abbreviation: 'CF', name: 'Outfielder' },
        secondary: [],
        assignments: [],
      },
      season_overview: {
        season: 2026,
        category: 'batting',
        preferred_category: 'batting',
        stats: [
          { key: 'homeRuns', label: 'HR', value: '18.0', scope_key: 'DET' },
          { key: 'ops', label: 'OPS', value: '0.842', scope_key: 'DET' },
        ],
      },
      career_overview: {
        category: 'batting',
        preferred_category: 'batting',
        first_season: 2022,
        last_season: 2026,
        season_count: 5,
        columns: [
          { key: 'gamesPlayed', label: 'G' },
          { key: 'homeRuns', label: 'HR' },
          { key: 'ops', label: 'OPS' },
        ],
        seasons: [
          {
            season: 2022,
            teams: [{ id: 1, mlb_id: 116, name: 'Detroit Tigers', abbreviation: 'DET' }],
            stats: [
              { key: 'gamesPlayed', label: 'G', value: '93' },
              { key: 'homeRuns', label: 'HR', value: '5' },
              { key: 'ops', label: 'OPS', value: '0.740' },
            ],
          },
          {
            season: 2026,
            teams: [{ id: 1, mlb_id: 116, name: 'Detroit Tigers', abbreviation: 'DET' }],
            stats: [
              { key: 'gamesPlayed', label: 'G', value: '120' },
              { key: 'homeRuns', label: 'HR', value: '18' },
              { key: 'ops', label: 'OPS', value: '0.842' },
            ],
          },
        ],
        stats: [
          { key: 'gamesPlayed', label: 'G', value: '590' },
          { key: 'homeRuns', label: 'HR', value: '82' },
          { key: 'ops', label: 'OPS', value: '0.821' },
        ],
      },
      current_membership: {
        id: 8,
        team: { id: 1, mlb_id: 116, name: 'Detroit Tigers', abbreviation: 'DET' },
        starts_on: '2026-03-26',
        roster_status: 'active',
        source_status_description: 'Active',
        jersey_number: '31',
      },
      team_history: [
        {
          id: 8,
          team: { id: 1, mlb_id: 116, name: 'Detroit Tigers', abbreviation: 'DET' },
          starts_on: '2026-03-26',
          current: true,
          roster_status: 'active',
          source_status_description: 'Active',
        },
      ],
      recent_pitch_indicators: {
        sample_size: 100,
        primary_role: 'batter',
        batting: {
          pitches_seen: 100,
          game_count: 8,
          batted_ball_count: 22,
          average_exit_velocity: 91.2,
          max_exit_velocity: 109.5,
          hard_hit_percentage: 45.5,
        },
        pitching: { pitch_count: 0, game_count: 0 },
      },
      contextual_benchmarks: {
        available: true,
        source_start_date: '2026-03-26',
        source_end_date: '2026-07-14',
        previous_start_date: '2025-12-05',
        previous_end_date: '2026-03-25',
        calculation_version: '1.0.0',
        metrics: [
          {
            metric_key: 'ops',
            metric_group: 'batting',
            display_name: 'OPS',
            unit: 'rate',
            raw_value: 0.842,
            mlb_average: 0.72,
            position_average: 0.745,
            position_key: 'CF',
            percentile: 82.5,
            previous_value: 0.79,
            change_value: 0.052,
            sample_size: 480,
            mlb_player_count: 280,
          },
        ],
      },
      analysis: {
        range: {
          preset: 'season',
          start_date: '2026-01-01',
          end_date: '2026-07-14',
          previous_start_date: '2025-06-20',
          previous_end_date: '2025-12-31',
          plate_appearance_window: 50,
          pitch_window: 100,
        },
        summary: {
          current: {
            batting: { average_exit_velocity: 91.2, hard_hit_percentage: 45.5, whiff_percentage: 24.0, chase_percentage: 28.0 },
            pitching: { average_velocity: null, whiff_percentage: null, chase_percentage: null },
          },
          previous: {
            batting: { average_exit_velocity: 89.8, hard_hit_percentage: 40.0, whiff_percentage: 26.0, chase_percentage: 30.0 },
            pitching: { average_velocity: null, whiff_percentage: null, chase_percentage: null },
          },
          changes: {},
        },
        batting: {
          window_type: 'plate_appearances',
          window_size: 50,
          total_observations: 480,
          charts: [
            {
              key: 'exit_velocity', title: 'Exit velocity', unit: 'mph',
              series: [{ key: 'exit_velocity', label: 'Exit velocity', points: [
                { date: '2026-04-01', sequence: 1, value: 89.0, sample_size: 1 },
                { date: '2026-07-14', sequence: 480, value: 91.2, sample_size: 18 },
              ] }],
            },
          ],
        },
        pitching: { window_type: 'pitches', window_size: 100, total_observations: 0, charts: [] },
      },
      source_metadata: {
        last_updated_at: '2026-07-14T12:00:00Z',
        sources: ['MLB Stats API', 'Baseball Savant'],
        datasets: [
          { name: 'profile', source_name: 'MLB Stats API', last_updated_at: '2026-07-14T12:00:00Z' },
          { name: 'pitch_data', source_name: 'Baseball Savant', last_updated_at: '2026-07-14T11:00:00Z' },
        ],
      },
    },
  }
}

function apiPayloadWith(mutator) {
  const payload = structuredClone(apiPayload())
  mutator(payload)
  return payload
}

describe('PlayerProfileView', () => {
  it('uses the longest-served team in a retired player header', async () => {
    const payload = apiPayloadWith((response) => {
      response.data.team = { id: 2, mlb_id: 146, name: 'Miami Marlins', abbreviation: 'MIA' }
      response.data.display_team = { id: 3, mlb_id: 110, name: 'Baltimore Orioles', abbreviation: 'BAL' }
      response.data.current_membership = null
    })
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue({ ok: true, json: async () => payload }))

    const wrapper = mount(PlayerProfileView, {
      props: { playerId: '42' },
      global: { stubs: { RouterLink: { template: '<a><slot /></a>' } } },
    })
    await flushPromises()

    expect(wrapper.get('.profile-teamline').text()).toContain('Baltimore Orioles')
    expect(wrapper.get('.profile-teamline').text()).not.toContain('Miami Marlins')
  })

  it('labels completed team-history windows as organization tenures instead of active', async () => {
    const payload = apiPayloadWith((response) => {
      response.data.team_history.push({
        id: 7,
        team: { id: 2, mlb_id: 120, name: 'Washington Nationals', abbreviation: 'WSH' },
        starts_on: '2022-08-07',
        ends_on: '2025-07-30',
        current: false,
        roster_status: 'active',
        source_status_description: 'Active',
      })
    })
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue({ ok: true, json: async () => payload }))

    const wrapper = mount(PlayerProfileView, {
      props: { playerId: '42' },
      global: { stubs: { RouterLink: { template: '<a><slot /></a>' } } },
    })
    await flushPromises()

    expect(wrapper.findAll('.team-timeline small').map((status) => status.text())).toEqual([
      'Active',
      'Organization tenure',
    ])
  })

  it('renders the unified player workflow', async () => {
    vi.stubGlobal(
      'fetch',
      vi.fn().mockResolvedValue({
        ok: true,
        json: async () => apiPayload(),
      }),
    )

    const wrapper = mount(PlayerProfileView, {
      props: { playerId: '42' },
      global: {
        stubs: {
          RouterLink: { template: '<a><slot /></a>' },
        },
      },
    })
    await flushPromises()

    expect(wrapper.text()).toContain('Riley Greene')
    expect(wrapper.text()).toContain('Detroit Tigers')
    expect(wrapper.text()).toContain('Active')
    expect(wrapper.get('[data-test="external-profile-mlb"]').attributes()).toMatchObject({
      href: 'https://www.mlb.com/player/riley-greene-680776',
      target: '_blank',
      rel: 'noopener noreferrer',
    })
    expect(wrapper.get('[data-test="external-profile-fangraphs"]').attributes('href')).toBe(
      'https://www.fangraphs.com/players/riley-greene/25976/stats',
    )
    expect(wrapper.get('[data-test="external-profile-baseball-reference"]').attributes('href')).toBe(
      'https://www.baseball-reference.com/players/g/greenri03.shtml',
    )
    expect(wrapper.get('[data-test="external-profile-baseball-savant"]').attributes('href')).toBe(
      'https://baseballsavant.mlb.com/savant-player/riley-greene-680776',
    )
    expect(wrapper.text()).toContain('Batting by season')
    expect(wrapper.text()).toContain('2022–2026 · 5 seasons')
    const careerTable = wrapper.get('[data-test="career-season-table"]')
    expect(careerTable.text()).toContain('2022')
    expect(careerTable.text()).toContain('2026')
    expect(careerTable.text()).toContain('DET')
    expect(careerTable.text()).toContain('0.740')
    expect(careerTable.text()).toContain('Career')
    expect(careerTable.text()).toContain('0.821')
    expect(wrapper.text()).not.toContain('Season snapshot')
    expect(wrapper.text()).toContain('Recent pitch indicators')
    expect(wrapper.text()).toContain('91.2 mph')
    expect(wrapper.text()).toContain('Team history')
    expect(wrapper.get('[data-test="player-date-range-controls"]').text()).toContain('Full season')
    expect(wrapper.get('[data-test="player-date-range-controls"]').text()).toContain('Last 30 days')
    expect(wrapper.get('[data-test="player-trends"]').text()).toContain('Performance trends')
    expect(wrapper.get('[data-test="player-trends"]').text()).toContain('Batting · Exit velocity')
    expect(wrapper.get('[data-test="player-trends"] svg').attributes('aria-label')).toBe('Batting · Exit velocity rolling trend')
    const benchmarks = wrapper.get('[data-test="contextual-benchmarks"]')
    expect(benchmarks.text()).toContain('Benchmarks & percentiles')
    expect(benchmarks.text()).toContain('0.842')
    expect(benchmarks.text()).toContain('0.720')
    expect(benchmarks.text()).toContain('CF')
    expect(benchmarks.text()).toContain('P83')
    expect(benchmarks.text()).toContain('+0.052')
    expect(benchmarks.text()).toContain('480')
    expect(wrapper.text()).toContain('Baseball Savant')
    expect(wrapper.get('.profile-portrait img').attributes()).toMatchObject({
      src: 'https://img.mlbstatic.com/mlb-photos/image/upload/ar_20:23,c_fill,g_north,w_260/c_pad,b_auto:border,w_300,h_300,q_auto:best/v1/people/680776/headshot/67/current',
      alt: 'Riley Greene headshot',
    })
    expect(wrapper.get('.profile-portrait').classes()).toContain('profile-portrait--photo')

    await wrapper.get('.range-presets button:nth-child(2)').trigger('click')
    await flushPromises()
    expect(fetch).toHaveBeenLastCalledWith('/api/players/42?range=7&pa_window=50&pitch_window=100', {
      headers: { Accept: 'application/json' },
    })
  })

  it('shows pitching trends for primary pitchers', async () => {
    vi.stubGlobal(
      'fetch',
      vi.fn().mockResolvedValue({
        ok: true,
        json: async () => apiPayloadWith((payload) => {
          payload.data.positions = {
            primary: { abbreviation: 'SP', name: 'Starting Pitcher', position_type: 'pitcher' },
            secondary: [],
            assignments: [],
          }
          payload.data.recent_pitch_indicators.primary_role = 'pitcher'
          payload.data.analysis.batting.charts = [
            {
              key: 'exit_velocity', title: 'Exit velocity', unit: 'mph',
              series: [{ key: 'exit_velocity', label: 'Exit velocity', points: [
                { date: '2026-04-01', sequence: 1, value: 89.0, sample_size: 1 },
                { date: '2026-07-14', sequence: 480, value: 91.2, sample_size: 18 },
              ] }],
            },
          ]
          payload.data.analysis.pitching = {
            window_type: 'pitches',
            window_size: 100,
            total_observations: 320,
            charts: [
              {
                key: 'velocity', title: 'Velocity', unit: 'mph',
                series: [{ key: 'velocity', label: 'Velocity', points: [
                  { date: '2026-04-01', sequence: 1, value: 96.1, sample_size: 20 },
                  { date: '2026-07-14', sequence: 320, value: 97.3, sample_size: 25 },
                ] }],
              },
            ],
          }
        }),
      }),
    )

    const wrapper = mount(PlayerProfileView, {
      props: { playerId: '42' },
      global: { stubs: { RouterLink: true } },
    })
    await flushPromises()

    const trends = wrapper.get('[data-test="player-trends"]')
    expect(trends.text()).toContain('Pitching · Velocity')
    expect(trends.text()).not.toContain('Batting · Exit velocity')
    expect(trends.find('svg').attributes('aria-label')).toBe('Pitching · Velocity rolling trend')
    expect(wrapper.find('[data-test="indicator-card-batting"]').exists()).toBe(false)
    expect(wrapper.find('[data-test="indicator-card-pitching"]').exists()).toBe(true)
  })

  it('shows both batting and pitching trends for two-way players', async () => {
    vi.stubGlobal(
      'fetch',
      vi.fn().mockResolvedValue({
        ok: true,
        json: async () => apiPayloadWith((payload) => {
          payload.data.positions = {
            primary: { abbreviation: 'TWP', name: 'Two-Way Player', position_type: 'two_way' },
            secondary: [
              { abbreviation: 'DH', name: 'Designated Hitter', position_type: 'designated_hitter' },
              { abbreviation: 'SP', name: 'Starting Pitcher', position_type: 'pitcher' },
            ],
            assignments: [
              { current: true, primary: true, position: { abbreviation: 'TWP', name: 'Two-Way Player', position_type: 'two_way', sort_order: 1 } },
              { current: true, primary: false, position: { abbreviation: 'SP', name: 'Starting Pitcher', position_type: 'pitcher', sort_order: 2 } },
            ],
          }
          payload.data.analysis.pitching = {
            window_type: 'pitches',
            window_size: 100,
            total_observations: 320,
            charts: [
              {
                key: 'velocity', title: 'Velocity', unit: 'mph',
                series: [{ key: 'velocity', label: 'Velocity', points: [
                  { date: '2026-04-01', sequence: 1, value: 96.1, sample_size: 20 },
                  { date: '2026-07-14', sequence: 320, value: 97.3, sample_size: 25 },
                ] }],
              },
            ],
          }
        }),
      }),
    )

    const wrapper = mount(PlayerProfileView, {
      props: { playerId: '42' },
      global: { stubs: { RouterLink: true } },
    })
    await flushPromises()

    const trends = wrapper.get('[data-test="player-trends"]')
    expect(trends.text()).toContain('Batting · Exit velocity')
    expect(trends.text()).toContain('Pitching · Velocity')
    expect(wrapper.find('[data-test="indicator-card-batting"]').exists()).toBe(true)
    expect(wrapper.find('[data-test="indicator-card-pitching"]').exists()).toBe(true)
  })

  it('falls back to player initials when the headshot cannot load', async () => {
    vi.stubGlobal(
      'fetch',
      vi.fn().mockResolvedValue({
        ok: true,
        json: async () => apiPayload(),
      }),
    )

    const wrapper = mount(PlayerProfileView, {
      props: { playerId: '42' },
      global: { stubs: { RouterLink: true } },
    })
    await flushPromises()

    await wrapper.get('.profile-portrait img').trigger('error')

    expect(wrapper.find('.profile-portrait img').exists()).toBe(false)
    expect(wrapper.get('.profile-portrait').classes()).not.toContain('profile-portrait--photo')
    expect(wrapper.get('.profile-portrait span').text()).toBe('RG')
  })

  it('renders a retry state when loading fails', async () => {
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue({ ok: false, status: 500 }))

    const wrapper = mount(PlayerProfileView, {
      props: { playerId: '42' },
      global: { stubs: { RouterLink: true } },
    })
    await flushPromises()

    expect(wrapper.get('[data-test="profile-error"]').text()).toContain('Unable to load this player profile')
    expect(wrapper.get('button').text()).toBe('Try again')
  })
})
